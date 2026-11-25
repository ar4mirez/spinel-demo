# frozen_string_literal: true

require "optparse"
require "json"
require_relative "store"

module Todo
  VERSION = "1.0.0"

  # The `todo` command line: global options, then a subcommand with options of
  # its own. #run returns the exit status instead of exiting, so tests can call
  # it directly.
  class CLI
    OK = 0
    FAILURE = 1 # the command ran but could not do what was asked
    USAGE = 2   # the command line itself was wrong

    # Raised for a bad command line; #run prints it with a usage hint.
    class UsageError < StandardError; end

    COMMANDS = {
      "add" => "add a task",
      "list" => "list open tasks",
      "done" => "mark tasks done",
      "rm" => "remove a task",
      "help" => "show help for a command"
    }.freeze

    def initialize(out: $stdout, err: $stderr, env: ENV)
      @out = out
      @err = err
      @file = env.fetch("TODO_FILE", "todo.json")
    end

    def run(argv)
      argv = argv.dup
      global.order!(argv) # stops at the first non-option: the subcommand
      return help([]) if argv.empty?

      name = argv.shift
      raise UsageError, "unknown command '#{name}'" unless COMMANDS.key?(name)

      send(:"cmd_#{name}", argv)
    rescue OptionParser::ParseError, UsageError => e
      @err.puts "todo: #{e.message}"
      @err.puts "Run 'todo help#{" #{name}" if COMMANDS.key?(name.to_s) && name != "help"}' for usage."
      USAGE
    rescue HelpShown
      OK
    end

    private

    # Raised once --help or --version has printed, to stop parsing.
    class HelpShown < StandardError; end

    def global
      OptionParser.new do |o|
        o.banner = "Usage: todo [options] COMMAND [command options] [ARGS]"
        o.separator ""
        o.separator "Commands:"
        COMMANDS.each { |name, summary| o.separator format("    %-10s %s", name, summary) }
        o.separator ""
        o.separator "Options:"
        o.on("-f", "--file PATH", "the task file (default: $TODO_FILE or ./todo.json)") { |v| @file = v }
        o.on("-V", "--version", "print the version and exit") do
          @out.puts "todo #{VERSION} (#{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}, ruby #{RUBY_VERSION})"
          raise HelpShown
        end
        o.on("-h", "--help", "print this help and exit") { show(o) }
        o.separator ""
        o.separator "Exit status: 0 on success, 1 when a task is not found, 2 for a usage error."
      end
    end

    def parser(name, args = nil)
      OptionParser.new do |o|
        o.banner = "Usage: todo #{name} [options]#{" #{args}" if args}"
        o.separator ""
        o.separator COMMANDS.fetch(name).capitalize
        yield o if block_given?
        o.on("-h", "--help", "print this help and exit") { show(o) }
        o.base.long.delete("version")
      end
    end

    def show(parser)
      @out.puts parser.help
      raise HelpShown
    end

    def cmd_add(argv)
      priority = "normal"
      parser("add", "TEXT...") do |o|
        o.on("-p", "--priority LEVEL", Store::PRIORITIES, "high, normal (default) or low") { |v| priority = v }
      end.parse!(argv)
      raise UsageError, "add: no task text given" if argv.empty?

      store = Store.new(@file)
      task = store.add(argv.join(" "), priority:)
      store.save
      @out.puts "added ##{task.id}: #{task.text}"
      OK
    end

    def cmd_list(argv)
      all = false
      format = "table"
      parser("list") do |o|
        o.on("-a", "--all", "include tasks that are done") { all = true }
        o.on("--format FORMAT", %w[table json], "table (default) or json") { |v| format = v }
      end.parse!(argv)
      raise UsageError, "list: unexpected argument '#{argv.first}'" unless argv.empty?

      tasks = Store.new(@file).tasks(all:)
      @out.puts format == "json" ? JSON.pretty_generate(tasks.map(&:to_h)) : table(tasks)
      OK
    end

    def cmd_done(argv)
      parser("done", "ID...").parse!(argv)
      ids = ids(argv, "done")
      store = Store.new(@file)
      missing = ids.reject { |id| store.complete(id) }
      store.save if missing.size < ids.size
      (ids - missing).each { |id| @out.puts "done ##{id}" }
      not_found(missing)
    end

    def cmd_rm(argv)
      parser("rm", "ID").parse!(argv)
      ids = ids(argv, "rm")
      raise UsageError, "rm: give exactly one ID" unless ids.size == 1

      store = Store.new(@file)
      task = store.remove(ids.first) or return not_found(ids)
      store.save
      @out.puts "removed ##{task.id}: #{task.text}"
      OK
    end

    def cmd_help(argv)
      parser("help", "[COMMAND]").parse!(argv)
      help(argv)
    end

    def help(argv)
      name = argv.first
      return show(global) if name.nil?
      raise UsageError, "unknown command '#{name}'" unless COMMANDS.key?(name)

      send(:"cmd_#{name}", ["--help"])
    end

    def ids(argv, name)
      raise UsageError, "#{name}: no task ID given" if argv.empty?

      argv.map { |arg| Integer(arg, 10, exception: false) or raise UsageError, "#{name}: not a task ID: '#{arg}'" }
    end

    def not_found(ids)
      return OK if ids.empty?

      @err.puts "todo: no task #{ids.map { |id| "##{id}" }.join(", ")} in #{@file}"
      FAILURE
    end

    def table(tasks)
      return "no tasks" if tasks.empty?

      tasks.map do |t|
        format("%3d  [%s]  %-6s  %s", t.id, t.done ? "x" : " ", t.priority, t.text)
      end.join("\n")
    end
  end
end
