# frozen_string_literal: true

module Middleware
  # Measures how long the rest of the stack takes and reports it in the
  # x-runtime header (seconds) and as a Server-Timing entry (milliseconds).
  class Timing
    def initialize(app, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @app = app
      @clock = clock
    end

    def call(env)
      started = @clock.call
      status, headers, body = @app.call(env)
      elapsed = @clock.call - started
      headers["x-runtime"] = format("%.6f", elapsed)
      headers["server-timing"] = format("app;dur=%.3f", elapsed * 1000)
      [status, headers, body]
    end
  end
end
