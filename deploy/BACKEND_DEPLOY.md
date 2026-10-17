# Automated backend deployment (GitHub Actions to your own server)

Optional automation for the FastAPI service and its long-lived R workers. It
ships one committed revision to a server you control, syncs the pinned Python and
R dependencies, restarts the systemd unit, and verifies `/api/health` before it
records anything.

Everything here is a template for your own infrastructure. Placeholders are the
same as in [`DEPLOY.md`](./DEPLOY.md); the automation never assumes a particular
domain, account or path beyond the values you configure.

This document covers only the FastAPI backend. The static frontend has its own
automation in [`FRONTEND_DEPLOY.md`](./FRONTEND_DEPLOY.md), and neither workflow
touches the other's files or services.

## 1. What it deploys, and what it must never touch

Deployed by this automation:

- One committed revision of the repository in `<app-path>`, checked out by its
  full Git SHA, so every deployment is reproducible from that SHA alone.
- The pinned Python dependencies in `<app-path>/.venv`, installed from
  `api/requirements.lock.txt`.
- The project `renv` library, restored from `renv.lock` with the R executable the
  service actually uses.
- The `<service-name>` systemd unit, restarted once the dependency steps succeed.

Never touched:

- `app.R`, `run_app.R` and the Shiny deployment.
- Any R model module, `api/main.py`, `api/plumber.R`, the frontend or exports.
- The systemd unit file, any drop-in, any environment file the unit declares,
  the Caddy configuration, DNS, firewall rules or certificates. The script reads
  those settings but never writes them, and never creates an environment file.
- The R installation in `/opt/R/<version>` (it is only used, never rebuilt).

## 2. The topology it relies on

| Item | Value |
|---|---|
| Project path | `<app-path>` (a Git checkout) |
| Service | `<service-name>` (systemd) |
| Service account | `<app-user>` |
| Deploy account | `<deploy-user>` (see §5) |
| API listener | loopback only; Caddy proxies `/api/*`. Resolved from the unit, not assumed. |
| Health | `GET http://<resolved-listener>/api/health`, publicly `https://<your-domain>/api/health` |
| R | `EQALB_RSCRIPT` when set, otherwise `Rscript` from the service `PATH` |
| R packages | the project `renv` library, restored from `renv.lock` |
| Python | `<app-path>/.venv/bin/python`, pinned by `api/requirements.lock.txt` |
| R workers | children of the FastAPI process (`api/r_client.py`), no separate unit, no port |
| Server-local settings | inline `Environment=` in the unit and/or any `EnvironmentFile=` it declares |

The unit uses `KillMode=control-group`, so restarting it stops and starts the API
**and every R worker child** together. There is no separate R worker service.

A host may legitimately differ from the committed templates: it can set
`EQALB_RSCRIPT`, the listener and the worker count inline in the unit and install
no environment file at all. That shape is supported; the values are resolved from
whatever the unit declares.

### 2.1 How the script resolves the service configuration

Before checkout, the script reads systemd's effective properties with
`systemctl show` (no root) and resolves only the settings the deployment needs.
It never sources or executes configuration text. Only values for the allowlisted
names `EQALB_RSCRIPT`, `EQALB_API_HOST`, `EQALB_API_PORT`, `EQALB_R_WORKERS`,
`UVICORN_HOST`, `UVICORN_PORT` and `PATH` are read or printed; other variables
are reported by name only (for example, one removed by `UnsetEnvironment=`) and
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
   - a uvicorn command line: `--host`/`--port`, then `UVICORN_HOST`/`UVICORN_PORT`,
     then the uvicorn defaults `127.0.0.1:8000`. `EQALB_API_*` is not read by this
     launcher.
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

If a setting cannot be established, the script stops before checkout and prints
the read-only commands that will establish it. It does not invent a value, and it
does not create or copy an environment file. `EQALB_DEPLOY_RSCRIPT`,
`EQALB_DEPLOY_API_HOST` and `EQALB_DEPLOY_API_PORT` are available as explicit
operator overrides for a host that cannot be resolved read-only, and
`EQALB_DEPLOY_STATE_DIR` (plus `EQALB_DEPLOY_HEALTH_TIMEOUT` and
`EQALB_DEPLOY_HEALTH_INTERVAL`) override the bookkeeping and health-check
defaults.

The `status` action runs the same resolution read-only and prints the chosen
values and their sources.

## 3. How a deployment runs

Workflow: [`.github/workflows/deploy-backend.yml`](../.github/workflows/deploy-backend.yml).

1. A maintainer starts **Deploy backend** manually (`workflow_dispatch`) with
   `mode = deploy` and a branch, tag or full SHA in `ref`.
2. The workflow checks out that ref, resolves it to a full 40-character commit
   SHA, and validates that the required deploy secrets exist. The server checks
   out that resolved SHA, so a branch that moves during the run cannot change
   what is deployed.
3. It writes the SSH private key and the pinned `known_hosts` line to the
   runner's `~/.ssh`, confirms the key is unencrypted, and connects with
   `StrictHostKeyChecking=yes`, `BatchMode=yes`, and only that pinned host key.
4. It pipes the committed `deploy/backend-deploy.sh` from the runner to `bash -s`
   on the server as the deploy account. The script is the one from the selected
   commit, not whatever copy is on the server.
5. On the server the script:
   - checks the state directory, the application-account sudo grant, the
     service-restart grant, the checkout and the component paths;
   - resolves the service configuration read-only (§2.1) and stops before
     changing anything if the R executable, the listener or a required
     environment file cannot be established;
   - probes the current health before the lock is taken; a service that is
     active but does not answer on the resolved listener is a stop;
   - takes a `flock` deployment lock;
   - records the current checkout HEAD and refuses to overwrite tracked local
     changes;
   - fetches `origin` (with prompts disabled), unshallows if needed, checks out
     the requested SHA, and verifies `HEAD`;
   - installs `api/requirements.lock.txt` into `.venv`, then runs `pip check` and
     an import check;
   - verifies the R version against `renv.lock`, runs
     `renv::restore(prompt = FALSE)`, and requires `renv::status()$synchronized`
     to be `TRUE`;
   - only then restarts `<service-name>` and polls the resolved
     `http://<listener>/api/health` (3 s interval, 180 s timeout);
   - on success writes the deployed SHA, deployment time and previous known-good
     SHA to `<state-directory>/state.env`, appends a line to `history.log`, and
     prints `DEPLOYED_SHA=`, `DEPLOYED_AT=`, `PREVIOUS_SHA=`, `ACTION=` and
     `HEALTH=ok`.
6. The workflow checks the server-reported SHA/time, then verifies the public
   `https://<your-domain>/api/health` response with the same health rules.
7. The SSH key material is removed from the runner at the end, on success or
   failure.

Ordering is deliberate: checkout and both dependency installs happen **before**
the restart. If `git`, `pip` or `renv` fails, the old API process is still
running and serving; the checkout has moved, but nothing restarted it.

## 4. Required GitHub secrets

Create an environment (for example `backend-production`) and add these secrets to
it. Environment-scoped secrets keep them out of every other workflow.

| Secret | Required | Meaning |
|---|---|---|
| `BACKEND_DEPLOY_SSH_HOST` | yes | Server host name or address. Never committed. |
| `BACKEND_DEPLOY_SSH_PORT` | no | SSH port; the workflow defaults to 22. |
| `BACKEND_DEPLOY_SSH_USER` | no | SSH deploy account; the workflow defaults to `ubuntu`. Set it to `<deploy-user>`. |
| `BACKEND_DEPLOY_SSH_KEY` | yes | Dedicated, unencrypted, CI-only OpenSSH private key. Never an operator's personal key. |
| `BACKEND_DEPLOY_KNOWN_HOSTS` | yes | The host's pinned public host key line(s), from `ssh-keyscan` or `/etc/ssh/ssh_host_*_key.pub`. |

The workflow also reads one repository or environment **variable** (not a
secret): `PUBLIC_HEALTH_URL`, the public health endpoint to verify after the
deployment, for example `https://<your-domain>/api/health`. If it is empty the
job fails immediately with a clear message, before it contacts the server.

### Creating the CI key and the pinned host key

```bash
# A CI-only key with no passphrase (the workflow runs unattended).
ssh-keygen -t ed25519 -N '' -C '<deploy-user>-ci' -f <deploy-user>-ci
# Install the PUBLIC half on the server for <deploy-user>, restricted:
#   restrict ssh-ed25519 AAAA... <deploy-user>-ci
# Then store the PRIVATE half and the pinned host key as secrets:
gh secret set BACKEND_DEPLOY_SSH_KEY    --env backend-production < <deploy-user>-ci
ssh-keyscan -p <ssh-port> -t ed25519 <host> > known_hosts
ssh-keygen -lf known_hosts        # verify the fingerprint out of band
gh secret set BACKEND_DEPLOY_KNOWN_HOSTS --env backend-production < known_hosts
```

Delete the local private key afterwards, or keep it in a password manager.
Rotate by adding a new public key, updating the secret, and removing the old
public key. Store the private key and `known_hosts` with Unix line endings; a
CRLF copy fails the workflow's key check or the host-key match.

Pin the host key from a trusted network and verify the fingerprint out of band.
Use the same host spelling in `ssh-keyscan` as in `BACKEND_DEPLOY_SSH_HOST`; SSH
looks the key up under the name or address it connects to, and a non-default port
is stored as `[host]:port`.

## 5. One-time server bootstrap

Everything here is done by an operator, once. The workflow does none of it.

### 5.1 State directory and least-privilege sudo

Use a dedicated deploy account, separate from `<app-user>` and from any
operator's login. It needs exactly two capabilities: run application commands as
`<app-user>`, and restart the one service.

```bash
sudo adduser --disabled-password --gecos '' <deploy-user>
sudo install -d -m 0700 -o <deploy-user> -g <deploy-user> <state-directory>

sudo tee /etc/sudoers.d/<deploy-user> >/dev/null <<EOF
<deploy-user> ALL=(<app-user>) NOPASSWD: ALL
<deploy-user> ALL=(root) NOPASSWD: /usr/bin/systemctl restart <service-name>.service
EOF
sudo chmod 0440 /etc/sudoers.d/<deploy-user>
sudo visudo -cf /etc/sudoers.d/<deploy-user>
```

`(<app-user>) NOPASSWD: ALL` is application-account access, not root: it lets the
deploy account install that account's code and dependencies. Root access is
limited to restarting one service. The deploy account owns `<state-directory>`
and nothing else; `<app-path>` stays owned by `<app-user>`.

Install the CI public key for `<deploy-user>` with the `restrict` prefix so it
cannot open a PTY or forward ports, and set `BACKEND_DEPLOY_SSH_USER`
accordingly. The workflow uses `ssh -T` and `sudo -n`, so no TTY is available; do
not set `Defaults requiretty` for this account.

Do not use `<app-user>` as the SSH account: it blurs the application and
deployment roles.

### 5.2 Verify the prerequisites

```bash
systemctl is-active <service-name>
cd <app-path> && bash deploy/backend-deploy.sh status    # resolved R, listener, workers

sudo -u <app-user> git -C <app-path> remote -v
sudo -u <app-user> env GIT_TERMINAL_PROMPT=0 git -C <app-path> fetch --dry-run origin

sudo -u <app-user> <app-path>/.venv/bin/python --version
cd <app-path> && sudo -u <app-user> -H /opt/R/4.5.1/bin/Rscript -e 'renv::status()'

command -v git curl python3 flock systemctl ss
sudo -n -u <app-user> -- true
sudo -n -l "$(command -v systemctl)" restart <service-name>.service
```

Read-only inspection of how the service is configured — this is what the script
does, and it needs no root:

```bash
systemctl show <service-name>.service --no-pager \
  -p FragmentPath -p DropInPaths -p User -p Group -p WorkingDirectory \
  -p ActiveState -p MainPID -p Environment -p EnvironmentFiles \
  -p UnsetEnvironment -p PassEnvironment -p ExecStart
systemctl cat <service-name>.service
sudo -u <app-user> ss -ltnp
```

`systemctl show -p Environment` contains **only** the inline `Environment=`
assignments. Values loaded from an `EnvironmentFile=` are not included; read
those files directly (as `<app-user>`) or use the `status` action, which resolves
both sources.

`renv::status()` must report the library and lockfile as synchronized before the
first automated run. The script refuses to restart over an unsynchronized
library.

## 6. First deployment

1. Confirm the environment and its secrets, and set the `PUBLIC_HEALTH_URL`
   variable.
2. In GitHub: **Actions → Deploy backend → Run workflow**
   - `mode`: `deploy`
   - `ref`: a branch, tag or full SHA

   or from the CLI:

   ```bash
   gh workflow run deploy-backend.yml --ref main -f mode=deploy -f ref=main
   ```

3. Approve the environment if required reviewers are configured.
4. Check the run summary: requested and deployed commit (the same full SHA), a
   UTC deployment time, the previous known-good SHA, and a successful public
   health check.
5. On the server, confirm the recorded state and the running service:

   ```bash
   cat <state-directory>/state.env
   sudo -u <app-user> git -C <app-path> rev-parse HEAD
   systemctl status <service-name> --no-pager | head -20
   cd <app-path> && bash deploy/backend-deploy.sh status
   curl -s https://<your-domain>/api/health
   ```

6. Run a manual rollback to a recorded commit (§7), confirm it passes health,
   then deploy the current revision again. Only then consider enabling automatic
   deployment (§10).

The first run takes longer than later ones because `pip` and `renv` may need to
download or compile packages. The 180-second health timeout starts only after
installation. The job has a 30-minute timeout: if it expires before the restart,
the old process keeps running; if it expires after the restart, treat it as a
failed health check and roll back.

## 7. Rollback

There is **no automatic rollback**. A failed health check fails the workflow and
prints the service diagnostics; the operator decides.

Through the same workflow:

- **Actions → Deploy backend → Run workflow**, `mode: rollback`, and either an
  empty `rollback_sha` or a full 40-character SHA.

  ```bash
  # Restore the last known-good revision recorded on the server.
  gh workflow run deploy-backend.yml --ref main -f mode=rollback -f ref=main

  # Restore a specific commit.
  gh workflow run deploy-backend.yml --ref main \
    -f mode=rollback -f ref=main -f rollback_sha=<full-commit-sha>
  ```

With an empty target the server chooses:

- the **previous recorded deployment** when the last attempt succeeded, so a
  normal rollback undoes the deployment that is running; or
- the **last recorded successful deployment** (or, on a first run, the checkout
  that was in place before the attempt) when the last attempt did **not**
  complete. That is what `pending.env` is for.

**First deployment:** `state.env` does not exist yet, so the first successful
deployment records an empty `PREVIOUS_SHA` and an empty-target rollback stops
with `error: no previous deployment is recorded; pass the full SHA to roll back
to` before it changes anything. Pass the pre-existing commit SHA explicitly in
that case. Once a second revision has been recorded, the empty target resolves
normally. If you want a first deployment to be immediately reversible without a
SHA, record the pre-existing checkout as an initial fallback — this is not
implemented; the safe form is described in §9.1.

The `ref` input for a rollback selects the copy of `deploy/backend-deploy.sh`
that is piped to the server; it does not select the rollback target.

The target SHA must be reachable from the server's `origin`. A commit that exists
only in a local clone cannot be fetched and the deployment fails with a clear
"commit not available" error.

Directly over SSH, using the local script so a broken checkout cannot block the
rollback:

```bash
ssh -T <deploy-user>@<host> 'bash -s -- rollback' < deploy/backend-deploy.sh
ssh -T <deploy-user>@<host> 'bash -s -- rollback <full-commit-sha>' < deploy/backend-deploy.sh
```

A rollback is a full deployment of the older SHA: it checks out that commit,
reinstalls its Python lock and `renv.lock`, restarts the service and health-checks
it. It briefly restarts the API.

## 8. Health check and failure behaviour

A run is healthy only when all of these are true:

- `GET /api/health` returns HTTP 200.
- `status` is `"ok"`.
- `model_ready` is `true`.
- `r_model.ready_workers` is at least 1.
- `r_model_error` is `null`.

The endpoint returns HTTP 200 even when the model is degraded, so the check parses
the JSON body rather than relying on the status code. The server check uses the
resolved listener; the workflow then repeats the same rules against
`PUBLIC_HEALTH_URL`. A public-only failure with a healthy private check points at
Caddy, TLS, DNS or the network, not at the new backend; the deployment is still
recorded and the workflow still fails, so the problem is not silent.

| Failure point | Service state | Automatic rollback |
|---|---|---|
| Secret/key/SSH/preflight | untouched | no |
| `git fetch` or checkout | old process still running | no |
| `pip install` / `pip check` | old process still running | no |
| `renv::restore` / `renv::status` | old process still running | no |
| `systemctl restart` | restart attempted, may have failed | no |
| local health timeout | target commit may be running | no |
| public health check | target commit is running; private check passed | no |

Every failure exits non-zero and prints the last health response, `systemctl
status`, recent `journalctl` lines and the running `Rscript` processes where it
can. An interrupted or failed attempt is recorded in `pending.env` so the manual
rollback can choose the last known-good revision.

## 9. State, known-good retention and audit

`<state-directory>` (owned by the deploy user, mode 0700) contains:

- `state.env`: `CURRENT_SHA`, `CURRENT_DEPLOYED_AT`, `PREVIOUS_SHA`,
  `PREVIOUS_DEPLOYED_AT`. Written atomically only after a successful health
  check.
- `pending.env`: `PENDING_SHA`, `PENDING_ACTION`, `PENDING_AT`,
  `PENDING_BASE_SHA`. Written after the checkout and before dependency
  installation, and removed only after a successful health check.
- `history.log`: one tab-separated line per completed deployment or rollback.
- `deploy.lock`: the `flock` target; two deployments cannot overlap.

"Previous known-good" is a Git SHA, not a copied directory: the commit and its
lockfiles remain in the checkout's Git history, so a rollback reconstructs that
deployment. A shallow checkout is unshallowed automatically the first time an
older SHA is needed.

### 9.1 First-run initialisation

Before the first deployment there is no `state.env`, so the first successful
deployment records `CURRENT_SHA` and an **empty** `PREVIOUS_SHA`: the new previous
is the *previously recorded* current release, and there is none. The checkout
that was in place before the deployment survives only as `PENDING_BASE_SHA` in
`pending.env`, which is deleted on success. Consequences:

- an empty-target rollback immediately after a first deployment is refused
  before any change; supply the pre-existing SHA explicitly;
- the first `history.log` line records `-` in the previous column;
- a first deployment followed only by later deployments leaves no record of the
  checkout that preceded it.

If you want to change this, the safe form is to record that base once, on the
first successful deployment: prefer `PENDING_BASE_SHA` when an interrupted
attempt is recorded and the `HEAD` observed at the start of the attempt
otherwise, accept it only as a full 40-character SHA that differs from the target
and is reachable from a fetched `origin/*` ref, and never fail the deployment
when that guard rejects it. Surfacing it as a separate `INITIAL_SHA` used only as
an empty-target fallback keeps `PREVIOUS_SHA` meaning "a release this tool
deployed and health-checked".

## 10. Enabling automatic deployment

The workflow has no `push` trigger by default; it is commented out under `on:`.
Uncomment it only after a manual deploy, a manual rollback and a browser smoke
test have all succeeded on your host, and treat that as a deliberate decision:

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

Keep the environment's required reviewers if you want a human gate even for
automatic runs; without it, a push to `main` deploys immediately.

Do not include `frontend/**` (the frontend has its own workflow) or `app.R` (not
part of the browser-stack backend).

## 11. Verification

What the repository can verify without your server:

- `bash -n deploy/backend-deploy.sh`, `shellcheck -x -S style` and `actionlint`
  are expected to pass on any supported Bash and shellcheck version.
- The configuration parser and the resolver have unit-level tests in the project's
  development notes; they exercise inline-only units, `EnvironmentFile` units,
  missing/optional/unreadable files, unset and conflicting settings, R and
  listener mismatches, unknown launchers, IPv6/wildcard/UDS listeners and
  fail-before-change ordering.

What only you can verify on your own infrastructure:

- The SSH key, pinned host key, port and account; the two sudo grants; the state
  directory ownership; and the absence of a sudo password prompt.
- The server's `origin` and a non-interactive `git fetch`.
- `renv` consistency and the Python environment on that host.
- The first real checkout, `pip install`, `renv::restore`, restart, health poll,
  state write and rollback.
- The environment's secrets and approval rule, and the public health path.

## 12. Risks and open information

- **The first live run is the integration test.** Everything before it is
  reasoning and local checks.
- **The configuration must be resolvable without root.** The script reads
  `systemctl show`, `/proc/PID/environ` and any declared environment files as
  `<app-user>`. An environment file that account cannot read is a stop; grant
  read access (for example `root:<app-user>`, mode 0640) or use the documented
  `EQALB_DEPLOY_*` overrides.
- **An unrecognised `ExecStart` launcher is resolved from the running service.**
  The post-restart health check is the final proof. A service that is not running
  and has no explicit listener is a stop.
- **`systemctl show -p Environment` does not include `EnvironmentFile` values.**
  Those files are parsed separately, as data, and applied after the inline
  assignments, matching systemd. The script never sources them.
- **A unit edited without `daemon-reload` can disagree with the running process.**
  R-path and listener differences stop the deployment; a worker-count difference
  warns.
- **A first deployment records no previous release** (§9.1).
- **Brief restart gap.** `systemctl restart` stops and starts the one service, so
  requests can fail for the restart duration. Zero-downtime deployment is not
  implemented.
- **Checkout moves before restart.** If the old process crashes during the
  dependency-install window, systemd restarts it from the new checkout. A failed
  install exits before any restart, but the window is not atomic.
- **No automatic rollback.** A failed health check requires an operator.
- **Public health depends on Caddy/DNS.** A Caddy or DNS outage fails the
  workflow even when the backend is healthy.
- **Python lock portability.** `api/requirements.lock.txt` was resolved under one
  Python version; a different interpreter on the host may need to compile a
  package that has no wheel. A build failure stops the deployment before the
  restart.
- **The deploy account is privileged inside the application account.** Keep its
  key CI-only, use the `restrict` authorized_keys prefix, use a dedicated
  environment, and rotate it.
- **No database or migrations.** The durable state is the Git SHA plus the
  server-local unit configuration and any environment file it declares.