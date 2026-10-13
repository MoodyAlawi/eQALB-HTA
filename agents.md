# eQalb agent instructions

## Project purpose
This is an educational R Shiny HTA model for a fictional hypertension digital
therapeutic named eQalb.

All patient data, clinical-effect assumptions, costs, utilities, event risks,
survival curves, and economic outputs are illustrative or simulated. Never
describe them as real clinical evidence, a validated model, or a real
reimbursement submission.

## Current status (verified 2026-10-10)
- Shiny (`app.R`) is unchanged and remains read-only historical reference
  behaviour; the Vue/API stack in `api/` and `frontend/` is the supported
  user-facing product.
- The browser stack (`api/` + `frontend/`) has phases 1 and 2 complete, the P0
  Kaplan-Meier interpretation fix, and all six P1 findings from the approved
  UI/UX audit (four batches). The audit's 15 P2 findings are triaged: the two
  approved pre-1.0 fixes are implemented (the one-way sensitivity ranked-outcome
  mismatch, and the tab-strip and table accessibility semantics) and the rest are
  deferred, three of them needing backend work. No deferred P2 item starts without
  explicit approval.
- R is the sole source of calculations, thresholds, statuses, interpretations and
  evidence priorities. Python, the worker and TypeScript only carry, format and
  present what `eqalb_*.R` returns.
- PSA validation runs use `n_sim = 100` with `seed = 12345` (about 20 s). Do not
  run the 1,000-draw default for validation unless a full default PSA is
  explicitly requested.
- The Vue rebuild of the Guided Tutorial is complete for both parts. Part 1 (four
  steps and the completion card) runs from `GET /api/tutorial` and
  `POST /api/tutorial/part1`; Part 2's five sections (Case brief, Value for money,
  Budget impact, DHT readiness, Recommendation) run from the same isolated
  `useTutorialSession` through `GET /api/tutorial/part2`,
  `POST /api/tutorial/part2/case` and `POST /api/tutorial/part2/evaluate`, with
  their components under `components/tutorial/Part2*.vue`. The budget impact, the
  readiness result and the recommendation outcome are all R-owned and isolated from
  dashboard state. The only unimplemented tutorial behaviour is Part 2's
  user-visible retry flow.
- The Kaplan-Meier patient-level dataset export and the R figure-rendering
  (PNG/PDF) endpoints are deferred, with honest limitation notes on the affected
  tabs.

## Architecture
- `app.R`: Shiny UI and server-side presentation logic (reference implementation).
- `eqalb_markov.R`: economic model and reusable model functions.
- `eqalb_owsa.R`, `eqalb_survival.R`, `eqalb_readiness.R`,
  `eqalb_km_interpretation.R`, `eqalb_ui_copy.R`: reusable analysis, readiness,
  interpretation and interface-copy modules sourced by both `app.R` and
  `api/plumber.R`.
- `api/`, `frontend/`: additive browser stack that reuses the R functions; see
  `FRONTEND_PLAN.md`.
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
- Label simulations: “Simulated illustrative data — not clinical evidence.”
- Use EUR formatting for costs and QALYs for effects.
- Use plain-language explanations for user-facing text.
- Use explicit, user-adjustable random seeds for simulated outputs.

## project_state.md update rules

- Read `project_state.md` before starting a multi-file or feature task.
- Do not rewrite the entire file.
- Update it only after the requested change has been implemented and tested.
- Update only:
  - `Working modules`
  - `Current methodological interpretation`
  - `Known limitations`
  - `Current task`
  - `Next planned task`
  - `Update log`
- Keep `FRONTEND_PLAN.md`, `frontend/README.md` and `api/api_contract.md` factual
  as well when their status statements change.
- Do not mark a feature as working unless it was tested in the running app.
- Keep the file concise; do not copy source code into it.
- Record uncertain or illustrative assumptions as limitations.
- After updating, report exactly what was changed in the state file.