# Serves the JSON API on http://127.0.0.1:4580 (PORT overrides the port).
require_relative "lib/json_api/app"

JsonApi::App.set :port, Integer(ENV.fetch("PORT", "4580"))
JsonApi::App.run!
