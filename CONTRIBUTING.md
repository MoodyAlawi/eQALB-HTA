# Contributing

Thanks for looking. This is an educational model, so the most useful
contributions are corrections, clarity improvements and well-explained changes to
the model or its interface.

## Before you start

- Everything in this repository is **simulated illustrative data**, not clinical
  evidence. Do not describe results as real evidence, a validated model or a
  reimbursement submission.
- R is the single source of calculations, thresholds, statuses, interpretations
  and evidence priorities. Python and TypeScript must carry, format and present
  what `eqalb_*.R` returns — never recompute a domain decision in another
  language.
- Do not commit secrets, keys, tokens, real host names or personal data. The
  deployment documentation is generic by design and uses placeholders.

## Never run `git push --mirror`

Local clones of this repository can contain `refs/agents/*` checkpoint refs,
which hold internal session commits. `git push --mirror` (and `git push --all`
with such refs present) publishes them.

Push explicit refs:

```bash
git push origin main
git push origin <branch>
```

## Prerequisites

| Layer | Needs |
|---|---|
| Shiny app | R, with the version recorded in `renv.lock` (4.5.1 at the time of writing) |
| Model API | Python 3, then the pinned set in `api/requirements.lock.txt` in a venv at `api/.venv` |
| Frontend | Node.js satisfying Vite's range (^20.19 or >=22.12) |

## Run it

### Shiny application

```r
# From the repository root, so .Rprofile can activate renv.
renv::restore()
shiny::runApp()
```

`run_app.R` is a small launcher pinned to `127.0.0.1:7788`. Keep
`shiny::runApp()` out of `app.R` so the file stays importable.

### Browser stack

The three services, their ports and their launchers are documented at the top of
`dev.sh`, which starts any subset of them:

```bash
./dev.sh            # R plumber API, FastAPI and the Vue dev server
./dev.sh api vue    # only the FastAPI API and the frontend
./dev.sh stop
```

The equivalent VS Code tasks are in `.vscode/tasks.json`. By hand:

```bash
# FastAPI model API (127.0.0.1:8788 by itself, 8000 when started by dev.sh)
python3 -m venv api/.venv
api/.venv/bin/python -m pip install -r api/requirements.lock.txt
api/.venv/bin/python api/run_api.py

# Vue dev server (127.0.0.1:5173)
cd frontend && npm ci && npm run dev
```

`api/api_contract.md` documents every endpoint and its response shape.

## Checks to run before proposing a change

```bash
# Frontend
cd frontend && npm run typecheck && npm run lint && npm run build

# Python API: import sanity after changing api/
api/.venv/bin/python -c 'import fastapi, uvicorn'

# R: after changing any eqalb_*.R or app.R (syntax only; nothing is sourced)
Rscript -e 'for (f in c("app.R", Sys.glob("eqalb_*.R"))) parse(f)'
cd /path/to/repo && Rscript -e 'renv::status()'

# R: the HTA decision-summary rule, with synthetic inputs (no model is run)
Rscript tests/test_hta_summary_rule.R
# R: the summary endpoint's availability gate, driven through its real handler
Rscript tests/test_hta_availability.R

# Shell scripts and workflows, if you have the tools
bash -n deploy/backend-deploy.sh deploy/frontend-deploy.sh
shellcheck -x -S style deploy/backend-deploy.sh deploy/frontend-deploy.sh
actionlint
```

Wrong or missing values should be reported honestly in the interface, not
silently replaced by a default. If you change a number, explain where it comes
from or label it as an illustrative assumption.

## Conventions

- Keep economic-model logic out of the Shiny server and out of the browser stack
  whenever possible; reuse existing model functions instead of creating a
  simplified duplicate.
- Make the smallest change that solves the problem, one feature at a time, and do
  not rewrite working modules to add a feature.
- Do not rename or remove working inputs, outputs, tabs, functions or IDs unless
  the change requires it and you say so.
- Use action buttons and `eventReactive()` for expensive model runs; use `req()`,
  `validate()` and `tryCatch()` where appropriate.
- Label simulated output with "Simulated illustrative data — not clinical
  evidence.", format costs in EUR and effects in QALYs, and keep user-facing text
  in plain language.
- Use an explicit, user-adjustable random seed for anything simulated.

## Documentation

- `readme.md` — what the project is and how to run it.
- `FRONTEND_PLAN.md`, `frontend/README.md` — the frontend architecture and state.
- `api/api_contract.md` — the API contract.
- `deploy/DEPLOY.md` — self-hosting runbook, with placeholders.
- `deploy/BACKEND_DEPLOY.md`, `deploy/FRONTEND_DEPLOY.md` — the optional GitHub
  Actions automations.
- `agents.md` — the project rules, for both people and automated assistants.

Keep those files factual. Live operational state, deployment records and internal
history are intentionally not tracked here.

## Licence

MIT. See [`License`](./License). By contributing you agree that your contribution
is licensed under the same terms.
