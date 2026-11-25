# wordcount-cli

A command-line tool on Spinel: `bin/wordcount` prints the most frequent words in files or standard input, as a table or as JSON. It uses `OptionParser` from the standard library, keeps its logic in `lib/wordcount.rb`, and tests it with Minitest under `spinel test`.

## Prerequisites

Spinel 0.1.0 on your `PATH` (see the [top-level README](../../README.md#install-spinel)).

## Run it

```sh
cd examples/wordcount-cli
spinel install --frozen                           # Minitest, for spinel test
spinel test                                       # test/wordcount_test.rb

spinel run bin/wordcount README.md                # the ten most frequent words
spinel run bin/wordcount -n 3 -m 4 README.md      # top 3, words of 4 letters or more
echo "the cat and the hat" | spinel run bin/wordcount -f json
spinel run bin/wordcount -i the,and,a README.md   # skip some words
spinel run bin/wordcount -- --help                # its options (see Known issues below)
```

`bin/wordcount` starts with `#!/usr/bin/env spinel`, so `bin/wordcount README.md` works too.

## Smoke check

```sh
./smoke            # or, from the repository root: bin/smoke wordcount-cli
```

## Known issues (spinel 0.1.0)

`spinel FILE --help`, `-h`, `--version` and `-v` print Spinel's help or version instead of passing the flag to the program, and so does `spinel run FILE --help`. This also breaks the `#!/usr/bin/env spinel` script: `bin/wordcount --help` prints Spinel's own help. Put `--` before the flag (`spinel run bin/wordcount -- --help`), or put another argument first.
