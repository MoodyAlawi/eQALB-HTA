# Self-hosting eQalb on one Ubuntu VPS

This is a complete, generic runbook for running the browser stack (Vue + FastAPI +
the local R worker) on a single Linux server you control. It describes the model,
not a particular installation: every value that belongs to your own host is a
placeholder you replace.

It is not a hosted service and it is not a hardening guide for a multi-tenant
platform. One small VPS, one application account, Caddy in front.

Target architecture:

```
Internet
  -> Caddy on :80 and :443        (the only public-facing process)
  -> static Vue build             <app-path>/public/dist  (or <app-path>/frontend/dist)
  -> /api/* reverse proxy         -> FastAPI on 127.0.0.1:8000
  -> R worker(s)                  child processes of FastAPI, no port,
                                  started with the Rscript named by EQALB_RSCRIPT

private, never published:  FastAPI (8000) and any R listener (there is none)
```

## Placeholders used in this runbook

| Placeholder | Meaning | Suggested value |
|---|---|---|
| `<your-domain>` | The single public hostname | `models.example.org` |
| `<app-path>` | Where the Git checkout lives | `/opt/eqalb` |
| `<app-user>` | Unprivileged account that owns `<app-path>` and runs the service | `eqalb` |
| `<service-name>` | systemd unit name | `eqalb-api` |
| `<deploy-user>` | Account used by CI to deploy (see `BACKEND_DEPLOY.md`) | `deploy` |
| `<state-directory>` | Deploy bookkeeping owned by `<deploy-user>` | `/var/lib/eqalb` |
| `<tag>` | Release tag or commit you are installing | a tag from this repository |
| `<repository-url>` | This repository's Git remote | — |

The suggested values are exactly what the committed templates use
(`deploy/eqalb-api.service`, `deploy/Caddyfile`, `deploy/api.env.example`), so if
you accept them you only have to replace `<your-domain>` and `<repository-url>`.
Any self-hoster may rename the account, the path or the unit; if you do, use your
values consistently and use the `EQALB_DEPLOY_*` overrides described in
`BACKEND_DEPLOY.md`.

Three things this deployment deliberately does **not** do:

* It does not deploy the legacy Shiny application (`app.R`, `run_app.R`). That is
  a reference implementation; it is not part of the browser stack.
* It does not start `api/run_api.R`, the plain plumber HTTP service. Port 8788
  belongs to local development only.
* It does not install R from an apt repository. The application's R is built from
  the official source archive into an isolated prefix (see the decision below),
  and no system R is required or used.

## Decision: build the R version `renv.lock` records, from source

`renv.lock` records the R version the project needs (**R 4.5.1** at the time of
writing). CRAN's binary repositories for current Ubuntu LTS releases track the
*current* R series, so they cannot be relied on to provide an older pinned
release. Building R from the official source archive into an isolated prefix is
the reproducible option:

* the project's R is not installed from apt, so no system R is replaced and no
  distribution upgrade can silently change it;
* the version is pinned by the archive and its checksum, so the R you get is the
  R you asked for;
* `.Rprofile`/`renv` still select the runtime from the installed R, so
  `renv::restore()` under that exact binary produces a library the service uses
  unchanged.

Two rules follow: do not relax the R requirement in `renv.lock` as a deployment
step, and do not install R packages ad hoc outside `renv`. Both would leave the
host in a state that no later `renv::restore()` reproduces. Moving the project to
a newer R is a project decision: re-snapshot `renv.lock`, review the diff and
re-validate the model's numbers.

The build is outside apt's world, so it receives no automatic security updates.
Rebuild it deliberately, keep the previous prefix until the new one passes the
checkpoint below, and record the change.

## 1. Packages

```bash
sudo apt-get update
sudo apt-get install -y \
  git curl ca-certificates gnupg rsync \
  unzip ufw unattended-upgrades

# --- 1.1 Build and library dependencies --------------------------------------
# One list, covering both building R from source and compiling the renv package
# set afterwards. zlib, libbz2, liblzma, libcurl and PCRE2 are what R's own
# install guide calls required or preferred; readline headers are needed for
# command-line editing; the graphics and text libraries cover R's bitmap devices
# and the packages that compile against them.
sudo apt-get install -y --no-install-recommends \
  build-essential gfortran pkg-config texinfo \
  zlib1g-dev libbz2-dev liblzma-dev libpcre2-dev libreadline-dev \
  libcurl4-openssl-dev libssl-dev libxml2-dev \
  libpng-dev libjpeg-dev libtiff-dev libcairo2-dev \
  libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev \
  libicu-dev \
  libuv1-dev cmake libsodium-dev pandoc
# Notes on that list:
#  * No X11/Tcl/Tk packages: R is configured with --with-x=no below, so it must
#    not look for them. The API is headless and renders no R-side graphics.
#  * No LaTeX: the PDF manuals are not built. `texinfo` is the one documentation
#    tool the build may want.
#  * libicu-dev lets stringi build against the system ICU instead of compiling
#    its bundled copy, which is far quicker.
#  * The last four are the libraries some locked packages name:
#    `fs` needs libuv1-dev, `nloptr` needs cmake, `sodium` needs libsodium-dev,
#    and knitr/rmarkdown need pandoc. If a package fails to build later, its log
#    names the missing header or library; add exactly that package here.
```

Disk: allow 30 GB or more. The R source tree plus build intermediates take a few
GB and can be deleted once `make install` succeeds; installed R is a few hundred
MB, the project R library plus caches about 1.5 GB, `node_modules` about 300 MB,
and the built frontend about 10 MB.

## 2. Server baseline

```bash
# --- 2.1 The application account ---------------------------------------------
sudo adduser --system --group --home /home/<app-user> --shell /bin/bash <app-user>

# --- 2.2 Timezone, firewall and unattended upgrades --------------------------
sudo timedatectl set-timezone UTC
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo dpkg-reconfigure -plow unattended-upgrades    # or: sudo apt-get install -y unattended-upgrades
```

Only 22, 80 and 443 are exposed. The API port stays on loopback.

## 3. Install the application

```bash
# --- 3.1 R from the official source, into an isolated prefix ------------------
# Replace the version with the one renv.lock records. The official checksums are
# published in the R Core Team's release announcement on r-announce; read them
# there rather than trusting a copy, and verify before extracting.
BUILD="$HOME/R-build"
mkdir -p "$BUILD" && cd "$BUILD"
curl -fsSLO https://cran.r-project.org/src/base/R-4/R-4.5.1.tar.gz
echo "<sha256-from-the-release-announcement>  R-4.5.1.tar.gz" | sha256sum -c -
# If that fails, stop. Do not continue with a mismatched file and do not edit the
# checksum to make it pass.

tar -tzf R-4.5.1.tar.gz | awk -F/ 'NF>1 {print $1}' | sort -u   # expect one dir
tar -xzOf R-4.5.1.tar.gz R-4.5.1/VERSION                        # expect the version
tar -xzf R-4.5.1.tar.gz
cd R-4.5.1
./configure --prefix=/opt/R/4.5.1 --enable-R-shlib --with-x=no
make -j"$(nproc)"            # on a 4 GB host, use -j2 if the build is killed
sudo make install
/opt/R/4.5.1/bin/Rscript --version    # expect exactly the version you built

# --- 3.2 Python 3 and Node.js ------------------------------------------------
sudo apt-get install -y python3 python3-venv python3-dev
python3 --version

# Vite requires Node ^20.19 or >=22.12. Check what the release ships and skip
# this block if it already satisfies that range.
curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/nodesource-setup.sh
less /tmp/nodesource-setup.sh        # read it before running it as root
sudo -E bash /tmp/nodesource-setup.sh
sudo apt-get install -y nodejs
node --version

# --- 3.3 Caddy ---------------------------------------------------------------
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install -y caddy
```

```bash
# --- 3.4 Source at a release tag, into the application path -------------------
sudo mkdir -p <app-path>
sudo chown <app-user>:<app-user> <app-path>
sudo -u <app-user> git clone --branch <tag> --depth 1 <repository-url> <app-path>
cd <app-path>

# --- 3.5 R packages, restored from the repository root so .Rprofile activates
#     renv and renv/library/ lands inside the project.
#     Use the ABSOLUTE path to the R you built: a bare `Rscript` picks up whatever
#     is first on PATH, which is not the runtime this project records.
sudo -u <app-user> -H /opt/R/4.5.1/bin/Rscript --version    # expect the pinned version
sudo -u <app-user> -H /opt/R/4.5.1/bin/Rscript -e 'renv::restore(prompt = FALSE)'
sudo -u <app-user> -H /opt/R/4.5.1/bin/Rscript -e 'renv::status()'   # expect consistent
ls renv/library

# --- 3.6 Python virtual environment -----------------------------------------
sudo -u <app-user> python3 -m venv <app-path>/.venv
sudo -u <app-user> <app-path>/.venv/bin/python -m pip install --upgrade pip
sudo -u <app-user> <app-path>/.venv/bin/python -m pip install -r api/requirements.lock.txt
sudo -u <app-user> <app-path>/.venv/bin/python --version    # record what it reports

# --- 3.7 Frontend production build ------------------------------------------
cd <app-path>/frontend
sudo -u <app-user> -H npm ci
sudo -u <app-user> -H npm run build        # writes <app-path>/frontend/dist
cd <app-path>
sudo chmod -R o+rX <app-path>/frontend/dist   # Caddy must be able to read it

# --- 3.8 Runtime configuration ----------------------------------------------
# Copy the example, review every value, and keep it root-owned and group-readable
# by the application account. This file is server-local: never commit it.
sudo install -d -m 0755 /etc/<service-name>
sudo cp <app-path>/deploy/api.env.example /etc/<service-name>/api.env
sudo chown root:<app-user> /etc/<service-name>/api.env
sudo chmod 0640 /etc/<service-name>/api.env
sudo editor /etc/<service-name>/api.env
grep -n '^EQALB_RSCRIPT=' /etc/<service-name>/api.env   # point it at your R

# --- 3.9 systemd unit --------------------------------------------------------
sudo cp <app-path>/deploy/eqalb-api.service /etc/systemd/system/<service-name>.service
sudo editor /etc/systemd/system/<service-name>.service   # User, Group, paths
sudo systemctl daemon-reload
sudo systemctl enable --now <service-name>

# --- 3.10 Private health check, before DNS or Caddy are involved --------------
curl -s http://127.0.0.1:8000/api/health
pgrep -a Rscript      # expect the workers under your /opt/R/<version> prefix
```

### Checkpoint: do not expose anything until these five are true

| # | Condition | Check it with |
|---|---|---|
| 1 | `renv::restore()` completed | The command finished with no error; `renv::status()` reports the project consistent |
| 2 | R is the version `renv.lock` records | `/opt/R/4.5.1/bin/Rscript --version` and `-e 'sessionInfo()'` both report it |
| 3 | The pinned Python set installs here | `pip install -r api/requirements.lock.txt` resolved without a build error |
| 4 | The service starts | `systemctl is-active <service-name>` is `active` |
| 5 | The model is reachable through the API | `/api/health` reports `"status":"ok"`, `"model_ready":true`, at least one ready worker in `"r_model"`, and `"r_model_error":null` |

If a condition fails, stop here — nothing is public yet. Collect the evidence
(`systemctl status`, `journalctl -u <service-name>`, `renv::status()`,
`renv::diagnostics()`, `pip list`) and decide deliberately. Do not work around a
failure by substituting a different R version or by installing R packages outside
renv.

A package that fails to compile usually names a missing system library: add
exactly that library to §1.1 and re-run `renv::restore()`. If the project itself
has to move to a newer R, that is a reviewed change to `renv.lock`, not a
deployment step.

### Two supported configuration shapes

`deploy/api.env.example` and `deploy/eqalb-api.service` show one model: an
`EnvironmentFile=` holding `EQALB_RSCRIPT`, `EQALB_API_HOST`, `EQALB_API_PORT`,
`EQALB_R_WORKERS` and the timeouts, with no paths in the unit. A host may instead
set those values inline with `Environment=` in the unit and install no
environment file at all. Both work; `deploy/backend-deploy.sh` resolves whichever
the unit actually declares before it changes anything. On an inline host,
changing the R path or the listener means editing the unit and running
`systemctl daemon-reload`; there is no file to edit.

## 4. DNS and Caddy

**Prerequisite: the checkpoint above is green.** Everything from here creates
public exposure.

```bash
# 4.1 Install the Caddyfile, then replace the placeholder on the server only.
sudo cp <app-path>/deploy/Caddyfile /etc/caddy/Caddyfile
sudo editor /etc/caddy/Caddyfile
#   Replace every YOUR_DOMAIN with your hostname: the site block's address, the
#   ACME e-mail subaddress, and the static root if you did not use the suggested
#   <app-path>. The committed template keeps the placeholder, so this is the one
#   deliberate server-side edit.
sudo caddy validate --config /etc/caddy/Caddyfile

# 4.2 Point the domain's A record at this host (AAAA only if IPv6 really works).
dig +short <your-domain>

# 4.3 Let Caddy obtain the certificate and serve. Ports 80 and 443 must be
#     reachable from the internet for the ACME challenge.
sudo systemctl enable --now caddy
sudo systemctl reload caddy
sudo journalctl -u caddy --since -5min | tail -30

# 4.4 Verify HTTPS.
curl -sS -o /dev/null -w 'https %{http_code} verify=%{ssl_verify_result}\n' https://<your-domain>/
curl -sS -o /dev/null -w 'http  %{http_code} -> %{redirect_url}\n'          http://<your-domain>/
```

## 5. Validation

```bash
systemctl is-active <service-name> caddy        # both: active
systemctl status <service-name> --no-pager | head -20

# Bindings: 80/443 public, 8000 loopback only, and no 8788 listener.
sudo ss -ltnp | grep -E ':(80|443|8000|8788)\b'

pgrep -a Rscript                                # expect your /opt/R/<version>/bin/Rscript
/opt/R/4.5.1/bin/Rscript --version              # expect the pinned version

sudo journalctl -u <service-name> --since -15min | tail -50

curl -s http://127.0.0.1:8000/api/health
curl -s https://<your-domain>/api/health
```

From another machine (not the host), confirm the API is not directly reachable:

```bash
curl -m 5 http://<your-domain>:8000/api/health    # expect refused or timeout
curl -m 5 http://<your-domain>:8788/              # expect refused or timeout
```

Browser smoke path:

1. `https://<your-domain>/` loads over HTTPS with a valid certificate, no mixed
   content and no CORS error; the console is free of errors.
2. `GET /api/defaults` succeeds in the network tab.
3. Run the base case; charts and tables render.
4. Open `https://<your-domain>/app?journey=1` and work through the Case brief and
   Chapter 2, the base case: the brief's text appears, advancing runs one base
   case, and its incremental cost, QALYs and ICER render. The journey is served
   by the R journey endpoints, so this step fails visibly if the backend was
   deployed without `eqalb_tutorial_journey.R`.
5. Run one sensitivity analysis.
6. First PSA: **100 iterations, seed 12345** (about 20 seconds). Confirm the
   cost-effectiveness plane and CEAC render.
7. Only if that was healthy, consider a 1,000-iteration run (roughly 3 minutes,
   the memory-intensive case) and watch `free -m`, `systemd-cgtop` and
   `ps -o pid,rss,cmd -C Rscript`.

On a 4 GB host keep `EQALB_R_WORKERS=1`; each worker loads the whole R model.
`api/r_client.py` defaults to 2 when the variable is unset, so set it explicitly
if memory is tight.

## 6. Routine operations and rollback

```bash
# --- Status and logs ---------------------------------------------------------
systemctl status <service-name> caddy --no-pager
journalctl -u <service-name> -f
tail -f /var/log/caddy/eqalb-access.log

# --- Frontend only: no API restart needed ------------------------------------
sudo -u <app-user> git -C <app-path> fetch --tags
sudo -u <app-user> git -C <app-path> checkout <tag>
cd <app-path>/frontend && sudo -u <app-user> -H npm ci && sudo -u <app-user> -H npm run build
sudo chmod -R o+rX <app-path>/frontend/dist

# --- API or R change --------------------------------------------------------
sudo systemctl restart <service-name>
curl -s http://127.0.0.1:8000/api/health      # expect model_ready true

# --- R dependencies changed -------------------------------------------------
# The checkpoint applies here too: never restart over an incomplete restore.
cd <app-path> && sudo -u <app-user> -H /opt/R/4.5.1/bin/Rscript -e 'renv::restore(prompt = FALSE)'
sudo -u <app-user> -H /opt/R/4.5.1/bin/Rscript -e 'renv::status()'
sudo systemctl restart <service-name>

# --- Rollback ---------------------------------------------------------------
# Option A: check out the previous tag and repeat the API/R and frontend steps.
sudo -u <app-user> git -C <app-path> checkout <previous-tag>
# Option B: restore the host from your provider's snapshot, then confirm
#   git describe, the health endpoint and the frontend build stamp.

# --- Updates ----------------------------------------------------------------
sudo apt-get update && sudo apt-get upgrade -y
sudo systemctl restart caddy            # certificate renewal is automatic

# --- Disk and log retention -------------------------------------------------
df -h / ; du -sh <app-path>/renv/library <app-path>/frontend/node_modules
sudo journalctl --vacuum-size=200M
sudo du -sh /var/log/caddy

# --- Backups ----------------------------------------------------------------
# No database and no user accounts: the durable state is the source tag plus the
# server-local configuration. Back up the unit, the environment file (if you use
# one), /etc/caddy/Caddyfile, and rely on provider snapshots for the rest.
```

## 7. Optional: automated releases from GitHub Actions

Two additive automations live in this repository and are documented separately:

* [`BACKEND_DEPLOY.md`](./BACKEND_DEPLOY.md) — deploys the FastAPI service and
  its R workers: fetch a commit, sync the Python lock and `renv`, restart the
  unit, verify `/api/health`, record the deployed SHA.
* [`FRONTEND_DEPLOY.md`](./FRONTEND_DEPLOY.md) — ships only the static Vue build:
  GitHub Actions builds the bundle, uploads it, and a root-owned script repoints
  a symlink that Caddy serves. No service restart, no Caddy reload.

Both are optional. The manual commands above remain the supported path, and they
are the fallback if an automation is unavailable.

If you adopt the frontend automation, do not run `npm run build` in place once
the served directory is a symlink into an immutable release: Vite empties its
output directory, which would write through the symlink. Build in a scratch
directory, or use the automation.

## Notes

* **Do not** start `api/run_api.R`, the Shiny app, or a Vite dev server on the
  server. §5 checks that none is running.
* **Do not** put your domain, an IP address, a certificate, a key or a token in a
  tracked file. `deploy/*.example` files are templates; the real values belong in
  the server's unit or environment file and in `/etc/caddy/Caddyfile`.
* The R worker has no listener, so there is no R service to firewall, supervise
  or restart separately. Restarting `<service-name>` restarts the API and every
  worker with it.
* **Do not** add a CRAN apt repository to obtain a pinned older R, and do not
  point apt at another distribution codename for it. The application's R is the
  source build in §3.1 and nothing else.
* **Do not** relax the R requirement in `renv.lock` as a deployment step.
* **Never run `git push --mirror`** from a clone of this repository: local
  `refs/agents/*` checkpoint refs can exist, and a mirror push would publish
  them. See [`../CONTRIBUTING.md`](../CONTRIBUTING.md).
* The simulated-data wording is a product decision: the API's `notice` field and
  the interface copy are not changed by deployment.