require "minitest/autorun"
require "json"
require "uri"
require_relative "../lib/todos/app"

# Drives the app in-process with Rack::MockRequest, over an in-memory SQLite
# database; ./smoke covers the same routes over HTTP, on Puma, with a file.
class AppTest < Minitest::Test
  def setup
    @store = Todos::Store.new(":memory:")
    Todos::App.set :store, @store
    @app = Rack::MockRequest.new(Todos::App)
  end

  def teardown = @store.close

  def json(method, path, body = nil)
    opts = {}
    if body
      opts[:input] = body.is_a?(String) ? body.dup : JSON.generate(body)
      opts["CONTENT_TYPE"] = "application/json"
    end
    response = @app.request(method, path, opts)
    [response.status, response.body.empty? ? nil : JSON.parse(response.body), response]
  end

  def form(method, path, fields)
    @app.request(method, path, input: URI.encode_www_form(fields).dup,
                               "CONTENT_TYPE" => "application/x-www-form-urlencoded")
  end

  def test_create_read_update_delete
    status, body, response = json("POST", "/todos", { "title" => "  buy milk " })
    assert_equal 201, status
    assert_equal "/todos/1", response.headers["location"]
    assert_equal({ "id" => 1, "title" => "buy milk", "done" => false }, body["data"].except("created_at"))
    assert_match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/, body["data"]["created_at"])

    assert_equal "buy milk", json("GET", "/todos/1")[1]["data"]["title"]

    status, body, = json("PATCH", "/todos/1", { "done" => true })
    assert_equal 200, status
    assert_equal true, body["data"]["done"]
    assert_equal "buy milk", body["data"]["title"]

    status, body, = json("DELETE", "/todos/1")
    assert_equal 204, status
    assert_nil body
    assert_equal 404, json("GET", "/todos/1")[0]
    assert_equal 0, @store.count
  end

  def test_list_filters_by_done
    json("POST", "/todos", { "title" => "one" })
    json("POST", "/todos", { "title" => "two", "done" => true })
    assert_equal %w[one two], json("GET", "/todos")[1]["data"].map { |t| t["title"] }
    assert_equal %w[two], json("GET", "/todos?done=true")[1]["data"].map { |t| t["title"] }
    assert_equal %w[one], json("GET", "/todos?done=false")[1]["data"].map { |t| t["title"] }
    assert_equal 400, json("GET", "/todos?done=maybe")[0]
  end

  def test_validation_names_every_bad_field
    status, body, = json("POST", "/todos", { "title" => " ", "done" => "yes", "due" => "today" })
    assert_equal 422, status
    assert_equal({ "due" => "is not allowed", "title" => "must be a non-empty string", "done" => "must be true or false" },
                 body["error"]["details"])
    assert_equal({ "title" => "is required" }, json("POST", "/todos", {})[1]["error"]["details"])
    assert_equal 422, json("PATCH", "/todos/1", { "title" => "x" * 201 })[0]
  end

  def test_bad_bodies_and_missing_todos
    assert_equal 400, json("POST", "/todos", '{"title":')[0]
    assert_equal 400, json("POST", "/todos", "[1]")[0]
    assert_equal 415, @app.post("/todos", input: "title", "CONTENT_TYPE" => "text/plain").status
    assert_equal 404, json("PATCH", "/todos/7", { "done" => true })[0]
    assert_equal 404, json("DELETE", "/todos/7")[0]
    status, body, = json("GET", "/todos/abc")
    assert_equal 404, status
    assert_equal "todo abc not found", body["error"]["message"]
    assert_equal "no route for GET /nope", json("GET", "/nope")[1]["error"]["message"]
  end

  def test_html_page_and_forms
    response = form("POST", "/todos", { "title" => "<walk> the dog" })
    assert_equal 303, response.status
    assert_equal "/", URI(response.headers["location"]).path

    page = @app.get("/").body
    assert_includes page, "&lt;walk&gt; the dog"
    assert_includes page, "SQLite #{SQLite3::SQLITE_VERSION}"

    assert_equal 303, form("POST", "/todos/1", { "_method" => "patch", "done" => "true" }).status
    assert_equal true, @store.find(1)["done"]
    assert_includes @app.get("/").body, "<s>&lt;walk&gt; the dog</s>"

    assert_equal 303, form("POST", "/todos/1", { "_method" => "delete" }).status
    assert_nil @store.find(1)
  end

  def test_health_reports_engine_and_sqlite
    _, body, = json("GET", "/health")
    assert_equal "ok", body["status"]
    assert_equal RUBY_ENGINE, body["engine"]
    assert_equal SQLite3::SQLITE_VERSION, body["sqlite"]
  end
end
