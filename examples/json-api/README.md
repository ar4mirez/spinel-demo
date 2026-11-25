# json-api

A small JSON API for authors and their books, on Sinatra 4 and WEBrick, run by Spinel. It has two resources, validates every request body, answers every error as JSON, and parses and generates JSON with the standard `json` library.

| File | What it does |
| --- | --- |
| [lib/json_api/app.rb](lib/json_api/app.rb) | The routes, body parsing (`JSON.parse`), JSON responses (`JSON.generate`) and error handlers |
| [lib/json_api/validator.rb](lib/json_api/validator.rb) | A small schema check: required fields, types, blank strings, lengths, ranges, unknown fields |
| [lib/json_api/store.rb](lib/json_api/store.rb) | An in-memory, `Mutex`-guarded table per resource (data is lost when the server stops) |
| [app.rb](app.rb) | Serves the app on http://127.0.0.1:4580 (`PORT` overrides the port) |
| [client.rb](client.rb) | A `Net::HTTP` client that creates, reads and deletes records and sends one invalid request |
| [test/api_test.rb](test/api_test.rb) | Minitest tests that drive the app in-process with `Rack::MockRequest` |

## Endpoints

| Method and path | Success | Body |
| --- | --- | --- |
| `GET /` | 200 | name, engine and version |
| `GET /authors` | 200 | `{"data": [author, ...]}` |
| `POST /authors` | 201 | `{"name": String (required, ≤ 100), "born": Integer (1..2100)}`; `Location` header |
| `GET /authors/:id` | 200 | the author with its `books` |
| `PATCH /authors/:id` | 200 | any author fields |
| `DELETE /authors/:id` | 204 | 409 while the author still has books |
| `GET /books` | 200 | filter with `?author_id=1` and `?tag=sf` |
| `POST /books` | 201 | `{"title": String (required, ≤ 200), "author_id": Integer (required, must exist), "year": Integer (1..2100), "tags": [String]}`; `Location` header |
| `GET /books/:id` | 200 | |
| `PATCH /books/:id` | 200 | any book fields |
| `DELETE /books/:id` | 204 | |

Every error has the same shape, with `details` only for validation errors:

```json
{"error": {"code": "validation_failed", "message": "the request body is invalid",
           "details": {"title": ["must not be blank"], "year": ["must be between 1 and 2100"]}}}
```

| Status | `code` | When |
| --- | --- | --- |
| 400 | `invalid_json` | the body does not parse |
| 400 | `bad_request` | the body is JSON but not an object, or an id or `author_id` query parameter is not an integer |
| 404 | `not_found` | no such record, or no such route |
| 409 | `conflict` | deleting an author who still has books |
| 415 | `unsupported_media_type` | a body sent without `Content-Type: application/json` |
| 422 | `validation_failed` | a field is missing, of the wrong type, blank, too long, out of range or unknown, or `author_id` names no author |
| 500 | `internal_error` | anything else; the exception is not leaked |

## Prerequisites

Spinel 0.1.0 on your `PATH` (see the [top-level README](../../README.md#install-spinel)), and `curl` for the smoke script.

## Run it

```sh
cd examples/json-api
spinel install --frozen    # sinatra, rackup, webrick and minitest into .spinel/gem_home/
spinel test                # 8 tests, 0 failures, 0 errors
spinel run app.rb          # serves on http://127.0.0.1:4580
```

In another terminal:

```sh
curl -H 'Content-Type: application/json' -d '{"name":"Ursula K. Le Guin","born":1929}' http://127.0.0.1:4580/authors
# {"data":{"id":1,"name":"Ursula K. Le Guin","born":1929}}
curl -H 'Content-Type: application/json' \
     -d '{"title":"The Dispossessed","author_id":1,"year":1974,"tags":["sf"]}' http://127.0.0.1:4580/books
curl 'http://127.0.0.1:4580/books?tag=sf'
curl -X PATCH -H 'Content-Type: application/json' -d '{"year":1975}' http://127.0.0.1:4580/books/1
curl http://127.0.0.1:4580/authors/1                     # the author with its books
curl -H 'Content-Type: application/json' -d '{"title":"","author_id":"1"}' http://127.0.0.1:4580/books
# 422 {"error":{"code":"validation_failed",...,"details":{"title":["must not be blank"],"author_id":["must be an integer"]}}}
curl -H 'Content-Type: application/json' -d '{"title":' http://127.0.0.1:4580/books    # 400 invalid_json
curl -X DELETE http://127.0.0.1:4580/authors/1          # 409: delete the books first

spinel run client.rb       # the same API from Net::HTTP
```

## Smoke check

```sh
./smoke            # or, from the repository root: bin/smoke json-api
```

It installs the gems, runs `spinel test`, starts `spinel run app.rb`, checks every endpoint and every error status above with `curl` (status, body and headers), runs `client.rb` against the server, and stops it. It uses port 4580.

## Known issues (spinel 0.1.0)

None: Sinatra, WEBrick, `json`, `net/http`, `Rack::MockRequest` and Minitest all ran on Spinel 0.1.0 with no workaround.

One thing to know if you port code from older Rack apps: Rack 3 no longer requires `rack.input` to be rewindable, and WEBrick's input under `rackup` 2 has no `rewind`, so read the body once with `request.body.read` and do not call `request.body.rewind`. CRuby behaves the same way; it is not a Spinel issue.
