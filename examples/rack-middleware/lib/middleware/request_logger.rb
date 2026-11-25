# frozen_string_literal: true

module Middleware
  # Writes one line per request: method, path, status, time taken and the
  # request id that RequestId set, for example
  #
  #   GET /admin/stats 401 0.21ms id=4f1c2a9e8b7d6c5e
  #
  # It logs to `io` (default: the server's rack.errors stream). A request
  # that raises is logged with status 500 and the error is raised again.
  class RequestLogger
    def initialize(app, io: nil)
      @app = app
      @io = io
    end

    def call(env)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      status, headers, body = @app.call(env)
      log(env, status, started)
      [status, headers, body]
    rescue StandardError
      log(env, 500, started)
      raise
    end

    private

    def log(env, status, started)
      ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
      path = env["PATH_INFO"].to_s
      path = "#{path}?#{env["QUERY_STRING"]}" unless env["QUERY_STRING"].to_s.empty?
      line = format("%s %s %d %.2fms id=%s\n", env["REQUEST_METHOD"], path, status, ms, env["app.request_id"] || "-")
      io = @io || env["rack.errors"]
      io.write(line)
      io.flush if io.respond_to?(:flush)
    end
  end
end
