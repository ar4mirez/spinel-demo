# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "stringio"
require "fileutils"
require "tmpdir"
require_relative "../lib/todo/cli"

class CLITest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("todo")
    @file = File.join(@dir, "todo.json")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # Runs the CLI and returns [status, stdout, stderr].
  def todo(*argv)
    out = StringIO.new
    err = StringIO.new
    status = Todo::CLI.new(out:, err:, env: {"TODO_FILE" => @file}).run(argv)
    [status, out.string, err.string]
  end

  def test_add_and_list
    assert_equal [0, "added #1: buy milk\n", ""], todo("add", "-p", "high", "buy", "milk")
    assert_equal [0, "added #2: write docs\n", ""], todo("add", "write docs")
    status, out, = todo("list")
    assert_equal 0, status
    assert_equal "  1  [ ]  high    buy milk\n  2  [ ]  normal  write docs\n", out
  end

  def test_done_hides_tasks_unless_all
    todo("add", "one")
    todo("add", "two")
    assert_equal [0, "done #1\n", ""], todo("done", "1")
    assert_equal "  2  [ ]  normal  two\n", todo("list")[1]
    assert_match(/1  \[x\]  normal  one/, todo("list", "--all")[1])
  end

  def test_json_format
    todo("add", "one")
    data = JSON.parse(todo("list", "--format", "json")[1])
    assert_equal [{"id" => 1, "text" => "one", "priority" => "normal", "done" => false}], data
  end

  def test_rm
    todo("add", "one")
    assert_equal [0, "removed #1: one\n", ""], todo("rm", "1")
    assert_equal "no tasks\n", todo("list")[1]
  end

  def test_file_option_overrides_env
    other = File.join(@dir, "other.json")
    todo("--file", other, "add", "elsewhere")
    assert File.exist?(other)
    refute File.exist?(@file)
  end

  def test_missing_task_exits_1
    status, out, err = todo("done", "7")
    assert_equal 1, status
    assert_equal "", out
    assert_match(/no task #7/, err)
  end

  def test_usage_errors_exit_2
    [
      %w[bogus],
      %w[add],
      %w[add -p urgent x],
      %w[list --format xml],
      %w[list extra],
      %w[done abc],
      %w[rm],
      %w[rm 1 2],
      %w[--nope]
    ].each do |argv|
      status, _, err = todo(*argv)
      assert_equal 2, status, "todo #{argv.join(" ")}"
      assert_match(/^todo: .*\nRun 'todo help/, err, "todo #{argv.join(" ")}")
    end
  end

  def test_help
    [[], %w[help], %w[--help], %w[-h]].each do |argv|
      status, out, = todo(*argv)
      assert_equal 0, status
      assert_match(/^Usage: todo \[options\] COMMAND/, out)
      assert_match(/^    add +add a task$/, out)
    end
    assert_equal todo("help", "list"), todo("list", "--help")
    assert_match(/^Usage: todo add \[options\] TEXT\.\.\./, todo("help", "add")[1])
    assert_equal 2, todo("help", "bogus")[0]
  end

  def test_version
    status, out, = todo("--version")
    assert_equal 0, status
    assert_equal "todo #{Todo::VERSION} (#{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}, ruby #{RUBY_VERSION})\n", out
  end
end
