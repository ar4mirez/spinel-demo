# frozen_string_literal: true

require_relative "test_helper"

class JobsTest < Minitest::Test
  Job = JobWorker::Queue::Job

  def run_job(type, args = [], attempts: 0)
    JobWorker::Jobs.run(Job.new({ "id" => "x", "type" => type, "args" => args, "attempts" => attempts }, nil, "running"))
  end

  def test_handlers
    assert_equal 49, run_job("square", [7])
    assert_equal 49, run_job("square", ["7"])
    assert_equal 2_880_067_194_370_816_120, run_job("fib", [90])
    assert_equal({ "words" => 5, "top" => "the" }, run_job("wordcount", ["The cat and", "the hat"]))
    assert_equal({ "words" => 0, "top" => nil }, run_job("wordcount", []))
    assert_equal 10, run_job("sleep", [10])
  end

  def test_flaky_fails_once
    assert_raises(RuntimeError) { run_job("flaky") }
    assert_equal "ok on attempt 2", run_job("flaky", attempts: 1)
  end

  def test_errors
    assert_raises(RuntimeError) { run_job("boom") }
    assert_raises(JobWorker::PermanentError) { run_job("nope") }
    assert_raises(JobWorker::PermanentError) { run_job("square", ["x"]) }
    assert_raises(JobWorker::PermanentError) { run_job("fib", [-1]) }
    assert_raises(JobWorker::PermanentError) { run_job("sleep", [600_000]) }
  end
end
