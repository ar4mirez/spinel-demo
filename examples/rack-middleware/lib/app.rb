# frozen_string_literal: true

require "json"
require "rack"
require_relative "middleware/request_id"
require_relative "middleware/request_logger"
require_relative "middleware/timing"
require_relative "middleware/token_auth"

# The app behind the middleware. It knows nothing about logging, timing or
# auth; it reads what the middleware left in the env.
class App
  def initialize
    @hits = 0
    @lock = Mutex.new
  end

  def call(env)
    @lock.synchronize { @hits += 1 }
    req = Rack::Request.new(env)
    case [req.request_method, req.path_info]
    in ["GET", "/"]
      text("Hello from #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}, behind four middleware\n")
    in ["GET", "/whoami"]
      json({request_id: env["app.request_id"], user: env["app.user"]})
    in ["GET", "/admin/stats"]
      json({user: env["app.user"], hits: @lock.synchronize { @hits }, engine: RUBY_ENGINE})
    else
      json({error: "no route for #{req.request_method} #{req.path_info}"}, status: 404)
    end
  end

  private

  def text(body, status: 200) = [status, {"content-type" => "text/plain"}, [body]]
  def json(data, status: 200) = [status, {"content-type" => "application/json"}, [JSON.generate(data)]]
end
