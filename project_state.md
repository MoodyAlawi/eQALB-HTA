# eQalb project state

Last verified: 2026-10-05

## Project purpose

Educational R Shiny HTA model for a fictional hypertension digital therapeutic
called eQalb.

All clinical data, costs, utilities, treatment effects, survival data, PSA
distributions, and economic outputs are illustrative or simulated unless
explicitly documented otherwise.

## File map

- `app.R`: Shiny UI and server logic.
- `eqalb_markov.R`: economic model and reusable model functions.
- `AGENTS.md`: permanent instructions for the coding agent.
- `PROJECT_STATE.md`: current verified project state and next task.

## Working modules

- Base-case cost-effectiveness model.
- Incremental cost, incremental QALY, and ICER outputs.
- Interactive deterministic cost-effectiveness plane.
- Simulated Kaplan–Meier curve and risk table.
- Kaplan–Meier traffic-light interpretation panel (event direction, apparent
  benefit, statistical evidence, censoring and competing events, evidence
  credibility).
- Kaplan–Meier simulation assumptions panel listing the exact risk, engagement,
  RRR, horizon, sample-size, seed, event-definition and censoring values used.
- Deterministic sensitivity analysis and tornado diagram.
- Probabilistic sensitivity analysis and CEAC in the existing Cost-effectiveness
  tab.
- DHT Readiness & Implementation tab.
- Budget-impact analysis (five-year, deterministic) in the existing
  Cost-effectiveness tab.
- Value of information (VOI) tab: EVPI per patient, a decision-uncertainty
  traffic light, and regression-based EVPPI per patient for the nine sampled PSA
  parameters.
- HTA decision summary tab: a five-domain traffic-light dashboard (economic
  value, decision uncertainty, budget impact, clinical evidence maturity,
  implementation readiness), an overall status, a provisional HTA position, a
  dynamic plain-language interpretation and a dynamic nine-row evidence-priority
  table.
- Landing page shown on start-up: a centred title screen with an "Open analysis
  dashboard" button reachable from it, and a "Home" button inside the dashboard
  (show/hide toggles over the existing containers; no duplicated UI).
- Light and dark colour modes via `bslib::input_dark_mode(id = "color_mode")`,
  with light mode as the initial default. A single switch sits above both the
  landing page and the dashboard. The `color_mode` input is styling-only and is
  not read by any server logic.
- Consolidated results export: a "Download results package" button in the
  landing page's "Download results" view downloads one ZIP containing the
  currently available results plus a README that lists which analyses were
  included and which had not been run. It reuses the reactives already computed
  by the other tabs and never reruns an analysis.
- Centred landing title screen with "Start analysis", "Project description" and
  "Download results" subviews, each centred with a Back button and driven by one
  `conditionalPanel` per view over a hidden `nav_page` control.
- Reproducible package environment managed with `renv` 1.3.1: `renv.lock` records
  R 4.5.1 and the exact version of all 130 packages, and `.Rprofile` activates
  the project library. Development-time only; no model behaviour changes.

## Current methodological interpretation

- ICER shows incremental cost per additional QALY.
- The cost-effectiveness plane shows incremental costs and QALYs for one
  scenario.
- Deterministic sensitivity analysis changes one input at a time.
- PSA varies multiple uncertain inputs together.
- CEAC shows the proportion of PSA simulations with positive net monetary
  benefit at each WTP threshold.
- The Kaplan–Meier risk table shows people who are event-free and still
  observed; it does not show app adherence.
- The Kaplan–Meier traffic-light panel summarises the simulated arm contrast;
  its evidence-credibility domain is always Red because the data are simulated.
- The Kaplan–Meier simulation uses the same global relative-risk-reduction and
  engagement inputs as the economic model base case.
- Budget impact shows the annual and cumulative payer cost or saving implied by
  uptake assumptions; it is not a measure of value for money.
- The Cost-effectiveness tab is organised into four clearly labelled sections:
  global eQalb assumptions (full-width, top), base-case
  cost-effectiveness, probabilistic sensitivity analysis, and budget impact
  analysis.
- The Value of information tab reuses the stored PSA simulations; it does not
  rerun the PSA. EVPI per patient is `mean(max(NMB_i, 0)) - max(mean(NMB_i), 0)`
  where `NMB_i = reference WTP x incremental QALYs_i - incremental cost_i` and
  usual care has incremental NMB of zero.
- EVPPI is a single-loop regression approximation (a natural cubic spline of NMB
  on each sampled parameter), not a nested Monte Carlo estimate.
- VOI uses the PSA distributions and parameter means defined by the PSA model,
  which are based on model constants and may differ from the live base-case
  sliders.
- The PSA intervention-price, implementation-cost, healthcare-use-savings, RRR
  and engagement distributions are centred on the live global inputs, so
  changing those controls and re-running the PSA changes the PSA results. Their
  uncertainty widths (sd €72, €8, €4, 0.03, 0.10, 0.10) are fixed.
- The VOI decision-uncertainty traffic light is derived from EVPI per patient
  and the probability of cost-effectiveness. Red if the less-preferred option
  wins in at least 40% of simulations or EVPI is above €1,000 per patient;
  Green if it wins in at most 1% and EVPI is €1 or less; Amber otherwise. These
  bands are educational presentation rules.

## Known limitations

- Clinical inputs and economic values are illustrative.
- PSA distributions and assumed standard deviations are not evidence-based.
- Kaplan–Meier data are simulated, not patient-level clinical evidence.
- Kaplan–Meier traffic-light thresholds (hazard ratio, log-rank p, and the 10%
  and 25% censoring-difference bands) are illustrative educational rules.
- The Kaplan–Meier survival simulation is a simplified patient-level model:
  engagement is redrawn each year, it stops at the first MI or stroke, and death
  is treated as competing censoring rather than the economic model's explicit
  Death state.
- The Kaplan–Meier curve is only regenerated when "Simulate and update curve" is
  clicked, so changing a global input does not redraw the curve until then; the
  assumptions panel reports the values the plotted run actually used.
- Formal model validation is deferred until the current modules are stable.
- PSA runtime is relatively long for large simulation counts.
- Budget-impact analysis is deterministic and illustrative; avoided-event
  savings default to €0 and are not linked to the Markov model, and no
  discounting is applied.
- Population EVPI is not calculated: the app has no defined research population,
  decision timeline, or population-incidence structure.
- EVPPI is a single-loop regression approximation and can be imprecise at small
  PSA simulation counts; it is shown only when at least 100 successful
  simulations are available. At low willingness-to-pay thresholds every EVPPI
  can be approximately zero because no single parameter is expected to change
  the preferred decision on its own.
- EVPPI estimates are only shown for parameters that are actually returned in
  the PSA draws.
- All nine PSA distributions are centred on the live global inputs, including
  the three health-state utilities, which are now editable base-case inputs.
  All distribution widths stay fixed (€72, €8, €4, 0.03, 0.10, 0.10, 0.03, 0.05,
  0.07) and do not scale with the means.
- The low/high utility values in the Cost-effectiveness tab are deterministic
  sensitivity-analysis ranges only; they never define base-case or PSA values.
- The HTA decision summary traffic-light thresholds (50%/5% probability bands,
  €1m/€10m budget-impact bands, and the 25% readiness Red share) are educational
  presentation rules, not official NICE or payer criteria. Clinical evidence
  maturity is always Red because the evidence is simulated, so the overall
  status can never be Green in this app.
- The HTA decision summary reads only outputs already computed by the other
  tabs; a domain shows "not yet available" until its analysis has been run in
  the session, and the provisional position is then "Not yet assessable". The
  evidence-priority table follows the same rule: rows whose driving output is
  missing show "Not yet available" instead of a guessed priority, except the
  relative-risk-reduction and engagement rows, which stay High with the status
  "Not yet quantified" until the PSA has been run because every other result
  depends on them.
- Evidence priorities combine dashboard domain status with clinical,
  implementation, equity and evidence-maturity considerations. They are not
  determined by EVPPI, so a gap with a low or zero EVPPI can still be rated High
  (for example the equity, workflow and interoperability gaps, which are not
  represented in the PSA parameter draws).
- The VOI traffic-light EVPI bands (€1, €100, €1,000 per patient) and the 1%
  and 40% decision-stability thresholds are illustrative educational rules, not
  official HTA or research-priority thresholds.
- The CEAC cost-vector alignment issue in `run_psa_eqalb()` was fixed by
  repeating the incremental-cost vector once per WTP grid point, so the CEAC
  curve is now non-decreasing in willingness to pay and agrees with
  `psa_probability_cost_effective()`.
- Dark mode is a colour-mode change only: the green/amber/red status cards keep
  their fixed inline pastel colours so the traffic-light meanings stay identical
  in both modes, and static `ggplot` figures keep their light image backgrounds.
  No other appearance controls are implemented.
- The app was renamed from "CardioConnect" to "eQalb". The CSS class prefix
  `cc-` (for example `cc-title`, `cc-panel-inner`) and the simulated
  `patient_id` prefix "CC" were deliberately left unchanged because they do not
  contain the old name and changing them would alter styling or exported data.
- Because the model source filenames changed, a Shiny session that was started
  before the rename must be restarted.
- `agents.md` previously listed a non-existent `cardioconnect_model.R`; the
  rename mapped it to `eqalb_model.R`, which was then corrected to the actual
  file `eqalb_markov.R` so the reference resolves.
- `renv` is a development-time tool. It pins package versions but does not pin
  the R installation itself beyond recording the version, and it adds
  `.Rprofile`, `renv.lock` and `renv/` to the project. Because `.Rprofile`
  activates the project library on startup, the app must be started from the
  project folder (as `run_app.R` does); a session started before `renv` existed
  keeps using the user library until it is restarted. `renv/library/` is local
  state and is ignored by version control.
- The results package contains the currently available results, so the file set
  changes between downloads and no archived snapshot of past runs exists. The
  PSA random seed is recorded when "Run probabilistic analysis" is clicked, so a
  seed changed after the last run is not reported for the exported results. The
  archive is not compressed (ZIP store method), so it is larger than a
  compressed equivalent. The file set is fixed by the app; there is no
  user-selectable subset.
- The landing title screen uses only CSS for its centring, gradient and fade-in,
  so the title screen is centred within the page rather than strictly within the
  viewport when the browser window is very short. The two animations are the
  only motion in the app and both are disabled under `prefers-reduced-motion`.

## Current task

Completed: added a reproducible package environment with `renv` 1.3.1.
`install.packages("renv")`, `renv::init()` and `renv::snapshot()` were run in the
project folder. Init linked the eight project dependencies (and their
dependencies, 130 packages in total) from the existing user library into
`renv/library/`, so nothing was downloaded, and wrote `renv.lock` recording R
4.5.1 and every package version. `renv::status()` reports the project is in a
consistent state. The app was verified to launch and run all analyses and
exports through the launcher under the renv-activated library.

## Next planned task

Interpret the PSA, CEAC, sensitivity-analysis, budget-impact and
value-of-information results together now that all nine PSA parameters follow
the live inputs and the CEAC curve is correctly aligned.
## Update log

| Date | Change | Verified? |
|---|---|---|
| 2026-10-05 | Created project state file | No feature change |
| 2026-10-05 | Added five-year budget-impact analysis to the Cost-effectiveness tab | Yes - tested in the running app |
| 2026-10-05 | Reorganised the Cost-effectiveness tab into global assumptions, base-case, PSA/CEAC, and budget-impact sections (responsive two-column layout; shared inputs de-duplicated) | Yes - tested in the running app |
| 2026-10-05 | Replaced the long Kaplan–Meier interpretation paragraph with a five-domain traffic-light panel | Yes - tested in the running app |
| 2026-10-05 | Added a "KM simulation assumptions" panel listing the exact values used by the Kaplan–Meier simulation | Yes - tested in the running app |
| 2026-10-05 | Added a "Value of information" tab with EVPI per patient and single-loop regression-based EVPPI per patient from the stored PSA results, and preserved the nine sampled PSA parameter draws as extra PSA result columns | Yes - tested in the running app |
| 2026-10-05 | Replaced the long EVPI paragraph with a dynamic decision-uncertainty traffic-light card, short explanation, "What this means" box and threshold note (EVPI calculation unchanged) | Yes - tested in the running app |
| 2026-10-06 | Connected the live global intervention price to the PSA price distribution (previously centred on the hard-coded module constant, so the price slider had no effect on PSA results) | Yes - tested in the running app |
| 2026-10-06 | Connected the live global implementation cost and healthcare-use savings to their PSA distributions in the same way | Yes - tested in the running app |
| 2026-10-06 | Connected the live global RRR, year-1 engagement and follow-up engagement to their PSA distributions in the same way | Yes - tested in the running app |
| 2026-10-06 | Added three editable base-case health-state utility inputs and connected them to the base case, sensitivity-analysis base values and PSA means; the low/high utility values remain sensitivity-only | Yes - tested in the running app |
| 2026-10-06 | Fixed the CEAC cost-vector alignment in `run_psa_eqalb()` so each WTP row pairs with the same simulation's incremental cost | Yes - tested in the running app |
| 2026-10-06 | Added the "HTA decision summary" tab: five-domain traffic-light dashboard, provisional HTA position, dynamic interpretation and a nine-row evidence-generation plan, reusing existing outputs only | Yes - tested in the running app |
| 2026-10-06 | Made the HTA evidence-generation table dynamic: signals, status, priority and affected dashboard domain now come from the current outputs, with unknown rows shown as "Not yet available" and a highest-priority summary sentence | Yes - tested in the running app |
| 2026-10-06 | Before the PSA is run, the relative-risk-reduction and engagement rows now keep a High priority with "Not yet quantified" and the domain "Clinical evidence maturity / decision uncertainty"; post-PSA behaviour is unchanged | Yes - tested in the running app |
| 2026-10-06 | Applied a modern bslib Bootstrap 5 visual theme (teal palette, system fonts, card/button/tab/table styling) as presentation only; layout, IDs, server logic and calculations unchanged | Yes - tested in the running app |
| 2026-10-06 | Added a landing page and simple two-way navigation (hidden `nav_page` state driving two `conditionalPanel`s); the dashboard is hidden, not rebuilt, so input values and output bindings survive navigation | Yes - tested in the running app |
| 2026-10-06 | Added a light/dark colour-mode switch (`bslib::input_dark_mode()`, ID `color_mode`, light default) with dark-mode style overrides; presentation only, no ID, server or calculation change | Yes - tested in the running app |
| 2026-10-06 | Added a "Download complete results package" button on the landing page that ZIPs the currently available results plus a README listing what was and was not included, reusing existing reactives only | Yes - tested in the running app, ZIP validated and extracted |
| 2026-10-06 | Redesigned the landing page as a centred title screen with Start analysis, Project description and Download results views; removed the Appearance section and kept the single top-right light/dark switch | Yes - tested in the running app, both colour modes |
| 2026-10-06 | Centred the three landing subviews horizontally and vertically with a 46rem readable width and added a Back button (`home_back_from_start`) to the Start analysis view | Yes - tested in the running app, desktop and 390px mobile |
| 2026-10-06 | Centre-aligned the content inside the three landing subviews (headings, text, bullet block and buttons) with CSS scoped to `.cc-panel-inner`, keeping the bullet text left-aligned | Yes - tested in the running app, both colour modes and 390px mobile |
| 2026-10-06 | Renamed the application from CardioConnect to eQalb throughout (naming only): files `eqalb_markov.R` / `eqalb_survival.R` / `eqalb_owsa.R`, `eqalb_` symbol and download-filename prefixes, `EQALB_THEME`, "eQalb plus usual care" arm label | Yes - 18-value numeric probe identical before/after; app tested in the running app |
| 2026-10-06 | Added a reproducible package environment with `renv` 1.3.1 (`renv::init()` + `renv::snapshot()`), linking 130 packages into a project library and writing `renv.lock` for R 4.5.1; no packages downloaded | Yes - `renv::status()` consistent; app launched and ran analyses and exports under the renv library |