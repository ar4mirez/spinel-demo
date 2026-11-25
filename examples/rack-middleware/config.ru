# frozen_string_literal: true

# A small app behind four custom Rack middleware, served by Puma on Spinel:
#
#   API_TOKEN=demo-token spinel run .spinel/gem_home/bin/puma -b tcp://127.0.0.1:9310
#
# Each `use` wraps everything below it, so a request passes through them
# top to bottom and the response comes back bottom to top.

require_relative "lib/app"

use Middleware::RequestId                    # sets env["app.request_id"], adds x-request-id
use Middleware::RequestLogger                # one line per request on rack.errors (Puma's stderr)
use Middleware::Timing                       # adds x-runtime and server-timing
use Middleware::TokenAuth,                   # 401 under /admin without the bearer token
    token: ENV.fetch("API_TOKEN") { abort "config.ru: set API_TOKEN to the bearer token for /admin, e.g. API_TOKEN=demo-token" },
    prefix: "/admin"
run App.new
