# Frontend production deployment (GitHub Actions + one root-owned script)

Status: **implemented in this repository, not yet configured or exercised.** No
workflow run has happened, none of the secrets below exists yet, and nothing in
this document has been executed on the server. Treat every operational statement
here as the intended design until a real run has succeeded and been reviewed.
[`DEPLOY.md`](./DEPLOY.md) remains the runbook for installing the host
(packages, R, the API service, DNS, Caddy) and for every non-frontend change.

This automation ships **one thing**: a completed Vue/Vite static bundle. The
Caddyfile and the API are not part of it.

## 1. What it deploys, and what it must never touch

Deployed by this automation:

- The contents of `frontend/`, built by GitHub Actions into `frontend/dist`,
  packaged as `frontend-<release-id>.tar.gz` with a SHA-256 checksum file.
- The `/opt/eqalb/frontend/dist` symlink, which is repointed atomically to the
  new immutable release under `/opt/eqalb/frontend/releases/`.

Never touched, by design and by construction:

- R, `renv`, R packages, `/opt/R/4.5.1`.
- Python, `api/` and its packages, the `eqalb-api` systemd unit, the API's
  environment file, and any API restart.
- Caddy's configuration, certificate handling, logging, compression, headers or
  TLS settings - and no Caddy reload or restart.
- DNS, domain registrar records, firewall rules, the deploy account and its key.
- The Git checkout on the server: the bundle is built in GitHub Actions, and the
  server-side script performs no git operation.
- Anything outside `/opt/eqalb/frontend` (plus the two root-owned scripts under
  `/opt/eqalb/bin` that are installed by hand, once, by an operator).

The API stays independent. A frontend release cannot restart, reconfigure or
even observe it; the only API contact anywhere in this automation is one
read-only `GET /api/health` during validation.

## 2. How a release is laid out on the server

```
/opt/eqalb/frontend/
  incoming/                                  # the workflow's SCP target: archive + checksum
  releases/<release-id>/                     # immutable release: index.html + assets/
  releases/manual-<timestamp>/               # a migrated hand-built release, if the host had one
  dist -> /opt/eqalb/frontend/releases/<id>  # absolute symlink; Caddy serves this path unchanged
  .deploy.lock                               # flock target; two deployments never overlap
/opt/eqalb/bin/
  frontend-deploy.sh                         # root-owned; exactly two operations
  eqalb-frontend-deploy-wrapper              # root-owned; the deployment key's forced command
```

The symlink target is absolute, which is why the script can require the active
path to sit under `releases/` and can report the previous release id.

A release id is a directory name matching `[A-Za-z0-9][A-Za-z0-9._-]{0,63}`.
The workflow generates `<run-number>-<40-hex commit>` (for example
`42-4eb8976e0f...`), which is fixed, unique per run, and auditable back to a
commit. Hand-made releases (the first migration, for instance) must satisfy the
same pattern.

`releases/` and every release keep the current and the immediately previous
release: `activate` never deletes anything, and `rollback` only repoints the
symlink. Old releases accumulate until an operator removes them explicitly (see
§9).

## 3. The workflow

`.github/workflows/deploy-frontend.yml`.

| Trigger | What runs |
|---|---|
| Push to `main` touching `frontend/**`, `deploy/**` or the workflow itself | Build job, then the deploy job behind the `production` environment. |
| Manual dispatch with `rollback_release_id` set | The rollback job only. No build, no activation. |
| Manual dispatch with the input empty | The rollback job fails immediately with a message; nothing reaches the server. |

Build job (`ubuntu-24.04`, Node 22, `contents: read` only):

```text
actions/checkout          (pin: v4.2.2)
actions/setup-node        (pin: v4.4.0, node-version 22)
npm ci --ignore-scripts
npm run typecheck
npm run lint
npm run build
package frontend/dist into frontend-<release-id>.tar.gz + .sha256
verify the checksum, refuse *.map files, upload the artifact
```

Deploy job (`environment: production`):

1. Write the deploy key and the pinned host key from the environment secrets
   into `~/.ssh` on the runner (mode 0600, never printed, removed at the end).
2. Download the artifact and verify its checksum again.
3. `scp -O` the archive and the checksum file into `/opt/eqalb/frontend/incoming`.
4. `ssh` the one fixed command `activate <release-id> <archive> <checksum>`.
5. Validate the public HTTPS URLs `/`, `/app`, `/about` and read-only
   `/api/health`. The pages must return HTTP 200 **and** contain a
   content-hashed asset named by the freshly built `index.html`, so a stale
   bundle cannot pass validation.
6. On any validation failure, `ssh` the one fixed command
   `rollback <previous-release-id>` and fail the run.

Concurrency is a single group (`frontend-production-deploy`) with
`cancel-in-progress: false`, so only one frontend production deployment runs at a
time and an in-flight one is never cancelled.

### Environment secrets (`production`)

Names only; no value ever belongs in a tracked file.

| Secret | Meaning |
|---|---|
| `DEPLOY_SSH_HOST` | Production host name or IP address. |
| `DEPLOY_SSH_PORT` | SSH port; the workflow defaults to 22 when unset. |
| `DEPLOY_SSH_USER` | The dedicated deploy account, e.g. `eqalb-deploy`. |
| `DEPLOY_SSH_KEY` | Private half (OpenSSH format) of the deployment key pair. |
| `DEPLOY_KNOWN_HOSTS` | The host's pinned public host key line(s), from `ssh-keyscan` or `/etc/ssh/ssh_host_*_key.pub`. |
| `DEPLOY_PUBLIC_BASE_URL` | Public HTTPS origin used for validation, e.g. `https://<production-host>`. |

Keep all six **environment** secrets (not repository secrets): they are then only
exposed to jobs that pass the `production` environment's protection rules.

## 4. One-time manual bootstrap (root on the host)

Everything in this section is done by an operator, by hand, once. The workflow
does none of it.

### 4.1 A dedicated deploy account

```bash
sudo adduser --disabled-password --gecos '' eqalb-deploy
# No sudo, no group memberships beyond its own, its own home directory.
# The account owns nothing but /opt/eqalb/frontend; the API's `eqalb` user keeps
# owning the rest of /opt/eqalb.
```

### 4.2 Directories, the lock file and the scripts

```bash
sudo mkdir -p /opt/eqalb/bin
sudo install -d -m 0755 -o eqalb-deploy -g eqalb-deploy /opt/eqalb/frontend
sudo install -d -m 0750 -o eqalb-deploy -g eqalb-deploy /opt/eqalb/frontend/incoming
sudo install -d -m 0755 -o eqalb-deploy -g eqalb-deploy /opt/eqalb/frontend/releases
sudo install -m 0644 -o eqalb-deploy -g eqalb-deploy /dev/null /opt/eqalb/frontend/.deploy.lock
```

Traversal matters: Caddy reads the release tree, so `/opt/eqalb`,
`/opt/eqalb/frontend` and `/opt/eqalb/frontend/releases` must be world-executable
(`0755`) - the `incoming` directory holds nothing Caddy needs.

Install the script **root-owned and not writable by the deploy account**, from a
reviewed checkout on the server (this is the only step that touches the Git
checkout, and it is an operator action, not the workflow's):

```bash
sudo install -o root -g root -m 0755 \
  /opt/eqalb/deploy/frontend-deploy.sh /opt/eqalb/bin/frontend-deploy.sh
```

The script has exactly two operations, `activate` and `rollback`, and no other
input than a validated release id and the two exact incoming paths it derives
itself. It never installs packages, downloads, evaluates a caller-supplied shell
or string, deletes a wildcard, or runs git, sudo, systemd or Caddy.

### 4.3 The forced-command wrapper

The deployment key must not open a shell. Save the wrapper (content below) as a
file, for example `./eqalb-frontend-deploy-wrapper`, and install it root-owned
mode 0755:

```bash
sudo install -o root -g root -m 0755 ./eqalb-frontend-deploy-wrapper \
  /opt/eqalb/bin/eqalb-frontend-deploy-wrapper
```

```bash
#!/usr/bin/env bash
# Root-owned forced command for the deployment key. Accepts exactly three
# request shapes and executes nothing else.
set -euo pipefail

readonly DEPLOY_SCRIPT="/opt/eqalb/bin/frontend-deploy.sh"
readonly INCOMING_DIR="/opt/eqalb/frontend/incoming"

read -r -a request <<< "${SSH_ORIGINAL_COMMAND:-}"

case "${request[0]:-}" in
  activate)
    [ "${#request[@]}" -eq 4 ] || exit 64
    exec "$DEPLOY_SCRIPT" activate "${request[1]}" "${request[2]}" "${request[3]}"
    ;;
  rollback)
    [ "${#request[@]}" -eq 2 ] || exit 64
    exec "$DEPLOY_SCRIPT" rollback "${request[1]}"
    ;;
  scp)
    # The workflow uploads with `scp -O`; its remote side is exactly
    # `scp -t <incoming dir>`, and that is the only upload it accepts.
    [ "${#request[@]}" -eq 3 ] || exit 64
    [ "${request[1]}" = "-t" ] || exit 64
    [ "${request[2]%/}" = "$INCOMING_DIR" ] || exit 64
    exec /usr/bin/scp -t "$INCOMING_DIR"
    ;;
  *)
    printf 'eqalb-frontend-deploy-wrapper: refusing request\n' >&2
    exit 64
    ;;
esac
```

The wrapper parses the request into arguments and only ever `exec`s the two
fixed programs with those arguments - no `eval`, no `bash -c`, no path taken
from the request. `scp` is accepted because a forced command also replaces the
SFTP/SCP subsystem, which is why the workflow uses the legacy protocol
(`scp -O`); that protocol's remote side is `scp -t <incoming dir>`, exactly what
the wrapper permits.

### 4.4 A dedicated key and a restricted `authorized_keys` entry

Generate the key pair **on the operator's machine**, not on the server, and keep
the private half only in the GitHub environment secret:

```bash
ssh-keygen -t ed25519 -C eqalb-frontend-deploy -f ./eqalb-frontend-deploy
```

On the server, for `eqalb-deploy` only, add one line to
`~eqalb-deploy/.ssh/authorized_keys` (mode 0600, directory 0700):

```bash
sudo install -d -m 0700 -o root -g root /home/eqalb-deploy/.ssh
sudo install -m 0600 -o root -g root /dev/null /home/eqalb-deploy/.ssh/authorized_keys
sudo editor /home/eqalb-deploy/.ssh/authorized_keys
```

```text
restrict,command="/opt/eqalb/bin/eqalb-frontend-deploy-wrapper" ssh-ed25519 AAAA...the public key...
```

Keeping `.ssh` and `authorized_keys` root-owned means the deploy account cannot
change or remove its own restriction. `restrict` disables the pty, agent and port
forwarding; the `command=` makes the wrapper the only thing the key can run. The
private key never leaves the GitHub environment secret, and no private key,
passphrase or token is written into this repository or into any file under
`/opt/eqalb`.

### 4.5 GitHub: the `production` environment

1. Repository → Settings → Environments → New environment → `production`.
2. Protection rules → **Required reviewers**: add the people who may approve a
   production frontend release. Until this is set, the deploy job runs without a
   gate - configure it before the first real run. Optionally restrict
   "Deployment branches and tags" to `main`.
3. Environment secrets: add the six names from §3.

### 4.6 If the host already serves `frontend/dist` as a real directory

The manual runbook (§3.4 of `DEPLOY.md`) leaves `/opt/eqalb/frontend/dist` as a
real directory built by `npm run build`. Convert it once, so the first automated
release has something to roll back to:

```bash
sudo chown -R eqalb-deploy:eqalb-deploy /opt/eqalb/frontend
cd /opt/eqalb/frontend
release="manual-$(date -u +%Y%m%dT%H%M%SZ)"
sudo -u eqalb-deploy mv dist "releases/$release"
sudo -u eqalb-deploy ln -s "/opt/eqalb/frontend/releases/$release" dist
readlink /opt/eqalb/frontend/dist      # expect the releases/... path
curl -sS -o /dev/null -w '%{http_code}\n' https://<production-host>/   # expect 200
```

From that point on, **do not** run `npm run build` in `/opt/eqalb/frontend`:
Vite empties its output directory, and with `dist` as a symlink that would write
into the active release. Use this automation, or build in a scratch directory and
publish by hand.

## 5. Normal deploy sequence

1. Merge a frontend change to `main`.
2. The build job runs the four commands and packages
   `frontend-<release-id>.tar.gz` plus its `.sha256`.
3. The deploy job waits for the `production` environment's approval.
4. On approval: upload to `incoming/`, `activate`, validate `/`, `/app`,
   `/about` and `/api/health`.
5. Only if every check passes does the run succeed. Caddy was never reloaded,
   the API was never restarted, and no release directory was deleted.

## 6. Failed deploy: automatic rollback

If activation fails, nothing is published: the script exits non-zero, removes its
staging directory, and `dist` keeps pointing at the previous release.

If activation succeeds but any public check fails, the deploy job invokes the
script's `rollback` mode with the reported previous release id, which repoints
`dist` in one rename, and the workflow fails. The failed release directory stays
on disk for inspection; it is not the live release.

## 7. Manual rollback (one command)

Anything retained under `releases/` can be activated again, one command, no
rebuild:

```bash
sudo -u eqalb-deploy /opt/eqalb/bin/frontend-deploy.sh rollback <release-id>
# prints PREVIOUS_RELEASE_ID=... and ACTIVE_RELEASE_ID=<release-id>
```

The same action through GitHub (approval-gated, and it re-checks the public URLs
afterwards) is a `workflow_dispatch` run with `rollback_release_id` set to the
release to restore. To see what is available:

```bash
readlink /opt/eqalb/frontend/dist                     # current release
ls -1 /opt/eqalb/frontend/releases/                   # retained releases
```

## 8. Re-running a failed deployment

A release id is the run number plus the commit SHA, so re-running the *same*
workflow run reuses the same id. If a previous attempt already created the
release directory (for example it was activated and then rolled back), the next
`activate` refuses to overwrite it and exits non-zero. The remedy is deliberate,
not automatic:

```bash
sudo rm -rf /opt/eqalb/frontend/releases/<failed-release-id>   # inspect it first
```

Then re-run the workflow, or push a new commit. Nothing else is deleted, and no
release that is currently or previously active is ever removed automatically.

## 9. Retention and disk use

Each release is the size of the built frontend (about 10 MB). `activate` keeps
everything; pruning is a manual, explicit act - list the releases, check
`readlink`, and remove only the directories you no longer want:

```bash
du -sh /opt/eqalb/frontend/releases/* | sort -h
sudo rm -rf /opt/eqalb/frontend/releases/<release-id>
```

The `incoming/` directory also grows by one archive and one checksum file per
attempt; remove the files you no longer need:

```bash
ls -lt /opt/eqalb/frontend/incoming/
sudo rm -f /opt/eqalb/frontend/incoming/frontend-<release-id>.tar.gz \
           /opt/eqalb/frontend/incoming/frontend-<release-id>.tar.gz.sha256
```

## 10. Not verified yet, and known limitations

- **Not run.** No workflow run, no server bootstrap, no secret exists. The first
  run is a controlled test: bootstrap the host, set the environment and its
  approval, then watch the first deploy end to end.
- The action pins are full commit SHAs written from the actions' published
  releases (`v4.2.2`, `v4.4.0`, `v4.6.2`, `v4.3.0`). Confirm each with
  `git ls-remote https://github.com/<owner>/<action> refs/tags/<tag>` before the
  first run; a wrong pin fails the workflow before it reaches the server.
- The design relies on Caddy resolving `/opt/eqalb/frontend/dist` per request, so
  a symlink swap changes what is served with no reload; the approved design
  assumes the live configuration does this, and the first controlled run is where
  that assumption is confirmed. If a future Caddy release pinned the resolved
  root at load time, the new bundle would not be served, the validation check
  would fail, the automatic rollback would restore the previous target, and the
  limitation would need an operator decision - this automation never reloads or
  restarts Caddy.
- Old releases and incoming archives are never pruned automatically (§9).
- Every push to the watched paths on `main` is a production release candidate;
  there is no staging environment and no per-commit opt-out. That is the
  deliberate Version 1 scope.
- This automation deploys the static frontend only. API, R, Caddy, systemd, DNS
  and server configuration changes still follow `deploy/DEPLOY.md`, by hand.
