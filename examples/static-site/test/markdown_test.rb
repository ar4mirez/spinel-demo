# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/static_site/markdown"

class MarkdownTest < Minitest::Test
  def md(text) = StaticSite::Markdown.to_html(text)

  def test_headings_get_ids
    assert_equal %(<h1 id="hello-world">Hello, world</h1>\n<h3 id="three">Three</h3>), md("# Hello, world\n\n### Three ###")
  end

  def test_heading_keeps_a_trailing_hash_that_is_part_of_the_text
    assert_equal %(<h1 id="c">C#</h1>\n<h2 id="f">F# ##</h2>), md("# C#\n## F# ## ##")
  end

  def test_lines_starting_with_hash_that_are_not_headings_are_paragraphs
    assert_equal "<p>#hashtag</p>", md("#hashtag")
    assert_equal "<p>text\n#tag</p>", md("text\n#tag")
    assert_equal "<p>#1 priority\n#\n####### seven</p>", md("#1 priority\n#\n####### seven")
    assert_equal %(<p>text</p>\n<h2 id="next">Next</h2>), md("text\n## Next")
  end

  def test_paragraphs_and_inline_formatting
    assert_equal "<p>One <em>two</em> <strong>three</strong>\n<code>a*b*c</code> <a href=\"https://x.test\">four</a></p>\n<p>Next</p>",
                 md("One *two* **three**\n`a*b*c` [four](https://x.test)\n\nNext")
  end

  def test_escapes_html
    assert_equal "<p>&lt;b&gt; &amp; <code>&lt;i&gt;</code></p>", md("<b> & `<i>`")
  end

  def test_lists
    assert_equal "<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n<ol>\n<li>one</li>\n<li>two</li>\n</ol>", md("- a\n* b\n\n1. one\n2) two")
  end

  def test_code_block_keeps_text_as_is
    assert_equal %(<pre><code class="language-ruby">x = 1 * 2 *3\n\n&lt;tag&gt;</code></pre>\n<p>after</p>),
                 md("```ruby\nx = 1 * 2 *3\n\n<tag>\n```\nafter")
  end

  def test_blockquote_and_rule
    assert_equal "<blockquote>\n<p>quoted\ntext</p>\n</blockquote>\n<hr>", md("> quoted\n> text\n\n---")
  end
end
