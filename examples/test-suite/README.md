# test-suite

A small library with a real test suite, written twice: once with Minitest under `test/` and once with RSpec under `spec/`. `spinel test` finds and runs both, in parallel workers, from the same project. The library is `lib/cart.rb`, a shopping cart priced in whole cents with coupons and tax, and both suites load the same YAML fixture, `fixtures/catalog.yml`.

What it shows:

- **Minitest** (`test/`): `test/test_helper.rb` (required once by `spinel test`, before the workers fork) loads the library and a `Fixtures` module that parses the catalog; `assert_equal`, `assert_raises`, `assert_match`, `assert_includes`, `assert_empty`, `refute`, `assert_nil` and `setup`.
- **RSpec** (`spec/`): `spec/spec_helper.rb` configures RSpec and defines a shared context that gives every group a `catalog`; `describe`/`context`, `subject`, `let`, `before`, `described_class`, `eq`, `raise_error`, `change { }.from().to()`, `have_attributes`, `contain_exactly`, compound `.and` matchers, and an `allow(File).to receive(:read)` stub from rspec-mocks.
- **Fixtures**: `fixtures/catalog.yml`, read with `YAML.safe_load`, shared by both suites.
- **Running tests**: everything, one suite, one test by `FILE:LINE`, a JUnit report for CI, what a failure looks like, and each framework's own runner.

## Prerequisites

Spinel 0.1.0 on your `PATH` (see the [top-level README](../../README.md#install-spinel)).

## Run it

```sh
cd examples/test-suite
spinel install --frozen                 # minitest and rspec into .spinel/
spinel test                             # both suites: 31 tests, 0 failures, 0 errors, 0 skips
```

Run one suite, one file, or one test:

```sh
spinel test test/*_test.rb              # only Minitest (see Known issues)
spinel test spec/*_spec.rb              # only RSpec
spinel test spec/cart_spec.rb           # one file
spinel test test/cart_test.rb:41        # the test defined at or above line 41
spinel test spec/cart_spec.rb:47        # the same for an RSpec example
```

When something fails, `spinel test` prints each failure with its `file:line`, the expected and actual values and a backtrace, then a `spinel test FILE:LINE` command to run just that failure again, and exits 1.

For CI or tools:

```sh
spinel test --reporter junit > junit.xml   # JUnit XML
spinel test --reporter json                # one JSON object per event
spinel test --watch                        # re-run as files change
```

Each framework's own runner works too:

```sh
spinel x rspec                          # RSpec's runner: 18 examples, 0 failures
spinel run test/cart_test.rb            # minitest/autorun runs the file's tests
```

## Layout

```
lib/cart.rb              Cart, Cart::Catalog, Cart::Product, Cart::Coupon
fixtures/catalog.yml     products and coupons, loaded by both suites
test/test_helper.rb      Minitest setup and the Fixtures module
test/*_test.rb           Minitest tests
spec/spec_helper.rb      RSpec configuration and the "catalog fixture" shared context
spec/*_spec.rb           RSpec specs
```

`spinel test` looks for `test/**/*_test.rb` and `spec/**/*_spec.rb`, so neither suite needs a `Rakefile` or a `.rspec` file.

## Smoke check

```sh
./smoke            # or, from the repository root: bin/smoke test-suite
```

## Known issues (spinel 0.1.0)

`spinel test` takes files but not directories: `spinel test spec` fails with `spinel test: no such file: spec` ([ar4mirez/spinel#910](https://github.com/ar4mirez/spinel/issues/910)). Let the shell list the files instead, as above: `spinel test spec/*_spec.rb`.
