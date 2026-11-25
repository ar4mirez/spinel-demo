# frozen_string_literal: true

require "json"

module Todo
  # A task list kept in a JSON file.
  class Store
    PRIORITIES = %w[high normal low].freeze

    Task = Struct.new(:id, :text, :priority, :done) do
      def to_h = {id:, text:, priority:, done:}
    end

    attr_reader :path

    def initialize(path)
      @path = path
      @tasks = File.exist?(path) ? load : []
    end

    def tasks(all: false) = all ? @tasks : @tasks.reject(&:done)

    def add(text, priority: "normal")
      task = Task.new(next_id, text, priority, false)
      @tasks << task
      task
    end

    def find(id) = @tasks.find { |task| task.id == id }

    def complete(id)
      task = find(id) or return
      task.done = true
      task
    end

    def remove(id)
      task = find(id) or return
      @tasks.delete(task)
    end

    def save
      File.write(path, JSON.pretty_generate({tasks: @tasks.map(&:to_h)}) + "\n")
    end

    private

    def next_id = (@tasks.map(&:id).max || 0) + 1

    def load
      JSON.parse(File.read(path)).fetch("tasks").map do |t|
        Task.new(t.fetch("id"), t.fetch("text"), t.fetch("priority"), t.fetch("done"))
      end
    end
  end
end
