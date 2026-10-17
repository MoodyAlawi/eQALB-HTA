# Automated frontend releases (GitHub Actions + one root-owned script)

Optional automation that ships **only** the static Vue/Vite bundle: GitHub Actions
builds it, uploads it, and a root-owned script on the server moves it into an
immutable release directory and repoints a symlink that Caddy serves. It never
restarts the API, never reloads Caddy, and never touches R, Python or the unit.

This is a template for your own server. Placeholders are the same as in
[`DEPLOY.md`](./DEPLOY.md).

## 1. What it deploys, and what it must never touch

Deployed:

- The contents of `frontend/`, built by GitHub Actions into `frontend/dist`,
  packaged as `frontend-<release-id>.tar.gz` with a SHA-256 checksum file.
- The `<app-path>/public/dist` symlink — the deployment's only mutable path —
  repointed atomically to a new immutable release under
  `<app-path>/frontend/releases/`. That is the symlink Caddy serves.

Never touched, by design and by construction:

- R, `renv`, R packages, `/opt/R/<version>`.
- Python, `api/` and its packages, the `<service-name>` unit, the API's
  environment file, and any API restart.
- Caddy's configuration, certificate handling, logging, compression, headers or
  TLS settings — and no Caddy reload or restart.
- DNS, registrar records, firewall rules, the deploy account and its key.
- The Git checkout on the server: the bundle is built in GitHub Actions and the
  server-side script performs no git operation.

The API stays independent. A frontend release cannot restart, reconfigure or
even observe it; the only API contact anywhere in this automation is one
read-only `GET /api/health` during validation.

## 2. How a release is laid out on the server

```
<app-path>/public/                             # deployment-only; owned by <deploy-user>
  dist -> <app-path>/frontend/releases/<id>    # the one mutable path; Caddy serves this
  .deploy.lock                                 # flock target; two deployments never overlap
<app-path>/frontend/
  incoming/                                    # the workflow's SCP target: archive + checksum
  releases/<release-id>/                       # immutable release: index.html + assets/
<app-path>/bin/
  frontend-deploy.sh                           # root-owned; exactly two operations
  frontend-deploy-wrapper                # root-owned; the deployment key's forced command
```

A release id is a directory name matching `[A-Za-z0-9][A-Za-z0-9._-]{0,63}`. The
workflow generates `<run-number>-<40-hex commit>`, which is unique per run and
auditable back to a commit. Hand-made releases must satisfy the same pattern.

Nothing is deleted by the automation: the current release and every earlier one
stay on disk, so a rollback to any retained release is one command, and the
immediately previous release is always available to the automatic rollback.

The deploy account owns only `public/`, `frontend/releases/` and
`frontend/incoming/`. It must not own — or be able to write — `frontend/` itself
or the rest of the checkout, so it can publish releases and move the pointer but
can never modify the source, the API, `deploy/` or Caddy's files. Never
`chown -R <deploy-user> <app-path>/frontend`.

Traversal is granted per user with ACLs, never by relaxing a directory mode:
`<app-path>` keeps its restrictive mode (for example `750 <app-user>:<app-user>`),
the deploy account gets traverse-only ACLs on the parent paths, and the Caddy
service account gets traverse-only ACLs on the parents plus read-and-traverse on
`public/` and the release tree, with no write access anywhere.

## 3. The workflow

`.github/workflows/deploy-frontend.yml`.

| Trigger | What runs |
|---|---|
| Push touching `frontend/**`, `deploy/**` or the workflow | Build job, then the deploy job behind the environment. |
| Manual dispatch with `rollback_release_id` set | The rollback job only. No build, no activation. |
| Manual dispatch with the input empty | The rollback job fails immediately; nothing reaches the server. |

Build job: `npm ci`, `npm run build`, a check that the output names no source
maps and references an `/assets/` file, then the archive and its checksum.
Deploy job: upload to `incoming/`, call the wrapper's `activate`, then verify
`/api/health` and the public URL; on failure it calls the wrapper's `rollback` to
the previously active release and reports that clearly.

Action pins are full commit SHAs, taken from each action's published release. If
you bump one, confirm the pin with
`git ls-remote https://github.com/<owner>/<action> refs/tags/<tag>`.

### Environment secrets

Create an environment (for example `production`) and add these:

| Secret | Meaning |
|---|---|
| `DEPLOY_SSH_HOST` | Server host name or address. |
| `DEPLOY_SSH_PORT` | SSH port (defaults to 22 in the workflow). |
| `DEPLOY_SSH_USER` | The dedicated frontend deploy account, `<deploy-user>`. |
| `DEPLOY_SSH_KEY` | The dedicated, passphrase-free, CI-only Ed25519 private key. |
| `DEPLOY_KNOWN_HOSTS` | The pinned public host key line(s). |
| `DEPLOY_PUBLIC_BASE_URL` | Public base URL used for verification, for example `https://<your-domain>`. |

## 4. One-time manual bootstrap (root on the host)

Everything here is done by an operator, by hand, once. The workflow does none of
it.

### 4.1 A dedicated deploy account

```bash
sudo adduser --disabled-password --gecos '' <deploy-user>
# No sudo, no extra groups. It owns exactly the three directories created in
# §4.2 and nothing else.
```

### 4.2 Directories, the script and the lock

```bash
sudo mkdir -p <app-path>/bin
sudo install -d -m 0755 -o <deploy-user> -g <deploy-user> <app-path>/public
sudo install -d -m 0755 -o <deploy-user> -g <deploy-user> <app-path>/frontend/releases
sudo install -d -m 0750 -o <deploy-user> -g <deploy-user> <app-path>/frontend/incoming

# The script is installed root-owned and not writable by the deploy account,
# from a reviewed checkout on the server. This is the only step that touches the
# Git checkout, and it is an operator action, not the workflow's.
sudo install -o root -g root -m 0755 \
  <app-path>/deploy/frontend-deploy.sh <app-path>/bin/frontend-deploy.sh
```

The lock file (`<app-path>/public/.deploy.lock`) is created by the script on
first use inside a directory the account already owns.

The script has exactly two operations, `activate` and `rollback`, and no other
input than a validated release id and the two exact incoming paths it derives
itself. It never installs packages, downloads, evaluates a caller-supplied shell
or string, deletes a wildcard, or runs git, sudo, systemd or Caddy.

### 4.3 The forced-command wrapper

The deployment key must not open a shell. Save this as
`./frontend-deploy-wrapper`, replace `<app-path>` with your path, and
install it root-owned mode 0755:

```bash
sudo install -o root -g root -m 0755 ./frontend-deploy-wrapper \
  <app-path>/bin/frontend-deploy-wrapper
```

```bash
#!/usr/bin/env bash
# Root-owned forced command for the deployment key. Accepts exactly three
# request shapes and executes nothing else.
set -euo pipefail

readonly DEPLOY_SCRIPT="<app-path>/bin/frontend-deploy.sh"
readonly INCOMING_DIR="<app-path>/frontend/incoming"

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
    printf 'frontend-deploy-wrapper: refusing request\n' >&2
    exit 64
    ;;
esac
```

The wrapper parses the request into arguments and only ever `exec`s two fixed
programs with those arguments — no `eval`, no `bash -c`, no path taken from the
request. `scp` is accepted because a forced command also replaces the SFTP/SCP
subsystem, which is why the workflow uses the legacy protocol (`scp -O`); that
protocol's remote side is `scp -t <incoming dir>`, exactly what the wrapper
permits.

### 4.4 The CI-only deploy key, and how to rotate it

A dedicated, passphrase-free, CI-only Ed25519 key. It is passphrase-free because
the workflow writes the private half to a file and authenticates with
`-o BatchMode=yes` — no agent, no TTY, so a passphrase could never be entered.
Its safety comes from its restrictions, not from a passphrase: the forced-command
wrapper and the `restrict` `authorized_keys` entry.

```bash
# On the operator's machine, outside this repository.
ssh-keygen -t ed25519 -N '' -C '<deploy-user>-ci' -f "$HOME/.ssh/deploy-ci"
ssh-keygen -y -f "$HOME/.ssh/deploy-ci" </dev/null >/dev/null && echo 'no passphrase: OK'
gh secret set DEPLOY_SSH_KEY --env production < "$HOME/.ssh/deploy-ci"
```

On the server, for the deploy account only, add one line to
`~<deploy-user>/.ssh/authorized_keys` (mode 0600, directory 0700):

```text
restrict,command="<app-path>/bin/frontend-deploy-wrapper" ssh-ed25519 AAAA...the public key...
```

Keeping `.ssh` and `authorized_keys` root-owned means the deploy account cannot
change or remove its own restriction. `restrict` disables the pty, agent and port
forwarding.

To rotate without a lockout: add the new public key as a second line, update the
secret, run one deployment to prove the new key works, then remove the old line.

### 4.5 GitHub: the environment

Create the `production` environment, add the six secrets from §3, and decide
whether it needs required reviewers. An approval rule is the only thing that
stops a push from deploying immediately.

### 4.6 If the live build is still a real directory

If the server currently serves `<app-path>/frontend/dist` as an ordinary
directory, either keep that arrangement and skip this automation, or move to the
public-pointer model in one deliberate step: build once more into
`releases/manual-<timestamp>/`, create `public/dist` as a symlink to it, and only
then change Caddy's root (below). Never point Caddy at a path the deploy account
can write directly.

### 4.7 One-time Caddy migration to the public pointer

```bash
# 1. Grant access with ACLs, not modes.
sudo setfacl -m u:<deploy-user>:x  <app-path>
sudo setfacl -m u:<deploy-user>:x  <app-path>/frontend
sudo setfacl -m u:caddy:x          <app-path>
sudo setfacl -m u:caddy:x          <app-path>/frontend
sudo setfacl -R -m u:caddy:rX      <app-path>/public <app-path>/frontend/releases

# 2. Move Caddy's static root from the build directory to the pointer.
sudo editor /etc/caddy/Caddyfile    # root * <app-path>/public/dist
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo systemctl is-active caddy

# 3. Verify.
curl -sS -o /dev/null -w '%{http_code}\n' https://<your-domain>/
curl -s  https://<your-domain>/api/health
```

Caddy resolves the symlink per request, so later releases need no reload. Do not
change the API proxy, TLS, logging, compression or header settings as part of
this migration.

## 5. Normal deploy sequence

1. Merge to the deployment branch (or start the workflow manually with the input
   empty).
2. The build job produces the archive and checksum; the deploy job uploads both
   with two separate single-file legacy `scp` calls, then calls
   `activate <release-id> <archive> <checksum>`.
3. The script verifies the checksum, extracts into
   `releases/<release-id>/`, sanity-checks `index.html`, repoints the symlink and
   prints the previous release id.
4. The workflow verifies `/api/health` and the public URL.

## 6. Failed deploy: automatic rollback

If validation fails after activation, the workflow calls
`rollback <previous-release-id>` and reports the failure; the site returns to the
previous release without an operator. If no previous release exists, it says so
explicitly and leaves the pointer where it is — inspect before changing anything
by hand.

## 7. Manual rollback (one command)

Through the workflow: **Actions → Deploy frontend → Run workflow** with
`rollback_release_id` set to a retained release directory name.

Directly over SSH, if you need to bypass the workflow:

```bash
ssh -T <deploy-user>@<host> 'rollback <release-id>'   # via the forced command
```

Or, as root on the server:

```bash
sudo <app-path>/bin/frontend-deploy.sh rollback <release-id>
```

## 8. Re-running a failed deployment

Re-run the workflow. A release id is unique per run, so a retry never collides
with a partially uploaded or partially extracted release. Incoming files from a
failed upload are overwritten by the next attempt; remove them by hand only if
you are short of disk.

## 9. Retention and disk use

Every release stays until an operator removes it. Keep the current release plus a
few predecessors, then delete the oldest directories explicitly:

```bash
ls -1t <app-path>/frontend/releases
sudo rm -rf <app-path>/frontend/releases/<old-release-id>
```

Never delete the release the symlink points at. `readlink -f <app-path>/public/dist`
tells you which one that is.

## 10. Limitations

- The automation assumes the public-pointer layout. A host that serves the build
  directory directly must migrate first (§4.6, §4.7) or keep using the manual
  build in `DEPLOY.md`.
- Validation uses one `GET /api/health`; it proves the API answers, not that the
  bundle is correct. A browser smoke test after a release is still worthwhile.
- Nothing prunes old releases; disk use grows until an operator acts.
- `scp -O` (legacy protocol) is required because the forced command stands in for
  the SFTP subsystem. A future OpenSSH that removes the legacy protocol would
  require moving to an upload subcommand in the wrapper.