# frozen_string_literal: true

require_relative "test_helper"

class QueueTest < Minitest::Test
  include QueueDir

  def test_creates_the_state_directories
    assert_equal %w[done failed incoming pending running], Dir.children(@dir).sort
    assert_equal({ "pending" => 0, "running" => 0, "done" => 0, "failed" => 0 }, @queue.counts)
  end

  def test_claims_jobs_oldest_first
    ids = %w[a b c].map { |arg| @queue.enqueue("square", [arg]) }
    assert_equal ids, ids.sort
    assert_equal %w[a b c], 3.times.map { @queue.claim.args.first }
    assert_nil @queue.claim
    assert_equal 3, @queue.counts["running"]
  end

  def test_a_claimed_file_names_the_worker_process
    @queue.enqueue("square", [2])
    job = @queue.claim(4242)
    assert_equal "#{job.id}.4242.json", File.basename(job.path)
    assert_equal "running", job.state
    assert_equal 0, job.attempts
  end

  def test_complete_moves_the_job_to_done_with_its_result
    @queue.enqueue("square", [3])
    @queue.complete(@queue.claim, 9, worker: "w1")
    done = @queue.jobs("done")
    assert_equal [9], done.map { |j| j.data["result"] }
    assert_equal "w1", done.first.data["worker"]
    assert_equal({ "pending" => 0, "running" => 0, "done" => 1, "failed" => 0 }, @queue.counts)
  end

  def test_fail_retries_until_the_attempts_run_out
    @queue.enqueue("boom", [], max_attempts: 2)
    assert_equal "pending", @queue.fail(@queue.claim, "first")
    job = @queue.claim
    assert_equal 1, job.attempts
    assert_equal "failed", @queue.fail(job, "second")
    failed = @queue.jobs("failed").first
    assert_equal [2, "second"], [failed.attempts, failed.data["error"]]
    assert_nil @queue.claim
  end

  def test_fail_without_retry_goes_straight_to_failed
    @queue.enqueue("boom")
    assert_equal "failed", @queue.fail(@queue.claim, "permanent", retryable: false)
    assert_equal 1, @queue.counts["failed"]
  end

  def test_recover_requeues_jobs_of_dead_processes_only
    dead = Process.spawn("true")
    Process.wait(dead)
    @queue.enqueue("square", [1])
    @queue.enqueue("square", [2])
    @queue.claim(dead)
    @queue.claim(Process.pid)
    assert_equal 1, @queue.recover.length
    assert_equal [1], @queue.jobs("pending").map { |j| j.args.first }
    assert_equal [2], @queue.jobs("running").map { |j| j.args.first }
  end

  def test_threads_never_claim_the_same_job_twice
    100.times { |i| @queue.enqueue("square", [i]) }
    claimed = Thread::Queue.new
    8.times.map { Thread.new { while (job = @queue.claim); claimed << job.args.first; end } }.each(&:join)
    ids = Array.new(claimed.size) { claimed.pop }
    assert_equal (0...100).to_a, ids.sort
  end

  def test_processes_never_claim_the_same_job_twice
    60.times { |i| @queue.enqueue("square", [i]) }
    readers = 3.times.map do
      r, w = IO.pipe
      pid = fork do
        r.close
        queue = JobWorker::Queue.new(@dir)
        while (job = queue.claim); w.puts(job.args.first); end
        w.close
        exit!(0)
      end
      w.close
      [pid, r]
    end
    ids = readers.flat_map { |pid, r| r.read.split.map(&:to_i).tap { Process.wait(pid); r.close } }
    assert_equal (0...60).to_a, ids.sort
  end

  def test_rejects_bad_jobs
    assert_raises(ArgumentError) { @queue.enqueue("") }
    assert_raises(ArgumentError) { @queue.enqueue("square", [1], max_attempts: 0) }
    assert_raises(ArgumentError) { @queue.jobs("lost") }
  end
end
