# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "../lib/static_site"

class BuilderTest < Minitest::Test
  SITE = File.expand_path("../site", __dir__)

  def setup
    @dir = Dir.mktmpdir("static-site")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def out(*parts) = File.join(@dir, "public", *parts)

  def build(source = SITE) = StaticSite.build(source, out)

  def test_builds_the_example_site
    assert_equal %w[about.html index.html posts/erb-templates.html posts/hello-spinel.html style.css], build
    index = File.read(out("index.html"))
    assert_includes index, "<title>Home | Notes from Spinel</title>"
    # Newest post first, linked relative to the page.
    assert_match(%r{posts/erb-templates\.html.*posts/hello-spinel\.html}m, index)
    assert_includes index, "ERB templates &amp; layouts"
    assert_includes index, "<p>2 posts.</p>"
  end

  def test_posts_use_the_layout_and_relative_links
    build
    post = File.read(out("posts", "hello-spinel.html"))
    assert_includes post, %(<link rel="stylesheet" href="../style.css">)
    assert_includes post, %(<time datetime="2026-11-02">November 2, 2026</time>)
    assert_includes post, %(<pre><code class="language-ruby">puts &quot;Hello from)
    assert_equal File.read(File.join(SITE, "assets", "style.css")), File.read(out("style.css"))
  end

  def test_rebuild_removes_stale_files
    FileUtils.mkdir_p(out)
    File.write(out("stale.html"), "old")
    build
    refute File.exist?(out("stale.html"))
  end

  def test_front_matter_layout_and_errors
    src = File.join(@dir, "src")
    FileUtils.mkdir_p([File.join(src, "layouts"), File.join(src, "pages")])
    File.write(File.join(src, "layouts", "bare.html.erb"), "[<%= page.title %>|<%= content %>]")
    File.write(File.join(src, "pages", "x.md"), "---\ntitle: X\nlayout: bare\n---\nhi\n")
    assert_equal ["x.html"], build(src)
    assert_equal "[X|<p>hi</p>]", File.read(out("x.html"))

    File.write(File.join(src, "pages", "x.md"), "---\nlayout: missing\n---\nhi\n")
    assert_raises(StaticSite::Error) { build(src) }
    File.write(File.join(src, "pages", "x.md"), "---\n- a list\n---\nhi\n")
    assert_raises(StaticSite::Error) { build(src) }
    assert_raises(StaticSite::Error) { StaticSite.build(File.join(@dir, "nope"), out) }
    assert_raises(StaticSite::Error) { StaticSite.build(src, @dir) }
  end
end
