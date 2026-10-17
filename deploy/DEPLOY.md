# Deploying eQalb on one Ubuntu 26.04 LTS (resolute) VPS

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
                                  runs /opt/R/4.5.1/bin/Rscript (source build)

private, never published:  FastAPI (8000)  and any R listener (there is none)
```

Placeholders used throughout: `YOUR_DOMAIN`, `/opt/eqalb`, `eqalb`,
`<repository-url>` (this project's Git remote).

Three things this deployment deliberately does **not** do:

* It does not deploy the legacy Shiny application (`app.R`, `run_app.R`). That
  stays a reference implementation for the existing Posit Connect deployment and
  is never started on the VPS.
* It does not start `api/run_api.R`, the plain plumber HTTP service. Port 8788
  belongs to local development only.
* It does not install R from any apt repository. The application's R is built
  from the official source archive into `/opt/R/4.5.1` (see "DECISION" and §1.2),
  and no system R is required or used.

### DECISION: R 4.5.1 is built from official source into `/opt/R/4.5.1`

The project runtime recorded in `renv.lock` is **R 4.5.1**, and this runbook keeps
it. Ubuntu 26.04's official CRAN binary repository cannot supply it:

* Ubuntu 26.04 ("resolute") **is** a supported CRAN binary release, and the suite
  really is **`resolute-cran40`** - the official step is
  `sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"`.
* But that suite installs the **current R 4.6.x series**, not 4.5.1. The official
  page states "Packages for the **current R 4.6.** release are available for
  Ubuntu 'Long Term Support' releases", and, explicitly, "'cran40' denotes a
  binary compatibility break by the R 4.0.\* release, it does not install
  R 4.0.\* but the **current R 4.6.\*** series."
* R 4.5 binaries are no longer published for any current LTS. The linked
  `olderreleasesREADME.html` states that "As of May 2026, packages for R versions
  below 4.6 are no longer being updated. These packages are available for
  archival purposes on CRAN", and the only R 4.5 entry it documents is
  `focal-cran40` for Ubuntu 20.04.
* The same applies to `noble-cran40` (24.04) and `jammy-cran40` (22.04), so
  reimaging to another release does not restore 4.5.1 either.

**Therefore the application's R is not installed from an apt repository at all.**
R 4.5.1 is built from the official R source archive and installed into the
isolated prefix **`/opt/R/4.5.1`**, leaving any system R untouched. The API finds
it through the existing `EQALB_RSCRIPT` setting (`api/r_client.py` reads it), not
through `PATH`, so `/usr/bin/Rscript` is not a requirement for this application.

`.Rprofile`/`renv` still select the runtime from the installed R, so a single
`renv::restore()` under `/opt/R/4.5.1/bin/Rscript` produces a library that the
service then uses unchanged. §1.2 gives the build, §3.2 restores with that exact
path, and §5's checkpoint still gates everything before public exposure.

Two things this decision does **not** change: `renv.lock` (R 4.5.1 stays the
recorded requirement) and the rules on how R packages are obtained - the project
library still comes from `renv::restore()` and nothing is installed ad hoc.

### The first installation is a controlled compatibility check

The stack was developed and validated on Windows with R 4.5.1 and Python 3.14;
the deployment target is **Ubuntu 26.04 LTS, codename `resolute`**. A source build
of R on this distribution, and a restore of all 135 locked packages against it, is
new work, so treat the first installation as a compatibility check whose result is
not yet known, not as a procedure already proven on that server:

* `renv.lock` records R 4.5.1 and must keep doing so. The source archive and its
  checksum are pinned in §1.2, so the R you get is the R you asked for - but
  whether every locked package compiles against it on this release is exactly what
  §3.2 checks.
* `api/requirements.lock.txt` was resolved under Python 3.14, so installing it
  under the Python 3 that Ubuntu 26.04 provides is part of the check rather than
  an established fact.

Nothing in §1 hard-codes the Ubuntu codename: where the distribution matters, the
commands read it from the running system, so they keep working on a later release.

§3.2 therefore ends in a stop-and-verify checkpoint. Reach the end of §3 with the
checkpoint green, or stop before anything public exists (§4 onwards), and decide
deliberately what to change. Do not paper over a failure by substituting a
different R version or by installing packages ad hoc.

### Deployment closeout: https://openhealth.ngo

The stack is **deployed and smoke-tested**, not fully validated.
`https://openhealth.ngo` serves the frontend over HTTPS; Caddy obtained its
certificate; the proxied `/api/health` check returned HTTP 200 with
`model_ready: true` and 2 of 2 R workers ready; and browser smoke testing found no
console errors, no failed API requests and working core interactions. Caddy needs
read and traverse access to the static frontend build directory to serve it.

**Not performed, and not claimed:** formal load, performance and security testing;
clinical or model validation; and exhaustive functional testing.

---

## 1. Packages

```bash
sudo apt-get update
sudo apt-get install -y \
  git curl ca-certificates gnupg rsync \
  unzip ufw unattended-upgrades

# --- §1.1  Build and library dependencies ------------------------------------
# One list, covering both building R from source and compiling the renv package
# set afterwards. The R-admin manual (https://cran.r-project.org/doc/manuals/r-release/R-admin.html,
# "Essential and useful other programs under a Unix-alike") says explicitly that
# zlib, libbz2 and liblzma are "required", that libcurl is "required", that PCRE2
# is preferred, and that the GNU readline library's headers are needed for
# command-line editing. The graphics and text libraries cover R's bitmap devices
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
#  * libicu-dev lets stringi (in renv.lock) build against the system ICU instead
#    of compiling its bundled copy, which is far quicker.
#  * The last four come from the first Ubuntu 26.04 compatibility run: renv named
#    each one - `fs` needs libuv1-dev, `nloptr` needs cmake, `sodium` needs
#    libsodium-dev, and knitr/rmarkdown need pandoc. With them installed, the
#    source-built R 4.5.1 restored all 135 packages; the library is now synchronized.

# --- §1.2  R 4.5.1 from the official source, into /opt/R/4.5.1 ---------------
# This is the application's R. It is NOT installed from an apt repository: see
# "DECISION" near the top of this file for why resolute-cran40 cannot be used.
# Do not add the CRAN apt repository on this host.
#
# Official source archive (verified reachable, 40,518,816 bytes):
#   https://cran.r-project.org/src/base/R-4/R-4.5.1.tar.gz
# Official checksum: CRAN ships no per-file checksum or signature beside the
# tarball, so the authoritative values come from the R Core Team's own release
# announcement on the official r-announce list:
#   https://stat.ethz.ch/pipermail/r-announce/2025/000713.html
#   "[Rd] R 4.5.1 is released", Peter Dalgaard, 13 June 2025
# It publishes both MD5 and SHA-256 for every entry, including
# "R-4/R-4.5.1.tar.gz". Open that message and read the two values for that entry
# yourself rather than trusting a copy; the expected SHA-256 is
#   b42a7921400386645b10105b91c68728787db5c4c83c9f6c30acdce632e1bb70

# Build as your normal administrative user in a directory you own, then install
# with sudo. Keeping the download and the build tree off root-owned paths means
# configure and make do not trip over file ownership.
BUILD="$HOME/R-build"
mkdir -p "$BUILD"
cd "$BUILD"
curl -fsSLO https://cran.r-project.org/src/base/R-4/R-4.5.1.tar.gz

# Verify BEFORE extracting or compiling. Compare against the announcement.
echo "b42a7921400386645b10105b91c68728787db5c4c83c9f6c30acdce632e1bb70  R-4.5.1.tar.gz" \
  | sha256sum -c -
# If that fails, stop: the download is not the official R 4.5.1 archive. Do not
# continue with a mismatched file, and do not "fix" it by editing the checksum.

# The archive holds exactly one top-level directory, R-4.5.1/, and its own
# version markers. Confirm both before building:
tar -tzf R-4.5.1.tar.gz | awk -F/ 'NF>1 {print $1}' | sort -u   # expect: R-4.5.1
tar -xzOf R-4.5.1.tar.gz R-4.5.1/VERSION                        # expect: 4.5.1
tar -xzOf R-4.5.1.tar.gz R-4.5.1/VERSION-NICK                   # expect: Great Square Root

# Configure, build and install into the isolated prefix. Nothing here touches a
# system R, and there is no apt R to conflict with.
tar -xzf R-4.5.1.tar.gz
cd R-4.5.1
./configure --prefix=/opt/R/4.5.1 --enable-R-shlib --with-x=no
# --enable-R-shlib is the usual Linux configuration and is what most packages
# expect; --with-x=no matches the headless dependency list above.
# BLAS/LAPACK are deliberately left at R's own bundled reference implementations,
# which keeps the build reproducible and needs no extra packages. If you later
# want an optimised BLAS, that is a separate, deliberate change.
make -j"$(nproc)"
# On a 4 GB host, if the build is killed for memory, drop to: make -j2
sudo make install
# /opt/R/4.5.1 ends up root-owned and world-readable, which is what the eqalb
# user needs: it only ever reads R, never writes into the prefix.

# Verify what you built - this is checkpoint condition 2:
/opt/R/4.5.1/bin/Rscript --version
/opt/R/4.5.1/bin/Rscript -e 'sessionInfo()'
# Expect exactly R version 4.5.1, and sessionInfo() reporting 4.5.1 from
# /opt/R/4.5.1/lib/R. renv itself is bootstrapped by renv/activate.R during
# §3.2; nothing is installed into /opt/R/4.5.1 by hand, and R stays root-owned
# and read-only, because every R package comes from the project library.
#
# Maintenance trade-off, to be accepted knowingly:
#   This R is outside apt's world. It receives no security updates through
#   `apt upgrade`, so it must be rebuilt deliberately - either when the project
#   intentionally changes R version, or when a security-maintenance decision is
#   taken. Rebuilding means repeating §1.2 with the new archive and checksum,
#   then re-running §3.2 and the §5 checkpoint. Record each rebuild in the host's
#   own change log.

# --- §1.3  Python 3 ----------------------------------------------------------
# Ubuntu 26.04's own Python 3 is what the virtual environment in §3.3 uses.
# api/requirements.lock.txt was resolved under Python 3.14, so record the
# interpreter that actually arrives instead of assuming a version:
sudo apt-get install -y python3 python3-venv python3-dev
python3 --version

# --- §1.4  Node.js LTS ------------------------------------------------------
# Vite 8 requires Node ^20.19 or >=22.12. Rather than assume what this release
# ships, check `node --version` first and skip this block if it already
# satisfies that range; otherwise NodeSource's 22.x line gives a known-good LTS.
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version

# --- §1.5  Caddy ------------------------------------------------------------
# Caddy is not in Ubuntu's main repository.
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install -y caddy
```

The compiler and library packages that `renv::restore()` needs are already in the
§1.1 list above, so there is no separate step later. A missing one shows up as a
package that fails to build, which is exactly what the §3.2 checkpoint is there to
catch. R itself stays headless: no X11, Tcl/Tk or TeX is required; `pandoc` is in
the §1.1 list for knitr and rmarkdown rather than for R itself.

Disk: allow 30 GB or more. The R source tree plus the build intermediates take a
few GB on their own and can be deleted once `make install` has succeeded; the
installed R is a few hundred MB, the project R library plus caches about 1.5 GB,
`node_modules` about 300 MB, and the built frontend about 10 MB.

Optional speed-up, and its limits: pointing renv at Posit Public Package Manager's
binaries for this release's codename - a URL of the form
`https://packagemanager.posit.co/cran/__linux__/<codename>/latest`, with the
codename resolved as `lsb_release -cs` - would turn the restore from a source
compile into mostly downloads. Two reasons it is not the default here. PPM's
Ubuntu binaries track the current R series, so they are not built for R 4.5.1 -
they are compiled against a different R and a different set of system libraries,
which puts the project library's reproducibility at risk. And it adds a
third-party repository to a host whose whole point is to stay on official
sources. Use it only as a deliberate, recorded decision, and re-verify with the
§3.2 checkpoint; never mix codenames.

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
#
#     Use the ABSOLUTE path to the source-built R. A bare `Rscript` would pick up
#     whatever is first on PATH, which is not the runtime this project records.
#     `/opt/R/4.5.1/bin/Rscript` is the same binary the service uses, because
#     /etc/eqalb/api.env sets EQALB_RSCRIPT to it (§3.5).
sudo -u eqalb -H /opt/R/4.5.1/bin/Rscript --version    # expect: exactly 4.5.1
sudo -u eqalb -H /opt/R/4.5.1/bin/Rscript -e 'renv::restore(prompt = FALSE)'
sudo -u eqalb -H /opt/R/4.5.1/bin/Rscript -e 'renv::status()'   # expect: consistent
# renv stores the library under the R version it is running, so this directory is
# the R 4.5 one. Confirm the service will read the same tree: it starts R from the
# same /opt/R/4.5.1 prefix, with the repository root as its working directory.
ls renv/library
```

> ## STOP AND VERIFY - do not continue past §3 until all five are true
>
> This is the controlled compatibility check described at the top of this
> runbook. Proceed to §4 (DNS, Caddy and public exposure) **only** if every
> condition below holds. Conditions 1 and 2 are checked right here; 3, 4 and 5
> are checked in the steps that follow, and the whole list must be green before
> anything becomes public.
>
> **Condition 2 is the one the source build exists to satisfy.** It compares the
> R that renv actually used against the R 4.5.1 recorded in `renv.lock`; see
> "DECISION" near the top of this file and §1.2.
>
> | # | Condition | Check it with |
> |---|---|---|
> | 1 | `renv::restore()` completed successfully | The command finished with no error and no "unable to install" package; `renv::status()` reports the project is consistent |
> | 2 | R is the version the project requires | `/opt/R/4.5.1/bin/Rscript --version` reports **exactly R 4.5.1**, the version recorded in `renv.lock`, and `/opt/R/4.5.1/bin/Rscript -e 'sessionInfo()'` agrees. Any other version - including the 4.6.x an apt R would give - fails this condition |
> | 3 | The pinned Python set installs under this release's Python 3 | §3.3 finishes; `/opt/eqalb/.venv/bin/python --version` reports the interpreter Ubuntu 26.04 provides and `pip install -r api/requirements.lock.txt` resolved without a build error |
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
> /opt/R/4.5.1/bin/Rscript --version > /tmp/eqalb-fail-r.txt 2>&1
> sudo -u eqalb -H /opt/R/4.5.1/bin/Rscript -e 'renv::status()' >> /tmp/eqalb-fail-r.txt 2>&1
> sudo -u eqalb -H /opt/R/4.5.1/bin/Rscript -e 'renv::diagnostics()' >> /tmp/eqalb-fail-r.txt 2>&1
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
>
> **How to read a failure.** The R version is already pinned by the §1.2 source
> build, so condition 2 failing almost always means the wrong `Rscript` was used
> somewhere - check that §3.2 and `/etc/eqalb/api.env` both name
> `/opt/R/4.5.1/bin/Rscript`, and that `sessionInfo()` reports that prefix. The
> remaining realistic failures are a locked package that will not compile against
> R 4.5.1 on this release, or the Python/pip step. For those:
>
> 1. **Fix the build input, not the project's contract.** A package that fails to
>    compile usually names a missing system library; add exactly that library to
>    the §1.1 list, record it in this runbook, and re-run §3.2. Do not patch the
>    package into the library by hand.
> 2. **Re-verify the R you built** if condition 2 is the failing one: the SHA-256
>    check in §1.2 is the authoritative test that `/opt/R/4.5.1` came from the
>    official archive, not from some other source.
> 3. **If the project itself has to move to a newer R**, that is not a deployment
>    step: it means re-snapshotting `renv.lock` under the new R, reviewing that
>    diff, and re-validating the model's numbers. Take it as a separate, reviewed
>    change, and only then revisit this runbook.
>
> Do not choose any of these by installing a repository R from another Ubuntu
> codename, from an archived package, or from a third-party binary PPA. R on this
> host comes from the official source archive in §1.2, or the deployment stops.

```bash
# 3.3 Python virtual environment. The unit expects it at /opt/eqalb/.venv, and
#     api/requirements.lock.txt is the pinned, reproducible set. That set was
#     resolved under Python 3.14; installing it here under the Python 3 that
#     Ubuntu 26.04 provides is condition 3 of the checkpoint above.
sudo -u eqalb python3 -m venv /opt/eqalb/.venv
sudo -u eqalb /opt/eqalb/.venv/bin/python -m pip install --upgrade pip
sudo -u eqalb /opt/eqalb/.venv/bin/python -m pip install -r api/requirements.lock.txt
sudo -u eqalb /opt/eqalb/.venv/bin/python --version      # record what it reports

# 3.4 Frontend production build. npm ci installs exactly frontend/package-lock.json.
cd /opt/eqalb/frontend
sudo -u eqalb -H npm ci
sudo -u eqalb -H npm run build                         # writes /opt/eqalb/frontend/dist
cd /opt/eqalb
# The build output must be readable by Caddy:
sudo chmod -R o+rX /opt/eqalb/frontend/dist

# 3.5 Server-local environment file. EQALB_RSCRIPT is the setting that points the
#     API's R worker at the source-built R, so check that line specifically.
sudo install -d -m 0755 /etc/eqalb
sudo cp /opt/eqalb/deploy/api.env.example /etc/eqalb/api.env
sudo chown root:eqalb /etc/eqalb/api.env
sudo chmod 0640 /etc/eqalb/api.env
sudo editor /etc/eqalb/api.env                          # review; the shipped defaults are correct
grep -n '^EQALB_RSCRIPT=' /etc/eqalb/api.env            # expect: /opt/R/4.5.1/bin/Rscript

# 3.6 systemd unit. No R path appears in the unit: the service inherits
#     EQALB_RSCRIPT from the environment file above, which is why only that file
#     needed changing for the source build.
sudo cp /opt/eqalb/deploy/eqalb-api.service /etc/systemd/system/eqalb-api.service
sudo systemctl daemon-reload
sudo systemctl enable --now eqalb-api

# 3.7 Private health check, before DNS or Caddy are involved at all.
#     This is condition 5 of the checkpoint above. The R worker must be the
#     source-built one: confirm the child process path too.
curl -s http://127.0.0.1:8000/api/health
pgrep -a Rscript            # expect a single worker under /opt/R/4.5.1/bin/Rscript
```

Expect `"status":"ok"`, `"model_ready":true`, `"r_model":{"configured_workers":1,
"ready_workers":1,...}` and `"r_model_error":null`. That closes conditions 4 and
5, so with conditions 1 to 3 already met the checkpoint is green and §4 may
begin. If it is not, follow the checkpoint's stop procedure - nothing is public
yet, and §4 is what makes it public.

> **Configuration source: template versus live host.** §3.5 and §3.6 describe the
> template model in `deploy/api.env.example` and `deploy/eqalb-api.service`: one
> server-local environment file, no R path in the unit. The live host deviates.
> `/etc/eqalb` and `/etc/eqalb/api.env` do not exist there, and
> `/etc/systemd/system/eqalb-api.service` sets
> `Environment=EQALB_RSCRIPT=/opt/R/4.5.1/bin/Rscript` inline. Do not create the
> environment file on that host; changing the R path or the listener there means
> editing the unit and running `systemctl daemon-reload`. The automated
> deployment reads whichever source the unit actually declares, so both shapes
> are supported; see [`BACKEND_DEPLOY.md`](./BACKEND_DEPLOY.md) §2.1.

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

# The R worker is the source-built R, running as eqalb:
pgrep -a Rscript                                       # expect /opt/R/4.5.1/bin/Rscript
/opt/R/4.5.1/bin/Rscript --version                     # expect exactly 4.5.1

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

For the automated backend release path, see
[`BACKEND_DEPLOY.md`](./BACKEND_DEPLOY.md). The commands below remain the manual
procedure and the rollback fallback.

Status: the automated path is live-verified. On 2026-10-17 a manual deployment of
`dcb664c`, an explicit rollback to `eaad7c1`, a return to `main`, an ordinary
empty-target rollback and a final return to `main` all completed and passed
`GET /api/health`, with `state.env` recording the current and previous SHAs. The
workflow remains manual-only: the `push` trigger is still disabled, and a fresh
base-case browser smoke test is the remaining verification. The deploy account is
`eqalb-backend-deploy`, which can act as `eqalb` and restart `eqalb-api.service`,
and nothing more.

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
#   packages by hand. Always use the absolute R path, never a bare `Rscript`.
cd /opt/eqalb && sudo -u eqalb -H /opt/R/4.5.1/bin/Rscript -e 'renv::restore(prompt = FALSE)'
sudo -u eqalb -H /opt/R/4.5.1/bin/Rscript -e 'renv::status()'   # expect: consistent
sudo systemctl restart eqalb-api
curl -s http://127.0.0.1:8000/api/health              # expect: model_ready true

# R itself (the source build in §1.2):
#   `/opt/R/4.5.1` is not managed by apt, so nothing updates it automatically.
#   Rebuild it only as a deliberate act - a new archive and checksum in §1.2, or
#   a security-maintenance decision - then repeat §3.2 and the §5 checkpoint.
#   Keep the previous prefix (for example mv /opt/R/4.5.1 /opt/R/4.5.1.old)
#   until the new one has passed the checkpoint, so the rollback is a rename
#   plus a service restart.
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

## 7. Frontend-only releases from GitHub Actions

[`FRONTEND_DEPLOY.md`](./FRONTEND_DEPLOY.md) documents an additive automation
that ships **only** the static Vue build: GitHub Actions builds the bundle,
uploads it to `/opt/eqalb/frontend/incoming/`, and one root-owned script
activates it by replacing `/opt/eqalb/public/dist` - an atomic symlink to an
immutable release under `/opt/eqalb/frontend/releases/`, owned by the
deployment-only account `eqalb-deploy`. It installs nothing, edits no unit,
Caddyfile or environment file, never restarts `eqalb-api` and never reloads
Caddy. Sections 1 to 6 above remain the way the host and the API are installed,
and §5 remains the validation checklist.

Two consequences for this runbook:

* §3.4 (the manual `npm ci && npm run build`) applies to a host that does not use
  the automation, or to a fresh install before the first automated release. Once
  the live build is a release behind a symlink, do not run the build in place:
  Vite empties its output directory, which would write through the symlink into
  the live release. Use the automation, or build in a scratch directory and
  publish by hand as §6 describes.
* A frontend rollback is no longer a rebuild from a previous tag: it repoints the
  public pointer to a retained release with one command (the `rollback` mode of
  the script, or a `workflow_dispatch` run with `rollback_release_id`; see
  `FRONTEND_DEPLOY.md` §7).

One Caddy change belongs to that automation's adoption, and only one: the
one-time move of the static `root` from `/opt/eqalb/frontend/dist` to
`/opt/eqalb/public/dist`, performed by hand and verified as
`FRONTEND_DEPLOY.md` §4.7 describes. This repository's `deploy/Caddyfile` still
shows the current root and must not be edited until that migration has been
performed and accepted; the API proxy, TLS, logging, compression, headers and
certificates are never part of it.

Status: the automation is implemented in the repository, but it is not
configured on GitHub, never run, and the Caddy migration above is still
outstanding. Until a real workflow run succeeds, the manual path in §3.4 and §6
is the supported one.

## Notes

* **Do not** start `api/run_api.R`, the Shiny app, or a Vite dev server on the
  VPS. The list in §5 checks that none is running.
* **Do not** add the simulated-data UI notice back: whether the interface shows
  that notice is a product decision that this deployment does not revisit. The
  API's `notice` field remains in the JSON as before.
* **Do not** put the domain, an IP address, a certificate, a key or a token in a
  tracked file. `deploy/*.example` files are templates; the real values live in
  the server's unit or `/etc/eqalb/api.env`, and `/etc/caddy/Caddyfile`.
* The R worker has no listener, so there is no R service to firewall, supervise
  or restart separately. Restarting `eqalb-api` restarts it.
* **Do not** add the CRAN apt repository to this host, and do not point apt at
  another Ubuntu codename to get R. The suite for this release (`resolute-cran40`)
  serves R 4.6.x, and the R 4.5 binaries CRAN documents are archived and built for
  Ubuntu 20.04. The application's R is the source build in §1.2 and nothing else.
* **Do not** relax the R requirement in `renv.lock` as a deployment step. Changing
  it means re-snapshotting under a different R and re-validating the model's
  numbers, which is a project decision with its own review.
* **Do not** resolve a failed §3.2 checkpoint by changing the R version or by
  installing R packages outside renv. The target version is the 4.5.1 recorded
  in `renv.lock`; anything else is a separate decision, taken with the collected
  `systemctl` and `journalctl` output in hand, and made before any public
  exposure rather than after it.
