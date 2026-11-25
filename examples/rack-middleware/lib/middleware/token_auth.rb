# frozen_string_literal: true

module Middleware
  # Guards every path under `prefix` with a bearer token. A request without
  # the right `Authorization: Bearer <token>` header gets a 401 and never
  # reaches the app; a request with it gets env["app.user"] set.
  class TokenAuth
    def initialize(app, token:, prefix: "/admin", user: "admin")
      raise ArgumentError, "token must not be empty" if token.to_s.empty?

      @app = app
      @token = token
      @prefix = prefix
      @user = user
    end

    def call(env)
      return @app.call(env) unless protected?(env["PATH_INFO"].to_s)

      scheme, given = env["HTTP_AUTHORIZATION"].to_s.split(" ", 2)
      return unauthorized unless scheme&.casecmp?("bearer") && secure_compare(given.to_s, @token)

      env["app.user"] = @user
      @app.call(env)
    end

    private

    def protected?(path)
      path == @prefix || path.start_with?("#{@prefix}/")
    end

    def unauthorized
      body = %({"error":"unauthorized"})
      [401, {"content-type" => "application/json", "www-authenticate" => %(Bearer realm="admin")}, [body]]
    end

    # Compares in time that does not depend on where the strings first differ.
    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      a.bytes.zip(b.bytes).reduce(0) { |acc, (x, y)| acc | (x ^ y) }.zero?
    end
  end
end
