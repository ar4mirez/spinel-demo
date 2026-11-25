# frozen_string_literal: true

require "json"

# Counts words in text and reports the most frequent ones.
module Wordcount
  WORD = /[[:alpha:]][[:alpha:]'-]*/

  Result = Struct.new(:total, :unique, :top) do
    def to_h = {total:, unique:, top: top.map { |word, count| {word:, count:} }}
  end

  module_function

  def count(text, top: 10, min_length: 1, ignore: [])
    ignored = ignore.map(&:downcase).to_set
    counts = text.scan(WORD).each_with_object(Hash.new(0)) do |word, tally|
      word = word.downcase
      next if word.length < min_length || ignored.include?(word)

      tally[word] += 1
    end
    ranked = counts.sort_by { |word, n| [-n, word] }
    Result.new(counts.values.sum, counts.size, ranked.first(top))
  end

  def format_table(result)
    width = result.top.map { |word, _| word.length }.max || 4
    lines = result.top.each_with_index.map do |(word, n), i|
      format("%3d. %-*s %6d", i + 1, width, word, n)
    end
    lines << "#{result.total} words, #{result.unique} unique"
    lines.join("\n")
  end

  def format_json(result) = JSON.pretty_generate(result.to_h)
end
