# spinel-demo

A demo app built by following the [Spinel](https://github.com/ar4mirez/spinel) README as a new user. It has three parts:

1. **The README's quick start**: a Sinatra app on WEBrick (`app.rb`), a Minitest test, `spinel x`, `spinel build --compile` and `spinel -e`.
2. **A command-line tool**: `bin/wordcount`, which prints the most frequent words in files or standard input (`lib/wordcount.rb`, tested in `test/wordcount_test.rb`).
3. **A Rack app served by Puma** (`puma/config.ru`), using Spinel's `puma-spinel` and `nio4r-spinel` substitutes.

`bin/smoke` runs and checks all three.

## Requirements

- [mise](https://mise.jdx.dev), or any other way to put `spinel` 0.1.0 on your `PATH`.
- `curl`, for `bin/smoke`.
- For the Puma part only: `git` and a Rust toolchain (`cargo`), because `puma-spinel` is not on rubygems.org yet and has to be built from Spinel's source.

## Setup

Spinel is pinned to 0.1.0 in `mise.toml`:

```sh
git clone https://github.com/ar4mirez/spinel-demo && cd spinel-demo
mise install              # installs github:ar4mirez/spinel@0.1.0
spinel --version          # spinel 0.1.0 (ruby 4.0.0) [x86_64-linux]
spinel install --frozen   # the gems in Gemfile.lock, into .spinel/gem_home/
```

`mise use github:ar4mirez/spinel@0.1.0` is what wrote `mise.toml`. A pinned version is needed for now: `mise use github:ar4mirez/spinel` (latest) fails for the first 24 hours after a release, because mise does not install a release younger than its `minimum_release_age`.

## 1. The quick start

```sh
spinel run app.rb                      # serves on http://localhost:4567
curl http://localhost:4567/            # Hello from spinel 0.1.0

spinel test                            # test/*_test.rb on parallel workers
spinel x rake --version                # a gem's executable, outside the project
spinel build --compile app.rb -o hello # one self-contained executable
./hello                                # the same server, from the executable
spinel -e 'puts RUBY_VERSION'          # 4.0.0
```

## 2. The wordcount CLI

```sh
spinel run bin/wordcount README.md                # the ten most frequent words
spinel run bin/wordcount -n 3 -m 4 README.md      # top 3, words of 4 letters or more
echo "the cat and the hat" | spinel run bin/wordcount -f json
spinel run bin/wordcount -i the,and,a README.md   # skip some words
spinel run bin/wordcount -- --help                # its options (see Known issues)
```

`bin/wordcount` starts with `#!/usr/bin/env spinel`, so `bin/wordcount README.md` works too.

## 3. A Rack app on Puma

Puma and nio4r have C extensions, which Spinel does not build. Spinel's own `puma-spinel` and `nio4r-spinel` gems stand in for them, but they are not published to rubygems.org yet. Spinel installs a substitute only when the substitute comes from the same gem source as the locked gem, and only when you opt in with `SPINEL_SUBSTITUTES=puma,nio4r`. So `puma/Gemfile` takes `puma` and `nio4r` from a gem source on `http://127.0.0.1:9293`, which this repository builds and serves:

```sh
bin/setup-puma            # clones Spinel at v0.1.0, builds both gems, writes tmp/gem-source/
bin/gem-source            # serves tmp/gem-source on http://127.0.0.1:9293 (leave it running)
```

In another terminal:

```sh
cd puma
SPINEL_SUBSTITUTES=puma,nio4r spinel install   # + nio4r 2.7.5, + puma 8.1.2
cat .spinel/substitutions.json                 # puma-spinel 8.1.2.1 stands in for puma 8.1.2
```

The gem source is needed only while installing, so you can stop `bin/gem-source` now. Then serve the app:

```sh
spinel run .spinel/gem_home/bin/puma -b tcp://127.0.0.1:9292
curl http://127.0.0.1:9292/                                    # Hello from spinel 0.1.0 on Puma 8.1.2
curl http://127.0.0.1:9292/health                              # {"status":"ok","engine":"spinel",...}
curl -X POST -d '{"text":"buy milk"}' http://127.0.0.1:9292/notes
curl http://127.0.0.1:9292/notes                               # {"notes":["buy milk"]}
```

`gem-source/build.rb` writes the source in the compact index format that rubygems.org serves. It takes the upstream `/info` lines for `puma 8.1.2` and `nio4r 2.7.5` from rubygems.org, so `Gemfile.lock` keeps upstream's checksums. It adds lines for the two substitutes and copies their `.gem` files. `gem-source/serve.rb` serves it with WEBrick. Both run on Spinel.

## Smoke check

```sh
bin/smoke                 # everything; runs bin/setup-puma first if tmp/gem-source is missing
SKIP_PUMA=1 bin/smoke     # parts 1 and 2 only: no git or Rust needed
```

It starts every server it needs and stops each one before it exits.

## Known issues (spinel 0.1.0)

- `spinel install --frozen` rejects `puma/Gemfile.lock`, which `spinel install` wrote, saying `puma from http://127.0.0.1:9293/ to no specified source`. It does this for any gem in a `source "..." do` block. Bundler 4.0.20 accepts the same lockfile with `BUNDLE_FROZEN=true`. So `bin/smoke` runs plain `spinel install` in `puma/` and then checks that the lockfile did not change.
- `spinel FILE --help`, `-h`, `--version` and `-v` print Spinel's help or version instead of passing the flag to the program, and so does `spinel run FILE --help`. This also breaks a `#!/usr/bin/env spinel` script and gem stubs: `bin/wordcount --help` and `.spinel/gem_home/bin/puma --version` print Spinel's own output. Put `--` before the flag (`spinel run bin/wordcount -- --help`), or put another argument first.
- `spinel run -S puma` does not find the project's `.spinel/gem_home/bin/puma`, so run the stub by its path, as above.

## Troubleshooting

### `mise install` fails with `no precompiled ruby found for core:ruby@spinel-...`

`spinel init` 0.1.0 writes a `.ruby-version` file containing `spinel-0.1.0`. mise (when `idiomatic_version_file_enable_tools` includes `ruby`), rbenv, asdf and chruby all read `.ruby-version` as a request for that version of CRuby, which does not exist, so `mise install` fails. Spinel 0.1.0 does not need the file, and this repository no longer has one. If you get this error in your own Spinel project, delete `.ruby-version`:

```sh
rm .ruby-version
mise install
```

The upstream fix is tracked in [ar4mirez/spinel#902](https://github.com/ar4mirez/spinel/issues/902).
