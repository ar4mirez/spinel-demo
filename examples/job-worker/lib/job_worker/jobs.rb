# frozen_string_literal: true

module JobWorker
  # Raised for a job that can never succeed, so it goes straight to failed/
  # instead of being retried.
  class PermanentError < StandardError; end

  # The job types a worker knows how to run. Each handler gets the job's args
  # (an array of JSON values) and the job itself, and returns a JSON value: the
  # job's result. Raising an error fails the job.
  module Jobs
    HANDLERS = {
      # square N: N * N
      "square" => ->(args, _job) { integer(args, 0) ** 2 },
      # fib N: the Nth Fibonacci number, computed iteratively
      "fib" => lambda do |args, _job|
        n = integer(args, 0)
        raise PermanentError, "fib needs 0 <= N <= 1000, got #{n}" unless (0..1000).cover?(n)

        a, b = 0, 1
        n.times { a, b = b, a + b }
        a
      end,
      # wordcount TEXT...: the number of words and the most common one
      "wordcount" => lambda do |args, _job|
        words = args.join(" ").downcase.scan(/[[:alnum:]']+/)
        top = words.tally.max_by { |word, count| [count, word] }
        { "words" => words.length, "top" => top&.first }
      end,
      # sleep MS: waits MS milliseconds (a stand-in for slow I/O)
      "sleep" => lambda do |args, _job|
        ms = integer(args, 0)
        raise PermanentError, "sleep needs 0 <= MS <= 60000, got #{ms}" unless (0..60_000).cover?(ms)

        sleep(ms / 1000.0)
        ms
      end,
      # flaky: fails on its first attempt and succeeds on the next one
      "flaky" => lambda do |_args, job|
        raise "flaky job failed on attempt #{job.attempts + 1}" if job.attempts.zero?

        "ok on attempt #{job.attempts + 1}"
      end,
      # boom: always fails, so it uses up its attempts and lands in failed/
      "boom" => ->(_args, _job) { raise "boom" }
    }.freeze

    def self.types = HANDLERS.keys

    def self.run(job)
      handler = HANDLERS.fetch(job.type) { raise PermanentError, "unknown job type: #{job.type}" }
      handler.call(job.args, job)
    end

    def self.integer(args, index)
      value = args[index]
      return value if value.is_a?(Integer)
      return Integer(value, 10) if value.is_a?(String) && value.match?(/\A-?\d+\z/)

      raise PermanentError, "argument #{index + 1} must be an integer, got #{value.inspect}"
    end
  end
end
