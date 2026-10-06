# eQalb agent instructions

## Project purpose
This is an educational R Shiny HTA model for a fictional hypertension digital
therapeutic named eQalb.

All patient data, clinical-effect assumptions, costs, utilities, event risks,
survival curves, and economic outputs are illustrative or simulated. Never
describe them as real clinical evidence, a validated model, or a real
reimbursement submission.

## Architecture
- `app.R`: Shiny UI and server-side presentation logic.
- `eqalb_markov.R`: reusable model and simulation functions.
- Keep economic-model logic outside the Shiny server whenever possible.
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

## PROJECT_STATE.md update rules

- Read `PROJECT_STATE.md` before starting a multi-file or feature task.
- Do not rewrite the entire file.
- Update it only after the requested change has been implemented and tested.
- Update only:
  - `Working modules`
  - `Current methodological interpretation`
  - `Known limitations`
  - `Current task`
  - `Next planned task`
  - `Update log`
- Do not mark a feature as working unless it was tested in the running app.
- Keep the file concise; do not copy source code into it.
- Record uncertain or illustrative assumptions as limitations.
- After updating, report exactly what was changed in the state file.