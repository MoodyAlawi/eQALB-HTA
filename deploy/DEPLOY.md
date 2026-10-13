# Deploying eQalb on one Ubuntu 24.04 LTS VPS

This is the production runbook for the browser stack (Vue + FastAPI + the local R
worker). It is a template: replace `YOUR_DOMAIN` with the single production
hostname, and keep every other path as it is. Nothing in this repository needs to
be edited to deploy it.

Target architecture:

```
Internet
  -> Caddy on :80 and :443        (the only public-facing process)
  -> static Vue build             /opt/eqalb/frontend/dist
  -> /api/* reverse proxy         -> FastAPI on 127.0.0.1:8000
  -> one R worker                 child process of FastAPI, stdin/stdout, no port

private, never published:  FastAPI (8000)  and any R listener (there is none)
```

Placeholders used throughout: `YOUR_DOMAIN`, `/opt/eqalb`, `eqalb`,
`<repository-url>` (this project's Git remote).

Two things this deployment deliberately does **not** do:

* It does not deploy the legacy Shiny application (`app.R`, `run_app.R`). That
  stays a reference implementation for the existing Posit Connect deployment and
  is never started on the VPS.
* It does not start `api/run_api.R`, the plain plumber HTTP service. Port 8788
  belongs to local development only.

### The first installation is a controlled compatibility check

This runbook has been written from the repository, not from a completed install
on the target host. The stack was developed and validated on Windows with
R 4.5.1 and Python 3.14; the target is Ubuntu 24.04 with R 4.5.1 and Python 3.12.
Treat the first installation as a compatibility check whose result is not yet
known, not as a procedure already proven on that server:

* `renv.lock` records R 4.5.1 and must keep doing so. CRAN's `noble-cran40`
  repository is an **intended** path to that version, not a guarantee that
  `renv::restore()` will succeed on Ubuntu 24.04 for all 135 locked packages.
* `api/requirements.lock.txt` was resolved under Python 3.14, so installing it
  under Python 3.12 is part of the check rather than an established fact.

§3.2 therefore ends in a stop-and-verify checkpoint. Reach the end of §3 with the
checkpoint green, or stop before anything public exists (§4 onwards), and decide
deliberately what to change. Do not paper over a failure by substituting a
different R version or by installing packages ad hoc.

---

## 1. Packages

```bash
sudo apt-get update
sudo apt-get install -y \
  git curl ca-certificates gnupg rsync \
  unzip ufw unattended-upgrades

# --- R 4.5.1 from CRAN ------------------------------------------------------
# renv.lock records R 4.5.1, and the target version stays 4.5.1. Ubuntu 24.04
# ships R 4.3.3, which is not the recorded version, so CRAN's own repository is
# the intended way to get 4.5.x. It is an intended setup path, not a proven one:
# see "The first installation is a controlled compatibility check" above, and
# the stop-and-verify checkpoint in §3.2, before assuming the restore succeeds.
curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
  | sudo tee /etc/apt/keyrings/cran.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/cran.asc] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" \
  | sudo tee /etc/apt/sources.list.d/cran.list
sudo apt-get update
sudo apt-get install -y r-base-core r-base-dev
# Confirm which R actually arrived before going further:
Rscript --version
# renv itself is bootstrapped by renv/activate.R; nothing else is installed
# globally, because every R package comes from the project library.

# --- Python 3.12 -------------------------------------------------------------
sudo apt-get install -y python3 python3-venv python3-dev

# --- Node.js LTS ------------------------------------------------------------
# Vite 8 requires Node ^20.19 or >=22.12; Ubuntu 24.04 ships Node 18, which is
# too old to build the frontend.
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# --- Caddy ------------------------------------------------------------------
# Caddy is not in Ubuntu's main repository.
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install -y caddy

# --- Compilers and system libraries for renv::restore() ----------------------
# renv.lock holds 135 packages, and several of them are expected to compile from
# source: Rcpp / RcppArmadillo / RcppEigen / heemod (C++), dplyr, stringi, curl,
# openssl, xml2, and the ggplot2 / ggtext / survminer text stack. Installing the
# development libraries below in advance is what gives the restore a chance to
# build them; a missing one shows up as a package that fails to install, which
# is exactly what the §3.2 checkpoint is there to catch.
sudo apt-get install -y --no-install-recommends \
  build-essential gfortran pkg-config \
  libcurl4-openssl-dev libssl-dev libxml2-dev \
  libpng-dev libjpeg-dev libtiff-dev \
  libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev
# R stays headless: no cairo, X11, Tcl/Tk, pandoc or TeX is needed.
```

Disk: allow 20 GB or more. The R library plus build caches take about 1.5 GB,
`node_modules` about 300 MB, the built frontend about 10 MB.

Optional speed-up: pointing renv at Posit Public Package Manager's `noble`
binaries is intended to turn the restore from a long source compile into mostly
downloads. It is a host-local choice that does not change this repository, and it
is another part of the install that has not yet been exercised on this target -
verify it with the same §3.2 checkpoint, and prefer it only after the standard
path is understood.

## 2. Server baseline

```bash
# Non-root deployment user, with a home directory (renv may use it as a cache).
sudo adduser --system --group --home /home/eqalb --shell /bin/bash eqalb

# SSH: install your public key for both accounts, then test the new login in a
# second terminal BEFORE closing the current one.
sudo install -d -m 0700 -o eqalb -g eqalb /home/eqalb/.ssh
#   ...put the public key in /home/eqalb/.ssh/authorized_keys (mode 0600)...

# Only after key-based login is confirmed working:
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/'                 /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/'   /etc/ssh/sshd_config
sudo sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
sudo systemctl reload ssh

# Firewall: SSH, HTTP and HTTPS only. Ports 8000 and 8788 are never opened.
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH          # change if SSH does not use port 22
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status verbose

# Unattended security updates.
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Keep logs small: the API logs to journald and Caddy rotates its own file.
sudo install -d -o caddy -g caddy /var/log/caddy
```

Confirm that nothing else is listening before continuing:

```bash
sudo ss -ltnp
```

## 3. Application install

```bash
# 3.1 Source at the release tag, into the deployment path.
sudo mkdir -p /opt/eqalb
sudo chown eqalb:eqalb /opt/eqalb
sudo -u eqalb git clone --branch v1.0.0-rc1 --depth 1 \
  <repository-url> /opt/eqalb
cd /opt/eqalb

# 3.2 R packages, restored from the repository root so .Rprofile activates renv
#     and renv/library/ lands inside the project.
sudo -u eqalb -H Rscript -e 'renv::restore(prompt = FALSE)'
sudo -u eqalb -H Rscript -e 'renv::status()'          # expect: consistent
```

> ## STOP AND VERIFY - do not continue past §3 until all five are true
>
> This is the controlled compatibility check described at the top of this
> runbook. Proceed to §4 (DNS, Caddy and public exposure) **only** if every
> condition below holds. Conditions 1 and 2 are checked right here; 3, 4 and 5
> are checked in the steps that follow, and the whole list must be green before
> anything becomes public.
>
> | # | Condition | Check it with |
> |---|---|---|
> | 1 | `renv::restore()` completed successfully | The command finished with no error and no "unable to install" package; `renv::status()` reports the project is consistent |
> | 2 | R is the expected version | `Rscript --version` reports R 4.5.x - the major/minor recorded in `renv.lock` (4.5.1) |
> | 3 | The pinned Python set installs under Python 3.12 | §3.3 finishes; `/opt/eqalb/.venv/bin/python --version` reports 3.12.x and `pip install -r api/requirements.lock.txt` resolved without a build error |
> | 4 | The API service starts | `systemctl is-active eqalb-api` is `active` (see §3.6) |
> | 5 | The model is reachable through the API | `curl -s http://127.0.0.1:8000/api/health` reports `"status":"ok"`, `"model_ready":true`, exactly one ready R worker in `"r_model":{"configured_workers":1,"ready_workers":1,...}`, and `"r_model_error":null` (see §3.7) |
>
> **If any condition fails, stop the deployment here.** At this point nothing is
> public: Caddy is not yet serving, no DNS record points at the host, and no
> domain has been configured. Before changing anything:
>
> ```bash
> # Collect the evidence first, so the failure can be diagnosed from a record.
> systemctl status eqalb-api --no-pager > /tmp/eqalb-fail-status.txt 2>&1
> journalctl -u eqalb-api --since -30min > /tmp/eqalb-fail-api.log 2>&1
> Rscript --version > /tmp/eqalb-fail-r.txt 2>&1
> sudo -u eqalb -H Rscript -e 'renv::status()' >> /tmp/eqalb-fail-r.txt 2>&1
> sudo -u eqalb -H Rscript -e 'renv::diagnostics()' >> /tmp/eqalb-fail-r.txt 2>&1
> /opt/eqalb/.venv/bin/python -m pip list > /tmp/eqalb-fail-python.txt 2>&1
> ```
>
> Then decide deliberately. Do **not** work around a failure by substituting a
> different R version (including relaxing the requirement away from the 4.5.1 in
> `renv.lock`), or by installing individual R packages ad hoc outside renv. Both
> would leave the host in a state that no longer matches the repository and that
> no later `renv::restore()` would reproduce. Any such change is a targeted
> follow-up decision, made with the collected output in hand, not a step in this
> runbook.

```bash
# 3.3 Python virtual environment. The unit expects it at /opt/eqalb/.venv, and
#     api/requirements.lock.txt is the pinned, reproducible set. That set was
#     resolved under Python 3.14; installing it here under Python 3.12 is
#     condition 3 of the checkpoint above.
sudo -u eqalb python3 -m venv /opt/eqalb/.venv
sudo -u eqalb /opt/eqalb/.venv/bin/python -m pip install --upgrade pip
sudo -u eqalb /opt/eqalb/.venv/bin/python -m pip install -r api/requirements.lock.txt
sudo -u eqalb /opt/eqalb/.venv/bin/python --version      # expect: Python 3.12.x

# 3.4 Frontend production build. npm ci installs exactly frontend/package-lock.json.
cd /opt/eqalb/frontend
sudo -u eqalb -H npm ci
sudo -u eqalb -H npm run build                         # writes /opt/eqalb/frontend/dist
cd /opt/eqalb
# The build output must be readable by Caddy:
sudo chmod -R o+rX /opt/eqalb/frontend/dist

# 3.5 Server-local environment file.
sudo install -d -m 0755 /etc/eqalb
sudo cp /opt/eqalb/deploy/api.env.example /etc/eqalb/api.env
sudo chown root:eqalb /etc/eqalb/api.env
sudo chmod 0640 /etc/eqalb/api.env
sudo editor /etc/eqalb/api.env                          # review; the defaults are correct

# 3.6 systemd unit.
sudo cp /opt/eqalb/deploy/eqalb-api.service /etc/systemd/system/eqalb-api.service
sudo systemctl daemon-reload
sudo systemctl enable --now eqalb-api

# 3.7 Private health check, before DNS or Caddy are involved at all.
#     This is condition 5 of the checkpoint above.
curl -s http://127.0.0.1:8000/api/health
```

Expect `"status":"ok"`, `"model_ready":true`, `"r_model":{"configured_workers":1,
"ready_workers":1,...}` and `"r_model_error":null`. That closes conditions 4 and
5, so with conditions 1 to 3 already met the checkpoint is green and §4 may
begin. If it is not, follow the checkpoint's stop procedure - nothing is public
yet, and §4 is what makes it public.

## 4. DNS and Caddy

**Prerequisite: the §3.2 checkpoint is green.** Everything from here on creates
public exposure, so do not start this section with an unresolved failure.

```bash
# 4.1 Install the Caddyfile, then replace the placeholder on the server only.
sudo cp /opt/eqalb/deploy/Caddyfile /etc/caddy/Caddyfile
sudo editor /etc/caddy/Caddyfile
#   Replace every YOUR_DOMAIN with the real hostname. There are two: the site
#   block's address and the ACME email's subaddress. The committed template
#   keeps the placeholder, so this is the one deliberate server-side edit.
sudo caddy validate --config /etc/caddy/Caddyfile
```

```bash
# 4.2 Point the domain's A record at this VPS's IPv4 address (and an AAAA record
#     only if the host really has working IPv6). Wait for propagation:
dig +short YOUR_DOMAIN
# 4.3 Then let Caddy obtain the certificate and serve. Ports 80 and 443 must be
#     reachable from the internet for the ACME challenge.
sudo systemctl enable --now caddy
sudo systemctl reload caddy
sudo journalctl -u caddy --since -5min | tail -30

# 4.4 Verify HTTPS.
curl -sS -o /dev/null -w 'https %{http_code} verify=%{ssl_verify_result}\n' https://YOUR_DOMAIN/
curl -sS -o /dev/null -w 'http  %{http_code} -> %{redirect_url}\n'          http://YOUR_DOMAIN/
```

## 5. Validation

Run these in order. This section only runs on a host whose §3.2 checkpoint was
green; if it was not, the checks below are the wrong next step and the
checkpoint's stop procedure applies instead. Do not start a 1,000-iteration PSA
until a 100-iteration run is healthy.

```bash
# Services
systemctl is-active eqalb-api caddy                    # both: active
systemctl status eqalb-api --no-pager | head -20

# Bindings: 80/443 public (caddy), 8000 loopback only, and NO 8788 listener.
sudo ss -ltnp | grep -E ':(80|443|8000|8788)\b'

# Logs are clean: no tracebacks, no RModelUnavailable.
sudo journalctl -u eqalb-api --since -15min | tail -50

# Health, private and public.
curl -s http://127.0.0.1:8000/api/health
curl -s https://YOUR_DOMAIN/api/health
```

```bash
# The R worker is a child process of the API, and there should be exactly one.
pgrep -a Rscript
ps -o pid,rss,cmd -C Rscript          # note the RSS for your own capacity record

# The API and R ports are not reachable from outside. Run this from another
# machine, not from the VPS:
curl -m 5 http://YOUR_DOMAIN:8000/api/health    # expect: refused or timeout
curl -m 5 http://YOUR_DOMAIN:8788/              # expect: refused or timeout

# No development process is running.
pgrep -a node ; pgrep -a vite
sudo ss -ltnp | grep -E ':(5173|4173|7788)\b'   # expect: no output
```

Browser smoke path, in this order:

1. `https://YOUR_DOMAIN/` loads in HTTPS with no mixed-content or CORS error, and
   the certificate is valid. Check the browser console is free of errors.
2. Open the analysis dashboard; the contract request `GET /api/defaults`
   succeeds in the network tab.
3. Run the base case, then the charts and tables render.
4. Open the guided tutorial and complete Part 1.
5. Run one analysis from the sensitivity tab.
6. First PSA: **100 iterations, seed 12345** (about 20 seconds). Confirm it
   completes and the cost-effectiveness plane and CEAC render.
7. Only if that was healthy, and after checking memory, a 1,000-iteration PSA
   from the UI. It takes roughly 3 minutes and is the memory-intensive case:

```bash
free -m
systemd-cgtop -1 -n 1 | head
ps -o pid,rss,cmd -C Rscript
```

If RAM is tight during a large PSA, the only knob is `EQALB_R_WORKERS`, which
must stay at `1` on a 4 GB host; an optional `MemoryMax=` for the unit can be
added later once real RSS figures are known.

## 6. Rollback and routine operations

```bash
# --- Status and logs ---------------------------------------------------------
systemctl status eqalb-api caddy --no-pager
journalctl -u eqalb-api -f
journalctl -u eqalb-api --since today | tail -100
tail -f /var/log/caddy/eqalb-access.log

# --- Rebuild and restart ----------------------------------------------------
# Frontend only (most common): no API restart is needed, Caddy serves the files.
sudo -u eqalb git -C /opt/eqalb fetch --tags --depth 1
sudo -u eqalb git -C /opt/eqalb checkout <tag>
cd /opt/eqalb/frontend && sudo -u eqalb -H npm ci && sudo -u eqalb -H npm run build
sudo chmod -R o+rX /opt/eqalb/frontend/dist

# API or R change:
sudo systemctl restart eqalb-api
sudo systemctl status eqalb-api --no-pager | head -10
curl -s http://127.0.0.1:8000/api/health

# R dependencies changed:
#   The §3.2 checkpoint applies here too: if the restore does not complete
#   cleanly, do not restart the service over it and do not patch individual
#   packages by hand.
cd /opt/eqalb && sudo -u eqalb -H Rscript -e 'renv::restore(prompt = FALSE)'
sudo -u eqalb -H Rscript -e 'renv::status()'          # expect: consistent
sudo systemctl restart eqalb-api
curl -s http://127.0.0.1:8000/api/health              # expect: model_ready true
```

```bash
# --- Rollback ----------------------------------------------------------------
# Option A: move to the previous tag and rebuild. The whole deployment is
# /opt/eqalb plus the two copied server files, so a rollback is a checkout.
sudo -u eqalb git -C /opt/eqalb checkout <previous-tag>
#   then repeat the API/R and frontend steps above.

# Option B: restore the whole host from the provider's snapshot or backup, then
#   confirm git describe, the health endpoint and the frontend build stamp.

# --- Updates -----------------------------------------------------------------
sudo apt-get update && sudo apt-get upgrade -y     # security updates are automatic
sudo systemctl restart caddy                        # certificate renewal is automatic
sudo -u eqalb git -C /opt/eqalb remote -v           # keep the deploy path read-only for others
```

```bash
# --- Disk and log retention --------------------------------------------------
df -h / ; du -sh /opt/eqalb/renv/library /opt/eqalb/frontend/node_modules
sudo journalctl --vacuum-size=200M
#   and cap it persistently:
#     sudo sed -i 's/^#\?SystemMaxUse=.*/SystemMaxUse=200M/' /etc/systemd/journald.conf
#     sudo systemctl restart systemd-journald
sudo du -sh /var/log/caddy        # Caddy rotates at 10 MiB, keeping 5 files

# --- Backups -----------------------------------------------------------------
# No database and no user accounts: the durable state is the source tag plus the
# two server-local files. Back up /etc/eqalb/api.env, /etc/caddy/Caddyfile and
# /etc/systemd/system/eqalb-api.service, and rely on the provider's snapshots for
# the rest.
```

## Notes

* **Do not** start `api/run_api.R`, the Shiny app, or a Vite dev server on the
  VPS. The list in §5 checks that none is running.
* **Do not** add the simulated-data UI notice back: whether the interface shows
  that notice is a product decision that this deployment does not revisit. The
  API's `notice` field remains in the JSON as before.
* **Do not** put the domain, an IP address, a certificate, a key or a token in a
  tracked file. `deploy/*.example` files are templates; the real values live in
  `/etc/eqalb/api.env` and `/etc/caddy/Caddyfile`.
* The R worker has no listener, so there is no R service to firewall, supervise
  or restart separately. Restarting `eqalb-api` restarts it.
* **Do not** resolve a failed §3.2 checkpoint by changing the R version or by
  installing R packages outside renv. The target version is the 4.5.1 recorded
  in `renv.lock`; anything else is a separate decision, taken with the collected
  `systemctl` and `journalctl` output in hand, and made before any public
  exposure rather than after it.
