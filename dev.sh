#!/usr/bin/env bash
#
# dev.sh - one-command control for the three local eQalb development services.
#
#   ./dev.sh start          start whatever is not already running
#   ./dev.sh stop           stop the services this script recorded
#   ./dev.sh restart        stop, wait, start
#   ./dev.sh status         running state, URLs and endpoint reachability
#   ./dev.sh logs [which] [lines]
#                           latest output (which: r | api | vue, default all)
#
# The three services, and the launcher each one uses:
#   r     R Plumber API      http://127.0.0.1:8788    Rscript api/run_api.R
#   api   FastAPI model API  http://127.0.0.1:8000    api/.venv/Scripts/python.exe api/run_api.py
#   vue   Vue dev server     http://127.0.0.1:5173    npm run dev (in frontend/)
#
# Why FastAPI is on 8000: api/run_api.py normally uses 8788, which is the same
# port as the plumber service, so in the published setup only one of the two can
# run at a time. This script runs FastAPI on 8000 (uvicorn's own default) so both
# APIs are available side by side, and points the Vue dev-server proxy at FastAPI
# because that is the primary service (it returns JSON `null` for values R could
# not compute, which the interface relies on; the plain plumber service reports
# those as the string "NA"). Override with R_PORT, API_PORT and VUE_PORT.
#
# Safety: this script only starts the existing launchers and only stops the
# process ids it recorded (or, if .dev.pids is missing, the listeners on those
# three development ports). It never touches R model logic, api/plumber.R,
# app.R, the Shiny app or the Vue sources, and it never uses ports 80 or 443.
# Process ids go to .dev.pids and output to .dev-logs/; both are git-ignored.
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$ROOT/.dev-logs"
PID_FILE="$ROOT/.dev.pids"

R_PORT="${R_PORT:-8788}"
API_PORT="${API_PORT:-8000}"
VUE_PORT="${VUE_PORT:-5173}"

R_URL="http://127.0.0.1:$R_PORT"
API_URL="http://127.0.0.1:$API_PORT"
VUE_URL="http://127.0.0.1:$VUE_PORT"

SERVICES="r api vue"

# --- Small helpers -----------------------------------------------------------

is_windows() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW* | MSYS* | CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

service_label() {
  case "$1" in
    r) echo "R Plumber API" ;;
    api) echo "FastAPI model API" ;;
    vue) echo "Vue dev server" ;;
    *) echo "$1" ;;
  esac
}

service_url() {
  case "$1" in
    r) echo "$R_URL" ;;
    api) echo "$API_URL" ;;
    vue) echo "$VUE_URL" ;;
  esac
}

service_port() {
  case "$1" in
    r) echo "$R_PORT" ;;
    api) echo "$API_PORT" ;;
    vue) echo "$VUE_PORT" ;;
  esac
}

service_log() {
  case "$1" in
    r) echo "$LOG_DIR/r.log" ;;
    api) echo "$LOG_DIR/api.log" ;;
    vue) echo "$LOG_DIR/vue.log" ;;
  esac
}

info() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }

# Process id currently listening on a port, or nothing. Only ever used for the
# three development ports above.
port_pid() {
  local port="$1"
  if is_windows; then
    netstat -ano 2>/dev/null |
      awk -v p=":$port\$" '$1 == "TCP" && $2 ~ p && $4 == "LISTENING" { print $5; exit }'
  elif command -v lsof >/dev/null 2>&1; then
    lsof -ti tcp:"$port" -sTCP:LISTEN 2>/dev/null | head -n 1
  elif command -v ss >/dev/null 2>&1; then
    ss -ltnp 2>/dev/null | awk -v p=":$port" '$4 ~ p { print $NF }' |
      grep -o '[0-9]\+' | head -n 1
  fi
}

pid_alive() {
  local pid="${1:-}"
  [ -n "$pid" ] || return 1
  case "$pid" in *[!0-9]*) return 1 ;; esac
  if is_windows; then
    tasklist //FI "PID eq $pid" //NH 2>/dev/null | grep -q "[^0-9]$pid[^0-9]"
  else
    kill -0 "$pid" 2>/dev/null
  fi
}

# Terminates one process and its children. Never called with an empty id.
kill_pid() {
  local pid="${1:-}"
  [ -n "$pid" ] || return 0
  if is_windows; then
    taskkill //T //F //PID "$pid" >/dev/null 2>&1 || true
  else
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
    sleep 1
    if pid_alive "$pid"; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  fi
}

wait_for_port() {
  local port="$1" seconds="${2:-20}" waited=0
  while [ "$waited" -lt "$seconds" ]; do
    [ -n "$(port_pid "$port")" ] && return 0
    sleep 0.5
    waited=$((waited + 1))
  done
  return 1
}

wait_for_port_free() {
  local port="$1" seconds="${2:-15}" waited=0
  while [ "$waited" -lt "$seconds" ]; do
    [ -z "$(port_pid "$port")" ] && return 0
    sleep 0.5
    waited=$((waited + 1))
  done
  return 1
}

# HTTP status code for a request, or 000 when the service cannot be reached.
http_code() {
  local method="$1" url="$2"
  if [ "$method" = "POST" ]; then
    curl -s -o /dev/null -m 30 -w '%{http_code}' -X POST \
      -H 'Content-Type: application/json' -d '{}' "$url" 2>/dev/null || echo 000
  else
    curl -s -o /dev/null -m 5 -w '%{http_code}' "$url" 2>/dev/null || echo 000
  fi
}

endpoint_state() {
  local url="$1" code
  code="$(http_code POST "$url")"
  case "$code" in
    200) echo "ok" ;;
    000) echo "unreachable" ;;
    *) echo "HTTP $code" ;;
  esac
}

# --- PID file ----------------------------------------------------------------

record_pid() {
  local name="$1" pid="$2"
  [ -n "$pid" ] || return 0
  mkdir -p "$ROOT"
  if [ -f "$PID_FILE" ]; then
    grep -v "^$name=" "$PID_FILE" >"$PID_FILE.tmp" 2>/dev/null || true
    mv "$PID_FILE.tmp" "$PID_FILE"
  fi
  printf '%s=%s\n' "$name" "$pid" >>"$PID_FILE"
}

recorded_pid() {
  local name="$1"
  [ -f "$PID_FILE" ] || return 0
  grep "^$name=" "$PID_FILE" 2>/dev/null | cut -d= -f2 | head -n 1
}

# --- Launchers ---------------------------------------------------------------

find_rscript() {
  if [ -n "${RSCRIPT:-}" ] && command -v "$RSCRIPT" >/dev/null 2>&1; then
    command -v "$RSCRIPT"
    return 0
  fi
  if command -v Rscript >/dev/null 2>&1; then
    command -v Rscript
    return 0
  fi
  local candidate
  for candidate in \
    "/c/Program Files/R/R-4.5.1/bin/Rscript.exe" \
    "/c/Program Files/R/R-4.5.1/bin/x64/Rscript.exe" \
    "/c/Program Files/R/R-4.5.1/bin/Rscript"; do
    [ -x "$candidate" ] && { echo "$candidate"; return 0; }
  done
  candidate="$(ls -d /c/Program\ Files/R/R-*/bin*/Rscript.exe 2>/dev/null | sort -V | tail -n 1)"
  [ -n "$candidate" ] && { echo "$candidate"; return 0; }
  return 1
}

find_python() {
  local candidate
  for candidate in \
    "$ROOT/api/.venv/Scripts/python.exe" \
    "$ROOT/api/.venv/bin/python"; do
    [ -x "$candidate" ] && { echo "$candidate"; return 0; }
  done
  return 1
}

find_npm() {
  command -v npm 2>/dev/null && return 0
  return 1
}

# --- Commands ----------------------------------------------------------------

start_r() {
  local pid rscript
  pid="$(port_pid "$R_PORT")"
  if [ -n "$pid" ]; then
    info "R API already running on $R_URL (pid $pid)"
    record_pid r "$pid"
    return 0
  fi
  if ! rscript="$(find_rscript)"; then
    warn "Rscript was not found. Install R, or set RSCRIPT=/path/to/Rscript."
    return 1
  fi
  mkdir -p "$LOG_DIR"
  (cd "$ROOT" && nohup "$rscript" api/run_api.R >>"$(service_log r)" 2>&1 &)
  info "R API starting on $R_URL   (log: .dev-logs/r.log)"
  if wait_for_port "$R_PORT" 30; then
    record_pid r "$(port_pid "$R_PORT")"
  else
    warn "R API did not open port $R_PORT within 30s; see .dev-logs/r.log"
    return 1
  fi
}

start_api() {
  local pid python
  pid="$(port_pid "$API_PORT")"
  if [ -n "$pid" ]; then
    info "FastAPI already running on $API_URL (pid $pid)"
    record_pid api "$pid"
    return 0
  fi
  if ! python="$(find_python)"; then
    warn "The api/ virtual environment was not found. Create it with: py -3.14 -m venv api/.venv"
    return 1
  fi
  mkdir -p "$LOG_DIR"
  (
    cd "$ROOT" &&
      EQALB_API_PORT="$API_PORT" nohup "$python" api/run_api.py >>"$(service_log api)" 2>&1 &
  )
  info "FastAPI starting on $API_URL   (log: .dev-logs/api.log)"
  wait_for_port "$API_PORT" 60 || true
  if [ -n "$(port_pid "$API_PORT")" ]; then
    record_pid api "$(port_pid "$API_PORT")"
  else
    warn "FastAPI did not open port $API_PORT; see .dev-logs/api.log"
    return 1
  fi
}

start_vue() {
  local pid npm
  pid="$(port_pid "$VUE_PORT")"
  if [ -n "$pid" ]; then
    info "Vue app already running on $VUE_URL (pid $pid)"
    record_pid vue "$pid"
    return 0
  fi
  if ! npm="$(find_npm)"; then
    warn "npm was not found. Install Node.js."
    return 1
  fi
  mkdir -p "$LOG_DIR"
  (
    cd "$ROOT/frontend" &&
      EQALB_API_URL="$API_URL" nohup "$npm" run dev >>"$(service_log vue)" 2>&1 &
  )
  info "Vue app starting on $VUE_URL   (proxy -> $API_URL, log: .dev-logs/vue.log)"
  wait_for_port "$VUE_PORT" 90 || true
  if [ -n "$(port_pid "$VUE_PORT")" ]; then
    record_pid vue "$(port_pid "$VUE_PORT")"
  else
    warn "Vue dev server did not open port $VUE_PORT; see .dev-logs/vue.log"
    return 1
  fi
}

cmd_start() {
  mkdir -p "$LOG_DIR"
  start_r
  start_api
  start_vue
  info ""
  info "Logs: .dev-logs/   Pids: .dev.pids   State: ./dev.sh status"
}

cmd_stop() {
  local name pid stopped=0
  if [ -f "$PID_FILE" ]; then
    for name in $SERVICES; do
      pid="$(recorded_pid "$name")"
      if [ -z "$pid" ]; then
        continue
      fi
      if pid_alive "$pid"; then
        kill_pid "$pid"
        info "Stopped $(service_label "$name") (pid $pid)"
        stopped=1
      else
        info "$(service_label "$name") was not running (pid $pid was recorded)"
      fi
    done
    rm -f "$PID_FILE"
  else
    for name in $SERVICES; do
      pid="$(port_pid "$(service_port "$name")")"
      if [ -n "$pid" ]; then
        kill_pid "$pid"
        info "Stopped $(service_label "$name") (pid $pid, listening on port $(service_port "$name"))"
        stopped=1
      fi
    done
    if [ "$stopped" -eq 0 ]; then
      info "Nothing to stop: no .dev.pids file and nothing listening on ports $R_PORT, $API_PORT, $VUE_PORT."
    fi
  fi
  # Give the ports a moment to be released before a restart reuses them.
  for name in $SERVICES; do
    wait_for_port_free "$(service_port "$name")" 15 || warn "Port $(service_port "$name") is still in use."
  done
}

cmd_restart() {
  cmd_stop
  sleep 2
  cmd_start
}

cmd_status() {
  local name pid url port state
  info "eQalb local services"
  info "-------------------"
  for name in $SERVICES; do
    url="$(service_url "$name")"
    port="$(service_port "$name")"
    pid="$(port_pid "$port")"
    if [ -n "$pid" ]; then
      state="running (pid $pid)"
    else
      state="not running"
    fi
    if [ "$name" = "vue" ]; then
      if [ -n "$pid" ]; then
        info "$(printf '%-19s %-22s %s' "$(service_label "$name")" "$url" "$state")"
        info "$(printf '%-19s proxy -> %s' '' "$API_URL")"
        info "$(printf '%-19s /api/readiness: %s   /api/hta-summary: %s (through the dev-server proxy)' '' \
          "$(endpoint_state "$VUE_URL/api/readiness")" "$(endpoint_state "$VUE_URL/api/hta-summary")")"
      else
        info "$(printf '%-19s %-22s %s' "$(service_label "$name")" "$url" "$state")"
      fi
    else
      info "$(printf '%-19s %-22s %s' "$(service_label "$name")" "$url" "$state")"
      if [ -n "$pid" ]; then
        info "$(printf '%-19s /api/readiness: %s   /api/hta-summary: %s' '' \
          "$(endpoint_state "$url/api/readiness")" "$(endpoint_state "$url/api/hta-summary")")"
      fi
    fi
  done
  if [ -f "$PID_FILE" ]; then
    info ""
    info "Recorded pids (.dev.pids):"
    while IFS= read -r line; do
      [ -n "$line" ] && info "  $line"
    done <"$PID_FILE"
  fi
}

cmd_logs() {
  local which="${1:-all}" lines="${2:-40}" name log
  case "$which" in
    all)
      for name in $SERVICES; do print_log "$name" "$lines"; done
      ;;
    r | api | vue)
      print_log "$which" "$lines"
      ;;
    *)
      warn "Unknown service '$which'. Use: r, api or vue."
      return 1
      ;;
  esac
}

print_log() {
  local name="$1" lines="$2" log
  log="$(service_log "$name")"
  info "===== $(service_label "$name") ($log) ====="
  if [ -f "$log" ]; then
    tail -n "$lines" "$log"
  else
    info "(no output yet)"
  fi
  info ""
}

usage() {
  cat <<'USAGE'
Usage: ./dev.sh <command>

  start                     start R Plumber (8788), FastAPI (8000) and Vue (5173)
  stop                      stop the services recorded in .dev.pids
  restart                   stop, wait, then start
  status                    running state, URLs and endpoint reachability
  logs [r|api|vue] [lines]  latest output (default: all services, 40 lines)

The Vue dev server proxies /api to FastAPI. Ports are overridable with
R_PORT, API_PORT and VUE_PORT.
USAGE
}

case "${1:-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  restart) cmd_restart ;;
  status) cmd_status ;;
  logs) shift; cmd_logs "${1:-all}" "${2:-40}" ;;
  "" | -h | --help | help) usage ;;
  *)
    warn "Unknown command '${1}'."
    usage
    exit 1
    ;;
esac
