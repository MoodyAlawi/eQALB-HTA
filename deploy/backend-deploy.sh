#!/usr/bin/env bash
#
# eQalb backend deployment: FastAPI plus its long-lived R worker children.
#
# This script runs on the VPS. The GitHub Actions workflow
# (.github/workflows/deploy-backend.yml) pipes it to `bash -s` as the SSH
# deploy user; the same script can be run by hand over SSH:
#
#   bash -s -- deploy <full-commit-sha>   < deploy/backend-deploy.sh
#   bash -s -- rollback [<full-commit-sha>] < deploy/backend-deploy.sh
#   bash -s -- status                     < deploy/backend-deploy.sh
#
# What it changes: the /opt/eqalb Git checkout, the pinned Python packages in
# /opt/eqalb/.venv, the project renv library, and the eqalb-api systemd service
# (which stops and starts the API and, with it, every R worker child). What it
# records: the deployed SHA and time, the previous known-good SHA, and any
# in-flight attempt, in /var/lib/eqalb-backend-deploy. It never edits model code,
# API code, the frontend, the Caddy configuration or /etc/eqalb/api.env.
#
# There is no separate R worker service: api/r_client.py starts the workers as
# children of the FastAPI process, and eqalb-api.service uses
# KillMode=control-group. Restarting eqalb-api.service therefore restarts the
# API and all R workers together, and the health check verifies at least one
# ready worker afterwards.
#
# Failure behaviour: the service is not restarted until the Python and R
# dependencies have been installed and checked. If a dependency step fails, the
# previous process keeps running (the checkout has moved, but nothing has
# restarted it). If the restart or health check fails, this script exits
# non-zero after printing the service logs; it does NOT roll back automatically.
# Use the rollback action documented in deploy/BACKEND_DEPLOY.md.
#
# This script is deliberately not root: run it as the SSH deploy user. It uses
# passwordless sudo for exactly two things:
#   * sudo -u eqalb ...        (the application account that owns /opt/eqalb)
#   * systemctl restart eqalb-api.service
# See deploy/BACKEND_DEPLOY.md for the one-time sudoers and state directory.

if [ -z "${BASH_VERSION:-}" ]; then
  printf 'backend-deploy: error: run this script with bash, not sh\n' >&2
  exit 1
fi

set -euo pipefail
umask 022

# --- Fixed server layout -----------------------------------------------------
PROJECT_DIR="/opt/eqalb"
APP_USER="eqalb"
SERVICE="eqalb-api.service"
RSCRIPT="/opt/R/4.5.1/bin/Rscript"
VENV_PYTHON="$PROJECT_DIR/.venv/bin/python"

# Deployment-only state. Owned by the SSH deploy user, never by eqalb and never
# tracked in Git.
STATE_DIR="/var/lib/eqalb-backend-deploy"
STATE_FILE="$STATE_DIR/state.env"
PENDING_FILE="$STATE_DIR/pending.env"
HISTORY_FILE="$STATE_DIR/history.log"
LOCK_FILE="$STATE_DIR/deploy.lock"

# The service binds loopback only (deploy/api.env.example). These overrides
# exist for a host whose /etc/eqalb/api.env uses different values.
API_HOST="${EQALB_DEPLOY_API_HOST:-127.0.0.1}"
API_PORT="${EQALB_DEPLOY_API_PORT:-8000}"
HEALTH_URL="http://${API_HOST}:${API_PORT}/api/health"
HEALTH_TIMEOUT="${EQALB_DEPLOY_HEALTH_TIMEOUT:-180}"
HEALTH_INTERVAL="${EQALB_DEPLOY_HEALTH_INTERVAL:-3}"

# --- Run-time state ----------------------------------------------------------
ACTION=""
TARGET_SHA=""
ORIGINAL_SHA=""
CURRENT_SHA=""
CURRENT_DEPLOYED_AT=""
PREVIOUS_SHA=""
PREVIOUS_DEPLOYED_AT=""
PENDING_SHA=""
PENDING_ACTION=""
PENDING_AT=""
PENDING_BASE_SHA=""
CHECKED_OUT=0
RESTARTED=0

GIT=""
CURL=""
FLOCK=""
SYSTEMCTL=""
PYTHON3=""
HEALTH_PYTHON=""

# Prints a compact status line and exits 1 unless the response is healthy.
# A 200 response with status "degraded" is a failed health check, so this reads
# the body instead of relying on curl's exit code.
read -r -d '' HEALTH_PARSER <<'PY' || true
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception as exc:  # noqa: BLE001 - any parse failure is unhealthy
    print("health: response is not valid JSON: %s" % exc, file=sys.stderr)
    sys.exit(2)

r_model = data.get("r_model") or {}
ready = r_model.get("ready_workers", 0)
configured = r_model.get("configured_workers", 0)

ok = (
    data.get("status") == "ok"
    and data.get("model_ready") is True
    and isinstance(ready, int)
    and ready >= 1
    and data.get("r_model_error") is None
)

if not ok:
    print(
        "health: not ready: status=%r model_ready=%r ready_workers=%r "
        "configured_workers=%r r_model_error=%r"
        % (
            data.get("status"),
            data.get("model_ready"),
            ready,
            configured,
            data.get("r_model_error"),
        ),
        file=sys.stderr,
    )
    sys.exit(1)

print(
    "health: status=ok model_ready=true ready_workers=%d configured_workers=%d"
    % (ready, configured)
)
if isinstance(configured, int) and configured > ready:
    print(
        "health: warning: only %d of %d configured R workers are ready"
        % (ready, configured),
        file=sys.stderr,
    )
PY

usage() {
  cat <<'EOF'
usage: backend-deploy.sh deploy <full-commit-sha>
       backend-deploy.sh rollback [<full-commit-sha>]
       backend-deploy.sh status
       backend-deploy.sh help

  deploy    Check out and deploy one committed backend revision, then restart
            and health-check eqalb-api.service.
  rollback  Deploy the recorded previous known-good SHA, or the SHA given.
  status    Print the recorded deployment state, checkout HEAD and health,
            without changing anything. It does not require sudo.

The SHA must be the full 40-character lowercase Git commit id.
EOF
}

die() {
  printf 'backend-deploy: error: %s\n' "$*" >&2
  exit 1
}

note() {
  printf 'backend-deploy: %s\n' "$*" >&2
}

on_exit() {
  local status=$?
  if [ "$status" -ne 0 ] && { [ "$ACTION" = "deploy" ] || [ "$ACTION" = "rollback" ]; }; then
    if [ -n "$TARGET_SHA" ]; then
      note "target commit: $TARGET_SHA"
    fi
    if [ "$RESTARTED" -eq 1 ]; then
      note "a service restart was attempted, so the service may be running the target commit or may be down."
    elif [ "$CHECKED_OUT" -eq 1 ]; then
      note "the checkout is now the target commit, but the service was not restarted;"
      note "the previously running process should still be serving."
    fi
    if [ -n "$CURRENT_SHA" ]; then
      note "last recorded successful deployment: $CURRENT_SHA"
    fi
    if [ -n "$ORIGINAL_SHA" ]; then
      note "manual rollback: bash deploy/backend-deploy.sh rollback $ORIGINAL_SHA"
    else
      note "manual rollback: see deploy/BACKEND_DEPLOY.md"
    fi
    if [ "$CHECKED_OUT" -eq 1 ] && [ -f "$PENDING_FILE" ]; then
      note "the incomplete attempt is recorded; 'bash deploy/backend-deploy.sh rollback' restores the last known-good"
    fi
  fi
  exit "$status"
}
trap on_exit EXIT

require_command() {
  local name=$1 path
  path="$(command -v "$name" || true)"
  [ -n "$path" ] || die "required command not found: $name"
  printf '%s' "$path"
}

validate_sha() {
  local sha=${1:-}
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] \
    || die "expected a full 40-character lowercase Git commit SHA, got '${sha}'"
}

run_as_app() {
  sudo -n -u "$APP_USER" -H -- "$@"
}

read_state() {
  CURRENT_SHA=""
  CURRENT_DEPLOYED_AT=""
  PREVIOUS_SHA=""
  PREVIOUS_DEPLOYED_AT=""

  if [ -f "$STATE_FILE" ]; then
    CURRENT_SHA="$(sed -n 's/^CURRENT_SHA=//p' "$STATE_FILE" | head -n 1)"
    CURRENT_DEPLOYED_AT="$(sed -n 's/^CURRENT_DEPLOYED_AT=//p' "$STATE_FILE" | head -n 1)"
    PREVIOUS_SHA="$(sed -n 's/^PREVIOUS_SHA=//p' "$STATE_FILE" | head -n 1)"
    PREVIOUS_DEPLOYED_AT="$(sed -n 's/^PREVIOUS_DEPLOYED_AT=//p' "$STATE_FILE" | head -n 1)"
  fi

  if [ -n "$CURRENT_SHA" ]; then
    validate_sha "$CURRENT_SHA"
  fi
  if [ -n "$PREVIOUS_SHA" ]; then
    validate_sha "$PREVIOUS_SHA"
  fi
}

read_pending() {
  PENDING_SHA=""
  PENDING_ACTION=""
  PENDING_AT=""
  PENDING_BASE_SHA=""

  if [ -f "$PENDING_FILE" ]; then
    PENDING_SHA="$(sed -n 's/^PENDING_SHA=//p' "$PENDING_FILE" | head -n 1)"
    PENDING_ACTION="$(sed -n 's/^PENDING_ACTION=//p' "$PENDING_FILE" | head -n 1)"
    PENDING_AT="$(sed -n 's/^PENDING_AT=//p' "$PENDING_FILE" | head -n 1)"
    PENDING_BASE_SHA="$(sed -n 's/^PENDING_BASE_SHA=//p' "$PENDING_FILE" | head -n 1)"
  fi

  if [ -n "$PENDING_SHA" ]; then
    validate_sha "$PENDING_SHA"
  fi
  if [ -n "$PENDING_BASE_SHA" ]; then
    validate_sha "$PENDING_BASE_SHA"
  fi
}

write_pending() {
  local sha=$1 action=$2 base=$3
  local tmp
  tmp="$(mktemp "$STATE_DIR/pending.XXXXXX")" \
    || die "cannot create a temporary pending-state file in $STATE_DIR"
  {
    printf 'PENDING_SHA=%s\n' "$sha"
    printf 'PENDING_ACTION=%s\n' "$action"
    printf 'PENDING_AT=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'PENDING_BASE_SHA=%s\n' "$base"
  } > "$tmp"
  chmod 0600 "$tmp"
  mv -f -- "$tmp" "$PENDING_FILE"
}

clear_pending() {
  rm -f -- "$PENDING_FILE" \
    || note "warning: could not remove $PENDING_FILE"
}

write_state() {
  local current=$1 current_at=$2 previous=$3 previous_at=$4
  local tmp
  tmp="$(mktemp "$STATE_DIR/state.XXXXXX")" \
    || die "cannot create a temporary state file in $STATE_DIR"
  {
    printf 'CURRENT_SHA=%s\n' "$current"
    printf 'CURRENT_DEPLOYED_AT=%s\n' "$current_at"
    printf 'PREVIOUS_SHA=%s\n' "$previous"
    printf 'PREVIOUS_DEPLOYED_AT=%s\n' "$previous_at"
  } > "$tmp"
  chmod 0600 "$tmp"
  mv -f -- "$tmp" "$STATE_FILE"
}

append_history() {
  local action=$1 sha=$2 previous=$3
  {
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$action" "$sha" "${previous:--}" "$(id -un)"
  } >> "$HISTORY_FILE" || note "warning: could not append to $HISTORY_FILE"
  chmod 0600 "$HISTORY_FILE" 2>/dev/null || true
}

preflight() {
  [ "$(id -u)" -ne 0 ] \
    || die "run this script as the SSH deploy user, not root (the state directory must stay owned by that user)"
  [ -d "$PROJECT_DIR/.git" ] \
    || die "$PROJECT_DIR is not a Git checkout; run deploy/DEPLOY.md section 3 first"
  [ -d "$STATE_DIR" ] \
    || die "$STATE_DIR is missing; create it once as described in deploy/BACKEND_DEPLOY.md"
  [ -w "$STATE_DIR" ] \
    || die "$STATE_DIR is not writable by $(id -un); see deploy/BACKEND_DEPLOY.md"
  if [ -f "$STATE_FILE" ] && [ ! -r "$STATE_FILE" ]; then
    die "$STATE_FILE is not readable by $(id -un); fix its ownership before deploying"
  fi
  if [ -f "$PENDING_FILE" ] && [ ! -r "$PENDING_FILE" ]; then
    die "$PENDING_FILE is not readable by $(id -un); fix its ownership before deploying"
  fi
  [ -x "$RSCRIPT" ] \
    || die "$RSCRIPT is not executable; the R 4.5.1 source build from deploy/DEPLOY.md is required"

  sudo -n -u "$APP_USER" -- true 2>/dev/null \
    || die "passwordless sudo as $APP_USER is required; see deploy/BACKEND_DEPLOY.md"
  sudo -n -l "$SYSTEMCTL" restart "$SERVICE" >/dev/null 2>&1 \
    || die "passwordless sudo for '$SYSTEMCTL restart $SERVICE' is required; see deploy/BACKEND_DEPLOY.md"

  if ! [[ "$HEALTH_TIMEOUT" =~ ^[0-9]+$ ]] || [ "$HEALTH_TIMEOUT" -lt 1 ]; then
    die "EQALB_DEPLOY_HEALTH_TIMEOUT must be a positive integer"
  fi
  if ! [[ "$HEALTH_INTERVAL" =~ ^[0-9]+$ ]] || [ "$HEALTH_INTERVAL" -lt 1 ]; then
    die "EQALB_DEPLOY_HEALTH_INTERVAL must be a positive integer"
  fi

  run_as_app test -r /etc/eqalb/api.env \
    || die "/etc/eqalb/api.env is not readable by $APP_USER"
  run_as_app test -w "$PROJECT_DIR" \
    || die "$APP_USER cannot write $PROJECT_DIR"

  # The service's own R path must be the one this script restores with, and the
  # health probe must use the host/port the service actually binds.
  local configured_rscript configured_host configured_port
  configured_rscript="$(run_as_app sed -n \
    's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}EQALB_RSCRIPT=//p' \
    /etc/eqalb/api.env | tail -n 1)"
  configured_rscript="${configured_rscript%\"}"
  configured_rscript="${configured_rscript#\"}"
  [ -n "$configured_rscript" ] \
    || die "EQALB_RSCRIPT is not set in /etc/eqalb/api.env"
  [ "$configured_rscript" = "$RSCRIPT" ] \
    || die "EQALB_RSCRIPT in /etc/eqalb/api.env is '$configured_rscript', not '$RSCRIPT'"

  configured_host="$(run_as_app sed -n \
    's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}EQALB_API_HOST=//p' \
    /etc/eqalb/api.env | tail -n 1)"
  configured_port="$(run_as_app sed -n \
    's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}EQALB_API_PORT=//p' \
    /etc/eqalb/api.env | tail -n 1)"
  [ -n "$configured_host" ] \
    || die "EQALB_API_HOST is not set in /etc/eqalb/api.env"
  [ -n "$configured_port" ] \
    || die "EQALB_API_PORT is not set in /etc/eqalb/api.env"
  if [ "$configured_host" != "$API_HOST" ]; then
    die "EQALB_API_HOST is '$configured_host' in /etc/eqalb/api.env, but the health check uses '$API_HOST'; set EQALB_DEPLOY_API_HOST"
  fi
  if [ "$configured_port" != "$API_PORT" ]; then
    die "EQALB_API_PORT is '$configured_port' in /etc/eqalb/api.env, but the health check uses '$API_PORT'; set EQALB_DEPLOY_API_PORT"
  fi

  if "$SYSTEMCTL" is-active --quiet "$SERVICE"; then
    note "$SERVICE is active before the deployment"
  else
    note "warning: $SERVICE is not active before the deployment; there is no running previous process to keep"
  fi
}

acquire_lock() {
  exec 9>"$LOCK_FILE"
  "$FLOCK" -n 9 \
    || die "another deployment is already running on this host"
}

fetch_and_checkout() {
  local sha=$1 dirty actual shallow
  ORIGINAL_SHA="$(run_as_app "$GIT" -C "$PROJECT_DIR" rev-parse HEAD)"
  validate_sha "$ORIGINAL_SHA"

  note "fetching origin"
  run_as_app env GIT_TERMINAL_PROMPT=0 "$GIT" -C "$PROJECT_DIR" \
    fetch --prune --tags origin '+refs/heads/*:refs/remotes/origin/*' \
    || die "git fetch failed; confirm the checkout's origin is reachable without a prompt"

  if ! run_as_app "$GIT" -C "$PROJECT_DIR" cat-file -e "${sha}^{commit}" 2>/dev/null; then
    shallow="$(run_as_app "$GIT" -C "$PROJECT_DIR" rev-parse --is-shallow-repository)"
    if [ "$shallow" = "true" ]; then
      note "the commit is not in the shallow checkout; fetching full history"
      run_as_app env GIT_TERMINAL_PROMPT=0 "$GIT" -C "$PROJECT_DIR" \
        fetch --unshallow --tags origin '+refs/heads/*:refs/remotes/origin/*' \
        || die "git fetch --unshallow failed"
    fi
  fi
  run_as_app "$GIT" -C "$PROJECT_DIR" cat-file -e "${sha}^{commit}" 2>/dev/null \
    || die "commit $sha is not available from origin"

  dirty="$(run_as_app "$GIT" -C "$PROJECT_DIR" status --porcelain --untracked-files=no)"
  [ -z "$dirty" ] \
    || die "the checkout has tracked local changes; refusing to overwrite them (commit, stash or discard them first)"

  note "checking out $sha"
  run_as_app "$GIT" -C "$PROJECT_DIR" checkout --detach "$sha" \
    || die "git checkout $sha failed"
  actual="$(run_as_app "$GIT" -C "$PROJECT_DIR" rev-parse HEAD)"
  [ "$actual" = "$sha" ] || die "the checkout did not reach $sha (HEAD is $actual)"
  CHECKED_OUT=1

  run_as_app test -r "$PROJECT_DIR/renv.lock" \
    || die "renv.lock is missing or unreadable after checkout"
  run_as_app test -r "$PROJECT_DIR/api/requirements.lock.txt" \
    || die "api/requirements.lock.txt is missing or unreadable after checkout"
}

sync_python() {
  if [ ! -x "$VENV_PYTHON" ]; then
    note "the Python virtual environment is missing; creating $PROJECT_DIR/.venv"
    run_as_app "$PYTHON3" -m venv "$PROJECT_DIR/.venv" \
      || die "could not create $PROJECT_DIR/.venv with $PYTHON3"
  fi

  note "syncing Python dependencies from api/requirements.lock.txt"
  run_as_app "$VENV_PYTHON" -m pip install \
    --disable-pip-version-check --no-input \
    --requirement "$PROJECT_DIR/api/requirements.lock.txt" \
    || die "pip install failed"
  run_as_app "$VENV_PYTHON" -m pip check \
    || die "pip check reported a broken Python environment"
  run_as_app "$VENV_PYTHON" -c 'import fastapi, uvicorn' \
    || die "the API's Python dependencies cannot be imported"
}

sync_r() {
  local required_r actual_r
  required_r="$(run_as_app cat "$PROJECT_DIR/renv.lock" \
    | grep -m 1 -o '"Version"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | sed 's/.*"\([^"]*\)"$/\1/')"
  [ -n "$required_r" ] || die "could not read the R version from renv.lock"
  actual_r="$(run_as_app "$RSCRIPT" --version 2>&1 \
    | sed -n 's/.* \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' \
    | head -n 1)"
  [ "$actual_r" = "$required_r" ] \
    || die "R is ${actual_r:-unknown}, but renv.lock requires $required_r ($RSCRIPT)"

  note "restoring the renv library with R $actual_r"
  ( cd "$PROJECT_DIR" && run_as_app "$RSCRIPT" -e 'renv::restore(prompt = FALSE)' ) \
    || die "renv::restore failed; do not restart the service over an incomplete restore"
  note "checking that renv.lock and the project library are synchronized"
  ( cd "$PROJECT_DIR" && run_as_app "$RSCRIPT" -e \
    'status <- renv::status(); if (!isTRUE(status[["synchronized"]])) { print(status); quit(status = 1) }' ) \
    || die "renv::status reports that the library is not synchronized with renv.lock"
}

health_once() {
  local body
  if ! body="$("$CURL" -sS --max-time 15 --connect-timeout 5 "$HEALTH_URL" 2>/dev/null)"; then
    printf 'GET %s failed' "$HEALTH_URL"
    return 1
  fi
  printf '%s' "$body" | "$HEALTH_PYTHON" -c "$HEALTH_PARSER" 2>&1
}

diagnose_service() {
  note "service state:"
  "$SYSTEMCTL" is-active "$SERVICE" 2>&1 | sed 's/^/  /' || true
  "$SYSTEMCTL" status --no-pager -n 20 "$SERVICE" 2>&1 | tail -n 30 | sed 's/^/  /' || true
  journalctl -u "$SERVICE" --since '-15 min' --no-pager -n 60 2>&1 | tail -n 60 | sed 's/^/  /' || true
  pgrep -a Rscript 2>/dev/null | head -n 10 | sed 's/^/  /' || true
}

restart_and_wait() {
  note "restarting $SERVICE (this also restarts its R worker children)"
  RESTARTED=1
  if ! sudo -n "$SYSTEMCTL" restart "$SERVICE"; then
    diagnose_service
    die "$SYSTEMCTL restart $SERVICE failed"
  fi

  local deadline message last_error=""
  deadline=$(( $(date +%s) + HEALTH_TIMEOUT ))
  while :; do
    if message="$(health_once)"; then
      note "$message"
      return 0
    fi
    last_error="$message"

    if [ "$(date +%s)" -ge "$deadline" ]; then
      note "the health check did not pass within ${HEALTH_TIMEOUT}s"
      [ -z "$last_error" ] || note "last health error: $last_error"
      diagnose_service
      die "GET $HEALTH_URL is not healthy; see the service diagnostics above"
    fi
    sleep "$HEALTH_INTERVAL"
  done
}

deploy_sha() {
  local action=$1 target=$2
  validate_sha "$target"
  read_state
  read_pending

  if [ -n "$PENDING_SHA" ]; then
    note "a previous attempt ($PENDING_ACTION $PENDING_SHA at $PENDING_AT) did not complete; this attempt replaces it"
  fi

  if [ "$action" = "deploy" ] && [ -n "$CURRENT_SHA" ] && [ "$CURRENT_SHA" = "$target" ]; then
    note "note: $target is already the recorded current deployment; dependencies and the service will still be re-synced and restarted"
  fi

  TARGET_SHA="$target"
  note "$action: target $target; recorded current ${CURRENT_SHA:-none}, previous ${PREVIOUS_SHA:-none}"

  # Read the current health before changing anything. This is informational: a
  # deployment can be used to recover an unhealthy backend, but the operator
  # should know that the recorded previous commit was not healthy either.
  local pre_health
  if pre_health="$(health_once)"; then
    note "current deployment health: $pre_health"
  else
    note "warning: the current deployment is not healthy (${pre_health:-no response}); the recorded previous may not be known-good"
  fi

  # All dependency work happens before the restart, so a failed install leaves
  # the previously running process untouched.
  fetch_and_checkout "$target"

  # Record the in-flight attempt until it either passes the health check or
  # fails. The record lets a later bare `rollback` choose the last known-good
  # commit rather than the commit that was being replaced.
  write_pending "$target" "$action" "$ORIGINAL_SHA"

  sync_python
  sync_r
  restart_and_wait

  DEPLOYED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local new_previous current_at
  if [ "$CURRENT_SHA" = "$target" ]; then
    # Deploying or rolling back to the revision that is already current does not
    # replace the last distinct known-good release. This is the usual recovery
    # after a failed attempt: current is the last success, and previous stays.
    new_previous="$PREVIOUS_SHA"
    current_at="$PREVIOUS_DEPLOYED_AT"
  else
    new_previous="$CURRENT_SHA"
    current_at="$CURRENT_DEPLOYED_AT"
  fi

  write_state "$target" "$DEPLOYED_AT" "$new_previous" "$current_at"
  clear_pending
  append_history "$action" "$target" "$new_previous"

  note "deployed $target at $DEPLOYED_AT"
  note "previous known-good: ${new_previous:-none}"
  printf 'DEPLOYED_SHA=%s\n' "$target"
  printf 'DEPLOYED_AT=%s\n' "$DEPLOYED_AT"
  printf 'PREVIOUS_SHA=%s\n' "$new_previous"
  printf 'PREVIOUS_DEPLOYED_AT=%s\n' "$current_at"
  printf 'ACTION=%s\n' "$action"
  printf 'HEALTH=ok\n'
}

show_status() {
  local head="" active="unknown" body="" message=""

  read_state
  read_pending
  if sudo -n -u "$APP_USER" -- true 2>/dev/null; then
    head="$(run_as_app "$GIT" -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || true)"
  fi
  if "$SYSTEMCTL" is-active --quiet "$SERVICE" 2>/dev/null; then
    active="active"
  else
    active="inactive"
  fi
  if body="$("$CURL" -sS --max-time 10 --connect-timeout 5 "$HEALTH_URL" 2>/dev/null)"; then
    message="$(printf '%s' "$body" | "$HEALTH_PYTHON" -c "$HEALTH_PARSER" 2>&1 || true)"
  else
    message="GET $HEALTH_URL failed"
  fi

  printf 'CURRENT_SHA=%s\n' "${CURRENT_SHA:-none}"
  printf 'CURRENT_DEPLOYED_AT=%s\n' "${CURRENT_DEPLOYED_AT:-unknown}"
  printf 'PREVIOUS_SHA=%s\n' "${PREVIOUS_SHA:-none}"
  printf 'PREVIOUS_DEPLOYED_AT=%s\n' "${PREVIOUS_DEPLOYED_AT:-unknown}"
  printf 'PENDING_SHA=%s\n' "${PENDING_SHA:-none}"
  printf 'PENDING_ACTION=%s\n' "${PENDING_ACTION:-none}"
  printf 'PENDING_AT=%s\n' "${PENDING_AT:-unknown}"
  printf 'PENDING_BASE_SHA=%s\n' "${PENDING_BASE_SHA:-none}"
  printf 'CHECKOUT_HEAD=%s\n' "${head:-unknown}"
  printf 'SERVICE=%s\n' "$active"
  printf 'HEALTH=%s\n' "$message"
  printf 'STATE_FILE=%s\n' "$STATE_FILE"
  printf 'HISTORY_FILE=%s\n' "$HISTORY_FILE"
}

main() {
  local action=${1:-}
  case "$action" in
    deploy)
      [ "$#" -eq 2 ] || { usage >&2; die "deploy requires exactly one commit SHA"; }
      validate_sha "$2"
      GIT="$(require_command git)"
      CURL="$(require_command curl)"
      FLOCK="$(require_command flock)"
      SYSTEMCTL="$(require_command systemctl)"
      PYTHON3="$(require_command python3)"
      HEALTH_PYTHON="$PYTHON3"
      ACTION="deploy"
      preflight
      acquire_lock
      deploy_sha deploy "$2"
      ;;
    rollback)
      [ "$#" -le 2 ] || { usage >&2; die "rollback takes at most one commit SHA"; }
      GIT="$(require_command git)"
      CURL="$(require_command curl)"
      FLOCK="$(require_command flock)"
      SYSTEMCTL="$(require_command systemctl)"
      PYTHON3="$(require_command python3)"
      HEALTH_PYTHON="$PYTHON3"
      ACTION="rollback"
      preflight
      acquire_lock
      # Choose the default target under the lock, so a concurrent deployment
      # cannot change the recorded state between the choice and the checkout.
      read_state
      read_pending
      local target=${2:-}
      if [ -z "$target" ]; then
        if [ -n "$PENDING_SHA" ]; then
          # The last attempt did not finish. Restore what was running before
          # it: the last recorded success, or the base checkout on a first run.
          target="${CURRENT_SHA:-$PENDING_BASE_SHA}"
          [ -n "$target" ] \
            || die "the last attempt ($PENDING_ACTION $PENDING_SHA) did not complete and no last known-good SHA is recorded; pass the full SHA to roll back to"
          note "the last attempt ($PENDING_ACTION $PENDING_SHA at $PENDING_AT) did not complete; rolling back to $target"
        else
          target="$PREVIOUS_SHA"
          [ -n "$target" ] \
            || die "no previous deployment is recorded; pass the full SHA to roll back to"
        fi
      fi
      validate_sha "$target"
      deploy_sha rollback "$target"
      ;;
    status)
      GIT="$(command -v git || true)"
      CURL="$(command -v curl || true)"
      SYSTEMCTL="$(command -v systemctl || true)"
      HEALTH_PYTHON="$(command -v python3 || true)"
      if [ -z "$GIT" ] || [ -z "$CURL" ] || [ -z "$SYSTEMCTL" ] || [ -z "$HEALTH_PYTHON" ]; then
        die "status requires git, curl, systemctl and python3 on PATH"
      fi
      show_status
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
