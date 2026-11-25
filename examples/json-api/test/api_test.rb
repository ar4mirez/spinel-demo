require "minitest/autorun"
require "json"
require_relative "../lib/json_api/app"

# Drives the app in-process with Rack::MockRequest; ./smoke covers the same
# endpoints over HTTP.
class ApiTest < Minitest::Test
  def setup
    JsonApi::App.set :authors, JsonApi::Store.new
    JsonApi::App.set :books, JsonApi::Store.new
    @app = Rack::MockRequest.new(JsonApi::App)
  end

  def request(method, path, body = nil, type: "application/json")
    opts = {}
    if body
      opts[:input] = body.is_a?(String) ? body.dup : JSON.generate(body)
      opts["CONTENT_TYPE"] = type
    end
    response = @app.request(method, path, opts)
    [response.status, response.body.empty? ? nil : JSON.parse(response.body), response]
  end

  def create_author(name = "Octavia E. Butler") = request("POST", "/authors", { "name" => name })[1]["data"]

  def test_create_and_show_author_with_books
    status, body, response = request("POST", "/authors", { "name" => "Ursula K. Le Guin", "born" => 1929 })
    assert_equal 201, status
    assert_equal "/authors/1", response.headers["location"]
    assert_equal({ "id" => 1, "name" => "Ursula K. Le Guin", "born" => 1929 }, body["data"])

    request("POST", "/books", { "title" => "The Dispossessed", "author_id" => 1, "tags" => ["sf"] })
    status, body, = request("GET", "/authors/1")
    assert_equal 200, status
    assert_equal ["The Dispossessed"], body["data"]["books"].map { |b| b["title"] }
  end

  def test_responses_are_json
    _, body, response = request("GET", "/")
    assert_equal "application/json", response.media_type
    assert_equal "spinel", body["engine"] if RUBY_ENGINE == "spinel"
  end

  def test_validation_errors_name_every_bad_field
    status, body, = request("POST", "/books", { "title" => " ", "author_id" => "1", "year" => 0, "isbn" => "x" })
    assert_equal 422, status
    assert_equal "validation_failed", body["error"]["code"]
    assert_equal({ "isbn" => ["is not allowed"], "title" => ["must not be blank"],
                   "author_id" => ["must be an integer"], "year" => ["must be between 1 and 2100"] },
                 body["error"]["details"])
  end

  def test_book_needs_an_existing_author
    status, body, = request("POST", "/books", { "title" => "Kindred", "author_id" => 7 })
    assert_equal 422, status
    assert_equal ["author 7 does not exist"], body["error"]["details"]["author_id"]
  end

  def test_malformed_json_wrong_shape_and_wrong_media_type
    status, body, = request("POST", "/authors", '{"name":')
    assert_equal [400, "invalid_json"], [status, body["error"]["code"]]
    status, body, = request("POST", "/authors", "[1, 2]")
    assert_equal [400, "bad_request"], [status, body["error"]["code"]]
    status, body, = request("POST", "/authors", "name=x", type: "application/x-www-form-urlencoded")
    assert_equal [415, "unsupported_media_type"], [status, body["error"]["code"]]
  end

  def test_not_found_and_bad_ids
    assert_equal [404, "not_found"], request("GET", "/books/9").then { |s, b| [s, b["error"]["code"]] }
    assert_equal [400, "bad_request"], request("GET", "/books/nine").then { |s, b| [s, b["error"]["code"]] }
    assert_equal [404, "not_found"], request("GET", "/nowhere").then { |s, b| [s, b["error"]["code"]] }
  end

  def test_patch_filter_and_delete
    author = create_author
    request("POST", "/books", { "title" => "Kindred", "author_id" => author["id"], "tags" => ["sf"] })
    request("POST", "/books", { "title" => "Fledgling", "author_id" => author["id"], "tags" => ["vampires"] })

    status, body, = request("PATCH", "/books/1", { "year" => 1979 })
    assert_equal [200, 1979, "Kindred"], [status, body["data"]["year"], body["data"]["title"]]
    assert_equal ["Fledgling"], request("GET", "/books?tag=vampires")[1]["data"].map { |b| b["title"] }
    assert_equal 2, request("GET", "/books?author_id=#{author["id"]}")[1]["data"].size

    assert_equal 409, request("DELETE", "/authors/#{author["id"]}")[0]
    assert_equal 204, request("DELETE", "/books/1")[0]
    assert_equal 204, request("DELETE", "/books/2")[0]
    assert_equal 204, request("DELETE", "/authors/#{author["id"]}")[0]
    assert_equal [], request("GET", "/authors")[1]["data"]
  end

  def test_bad_author_id_filter_is_rejected_even_with_no_books
    status, body, = request("GET", "/books?author_id=abc")
    assert_equal [400, "bad_request"], [status, body["error"]["code"]]
  end

  def test_malformed_query_string_answers_json
    response = @app.request("GET", "/books", "QUERY_STRING" => "tag=%zz")
    assert_equal [400, "bad_request", "application/json"],
                 [response.status, JSON.parse(response.body)["error"]["code"], response.media_type]
  end

  def test_unicode_round_trips
    _, body, = request("POST", "/authors", { "name" => "Gabriel García Márquez ✓" })
    assert_equal "Gabriel García Márquez ✓", body["data"]["name"]
  end
end
