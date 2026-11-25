# frozen_string_literal: true

module JsonApi
  # An in-memory table of records keyed by integer id. WEBrick serves each
  # request on its own thread, so every read and write takes the lock.
  class Store
    def initialize
      @records = {}
      @next_id = 1
      @lock = Mutex.new
    end

    def all = @lock.synchronize { @records.values }
    def find(id) = @lock.synchronize { @records[id] }

    def create(attrs)
      @lock.synchronize do
        record = { "id" => @next_id }.merge(attrs)
        @records[@next_id] = record
        @next_id += 1
        record
      end
    end

    def update(id, attrs)
      @lock.synchronize do
        return nil unless @records.key?(id)
        @records[id] = @records[id].merge(attrs)
      end
    end

    def delete(id) = @lock.synchronize { @records.delete(id) }
  end
end
