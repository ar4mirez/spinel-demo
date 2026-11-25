# frozen_string_literal: true

# Serves a directory written by gem-source/build.rb as a gem source:
#
#   spinel run gem-source/serve.rb DIR [PORT]   # default port 9293

require "webrick"

dir, port = ARGV
abort "usage: spinel run #{$0} DIR [PORT]" unless dir && File.file?(File.join(dir, "versions"))

server = WEBrick::HTTPServer.new(
  BindAddress: "127.0.0.1",
  Port: Integer(port || 9293),
  DocumentRoot: dir,
  AccessLog: [],
  Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
  MimeTypes: WEBrick::HTTPUtils::DefaultMimeTypes.merge("gem" => "application/octet-stream")
)
trap("TERM") { server.shutdown }
trap("INT") { server.shutdown }
warn "gem source: http://127.0.0.1:#{server.config[:Port]}/ serving #{dir}"
server.start
