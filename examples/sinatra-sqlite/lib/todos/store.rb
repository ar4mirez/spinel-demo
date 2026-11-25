# frozen_string_literal: true

require "sqlite3"

module Todos
  # Todos in a SQLite database, through the sqlite3 gem's API (on Spinel,
  # sqlite3-spinel provides it). Rows come back as Hashes with string keys.
  class Store
    SCHEMA = <<~SQL
      CREATE TABLE IF NOT EXISTS todos (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        title      TEXT    NOT NULL,
        done       INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0, 1)),
        created_at TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
      )
    SQL
    COLUMNS = "id, title, done, created_at"

    attr_reader :path

    # PATH is a database file, created if missing, or ":memory:".
    def initialize(path)
      @path = path
      @db = SQLite3::Database.new(path, results_as_hash: true)
      @db.busy_timeout = 1000
      @db.execute(SCHEMA)
      @lock = Mutex.new
    end

    def all(done: nil)
      sql = "SELECT #{COLUMNS} FROM todos"
      args = []
      unless done.nil?
        sql += " WHERE done = ?"
        args << (done ? 1 : 0)
      end
      sync { @db.execute("#{sql} ORDER BY id", args).map { |row| present(row) } }
    end

    def find(id)
      sync { find_unlocked(id) }
    end

    def create(title:, done: false)
      sync do
        @db.transaction do
          @db.execute("INSERT INTO todos (title, done) VALUES (?, ?)", [title, done ? 1 : 0])
          find_unlocked(@db.last_insert_row_id)
        end
      end
    end

    # Changes the given attributes (title:, done:); nil if there is no such todo.
    def update(id, attrs)
      sets = []
      args = []
      if attrs.key?(:title)
        sets << "title = ?"
        args << attrs[:title]
      end
      if attrs.key?(:done)
        sets << "done = ?"
        args << (attrs[:done] ? 1 : 0)
      end
      sync do
        @db.transaction do
          @db.execute("UPDATE todos SET #{sets.join(", ")} WHERE id = ?", args + [id]) unless sets.empty?
          find_unlocked(id)
        end
      end
    end

    # True if a todo was deleted.
    def delete(id)
      sync do
        @db.execute("DELETE FROM todos WHERE id = ?", [id])
        @db.changes == 1
      end
    end

    def count = sync { @db.get_first_value("SELECT count(*) FROM todos") }

    def sqlite_version = SQLite3::SQLITE_VERSION

    def close = sync { @db.close }

    private

    # One connection serves every Puma thread, one statement at a time.
    def sync(&) = @lock.synchronize(&)

    def find_unlocked(id)
      row = @db.get_first_row("SELECT #{COLUMNS} FROM todos WHERE id = ?", [id])
      row && present(row)
    end

    def present(row)
      { "id" => row["id"], "title" => row["title"], "done" => row["done"] == 1, "created_at" => row["created_at"] }
    end
  end
end
