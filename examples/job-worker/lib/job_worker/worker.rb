# frozen_string_literal: true

require_relative "queue"
require_relative "jobs"

module JobWorker
  # A worker process: a pool of threads that claim jobs from a Queue directory
  # and run them, until it is told to stop (or, with drain: true, until the
  # queue is empty).
  #
  # Log lines go through a Thread::Queue to one logger thread, so the job
  # threads never write to the output at the same time, and #stop (which a
  # signal handler calls) only sets a flag.
  class Worker
    attr_reader :processed, :failed

    def initialize(queue, threads: 2, poll: 0.1, out: $stdout, runner: Jobs)
      raise ArgumentError, "threads must be at least 1" unless threads.is_a?(Integer) && threads >= 1

      @queue = queue
      @threads = threads
      @poll = poll
      @out = out
      @runner = runner
      @lock = Mutex.new
      @busy = 0
      @processed = 0
      @failed = 0
      @stopping = false
    end

    # Asks the worker to stop: each thread finishes the job it is running and
    # claims no more. Safe to call from a signal handler.
    def stop = @stopping = true

    def stopping? = @stopping

    # Runs until #stop is called, or with drain: true until no job is pending
    # or running in this worker. Returns the number of jobs this worker ran.
    def run(drain: false)
      @log = Thread::Queue.new
      logger = Thread.new { while (line = @log.pop); @out.puts(line); @out.flush; end }
      @queue.recover.each { |id| log("recovered #{id} from a worker that is gone") }
      log("worker #{Process.pid} started with #{@threads} threads#{" (drain)" if drain} on #{@queue.root}")
      pool = Array.new(@threads) { |i| Thread.new { work("#{Process.pid}/t#{i + 1}", drain) } }
      pool.each(&:join)
      log("worker #{Process.pid} stopped: #{@processed} done, #{@failed} failed")
      @log.close
      logger.join
      @processed + @failed
    end

    private

    def work(name, drain)
      until @stopping
        job = @lock.synchronize do
          @queue.claim.tap { |claimed| @busy += 1 if claimed }
        end
        if job
          perform(job, name)
          @lock.synchronize { @busy -= 1 }
        elsif drain && idle?
          break
        else
          sleep(@poll)
        end
      end
    end

    # Pending is empty and no thread here is running a job that might be retried.
    def idle? = @lock.synchronize { @busy.zero? && @queue.counts["pending"].zero? }

    def perform(job, name)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = @runner.run(job)
      @queue.complete(job, result, worker: name)
      @lock.synchronize { @processed += 1 }
      log("#{name} done #{job.type} #{job.id} -> #{JSON.generate(result)} (#{elapsed(started)})")
    rescue StandardError => e
      state = @queue.fail(job, "#{e.class}: #{e.message}", worker: name, retryable: !e.is_a?(PermanentError))
      @lock.synchronize { @failed += 1 } if state == "failed"
      verb = state == "pending" ? "will retry" : "failed"
      log("#{name} #{verb} #{job.type} #{job.id}: #{e.message} (attempt #{job.attempts + 1} of #{job.data["max_attempts"]})")
    end

    def elapsed(started) = format("%.0fms", (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000)

    def log(line) = @log << line
  end
end
