# rack-puma

A small Rack app (`config.ru`, a JSON notes service) served by Puma 8 on Spinel. Puma and nio4r have C extensions, which Spinel does not build, so this example installs Spinel's own `puma-spinel` and `nio4r-spinel` substitutes from a gem source it builds and serves itself.

## Prerequisites

- Spinel 0.1.0 on your `PATH` (see the [top-level README](../../README.md#install-spinel)).
- `curl`, for the smoke script.
- `git` and a Rust toolchain (`cargo`): `puma-spinel` and `nio4r-spinel` are not on rubygems.org yet, so `bin/setup-puma` builds them from Spinel's source.

## How the substitutes get installed

Spinel installs a substitute only when the substitute comes from the same gem source as the locked gem, and only when you opt in with `SPINEL_SUBSTITUTES=puma,nio4r`. So the `Gemfile` takes `puma` and `nio4r` from a gem source on `http://127.0.0.1:9293`:

- `bin/setup-puma` clones Spinel at the tag of the installed `spinel`, builds both gems with their `build.rb`, and runs `gem-source/build.rb`, which writes the source to `tmp/gem-source/`.
- `gem-source/build.rb` writes the compact index format that rubygems.org serves. It takes the upstream `/info` lines for `puma 8.1.2` and `nio4r 2.7.5` from rubygems.org, so `Gemfile.lock` keeps upstream's checksums, and adds lines for the two substitutes and copies their `.gem` files.
- `bin/gem-source` serves `tmp/gem-source/` with WEBrick (`gem-source/serve.rb`). Both scripts run on Spinel.

## Run it

```sh
cd examples/rack-puma
bin/setup-puma            # clones Spinel at v0.1.0, builds both gems, writes tmp/gem-source/
bin/gem-source            # serves tmp/gem-source on http://127.0.0.1:9293 (leave it running)
```

In another terminal, in `examples/rack-puma`:

```sh
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

## Smoke check

```sh
./smoke            # or, from the repository root: bin/smoke rack-puma
```

It runs `bin/setup-puma` first if `tmp/gem-source/` is missing, starts the gem source and Puma, checks every route, and stops both. It uses ports 9292 and 9293.

## Known issues (spinel 0.1.0)

- `spinel install --frozen` rejects the `Gemfile.lock` that `spinel install` wrote, saying `puma from http://127.0.0.1:9293/ to no specified source`. It does this for any gem in a `source "..." do` block. Bundler 4.0.20 accepts the same lockfile with `BUNDLE_FROZEN=true`. So `./smoke` runs plain `spinel install` and then checks that the lockfile did not change.
- `spinel run -S puma` does not find the project's `.spinel/gem_home/bin/puma`, so run the stub by its path, as above.
- Gem stubs have the flag problem described in [wordcount-cli](../wordcount-cli/README.md#known-issues-spinel-010): `.spinel/gem_home/bin/puma --version` prints Spinel's version.
