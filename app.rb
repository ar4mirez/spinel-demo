require "sinatra/base"

class App < Sinatra::Base
  set :server, "webrick"
  get("/") { "Hello from #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}" }
end

App.run!
