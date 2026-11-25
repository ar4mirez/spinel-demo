# sinatra-sqlite

A todo list with full CRUD over SQLite, written with Sinatra and served by Puma 8 on Spinel. Todos persist in `tmp/todos.db`, a SQLite database file, through the `sqlite3` gem's API. Spinel does not build C extensions, so `sqlite3`, `puma` and `nio4r` come from Spinel's own substitutes, `sqlite3-spinel`, `puma-spinel` and `nio4r-spinel`, installed from a gem source this example builds and serves itself.

It shows:

- `sqlite3-spinel` standing in for `sqlite3 2.10.2`: `SQLite3::Database` with bound parameters, `results_as_hash`, `transaction`, `last_insert_row_id`, `changes`, `get_first_row` and `get_first_value`, a `CHECK` and a `NOT NULL` constraint, and SQLite 3.54.1 compiled into the gem.
- A JSON API (`/todos`) and an HTML page (`/`) whose forms use the same routes, with `Rack::MethodOverride` for `PATCH` and `DELETE`.
- Request validation with JSON error bodies (400, 404, 415, 422).
- Data that survives a restart: the smoke script stops Puma, starts it again and reads the todos back.
- A Minitest suite that drives every route in-process over an in-memory database, run with `spinel test`.

## Prerequisites

- Spinel 0.1.0 on your `PATH` (see the [top-level README](../../README.md#install-spinel)).
- `curl`, for the smoke script.
- `git` and a Rust toolchain (`cargo`): the three substitutes are not on rubygems.org yet, so `bin/setup-gems` builds them from Spinel's source. The first build takes a few minutes; set `CARGO_BUILD_JOBS` to limit cargo's parallel jobs.

## Layout

```
config.ru            opens tmp/todos.db and runs Todos::App (Puma reads it)
lib/todos/store.rb   Todos::Store: the todos table, over SQLite3::Database
lib/todos/app.rb     Todos::App: the Sinatra routes, validation and the HTML page
test/app_test.rb     Minitest, through Rack::MockRequest, over ":memory:"
bin/setup-gems       builds the three substitutes and the gem source in tmp/
bin/gem-source       serves tmp/gem-source on http://127.0.0.1:9331
gem-source/          the gem source's builder and server (as in ../rack-puma)
```

## Run it

Build the gem source and serve it:

```sh
cd examples/sinatra-sqlite
bin/setup-gems            # clones Spinel at v0.1.0, builds the three gems, writes tmp/gem-source/
bin/gem-source            # serves tmp/gem-source on http://127.0.0.1:9331 (leave it running)
```

In another terminal, in `examples/sinatra-sqlite`, install the gems with the substitutes switched on:

```sh
SPINEL_SUBSTITUTES=sqlite3,puma,nio4r spinel install   # + sqlite3 2.10.2-x86_64-linux-gnu, + puma 8.1.2, ...
cat .spinel/substitutions.json                         # sqlite3-spinel 2.10.2.1 stands in for sqlite3 2.10.2
```

The gem source is needed only while installing, so you can stop `bin/gem-source` now. Run the tests, then serve the app:

```sh
spinel test test/app_test.rb                                    # 6 tests, 0 failures, 0 errors, 0 skips
spinel run .spinel/gem_home/bin/puma -b tcp://127.0.0.1:9330
```

Open <http://127.0.0.1:9330/> for the HTML page, or use the API:

```sh
curl http://127.0.0.1:9330/health          # {"status":"ok","engine":"spinel","version":"0.1.0","sqlite":"3.54.1","todos":0}
curl -H 'Content-Type: application/json' -d '{"title":"buy milk"}' http://127.0.0.1:9330/todos
curl http://127.0.0.1:9330/todos           # {"data":[{"id":1,"title":"buy milk","done":false,"created_at":"..."}]}
curl -X PATCH -H 'Content-Type: application/json' -d '{"done":true}' http://127.0.0.1:9330/todos/1
curl 'http://127.0.0.1:9330/todos?done=true'
curl -X DELETE http://127.0.0.1:9330/todos/1
```

| Route | Does |
| --- | --- |
| `GET /` | the HTML page: every todo, with forms to add, finish and delete |
| `GET /health` | engine, Spinel version, SQLite version and the number of todos |
| `GET /todos` | every todo; `?done=true` or `?done=false` filters |
| `POST /todos` | creates a todo from `{"title": ..., "done": ...}` (201 and `Location`), or from a form (303 to `/`) |
| `GET /todos/:id` | one todo, or 404 |
| `PATCH /todos/:id` | changes `title` and/or `done` |
| `DELETE /todos/:id` | deletes it (204) |

Errors are JSON, `{"error":{"message":...,"details":{...}}}`: 400 for a body that is not a JSON object, 415 for a body that is neither JSON nor a form, 422 naming each bad or unknown field, 404 for a missing todo or route.

The database is `tmp/todos.db` in this directory (`tmp/` is ignored by git). Delete it to start over.

## Smoke check

```sh
./smoke            # or, from the repository root: bin/smoke sinatra-sqlite
```

It runs `bin/setup-gems` first if `tmp/gem-source/` is missing, installs the gems, runs `spinel test`, deletes `tmp/todos.db`, starts Puma and checks every route, then restarts Puma and checks that the todos are still there. It uses ports 9330 and 9331 on 127.0.0.1, and stops both servers before it exits.

## Known issues (spinel 0.1.0)

This example hits no Spinel gap of its own; `sqlite3-spinel` covered everything it uses. It has the same two install issues as [rack-puma](../rack-puma/README.md#known-issues-spinel-010), both fixed upstream after 0.1.0:

- `spinel install --frozen` rejects the `Gemfile.lock` that `spinel install` wrote, because `sqlite3`, `puma` and `nio4r` come from a `source "..." do` block ([ar4mirez/spinel#894](https://github.com/ar4mirez/spinel/issues/894)). So `./smoke` runs plain `spinel install` and then checks that the lockfile did not change.
- `spinel run -S puma` does not find the project's `.spinel/gem_home/bin/puma` ([ar4mirez/spinel#896](https://github.com/ar4mirez/spinel/issues/896)), so run the stub by its path, as above.

What `sqlite3-spinel` 2.10.2.1 does not have yet (none of it is used here): anything that calls back into Ruby from inside SQLite (`create_function`, `create_aggregate`, `collation`, `trace`, a busy handler block, an authorizer, `statement_timeout=`) raises `NotImplementedError`, and `SQLite3::Backup`, `serialize` and `deserialize` are missing. See Spinel's `docs/package-manager.md`, section 6.
