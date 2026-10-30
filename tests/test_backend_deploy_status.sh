#!/usr/bin/env bash
#
# Tests for how `deploy/backend-deploy.sh status` reports the deployment state.
#
# Status must tell apart state it read, state that does not exist, and state it
# cannot read: a state directory or file the current account has no access to is
# reported as unknown, never as "no deployment recorded".
#
# Linux only, and as a non-root user: root ignores the file permissions these
# cases depend on, and Windows filesystems do not enforce them. Everything runs in
# a temporary directory. sudo, systemctl, git, curl and ss are replaced by
# stand-ins that fail or print nothing, so no service, server or privilege is
# touched; python3 must be installed, because status requires it.
#
#     bash tests/test_backend_deploy_status.sh
#
# Exits non-zero if any check fails.

set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/deploy/backend-deploy.sh"

CURRENT=6fd7754fe34297eaf99d9974125735b566b4cdc5
PREVIOUS=2a42ab4f9e20cbfb3953439ed8b0816c0979f75e
PENDING=96a5f0a8132b03e1b232b306ef32266ba35eecfe
HINT="cannot be read by the current account"

if [ "$(uname -s)" != "Linux" ]; then
  echo "error: these tests need Linux file permissions" >&2
  exit 2
fi
if [ "$(id -u)" -eq 0 ]; then
  echo "error: run these tests as a non-root user; root bypasses the permissions under test" >&2
  exit 2
fi
command -v python3 >/dev/null || { echo "error: python3 is required by status" >&2; exit 2; }

WORK="$(mktemp -d)"
cleanup() {
  # Give access back first, so every test directory can be removed.
  chmod -R u+rwX "$WORK" 2>/dev/null || true
  rm -rf -- "$WORK"
}
trap cleanup EXIT

STUBS="$WORK/bin"
mkdir -p "$STUBS"
for tool in sudo systemctl git curl; do
  printf '#!/bin/sh\nexit 1\n' > "$STUBS/$tool"
done
printf '#!/bin/sh\nexit 0\n' > "$STUBS/ss"
chmod +x "$STUBS"/*
ln -s "$(command -v python3)" "$STUBS/python3"

FAILURES=0
OUT=""
ERR=""
CODE=0

# Runs status against one state directory; stand-ins first on PATH.
run_status() {
  local state_dir=$1
  OUT="$WORK/out" ERR="$WORK/err"
  env -i HOME="$WORK" PATH="$STUBS:/usr/bin:/bin" \
    EQALB_DEPLOY_STATE_DIR="$state_dir" \
    bash "$SCRIPT" status > "$OUT" 2> "$ERR"
  CODE=$?
}

fail() {
  echo "  FAIL: $*"
  FAILURES=$((FAILURES + 1))
}

expect_line() {
  grep -qxF -- "$1" "$OUT" || fail "expected the line '$1'; got: $(grep -E '^(CURRENT|PREVIOUS|PENDING|STATE_ACCESS)' "$OUT" | paste -sd ' ' -)"
}

expect_exit_zero() {
  [ "$CODE" -eq 0 ] || fail "status exited $CODE; stderr: $(tail -n 3 "$ERR" | paste -sd ' ' -)"
}

expect_hint() {
  grep -qF -- "$HINT" "$ERR" || fail "the unreadable-state hint is missing from stderr"
}

expect_no_hint() {
  if grep -qF -- "$HINT" "$ERR"; then fail "the unreadable-state hint was printed"; fi
}

write_state() {
  local dir=$1
  mkdir -p "$dir"
  printf 'CURRENT_SHA=%s\nCURRENT_DEPLOYED_AT=2026-10-30T09:33:29Z\nPREVIOUS_SHA=%s\nPREVIOUS_DEPLOYED_AT=2026-10-28T11:03:46Z\n' \
    "$CURRENT" "$PREVIOUS" > "$dir/state.env"
  chmod 0600 "$dir/state.env"
}

write_pending() {
  local dir=$1
  printf 'PENDING_SHA=%s\nPENDING_ACTION=deploy\nPENDING_AT=2026-10-30T10:00:00Z\nPENDING_BASE_SHA=%s\n' \
    "$PENDING" "$CURRENT" > "$dir/pending.env"
  chmod 0600 "$dir/pending.env"
}

# --- cases --------------------------------------------------------------------

test_readable_state() {
  local dir="$WORK/readable" before
  write_state "$dir"
  write_pending "$dir"
  chmod 0700 "$dir"
  before="$(cat "$dir/state.env" "$dir/pending.env" | sha256sum)"
  run_status "$dir"
  expect_exit_zero
  expect_line "CURRENT_SHA=$CURRENT"
  expect_line "CURRENT_DEPLOYED_AT=2026-10-30T09:33:29Z"
  expect_line "PREVIOUS_SHA=$PREVIOUS"
  expect_line "PREVIOUS_DEPLOYED_AT=2026-10-28T11:03:46Z"
  expect_line "PENDING_SHA=$PENDING"
  expect_line "PENDING_ACTION=deploy"
  expect_line "PENDING_BASE_SHA=$CURRENT"
  expect_line "STATE_ACCESS=readable"
  expect_line "PENDING_ACCESS=readable"
  expect_no_hint
  [ "$(cat "$dir/state.env" "$dir/pending.env" | sha256sum)" = "$before" ] \
    || fail "status changed the state files"
}

test_readable_state_without_pending_attempt() {
  local dir="$WORK/readable-no-pending"
  write_state "$dir"
  run_status "$dir"
  expect_exit_zero
  expect_line "CURRENT_SHA=$CURRENT"
  expect_line "PENDING_SHA=none"
  expect_line "PENDING_ACCESS=absent"
  expect_no_hint
}

test_missing_state_directory() {
  run_status "$WORK/never-created/state"
  expect_exit_zero
  expect_line "CURRENT_SHA=none"
  expect_line "PREVIOUS_SHA=none"
  expect_line "PENDING_SHA=none"
  expect_line "STATE_ACCESS=absent"
  expect_line "PENDING_ACCESS=absent"
  expect_no_hint
  [ ! -e "$WORK/never-created" ] || fail "status created the state directory"
}

test_empty_state_directory() {
  local dir="$WORK/empty"
  mkdir -p "$dir"
  run_status "$dir"
  expect_exit_zero
  expect_line "CURRENT_SHA=none"
  expect_line "STATE_ACCESS=absent"
  expect_line "PENDING_ACCESS=absent"
  expect_no_hint
}

test_inaccessible_state_directory() {
  # The production case: a 0700 directory owned by another account. Removing
  # the owner's own access reproduces it without a second user.
  local dir="$WORK/hidden"
  write_state "$dir"
  write_pending "$dir"
  chmod 0000 "$dir"
  run_status "$dir"
  chmod 0700 "$dir"
  expect_exit_zero
  expect_line "CURRENT_SHA=unknown"
  expect_line "PREVIOUS_SHA=unknown"
  expect_line "PENDING_SHA=unknown"
  expect_line "PENDING_ACTION=unknown"
  expect_line "PENDING_BASE_SHA=unknown"
  expect_line "STATE_ACCESS=inaccessible"
  expect_line "PENDING_ACCESS=inaccessible"
  expect_hint
  if grep -qxF "CURRENT_SHA=none" "$OUT"; then fail "inaccessible state was reported as none"; fi
}

test_searchable_but_unlisted_directory() {
  # Execute without read permission: names can be looked up, so presence is
  # known and the readable file is read.
  local dir="$WORK/no-list"
  write_state "$dir"
  chmod 0300 "$dir"
  run_status "$dir"
  chmod 0700 "$dir"
  expect_exit_zero
  expect_line "CURRENT_SHA=$CURRENT"
  expect_line "STATE_ACCESS=readable"
  expect_line "PENDING_ACCESS=absent"
  expect_no_hint
}

test_unreadable_state_file() {
  local dir="$WORK/unreadable-file"
  write_state "$dir"
  chmod 0000 "$dir/state.env"
  run_status "$dir"
  chmod 0600 "$dir/state.env"
  expect_exit_zero
  expect_line "CURRENT_SHA=unknown"
  expect_line "PREVIOUS_SHA=unknown"
  expect_line "STATE_ACCESS=inaccessible"
  expect_line "PENDING_SHA=none"
  expect_line "PENDING_ACCESS=absent"
  expect_hint
}

test_unreadable_pending_file_only() {
  local dir="$WORK/unreadable-pending"
  write_state "$dir"
  write_pending "$dir"
  chmod 0000 "$dir/pending.env"
  run_status "$dir"
  chmod 0600 "$dir/pending.env"
  expect_exit_zero
  expect_line "CURRENT_SHA=$CURRENT"
  expect_line "STATE_ACCESS=readable"
  expect_line "PENDING_SHA=unknown"
  expect_line "PENDING_ACCESS=inaccessible"
  expect_hint
}

# --- runner -------------------------------------------------------------------

TESTS=(
  test_readable_state
  test_readable_state_without_pending_attempt
  test_missing_state_directory
  test_empty_state_directory
  test_inaccessible_state_directory
  test_searchable_but_unlisted_directory
  test_unreadable_state_file
  test_unreadable_pending_file_only
)

for name in "${TESTS[@]}"; do
  before=$FAILURES
  "$name"
  if [ "$FAILURES" -eq "$before" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name"
  fi
done

if [ "$FAILURES" -ne 0 ]; then
  echo "$FAILURES check(s) failed"
  exit 1
fi
echo "all ${#TESTS[@]} cases passed"
