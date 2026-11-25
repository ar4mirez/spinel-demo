# frozen_string_literal: true

require "erb"

module StaticSite
  # A small Markdown-to-HTML converter: ATX headings, paragraphs, bullet and
  # numbered lists, block quotes, fenced code blocks, horizontal rules, and
  # inline `code`, **strong**, *emphasis* and [links](url). Text is HTML-escaped,
  # so raw HTML in the source shows up as text.
  module Markdown
    module_function

    HEADING = /\A(\#{1,6})\s+(.*?)(?:\s+#+)?\s*\z/

    def to_html(source)
      lines = source.gsub("\r\n", "\n").split("\n", -1)
      html = []
      until lines.empty?
        line = lines.first
        if line.strip.empty?
          lines.shift
        elsif line.start_with?("```")
          html << code_block(lines)
        elsif (m = line.match(HEADING))
          lines.shift
          level = m[1].length
          html << "<h#{level} id=\"#{slug(m[2])}\">#{inline(m[2])}</h#{level}>"
        elsif line.match?(/\A\s*([-*_])(\s*\1){2,}\s*\z/)
          lines.shift
          html << "<hr>"
        elsif line.start_with?(">")
          quoted = take_while(lines) { |l| l.start_with?(">") }.map { |l| l.sub(/\A>\s?/, "") }
          html << "<blockquote>\n#{to_html(quoted.join("\n"))}\n</blockquote>"
        elsif line.match?(/\A[-*+]\s+/)
          html << list(lines, "ul", /\A[-*+]\s+/)
        elsif line.match?(/\A\d+[.)]\s+/)
          html << list(lines, "ol", /\A\d+[.)]\s+/)
        else
          para = take_while(lines) { |l| !l.strip.empty? && !block_start?(l) }
          html << "<p>#{inline(para.map(&:strip).join("\n"))}</p>"
        end
      end
      html.join("\n")
    end

    def inline(text)
      # Pull code spans out first so their contents are not formatted.
      codes = []
      text = text.gsub(/`([^`]+)`/) do
        codes << "<code>#{h(Regexp.last_match(1))}</code>"
        "\u0000#{codes.length - 1}\u0000"
      end
      text = h(text)
      text = text.gsub(/\[([^\]]+)\]\(([^)\s]+)\)/) { %(<a href="#{Regexp.last_match(2)}">#{Regexp.last_match(1)}</a>) }
      text = text.gsub(/\*\*(.+?)\*\*/) { "<strong>#{Regexp.last_match(1)}</strong>" }
      text = text.gsub(/(?<![*\w])\*(?!\s)(.+?)(?<!\s)\*(?![*\w])/) { "<em>#{Regexp.last_match(1)}</em>" }
      text.gsub(/\u0000(\d+)\u0000/) { codes[Regexp.last_match(1).to_i] }
    end

    def slug(text)
      text.downcase.gsub(/`|\*/, "").gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end

    def h(text)
      ERB::Util.html_escape(text)
    end

    def block_start?(line)
      line.start_with?("```", ">") || line.match?(HEADING) || line.match?(/\A([-*+]|\d+[.)])\s+/)
    end

    def take_while(lines)
      taken = []
      taken << lines.shift while !lines.empty? && yield(lines.first)
      taken
    end

    def code_block(lines)
      lang = lines.shift.delete_prefix("```").strip
      body = take_while(lines) { |l| !l.start_with?("```") }
      lines.shift # the closing fence, if there is one
      attr = lang.empty? ? "" : %( class="language-#{h(lang)}")
      "<pre><code#{attr}>#{h(body.join("\n"))}</code></pre>"
    end

    def list(lines, tag, marker)
      items = take_while(lines) { |l| l.match?(marker) }
      "<#{tag}>\n#{items.map { |l| "<li>#{inline(l.sub(marker, ""))}</li>" }.join("\n")}\n</#{tag}>"
    end
  end
end
