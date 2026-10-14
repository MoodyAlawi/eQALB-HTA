# Frontend production deployment (GitHub Actions + one root-owned script)

Status: **server side migrated and verified; the first automated workflow run is
outstanding.** The GitHub `production` environment and its six secrets are
configured; the passphrase-free CI-only Ed25519 key has been created, installed
behind the restricted forced-command wrapper, tested, rotated into the
`DEPLOY_SSH_KEY` secret and the old key removed; and the one-time public-pointer
and Caddy migration (§4.7) has been performed and verified on the VPS. No
automated release has been deployed yet: the first workflow run has not
happened, and the `production` environment's required-reviewer/approval rule
must still be confirmed with the operator before that run. §10 records the
evidence and what remains. [`DEPLOY.md`](./DEPLOY.md) remains the runbook for
installing the host (packages, R, the API service, DNS, Caddy) and for every
non-frontend change.

This automation ships **one thing**: a completed Vue/Vite static bundle. The
Caddyfile and the API are not part of it.

## 1. What it deploys, and what it must never touch

Deployed by this automation:

- The contents of `frontend/`, built by GitHub Actions into `frontend/dist`,
  packaged as `frontend-<release-id>.tar.gz` with a SHA-256 checksum file.
- The `/opt/eqalb/public/dist` symlink - the deployment's only mutable path -
  which is repointed atomically to the new immutable release under
  `/opt/eqalb/frontend/releases/`. That is the symlink Caddy serves.

Never touched, by design and by construction:

- R, `renv`, R packages, `/opt/R/4.5.1`.
- Python, `api/` and its packages, the `eqalb-api` systemd unit, the API's
  environment file, and any API restart.
- Caddy's configuration, certificate handling, logging, compression, headers or
  TLS settings - and no Caddy reload or restart. Moving Caddy's static root to
  `/opt/eqalb/public/dist` is a separate **one-time** manual act (§4.7); the
  normal deploy never runs a Caddy command.
- DNS, domain registrar records, firewall rules, the deploy account and its key.
- The Git checkout on the server: the bundle is built in GitHub Actions, and the
  server-side script performs no git operation.
- Anything outside `/opt/eqalb/public` and `/opt/eqalb/frontend/releases` (plus
  the incoming directory written by the upload, and the two root-owned scripts
  under `/opt/eqalb/bin` that an operator installs once).

The API stays independent. A frontend release cannot restart, reconfigure or
even observe it; the only API contact anywhere in this automation is one
read-only `GET /api/health` during validation.

## 2. How a release is laid out on the server

```
/opt/eqalb/public/                            # deployment-only; owned by eqalb-deploy
  dist -> /opt/eqalb/frontend/releases/<id>   # the one mutable path; Caddy serves this
  .deploy.lock                                # flock target; two deployments never overlap
/opt/eqalb/frontend/
  incoming/                                   # the workflow's SCP target: archive + checksum
  releases/<release-id>/                      # immutable release: index.html + assets/
  releases/manual-<timestamp>/                # a migrated hand-built release, if the host had one
/opt/eqalb/bin/
  frontend-deploy.sh                          # root-owned; exactly two operations
  eqalb-frontend-deploy-wrapper               # root-owned; the deployment key's forced command
```

Caddy's static root is `/opt/eqalb/public/dist` (§4.7). `/opt/eqalb` keeps its
existing restrictive mode (`750`, `eqalb:eqalb`): neither the deploy account nor
Caddy is given broad permissions on it. The deploy account owns
`/opt/eqalb/public`, `releases/` and `incoming/`, and receives only narrow
per-user ACL traverse access to the parent paths, so an activation writes nothing
in the frontend tree except a new release directory. Caddy receives only the
per-user ACL access it needs - traverse `/opt/eqalb` and `/opt/eqalb/frontend`,
read and traverse `/opt/eqalb/public` (so it can resolve the `dist` symlink name
inside it) and the release tree, and write nowhere (§4.7). The public
pointer's target is absolute, which is why the script can require the active path
to sit under `releases/` and can report the previous release id.

A release id is a directory name matching `[A-Za-z0-9][A-Za-z0-9._-]{0,63}`.
The workflow generates `<run-number>-<40-hex commit>` (for example
`42-4eb8976e0f...`), which is fixed, unique per run, and auditable back to a
commit. Hand-made releases (the first migration, for instance) must satisfy the
same pattern.

Nothing is deleted by the automation: the current release and every earlier one
stay on disk, so a rollback to any retained release is one command, and the
immediately previous release is always available to the automatic rollback.
`activate` never deletes anything and `rollback` only repoints the public
pointer; old releases accumulate until an operator removes them explicitly (see
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

The only server path the deploy job can change is `/opt/eqalb/public/dist`, and
only through the script's two operations.

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
| `DEPLOY_SSH_KEY` | The dedicated, passphrase-free, **CI-only** Ed25519 private key (OpenSSH format). Never an operator's personal key, and never given a passphrase: the workflow authenticates in `BatchMode=yes` with no agent and no TTY, so a protected key cannot be unlocked. See §4.4 for generation and rotation. |
| `DEPLOY_KNOWN_HOSTS` | The host's pinned public host key line(s), from `ssh-keyscan` or `/etc/ssh/ssh_host_*_key.pub`. This is the canonical name the workflow reads. |
| `DEPLOY_PUBLIC_BASE_URL` | Public HTTPS origin used for validation, e.g. `https://<production-host>`. |

Keep all six **environment** secrets (not repository secrets): they are then only
exposed to jobs that pass the `production` environment's protection rules. All
six are configured in the `production` environment now; this table is the
canonical record of their names and meanings, so an audit or a rebuild uses
exactly these.

Secret naming: `DEPLOY_KNOWN_HOSTS` is the name the workflow uses, and every
document here uses it too. If the environment also carries a redundant
`DEPLOY_SSH_KNOWN_HOSTS` (an earlier alternative spelling), nothing reads it -
delete it manually after the first successful deployment, and do not add it back.

## 4. One-time manual bootstrap (root on the host)

Everything in this section is done by an operator, by hand, once. The workflow
does none of it.

### 4.1 A dedicated deploy account

```bash
sudo adduser --disabled-password --gecos '' eqalb-deploy
# No sudo, no group memberships beyond its own, its own home directory.
# The account owns exactly three directories - /opt/eqalb/public,
# /opt/eqalb/frontend/releases and /opt/eqalb/frontend/incoming (created in
# §4.2) - and owns nothing else; the API's `eqalb` user keeps owning the rest of
# /opt/eqalb, and the frontend checkout stays root-owned.
```

### 4.2 Directories, the scripts and the lock

```bash
sudo mkdir -p /opt/eqalb/bin
sudo install -d -m 0755 -o eqalb-deploy -g eqalb-deploy /opt/eqalb/public
sudo install -d -m 0755 -o eqalb-deploy -g eqalb-deploy /opt/eqalb/frontend/releases
sudo install -d -m 0750 -o eqalb-deploy -g eqalb-deploy /opt/eqalb/frontend/incoming
```

Ownership rule, and the reason for it: the deploy account owns exactly
`/opt/eqalb/public`, `/opt/eqalb/frontend/releases` and
`/opt/eqalb/frontend/incoming`. It must **not** own - or be able to write -
`/opt/eqalb/frontend` itself or anything else in the frontend checkout, so the
account can publish releases and move the public pointer but can never modify
the source, the API, `/opt/eqalb/deploy` or Caddy's files. Do not
`chown -R eqalb-deploy /opt/eqalb/frontend`. The lock file
(`/opt/eqalb/public/.deploy.lock`) is created by the script on first use inside
the directory the account already owns, so no extra step is needed.

Traversal matters, and it is granted per user - never by relaxing a directory
mode. `/opt/eqalb` keeps its existing restrictive mode (`750`, `eqalb:eqalb`):
do **not** `chmod 0755 /opt/eqalb` or any other parent, and do not add
world-executable or world-readable bits to widen access. §4.7 grants
`eqalb-deploy` traverse-only ACLs on `/opt/eqalb` and `/opt/eqalb/frontend`, and
gives the Caddy service account traverse-only ACLs on those same two parents plus
read-and-traverse ACLs on `/opt/eqalb/public` and the release tree, with no write
access anywhere. The `incoming` directory holds nothing Caddy needs. (The `0755`
on `/opt/eqalb/public` and `releases/` only records the
deploy account's own directories; their parent `/opt/eqalb` stays `750`, so
those bits grant nothing to anyone without an ACL entry.)

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

### 4.4 The CI-only deploy key, and how to rotate it

The workflow key is a **dedicated, passphrase-free, CI-only Ed25519 key**. It is
not an operator's personal key and never becomes one. It is passphrase-free
because the workflow writes the private half to a file and authenticates with
`-o BatchMode=yes` - no agent, no TTY, so a passphrase could never be entered.
Its safety comes from its restrictions, not from a passphrase: the forced-command
wrapper (§4.3) and the `restrict` `authorized_keys` entry below.

Generate it **on the operator's machine, outside this repository** (never inside
the checkout, so no private key can be committed by accident):

```bash
ssh-keygen -t ed25519 -N '' -C eqalb-frontend-deploy-ci -f "$HOME/.ssh/eqalb-deploy-ci"
ssh-keygen -y -f "$HOME/.ssh/eqalb-deploy-ci" </dev/null >/dev/null && echo 'no passphrase: OK'
```

The private half is stored in exactly one place: the protected `production`
Environment secret `DEPLOY_SSH_KEY` (§4.5, §3). Never a repository secret, never
a tracked file, never an SSH-agent action, and no separate passphrase secret
exists. One file has one line, so add it from a file rather than pasting it into
a shell:

```bash
gh secret set DEPLOY_SSH_KEY --env production < "$HOME/.ssh/eqalb-deploy-ci"
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
forwarding; the `command=` makes the wrapper the only thing the key can run. No
private key, passphrase or token is written into this repository or into any file
under `/opt/eqalb`.

#### Rotating the key without a lockout

The old key stays valid until the new one is proven **through GitHub**, because
an Environment secret is write-only and can only be verified by using it.

1. Generate the replacement as above.
2. Add its public key as a **second line** in `authorized_keys`, with the same
   `restrict,command=...` prefix. Both keys now work; nothing is removed yet.
3. From the operator's machine, verify the new key: fingerprint, the refusal
   tests, and one positive control that names the currently active release id
   (see "Verifying the key" below). The positive control is a no-op rollback, so
   it changes nothing.
4. Replace the `production` environment secret `DEPLOY_SSH_KEY` with the new
   private key (`gh secret set DEPLOY_SSH_KEY --env production < <new-key>`).
5. Prove it end to end through GitHub without deploying anything new: read the
   active release id on the server, then dispatch the workflow's rollback job
   with that same id (`gh workflow run deploy-frontend.yml -f
   rollback_release_id=<active-id>`). Expect success and
   `ACTIVE_RELEASE_ID=<active-id>` - that is the new key authenticating to the
   wrapper, the script running, and the public checks passing.
6. Only after step 5 succeeds, remove the **old** public key line from
   `authorized_keys`, and delete the old private key material
   (`shred -u` where available).
7. Re-run the refusal tests with the old key: they must now fail to authenticate.

#### Verifying the key

```bash
# fingerprints, never key material
ssh-keygen -lf "$HOME/.ssh/eqalb-deploy-ci.pub"
sudo ssh-keygen -lf /home/eqalb-deploy/.ssh/authorized_keys
```

Refusal tests (each must be refused: no shell, no arbitrary command, no pty, no
forwarding; exit 64 is the wrapper's own refusal):

```bash
KEY="$HOME/.ssh/eqalb-deploy-ci"; H=eqalb-deploy@<host>; P=<port>
SSH="ssh -i $KEY -p $P -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10"
$SSH -T "$H"                     ; echo "exit=$?"   # no command        -> refused
$SSH -T "$H" id                  ; echo "exit=$?"   # arbitrary command -> refused
$SSH -T "$H" 'bash -lc id'       ; echo "exit=$?"   # shell request     -> refused
$SSH -T "$H" 'cat /etc/passwd'   ; echo "exit=$?"   # file read         -> refused
$SSH -tT "$H"                    ; echo "exit=$?"   # pty allocation    -> refused
timeout 10 $SSH -N -T -o ExitOnForwardFailure=yes -L 15432:127.0.0.1:8000 "$H" ; echo "exit=$?"   # forwarding off
scp -O -i "$KEY" -P "$P" ./dummy.txt "$H:/etc/cron.d/" ; echo "exit=$?"   # wrong target dir -> refused
```

Positive control - the only request that must succeed, and it changes nothing
when the id is the active one (`readlink` on the server prints the live release):

```bash
ACTIVE=$(basename "$(readlink -f /opt/eqalb/public/dist)")   # read on the server
$SSH -T "$H" "rollback $ACTIVE" ; echo "exit=$?"             # expect exit 0, ACTIVE_RELEASE_ID=$ACTIVE
```

### 4.5 GitHub: the `production` environment

The environment and its six secrets are configured, and `DEPLOY_SSH_KEY` holds
the rotated passphrase-free CI-only key (the rotation is recorded in §4.4 and
§10). This is the checklist to audit them, or to rebuild them if they are ever
lost.

1. Repository → Settings → Environments → `production` (create it only if it is
   missing; it is already configured).
2. Protection rules → **Required reviewers**: add the people who may approve a
   production frontend release. This rule has **not yet been confirmed with the
   operator** - until it is set, the deploy job runs without a gate, so confirm
   it before the first real run. Optionally restrict
   "Deployment branches and tags" to `main`.
3. Environment secrets: the six names from §3, and no others (delete the
   redundant `DEPLOY_SSH_KNOWN_HOSTS` after a successful deployment, as §3
   notes). `DEPLOY_SSH_KEY` is the replacement key installed on the server in
   §4.4.

### 4.6 If the live build is still a real directory under the frontend tree

The manual runbook (§3.4 of `DEPLOY.md`) leaves `/opt/eqalb/frontend/dist` as a
real directory built by `npm run build`. Convert it once, so there is an initial
release and the first automated release has something to roll back to. Root does
the move, because the deploy account must not be able to write
`/opt/eqalb/frontend`; the release keeps exactly the same ownership and
permissions an automated release gets.

```bash
readlink -f /opt/eqalb/frontend/dist   # a directory path (not a symlink) means this step applies
release="manual-$(date -u +%Y%m%dT%H%M%SZ)"
sudo mv /opt/eqalb/frontend/dist "/opt/eqalb/frontend/releases/$release"
sudo chown -R eqalb-deploy:eqalb-deploy "/opt/eqalb/frontend/releases/$release"
sudo chmod -R go-w "/opt/eqalb/frontend/releases/$release"
sudo ln -s "/opt/eqalb/frontend/releases/$release" /opt/eqalb/frontend/dist
readlink /opt/eqalb/frontend/dist      # expect the releases/... path
curl -s -o /dev/null -w '%{http_code}\n' https://<production-host>/   # expect 200
```

If `/opt/eqalb/frontend/dist` is already a symlink into `releases/`, the
conversion has been done; record the initial release id and continue:

```bash
basename "$(readlink -f /opt/eqalb/frontend/dist)"   # the initial release id, e.g. manual-...
```

From this point on, **do not** run `npm run build` in `/opt/eqalb/frontend`:
Vite empties its output directory, and with `dist` as a symlink that would write
into the live release. Use this automation, or build in a scratch directory and
publish by hand.

### 4.7 One-time Caddy migration to the public pointer

**Performed and verified on the VPS.** This migration is the only time the
deployment touches Caddy, and it happened as described below: every step is
ordered so the site kept serving (the public pointer was created **before**
Caddy's root changed, and the old path was kept until the new one was proven),
and nothing relaxed a directory mode - `/opt/eqalb` keeps its existing
restrictive mode (`750`, `eqalb:eqalb`) and access is granted with narrow
per-user ACLs instead.

Recorded server state after the migration:

- Caddy runs as user and group `caddy`.
- `/opt/eqalb` is still `750 eqalb:eqalb`; it was not widened.
- `/opt/eqalb/public` exists at mode `0755`, owned by
  `eqalb-deploy:eqalb-deploy`.
- ACLs: `eqalb-deploy` `--x` on `/opt/eqalb` and `/opt/eqalb/frontend`; `caddy`
  `--x` on those same two paths; `caddy` `r-x` on `/opt/eqalb/public` and
  `/opt/eqalb/frontend/releases`. No entry grants Caddy write access anywhere.
- `/opt/eqalb/public/dist` is an `eqalb-deploy`-owned symlink to
  `/opt/eqalb/frontend/releases/initial-20261013`, and that release is still the
  active one.
- `/etc/caddy/Caddyfile` uses `root * /opt/eqalb/public/dist`; Caddy was
  validated and reloaded, and `systemctl is-active caddy` reports `active`.
- Public verification returned HTTP 200 at `https://openhealth.ngo/`, and
  `https://openhealth.ngo/api/health` returned JSON with `"status":"ok"` and
  `"model_ready":true`.

The steps below are the record of how it was performed, kept so a fresh host can
repeat it, the result can be re-audited, and the migration can be rolled back.

```bash
# 0. Identify the Caddy service account. Read-only: the unit may rely on the
#    packaged default or name an explicit user, so read it instead of assuming.
#    On the deployed server this resolved to user and group `caddy`.
systemctl show -p User --value caddy      # prints e.g. "caddy"; empty means the unit runs as root
systemctl cat caddy | grep -E '^(User|Group)=' || true
getent passwd caddy                       # confirm the account actually exists
#    Use the value from the first command as $CADDY_USER below. If it is empty,
#    Caddy runs as root, needs no ACL entries, and the Caddy lines are skipped.
#    If it names a different account, substitute that name everywhere below;
#    never guess it.

# 1. The deployment-only directory, owned by the deploy account (§4.2). This is
#    the only path a normal deploy can change:
sudo install -d -m 0755 -o eqalb-deploy -g eqalb-deploy /opt/eqalb/public
#    Do NOT relax /opt/eqalb or /opt/eqalb/frontend: they keep their existing
#    restrictive modes, and step 2 grants access with ACLs instead.

# 2. Narrow per-user ACLs. setfacl comes from the `acl` package, installed by
#    default on Ubuntu (`sudo apt-get install -y acl` only if setfacl is
#    missing); access ACLs are stored on the filesystem and survive reboots.
CADDY_USER=caddy                          # the account identified in step 0
#    The deploy account needs traverse only on the parents it does not own:
sudo setfacl -m u:eqalb-deploy:--x /opt/eqalb /opt/eqalb/frontend
#    Caddy needs traverse up to the pointer directory, read+traverse of that
#    directory (to resolve the `dist` symlink name inside it), and read+traverse
#    of the release tree. New release directories are created 755/644 (the
#    script's chmod), so no per-release ACL entry is needed, and no entry grants
#    write:
sudo setfacl -m u:"$CADDY_USER":--x /opt/eqalb /opt/eqalb/frontend
sudo setfacl -m u:"$CADDY_USER":r-x /opt/eqalb/public /opt/eqalb/frontend/releases
#    Record the result and prove it before touching Caddy:
getfacl -p /opt/eqalb /opt/eqalb/frontend /opt/eqalb/public /opt/eqalb/frontend/releases
sudo -u eqalb-deploy ls /opt/eqalb/frontend/releases >/dev/null && echo 'ok: deploy can traverse releases'
sudo -u "$CADDY_USER" test -x /opt/eqalb/frontend/releases \
  && sudo -u "$CADDY_USER" test -r /opt/eqalb/frontend/releases \
  && echo 'ok: caddy can read/traverse releases'
sudo -u "$CADDY_USER" test -x /opt/eqalb/public \
  && sudo -u "$CADDY_USER" test -r /opt/eqalb/public \
  && sudo -u "$CADDY_USER" readlink /opt/eqalb/public/dist >/dev/null \
  && echo 'ok: caddy can read/traverse the public pointer directory'

# 3. Point the public symlink at the release that is live right now. Read the id
#    from the current path, then create the pointer atomically, so it is never
#    half-written. On the deployed server this produced
#    `/opt/eqalb/public/dist -> /opt/eqalb/frontend/releases/initial-20261013`:
live="$(basename "$(readlink -f /opt/eqalb/frontend/dist)")"   # or the releases/<id> you recorded
sudo -u eqalb-deploy ln -sfn "/opt/eqalb/frontend/releases/$live" /opt/eqalb/public/dist.tmp
sudo -u eqalb-deploy mv -T /opt/eqalb/public/dist.tmp /opt/eqalb/public/dist
readlink /opt/eqalb/public/dist        # expect /opt/eqalb/frontend/releases/<live>

# 4. Change Caddy's static root, and only that. One line in the site block:
#      root * /opt/eqalb/frontend/dist      ->      root * /opt/eqalb/public/dist
#    Do not change the API proxy, TLS, logging, compression, headers or
#    certificates. The tracked deploy/Caddyfile now names the same root as the
#    live file, updated once this migration was accepted (see §10).
sudo editor /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile

# 5. Reload, not restart: validate first, then apply without dropping service.
sudo systemctl reload caddy
sudo systemctl status caddy --no-pager | head -5
sudo journalctl -u caddy --since -5min | tail -20

# 6. Verify the public site through the new root.
for p in / /app /about; do
  curl -s -o /dev/null -w "GET $p -> %{http_code}\n" "https://<production-host>$p"
done
curl -s https://<production-host>/api/health      # expect "status":"ok" (the API is untouched)
```

On the deployed server this step returned HTTP 200 for
`https://openhealth.ngo/` and `"status":"ok"` with `"model_ready":true` from
`https://openhealth.ngo/api/health`.

```bash
# 7. Prove the access split: the account can move the pointer and cannot write
#    the frontend tree or the source checkout; Caddy can read the live release;
#    and /opt/eqalb still has its original restrictive mode.
CADDY_USER=caddy                       # as identified in step 0 (skip if empty)
live="$(basename "$(readlink -f /opt/eqalb/public/dist)")"
stat -c '%a %U:%G' /opt/eqalb          # expect: 750 eqalb:eqalb (unchanged)
getfacl -p /opt/eqalb | grep -E '^user:' || echo 'note: no ACL entries on /opt/eqalb'
sudo -u eqalb-deploy test -w /opt/eqalb/public && echo 'ok: pointer dir writable'
sudo -u eqalb-deploy ln -sfn "/opt/eqalb/frontend/releases/$live" /opt/eqalb/public/dist.probe \
  && sudo -u eqalb-deploy rm -f /opt/eqalb/public/dist.probe && echo 'ok: pointer replaceable'
sudo -u eqalb-deploy touch /opt/eqalb/frontend/forbidden 2>/dev/null \
  && { echo 'FAIL: frontend dir writable'; rm -f /opt/eqalb/frontend/forbidden; } \
  || echo 'ok: frontend dir not writable'
sudo -u eqalb-deploy touch /opt/eqalb/frontend/readme.md 2>/dev/null \
  && echo 'FAIL: source writable' || echo 'ok: source not writable'
sudo -u "$CADDY_USER" test -r "/opt/eqalb/frontend/releases/$live/index.html" \
  && echo 'ok: caddy can read the live release' || echo 'FAIL: caddy cannot read the live release'
sudo -u "$CADDY_USER" test -r /opt/eqalb/public \
  && sudo -u "$CADDY_USER" readlink /opt/eqalb/public/dist >/dev/null \
  && echo 'ok: caddy can read/traverse the public pointer directory' \
  || echo 'FAIL: caddy cannot resolve the public pointer'
```

```bash
# 8. Rollback of this migration, if it had failed. The old path exists until it
#    is removed, so restoring it is one edit:
sudo editor /etc/caddy/Caddyfile       # root * /opt/eqalb/public/dist -> root * /opt/eqalb/frontend/dist
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
curl -s -o /dev/null -w '%{http_code}\n' https://<production-host>/   # expect 200
#    The public pointer is then unused and harmless; fix the migration and
#    repeat steps 4-7, or leave Caddy on the old root and treat the automation
#    as not yet adopted. The ACLs are additive and harmless; remove them with
#    `sudo setfacl -x u:<user> <path>` if the migration is abandoned entirely.
#
#    The migration has since been accepted, so the old, now-unused symlink is
#    no longer needed and can be removed at any time - if it is still present -
#    as root, so no second, drifting copy of "the live path" exists:
sudo rm -f /opt/eqalb/frontend/dist
#    After that removal, a Caddy rollback to the old root is no longer possible
#    without recreating the symlink; use the script's rollback instead (§7).
#    Removed or not, it never affects the served path: Caddy only ever reads
#    /opt/eqalb/public/dist.
```

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
staging directory, and `/opt/eqalb/public/dist` keeps pointing at the previous
release.

If activation succeeds but any public check fails, the deploy job invokes the
script's `rollback` mode with the reported previous release id, which repoints
the public pointer in one rename, and the workflow fails. The failed release
directory stays on disk for inspection; it is not the live release.

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
readlink /opt/eqalb/public/dist                       # current release
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
everything; pruning is a manual, explicit act - list the releases, check the
pointer, and remove only the directories you no longer want:

```bash
du -sh /opt/eqalb/frontend/releases/* | sort -h
readlink /opt/eqalb/public/dist                        # never remove this release
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

- **Server side migrated and verified; no automated release yet.** The one-time
  public-pointer and Caddy migration (§4.7) has been performed and verified on
  the VPS: `/opt/eqalb` is still `750 eqalb:eqalb` (never widened, and no broad
  `chmod` was used), `/opt/eqalb/public` is `0755 eqalb-deploy:eqalb-deploy`,
  `/opt/eqalb/public/dist` is an `eqalb-deploy`-owned symlink to
  `/opt/eqalb/frontend/releases/initial-20261013` (still the active release),
  `/etc/caddy/Caddyfile` uses `root * /opt/eqalb/public/dist`, Caddy was
  validated and reloaded and `systemctl is-active caddy` reports `active`, and
  the public checks returned HTTP 200 at `https://openhealth.ngo/` and
  `"status":"ok"` with `"model_ready":true` at
  `https://openhealth.ngo/api/health`. The CI key rotation is complete as well:
  a new passphrase-free CI-only Ed25519 key was created, installed behind the
  restricted forced-command wrapper, tested, rotated into the `production`
  secret `DEPLOY_SSH_KEY`, and the old key removed. What remains is the
  automation run itself: the first workflow run has not happened, and the
  `production` environment's required-reviewer/approval rule must be confirmed
  with the operator first. The first run is a controlled test of the workflow:
  confirm the approval rule, then watch one deploy end to end (§5) - including a
  rollback - before treating the automation as supported.
- The action pins are full commit SHAs written from the actions' published
  releases (`v4.2.2`, `v4.4.0`, `v4.6.2`, `v4.3.0`). Confirm each with
  `git ls-remote https://github.com/<owner>/<action> refs/tags/<tag>` before the
  first run; a wrong pin fails the workflow before it reaches the server.
- The design relies on Caddy resolving the static root per request, so replacing
  the `/opt/eqalb/public/dist` symlink changes what is served with no reload.
  The migration verified that Caddy serves through the public pointer, but a
  live swap under a running Caddy has not been exercised yet - the first
  automated deploy (or a rollback after it) is where that is proven. If a future
  Caddy release pinned the resolved root at load time, the new bundle would not
  be served, the validation check would fail, the automatic rollback would
  restore the previous target, and the limitation would need an operator
  decision - this automation never reloads or restarts Caddy.
- The deploy account owns `/opt/eqalb/public`, `releases/` and `incoming/`, so a
  compromised key could modify those paths (not the frontend source, Caddy's
  files or the API). That is the approved blast radius of the CI key, and the
  reason the key is single-purpose, passphrase-free, and replaceable in minutes
  (§4.4).
- Releases are immutable by convention rather than by ownership: the script never
  overwrites an existing release and strips group/world write bits, but an
  automated release stays owned by the deploy account, which could still rewrite
  it directly. Making releases root-owned would require privileges the script
  deliberately does not have.
- Old releases and incoming archives are never pruned automatically (§9).
- Every push to the watched paths on `main` is a production release candidate;
  there is no staging environment and no per-commit opt-out. That is the
  deliberate Version 1 scope.
- This automation deploys the static frontend only. API, R, Caddy, systemd, DNS
  and server configuration changes still follow `deploy/DEPLOY.md`, by hand; the
  one static-root change in §4.7 has already been performed and verified.
