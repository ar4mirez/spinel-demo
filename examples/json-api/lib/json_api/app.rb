# frozen_string_literal: true

require "json"
require "sinatra/base"
require_relative "store"
require_relative "validator"

module JsonApi
  # A JSON API for authors and the books they wrote. Every response, errors
  # included, is a JSON object with the content type application/json.
  class App < Sinatra::Base
    AUTHOR = {
      "name" => { type: String, required: true, max: 100 },
      "born" => { type: Integer, range: 1..2100 }
    }.freeze
    BOOK = {
      "title" => { type: String, required: true, max: 200 },
      "author_id" => { type: Integer, required: true },
      "year" => { type: Integer, range: 1..2100 },
      "tags" => { type: Array, of: String }
    }.freeze

    configure do
      set :server, "webrick"
      set :bind, "127.0.0.1"
      set :port, 4580
      set :show_exceptions, false
      set :raise_errors, false
      set :dump_errors, false
      set :authors, Store.new
      set :books, Store.new
    end

    LOCK = Mutex.new

    # Raised by the helpers below; the error handler turns it into JSON.
    class Error < StandardError
      attr_reader :status, :code, :details

      def initialize(status, code, message, details = nil)
        super(message)
        @status = status
        @code = code
        @details = details
      end
    end

    before { content_type :json }

    get "/" do
      json(name: "json-api", engine: RUBY_ENGINE, version: RUBY_ENGINE_VERSION,
           resources: ["/authors", "/books"])
    end

    # Authors

    get "/authors" do
      json(data: settings.authors.all)
    end

    post "/authors" do
      author = settings.authors.create(validate(AUTHOR, body_object))
      status 201
      headers "Location" => "/authors/#{author["id"]}"
      json(data: author)
    end

    get "/authors/:id" do
      author = find(settings.authors, "author")
      json(data: author.merge("books" => books_by(author["id"])))
    end

    patch "/authors/:id" do
      find(settings.authors, "author")
      attrs = validate(AUTHOR, body_object, partial: true)
      atomically do
        find(settings.authors, "author")
        json(data: settings.authors.update(id, attrs))
      end
    end

    delete "/authors/:id" do
      atomically do
        find(settings.authors, "author")
        unless books_by(id).empty?
          raise Error.new(409, "conflict", "author #{id} still has books; delete them first")
        end
        settings.authors.delete(id)
      end
      status 204
      ""
    end

    # Books

    get "/books" do
      books = settings.books.all
      if params.key?("author_id")
        author_id = integer_param("author_id")
        books = books.select { |book| book["author_id"] == author_id }
      end
      if params.key?("tag")
        books = books.select { |book| Array(book["tags"]).include?(params["tag"]) }
      end
      json(data: books)
    end

    post "/books" do
      attrs = validate(BOOK, body_object)
      book = atomically do
        require_author(attrs["author_id"])
        settings.books.create(attrs)
      end
      status 201
      headers "Location" => "/books/#{book["id"]}"
      json(data: book)
    end

    get "/books/:id" do
      json(data: find(settings.books, "book"))
    end

    patch "/books/:id" do
      find(settings.books, "book")
      attrs = validate(BOOK, body_object, partial: true)
      atomically do
        find(settings.books, "book")
        require_author(attrs["author_id"]) if attrs.key?("author_id")
        json(data: settings.books.update(id, attrs))
      end
    end

    delete "/books/:id" do
      atomically do
        find(settings.books, "book")
        settings.books.delete(id)
      end
      status 204
      ""
    end

    # Errors

    error Error do
      e = env["sinatra.error"]
      status e.status
      error_body(e.code, e.message, e.details)
    end

    error Sinatra::BadRequest do
      content_type :json
      error_body("bad_request", env["sinatra.error"].message)
    end

    not_found do
      content_type :json
      error_body("not_found", "no route for #{request.request_method} #{request.path_info}")
    end

    error 500 do
      content_type :json
      error_body("internal_error", "something went wrong")
    end

    helpers do
      def json(object) = JSON.generate(object)

      def error_body(code, message, details = nil)
        error = { code: code, message: message }
        error[:details] = details if details
        json(error: error)
      end

      def id = integer_param("id")

      # Writes that check one record and then change another run under one
      # app-wide lock, so a check cannot go stale before its write lands.
      def atomically(&) = LOCK.synchronize(&)

      def integer_param(name)
        value = params[name].to_s
        raise Error.new(400, "bad_request", "#{name} must be an integer") unless value.match?(/\A\d+\z/)
        value.to_i
      end

      def find(store, kind)
        store.find(id) || raise(Error.new(404, "not_found", "#{kind} #{id} not found"))
      end

      def books_by(author_id) = settings.books.all.select { |book| book["author_id"] == author_id }

      def require_author(author_id)
        return if settings.authors.find(author_id)
        raise Error.new(422, "validation_failed", "the request body is invalid",
                        { "author_id" => ["author #{author_id} does not exist"] })
      end

      # The request body as a JSON object (a Hash), or a 400/415.
      def body_object
        unless request.media_type == "application/json"
          raise Error.new(415, "unsupported_media_type", "send the body as application/json")
        end
        body = JSON.parse(request.body.read)
        raise Error.new(400, "bad_request", "the body must be a JSON object") unless body.is_a?(Hash)
        body
      rescue JSON::ParserError => e
        raise Error.new(400, "invalid_json", "the body is not valid JSON: #{e.message.lines.first.strip}")
      end

      def validate(schema, body, partial: false)
        validator = Validator.new(schema, body, partial: partial)
        return validator.attributes if validator.valid?
        raise Error.new(422, "validation_failed", "the request body is invalid", validator.errors)
      end
    end
  end
end
