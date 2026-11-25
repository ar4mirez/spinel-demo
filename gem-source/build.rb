# frozen_string_literal: true

# Builds a static compact-index gem source (the format rubygems.org serves)
# for Spinel's native gems, so `spinel install` can substitute them for
# upstream gems with C extensions (Spinel docs/package-manager.md, section 6).
#
#   spinel run gem-source/build.rb GEM_DIR OUT_DIR
#
# GEM_DIR holds `<gem>-spinel-<version>.<rev>-<platform>.gem` files built by
# `gems/<gem>-spinel/build.rb` in a Spinel checkout. For each one, OUT_DIR gets
# rubygems.org's `/info` lines for the upstream gem at that version (so the
# lockfile's checksums stay upstream's), an `/info` line for the substitute,
# and the substitute's `.gem` under `gems/`. `/versions` and `/names` list both.

require "digest"
require "fileutils"
require "net/http"
require "rubygems/package"
require "time"

UPSTREAM = ENV.fetch("UPSTREAM_INDEX", "https://rubygems.org")

gem_dir, out_dir = ARGV
abort "usage: spinel run #{$0} GEM_DIR OUT_DIR" unless gem_dir && out_dir

def info_line(spec, checksum)
  deps = spec.runtime_dependencies.sort_by(&:name).map do |dep|
    "#{dep.name}:#{dep.requirement.requirements.map { |op, v| "#{op} #{v}" }.join("&")}"
  end
  version = spec.platform.to_s == "ruby" ? spec.version.to_s : "#{spec.version}-#{spec.platform}"
  meta = ["checksum:#{checksum}"]
  meta << "ruby:#{spec.required_ruby_version}" unless spec.required_ruby_version.none?
  meta << "rubygems:#{spec.required_rubygems_version}" unless spec.required_rubygems_version.none?
  "#{version} #{deps.join(",")}|#{meta.join(",")}"
end

def upstream_info(name, version)
  uri = URI("#{UPSTREAM}/info/#{name}")
  body = Net::HTTP.get_response(uri).tap { |r| r.value }.body
  lines = body.lines(chomp: true).select { |l| l.start_with?("#{version} ", "#{version}-") }
  abort "#{uri} has no line for #{name} #{version}" if lines.empty?
  lines
end

infos = Hash.new { |h, k| h[k] = [] }
FileUtils.mkdir_p(File.join(out_dir, "gems"))
FileUtils.mkdir_p(File.join(out_dir, "info"))

gems = Dir[File.join(gem_dir, "*-spinel-*.gem")].sort
abort "no *-spinel-*.gem files in #{gem_dir}" if gems.empty?
gems.each do |path|
  spec = Gem::Package.new(path).spec
  upstream = spec.name.delete_suffix("-spinel")
  upstream_version = spec.version.segments[0..-2].join(".")
  infos[spec.name] << info_line(spec, Digest::SHA256.file(path).hexdigest)
  infos[upstream].concat(upstream_info(upstream, upstream_version)) if infos[upstream].empty?
  FileUtils.cp(path, File.join(out_dir, "gems", File.basename(path)))
  puts "#{spec.full_name} stands in for #{upstream} #{upstream_version}"
end

versions = ["created_at: #{Time.now.utc.iso8601}", "---"]
infos.sort.each do |name, lines|
  body = "---\n#{lines.uniq.join("\n")}\n"
  File.write(File.join(out_dir, "info", name), body)
  list = lines.uniq.map { |l| l.split(" ", 2).first }.join(",")
  versions << "#{name} #{list} #{Digest::MD5.hexdigest(body)}"
end
File.write(File.join(out_dir, "versions"), "#{versions.join("\n")}\n")
File.write(File.join(out_dir, "names"), "---\n#{infos.keys.sort.join("\n")}\n")
puts "wrote #{out_dir}"
