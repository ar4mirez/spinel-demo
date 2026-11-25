# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "../lib/job_worker"

# Every test gets a fresh queue directory under this example's tmp/, never
# anywhere outside the example, and removes it afterwards.
module QueueDir
  TMP = File.join(JobWorker::ROOT, "tmp")

  def setup
    FileUtils.mkdir_p(TMP)
    @dir = Dir.mktmpdir("test-", TMP)
    @queue = JobWorker::Queue.new(@dir)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end
end
