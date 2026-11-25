# frozen_string_literal: true

require "erb"
require "date"
require "fileutils"
require "yaml"
require_relative "static_site/markdown"

# Builds an HTML site from a source directory:
#
#   site/config.yml           site-wide settings (title, description, ...)
#   site/layouts/*.html.erb   ERB layouts; a page names one in its front matter
#   site/pages/**/*.md        Markdown pages, written to the same path as .html
#   site/pages/**/*.html.erb  ERB pages, which can list the posts
#   site/posts/*.md           dated posts (YYYY-MM-DD-slug.md), written to posts/slug.html
#   site/assets/**/*          copied as is
#
# Each page and post can start with YAML front matter between `---` lines.
module StaticSite
  class Error < StandardError; end

  FRONT_MATTER = /\A---\s*\n(.*?)\n---\s*(?:\n|\z)/m

  # One output page: its front matter, its rendered body, and where it goes.
  Page = Struct.new(:data, :body, :path, keyword_init: true) do
    def title = data.fetch("title", File.basename(path, ".html"))
    def date = data["date"]
    def url = path
    def summary = data["summary"]
  end

  # What a template sees: `site`, `page`, `posts`, `content`, and helpers.
  class Context
    include ERB::Util

    attr_reader :site, :page, :posts, :content

    def initialize(site:, page:, posts:, content: nil)
      @site = site
      @page = page
      @posts = posts
      @content = content
    end

    def markdown(text) = Markdown.to_html(text)

    def format_date(date) = date.strftime("%B %-d, %Y")

    # A link to `path` (relative to the site root) from the current page, so
    # the site works from any directory and from file:// URLs.
    def url_for(path) = ("../" * page.path.count("/")) + path

    def link_to(text, path) = %(<a href="#{h(url_for(path))}">#{h(text)}</a>)

    def render(template) = template.result(binding)
  end

  class Builder
    attr_reader :source, :output

    def initialize(source, output)
      @source = File.expand_path(source)
      @output = File.expand_path(output)
      raise Error, "no such site directory: #{source}" unless File.directory?(@source)
      raise Error, "the output directory must not contain the source" if @source.start_with?("#{@output}/") || @source == @output
    end

    # Writes the whole site into `output` (removing what was there before) and
    # returns the paths it wrote, relative to `output`, sorted.
    def build
      config = load_config
      layouts = load_layouts
      posts = load_posts.sort_by { |p| [p.date, p.path] }.reverse
      pages = load_pages(posts, config)

      FileUtils.rm_rf(output)
      written = (posts + pages).map do |page|
        layout_name = page.data.fetch("layout", "default")
        layout = layouts.fetch(layout_name) { raise Error, "#{page.path}: no layout named #{layout_name}" }
        html = Context.new(site: config, page: page, posts: posts, content: page.body).render(layout)
        write(page.path, html)
      end
      written.concat(copy_assets).sort
    end

    private

    def load_config
      path = File.join(source, "config.yml")
      File.exist?(path) ? YAML.safe_load_file(path) || {} : {}
    end

    def load_layouts
      Dir.glob(File.join(source, "layouts", "*.html.erb")).to_h do |path|
        [File.basename(path, ".html.erb"), template(File.read(path), path)]
      end
    end

    def load_posts
      Dir.glob(File.join(source, "posts", "*.md")).map do |path|
        m = File.basename(path).match(/\A(\d{4}-\d{2}-\d{2})-(.+)\.md\z/) or
          raise Error, "#{relative(path)}: post names look like YYYY-MM-DD-slug.md"
        data, text = front_matter(path)
        data["date"] = Date.parse(m[1]) unless data["date"].is_a?(Date)
        Page.new(data: data, body: Markdown.to_html(text), path: "posts/#{m[2]}.html")
      end
    end

    def load_pages(posts, config)
      dir = File.join(source, "pages")
      Dir.glob(File.join(dir, "**", "*.{md,html.erb}")).sort.map do |path|
        rel = path.delete_prefix("#{dir}/")
        data, text = front_matter(path)
        if rel.end_with?(".md")
          Page.new(data: data, body: Markdown.to_html(text), path: rel.sub(/\.md\z/, ".html"))
        else
          page = Page.new(data: data, body: nil, path: rel.delete_suffix(".erb"))
          page.body = Context.new(site: config, page: page, posts: posts).render(template(text, path))
          page
        end
      end
    end

    def front_matter(path)
      text = File.read(path)
      m = text.match(FRONT_MATTER)
      return [{}, text] unless m

      data = YAML.safe_load(m[1], permitted_classes: [Date]) || {}
      raise Error, "#{relative(path)}: front matter must be a mapping" unless data.is_a?(Hash)

      [data, m.post_match]
    rescue Psych::SyntaxError => e
      raise Error, "#{relative(path)}: bad front matter: #{e.message}"
    end

    def template(text, path)
      erb = ERB.new(text, trim_mode: "-")
      erb.filename = path
      erb
    end

    def copy_assets
      dir = File.join(source, "assets")
      Dir.glob(File.join(dir, "**", "*")).select { |f| File.file?(f) }.map do |path|
        rel = path.delete_prefix("#{dir}/")
        FileUtils.mkdir_p(File.dirname(File.join(output, rel)))
        FileUtils.cp(path, File.join(output, rel))
        rel
      end
    end

    def write(rel, html)
      dest = File.join(output, rel)
      FileUtils.mkdir_p(File.dirname(dest))
      File.write(dest, html)
      rel
    end

    def relative(path) = path.delete_prefix("#{source}/")
  end

  def self.build(source, output) = Builder.new(source, output).build
end
