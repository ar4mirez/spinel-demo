require "minitest/autorun"
class HelloTest < Minitest::Test
  def test_engine = assert_equal "spinel", RUBY_ENGINE
end
