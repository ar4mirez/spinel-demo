# frozen_string_literal: true

require_relative "job_worker/queue"
require_relative "job_worker/jobs"
require_relative "job_worker/worker"

module JobWorker
  # This example's directory. The queue lives in its tmp/, which git ignores.
  ROOT = File.expand_path("..", __dir__)
  QUEUE_DIR = File.join(ROOT, "tmp", "queue")

  def self.queue = Queue.new(QUEUE_DIR)
end
