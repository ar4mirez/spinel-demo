# quickstart

The quick start from the [Spinel README](https://github.com/ar4mirez/spinel), followed as a new user: a Sinatra app on WEBrick, a Minitest test, and the `spinel` commands you meet first.

| What | Shows |
| --- | --- |
| `app.rb` | Sinatra 4 on WEBrick, run by `spinel run` |
| `test/hello_test.rb` | `spinel test`, running Minitest on parallel workers |
| `spinel x rake --version` | running a gem's executable without adding it to the project |
| `spinel build --compile` | building one self-contained executable |
| `spinel -e` | one-line scripts |

## Prerequisites

Spinel 0.1.0 on your `PATH` (see the [top-level README](../../README.md#install-spinel)), and `curl` for the smoke script.

## Run it

```sh
cd examples/quickstart
spinel install --frozen                # the gems in Gemfile.lock, into .spinel/gem_home/

spinel run app.rb                      # serves on http://localhost:4567
curl http://localhost:4567/            # Hello from spinel 0.1.0

spinel test                            # test/*_test.rb on parallel workers
spinel x rake --version                # a gem's executable, outside the project
spinel build --compile app.rb -o hello # one self-contained executable
./hello                                # the same server, from the executable
spinel -e 'puts RUBY_VERSION'          # 4.0.0
```

## Smoke check

```sh
./smoke            # or, from the repository root: bin/smoke quickstart
```

It runs every step above, checks the output, and stops the servers it starts. It uses port 4567.
