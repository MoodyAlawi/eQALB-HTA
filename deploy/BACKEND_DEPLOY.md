# Backend production deployment (GitHub Actions, manual first version)

Status: **the manual deploy and rollback paths are live-verified; automatic
deployment is still disabled.** On 2026-10-17 the workflow, on the live host,
deployed `dcb664c157f5998f1e63bd1b41e6c7c1d07ca0f1`, rolled back explicitly to
`eaad7c133999bbe12b49d9de3835df687c4b5881`, deployed `main` again, **rolled back
successfully with an empty target**, and deployed `main` once more — with a
healthy `/api/health` at every step. A fresh base-case browser analysis smoke test
against that deployment then completed with the result and the chart rendering
successfully (section 11). The workflow remains manual-only: the `push` trigger
stays commented out, and enabling it is a separate, explicit decision that has not
been taken. [`DEPLOY.md`](./DEPLOY.md) remains the host runbook (packages, R, the
API service, DNS, Caddy) and the manual fallback.

The first live run, before the configuration fix, reached the server and stopped
before checkout with `/etc/eqalb/api.env is not readable by eqalb`. Live
inspection found that `/etc/eqalb` and `/etc/eqalb/api.env` do not exist: this
host keeps its settings inline in the systemd unit
(`Environment=EQALB_RSCRIPT=/opt/R/4.5.1/bin/Rscript`, no `EnvironmentFiles=`)
and runs two R workers. The script now reads the effective configuration from
systemd and its environment files and only requires an environment file when the
unit actually declares one; section 2.1 records the resolution rules. Every live
run used the dedicated deploy account `eqalb-backend-deploy`, and every
successful one exercised its `systemctl restart eqalb-api.service` grant.

This document covers only the FastAPI backend and its R workers. The frontend has
its own automation in [`FRONTEND_DEPLOY.md`](./FRONTEND_DEPLOY.md), and neither
workflow touches the other's files or services.

## 1. What it deploys, and what it must never touch

Deployed by this automation:

- One committed revision of the repository in `/opt/eqalb`, checked out by its
  full Git SHA (reproducible from that SHA alone).
- The pinned Python dependencies in `/opt/eqalb/.venv`, installed from
  `api/requirements.lock.txt`.
- The project `renv` library, restored from `renv.lock` with the R executable
  the service actually uses (resolved from the service configuration).
- The `eqalb-api` systemd service, restarted once the dependency steps succeed.

Never touched:

- `app.R`, `run_app.R` and the Posit Connect Shiny deployment.
- Any R model module, `api/main.py`, `api/plumber.R`, the frontend, exports or
  application defaults. The automation ships the committed files unchanged; it
  does not edit them.
- `/etc/systemd/system/eqalb-api.service`, any drop-in, any environment file the
  unit declares, the Caddy configuration, DNS, firewall rules, certificates or
  the frontend symlink. The script reads those settings but never writes them,
  and it never creates an environment file.
- The R installation in `/opt/R/4.5.1` (it is only used, never rebuilt).

## 2. The deployed topology this relies on

Inspection of the repository and runbook established:

| Item | Value |
|---|---|
| Project path | `/opt/eqalb` (the Git checkout) |
| Service | `eqalb-api.service` |
| Service account | `eqalb` |
| Process manager | systemd |
| API listener | loopback only; Caddy proxies `/api/*`. Resolved from the unit, not assumed to be a fixed port. |
| Health | `GET http://<resolved-listener>/api/health`, publicly `https://openhealth.ngo/api/health` |
| R | `EQALB_RSCRIPT` when set, otherwise `Rscript` from the service `PATH`; R 4.5.1 is recorded in `renv.lock` |
| R packages | the project `renv` library, restored from `renv.lock` |
| Python | `/opt/eqalb/.venv/bin/python`; pinned by `api/requirements.lock.txt` |
| R workers | children of the FastAPI process (`api/r_client.py`), no separate unit, no port |
| Server-local settings | inline `Environment=` in the unit and/or any `EnvironmentFile=` it declares. On the live host: inline only, no environment file. |

`eqalb-api.service` is the only process manager entry. Its unit uses
`KillMode=control-group`, so restarting it stops and starts the API **and every R
worker child** together. There is no R worker service to restart separately.

Observed on the live host: `/api/health` reports `status: ok`,
`model_ready: true`, and `configured_workers: 2`, `ready_workers: 2`, with
`rscript: /opt/R/4.5.1/bin/Rscript`. The unit sets `EQALB_RSCRIPT` inline, has no
`EnvironmentFile=`, and is active and healthy. The committed
`deploy/api.env.example` sets `EQALB_R_WORKERS=1`; the live host is server-local
configuration and is **not** changed by this workflow. The health check accepts
any positive number of ready workers and warns when fewer than configured are
ready, so it works with either setting.

The live preflight resolved the R executable, the listener and the worker count
with no `EQALB_DEPLOY_*` override, and the deployment that used those values
restarted the service and passed the health check. The launcher/port question
left open by earlier revisions of this document is therefore closed for this
host; the resolved values are printed by `status` and in each deployment log.

### 2.1 How the script resolves the service configuration

Before checkout, the script reads systemd's effective properties with
`systemctl show` (no root) and resolves only the settings the deployment needs.
It never sources or executes configuration text. Only values for the allowlisted
names `EQALB_RSCRIPT`, `EQALB_API_HOST`, `EQALB_API_PORT`, `EQALB_R_WORKERS`,
`UVICORN_HOST`, `UVICORN_PORT` and `PATH` are read or printed; other variables
are only reported by name (for example, one removed by `UnsetEnvironment=`) and
never by value.

Order of precedence, matching systemd:

1. `Environment=` in the unit and its drop-ins.
2. Each `EnvironmentFile=` the unit declares, in order. These override
   `Environment=`; later files override earlier ones. A `-`-prefixed file is
   optional: a missing optional file is skipped exactly as systemd skips it. A
   missing required file is a stop, because the service could not start.
3. `ExecStart=` decides how the listener is chosen:
   - `api/run_api.py` / `api/main.py`: `EQALB_API_HOST`/`EQALB_API_PORT`, else
     the code defaults `127.0.0.1:8788`.
   - a uvicorn command line (`python -m uvicorn ...` or the `uvicorn` script):
     `--host`/`--port`, then `UVICORN_HOST`/`UVICORN_PORT`, then the uvicorn
     defaults `127.0.0.1:8000`. `EQALB_API_*` is not read by this launcher.
   - an unrecognised launcher: `EQALB_API_*`/`UVICORN_*` if set, otherwise the
     listener observed from the running service.
4. `EQALB_RSCRIPT`, else the same `PATH` lookup `api/r_client.py` performs.
   `EQALB_R_WORKERS` defaults to `2`.

The running process is cross-checked against the configuration:

- `EQALB_RSCRIPT` must match what a restart would use, or the script stops; the
  `renv` library is version-specific, so a silent R change is not acceptable.
- The resolved listener port must match the port the service is actually
  listening on, or the script stops; a restart would move Caddy's upstream.
- For a uvicorn command line, `--host`/`--port` override `UVICORN_*`, so an
  overridden variable is not treated as a conflict.
- A worker-count difference is reported as a warning, not a stop.

If a setting cannot be established from those sources, the script stops before
checkout and prints the read-only commands that will establish it. It does not
invent a value, and it does not create or copy an environment file.

The `status` action runs the same resolution read-only and prints the chosen
values and their sources.

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
   `bash -s` on the VPS as the SSH deploy user. Production uses the dedicated
   account `eqalb-backend-deploy` (set in `BACKEND_DEPLOY_SSH_USER`); the
   workflow's fallback is `ubuntu` for a host that has not been migrated. The
   script is the one from the selected commit, not whatever copy is on the
   server.
5. On the server the script:
   - checks the state directory, the application-account sudo grant, the
     service-restart grant, the checkout and the component paths;
   - resolves the service configuration read-only (section 2.1) and stops
     before changing anything if the R executable, the listener or a required
     environment file cannot be established;
   - probes the current health before the lock is taken; a service that is
     active but does not answer on the resolved listener is a stop;
   - takes a `flock` deployment lock;
   - records the current checkout HEAD and refuses to overwrite tracked local
     changes;
   - fetches `origin` (with prompts disabled), unshallows if needed, checks out
     the requested SHA, and verifies `HEAD`;
   - installs `api/requirements.lock.txt` into `.venv` and runs `pip check` and
     an import check;
   - verifies the R version against `renv.lock`, runs
     `renv::restore(prompt = FALSE)`, and requires
     `renv::status()$synchronized` to be `TRUE`;
   - only then restarts `eqalb-api.service` and polls the resolved
     `http://<listener>/api/health` (3 s interval, 180 s timeout);
   - on success writes the deployed SHA, deployment time and previous known-good
     SHA to `/var/lib/eqalb-backend-deploy/state.env` (the previous SHA is empty
     on a first deployment; section 9.1), appends a line to `history.log`, and
     prints `DEPLOYED_SHA=`, `DEPLOYED_AT=`, `PREVIOUS_SHA=`, `ACTION=` and
     `HEALTH=ok`.
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
| `BACKEND_DEPLOY_SSH_USER` | no | SSH deploy account. Production is `eqalb-backend-deploy`, which is already set; the workflow's fallback is `ubuntu`. |
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

Production uses a dedicated account, `eqalb-backend-deploy`, which is not the
application account and is not an operator's login. It needs exactly two sudo
capabilities: run application commands as `eqalb`, and restart the one service.
Nothing broader is granted.

```bash
sudo install -d -m 0700 -o eqalb-backend-deploy -g eqalb-backend-deploy \
  /var/lib/eqalb-backend-deploy

sudo tee /etc/sudoers.d/eqalb-backend-deploy >/dev/null <<'EOF'
eqalb-backend-deploy ALL=(eqalb) NOPASSWD: ALL
eqalb-backend-deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart eqalb-api.service
EOF
sudo chmod 0440 /etc/sudoers.d/eqalb-backend-deploy
sudo visudo -cf /etc/sudoers.d/eqalb-backend-deploy
```

`(eqalb) NOPASSWD: ALL` is application-account access, not root: it lets the
deploy account install that account's code and dependencies. Root access is
limited to restarting `eqalb-api.service`. The account owns the state directory
and nothing else; `/opt/eqalb` stays owned by `eqalb`.

The SSH key is installed for this account with the `restrict` prefix described
in section 4. `BACKEND_DEPLOY_SSH_USER` is already set to
`eqalb-backend-deploy`. SSH login with the pinned host key, the
application-account sudo grant and the systemctl restart grant have all been
exercised by the successful live deployments and the live rollback.

The workflow uses `ssh -T` and `sudo -n`, so no TTY is available. Do not set
`Defaults requiretty` for this account; Ubuntu's default does not. The preflight
`sudo -n` checks fail fast if a password or a TTY is required.

A host that has not been migrated can still use `ubuntu` as the deploy account.
Create the same state directory owned by `ubuntu` and replace the account name
in the sudoers entries and `BACKEND_DEPLOY_SSH_USER`. Do not use `eqalb` itself
as the SSH account: it would blur the application and deployment roles. Do not
use `eqalb-deploy`, which is the frontend deployment account.

### 5.2 Verify the server prerequisites

Run these as the deploy user, or adjust for the account you chose:

```bash
# The service and its current health.
systemctl is-active eqalb-api
cd /opt/eqalb
bash deploy/backend-deploy.sh status        # prints the resolved listener
curl -s http://127.0.0.1:<resolved-port>/api/health

# The checkout is on origin and can be fetched without a prompt.
sudo -u eqalb git -C /opt/eqalb remote -v
sudo -u eqalb env GIT_TERMINAL_PROMPT=0 git -C /opt/eqalb fetch --dry-run origin

# The pinned environments exist and are usable.
sudo -u eqalb /opt/eqalb/.venv/bin/python --version
sudo -u eqalb /opt/eqalb/.venv/bin/python -m pip --version
cd /opt/eqalb
sudo -u eqalb -H /opt/R/4.5.1/bin/Rscript --version        # expect 4.5.1
sudo -u eqalb -H /opt/R/4.5.1/bin/Rscript -e 'renv::status()'

# The tools the script uses, and the two sudo grants.
command -v git curl python3 flock systemctl ss
sudo -n -u eqalb -- true
sudo -n -l "$(command -v systemctl)" restart eqalb-api.service
```

Read-only inspection of how the service is configured. This is what the script
does; it needs no root:

```bash
systemctl show eqalb-api.service --no-pager \
  -p FragmentPath -p DropInPaths -p User -p Group -p WorkingDirectory \
  -p ActiveState -p MainPID -p Environment -p EnvironmentFiles \
  -p UnsetEnvironment -p PassEnvironment -p ExecStart
systemctl cat eqalb-api.service
sudo -u eqalb ss -ltnp
```

`systemctl show -p Environment` contains **only** the inline `Environment=`
assignments. Values loaded from an `EnvironmentFile=` are not included; read
those files directly (as `eqalb`) or use the `status` action, which resolves
both sources.

On the live host the expected shape is: `FragmentPath=/etc/systemd/system/eqalb-api.service`,
no drop-ins, no `EnvironmentFiles=`, `User=eqalb`, `Group=eqalb`,
`WorkingDirectory=/opt/eqalb`, inline
`EQALB_RSCRIPT=/opt/R/4.5.1/bin/Rscript`, and two ready workers. There is no
`/etc/eqalb/api.env`; the deployment does not need one and must not create one.

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

1. Confirm the `backend-production` environment exists and its secrets are set
   (three are mandatory; the port has a default and the user secret is already
   set to `eqalb-backend-deploy`). This path is live-verified: the environment and
   every successful run in section 6.1 worked, including the deployment job.
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
   cd /opt/eqalb
   bash deploy/backend-deploy.sh status    # prints the resolved listener and sources
   curl -s https://openhealth.ngo/api/health
   ```

6. Run a manual rollback to the recorded previous commit (next section), confirm
   it passes health, then deploy `main` again, and finish with a browser smoke
   test of the base case (section 11). The runbook steps end there: enabling the
   automatic `push` trigger is a separate decision (section 10), not part of a
   first deployment.

### 6.1 What the live deployment and rollback runs actually did

Recorded on the live host on 2026-10-17, in this order:

| Step | Run | Result |
|---|---|---|
| 1 | `deploy` `dcb664c157f5998f1e63bd1b41e6c7c1d07ca0f1` | healthy; `state.env` recorded `CURRENT_SHA=dcb664c…` and an **empty** `PREVIOUS_SHA` (section 9.1) |
| 2 | `rollback` with an empty target | **failed safely**: `backend-deploy: error: no previous deployment is recorded; pass the full SHA to roll back to`. No checkout, no `pending.env`, no restart, no state change |
| 3 | `rollback` `eaad7c133999bbe12b49d9de3835df687c4b5881` (explicit) | healthy; `CURRENT_SHA=eaad7c1…` at `17:22:19Z`, `PREVIOUS_SHA=dcb664c…` |
| 4 | `deploy` `main` (`dcb664c…`) | healthy; `CURRENT_SHA=dcb664c…` at `17:29:03Z`, `PREVIOUS_SHA=eaad7c1…` |
| 5 | `rollback` with an **empty target**, now that a previous release was recorded | healthy; the server resolved the target itself, restored `eaad7c1…` without a hand-supplied SHA, and recorded `CURRENT_SHA=eaad7c1…` at `17:43:28Z` |
| 6 | `deploy` `main` (`dcb664c…`) | healthy; final `CURRENT_SHA=dcb664c…` at `17:45:47Z`, `PREVIOUS_SHA=eaad7c1…` at `17:43:28Z` |

Final verified server state: `/opt/eqalb` HEAD equals
`dcb664c157f5998f1e63bd1b41e6c7c1d07ca0f1`; public
`https://openhealth.ngo/api/health` returned `status=ok`, `model_ready=true`,
`configured_workers=2`, `ready_workers=2`, `r_model_error=null`.

Step 2 is expected on a first deployment, not a fault in the run: there was no
recorded previous release yet, so the script refused instead of guessing. The
explicit SHA in step 3 supplied the target, exactly as section 7 describes, and
populated `PREVIOUS_SHA`. Step 5 then exercised the documented empty-target path
successfully, and step 6 left the latest revision live.

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

An empty target is **not** available on a first deployment: with no recorded
previous release the script stops with
`error: no previous deployment is recorded; pass the full SHA to roll back to`
before it changes anything. Pass the pre-existing commit SHA explicitly in that
case; section 9.1 explains why the checkout found before the first deployment is
not seeded as `PREVIOUS_SHA`. This happened on the live host (section 6.1,
step 2) and failed safely; the ordinary empty-target rollback was then performed
successfully (section 6.1, step 5).

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
check uses the resolved listener, which section 2.1 proves against the running
service; the workflow then repeats the same rules against the public
`https://openhealth.ngo/api/health`. A public-only failure with a healthy private
check points at Caddy, TLS, DNS or the network, not at the new backend; the
backend deployment is still recorded, and the workflow still fails so the
problem is not silent.

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

### 9.1 First-run initialisation (current, recorded behaviour)

`state.env` does not exist before the first deployment, so the first successful
deployment records `CURRENT_SHA` (the target) and an **empty** `PREVIOUS_SHA`:
the new state sets the previous release to the *previously recorded* current
release, and there is none yet. The checkout that was in place before the
deployment is recorded only as `PENDING_BASE_SHA` in `pending.env` (from the
`HEAD` observed at checkout time), and that file is removed once the health check
passes. It therefore does not survive as a rollback target.

Observed consequences on the live host (2026-10-17):

- an empty-target `rollback` immediately after the first deployment was refused
  before any change; the operator supplied the pre-existing SHA explicitly;
- the first `history.log` line records `-` in the previous column;
- the pre-existing base was still recoverable afterwards, but only through the
  operator's explicit target: rolling back to `eaad7c1` made it the recorded
  current release, and deploying `main` again then recorded it as
  `PREVIOUS_SHA=eaad7c1…`. A first deployment followed only by later deployments
  leaves no record of the checkout that preceded it;
- once a previous release was recorded, an empty-target `rollback` resolved it
  and succeeded (section 6.1, step 5).

Whether the first deployment should record the pre-existing checkout is an open
decision; this document records the behaviour, not a plan to change it. If it is
changed, the safe form is to record the base once, on the first successful
deployment, taking `PENDING_BASE_SHA` when an interrupted attempt is recorded and
the `HEAD` observed at the start of this attempt otherwise, accepting it only if
it is a full SHA, differs from the target and is reachable from a fetched
`origin/*` ref, and never failing the deployment when that guard rejects it.

## 10. Enabling automatic deployment

The workflow intentionally has no `push` trigger yet. Deploy, explicit rollback,
an ordinary empty-target rollback, the return to the latest revision and a fresh
base-case browser analysis smoke test have all been verified (sections 6.1 and
11). Enabling automatic deployment is therefore now a decision rather than an
unfinished verification: it is **not** enabled here, the `pending.env` recovery
path in section 11 is still untested, and uncommenting the block below must be an
explicit choice. If it is taken, the block to uncomment under `on:` is:

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

## 11. Verification: live, local, and outstanding

Verified on the live host (`openhealth.ngo`), 2026-10-17:

- A manual `deploy` of `dcb664c157f5998f1e63bd1b41e6c7c1d07ca0f1` completed:
  checkout, Python lock sync, `renv` restore, `eqalb-api.service` restart and the
  health poll all passed, and the workflow reported the deployed SHA and time.
- An explicit `rollback` to `eaad7c133999bbe12b49d9de3835df687c4b5881` completed
  and passed the health check.
- A second `deploy` of `main` returned to `dcb664c…`.
- An **empty-target** `rollback` with a populated state completed: the server
  resolved the recorded previous release itself, restored `eaad7c1…` without a
  hand-supplied SHA and passed the health check.
- A final `deploy` of `main` returned to `dcb664c…`.
- `state.env` ends at `CURRENT_SHA=dcb664c…` (`2026-10-17T17:45:47Z`) with
  `PREVIOUS_SHA=eaad7c1…` (`2026-10-17T17:43:28Z`), so current/previous tracking
  is populated and the server checkout `HEAD` matches `CURRENT_SHA`.
- Public `GET https://openhealth.ngo/api/health` returned `status=ok`,
  `model_ready=true`, `configured_workers=2`, `ready_workers=2` and
  `r_model_error=null`.
- Every run used the dedicated account `eqalb-backend-deploy`: SSH login with the
  pinned host key, `sudo -u eqalb` for the application commands, and the
  `systemctl restart eqalb-api.service` grant for the restarts.
- An empty-target `rollback` before any previous release was recorded failed
  safely (section 6.1, step 2): non-zero exit, no checkout, no `pending.env`, no
  restart and no state change.
- A fresh base-case browser analysis smoke test against the deployed backend
  completed on 2026-10-17 (recorded at `17:54Z`): the base case ran against the
  deployed API, its result was produced and its chart rendered successfully. The
  run was performed by the operator in the browser; only the outcome above is
  recorded, not a value by value re-check of the result.

Verified in the repository, without a VPS or GitHub secrets:

- `bash -n deploy/backend-deploy.sh` passes.
- `shellcheck -x -S style deploy/backend-deploy.sh` reports no findings.
- `actionlint` (with shellcheck) reports no findings on
  `.github/workflows/deploy-backend.yml`.
- The workflow YAML parses and contains one `deploy` job with the expected nine
  steps and only the `workflow_dispatch` trigger.
- The configuration parser was tested against realistic systemd property and
  environment-file inputs: quoted and unquoted values, comments, blank lines,
  line continuations, CRLF, UTF-8 rejection, multi-line quotes, `export` (not
  supported by systemd), inline comments (kept as part of the value), NUL-
  separated `/proc/PID/environ`, `ss` output with IPv4/IPv6/wildcard addresses
  and PID filtering, `ExecStart` with `run_api.py`, `uvicorn`, `--host`/`--port`,
  `--uds`, and unknown launchers.
- The resolver was run with stubbed systemd, `ss`, curl and `/proc` in 30
  scenarios, including: inline-only configuration with no environment file (the
  production shape), a genuine `EnvironmentFile` (including one that overrides
  `Environment=`), an optional missing file, a required missing file, an
  unreadable file, a `%` specifier, an `UnsetEnvironment` conflict, a listener
  mismatch, an R mismatch between configuration and the running process, an
  unknown launcher resolved from `ss`, an inactive service with explicit
  settings, a wildcard and an IPv6 listener, `run_api.py` ignoring `--port`,
  uvicorn CLI arguments overriding `UVICORN_*`, and a worker-count warning.
- Preflight ordering was tested: a configuration failure exits non-zero with no
  checkout, `pip`, `renv` or restart call.
- The health parser was validated locally against the live production
  `/api/health` payload, and it rejects synthetic degraded, zero-worker,
  startup-error and invalid-JSON responses.

Not verified, or not yet recorded:

- The `pending.env` recovery path (a deployment interrupted or failed after the
  checkout) on the live host. It has **not** been live-tested.
- The automatic `push` trigger, which remains commented out and disabled.
- The `backend-production` required-reviewer rule, if one is configured; the runs
  that succeeded needed no manual approval.

The first live run failed at the old preflight, before any change, so no
deployment state was written and no service was restarted. The configuration fix
was then deployed and exercised by the runs above.

## 12. Risks and open deployment information

- **The deploy and rollback paths are verified; the recovery path is not.**
  Deploy, explicit rollback, an ordinary empty-target rollback, the return to the
  latest revision and a fresh base-case browser analysis smoke test all succeeded
  on 2026-10-17. The `pending.env` interrupted-deployment recovery path is still
  unrecorded and has **not** been live-tested.
- **A first deployment records no previous release.** `state.env` starts empty,
  so the first successful deployment writes an empty `PREVIOUS_SHA` and a bare
  rollback is refused until a second revision has been recorded (section 9.1).
  Supply the pre-existing SHA explicitly. Whether to seed it automatically is an
  open decision, not implemented.
- **Automatic deployment is disabled.** The `push` trigger stays commented out.
  Its verification track is now complete, so enabling it is a deliberate decision
  that has not been taken (section 10).
- **Git access holds on the live host.** Every successful run fetched `origin`
  non-interactively and checked out the requested SHA, so the public HTTPS path
  needs no credentials and no server-side key. A future private `origin` would
  need its own read-only credential for `eqalb`.
- **The configuration must be resolvable without root.** The script reads
  `systemctl show`, `/proc/PID/environ` and any declared environment files as
  `eqalb`. An environment file that `eqalb` cannot read is a stop, not an
  attempt to read it as root. Grant read access with the `DEPLOY.md` ownership
  (`root:eqalb`, mode 0640) or set the documented `EQALB_DEPLOY_*` overrides.
- **An unrecognised `ExecStart` launcher is resolved from the running service.**
  If the listener cannot be established from the unit, an environment file or
  `ExecStart`, the script uses the port the service is actually listening on and
  reports that source. The post-restart health check is the final proof. A
  service that is not running and has no explicit listener is a stop.
- **`systemctl show -p Environment` does not include `EnvironmentFile` values.**
  Those files are parsed separately, as data, and are applied after the inline
  assignments, matching systemd. The script never sources them.
- **A unit edited without `daemon-reload` can disagree with the running
  process.** An R-path, listener or worker difference between the running
  process and the unit configuration is reported; the first two stop the
  deployment, the worker count warns. Reconcile the unit or reload systemd
  before deploying.
- **The live host reports 2 R workers**, while the committed
  `deploy/api.env.example` records 1. This is server-local configuration and is
  not changed here. The health check deliberately accepts any positive ready
  count; confirm the intended count in the unit environment.
- **The live host has no `/etc/eqalb/api.env`.** That is supported; the script
  does not require it, does not create it, and does not copy
  `api.env.example` over production.
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
  Python 3.14. The live deployments installed it on the host without a build
  failure, so the risk did not materialise for this revision; a future
  dependency that has no wheel for the host's Python 3 would need to compile.
  This is the same compatibility condition as `DEPLOY.md` sections 3.2 and 3.3,
  not a new requirement introduced by the automation. A build failure stops the
  deployment before the service is restarted.
- **No database or migrations.** The application has no database, so there is
  nothing else to back up or migrate. The durable state is the Git SHA plus the
  server-local unit configuration and any environment file it declares.
