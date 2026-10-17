# Backend production deployment (GitHub Actions, manual first version)

Status: **implemented in the repository, not yet run against production.** The
workflow is manual-only. The first live deploy, the first live rollback and the
`backend-production` environment are still outstanding; until they have been
done, treat this automation as unverified. [`DEPLOY.md`](./DEPLOY.md) remains the
host runbook (packages, R, the API service, DNS, Caddy) and the manual fallback.

This document covers only the FastAPI backend and its R workers. The frontend has
its own automation in [`FRONTEND_DEPLOY.md`](./FRONTEND_DEPLOY.md), and neither
workflow touches the other's files or services.

## 1. What it deploys, and what it must never touch

Deployed by this automation:

- One committed revision of the repository in `/opt/eqalb`, checked out by its
  full Git SHA (reproducible from that SHA alone).
- The pinned Python dependencies in `/opt/eqalb/.venv`, installed from
  `api/requirements.lock.txt`.
- The project `renv` library, restored from `renv.lock` with
  `/opt/R/4.5.1/bin/Rscript`.
- The `eqalb-api` systemd service, restarted once the dependency steps succeed.

Never touched:

- `app.R`, `run_app.R` and the Posit Connect Shiny deployment.
- Any R model module, `api/main.py`, `api/plumber.R`, the frontend, exports or
  application defaults. The automation ships the committed files unchanged; it
  does not edit them.
- `/etc/eqalb/api.env`, `/etc/systemd/system/eqalb-api.service`, the Caddy
  configuration, DNS, firewall rules, certificates or the frontend symlink.
- The R installation in `/opt/R/4.5.1` (it is only used, never rebuilt).

## 2. The deployed topology this relies on

Inspection of the repository and runbook established:

| Item | Value |
|---|---|
| Project path | `/opt/eqalb` (the Git checkout) |
| Service | `eqalb-api.service` |
| Service account | `eqalb` |
| Process manager | systemd |
| API listener | `127.0.0.1:8000` (loopback only; Caddy proxies `/api/*`) |
| Health | `GET http://127.0.0.1:8000/api/health`, publicly `https://openhealth.ngo/api/health` |
| R | `/opt/R/4.5.1/bin/Rscript`; R 4.5.1 is recorded in `renv.lock` |
| R packages | the project `renv` library, restored from `renv.lock` |
| Python | `/opt/eqalb/.venv/bin/python`; pinned by `api/requirements.lock.txt` |
| R workers | children of the FastAPI process (`api/r_client.py`), no separate unit, no port |
| Server-local settings | `/etc/eqalb/api.env` (root:eqalb, mode 0640) |

`eqalb-api.service` is the only process manager entry. Its unit uses
`KillMode=control-group`, so restarting it stops and starts the API **and every R
worker child** together. There is no R worker service to restart separately.

Observed on the live host while writing this: `/api/health` reports `status: ok`,
`model_ready: true`, and `configured_workers: 2`, `ready_workers: 2`, with
`rscript: /opt/R/4.5.1/bin/Rscript`. The committed `deploy/api.env.example` sets
`EQALB_R_WORKERS=1`; the live host is server-local configuration and is **not**
changed by this workflow. The health check accepts any positive number of ready
workers and warns when fewer than configured are ready, so it works with either
setting.

## 3. How a deployment runs

Workflow: [`.github/workflows/deploy-backend.yml`](../.github/workflows/deploy-backend.yml).

1. A maintainer starts **Deploy backend** manually (`workflow_dispatch`) with
   `mode = deploy` and a branch, tag or full SHA in `ref` (default `main`).
2. The workflow checks out that ref, resolves it to a full 40-character commit
   SHA, and validates that the required deploy secrets exist. The server checks
   out that resolved SHA, so a branch that moves during the run cannot change
   what is deployed.
3. It writes the SSH private key and the pinned `known_hosts` line to the
   runner's `~/.ssh`, confirms the key is unencrypted, and connects with
   `StrictHostKeyChecking=yes`, `BatchMode=yes`, and only that pinned host key.
4. It pipes the committed `deploy/backend-deploy.sh` from the runner to
   `bash -s` on the VPS as the SSH deploy user (default `ubuntu`). The script is
   the one from the selected commit, not whatever copy is on the server.
5. On the server the script:
   - takes a `flock` deployment lock, checks the state directory, the service
     account, passwordless sudo, `/etc/eqalb/api.env` and `EQALB_RSCRIPT`;
   - records the current checkout HEAD and refuses to overwrite tracked local
     changes;
   - fetches `origin` (with prompts disabled), unshallows if needed, checks out
     the requested SHA, and verifies `HEAD`;
   - installs `api/requirements.lock.txt` into `.venv` and runs `pip check` and
     an import check;
   - verifies the R version against `renv.lock`, runs
     `renv::restore(prompt = FALSE)`, and requires
     `renv::status()$synchronized` to be `TRUE`;
   - only then restarts `eqalb-api.service` and polls
     `http://127.0.0.1:8000/api/health` (3 s interval, 180 s timeout);
   - on success writes the deployed SHA, deployment time and previous known-good
     SHA to `/var/lib/eqalb-backend-deploy/state.env`, appends a line to
     `history.log`, and prints `DEPLOYED_SHA=`, `DEPLOYED_AT=`, `PREVIOUS_SHA=`,
     `ACTION=` and `HEALTH=ok`.
6. The workflow checks the server-reported SHA/time, then verifies the public
   `https://openhealth.ngo/api/health` response with the same health rules. The
   job summary records the commit, deployment time, previous known-good commit
   and the workflow run.
7. The SSH key material is removed from the runner at the end, on success or
   failure.

Ordering is deliberate: checkout and both dependency installs happen **before**
the restart. If `git`, `pip` or `renv` fails, the old API process is still
running and serving. The checkout has moved, but nothing restarted it. The
script's exit message prints the rollback command for that case.

## 4. Required GitHub secrets

Create a **separate** environment named `backend-production` (recommended: add
`main` as a deployment branch and one or more required reviewers). The existing
`production` environment's key is restricted to the frontend forced command and
cannot run backend commands, so do not reuse it.

Environment secrets:

| Secret | Required | Meaning |
|---|---|---|
| `BACKEND_DEPLOY_SSH_HOST` | yes | VPS host name or address. Never committed; supplied only here. |
| `BACKEND_DEPLOY_SSH_PORT` | no | SSH port; the workflow defaults to 22. |
| `BACKEND_DEPLOY_SSH_USER` | no | SSH deploy account; the workflow defaults to `ubuntu`. |
| `BACKEND_DEPLOY_SSH_KEY` | yes | Dedicated, unencrypted, CI-only OpenSSH private key. Never an operator's personal key. |
| `BACKEND_DEPLOY_KNOWN_HOSTS` | yes | The host's pinned public host key line(s), from `ssh-keyscan` or `/etc/ssh/ssh_host_*_key.pub`. |

Create the environment and set the secrets with the GitHub CLI (replace the
repository if it is forked):

```bash
gh api --method PUT repos/MoodyAlawi/eQALB-HTA/environments/backend-production

gh secret set BACKEND_DEPLOY_SSH_HOST --env backend-production
gh secret set BACKEND_DEPLOY_SSH_PORT --env backend-production   # optional
gh secret set BACKEND_DEPLOY_SSH_USER --env backend-production   # optional
gh secret set BACKEND_DEPLOY_SSH_KEY --env backend-production < eqalb-backend-deploy-ci
gh secret set BACKEND_DEPLOY_KNOWN_HOSTS --env backend-production < known_hosts
```

`gh secret set` without a value prompts, so the value does not enter shell
history. Use environment secrets, not repository secrets, so only jobs that pass
the `backend-production` protections receive them. The public health URL is
`https://openhealth.ngo/api/health`, set as `PUBLIC_HEALTH_URL` in the
workflow's `env` block; change that one line for a fork or a different
production domain.

### Creating the CI key and the pinned host key

On a trusted workstation:

```bash
ssh-keygen -t ed25519 -N '' -C 'eqalb-backend-deploy-ci' -f eqalb-backend-deploy-ci
```

Install the **public** half on the VPS in the deploy user's
`~/.ssh/authorized_keys`, prefixed with `restrict` so the key cannot open a PTY
or forward ports/agents. As the deploy user on the VPS:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
printf '%s\n' 'restrict ssh-ed25519 AAAA... eqalb-backend-deploy-ci' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

`restrict` is supported by OpenSSH 7.2+ (Ubuntu 26.04 has it). The workflow uses
`ssh -T` and `sudo -n`, so it does not need a PTY. Store the **private** half as
`BACKEND_DEPLOY_SSH_KEY`, then remove the local copy or keep it in the team's
password manager. Rotate by adding a new public key, updating the secret, and
removing the old public key.

Pin the host key from a trusted network and verify the fingerprint out of band
before storing it. Use the same port as `BACKEND_DEPLOY_SSH_PORT`, and use the
same host spelling in `ssh-keyscan` as in `BACKEND_DEPLOY_SSH_HOST`; SSH looks
the key up under the name or address it connects to, and a non-default port is
stored as `[host]:port`.

```bash
ssh-keyscan -p <ssh-port> -t ed25519 <vps-host> > known_hosts
ssh-keygen -lf known_hosts
gh secret set BACKEND_DEPLOY_KNOWN_HOSTS --env backend-production < known_hosts
```

Do not commit `known_hosts`, the key, the host address or the port. Store the
private key and `known_hosts` with Unix line endings; a CRLF copy may fail the
workflow's key check or the host-key match.

## 5. One-time server bootstrap

Everything here is done by an operator, once. The workflow does none of it.

### 5.1 State directory and least-privilege sudo

The script runs as the SSH deploy user (not root). It needs exactly two sudo
capabilities: run application commands as `eqalb`, and restart the one service.
For the default `ubuntu` account:

```bash
sudo install -d -m 0700 -o ubuntu -g ubuntu /var/lib/eqalb-backend-deploy

sudo tee /etc/sudoers.d/eqalb-backend-deploy >/dev/null <<'EOF'
ubuntu ALL=(eqalb) NOPASSWD: ALL
ubuntu ALL=(root) NOPASSWD: /usr/bin/systemctl restart eqalb-api.service
EOF
sudo chmod 0440 /etc/sudoers.d/eqalb-backend-deploy
sudo visudo -cf /etc/sudoers.d/eqalb-backend-deploy
```

`(eqalb) NOPASSWD: ALL` is application-account access, not root: it lets the
deploy user install that account's code and dependencies. Root access is limited
to restarting `eqalb-api.service`. If the deploy user already has broad
passwordless sudo, these entries still work but do not give the least-privilege
split; prefer the dedicated entries.

The workflow uses `ssh -T` and `sudo -n`, so no TTY is available. Do not set
`Defaults requiretty` for this account; Ubuntu's default does not. The preflight
`sudo -n` checks fail fast if a password or a TTY is required.

If you use a dedicated account instead of `ubuntu`, create it, own the state
directory with it, and replace `ubuntu` in the sudoers file. Set
`BACKEND_DEPLOY_SSH_USER` accordingly. A dedicated account is the better
least-privilege choice; `ubuntu` is the documented default because that is the
existing operator account.

### 5.2 Verify the server prerequisites

Run these as the deploy user, or adjust for the account you chose:

```bash
# The service and its current health.
systemctl is-active eqalb-api
curl -s http://127.0.0.1:8000/api/health

# The checkout is on origin and can be fetched without a prompt.
sudo -u eqalb git -C /opt/eqalb remote -v
sudo -u eqalb env GIT_TERMINAL_PROMPT=0 git -C /opt/eqalb fetch --dry-run origin

# The pinned environments exist and are usable.
sudo -u eqalb /opt/eqalb/.venv/bin/python --version
sudo -u eqalb /opt/eqalb/.venv/bin/python -m pip --version
cd /opt/eqalb
sudo -u eqalb -H /opt/R/4.5.1/bin/Rscript --version        # expect 4.5.1
sudo -u eqalb -H /opt/R/4.5.1/bin/Rscript -e 'renv::status()'
sudo -u eqalb sed -n 's/^EQALB_RSCRIPT=//p' /etc/eqalb/api.env

# The tools the script uses, and the two sudo grants.
command -v git curl python3 flock systemctl
sudo -n -u eqalb -- true
sudo -n -l "$(command -v systemctl)" restart eqalb-api.service
```

Use the path printed by `command -v systemctl` in the sudoers entry too; on
Ubuntu it is `/usr/bin/systemctl`.

The repository is public, so an HTTPS `origin` needs no credentials. If the
server's checkout uses SSH, `eqalb` needs its own read-only key; that access is
not part of this automation. Verify it rather than assuming it.

`renv::status()` must report the library and lockfile as synchronized before the
first automated run. If it does not, fix it with `DEPLOY.md` section 3.2 first;
the deployment script will intentionally refuse to restart over an
unsynchronized library.

The Python virtual environment and `renv` library are assumed to be the ones
`DEPLOY.md` section 3 created. The script will create `.venv` if it is missing,
but it will not recreate `/opt/R/4.5.1` or install R packages outside `renv`.

## 6. First deployment

1. Add the `backend-production` environment and the secrets above (three are
   mandatory; the port and user secrets have defaults).
2. In GitHub: **Actions → Deploy backend → Run workflow**.
   - `mode`: `deploy`
   - `ref`: `main` (or the exact commit/tag you want)

   Or from the GitHub CLI:

   ```bash
   gh workflow run deploy-backend.yml --ref main -f mode=deploy -f ref=main
   ```

3. Approve the environment if required reviewers are configured.
4. Check the run summary: it must show the requested and deployed commit (the
   same full SHA), a UTC deployment time, the previous known-good SHA, and a
   successful public health check.
5. On the server, confirm the recorded state and the running service:

   ```bash
   cat /var/lib/eqalb-backend-deploy/state.env
   sudo -u eqalb git -C /opt/eqalb rev-parse HEAD
   systemctl status eqalb-api --no-pager | head -20
   curl -s http://127.0.0.1:8000/api/health
   curl -s https://openhealth.ngo/api/health
   ```

6. Run a manual rollback to the recorded previous commit (next section), confirm
   it passes health, then deploy `main` again. Only after both directions have
   been verified should the automatic `push` trigger be enabled.

The first run can take longer than later ones because `pip` and `renv` may need
to download or compile changed packages. The 180-second health timeout starts
only after installation, so it does not cover dependency download time. The job
itself has a 30-minute timeout; if it expires before the restart, the old process
keeps running. If it expires after the restart, treat it like a failed health
check and use the rollback.

## 7. Rollback

There is **no automatic rollback** in this version. A failed health check fails
the workflow and prints the service diagnostics; the operator decides.

Through the same workflow (recommended):

- **Actions → Deploy backend → Run workflow**
- `mode`: `rollback`
- `rollback_sha`: empty to restore the last known-good revision recorded on the
  server, or a full 40-character SHA for a specific earlier commit.

  From the GitHub CLI:

  ```bash
  # Restore the last known-good revision recorded on the server.
  gh workflow run deploy-backend.yml --ref main -f mode=rollback -f ref=main

  # Restore a specific commit.
  gh workflow run deploy-backend.yml --ref main \
    -f mode=rollback -f ref=main -f rollback_sha=<full-commit-sha>
  ```

With an empty target, the server chooses:
- the **previous recorded deployment** when the last attempt succeeded, so a
  normal rollback undoes the deployment that is running; or
- the **last recorded successful deployment** (or, on a first run, the checkout
  that was in place before the attempt) when the last attempt did **not**
  complete. This is what the `pending.env` state file is for.

The `ref` input for a rollback selects the copy of `deploy/backend-deploy.sh`
that is piped to the server; it does not select the rollback target.

The target SHA must be reachable from the server's `origin` (any fetched branch
or tag). A commit that exists only in a local clone cannot be fetched by the
server and the deployment fails with a clear "commit not available" error.

Directly over SSH, using the local script so a broken or half-deployed checkout
cannot block the rollback:

```bash
ssh -T <deploy-user>@<vps-host> 'bash -s -- rollback' < deploy/backend-deploy.sh
ssh -T <deploy-user>@<vps-host> 'bash -s -- rollback <full-commit-sha>' < deploy/backend-deploy.sh
```

On the VPS as the deploy user, after the checkout is usable:

```bash
cd /opt/eqalb
bash deploy/backend-deploy.sh status
bash deploy/backend-deploy.sh rollback
bash deploy/backend-deploy.sh rollback <full-commit-sha>
```

A rollback is a full deployment of the older SHA: it checks out that commit,
reinstalls its Python lock and its `renv.lock`, restarts the service and
health-checks it. It is not instantaneous and briefly restarts the API. If the
older commit's lockfiles differ, packages are downloaded/downgraded as needed.

After a successful rollback to a **different** revision, the state file records
the restored SHA as current and the SHA it replaced as previous, so a
roll-forward is possible with another `rollback` or `deploy`. If the rollback
restores the revision that is already recorded as current — the usual recovery
after a failed attempt — the recorded previous known-good is kept rather than
replaced by itself.

## 8. Health check and failure behaviour

A run is healthy only when all of these are true:

- `GET /api/health` returns HTTP 200.
- `status` is `"ok"`.
- `model_ready` is `true`.
- `r_model.ready_workers` is at least 1.
- `r_model_error` is `null`.

The endpoint returns HTTP 200 even when the model is degraded, so the check
parses the JSON body rather than relying on the status code alone. The server
check is private (`127.0.0.1:8000`); the workflow then repeats the same rules
against the public `https://openhealth.ngo/api/health`. A public-only failure
with a healthy private check points at Caddy, TLS, DNS or the network, not at the
new backend; the backend deployment is still recorded, and the workflow still
fails so the problem is not silent.

Failure outcomes:

| Failure point | Service state | Automatic rollback |
|---|---|---|
| Secret/key/SSH/preflight | untouched | no |
| `git fetch` or checkout | old process still running | no |
| `pip install` / `pip check` | old process still running | no |
| `renv::restore` / `renv::status` | old process still running | no |
| `systemctl restart` | restart attempted, may have failed | no |
| local health timeout | target commit may be running | no |
| public health check | target commit is running; private check passed | no |

Every failure exits non-zero, and the script prints the last health response,
`systemctl status`, recent `journalctl` lines and the running `Rscript`
processes where it can. An interrupted or failed attempt is recorded in
`pending.env`, so the manual rollback can choose the last known-good revision.
The workflow never echoes the SSH key or a secret, and GitHub masks secret
values in logs.

## 9. State, known-good retention and audit

`/var/lib/eqalb-backend-deploy/` (owned by the deploy user, mode 0700) contains:

- `state.env`: `CURRENT_SHA`, `CURRENT_DEPLOYED_AT`, `PREVIOUS_SHA`,
  `PREVIOUS_DEPLOYED_AT`. Written atomically only after a successful health
  check. `CURRENT_SHA` is always a revision that passed the deployment health
  check (or the initial checkout verified by the prerequisites).
- `pending.env`: `PENDING_SHA`, `PENDING_ACTION`, `PENDING_AT`,
  `PENDING_BASE_SHA`. Written after the checkout and before dependency
  installation, and removed only after a successful health check. It records an
  interrupted or failed attempt so a bare `rollback` restores the last
  known-good revision rather than the failed one.
- `history.log`: one tab-separated line per completed deployment or rollback:
  UTC time, action, deployed SHA, previous SHA, deploy user.
- `deploy.lock`: the `flock` target; two deployments cannot overlap.

"Previous known-good" is a Git SHA, not a copied directory. The full commit and
its lockfiles remain in the server checkout's Git history, so the rollback can
reconstruct that deployment. The server's Git fetch may need to unshallow a
shallow checkout the first time; the script does that automatically.

## 10. Enabling automatic deployment

The workflow intentionally has no `push` trigger yet. After a manual deploy and
a manual rollback have both been verified, uncomment the block under `on:`:

```yaml
  push:
    branches: [main]
    paths:
      - 'api/**'
      - 'eqalb_*.R'
      - '.Rprofile'
      - 'renv.lock'
      - 'renv/**'
      - 'deploy/backend-deploy.sh'
      - '.github/workflows/deploy-backend.yml'
```

The workflow already defaults `mode` to `deploy` and `ref` to `main` when those
inputs are absent, so the same job works for a push run. Keep the
`backend-production` environment's required reviewers if you want a human gate
even for automatic runs; without it, a push to `main` deploys immediately.

Do not include `frontend/**`; the frontend has its own workflow and deployment
account. Do not include `app.R`; it is not part of the browser-stack backend.

## 11. What was verified locally, and what needs a live run

Verified in the repository, without a VPS or GitHub secrets:

- `bash -n deploy/backend-deploy.sh` passes.
- `shellcheck -x -S style deploy/backend-deploy.sh` reports no findings.
- `actionlint` (with shellcheck) reports no findings on
  `.github/workflows/deploy-backend.yml`.
- The workflow YAML parses and contains one `deploy` job with the expected nine
  steps and only the `workflow_dispatch` trigger.
- The health parser was run against the **live** production
  `https://openhealth.ngo/api/health` response: it accepted the healthy
  response (`status=ok`, `model_ready=true`, 2 of 2 workers) and rejected
  synthetic degraded, zero-worker, startup-error and invalid-JSON responses.
- The current live health response confirms the field names, the R path and the
  worker-count shape used by the checks.

Not verified locally, because they require the live host and the GitHub
environment:

- The SSH key, pinned host key, port, user and network path.
- The sudoers grants, the state directory ownership and the absence of a sudo
  password prompt.
- The server's `origin` URL and non-interactive fetch.
- The current `renv` consistency and the Python environment.
- The actual checkout, `pip install`, `renv::restore`, service restart, health
  polling, state write and rollback.
- The `backend-production` environment and its secrets/approval rule.
- The public health path after a real deployment.

The first run should therefore be treated as the integration test. Inspect the
workflow log and the server state file; do not enable the `push` trigger first.

## 12. Risks and open deployment information

- **No live run yet.** Everything server-side is unverified until the first
  manual deploy. The first run is expected to be the integration test.
- **Passwordless sudo is a prerequisite.** The host's current sudo policy was
  not inspected from here. If `ubuntu` requires a password for `sudo`, the
  workflow fails at the preflight check; install the sudoers drop-in first.
- **The live host's Git access is unverified.** The repository is public, so an
  HTTPS checkout should fetch without credentials, but the server's actual
  `origin` and whether it uses SSH is not known. The script disables interactive
  prompts, so a missing credential fails fast rather than hanging.
- **The live host reports 2 R workers**, while the committed
  `deploy/api.env.example` records 1. This is server-local configuration and is
  not changed here. The health check deliberately accepts any positive ready
  count; confirm the intended count in `/etc/eqalb/api.env`.
- **Brief restart gap.** `systemctl restart` stops and starts the one service, so
  requests can fail for the restart duration. Zero-downtime deployment is not
  implemented, by design for this version.
- **Checkout moves before restart.** If the old process crashes during the
  dependency-install window, systemd will restart it from the new checkout. The
  window is small, and a failed install exits before any restart, but it is not
  atomic.
- **No automatic rollback.** A failed health check requires an operator to run
  the documented rollback. This is intentional for the first version.
- **Public health depends on Caddy/DNS.** A Caddy or DNS outage fails the
  workflow even when the backend itself is healthy; the recorded state still
  reflects the successful backend deployment.
- **The deploy account is more privileged than the frontend account.** It can
  act as `eqalb` and restart one service. Keep its key CI-only, use the
  `restrict` authorized_keys prefix, use the dedicated environment, and rotate
  the key. It cannot run arbitrary root commands through the documented sudoers
  entry.
- **Shallow checkout.** If `/opt/eqalb` was cloned with `--depth 1`, the first
  deployment fetches full history before checking out an older SHA. This is
  expected and one-time.
- **Python lock portability.** `api/requirements.lock.txt` was resolved under
  Python 3.14; the host's Python 3 may need to build a package that has no wheel.
  This is the same compatibility condition as `DEPLOY.md` sections 3.2 and 3.3,
  not a new requirement introduced by the automation. A build failure stops the
  deployment before the service is restarted.
- **No database or migrations.** The application has no database, so there is
  nothing else to back up or migrate. The durable state is the Git SHA plus
  `/etc/eqalb/api.env`.
