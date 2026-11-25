# frozen_string_literal: true

# A small Rack app, served by Puma on Spinel:
#
#   cd puma && spinel run .spinel/gem_home/bin/puma -b tcp://127.0.0.1:9292

require "json"
require "rack"

class NotesApp
  def initialize
    @notes = []
    @lock = Mutex.new
  end

  def call(env)
    req = Rack::Request.new(env)
    case [req.request_method, req.path_info]
    in ["GET", "/"]
      text("Hello from #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION} on Puma #{Puma::Const::PUMA_VERSION}\n")
    in ["GET", "/health"]
      json({status: "ok", engine: RUBY_ENGINE, ruby: RUBY_VERSION, pid: Process.pid})
    in ["GET", "/notes"]
      json({notes: @lock.synchronize { @notes.dup }})
    in ["POST", "/notes"]
      body = JSON.parse(req.body.read)
      note = body["text"] if body.is_a?(Hash)
      return error(422, "missing text") unless note.is_a?(String)

      @lock.synchronize { @notes << note }
      json({created: note}, status: 201)
    else
      error(404, "no route for #{req.request_method} #{req.path_info}")
    end
  rescue JSON::ParserError
    error(400, "body is not JSON")
  end

  private

  def text(body, status: 200) = [status, {"content-type" => "text/plain"}, [body]]
  def json(data, status: 200) = [status, {"content-type" => "application/json"}, [JSON.generate(data)]]
  def error(status, message) = json({error: message}, status:)
end

run NotesApp.new
