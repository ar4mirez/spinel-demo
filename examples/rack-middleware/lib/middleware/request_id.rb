# frozen_string_literal: true

require "securerandom"

module Middleware
  # Gives every request an id: the client's X-Request-Id when it sent a sane
  # one, otherwise a new random one. The id goes into the env for the layers
  # below and back to the client in the x-request-id response header.
  class RequestId
    HEADER = "x-request-id"
    ENV_KEY = "app.request_id"
    VALID = /\A[\w.-]{1,64}\z/

    def initialize(app)
      @app = app
    end

    def call(env)
      id = env["HTTP_X_REQUEST_ID"]
      id = SecureRandom.hex(8) unless id&.match?(VALID)
      env[ENV_KEY] = id

      status, headers, body = @app.call(env)
      headers[HEADER] = id
      [status, headers, body]
    end
  end
end
