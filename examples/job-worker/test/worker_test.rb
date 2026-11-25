# frozen_string_literal: true

require "stringio"
require_relative "test_helper"

class WorkerTest < Minitest::Test
  include QueueDir

  def worker(threads: 3, out: StringIO.new) = JobWorker::Worker.new(@queue, threads: threads, poll: 0.01, out: out)

  def test_drain_runs_every_job_including_retries
    10.times { |i| @queue.enqueue("square", [i]) }
    @queue.enqueue("flaky")
    @queue.enqueue("boom", [], max_attempts: 2)
    @queue.enqueue("square", ["x"])
    out = StringIO.new
    w = worker(out: out)
    assert_equal 13, w.run(drain: true)
    assert_equal [11, 2], [w.processed, w.failed]
    assert_equal({ "pending" => 0, "running" => 0, "done" => 11, "failed" => 2 }, @queue.counts)
    assert_equal (0...10).map { |i| i * i }.sort, @queue.jobs("done").map { |j| j.data["result"] }.grep(Integer).sort
    log = out.string
    assert_match(/started with 3 threads \(drain\)/, log)
    assert_match(/will retry flaky .*attempt 1 of 3/, log)
    assert_match(/failed square .*must be an integer.*attempt 1 of 3/, log)
    assert_match(/stopped: 11 done, 2 failed\n\z/, log)
  end

  def test_threads_share_the_work
    12.times { @queue.enqueue("sleep", [50]) }
    worker(threads: 4).run(drain: true)
    assert_operator @queue.jobs("done").map { |j| j.data["worker"] }.uniq.length, :>, 1
  end

  def test_stop_finishes_the_running_job_and_claims_no_more
    @queue.enqueue("sleep", [300])
    3.times { @queue.enqueue("square", [2]) }
    w = worker(threads: 1)
    runner = Thread.new { w.run }
    sleep 0.01 until @queue.counts["running"] == 1
    w.stop
    runner.join
    assert_equal({ "pending" => 3, "running" => 0, "done" => 1, "failed" => 0 }, @queue.counts)
  end

  def test_recovers_jobs_from_dead_workers_on_start
    dead = Process.spawn("true")
    Process.wait(dead)
    @queue.enqueue("square", [5])
    @queue.claim(dead)
    out = StringIO.new
    worker(out: out).run(drain: true)
    assert_equal [25], @queue.jobs("done").map { |j| j.data["result"] }
    assert_match(/recovered .* from a worker that is gone/, out.string)
  end

  def test_rejects_zero_threads
    assert_raises(ArgumentError) { worker(threads: 0) }
  end
end
