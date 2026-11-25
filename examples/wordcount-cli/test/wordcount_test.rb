# frozen_string_literal: true

require "minitest/autorun"
require "json"
require_relative "../lib/wordcount"

class WordcountTest < Minitest::Test
  TEXT = "The cat and the hat. The cat sat; a cat's hat!"

  def test_counts_and_ranks_words
    result = Wordcount.count(TEXT, top: 3)
    assert_equal 11, result.total
    assert_equal 7, result.unique
    assert_equal [["the", 3], ["cat", 2], ["hat", 2]], result.top
  end

  def test_min_length_and_ignore
    result = Wordcount.count(TEXT, min_length: 3, ignore: ["THE"])
    assert_equal [["cat", 2], ["hat", 2], ["and", 1], ["cat's", 1], ["sat", 1]], result.top
  end

  def test_json_output
    data = JSON.parse(Wordcount.format_json(Wordcount.count("b a b", top: 1)))
    assert_equal({"total" => 3, "unique" => 2, "top" => [{"word" => "b", "count" => 2}]}, data)
  end

  def test_table_output
    assert_equal "  1. b      2\n  2. a      1\n3 words, 2 unique",
                 Wordcount.format_table(Wordcount.count("b a b"))
  end
end
