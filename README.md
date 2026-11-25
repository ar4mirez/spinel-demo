# spinel-demo

A collection of small apps and use cases that show [Spinel](https://github.com/ar4mirez/spinel) at work. Each example lives in its own directory under `examples/`, has its own README and gems, and has a smoke script that CI runs on every push and pull request.

## What Spinel is

Spinel is a Ruby engine and toolchain built from scratch, in one binary. The same `spinel` runs Ruby programs on its own VM (`RUBY_ENGINE` is `"spinel"`, `RUBY_VERSION` is 4.0.0), installs gems from a `Gemfile` (`spinel install`), runs tests (`spinel test`), runs gem executables (`spinel x`) and packs a project into one executable (`spinel build`). The examples here use it the way a new user would, following its README.

## Install Spinel

Spinel is pinned to 0.1.0 in `mise.toml`, and every example uses that version:

```sh
git clone https://github.com/ar4mirez/spinel-demo && cd spinel-demo
mise install              # installs github:ar4mirez/spinel@0.1.0
spinel --version          # spinel 0.1.0 (ruby 4.0.0) [x86_64-linux]
```

[mise](https://mise.jdx.dev) is the easiest way, but any way of putting `spinel` 0.1.0 on your `PATH` works. `mise use github:ar4mirez/spinel@0.1.0` is what wrote `mise.toml`. A pinned version is needed for now: `mise use github:ar4mirez/spinel` (latest) fails for the first 24 hours after a release, because mise does not install a release younger than its `minimum_release_age`.

The smoke scripts also need `curl`.

## Examples

| Example | What it shows | Needs |
| --- | --- | --- |
| [quickstart](examples/quickstart/) | The Spinel README's quick start: Sinatra on WEBrick, `spinel test`, `spinel x`, `spinel build --compile`, `spinel -e` | |
| [wordcount-cli](examples/wordcount-cli/) | A command-line tool with `OptionParser`, table and JSON output, and Minitest tests | |
| [test-suite](examples/test-suite/) | A small library tested twice, with Minitest and with RSpec, sharing a YAML fixture: `spinel test` for both suites, one suite, `FILE:LINE`, JUnit output, failures, and `spinel x rspec` | |
| [optparse-cli](examples/optparse-cli/) | A fuller CLI on `OptionParser`: subcommands, global and per-command flags, `--help` output, exit codes, and a single executable from `spinel build` | |
| [json-api](examples/json-api/) | A JSON API on Sinatra and WEBrick: two resources, request validation, JSON error responses, `JSON` parsing and generation, and a `Net::HTTP` client | |
| [rack-puma](examples/rack-puma/) | A Rack JSON app served by Puma, using Spinel's `puma-spinel` and `nio4r-spinel` substitutes from a local gem source | `git`, Rust (`cargo`) |
| [rack-middleware](examples/rack-middleware/) | Custom Rack middleware (request id, request logging, timing headers, bearer-token auth) stacked in `config.ru` in front of a small app, served by Puma, with Minitest tests | `git`, Rust (`cargo`) |

Run one example by following its README, or check them with the smoke scripts:

```sh
bin/smoke                          # every example
bin/smoke quickstart wordcount-cli # only these
bin/smoke --list                   # the example names
```

Each smoke script starts the servers it needs and stops them before it exits.

## Adding an example

Every example follows the same layout, so `bin/smoke` and CI pick it up without changes:

```
examples/<name>/
  README.md      what it shows, prerequisites, how to run it with Spinel, known Spinel issues
  smoke          executable; runs the example and checks its output, exits non-zero on failure
  Gemfile        if it uses gems, with the Gemfile.lock that `spinel install` wrote
  Gemfile.lock
  ...            the example's own code
```

- Name the directory in lowercase with dashes (`json-api`, `sinatra-sqlite`). The name is what `bin/smoke NAME` and the CI job use.
- Keep the example self-contained: it must run from its own directory, with its own gems, and must not depend on another example.
- Start `smoke` with `set -euo pipefail`, `cd "$(dirname "$0")"` and `. ../../lib/smoke.sh`. That checks the pinned Spinel version and gives you `step`, `expect`, `fail`, `wait_for` and `start_server`/`stop_server` (any server still running is stopped on exit). See [quickstart/smoke](examples/quickstart/smoke) for a short one.
- Write scratch output to the example's `tmp/` and gems to its `.spinel/`; both are ignored by git.
- Pick ports no other example uses: quickstart uses 4567, json-api uses 4580, rack-puma uses 9292 and 9293, rack-middleware uses 9310 and 9311.
- Do not add a `.ruby-version` (see Troubleshooting).
- Add a row to the table above.
- If the example hits a gap in Spinel, describe it under "Known issues" in its README and report it on [ar4mirez/spinel](https://github.com/ar4mirez/spinel/issues).

CI (`.github/workflows/ci.yml`) installs Spinel from `mise.toml` and runs `bin/smoke <name>` for every directory `bin/smoke --list` finds, one job per example.

## Troubleshooting

### `mise install` fails with `no precompiled ruby found for core:ruby@spinel-...`

`spinel init` 0.1.0 writes a `.ruby-version` file containing `spinel-0.1.0`. mise (when `idiomatic_version_file_enable_tools` includes `ruby`), rbenv, asdf and chruby all read `.ruby-version` as a request for that version of CRuby, which does not exist, so `mise install` fails. Spinel 0.1.0 does not need the file, and this repository has none. If you get this error in your own Spinel project, delete `.ruby-version`:

```sh
rm .ruby-version
mise install
```

The upstream fix is tracked in [ar4mirez/spinel#902](https://github.com/ar4mirez/spinel/issues/902).

### Known issues in Spinel 0.1.0

Each example's README lists the Spinel issues it works around:

- [wordcount-cli](examples/wordcount-cli/README.md#known-issues-spinel-010): `spinel FILE --help` (and `-h`, `--version`, `-v`) prints Spinel's output instead of passing the flag on; put `--` first.
- [optparse-cli](examples/optparse-cli/README.md#known-issues-spinel-010): the same `--help` interception ([ar4mirez/spinel#895](https://github.com/ar4mirez/spinel/issues/895)); use `--`, the `help` command, or the `spinel build` executable.
- [test-suite](examples/test-suite/README.md#known-issues-spinel-010): `spinel test DIR` fails with "no such file" ([ar4mirez/spinel#910](https://github.com/ar4mirez/spinel/issues/910)); pass the files (`spinel test spec/*_spec.rb`).
- [rack-puma](examples/rack-puma/README.md#known-issues-spinel-010): `spinel install --frozen` rejects gems from a `source "..." do` block, and `spinel run -S puma` does not find the project's gem stub.
- [rack-middleware](examples/rack-middleware/README.md#known-issues-spinel-010): the same two Puma install issues as rack-puma.
