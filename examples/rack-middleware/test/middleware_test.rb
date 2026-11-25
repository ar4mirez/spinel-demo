# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "stringio"
require "rack"
require "rack/mock"
require_relative "../lib/app"

# Each middleware on its own, around a tiny app, then the whole stack from
# config.ru, all through Rack::MockRequest (no server).
class MiddlewareTest < Minitest::Test
  OK = ->(env) { [200, {"content-type" => "text/plain"}, ["ok #{env["app.user"]}"]] }

  def request(app, path, **opts) = Rack::MockRequest.new(app).get(path, opts)

  def test_request_id_generates_one
    res = request(Middleware::RequestId.new(OK), "/")
    assert_match(/\A\h{16}\z/, res.headers["x-request-id"])
  end

  def test_request_id_keeps_a_valid_client_id_and_replaces_a_bad_one
    app = Middleware::RequestId.new(OK)
    assert_equal "abc-123", request(app, "/", "HTTP_X_REQUEST_ID" => "abc-123").headers["x-request-id"]
    refute_equal "bad id!", request(app, "/", "HTTP_X_REQUEST_ID" => "bad id!").headers["x-request-id"]
  end

  def test_timing_uses_the_clock
    ticks = [10.0, 10.25].each
    res = request(Middleware::Timing.new(OK, clock: -> { ticks.next }), "/")
    assert_equal "0.250000", res.headers["x-runtime"]
    assert_equal "app;dur=250.000", res.headers["server-timing"]
  end

  def test_token_auth
    app = Middleware::TokenAuth.new(OK, token: "s3cret")
    assert_equal 200, request(app, "/public").status
    assert_equal 200, request(app, "/administrator").status
    assert_equal 401, request(app, "/admin").status
    assert_equal 401, request(app, "/admin/x", "HTTP_AUTHORIZATION" => "Bearer nope").status
    assert_equal 401, request(app, "/admin/x", "HTTP_AUTHORIZATION" => "Basic s3cret").status
    res = request(app, "/admin/x", "HTTP_AUTHORIZATION" => "Bearer s3cret")
    assert_equal [200, "ok admin"], [res.status, res.body]
    assert_raises(ArgumentError) { Middleware::TokenAuth.new(OK, token: "") }
  end

  def test_request_logger
    log = StringIO.new
    app = Middleware::RequestLogger.new(OK, io: log)
    request(app, "/x?y=1", "app.request_id" => "rid")
    assert_match(%r{\AGET /x\?y=1 200 \d+\.\d\dms id=rid\n\z}, log.string)
  end

  def test_request_logger_logs_errors_as_500
    log = StringIO.new
    app = Middleware::RequestLogger.new(->(_) { raise "boom" }, io: log)
    assert_raises(RuntimeError) { request(app, "/boom") }
    assert_match(%r{\AGET /boom 500 }, log.string)
  end

  def test_config_ru_stack
    app, = Rack::Builder.parse_file(File.expand_path("../config.ru", __dir__))
    res = request(app, "/admin/stats", "HTTP_AUTHORIZATION" => "Bearer secret", "HTTP_X_REQUEST_ID" => "t1")
    assert_equal 200, res.status
    assert_equal "t1", res.headers["x-request-id"]
    assert res.headers["x-runtime"]
    assert_equal "admin", JSON.parse(res.body)["user"]
    assert_match(%r{GET /admin/stats 200 .* id=t1}, res.errors)

    res = request(app, "/admin/stats")
    assert_equal 401, res.status
    assert_equal "t1", request(app, "/whoami", "HTTP_X_REQUEST_ID" => "t1").headers["x-request-id"]
  end
end
