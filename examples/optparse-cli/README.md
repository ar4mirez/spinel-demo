# optparse-cli

A fuller command-line tool on Spinel: `bin/todo` keeps a task list in a JSON file. It builds on the [wordcount-cli](../wordcount-cli/) pattern with the parts a real CLI needs:

- **Subcommands** (`add`, `list`, `done`, `rm`, `help`), each with its own `OptionParser` and options.
- **Global options** before the subcommand (`--file`, `--version`, `--help`), parsed with `OptionParser#order!` so parsing stops at the subcommand.
- **`--help` output** for the tool and for every subcommand (`todo help add` and `todo add --help` print the same thing).
- **Exit codes**: 0 on success, 1 when a task is not found, 2 for a usage error (unknown command, bad option or value, missing argument), with a `Run 'todo help COMMAND' for usage.` hint on standard error.
- **Testable design**: `Todo::CLI#run(argv)` returns the exit status instead of calling `exit`, and takes its output streams and environment as arguments, so the Minitest tests call it directly.
- **Installable**: `spinel build --compile` packs it into one executable you can copy onto your `PATH`.

The code is in `lib/todo/cli.rb` (the command line) and `lib/todo/store.rb` (the task file); `bin/todo` only calls `Todo::CLI.new.run(ARGV)`.

## Prerequisites

Spinel 0.1.0 on your `PATH` (see the [top-level README](../../README.md#install-spinel)).

## Run it

```sh
cd examples/optparse-cli
spinel install --frozen                         # Minitest, for spinel test
spinel test                                     # test/cli_test.rb

spinel run bin/todo add -p high buy milk        # added #1: buy milk
spinel run bin/todo add write the docs          # added #2: write the docs
spinel run bin/todo done 1                      # done #1
spinel run bin/todo list                        # open tasks
spinel run bin/todo list --all --format json    # every task, as JSON
spinel run bin/todo rm 2                        # removed #2: write the docs
spinel run bin/todo done 9; echo $?             # todo: no task #9 in todo.json, then 1
spinel run bin/todo bogus; echo $?              # todo: unknown command 'bogus', then 2

spinel run bin/todo help                        # the commands and global options
spinel run bin/todo help list                   # one command's options
spinel run bin/todo -- --help                   # same as help (see Known issues below)
```

Tasks go to `./todo.json`; set `TODO_FILE` or pass `--file PATH` (before the command) to use another file.

## Install it

`spinel build` packs this `spinel`, the project and its gems into one executable, so the tool runs on a machine without Spinel:

```sh
spinel build --compile bin/todo -o todo
install todo ~/.local/bin/                      # or anywhere on your PATH
todo --help
```

The built executable passes every argument, `--help` included, to the program.

## Smoke check

```sh
./smoke            # or, from the repository root: bin/smoke optparse-cli
```

## Known issues (spinel 0.1.0)

Flags right after the script path go to `spinel` instead of the program ([ar4mirez/spinel#895](https://github.com/ar4mirez/spinel/issues/895), fixed after 0.1.0):

- `spinel run bin/todo --help` and `-h` print the help of `spinel run`. `--version`, `-V` and `-v` do reach the program under `spinel run`.
- Through the `#!/usr/bin/env spinel` line, `bin/todo --help`, `-h`, `--version`, `-V` and `-v` print Spinel's own help or version.

Workarounds: put `--` first (`spinel run bin/todo -- --help`), use the `help` command (`spinel run bin/todo help`), put the flag after a command (`bin/todo list --help`), or run the executable from `spinel build`, which is not affected.
