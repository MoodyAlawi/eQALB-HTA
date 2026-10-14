#!/usr/bin/env bash
#
# eQalb frontend release activation and rollback.
#
# This is the only command the frontend deployment workflow may run on the
# server (through the root-owned forced-command wrapper described in
# deploy/FRONTEND_DEPLOY.md). It has exactly two operations:
#
#   activate <release-id> <archive-path> <checksum-path>
#   rollback <release-id>
#
# It publishes a static Vue build and nothing else. It never installs packages,
# never downloads anything, never touches git, R, Python, the API, systemd,
# Caddy's configuration or environment files, and it never invokes sudo, a
# shell of its own, or a service command.
#
# Install it root-owned, readable and executable by the deploy account, and
# writable by nobody but root:
#
#   sudo install -o root -g root -m 0755 deploy/frontend-deploy.sh \
#     /opt/eqalb/bin/frontend-deploy.sh
#
# Every path is fixed below. The caller supplies a release id, which is
# validated against a safe allowlist, and the two incoming files, whose derived
# paths are required to match exactly - no other location is accepted. The only
# mutable path is the Caddy-served public pointer, /opt/eqalb/public/dist; the
# release tree and the incoming directory are the only places the script ever
# writes, and the frontend checkout is never written by it.

if [ -z "${BASH_VERSION:-}" ]; then
  printf 'frontend-deploy: error: run this script with bash, not sh\n' >&2
  exit 1
fi

set -euo pipefail
umask 022

RELEASES_ROOT="/opt/eqalb/frontend/releases"
INCOMING_DIR="/opt/eqalb/frontend/incoming"

# Caddy serves /opt/eqalb/public/dist, and that symlink is the deployment's only
# mutable path. The directory is owned by the deploy account, so an activation
# never needs write access to /opt/eqalb/frontend or the source checkout.
PUBLIC_DIR="/opt/eqalb/public"
PUBLIC_DIST_LINK="$PUBLIC_DIR/dist"
LOCK_FILE="$PUBLIC_DIR/.deploy.lock"

# A release id is a directory name: a letter or digit followed by up to 63
# characters from [A-Za-z0-9._-]. The workflow generates
# "<run-number>-<40-hex commit>"; a hand-made release (for example the first
# migration of an existing dist directory) must satisfy the same pattern.
RELEASE_ID_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'

STAGING=""

usage() {
  cat <<'EOF'
usage: frontend-deploy.sh activate <release-id> <archive-path> <checksum-path>
       frontend-deploy.sh rollback <release-id>
EOF
}

die() {
  printf 'frontend-deploy: error: %s\n' "$*" >&2
  exit 1
}

note() {
  printf 'frontend-deploy: %s\n' "$*" >&2
}

cleanup() {
  if [ -n "$STAGING" ] && [ -d "$STAGING" ]; then
    rm -rf -- "$STAGING" || true
  fi
}
trap cleanup EXIT

validate_release_id() {
  if ! [[ "${1:-}" =~ $RELEASE_ID_PATTERN ]]; then
    die "invalid release id '${1:-}': expected $RELEASE_ID_PATTERN"
  fi
}

path_for_release() {
  printf '%s/%s' "$RELEASES_ROOT" "$1"
}

require_file() {
  [ -f "$1" ] || die "not a regular file: $1"
}

require_release_tree() {
  [ -d "$1" ] || die "release directory is missing: $1"
  [ ! -L "$1" ] || die "release path is a symlink, refusing it: $1"
  [ -f "$1/index.html" ] || die "release directory has no index.html: $1"
}

require_public_dir() {
  [ -d "$PUBLIC_DIR" ] || die "public directory is missing: $PUBLIC_DIR (run the one-time server migration in deploy/FRONTEND_DEPLOY.md)"
}

assert_dist_usable() {
  require_public_dir
  if [ -e "$PUBLIC_DIST_LINK" ] && [ ! -L "$PUBLIC_DIST_LINK" ]; then
    die "$PUBLIC_DIST_LINK exists and is not a symlink; refusing it (see deploy/FRONTEND_DEPLOY.md)"
  fi
}

# Prints the release directory the public pointer points at, or nothing when the
# symlink does not exist yet.
current_dist_target() {
  if [ -L "$PUBLIC_DIST_LINK" ]; then
    local target
    target="$(readlink -- "$PUBLIC_DIST_LINK")"
    printf '%s' "${target%/}"
  fi
}

# Replaces the public pointer in one rename, so a reader either follows the old
# target or the new one and never sees a missing or half-written path.
publish_dist() {
  local new_dir="$1" tmp_link="${PUBLIC_DIST_LINK}.tmp"
  ln -sfn -- "$new_dir" "$tmp_link"
  mv -T -- "$tmp_link" "$PUBLIC_DIST_LINK"
}

take_lock() {
  require_public_dir
  exec 9>>"$LOCK_FILE"
  flock -w 120 9 || die "another frontend deployment holds $LOCK_FILE"
}

activate() {
  [ "$#" -eq 3 ] || die "usage: frontend-deploy.sh activate <release-id> <archive-path> <checksum-path>"
  local release_id="$1" archive="$2" checksum="$3"

  validate_release_id "$release_id"

  local expected_archive="$INCOMING_DIR/frontend-$release_id.tar.gz"
  local expected_checksum="$expected_archive.sha256"
  [ "$archive" = "$expected_archive" ] || die "archive must be exactly $expected_archive"
  [ "$checksum" = "$expected_checksum" ] || die "checksum must be exactly $expected_checksum"
  require_file "$archive"
  require_file "$checksum"

  [ -d "$RELEASES_ROOT" ] || die "releases root is missing: $RELEASES_ROOT"
  assert_dist_usable

  local new_dir
  new_dir="$(path_for_release "$release_id")"
  if [ -e "$new_dir" ] || [ -L "$new_dir" ]; then
    die "release already exists, refusing to overwrite it: $new_dir"
  fi

  # The incoming archive must match the workflow's checksum before anything is
  # unpacked. The checksum file is the standard "<hash>  <name>" form.
  local expected actual listed
  expected="$(awk 'NR == 1 { print $1 }' "$checksum")"
  listed="$(awk 'NR == 1 { print $2 }' "$checksum")"
  listed="${listed#\*}"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || die "checksum file does not hold a SHA-256 value: $checksum"
  [ "$listed" = "${expected_archive##*/}" ] || die "checksum file names '$listed', expected '${expected_archive##*/}'"
  actual="$(sha256sum -- "$archive" | awk '{ print $1 }')"
  [ "$actual" = "$expected" ] || die "SHA-256 mismatch for $archive"

  # Refuse an archive that could write outside the release directory.
  local listing
  listing="$(tar -tzf "$archive")" || die "cannot read archive: $archive"
  if printf '%s\n' "$listing" | grep -Eq '(^|/)\.\.(/|$)|^/'; then
    die "archive contains absolute or parent-relative paths"
  fi

  local previous_target previous_id=""
  previous_target="$(current_dist_target)"
  if [ -n "$previous_target" ]; then
    case "$previous_target" in
      "$RELEASES_ROOT"/*) previous_id="${previous_target##*/}" ;;
      *) die "the public pointer points outside $RELEASES_ROOT: $previous_target" ;;
    esac
  fi

  # Extract, verify and harden inside the staging directory; nothing below
  # touches the public pointer until the release is complete.
  STAGING="$(mktemp -d "$RELEASES_ROOT/.staging-$release_id.XXXXXX")"
  tar -xzf "$archive" -C "$STAGING" --no-same-owner --no-same-permissions
  [ -f "$STAGING/index.html" ] || die "the bundle has no index.html at its root"
  if [ -n "$(find "$STAGING" -type l -print -quit)" ]; then
    die "the bundle contains symbolic links, refusing to publish it"
  fi
  # Caddy reads this tree: files and directories readable, nothing writable by
  # group or world.
  chmod -R u=rwX,go=rX "$STAGING"
  chmod -R go-w "$STAGING"

  mv -T -- "$STAGING" "$new_dir"
  STAGING=""

  publish_dist "$new_dir"

  note "activated release $release_id"
  if [ -n "$previous_id" ]; then
    note "previous release retained: $previous_id"
  else
    note "no previous release was active"
  fi
  printf 'PREVIOUS_RELEASE_ID=%s\n' "$previous_id"
  printf 'ACTIVE_RELEASE_ID=%s\n' "$release_id"
}

rollback() {
  [ "$#" -eq 1 ] || die "usage: frontend-deploy.sh rollback <release-id>"
  local release_id="$1"
  validate_release_id "$release_id"

  local new_dir previous_target
  new_dir="$(path_for_release "$release_id")"
  require_release_tree "$new_dir"
  assert_dist_usable

  previous_target="$(current_dist_target)"
  if [ -n "$previous_target" ]; then
    case "$previous_target" in
      "$RELEASES_ROOT"/*) : ;;
      *) die "the public pointer points outside $RELEASES_ROOT: $previous_target" ;;
    esac
  fi

  if [ "$previous_target" = "$new_dir" ]; then
    note "the public pointer already points at release $release_id"
    printf 'ACTIVE_RELEASE_ID=%s\n' "$release_id"
    return 0
  fi

  publish_dist "$new_dir"

  note "rolled back to release $release_id"
  printf 'PREVIOUS_RELEASE_ID=%s\n' "${previous_target##*/}"
  printf 'ACTIVE_RELEASE_ID=%s\n' "$release_id"
}

main() {
  local operation="${1:-}"
  case "$operation" in
    activate)
      shift
      take_lock
      activate "$@"
      ;;
    rollback)
      shift
      take_lock
      rollback "$@"
      ;;
    -h | --help | help)
      usage
      ;;
    "")
      usage >&2
      exit 2
      ;;
    *)
      die "unknown operation '$operation' (expected 'activate' or 'rollback')"
      ;;
  esac
}

main "$@"
