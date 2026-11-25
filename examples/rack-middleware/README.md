# rack-middleware

Four custom Rack middleware, written from scratch and stacked with `use` in `config.ru` in front of a small app, served by Puma 8 on Spinel:

| Middleware | File | What it does |
| --- | --- | --- |
| `RequestId` | [lib/middleware/request_id.rb](lib/middleware/request_id.rb) | Keeps the client's `X-Request-Id` (or makes one with `SecureRandom`), puts it in `env["app.request_id"]` and returns it in `x-request-id` |
| `RequestLogger` | [lib/middleware/request_logger.rb](lib/middleware/request_logger.rb) | Writes `GET /whoami 200 0.62ms id=abc` per request to `rack.errors` (Puma's stderr); logs a request that raises as 500 and raises again |
| `Timing` | [lib/middleware/timing.rb](lib/middleware/timing.rb) | Adds `x-runtime` (seconds) and `server-timing` (milliseconds) |
| `TokenAuth` | [lib/middleware/token_auth.rb](lib/middleware/token_auth.rb) | Answers 401 under `/admin` unless the request has `Authorization: Bearer $API_TOKEN`; sets `env["app.user"]` when it does |

Each `use` wraps everything below it, so a request goes down the list in [config.ru](config.ru) and the response comes back up. The app in [lib/app.rb](lib/app.rb) knows nothing about ids, logs, timing or tokens; it only reads what the middleware left in the env. [test/middleware_test.rb](test/middleware_test.rb) tests each middleware on its own and then the whole `config.ru` stack, with `Rack::MockRequest` and no server.

Puma and nio4r have C extensions, which Spinel does not build, so Puma comes from Spinel's `puma-spinel` and `nio4r-spinel` substitutes, installed from a gem source this example builds and serves itself. That part works exactly as in [rack-puma](../rack-puma/README.md#how-the-substitutes-get-installed), on port 9311 instead of 9293.

## Prerequisites

- Spinel 0.1.0 on your `PATH` (see the [top-level README](../../README.md#install-spinel)).
- `curl`, for the smoke script.
- `git` and a Rust toolchain (`cargo`), for `bin/setup-puma`.

## Run it

```sh
cd examples/rack-middleware
bin/setup-puma            # clones Spinel at v0.1.0, builds both gems, writes tmp/gem-source/
bin/gem-source            # serves tmp/gem-source on http://127.0.0.1:9311 (leave it running)
```

In another terminal, in `examples/rack-middleware`:

```sh
SPINEL_SUBSTITUTES=puma,nio4r spinel install   # rack, minitest, and puma-spinel standing in for puma
spinel test                                    # 7 tests, 0 failures, 0 errors
```

Stop `bin/gem-source`, then serve the app:

```sh
API_TOKEN=s3cret spinel run .spinel/gem_home/bin/puma -b tcp://127.0.0.1:9310
```

And try it from a third terminal:

```sh
curl -i http://127.0.0.1:9310/                              # x-request-id, x-runtime, server-timing headers
curl -H 'X-Request-Id: abc' http://127.0.0.1:9310/whoami    # {"request_id":"abc","user":null}
curl -i http://127.0.0.1:9310/admin/stats                   # 401, www-authenticate: Bearer realm="admin"
curl -H 'Authorization: Bearer s3cret' http://127.0.0.1:9310/admin/stats
                                                            # {"user":"admin","hits":4,"engine":"spinel"}
```

Puma's terminal shows one line per request from `RequestLogger`:

```
GET /whoami 200 0.62ms id=abc
GET /admin/stats 401 0.56ms id=e5a617163ec681f9
GET /admin/stats 200 0.82ms id=99595bea3d8389a1
```

`API_TOKEN` defaults to `secret` when it is not set.

## Smoke check

```sh
./smoke            # or, from the repository root: bin/smoke rack-middleware
```

It runs `bin/setup-puma` first if `tmp/gem-source/` is missing, installs the gems, runs `spinel test`, starts Puma, checks the headers, the 401s and the log lines, and stops everything. It uses ports 9310 and 9311.

## Known issues (spinel 0.1.0)

The middleware, `Rack::Builder`, `Rack::MockRequest` and Puma all ran on Spinel 0.1.0 with no workaround. Installing Puma has the same two issues as [rack-puma](../rack-puma/README.md#known-issues-spinel-010), both fixed upstream after 0.1.0:

- `spinel install --frozen` rejects the lockfile that `spinel install` wrote when gems come from a `source "..." do` block ([ar4mirez/spinel#894](https://github.com/ar4mirez/spinel/issues/894)). `./smoke` runs plain `spinel install` and checks that `Gemfile.lock` did not change.
- `spinel run -S puma` does not find `.spinel/gem_home/bin/puma` ([ar4mirez/spinel#896](https://github.com/ar4mirez/spinel/issues/896)), so run the stub by its path, as above.
