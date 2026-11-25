# frozen_string_literal: true

require "json"
require "fileutils"

module JobWorker
  # A job queue kept in a directory, one JSON file per job:
  #
  #   ROOT/pending/ID.json        waiting to run, oldest ID first
  #   ROOT/running/ID.PID.json    claimed by the worker process PID
  #   ROOT/done/ID.json           finished, with its result
  #   ROOT/failed/ID.json         gave up, with the last error
  #   ROOT/incoming/              files being written, renamed into place when complete
  #
  # Every move between states is a File.rename, which is atomic on one file
  # system: when several workers race for the same pending job, exactly one
  # rename succeeds and the others get Errno::ENOENT and try the next job. So
  # any number of worker processes, each with any number of threads, can share
  # one queue directory without a lock file or a database.
  #
  # The queue only ever creates, renames and deletes its own job files under
  # ROOT; it never removes a directory.
  class Queue
    STATES = %w[pending running done failed].freeze
    RUNNING = /\A(?<id>[^.]+)\.(?<pid>\d+)\.json\z/
    DEFAULT_ATTEMPTS = 3

    # A job's attributes, the path of its file, and its state directory.
    Job = Struct.new(:data, :path, :state) do
      def id = data["id"]
      def type = data["type"]
      def args = data["args"]
      def attempts = data["attempts"]
    end

    attr_reader :root

    def initialize(root)
      @root = File.expand_path(root)
      @seq = 0
      @lock = Mutex.new
      (STATES + ["incoming"]).each { |dir| FileUtils.mkdir_p(File.join(@root, dir)) }
    end

    # Adds a job and returns its id. Ids sort in the order jobs were enqueued.
    def enqueue(type, args = [], max_attempts: DEFAULT_ATTEMPTS)
      raise ArgumentError, "job type must be a non-empty string" unless type.is_a?(String) && !type.empty?
      raise ArgumentError, "max_attempts must be at least 1" unless max_attempts.is_a?(Integer) && max_attempts >= 1

      id = next_id
      write("pending", "#{id}.json", {
        "id" => id, "type" => type, "args" => Array(args), "attempts" => 0,
        "max_attempts" => max_attempts, "enqueued_at" => now
      })
      id
    end

    # Claims the oldest pending job for process +pid+, or returns nil when
    # nothing is pending.
    def claim(pid = Process.pid)
      names("pending").each do |name|
        from = path("pending", name)
        to = path("running", "#{File.basename(name, ".json")}.#{pid}.json")
        begin
          File.rename(from, to)
        rescue Errno::ENOENT
          next # another worker claimed it first
        end
        return Job.new(JSON.parse(File.read(to)), to, "running")
      end
      nil
    end

    # Records a claimed job's result and moves it to done/.
    def complete(job, result, worker: nil)
      finish(job, "done", job.data.merge("result" => result, "worker" => worker, "finished_at" => now))
    end

    # Records a claimed job's error. The job goes back to pending/ while it has
    # attempts left, unless +retryable+ is false, and to failed/ otherwise.
    # Returns the state it went to.
    def fail(job, error, worker: nil, retryable: true)
      data = job.data.merge("attempts" => job.attempts + 1, "error" => error, "worker" => worker, "finished_at" => now)
      state = retryable && data["attempts"] < data["max_attempts"] ? "pending" : "failed"
      finish(job, state, data)
      state
    end

    # Puts jobs claimed by processes that no longer exist back in pending/, so
    # a worker that was killed mid-job does not lose it. Returns their ids.
    def recover
      names("running").filter_map do |name|
        m = RUNNING.match(name) or next
        next if alive?(m[:pid].to_i)

        begin
          File.rename(path("running", name), path("pending", "#{m[:id]}.json"))
          m[:id]
        rescue Errno::ENOENT
          nil # its worker finished it, or another worker recovered it
        end
      end
    end

    # The number of jobs in each state.
    def counts = STATES.to_h { |state| [state, names(state).length] }

    # The jobs in +state+, oldest first.
    def jobs(state)
      raise ArgumentError, "unknown state: #{state}" unless STATES.include?(state)

      names(state).filter_map do |name|
        file = path(state, name)
        Job.new(JSON.parse(File.read(file)), file, state)
      rescue Errno::ENOENT
        nil # moved while we listed it
      end
    end

    private

    def finish(job, state, data)
      write(state, "#{job.id}.json", data)
      File.delete(job.path)
    end

    # Writes the file under incoming/ first, then renames it into place, so a
    # reader never sees a half-written job.
    def write(state, name, data)
      tmp = path("incoming", "#{name}.#{Process.pid}.#{Thread.current.object_id}")
      File.write(tmp, JSON.generate(data))
      File.rename(tmp, path(state, name))
    end

    def next_id
      seq = @lock.synchronize { @seq += 1 }
      format("%s-%d-%06d", Time.now.utc.strftime("%Y%m%d%H%M%S%6N"), Process.pid, seq)
    end

    def names(state) = Dir.children(File.join(@root, state)).select { |n| n.end_with?(".json") }.sort

    def path(state, name) = File.join(@root, state, name)

    def now = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%3NZ")

    def alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true # it exists but belongs to someone else
    end
  end
end
