# frozen_string_literal: true

# Serves the todo app with its database at tmp/todos.db in this directory:
#
#   spinel run .spinel/gem_home/bin/puma -b tcp://127.0.0.1:9330
require "fileutils"
require_relative "lib/todos/app"

database = File.join(__dir__, "tmp", "todos.db")
FileUtils.mkdir_p(File.dirname(database))
Todos::App.set :store, Todos::Store.new(database)

run Todos::App
