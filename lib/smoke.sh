# shellcheck shell=bash
# Helpers shared by every example's smoke script. Source it from
# examples/<name>/smoke after `cd`-ing into the example:
#
#   set -euo pipefail
#   cd "$(dirname "$0")"
#   . ../../lib/smoke.sh
#
# It sets `pinned` to the Spinel version in the repository's mise.toml, checks
# that `spinel` on PATH is that version, and stops any server started with
# `start_server` when the script exits.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
server=
stop_server() { [ -n "$server" ] || return 0; kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; server=; }
trap stop_server EXIT

step() { printf '\n== %s\n' "$*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
expect() { # expect DESCRIPTION ACTUAL PATTERN
  grep -qE -- "$3" <<<"$2" || fail "$1: expected /$3/, got: $2"
  echo "ok: $1"
}
wait_for() { # wait_for URL: polls until the server answers, up to 60s
  for _ in $(seq 1 120); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  fail "no answer from $1"
}
start_server() { # start_server LOG COMMAND...: runs COMMAND in the background
  local log=$1; shift
  "$@" >"$log" 2>&1 & server=$!
}

pinned=$(sed -nE 's/^"github:ar4mirez\/spinel" = "(.*)"/\1/p' "$root/mise.toml")
mkdir -p tmp
expect "spinel $pinned (pinned in mise.toml)" "$(spinel --version)" "^spinel $pinned "
