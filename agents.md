# eQalb agent instructions

## Project purpose
This is an educational R Shiny HTA model for a fictional hypertension digital
therapeutic named eQalb, with an additive browser stack (Vue + FastAPI + a local R
worker).

All patient data, clinical-effect assumptions, costs, utilities, event risks,
survival curves, and economic outputs are illustrative or simulated. Never
describe them as real clinical evidence, a validated model, or a real
reimbursement submission.

## Sources of truth
- `readme.md` and `CONTRIBUTING.md`: what the project is, how to build, run and
  test it.
- `FRONTEND_PLAN.md`: the frontend architecture and the delivered/planned work.
- `frontend/README.md`, `api/api_contract.md`, `deploy/*.md`: per-area detail.

Live operational state, deployment records and internal history are kept in a
private repository, not here. Do not add internal status logs, incident reports,
deployment transcripts or task history to this repository.

## Architecture
- `app.R`: Shiny UI and server-side presentation logic (reference implementation).
- `eqalb_markov.R`: economic model and reusable model functions.
- `eqalb_owsa.R`, `eqalb_survival.R`, `eqalb_readiness.R`,
  `eqalb_km_interpretation.R`, `eqalb_ui_copy.R`: reusable analysis, readiness,
  interpretation and interface-copy modules sourced by both `app.R` and
  `api/plumber.R`.
- `api/`, `frontend/`: the browser stack that reuses the R functions.
- R is the sole source of calculations, thresholds, statuses, interpretations and
  evidence priorities. Python, the worker and TypeScript only carry, format and
  present what `eqalb_*.R` returns.
- Keep economic-model logic outside the Shiny server and outside the browser
  stack whenever possible.
- Reuse existing model functions rather than creating duplicate simplified
  calculations.

## Do not break these rules
- Never put `shiny::runApp()` inside `app.R`.
- `shinyApp(ui, server)` should appear once at the end of `app.R`.
- Do not rename or remove working inputs, outputs, tabs, functions, or IDs
  unless explicitly requested.
- Do not rewrite working modules to add a new feature.
- Do not install packages inside reactive code.
- Do not add packages unless necessary; explain why before adding them.
- Preserve the existing interactive cost-effectiveness plane and simulated
  Kaplan–Meier module.
- Never commit secrets, keys, tokens, real host values or personal data. The
  deployment documentation is generic by design: keep it that way.

## Development approach
1. Read only files relevant to the task.
2. Identify the existing model function and its accepted arguments before
   making changes.
3. Make the smallest possible change.
4. Complete one feature at a time.
5. Use action buttons and `eventReactive()` for expensive model runs.
6. Use `req()`, `validate()`, and `tryCatch()` where appropriate.
7. Test the changed feature and check existing features still run.
8. Report files changed, tests performed, and any remaining limitation.

## Output conventions
- Label simulations: "Simulated illustrative data — not clinical evidence."
- Use EUR formatting for costs and QALYs for effects.
- Use plain-language explanations for user-facing text.
- Use explicit, user-adjustable random seeds for simulated outputs.

## Documentation upkeep
- Keep `FRONTEND_PLAN.md`, `frontend/README.md`, `api/api_contract.md` and the
  `deploy/*.md` files factual when their status statements change.
- Do not mark a feature as working unless it was tested in the running app.
- Record uncertain or illustrative assumptions as limitations in the document
  that owns them; do not create a new status log.
- Never run `git push --mirror` or `git push --all` from this clone; local
  `refs/agents/*` checkpoint refs would be published. Push explicit refs only.