# frozen_string_literal: true

require "erb"
require "json"
require "sinatra/base"
require_relative "store"

module Todos
  # A todo list over SQLite: a JSON API under /todos and an HTML page at /
  # whose forms use the same routes. Set :store to a Todos::Store before
  # serving it (config.ru does).
  class App < Sinatra::Base
    configure do
      set :show_exceptions, false
      set :raise_errors, false
      set :dump_errors, false
      set :method_override, true # HTML forms send _method=patch|delete
      set :store, nil
    end

    # Raised by the helpers below; the error handler turns it into JSON.
    class Error < StandardError
      attr_reader :status, :details

      def initialize(status, message, details = nil)
        super(message)
        @status = status
        @details = details
      end
    end

    get "/" do
      @todos = store.all
      erb :index
    end

    get "/health" do
      json(status: "ok", engine: RUBY_ENGINE, version: RUBY_ENGINE_VERSION,
           sqlite: store.sqlite_version, todos: store.count)
    end

    get "/todos" do
      done = params.key?("done") ? boolean(params["done"], "done") : nil
      json(data: store.all(done: done))
    end

    post "/todos" do
      attrs = validate(input, partial: false)
      todo = store.create(**attrs)
      return redirect("/", 303) if form?
      status 201
      headers "Location" => "/todos/#{todo["id"]}"
      json(data: todo)
    end

    get "/todos/:id" do
      json(data: find)
    end

    patch "/todos/:id" do
      attrs = validate(input, partial: true)
      todo = store.update(id, attrs) || not_found_error
      return redirect("/", 303) if form?
      json(data: todo)
    end

    delete "/todos/:id" do
      store.delete(id) || not_found_error
      return redirect("/", 303) if form?
      status 204
      ""
    end

    error Error do
      e = env["sinatra.error"]
      status e.status
      error_body(e.message, e.details)
    end

    error SQLite3::Exception do
      status 500
      error_body("database error: #{env["sinatra.error"].message}")
    end

    not_found do
      error_body("no route for #{request.request_method} #{request.path_info}")
    end

    helpers do
      def store = settings.store

      def json(object)
        content_type :json
        JSON.generate(object)
      end

      def error_body(message, details = nil)
        error = { message: message }
        error[:details] = details if details
        json(error: error)
      end

      def form? = request.form_data?

      def id
        value = params["id"].to_s
        raise Error.new(404, "todo #{value} not found") unless value.match?(/\A\d{1,18}\z/)
        value.to_i
      end

      def find = store.find(id) || not_found_error

      def not_found_error = raise(Error.new(404, "todo #{params["id"]} not found"))

      # The request's fields: a JSON object, or the form's fields.
      def input
        return params.slice("title", "done") if form?
        unless request.media_type == "application/json"
          raise Error.new(415, "send application/json or a form")
        end
        body = request.body.read
        object = begin
          JSON.parse(body)
        rescue JSON::ParserError
          raise Error.new(400, "the request body is not valid JSON")
        end
        raise Error.new(400, "the request body must be a JSON object") unless object.is_a?(Hash)
        object
      end

      # Checks title and done, and returns them as keyword arguments for
      # the store. Unknown fields and bad values are a 422 naming each one.
      def validate(fields, partial:)
        errors = {}
        attrs = {}
        (fields.keys - %w[title done]).each { |key| errors[key] = "is not allowed" }
        if fields.key?("title")
          title = fields["title"]
          if !title.is_a?(String) || title.strip.empty?
            errors["title"] = "must be a non-empty string"
          elsif title.strip.length > 200
            errors["title"] = "must be at most 200 characters"
          else
            attrs[:title] = title.strip
          end
        elsif !partial
          errors["title"] = "is required"
        end
        if fields.key?("done")
          value = fields["done"]
          value = { "true" => true, "false" => false }.fetch(value, value) if form?
          if value == true || value == false
            attrs[:done] = value
          else
            errors["done"] = "must be true or false"
          end
        end
        raise Error.new(422, "the request is invalid", errors) unless errors.empty?
        attrs
      end

      def boolean(value, name)
        return true if value == "true"
        return false if value == "false"
        raise Error.new(400, "#{name} must be true or false")
      end

      def h(text) = ERB::Util.html_escape(text)
    end

    template :index do
      <<~'HTML'
        <!doctype html>
        <html lang="en">
        <head><meta charset="utf-8"><title>Todos</title></head>
        <body>
          <h1>Todos</h1>
          <p>On <%= h RUBY_ENGINE %> <%= h RUBY_ENGINE_VERSION %>, SQLite <%= h store.sqlite_version %>.</p>
          <form method="post" action="/todos">
            <input name="title" placeholder="What needs doing?" required maxlength="200">
            <button>Add</button>
          </form>
          <ul>
          <% @todos.each do |todo| %>
            <li id="todo-<%= todo["id"] %>">
              <form method="post" action="/todos/<%= todo["id"] %>" style="display:inline">
                <input type="hidden" name="_method" value="patch">
                <input type="hidden" name="done" value="<%= !todo["done"] %>">
                <button><%= todo["done"] ? "Undo" : "Done" %></button>
              </form>
              <%= todo["done"] ? "<s>#{h todo["title"]}</s>" : h(todo["title"]) %>
              <form method="post" action="/todos/<%= todo["id"] %>" style="display:inline">
                <input type="hidden" name="_method" value="delete">
                <button>Delete</button>
              </form>
            </li>
          <% end %>
          </ul>
        </body>
        </html>
      HTML
    end
  end
end
