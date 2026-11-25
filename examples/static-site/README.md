# static-site

A small static site generator on Spinel: `bin/build` turns Markdown and ERB templates into a folder of plain HTML. It uses `ERB` from the standard library for layouts and pages, `YAML` for front matter and site settings, `Date` for post dates, and `File`, `Dir` and `FileUtils` to read the source tree and write the output. The Markdown converter is part of the example, so it needs no gems; Minitest is the only gem, for `spinel test`.

| File | What it does |
| --- | --- |
| [lib/static_site.rb](lib/static_site.rb) | The builder: reads `config.yml`, layouts, pages and posts, renders them with ERB, writes the output and copies assets |
| [lib/static_site/markdown.rb](lib/static_site/markdown.rb) | A small Markdown-to-HTML converter (headings, paragraphs, lists, block quotes, fenced code, `code`, **strong**, *emphasis*, links), escaping HTML |
| [bin/build](bin/build) | `build [SOURCE [OUTPUT]]`: builds `site/` into `tmp/public/` by default; OUTPUT must be inside this example |
| [site/](site/) | The example site |
| [test/](test/) | Minitest tests for the converter and the builder |

## The source layout

```
site/
  config.yml                  site settings, available to templates as site["title"] etc.
  layouts/default.html.erb    the layout every page gets unless its front matter names another
  pages/about.md              Markdown page  -> about.html
  pages/index.html.erb        ERB page       -> index.html (lists the posts)
  posts/2026-11-02-hello-spinel.md           -> posts/hello-spinel.html, dated 2026-11-02
  assets/style.css            copied as is   -> style.css
```

A page or post can start with YAML front matter (`title`, `summary`, `layout`, and anything else you want to use in a template):

```markdown
---
title: Hello, Spinel
summary: The first post, written in Markdown.
---
Spinel runs this generator from one binary.
```

Two sources that would write the same output file (two posts with the same slug, a page and a post, or an asset and a page) stop the build with an error, as does front matter or `config.yml` that is not a YAML mapping of plain values (a timestamp, for example, is refused; write dates as `2026-11-02`).

Templates see `site`, `page`, `posts` (newest first) and, in layouts, `content`, plus the helpers `h` (HTML escape), `link_to`, `url_for` and `format_date`. Links are relative to the page, so the output works from any directory and when opened straight from disk. Each build empties the output directory first, so the builder only accepts an output directory strictly inside this example (`examples/static-site/`). It resolves the path first (`File.expand_path`, then `File.realpath`, so symlinks count where they lead) and refuses `/`, your home directory, the example directory or any of its parents, anywhere outside the example, a dangling symlink, the source directory, a directory holding it, and a directory inside it, before it deletes or writes anything. Use a directory under `tmp/`, which git ignores.

## Prerequisites

Spinel 0.1.0 on your `PATH` (see the [top-level README](../../README.md#install-spinel)).

## Run it

```sh
cd examples/static-site
spinel install --frozen           # Minitest, for spinel test
spinel test                       # 22 tests, 0 failures, 0 errors
spinel run bin/build              # site/ -> tmp/public/
spinel run bin/build site tmp/preview   # or name the source and an output directory under tmp/
```

Then open `tmp/public/index.html` in a browser, or serve the folder with any static file server. `bin/build` starts with `#!/usr/bin/env spinel`, so `bin/build` works too.

## Smoke check

```sh
./smoke            # or, from the repository root: bin/smoke static-site
```

It installs Minitest, runs `spinel test`, builds `site/` into `tmp/public/` over a stale file, checks the files written and their HTML (layout, post order, escaping, dates, Markdown, relative links, copied assets), and checks that a missing source directory, and an output directory that holds the source, fail with a message.

## Known issues (spinel 0.1.0)

None: `ERB` (with `trim_mode: "-"`), `ERB::Util`, `YAML.safe_load` with `Date`, `Date`, `File`, `Dir.glob`, `FileUtils`, `File.realpath`, `File.symlink` and `Dir.mktmpdir` all ran on Spinel 0.1.0 with no workaround.
