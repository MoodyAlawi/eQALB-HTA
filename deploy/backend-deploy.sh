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
# in-flight attempt, in the state directory below. It never edits model code,
# API code, the frontend, the Caddy configuration or any unit or environment
# file.
#
# Configuration is resolved from the service itself, read-only, before anything
# is changed. Supported sources, in the order systemd applies them:
#   * Environment= in the unit (and its drop-ins)
#   * EnvironmentFile= files listed by the unit, in order (they override
#     Environment=, and later files override earlier ones)
#   * ExecStart: a uvicorn command line uses --host/--port, then
#     UVICORN_HOST/UVICORN_PORT, then 127.0.0.1:8000; api/run_api.py and
#     api/main.py use EQALB_API_HOST/EQALB_API_PORT and default to 127.0.0.1:8788
#   * unset settings fall back to the application defaults from those files
# EQALB_RSCRIPT selects R; when it is unset, Rscript is resolved from the
# service PATH exactly as api/r_client.py does. EQALB_R_WORKERS defaults to 2.
# An EnvironmentFile is optional: a host with only inline systemd settings is
# supported. Files are parsed as data (never sourced), every value used is
# checked against the running service, and a value that cannot be established
# is reported instead of guessed.
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
# This script is deliberately not root: run it as the SSH deploy account
# (the account named by the workflow's BACKEND_DEPLOY_SSH_USER).
# It uses passwordless sudo for exactly two things:
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
VENV_PYTHON="$PROJECT_DIR/.venv/bin/python"

# Deployment-only state. Owned by the SSH deploy user, never by eqalb and never
# tracked in Git.
STATE_DIR="${EQALB_DEPLOY_STATE_DIR:-/var/lib/eqalb-backend-deploy}"
STATE_FILE="$STATE_DIR/state.env"
PENDING_FILE="$STATE_DIR/pending.env"
HISTORY_FILE="$STATE_DIR/history.log"
LOCK_FILE="$STATE_DIR/deploy.lock"

# Application defaults, used only when the service configuration does not
# determine a value. They come from the committed launchers:
#   api/main.py and api/run_api.py: 127.0.0.1:8788, EQALB_R_WORKERS defaults to 2
#   api/r_client.py:               EQALB_R_WORKERS defaults to 2, Rscript from PATH
#   uvicorn command line:          127.0.0.1:8000
DEFAULT_APP_HOST="127.0.0.1"
DEFAULT_APP_PORT="8788"
DEFAULT_UVICORN_HOST="127.0.0.1"
DEFAULT_UVICORN_PORT="8000"
DEFAULT_WORKERS="2"

# The only variables this script reads values for from the unit environment or
# an environment file. A service unit may set other (including secret)
# variables; they are ignored, and only their names can appear in a diagnostic,
# never their values.
CONFIG_KEYS=(EQALB_RSCRIPT EQALB_API_HOST EQALB_API_PORT EQALB_R_WORKERS UVICORN_HOST UVICORN_PORT PATH)

# Explicit operator overrides for a host whose configuration cannot be resolved
# read-only. They are never guessed and are still health-checked.
RSCRIPT_OVERRIDE="${EQALB_DEPLOY_RSCRIPT:-}"
API_HOST_OVERRIDE="${EQALB_DEPLOY_API_HOST:-}"
API_PORT_OVERRIDE="${EQALB_DEPLOY_API_PORT:-}"
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
CHANGES_POSSIBLE=0
CONFIG_STRICT=1

# Resolved service configuration. Each value carries its provenance so a
# failure can say exactly which source produced it.
HEALTH_URL=""
SERVICE_PROPERTIES=""
SERVICE_FRAGMENT=""
SERVICE_DROPINS=""
SERVICE_USER=""
SERVICE_GROUP=""
SERVICE_WORKDIR=""
SERVICE_ACTIVE="unknown"
SERVICE_MAINPID="0"
EXEC_MODE="unknown"
EXEC_HOST=""
EXEC_PORT=""
EXEC_SOCKET=0
RUNTIME_AVAILABLE=0
RESOLVED_RSCRIPT=""
RESOLVED_RSCRIPT_SOURCE=""
RESOLVED_R_VERSION=""
RESOLVED_API_HOST=""
RESOLVED_API_HOST_SOURCE=""
RESOLVED_API_PORT=""
RESOLVED_API_PORT_SOURCE=""
RESOLVED_WORKERS=""
RESOLVED_WORKERS_SOURCE=""
OBSERVED_HOSTS=()
OBSERVED_PORTS=()
declare -A CONFIG_ENV=()
declare -A CONFIG_SOURCE=()
declare -A RUNTIME_ENV=()

GIT=""
CURL=""
FLOCK=""
SYSTEMCTL=""
PYTHON3=""
HEALTH_PYTHON=""
SS=""

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

# Reads only the settings listed in CONFIG_KEYS from systemd's property formats
# and from environment files. It never executes or sources configuration text,
# and it never prints a value that is not in CONFIG_KEYS.
read -r -d '' CONFIG_PARSER <<'PY' || true
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(newline="\n")

MODE = sys.argv[1] if len(sys.argv) > 1 else ""
ALLOWED = set(sys.argv[2:])

def emit(key, value):
    if key in ALLOWED:
        sys.stdout.write("%s\t%s\n" % (key, value))

def fail(message):
    sys.stderr.write("config: error: %s\n" % message)
    sys.exit(2)

def shell_words(text):
    words = []
    i = 0
    n = len(text)
    while i < n:
        while i < n and text[i] in " \t\n\r":
            i += 1
        if i >= n:
            break
        buf = []
        while i < n and text[i] not in " \t\n\r":
            ch = text[i]
            if ch in "'\"":
                quote = ch
                i += 1
                while i < n and text[i] != quote:
                    if quote == '"' and text[i] == "\\":
                        i += 1
                        if i >= n:
                            fail("unterminated escape in a systemd property value")
                        esc = text[i]
                        buf.append({"n": "\n", "t": "\t", "r": "\r"}.get(esc, esc))
                        i += 1
                        continue
                    buf.append(text[i])
                    i += 1
                if i >= n:
                    fail("unterminated quote in a systemd property value")
                i += 1
                continue
            if ch == "\\":
                i += 1
                if i >= n:
                    break
                esc = text[i]
                buf.append({"n": "\n", "t": "\t", "r": "\r"}.get(esc, esc))
                i += 1
                continue
            buf.append(ch)
            i += 1
        words.append("".join(buf))
    return words

def split_assignment(word):
    if "=" not in word:
        return None, None
    key, value = word.split("=", 1)
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
        return None, None
    return key, value

def parse_environment(text):
    for word in shell_words(text):
        key, value = split_assignment(word)
        if key is not None:
            emit(key, value)

def read_env_value(text, i, line):
    n = len(text)
    value = []
    if i < n and text[i] in "'\"":
        quote = text[i]
        i += 1
        while i < n:
            ch = text[i]
            if quote == "'":
                if ch == "'":
                    return "".join(value), i + 1, line
                if ch == "\n":
                    line += 1
                value.append(ch)
                i += 1
                continue
            if ch == '"':
                return "".join(value), i + 1, line
            if ch == "\\":
                i += 1
                if i >= n:
                    fail("unterminated escape in the environment file (line %d)" % line)
                esc = text[i]
                if esc == "\n":
                    line += 1
                    i += 1
                    continue
                value.append({"n": "\n", "t": "\t", "r": "\r"}.get(esc, esc))
                i += 1
                continue
            if ch == "\n":
                line += 1
            value.append(ch)
            i += 1
        fail("unterminated quote in the environment file (line %d)" % line)

    while i < n and text[i] != "\n":
        ch = text[i]
        if ch == "\\":
            i += 1
            if i >= n:
                break
            if text[i] == "\n":
                line += 1
                i += 1
                continue
            value.append(text[i])
            i += 1
            continue
        value.append(ch)
        i += 1
    while value and value[-1] in " \t\r":
        value.pop()
    return "".join(value), i, line

def parse_env_file(text):
    i = 0
    n = len(text)
    line = 1
    while i < n:
        while i < n and text[i] in " \t\r":
            i += 1
        if i >= n:
            break
        if text[i] == "\n":
            i += 1
            line += 1
            continue
        if text[i] in "#;":
            while i < n and text[i] != "\n":
                i += 1
            continue
        start = i
        while i < n and text[i] not in "=\n":
            i += 1
        if i >= n or text[i] == "\n":
            if i < n:
                i += 1
                line += 1
            continue
        key = text[start:i].strip()
        i += 1
        while i < n and text[i] in " \t\r":
            i += 1
        value, i, line = read_env_value(text, i, line)
        while i < n and text[i] in " \t\r":
            i += 1
        if i < n and text[i] != "\n":
            fail("unexpected content after a value in the environment file (line %d)" % line)
        if i < n:
            i += 1
            line += 1
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            if key in ALLOWED:
                emit(key, value)

def split_endpoint(text):
    if text.startswith("["):
        end = text.find("]")
        if end < 0:
            return None, None
        host = text[1:end]
        rest = text[end + 1:]
        if not rest.startswith(":"):
            return None, None
        port = rest[1:]
    else:
        if ":" not in text:
            return None, None
        host, port = text.rsplit(":", 1)
    host = host.split("%", 1)[0]
    if not port.isdigit():
        return None, None
    return host, int(port)

def parse_listeners(pid):
    seen = set()
    for line in sys.stdin:
        fields = line.split()
        if len(fields) < 6 or fields[0] != "LISTEN":
            continue
        process = " ".join(fields[5:])
        if not re.search(r"(?:^|[,(])pid=%d(?:[,)]|$)" % pid, process):
            continue
        host, port = split_endpoint(fields[3])
        if host is None:
            continue
        key = (host, port)
        if key in seen:
            continue
        seen.add(key)
        sys.stdout.write("LISTEN\t%s\t%s\n" % (host, port))

def parse_exec_start(lines):
    modes = set()
    hosts = set()
    ports = set()
    sockets = False
    for line in lines:
        for match in re.finditer(r"argv\[\]=(.*?)(?:\s;\s|\}$)", line):
            argv = match.group(1).split()
            if not argv:
                continue
            mode = "unknown"
            for j, arg in enumerate(argv):
                basename = arg.rsplit("/", 1)[-1]
                if basename == "uvicorn" or (arg == "-m" and j + 1 < len(argv) and argv[j + 1] == "uvicorn"):
                    mode = "uvicorn"
                elif arg.endswith("run_api.py") or arg.rsplit("/", 1)[-1] == "main.py":
                    mode = "app"
            modes.add(mode)
            if mode != "uvicorn":
                continue
            j = 0
            while j < len(argv):
                arg = argv[j]
                if arg in ("--uds", "--fd"):
                    sockets = True
                    j += 1
                    continue
                if arg in ("--host", "--port"):
                    if j + 1 < len(argv):
                        (hosts if arg == "--host" else ports).add(argv[j + 1])
                    j += 2
                    continue
                if arg.startswith("--host="):
                    hosts.add(arg.split("=", 1)[1])
                elif arg.startswith("--port="):
                    ports.add(arg.split("=", 1)[1])
                j += 1
    if len(modes) > 1:
        fail("ExecStart uses more than one launcher type (%s); cannot determine the listener"
             % ", ".join(sorted(modes)))
    print("EXEC_MODE\t%s" % (modes.pop() if modes else "unknown"))
    for host in sorted(hosts):
        print("EXEC_HOST\t%s" % host)
    for port in sorted(ports):
        print("EXEC_PORT\t%s" % port)
    if sockets:
        print("EXEC_SOCKET\t1")

if MODE == "environment":
    parse_environment(sys.stdin.read())
elif MODE == "names":
    for word in shell_words(sys.stdin.read()):
        name = word.split("=", 1)[0]
        if name in ALLOWED:
            sys.stdout.write("%s\n" % name)
elif MODE == "envfile":
    try:
        text = sys.stdin.buffer.read().decode("utf-8")
    except UnicodeDecodeError:
        fail("the environment file is not valid UTF-8")
    parse_env_file(text)
elif MODE == "proc-environ":
    for entry in sys.stdin.buffer.read().split(b"\0"):
        if not entry:
            continue
        key, value = split_assignment(entry.decode("utf-8", "surrogateescape"))
        if key is not None:
            emit(key, value)
elif MODE == "execstart":
    parse_exec_start(sys.stdin.read().splitlines())
elif MODE == "listeners":
    parse_listeners(int(sys.argv[2]))
else:
    fail("unknown parser mode %r" % MODE)

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
  if [ "$status" -ne 0 ] && [ "$CHANGES_POSSIBLE" -eq 1 ] \
    && { [ "$ACTION" = "deploy" ] || [ "$ACTION" = "rollback" ]; }; then
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

# A configuration problem stops a deploy/rollback before anything is changed.
# The status action calls the same resolution in soft mode and reports what it
# could determine.
config_fail() {
  if [ "$CONFIG_STRICT" -eq 1 ]; then
    config_report
    die "$*"
  fi
  note "warning: $*"
}

prop_first() {
  printf '%s\n' "$SERVICE_PROPERTIES" | sed -n "s/^$1=//p" | head -n 1
}

prop_all() {
  printf '%s\n' "$SERVICE_PROPERTIES" | sed -n "s/^$1=//p"
}

# Reads the effective unit metadata and configuration sources. None of this
# needs root: systemctl show is read-only and every value this script uses is
# either unit metadata or one of the allowlisted variables in CONFIG_KEYS.
load_service_properties() {
  local output workdir
  if ! output="$("$SYSTEMCTL" show "$SERVICE" --no-pager \
      -p FragmentPath -p DropInPaths -p User -p Group -p WorkingDirectory \
      -p ActiveState -p MainPID -p Environment -p EnvironmentFiles \
      -p UnsetEnvironment -p PassEnvironment -p ExecStart 2>&1)"; then
    config_fail "cannot read the properties of $SERVICE with systemctl show: $(printf '%s\n' "$output" | head -n 1)"
    return 1
  fi

  SERVICE_PROPERTIES="$output"
  SERVICE_FRAGMENT="$(prop_first FragmentPath)"
  SERVICE_DROPINS="$(prop_all DropInPaths | paste -sd ' ' -)"
  SERVICE_USER="$(prop_first User)"
  SERVICE_GROUP="$(prop_first Group)"
  SERVICE_WORKDIR="$(prop_first WorkingDirectory)"
  SERVICE_ACTIVE="$(prop_first ActiveState)"
  SERVICE_MAINPID="$(prop_first MainPID)"
  if [ -z "$SERVICE_MAINPID" ]; then
    SERVICE_MAINPID=0
  fi

  if [ -z "$SERVICE_FRAGMENT" ] || [ "$SERVICE_ACTIVE" = "not-found" ]; then
    config_fail "systemd does not know $SERVICE (FragmentPath is empty); install the unit from deploy/eqalb-api.service first"
    return 1
  fi
  if [ "$SERVICE_USER" != "$APP_USER" ]; then
    config_fail "$SERVICE runs as user '${SERVICE_USER:-unknown}', not $APP_USER; this script deploys the $APP_USER application account"
    return 1
  fi
  if [ "$SERVICE_GROUP" != "$APP_USER" ]; then
    config_fail "$SERVICE runs as group '${SERVICE_GROUP:-unknown}', not $APP_USER; confirm the service unit before deploying"
    return 1
  fi
  workdir="${SERVICE_WORKDIR#-}"
  if [ "${workdir%/}" != "$PROJECT_DIR" ]; then
    config_fail "$SERVICE has WorkingDirectory='${SERVICE_WORKDIR:-unset}', not $PROJECT_DIR; this script deploys the checkout in $PROJECT_DIR"
    return 1
  fi
  return 0
}

# UnsetEnvironment= and PassEnvironment= are applied after Environment= and
# EnvironmentFile=, so a key named there would make the effective value differ
# from what this script reads. Detect that instead of guessing.
check_unsets_and_passthrough() {
  local prop raw names
  for prop in UnsetEnvironment PassEnvironment; do
    raw="$(prop_first "$prop")"
    if [ -z "$raw" ]; then
      continue
    fi
    if ! names="$(printf '%s\n' "$raw" | "$HEALTH_PYTHON" -c "$CONFIG_PARSER" names "${CONFIG_KEYS[@]}" | paste -sd ' ' -)"; then
      config_fail "cannot parse $prop= from $SERVICE"
      return 1
    fi
    if [ -n "$names" ]; then
      config_fail "$SERVICE uses $prop for: $names. That setting is applied after Environment= and EnvironmentFile=, so this script cannot determine the effective value. Remove those names from $prop or set the EQALB_DEPLOY_* overrides."
      return 1
    fi
  done
  return 0
}

# systemd's Environment= property holds shell-quoted KEY=VALUE tokens. The
# parser emits only the allowlisted keys; any other value is discarded unseen.
collect_environment_property() {
  local raw parsed key value
  raw="$(prop_first Environment)"
  if [ -z "$raw" ]; then
    return 0
  fi
  if ! parsed="$(printf '%s\n' "$raw" | "$HEALTH_PYTHON" -c "$CONFIG_PARSER" environment "${CONFIG_KEYS[@]}")"; then
    config_fail "cannot parse the Environment= property of $SERVICE"
    return 1
  fi
  while IFS=$'\t' read -r key value; do
    if [ -z "$key" ]; then
      continue
    fi
    CONFIG_ENV["$key"]="$value"
    CONFIG_SOURCE["$key"]="unit Environment="
  done <<< "$parsed"
  return 0
}

# systemd's EnvironmentFiles= property is a list of (path, ignore_errors)
# entries. Each file is parsed as data with the documented EnvironmentFile
# rules; it is never sourced. Settings from these files override Environment=,
# and later files override earlier ones, which is why they are applied in order.
collect_environment_files() {
  local spec ignore path parsed key value
  local -a specs=()
  # prop_all already strips the "EnvironmentFiles=" prefix; each line is one
  # "<path> (ignore_errors=yes|no)" entry.
  while IFS= read -r spec; do
    if [ -n "$spec" ]; then
      specs+=("$spec")
    fi
  done < <(prop_all EnvironmentFiles)

  if [ "${#specs[@]}" -eq 0 ]; then
    return 0
  fi

  for spec in "${specs[@]}"; do
    ignore=no
    case "$spec" in
      *" (ignore_errors=yes)")
        ignore=yes
        spec="${spec% (ignore_errors=yes)}"
        ;;
      *" (ignore_errors=no)")
        spec="${spec% (ignore_errors=no)}"
        ;;
    esac
    path="$spec"

    case "$path" in
      *%*)
        config_fail "the unit declares EnvironmentFile=$path, which uses a systemd specifier. This script does not expand specifiers; make the path literal or set the EQALB_DEPLOY_* overrides."
        return 1
        ;;
      /*) ;;
      *)
        config_fail "the unit declares a non-absolute EnvironmentFile '$path'; systemd requires an absolute path"
        return 1
        ;;
    esac

    if [ ! -e "$path" ]; then
      if [ "$ignore" = "yes" ]; then
        note "note: optional EnvironmentFile $path does not exist; systemd ignores it and so does this script"
        continue
      fi
      config_fail "the unit requires EnvironmentFile $path, but it does not exist; $SERVICE would fail to start"
      return 1
    fi

    if ! run_as_app test -r "$path"; then
      config_fail "EnvironmentFile $path is not readable by $APP_USER. This script reads it as $APP_USER, never as root. Grant $APP_USER read access (deploy/DEPLOY.md uses root:$APP_USER 0640) or set the EQALB_DEPLOY_* overrides."
      return 1
    fi

    if ! parsed="$(run_as_app cat -- "$path" | "$HEALTH_PYTHON" -c "$CONFIG_PARSER" envfile "${CONFIG_KEYS[@]}")"; then
      config_fail "cannot parse EnvironmentFile $path; the parser reported the line number above. Fix its quoting or continuation before deploying."
      return 1
    fi

    while IFS=$'\t' read -r key value; do
      if [ -z "$key" ]; then
        continue
      fi
      CONFIG_ENV["$key"]="$value"
      CONFIG_SOURCE["$key"]="EnvironmentFile $path"
    done <<< "$parsed"
  done
  return 0
}

# The running process environment is read as the service user (it owns the
# process) from /proc/PID/environ. It is used only for the allowlisted keys and
# only to cross-check the configuration, because it shows what is running now
# rather than what systemd will apply on the next start.
load_runtime_environment() {
  RUNTIME_AVAILABLE=0
  if [ "$SERVICE_ACTIVE" != "active" ]; then
    return 0
  fi
  if ! [[ "$SERVICE_MAINPID" =~ ^[0-9]+$ ]]; then
    return 0
  fi
  if [ "$SERVICE_MAINPID" -le 1 ]; then
    return 0
  fi
  if ! run_as_app test -r "/proc/$SERVICE_MAINPID/environ"; then
    note "note: /proc/$SERVICE_MAINPID/environ is not readable as $APP_USER; the running environment cannot be cross-checked"
    return 0
  fi

  local parsed key value
  if ! parsed="$(run_as_app cat -- "/proc/$SERVICE_MAINPID/environ" | "$HEALTH_PYTHON" -c "$CONFIG_PARSER" proc-environ "${CONFIG_KEYS[@]}")"; then
    note "note: the running environment of $SERVICE could not be read; it is not cross-checked"
    return 0
  fi
  RUNTIME_AVAILABLE=1
  while IFS=$'\t' read -r key value; do
    if [ -z "$key" ]; then
      continue
    fi
    RUNTIME_ENV["$key"]="$value"
  done <<< "$parsed"
  return 0
}

# ExecStart determines which launcher runs and therefore how the listener is
# chosen. api/main.py and api/run_api.py read EQALB_API_HOST/PORT and default
# to 127.0.0.1:8788; a uvicorn command line reads --host/--port and
# UVICORN_HOST/UVICORN_PORT and defaults to 127.0.0.1:8000.
load_exec_start() {
  EXEC_MODE="unknown"
  EXEC_HOST=""
  EXEC_PORT=""
  EXEC_SOCKET=0

  local raw parsed key value
  raw="$(prop_all ExecStart)"
  if [ -z "$raw" ]; then
    return 0
  fi
  if ! parsed="$(printf '%s\n' "$raw" | "$HEALTH_PYTHON" -c "$CONFIG_PARSER" execstart)"; then
    config_fail "cannot parse ExecStart= from $SERVICE. Make the launcher a supported uvicorn or run_api.py command, or set EQALB_DEPLOY_API_HOST/EQALB_DEPLOY_API_PORT explicitly."
    return 1
  fi
  while IFS=$'\t' read -r key value; do
    case "$key" in
      EXEC_MODE) EXEC_MODE="$value" ;;
      EXEC_HOST)
        if [ -n "$EXEC_HOST" ] && [ "$EXEC_HOST" != "$value" ]; then
          config_fail "ExecStart declares conflicting --host values ('$EXEC_HOST' and '$value')"
          return 1
        fi
        EXEC_HOST="$value"
        ;;
      EXEC_PORT)
        if [ -n "$EXEC_PORT" ] && [ "$EXEC_PORT" != "$value" ]; then
          config_fail "ExecStart declares conflicting --port values ('$EXEC_PORT' and '$value')"
          return 1
        fi
        EXEC_PORT="$value"
        ;;
      EXEC_SOCKET) EXEC_SOCKET=1 ;;
    esac
  done <<< "$parsed"

  if [ "$EXEC_SOCKET" -eq 1 ]; then
    config_fail "$SERVICE passes --uds/--fd to uvicorn, so it does not listen on TCP and GET /api/health cannot be used. This deployment supports a loopback TCP listener only."
    return 1
  fi
  return 0
}

lookup_in_path() {
  local name=$1 path_value=$2 candidate dir
  local -a dirs=()
  local found=""
  local count=0

  IFS=: read -r -a dirs <<< "$path_value"
  for dir in "${dirs[@]}"; do
    if [ -z "$dir" ]; then
      dir="."
    fi
    candidate="${dir%/}/$name"
    if [ -x "$candidate" ] && [ ! -d "$candidate" ]; then
      count=$((count + 1))
      if [ -z "$found" ]; then
        found="$candidate"
      fi
    fi
  done

  if [ -z "$found" ]; then
    return 1
  fi
  if [ "$count" -gt 1 ]; then
    note "note: $count candidates for $name exist on the service PATH; using the first, $found, as shutil.which() would"
  fi
  printf '%s\n' "$found"
}

# Resolves the R that the service will use after the restart, not merely a
# convenient one: EQALB_RSCRIPT when configured, otherwise the same PATH lookup
# api/r_client.py performs. The version is checked against the target commit's
# renv.lock later, before the service is restarted.
resolve_rscript() {
  local rscript="" source="" service_path="" path_source="" version_output=""
  local lock_r=""

  if [ -n "$RSCRIPT_OVERRIDE" ]; then
    rscript="$RSCRIPT_OVERRIDE"
    source="EQALB_DEPLOY_RSCRIPT override"
  elif [ -n "${CONFIG_ENV[EQALB_RSCRIPT]:-}" ]; then
    rscript="${CONFIG_ENV[EQALB_RSCRIPT]}"
    source="${CONFIG_SOURCE[EQALB_RSCRIPT]}"
  fi

  if [ -n "${CONFIG_ENV[PATH]:-}" ]; then
    service_path="${CONFIG_ENV[PATH]}"
    path_source="${CONFIG_SOURCE[PATH]}"
  elif [ -n "${RUNTIME_ENV[PATH]:-}" ]; then
    service_path="${RUNTIME_ENV[PATH]}"
    path_source="the running service environment"
  fi

  if [ -z "$rscript" ]; then
    if [ -z "$service_path" ]; then
      config_fail "EQALB_RSCRIPT is not set in the unit configuration or an environment file, and the service PATH cannot be determined (the service is not running or its environment is unreadable). Set EQALB_RSCRIPT or provide EQALB_DEPLOY_RSCRIPT."
      return 1
    fi
    if ! rscript="$(lookup_in_path Rscript "$service_path")"; then
      config_fail "EQALB_RSCRIPT is not set and no executable Rscript is on the service PATH ($service_path). Set EQALB_RSCRIPT to the R binary the project requires."
      return 1
    fi
    source="service PATH ($path_source)"
  fi

  case "$rscript" in
    /*) ;;
    *)
      config_fail "the resolved R executable '$rscript' is not an absolute path; api/r_client.py needs a usable absolute path on the server"
      return 1
      ;;
  esac
  if ! run_as_app test -x "$rscript"; then
    config_fail "the resolved R executable $rscript is not executable by $APP_USER"
    return 1
  fi

  if ! version_output="$(run_as_app "$rscript" --version 2>&1)"; then
    config_fail "the resolved R executable $rscript could not be run as $APP_USER: $(printf '%s\n' "$version_output" | head -n 1)"
    return 1
  fi
  RESOLVED_R_VERSION="$(printf '%s\n' "$version_output" \
    | sed -n 's/.* \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n 1)"
  if [ -z "$RESOLVED_R_VERSION" ]; then
    config_fail "cannot determine the R version reported by $rscript"
    return 1
  fi

  RESOLVED_RSCRIPT="$rscript"
  RESOLVED_RSCRIPT_SOURCE="$source"

  if [ "$RUNTIME_AVAILABLE" -eq 1 ] && [ -n "${RUNTIME_ENV[EQALB_RSCRIPT]:-}" ]; then
    if [ "${RUNTIME_ENV[EQALB_RSCRIPT]}" != "$rscript" ]; then
      config_fail "the running service uses EQALB_RSCRIPT=${RUNTIME_ENV[EQALB_RSCRIPT]}, but a restart would use $rscript ($source). Reconcile the unit or EnvironmentFile before deploying."
    fi
  fi

  if lock_r="$(run_as_app cat -- "$PROJECT_DIR/renv.lock" 2>/dev/null \
      | grep -m 1 -o '"Version"[[:space:]]*:[[:space:]]*"[^"]*"' \
      | sed 's/.*"\([^"]*\)"$/\1/')" && [ -n "$lock_r" ]; then
    if [ "$lock_r" != "$RESOLVED_R_VERSION" ]; then
      note "warning: the current checkout's renv.lock records R $lock_r, but the service R is $RESOLVED_R_VERSION; the target commit's renv.lock is checked before the restart"
    fi
  fi
  return 0
}

# Finds the TCP socket the service main process is listening on. Run as the
# service user, ss can attribute the service's own sockets without root. This
# is evidence about the running listener, used to cross-check the configuration
# and to fill in a port that the configuration does not state.
observe_listeners() {
  local need_observation=$1
  OBSERVED_HOSTS=()
  OBSERVED_PORTS=()
  if [ "$SERVICE_ACTIVE" != "active" ]; then
    return 0
  fi
  if [ -z "$SS" ]; then
    if [ "$need_observation" -eq 1 ]; then
      config_fail "ss is not available, so the listener of the running service cannot be observed. Install iproute2 or set EQALB_DEPLOY_API_PORT explicitly."
      return 1
    fi
    note "note: ss is not available; the configured listener cannot be cross-checked against the running service"
    return 0
  fi

  local parsed tag host port
  local -a ports=()
  if ! parsed="$(run_as_app "$SS" -ltnp 2>/dev/null | "$HEALTH_PYTHON" -c "$CONFIG_PARSER" listeners "$SERVICE_MAINPID")"; then
    config_fail "cannot inspect the listening sockets of PID $SERVICE_MAINPID"
    return 1
  fi
  while IFS=$'\t' read -r tag host port; do
    if [ "$tag" != "LISTEN" ]; then
      continue
    fi
    OBSERVED_HOSTS+=("$host")
    ports+=("$port")
  done <<< "$parsed"

  if [ "${#ports[@]}" -eq 0 ]; then
    return 0
  fi
  mapfile -t OBSERVED_PORTS < <(printf '%s\n' "${ports[@]}" | sort -u)
  if [ "${#OBSERVED_PORTS[@]}" -gt 1 ]; then
    config_fail "PID $SERVICE_MAINPID holds more than one TCP listener (ports: ${OBSERVED_PORTS[*]}); set EQALB_DEPLOY_API_PORT to the port that serves /api"
    return 1
  fi
  return 0
}

check_runtime_key() {
  local severity=$1 key=$2 resolved=$3 source=$4 label=$5 runtime
  runtime="${RUNTIME_ENV[$key]:-}"
  if [ -z "$runtime" ]; then
    return 0
  fi
  if [ "$runtime" = "$resolved" ]; then
    return 0
  fi
  if [ "$severity" = "fail" ]; then
    config_fail "the running service has $key=$runtime, but the resolved $label is $resolved ($source); a restart would change it. Reconcile the unit or set the EQALB_DEPLOY_* override."
  else
    note "warning: the running service has $key=$runtime, but the resolved $label is $resolved ($source); the launcher type is not recognised, so this is reported without blocking"
  fi
}

# Resolves the listener the restarted service will use. Configuration beats
# observation; observation fills in a value the configuration does not state;
# a disagreement between the two is a stop, because a restart would move the
# listener and Caddy would lose its upstream.
resolve_listener() {
  local host="" port="" host_source="" port_source="" observed_port=""

  case "$EXEC_MODE" in
    uvicorn)
      if [ -n "$EXEC_HOST" ]; then
        host="$EXEC_HOST"; host_source="ExecStart --host"
      elif [ -n "${CONFIG_ENV[UVICORN_HOST]:-}" ]; then
        host="${CONFIG_ENV[UVICORN_HOST]}"; host_source="${CONFIG_SOURCE[UVICORN_HOST]}"
      else
        host="$DEFAULT_UVICORN_HOST"; host_source="uvicorn command-line default"
      fi
      if [ -n "$EXEC_PORT" ]; then
        port="$EXEC_PORT"; port_source="ExecStart --port"
      elif [ -n "${CONFIG_ENV[UVICORN_PORT]:-}" ]; then
        port="${CONFIG_ENV[UVICORN_PORT]}"; port_source="${CONFIG_SOURCE[UVICORN_PORT]}"
      else
        port="$DEFAULT_UVICORN_PORT"; port_source="uvicorn command-line default"
      fi
      if [ -n "${CONFIG_ENV[EQALB_API_HOST]:-}" ] || [ -n "${CONFIG_ENV[EQALB_API_PORT]:-}" ]; then
        note "note: EQALB_API_HOST/EQALB_API_PORT are set, but the unit starts the uvicorn command line, which does not read them; --host/--port and UVICORN_HOST/UVICORN_PORT control this listener"
      fi
      ;;
    app)
      if [ -n "${CONFIG_ENV[EQALB_API_HOST]:-}" ]; then
        host="${CONFIG_ENV[EQALB_API_HOST]}"; host_source="${CONFIG_SOURCE[EQALB_API_HOST]}"
      else
        host="$DEFAULT_APP_HOST"; host_source="api/main.py default"
      fi
      if [ -n "${CONFIG_ENV[EQALB_API_PORT]:-}" ]; then
        port="${CONFIG_ENV[EQALB_API_PORT]}"; port_source="${CONFIG_SOURCE[EQALB_API_PORT]}"
      else
        port="$DEFAULT_APP_PORT"; port_source="api/main.py default"
      fi
      if [ -n "$EXEC_HOST$EXEC_PORT" ]; then
        note "note: ExecStart passes --host/--port, but the run_api.py launcher ignores command-line arguments; EQALB_API_* controls this listener"
      fi
      ;;
    *)
      if [ -n "${CONFIG_ENV[EQALB_API_HOST]:-}" ]; then
        host="${CONFIG_ENV[EQALB_API_HOST]}"; host_source="${CONFIG_SOURCE[EQALB_API_HOST]}"
      elif [ -n "${CONFIG_ENV[UVICORN_HOST]:-}" ]; then
        host="${CONFIG_ENV[UVICORN_HOST]}"; host_source="${CONFIG_SOURCE[UVICORN_HOST]}"
      fi
      if [ -n "${CONFIG_ENV[EQALB_API_PORT]:-}" ]; then
        port="${CONFIG_ENV[EQALB_API_PORT]}"; port_source="${CONFIG_SOURCE[EQALB_API_PORT]}"
      elif [ -n "${CONFIG_ENV[UVICORN_PORT]:-}" ]; then
        port="${CONFIG_ENV[UVICORN_PORT]}"; port_source="${CONFIG_SOURCE[UVICORN_PORT]}"
      fi
      ;;
  esac

  if [ -n "$API_HOST_OVERRIDE" ]; then
    host="$API_HOST_OVERRIDE"; host_source="EQALB_DEPLOY_API_HOST override"
  fi
  if [ -n "$API_PORT_OVERRIDE" ]; then
    port="$API_PORT_OVERRIDE"; port_source="EQALB_DEPLOY_API_PORT override"
  fi

  local need_observation=0
  if [ -z "$port" ]; then
    need_observation=1
  fi
  if ! observe_listeners "$need_observation"; then
    return 1
  fi

  if [ "${#OBSERVED_PORTS[@]}" -gt 0 ]; then
    observed_port="${OBSERVED_PORTS[0]}"
    if [ -n "$port" ] && [ "$port" != "$observed_port" ]; then
      config_fail "the unit configuration resolves port $port ($port_source), but the running service listens on $observed_port. A restart would move the listener; reconcile the unit or set EQALB_DEPLOY_API_PORT=$observed_port deliberately."
      return 1
    fi
    if [ -z "$port" ]; then
      port="$observed_port"
      port_source="observed listener (ss)"
    fi
    if [ -z "$host" ] && [ "${#OBSERVED_HOSTS[@]}" -gt 0 ]; then
      host="${OBSERVED_HOSTS[0]}"
      host_source="observed listener (ss)"
    fi
  fi

  if [ -z "$port" ] || [ -z "$host" ]; then
    if [ "$SERVICE_ACTIVE" = "active" ]; then
      config_fail "cannot determine the API listener: host='${host}', port='${port}', and no single TCP listener was observed for PID $SERVICE_MAINPID. Run the read-only commands below, then set EQALB_DEPLOY_API_HOST/EQALB_DEPLOY_API_PORT explicitly."
    else
      config_fail "cannot determine the API listener while $SERVICE is not active: host='${host}', port='${port}'. Start the service once, or set EQALB_DEPLOY_API_HOST/EQALB_DEPLOY_API_PORT explicitly."
    fi
    return 1
  fi

  if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    config_fail "the resolved API port '$port' is not a TCP port (source: $port_source)"
    return 1
  fi
  case "$host" in
    *[[:space:]]*)
      config_fail "the resolved API host '$host' contains whitespace"
      return 1
      ;;
  esac

  # Only the setting that actually selects the listener is compared. For a
  # uvicorn command line, --host/--port override the UVICORN_* variables, so an
  # overridden variable is not a disagreement.
  case "$EXEC_MODE" in
    uvicorn)
      if [ -z "$EXEC_HOST" ]; then
        check_runtime_key fail UVICORN_HOST "$host" "$host_source" "host"
      fi
      if [ -z "$EXEC_PORT" ]; then
        check_runtime_key fail UVICORN_PORT "$port" "$port_source" "port"
      fi
      ;;
    app)
      check_runtime_key fail EQALB_API_HOST "$host" "$host_source" "host"
      check_runtime_key fail EQALB_API_PORT "$port" "$port_source" "port"
      ;;
    *)
      check_runtime_key warn EQALB_API_HOST "$host" "$host_source" "host"
      check_runtime_key warn EQALB_API_PORT "$port" "$port_source" "port"
      check_runtime_key warn UVICORN_HOST "$host" "$host_source" "host"
      check_runtime_key warn UVICORN_PORT "$port" "$port_source" "port"
      ;;
  esac

  local probe_host="$host"
  case "$host" in
    0.0.0.0|"*"|"") probe_host="127.0.0.1" ;;
    "::"|"[::]") probe_host="::1" ;;
    "::ffff:127.0.0.1"|"[::ffff:127.0.0.1]") probe_host="127.0.0.1" ;;
    \[*\])
      probe_host="${host#\[}"
      probe_host="${probe_host%\]}"
      ;;
  esac
  case "$probe_host" in
    127.*|::1|localhost) ;;
    *)
      note "warning: the service is configured to listen on $host, not loopback; deploy/DEPLOY.md expects 127.0.0.1 behind Caddy"
      ;;
  esac
  case "$probe_host" in
    *:*) HEALTH_URL="http://[${probe_host}]:${port}/api/health" ;;
    *) HEALTH_URL="http://${probe_host}:${port}/api/health" ;;
  esac

  RESOLVED_API_HOST="$host"
  RESOLVED_API_HOST_SOURCE="$host_source"
  RESOLVED_API_PORT="$port"
  RESOLVED_API_PORT_SOURCE="$port_source"
  return 0
}

resolve_workers() {
  local value="" source=""
  if [ -n "${CONFIG_ENV[EQALB_R_WORKERS]:-}" ]; then
    value="${CONFIG_ENV[EQALB_R_WORKERS]}"
    source="${CONFIG_SOURCE[EQALB_R_WORKERS]}"
  else
    value="$DEFAULT_WORKERS"
    source="application default (api/r_client.py)"
  fi
  if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ]; then
    config_fail "EQALB_R_WORKERS resolves to '$value' ($source), which is not a positive integer"
    return 1
  fi
  if [ "$RUNTIME_AVAILABLE" -eq 1 ] && [ -n "${RUNTIME_ENV[EQALB_R_WORKERS]:-}" ]; then
    if [ "${RUNTIME_ENV[EQALB_R_WORKERS]}" != "$value" ]; then
      note "warning: the running service uses EQALB_R_WORKERS=${RUNTIME_ENV[EQALB_R_WORKERS]}, but the unit configuration resolves $value ($source); a restart will change the worker count"
    fi
  fi
  RESOLVED_WORKERS="$value"
  RESOLVED_WORKERS_SOURCE="$source"
  return 0
}

# Prints only allowlisted setting values and unit metadata. Any other variable
# in Environment= or an environment file is never read out.
config_report() {
  local names="" key
  note "service configuration:"
  note "  unit: ${SERVICE_FRAGMENT:-unknown}"
  note "  drop-ins: ${SERVICE_DROPINS:-none}"
  note "  user/group: ${SERVICE_USER:-unknown}/${SERVICE_GROUP:-unknown}, working directory ${SERVICE_WORKDIR:-unknown}"
  note "  state: ${SERVICE_ACTIVE:-unknown}, main PID ${SERVICE_MAINPID:-unknown}"
  for key in "${CONFIG_KEYS[@]}"; do
    if [ -n "${CONFIG_ENV[$key]:-}" ]; then
      names="$names $key"
    fi
  done
  note "  variables read from Environment=/EnvironmentFiles=:${names:- none}"
  note "  launcher: $EXEC_MODE"
  note "  R: ${RESOLVED_RSCRIPT:-unresolved} (${RESOLVED_RSCRIPT_SOURCE:-unknown source}), version ${RESOLVED_R_VERSION:-unknown}"
  note "  listener: ${RESOLVED_API_HOST:-unresolved}:${RESOLVED_API_PORT:-unresolved} (${RESOLVED_API_HOST_SOURCE:-unknown} / ${RESOLVED_API_PORT_SOURCE:-unknown})"
  note "  workers: ${RESOLVED_WORKERS:-unresolved} (${RESOLVED_WORKERS_SOURCE:-unknown})"
  note "  observed TCP listeners: hosts ${OBSERVED_HOSTS[*]:-none}; ports ${OBSERVED_PORTS[*]:-none}"
}

config_diagnostics() {
  note "read-only commands to confirm an unresolved setting (they may contain server-local values; do not paste them into a public issue):"
  note "  systemctl show $SERVICE -p FragmentPath -p DropInPaths -p User -p Group -p WorkingDirectory -p ActiveState -p MainPID -p Environment -p EnvironmentFiles -p UnsetEnvironment -p PassEnvironment -p ExecStart"
  note "  systemctl cat $SERVICE"
  note "  sudo -u $APP_USER ss -ltnp"
}

resolve_service_configuration() {
  load_service_properties || true
  check_unsets_and_passthrough || true
  collect_environment_property || true
  collect_environment_files || true
  load_runtime_environment || true
  load_exec_start || true
  resolve_rscript || true
  resolve_listener || true
  resolve_workers || true
  config_report
}

# The service is running before the deployment, so its listener must answer
# before anything is checked out. A degraded response is reported but does not
# block: a deployment may be the recovery. A listener that does not answer is a
# stop, because the resolved endpoint would be unproven.
probe_current_health() {
  if [ "$SERVICE_ACTIVE" != "active" ]; then
    note "note: $SERVICE is not active; the pre-restart health probe is skipped"
    return 0
  fi
  local out="" status=0
  out="$(health_probe)" || status=$?
  case "$status" in
    0) note "current deployment health: $out" ;;
    1) note "warning: the current deployment is running but degraded: $out"; note "the deployment continues; the post-restart health check must pass" ;;
    3)
      config_diagnostics
      config_fail "the service is active but GET $HEALTH_URL did not respond ($out). The resolved listener is unproven, so the deployment stops before checkout, dependency installation and restart."
      ;;
    *)
      config_diagnostics
      config_fail "GET $HEALTH_URL answered, but not with a valid health document ($out). The resolved listener is unproven, so the deployment stops before checkout, dependency installation and restart."
      ;;
  esac
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

  run_as_app test -w "$PROJECT_DIR" \
    || die "$APP_USER cannot write $PROJECT_DIR"

  # Everything below is read-only and happens before checkout, dependency
  # installation or restart. A failure here changes nothing on the server.
  resolve_service_configuration
  probe_current_health

  if [ "$SERVICE_ACTIVE" = "active" ]; then
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
  if [ -z "$RESOLVED_RSCRIPT" ]; then
    die "no R executable was resolved for $SERVICE; the deployment cannot restore renv"
  fi
  required_r="$(run_as_app cat "$PROJECT_DIR/renv.lock" \
    | grep -m 1 -o '"Version"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | sed 's/.*"\([^"]*\)"$/\1/')"
  [ -n "$required_r" ] || die "could not read the R version from renv.lock"
  actual_r="$(run_as_app "$RESOLVED_RSCRIPT" --version 2>&1 \
    | sed -n 's/.* \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' \
    | head -n 1)"
  [ "$actual_r" = "$required_r" ] \
    || die "R is ${actual_r:-unknown}, but renv.lock requires $required_r ($RESOLVED_RSCRIPT)"

  note "restoring the renv library with R $actual_r from $RESOLVED_RSCRIPT"
  ( cd "$PROJECT_DIR" && run_as_app "$RESOLVED_RSCRIPT" -e 'renv::restore(prompt = FALSE)' ) \
    || die "renv::restore failed; do not restart the service over an incomplete restore"
  note "checking that renv.lock and the project library are synchronized"
  ( cd "$PROJECT_DIR" && run_as_app "$RESOLVED_RSCRIPT" -e \
    'status <- renv::status(); if (!isTRUE(status[["synchronized"]])) { print(status); quit(status = 1) }' ) \
    || die "renv::status reports that the library is not synchronized with renv.lock"
}

# Returns 0 for a healthy response, 1 for a response that is not healthy, and 3
# when the endpoint did not answer at all. Callers treat "no answer" and
# "degraded" differently: a deployment can recover a degraded service, but it
# must not restart one whose listener it cannot prove.
health_probe() {
  local body
  if [ -z "$HEALTH_URL" ]; then
    printf 'no health URL was resolved'
    return 3
  fi
  if ! body="$("$CURL" -sS --max-time 15 --connect-timeout 5 "$HEALTH_URL" 2>/dev/null)"; then
    printf 'GET %s failed' "$HEALTH_URL"
    return 3
  fi
  printf '%s' "$body" | "$HEALTH_PYTHON" -c "$HEALTH_PARSER" 2>&1
  return "${PIPESTATUS[1]}"
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

  local deadline message last_error="" status=0
  deadline=$(( $(date +%s) + HEALTH_TIMEOUT ))
  while :; do
    status=0
    message="$(health_probe)" || status=$?
    if [ "$status" -eq 0 ]; then
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

  # The current health was probed, and the listener proven to answer, in the
  # read-only preflight. All dependency work happens before the restart, so a
  # failed install leaves
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

# Used by status only. Prints "readable", "absent" or "inaccessible" for a state
# file. A path is "absent" only when its directory can be searched and it is not
# there; when permissions hide whether it exists, it is "inaccessible".
path_access() {
  local path=$1 parent
  if [ -e "$path" ]; then
    if [ -r "$path" ]; then printf 'readable'; else printf 'inaccessible'; fi
    return 0
  fi
  parent="$(dirname -- "$path")"
  if [ "$parent" = "$path" ]; then
    printf 'absent'
  elif [ -d "$parent" ]; then
    if [ -x "$parent" ]; then printf 'absent'; else printf 'inaccessible'; fi
  elif [ -e "$parent" ]; then
    printf 'absent'  # the parent is a file, so nothing can exist beneath it
  else
    path_access "$parent"
  fi
}

show_status() {
  local head="" active="unknown" message="" status=0
  local state_access pending_access state_unset="none" pending_unset="none"

  # Status may be run by an account that cannot read the deploy user's state;
  # deploy and rollback refuse to start in that case (see preflight). Unreadable
  # state is reported as unknown rather than as no deployment.
  state_access="$(path_access "$STATE_FILE")"
  pending_access="$(path_access "$PENDING_FILE")"
  if [ "$state_access" = "readable" ]; then
    read_state
  elif [ "$state_access" = "inaccessible" ]; then
    state_unset="unknown"
  fi
  if [ "$pending_access" = "readable" ]; then
    read_pending
  elif [ "$pending_access" = "inaccessible" ]; then
    pending_unset="unknown"
  fi
  if [ "$state_access" = "inaccessible" ] || [ "$pending_access" = "inaccessible" ]; then
    note "the deployment state in $STATE_DIR cannot be read by the current account, so it is reported as unknown."
    note "run status as the SSH deploy account that owns $STATE_DIR, or read those files with that account's privileges."
  fi
  if sudo -n -u "$APP_USER" -- true 2>/dev/null; then
    head="$(run_as_app "$GIT" -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || true)"
  fi
  if "$SYSTEMCTL" is-active --quiet "$SERVICE" 2>/dev/null; then
    active="active"
  else
    active="inactive"
  fi

  CONFIG_STRICT=0
  resolve_service_configuration || true
  if [ -n "$HEALTH_URL" ]; then
    status=0
    message="$(health_probe)" || status=$?
    if [ "$status" -eq 3 ] && [ -z "$message" ]; then
      message="no response"
    fi
  else
    message="not resolved"
  fi

  printf 'CURRENT_SHA=%s\n' "${CURRENT_SHA:-$state_unset}"
  printf 'CURRENT_DEPLOYED_AT=%s\n' "${CURRENT_DEPLOYED_AT:-unknown}"
  printf 'PREVIOUS_SHA=%s\n' "${PREVIOUS_SHA:-$state_unset}"
  printf 'PREVIOUS_DEPLOYED_AT=%s\n' "${PREVIOUS_DEPLOYED_AT:-unknown}"
  printf 'PENDING_SHA=%s\n' "${PENDING_SHA:-$pending_unset}"
  printf 'PENDING_ACTION=%s\n' "${PENDING_ACTION:-$pending_unset}"
  printf 'PENDING_AT=%s\n' "${PENDING_AT:-unknown}"
  printf 'PENDING_BASE_SHA=%s\n' "${PENDING_BASE_SHA:-$pending_unset}"
  printf 'CHECKOUT_HEAD=%s\n' "${head:-unknown}"
  printf 'SERVICE=%s\n' "$active"
  printf 'SERVICE_UNIT=%s\n' "${SERVICE_FRAGMENT:-unknown}"
  printf 'R_SCRIPT=%s\n' "${RESOLVED_RSCRIPT:-unresolved}"
  printf 'R_VERSION=%s\n' "${RESOLVED_R_VERSION:-unknown}"
  printf 'LISTENER=%s\n' "$(printf '%s:%s' "${RESOLVED_API_HOST:-unresolved}" "${RESOLVED_API_PORT:-unresolved}")"
  printf 'LISTENER_SOURCE=%s\n' "${RESOLVED_API_HOST_SOURCE:-unknown}/${RESOLVED_API_PORT_SOURCE:-unknown}"
  printf 'WORKERS=%s\n' "${RESOLVED_WORKERS:-unresolved}"
  printf 'HEALTH_URL=%s\n' "${HEALTH_URL:-unresolved}"
  printf 'HEALTH=%s\n' "$message"
  printf 'STATE_FILE=%s\n' "$STATE_FILE"
  printf 'STATE_ACCESS=%s\n' "$state_access"
  printf 'PENDING_ACCESS=%s\n' "$pending_access"
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
      SS="$(command -v ss || true)"
      CONFIG_STRICT=1
      ACTION="deploy"
      preflight
      CHANGES_POSSIBLE=1
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
      SS="$(command -v ss || true)"
      CONFIG_STRICT=1
      ACTION="rollback"
      preflight
      CHANGES_POSSIBLE=1
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
      SS="$(command -v ss || true)"
      if [ -z "$GIT" ] || [ -z "$CURL" ] || [ -z "$SYSTEMCTL" ] || [ -z "$HEALTH_PYTHON" ]; then
        die "status requires git, curl, systemctl and python3 on PATH"
      fi
      CONFIG_STRICT=0
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
