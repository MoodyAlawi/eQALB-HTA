# eQalb project state

Last verified: 2026-10-11

## Project purpose

Educational R Shiny HTA model for a fictional hypertension digital therapeutic
called eQalb.

All clinical data, costs, utilities, treatment effects, survival data, PSA
distributions, and economic outputs are illustrative or simulated unless
explicitly documented otherwise.

## File map

- `app.R`: Shiny UI and server logic (reference implementation and tutorials).
- `eqalb_markov.R`: economic model and reusable model functions.
- `eqalb_owsa.R`: reusable one-way sensitivity-analysis helpers, the canonical
  one-way range policy (`eqalb_owsa_range_specs()`,
  `eqalb_owsa_range_defaults()`, `eqalb_owsa_range_bounds()`,
  `eqalb_owsa_override_error()`, `eqalb_owsa_contains_warning()`) and the OWSA
  narrative (`summarize_eqalb_owsa()`).
- `eqalb_survival.R`: reusable simulated survival (Kaplan-Meier) helper.
- `eqalb_readiness.R`: reusable DHT readiness assessment.
- `eqalb_km_interpretation.R`: reusable Kaplan-Meier traffic-light interpretation.
- `eqalb_ui_copy.R`: interface wording shared verbatim with the browser stack
  (`CC_INFO_TEXT`, the HTA rule text and the OWSA sentences).
- `eqalb_price.R`: reusable value-based price analysis
  (`calculate_value_based_price()`): the supported annual price, the headroom, the
  required relative risk reduction and the 3 x 3 scan across the model's own
  bounds.
- `eqalb_tutorial.R`: Guided Tutorial: Part 1 (its own defaults, control metadata,
  fixed values including the post-event utilities, simplified traffic-light rules,
  teaching copy and the four-step decision summary) and Part 2 in full (the
  commissioning cases with their facts, the price rules and the 43-point price
  curve, the value-for-money result, the budget-impact coverage cap with its annual
  rows, affordability states and maximum affordable coverage, the four-answer
  readiness exercise, and the recommendation outcome). It calls the model,
  budget-impact, readiness and decision-summary functions and re-implements none
  of them.
- `api/`: FastAPI service and R worker exposing the R functions over HTTP.
- `frontend/`: Vue 3 + Vite browser interface; no model logic.
- `dev.sh`: start/stop/status control script for the three development services.
- `readme.md`: project overview and user-facing documentation.
- `run_app.R`: launcher that pins the address to 127.0.0.1:7788.
- `FRONTEND_PLAN.md`: browser-stack plan, phases and known limitations.
- `agents.md`: permanent instructions for the coding agent.
- `project_state.md`: current verified project state and next task.

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
  tab. One user-facing WTP control (Reference WTP threshold) drives the headline
  probability of cost-effectiveness, the reference row of the PSA summary table,
  the VOI thresholds and the HTA-summary rules. The CEAC x-axis upper limit is
  derived internally from that one control, so the CEAC exposes no second
  threshold of its own; the one-way sensitivity section keeps its own
  willingness-to-pay input for its incremental net monetary benefit column, and
  every threshold input in the app defaults to €100,000/QALY. The CEAC subtitle
  explains how to read the curve. The PSA summary table carries two (i) controls
  beside "Mean incremental cost" and "Mean incremental QALYs" whose popovers show
  a true mean component decomposition: the cost popover splits the mean into
  eQalb intervention cost, one-off implementation cost, healthcare-use savings,
  post-MI state cost and post-stroke state cost, and the QALY popover splits it
  into time without an event, time after MI and time after stroke, each with a
  total row that reproduces the headline summary value. The components are real
  heemod value variables (see `PSA_COMPONENT_NAMES`) rather than an assumed
  split, and their means come from the same successful simulations, so the parts
  sum to the totals; the no-event state cost is carried internally to keep the
  reconciliation exact but is not displayed because it is always zero.
- DHT Readiness & Implementation tab: quantitative reach and workload
  outputs, a seven-row "Domain assessment" table (domain, status, current input
  and plain-language interpretation) and the readiness inputs (target
  population, access, suitability, review minutes, languages, accessibility,
  interoperability and algorithm governance). Engagement is not adjustable here:
  the assessment reads the live year-1 and follow-up engagement values from
  Global Settings, so there is one engagement control in the app. The
  tab no longer shows a "Readiness overview" section; the per-domain detail
  lives in the Domain assessment table only, which is rendered inside a
  `.cc-readiness-domain` wrapper with a fixed column layout so the four-column
  table stays inside the panel at mobile widths.
- Budget-impact analysis (five-year, deterministic) in the existing
  Cost-effectiveness tab.
- Value of information (VOI) tab: EVPI per patient and regression-based EVPPI per
  patient for the nine sampled PSA parameters. The tab carries no traffic light
  of its own. Its interpretation sits behind a green on-demand "Decision context
  and interpretation" button (`cc_context_popover()`, trigger class
  `cc-context-trigger`, popover class `cc-context-popover`), which opens a short
  panel holding one dynamic headline (`assessment$label` from
  `voi_uncertainty_status()`), one plain-language paragraph built from the
  preferred option, the current EVPI and a magnitude word, and one example
  sentence. The "Method and limitations" list is a collapsed-by-default bslib
  accordion (`voi_method_accordion`) with the same six items. Decision
  uncertainty is shown as a traffic light only in the HTA decision summary,
  which calls the same `voi_uncertainty_status()` helper.
- HTA decision summary tab: a five-domain traffic-light dashboard (economic
  value, decision uncertainty, budget impact, clinical evidence maturity,
  implementation readiness), an overall status, a provisional HTA position, a
  dynamic plain-language interpretation and a dynamic nine-row evidence-priority
  table. The full traffic-light rules sit in an on-demand bslib popover
  ("Traffic-light rules"), and the evidence-priority table sitd in a collapsed
  bslib accordion ("Evidence-generation plan"), so the tab leads with the
  decision and status.
- Repeated "Simulated illustrative analysis" banners removed from the analysis
  tabs (value of information, HTA decision summary) and from the Kaplan-Meier
  headings. The landing Project description and Start analysis views keep the
  project-level disclaimer, and warnings that explain a specific result are
  retained.
- Traffic-light rules are on demand in every analysis tab that uses them
  (Kaplan-Meier, DHT Readiness, Value of information, HTA decision summary) and
  in the tutorial summary, through the shared `cc_rules_popover()` control.
- Short subheader explanations on the Sensitivity Analysis, Kaplan-Meier and
  DHT Readiness tabs, and an information control next to Annual healthcare
  savings.
- Guided tutorial: a four-step beginner walkthrough (base cost effectiveness,
  budget impact, DHT readiness, tutorial decision summary) with Next, Back, an
  exit, a return-to-step-1 control on the budget-impact step, a Finish tutorial
  button and a centred tutorial-specific completion card offering Open full
  analysis, Restart tutorial or Start Part 2: Commissioning case. It reuses the
  existing model, budget-impact and readiness functions and the existing
  `assess_hta_decision_summary()` readiness result, and shares the
  Cost-effectiveness plane and budget-impact chart builders with the full
  analysis. Step 1 also shows a compact read-only block
  under the no-event utility slider listing the fixed post-event utilities the
  tutorial applies (post-MI and post-stroke) with a short explanation. The
  five step-1 sliders (price, risk reduction, year-1 engagement, follow-up
  engagement, no-event utility) carry an on-demand information control instead
  of permanently visible explanation sentences, reusing `cc_info()` /
  `cc_label()` and the `cc-info-popover` styling. Steps 2 and 3 use progressive
  disclosure: each keeps a two-sentence introduction plus an information control
  holding the longer explanation, and each puts its detail in a collapsible
  `tags$details` section ("View annual breakdown", "View readiness
  calculations"). The budget-impact step leads with a compact summary card
  holding the five-year net budget impact, shows the linked Step-1 price with an
  "Adjust linked price in Step 1" action, and the readiness step leads with the
  domain statuses before an "Implementation conditions" card holding the two
  yes/no questions. The
  tutorial budget impact uses the tutorial's own step-1 price and follow-up
  engagement values.
- Optional Guided Tutorial Part 2 ("Commissioning case challenge"), reachable
  only from the Part 1 completion card via "Start Part 2: Commissioning case".
  It is a five-section tutorial-only case (Case brief, Value for money, Budget
  impact, DHT readiness, Recommendation) held in its own `tutorial_step` value
  (`part2`) with its own sub-step input (`tutorial_part2_step`), so every Part 1
  panel is untouched. Three complete, internally consistent cases are predefined
  in `PART2_CASES` (Case A "Regional roll-out", Case B "Integrated pilot", Case C
  "Fragmented deployment"), and `part2_case_index` draws one at session start and
  holds it for the whole run, so navigating or moving a lever never changes it.
  Every displayed fact, every model input and the budget, readiness and
  recommendation calculations read that one case through `part2_case_facts()`
  (the utilities are read from the model file, so they cannot drift), and an
  "Active case" banner plus the read-only Case facts overlay always name it. The
  facts are fixed per case, not globally: Case A is RRR 10%, year-1 engagement
  70%, follow-up engagement 42%, utilities 0.86 / 0.80 / 0.60, population
  100,000, review 10 minutes, 3 languages; Cases B and C differ on those values.
  Interoperability reads Yes in every case, while required-language availability
  reads Yes when the case supports at least three languages and No otherwise, so
  Case C (2 languages) reads No. WTP €100,000, the five-year ceiling
  €3,000,000, no Red domain allowed and the manufacturer's reference
  price of €150 per active user per year are identical in all three cases. The
  case has two levers: the negotiated price and a programme coverage cap. The
  price lever is
  `part2_price` (€150-360, default 360, step 5), which is passed into the
  existing `run_eqalb_model()` / `calculate_budget_impact()` and
  `calculate_readiness()` and affects the case only. The coverage lever is
  `part2_coverage` ("Programme coverage cap (% of eligible population)",
  10-100, default 100, step 5); it scales the case's own potentially eligible
  population passed to `calculate_budget_impact()` for the Part 2 budget impact
  only, via `part2_coverage_pct()` and `part2_covered_population()`, so the
  annual table, chart, five-year total, affordability status and recommendation
  checklist all move together. It does not enter the per-person model, so
  incremental cost, incremental QALYs, the ICER, the ICER chart and the
  value-for-money criterion are unaffected by the cap. The Budget impact section
  also carries a visible task statement and a compact three-state live note under
  the coverage slider: red ("Above the available five-year budget.") when the cap
  exceeds the ceiling, amber ("Within budget.") when it fits but sits below the
  highest affordable cap, and green ("Maximum affordable coverage achieved.") at
  that cap, using the same traffic-light colours as the readiness and status
  cards. That one-line note is the only budget status shown in the section,
  and `part2_max_affordable_coverage()` finds the highest cap that still fits by
  walking the coverage steps through `part2_budget_at()`. A fourth recommendation
  item, "Coverage maximised within budget", passes only when value for money,
  affordability and readiness all pass and the selected cap equals that maximum;
  the completion card requires it, and a separate `increase_coverage` outcome
  gives accurate wording when those three pass at a lower cap. The Value for money section
  also draws `part2_icer_plot`, a deterministic ICER curve across the whole
  slider range, built by `part2_icer_curve()` from the existing model function
  with a 100,000/QALY threshold line and a marker at the selected price; the
  curve reactive deliberately does not read the slider, so moving the slider
  only moves the marker. The chart carries no explanatory text, so the
  threshold crossing is shown graphically only. The section opens with the task
  "Find the highest annual price that remains cost-effective at the payer's
  €100,000/QALY threshold." (constant `PART2_PRICE_TASK`), so the exercise is to
  locate the top of the passing band rather than any passing value.
  `part2_max_acceptable_price()` reads that top value straight from the cached
  ICER curve (the highest slider value whose ICER is at or below the threshold),
  so it adds no model runs and never depends on the learner's slider. The result
  card reports one of three states: above the threshold (`PART2_PRICE_OVER`),
  passing but below the top ("Increase the price to find the highest acceptable
  negotiated price.", `PART2_PRICE_BELOW_MAX`), and at the top ("Maximum
  acceptable negotiated price reached.", `PART2_PRICE_AT_MAX`). The Budget impact section offers
  a "Change negotiated
  price" shortcut back to the Value for money section while value for money has
  not been achieved, and the global top row shows a Part 2-only orange "Case
  facts" button (with the "Assumptions" button hidden outside the full
  analysis) that opens `cc_part2_facts_modal()`, a read-only overlay of the same
  fixed facts. The value-for-money test is the ICER against the threshold with
  positive incremental QALYs, so it is never tied to the €150 manufacturer
  minimum, and the Case brief, the price lever note, the price info control and
  the overlay note all say so. The Case brief adds that the task is to find the
  highest negotiated price that still meets the criterion, so the €150 floor and
  the passing band are no longer presented as the answer. The three criteria
  (`part2_value_for_money_pass()`, `part2_affordability_pass()`,
  `part2_deliverability_pass()`) drive the status cards, the live checklist and
  one of the four `part2_recommendation()` outcomes; the conditional-adoption
  outcome adds a compact completion card holding "Retry Part 2 with different
  assumptions" and "Open full analysis", with Back retained in the section nav. Part 2 carries no panel-level disclaimer: the
  Part 1 tutorial disclaimer is hidden while `tutorial_step` is `part2` and is
  not replaced. The Part 2 DHT readiness section is a learner exercise only: four
  case-based questions ("How would this programme exchange information with
  existing clinical systems?", "How is the algorithm governed after
  implementation?", "How would the programme fit into routine clinical work?",
  "What level of follow-up engagement should this case assume?") each offer
  three concrete options labelled A/B/C that describe observable implementation
  choices rather than a quality word, and their values are the exercise codes
  (no/basic/strong, weak/partial/strong, high/moderate/low, low/moderate/high).
  `part2_readiness_level()` maps each code onto the input
  `calculate_readiness()` already accepts, so the exercise reuses the existing
  bands instead of new rules. It shows no traffic-light output: the per-domain
  readiness cards and the Deliverability card render in the
  Recommendation section under "Readiness with the selected DHT settings", and a
  single short line under the questions reports the reach and clinician hours
  the choices imply. A note under the engagement question states that engagement
  is included for learning and is not fully controllable by the commissioning
  team. The Recommendation section restates the Engagement description from the
  learner's own answer via `part2_engagement_level()`, so it reads "Follow-up
  engagement is low / moderate / high" for the 30% / 60% / 90% choice instead of
  repeating the traffic light's band; the status, thresholds and colours still
  come from `calculate_readiness()` and its shared text is left untouched for the
  DHT Readiness tab. No readiness choice reaches `run_eqalb_model()`,
  `calculate_budget_impact()`, the price lever or the coverage cap, so the ICER,
  the five-year budget and the maximum affordable coverage are unaffected.
  "Retry Part 2 with different assumptions" returns the price lever, the
  coverage cap, the section and all four readiness answers to their defaults, so
  a retry never inherits the previous case's answers.
- Guided Tutorial Part 1 in the browser stack
  (`frontend/src/views/TutorialView.vue` with `components/tutorial/`, driven by
  `eqalb_tutorial.R` through `GET /api/tutorial` and `POST /api/tutorial/part1`):
  the reference tutorial's four steps (base cost effectiveness, budget impact,
  DHT readiness, and the tutorial-only decision summary) and its completion card,
  reachable from the Home screen. Every default, range, label, explanation,
  status, threshold, interpretation, table row, chart series and decision-summary
  sentence is R's; the client renders them and derives nothing of its own. The
  session is isolated: `useTutorialSession` holds the tutorial's inputs, results
  and step and never reads or writes the analysis store, so a tutorial control
  cannot move a dashboard input and a dashboard edit cannot move a tutorial
  result. It uses explicit R-owned values for everything it needs, including the
  two post-event utilities, so the reference tutorial's behaviour of borrowing
  those two fields from the dashboard's utility inputs is deliberately not carried
  over. A control change re-evaluates all four steps in one request, as the
  reference tutorial's live reactive values did, coalesced so one drag of a
  slider is one request; a four-step stepper plus Next and Back move between steps
  and a step outside 1-4 is refused; "Restart tutorial" restores R's own defaults;
  leaving for Home or the full analysis keeps the session, and a page reload
  clears it. Part 2 is a separate section of the same screen, reached only from
  the Part 1 completion card; the Home screen has no Part 2 entry point.
- Guided Tutorial Part 2, slices 1 and 2, in the browser stack (the Case brief,
  Value for money and Budget impact sections,
  `frontend/src/components/tutorial/Part2*.vue` driven by
  `eqalb_tutorial.R` through `GET /api/tutorial/part2`,
  `POST /api/tutorial/part2/case` and `POST /api/tutorial/part2/evaluate`):
  reached from the Part 1 completion card and held in the same isolated tutorial
  session, so it shares nothing with the analysis dashboard and returning to
  Part 1 leaves Part 1's step, values and results untouched. R draws the case and
  returns an opaque handle; the client stores and echoes that handle and never
  selects, infers or names a case, and an unknown handle is R's error rather than
  a silent re-draw. A case's fourteen facts, its own post-event utilities, its
  later-section inputs, the 43-point price curve, every pass/fail classification,
  the highest acceptable price, the marker and the chart's labels, series colours
  and threshold line are all R's. A case's values are its own — the reference
  tutorial's case borrowed the implementation cost, the healthcare savings, the
  budget-impact settings, the digital-access settings and the two post-event
  utility fields from the dashboard, and that inheritance is gone. The curve is
  bound to its case: the case's curve is posted back so R re-classifies it rather
  than re-running its 43 model runs (a price change costs one run), R re-derives
  every classification in that path, and a curve belonging to another case is
  rejected. The Budget impact section (slice 2) is R-owned and equally isolated:
  the coverage cap scales only the case's covered population, so it can never
  move the per-person value-for-money result, and R computes the covered
  population, the five-year annual rows and chart series, the total, the
  affordability state against the case's own budget ceiling and the maximum
  affordable coverage by scanning the permitted coverage steps rather than
  inverting the budget formula. The DHT readiness section (slice 3) asks the four
  case-based questions and reports R's reach and workload line and its five figures
  in one closed disclosure, and it deliberately shows no traffic light: the seven
  domain statuses and the deliverability verdict are R's and render in the
  Recommendation section (slice 4), which adds the four-outcome commissioning
  checklist, R's outcome card for the case and a completion card with an "Open full
  analysis" action; the retry flow is implemented as well, both from that completion
  card and, when R's outcome is not `conditional_adoption`, from a retry row under
  the engagement note, so Retry is available whenever the Recommendation screen is
  reached.
- A dismissible welcome prompt shown the first time the full analysis is opened
  from the home page in a session, offering the tutorial or the full analysis.
  Its title, text and buttons are centre-aligned.
- Landing page shown on start-up: a centred title screen with an "Open analysis
  dashboard" button reachable from it, and a "Home" button inside the dashboard
  (show/hide toggles over the existing containers; no duplicated UI).
- Light and dark colour modes via `bslib::input_dark_mode(id = "color_mode")`,
  with light mode as the initial default. A single switch sits above both the
  landing page and the dashboard. The `color_mode` input is styling-only and is
  not read by any server logic.
- Read-only "Assumptions" button in that same global top row, next to the Home
  button and available in every view. It opens a closeable modal titled "Model
  assumptions and inputs" with five collapsible sections (user-adjustable inputs
  with their current values, fixed model inputs, model structure, PSA and CEAC,
  and scope and limitations). It adds no new input beyond a link trigger, reads
  all input values inside `isolate()` so changing an input never re-opens it,
  and renders the model constants from the model file rather than duplicating
  them. `cc_assumptions_modal(values, open_section)` accepts an optional section
  name: the "Assumptions" button passes none (everything collapsed), while the
  inline "multiple uncertain parameters" link in the PSA explanation opens the
  same modal with the "PSA and CEAC" panel already expanded.
- Consolidated results export: a "Download results package" button in the
  landing page's "Download results" view downloads one ZIP containing the
  currently available results plus a README that lists which analyses were
  included and which had not been run. It reuses the reactives already computed
  by the other tabs and never reruns an analysis.
- Centred landing title screen with "Start analysis", "Project description" and
  "Download results" subviews, each centred with a Back button and driven by one
  `conditionalPanel` per view over a hidden `nav_page` control. The Project
  description body copy is centred like the rest of the view and gets its own
  paragraph spacing from the scoped `.cc-desc` class, and it ends with a
  "Feedback and contact" paragraph containing a `mailto:` link and the LinkedIn
  link (new tab).
- Creator credit "By Mahmood Alawi" and two external links (LinkedIn and the
  GitHub repository) on the title screen, styled as a subordinate subtitle with
  a centred, wrapping link row.
- Reproducible package environment managed with `renv` 1.3.1: `renv.lock` records
  R 4.5.1 and the exact version of all 130 packages, and `.Rprofile` activates
  the project library. Development-time only; no model behaviour changes.
- Browser stack (additive, phase 1): a FastAPI service (`api/main.py`) and a Vue 3
  + Vite frontend (`frontend/`) that present the same R model on
  http://127.0.0.1:5173. The Shiny app is the reference implementation and is
  unchanged. No model arithmetic exists outside R: `api/r_worker.R` keeps a
  persistent Rscript alive, takes the endpoint handlers out of `api/plumber.R`,
  and calls them over a JSON-lines pipe, so every endpoint has one implementation
  and Python only transports JSON. Endpoints cover health, defaults, base case,
  PSA, one-way sensitivity analysis with optional edited bounds, budget impact,
  value of information (reusing PSA draws) and the simulated Kaplan-Meier
  analysis. The frontend has global assumptions, the base case (its own
  deterministic cost-effectiveness plane plus the reconciled cost/QALY
  decompositions, shown on demand under the metric cards), an interactive
  cost-effectiveness plane with the mean-of-iterations marker, the
  PSA summary, CEAC with a reference-threshold dot and the iteration cloud, a
  tornado diagram, the budget-impact
  chart and table, the simulated survival curves with risk table and diagnostics,
  value of information, and light/dark mode in the Shiny palette. Every response
  carries the simulated-data notice, and non-finite model results arrive as JSON
  `null` and are shown as a dash rather than as a number. Source `./api/run_api.py`
  for the service, `./api/api_contract.md` for the contract, and
  `./frontend/README.md` for the interface.
- DHT readiness logic extracted into `eqalb_readiness.R`, sourced by `app.R` and
  by `api/plumber.R`, so the Shiny DHT Readiness tab, Tutorial Part 1 (Step 3),
  Tutorial Part 2 (DHT readiness) and the HTA decision summary readiness domain
  all use one implementation and the API can reuse it without sourcing `app.R`.
  The module holds `DHT_INTEROPERABILITY_LEVELS`, `DHT_ALGORITHM_APPROACHES`,
  `DHT_DISCLAIMER` (read by `calculate_readiness()` when it builds the
  interpretation), `dht_format_count()`, `dht_format_rate()` and
  `calculate_readiness()`. Nothing else moved: the app-only readiness constants
  (`DHT_STATUS_STYLES`, `DHT_THRESHOLD_NOTE`, `DHT_TRAFFIC_LEGEND`,
  `DHT_RULES_TRIGGER_LABEL`) stay in `app.R`, and the module has no Shiny
  dependency. Outputs are unchanged, verified by hashing the complete returned
  object before and after extraction.
- DHT readiness over HTTP: `POST /api/readiness` (and its FastAPI proxy) exposes
  `calculate_readiness()` with the ten Shiny inputs, returning the calculation
  object unchanged — the five figures, `numbers`, `domains`, `cards`, `counts`
  and `interpretation` — plus the simulated-data notice. `GET /api/defaults` now
  also carries `readiness`: the eight-input parameter contract (id, label, group,
  unit, type, default, min, max, step, percent) and `choices` with the
  interoperability levels and algorithm-governance approaches and the values
  Shiny preselects. Units follow the R function: the access shares and the two
  engagement fields are percentages (0-100), not the fractions the scenario
  inputs use, and nothing is rescaled in Python or TypeScript. Ranges, level sets
  and all error wording come from R, so no readiness rule exists outside
  `eqalb_readiness.R`. The endpoint is independent of every other analysis, so a
  readiness assessment needs no base case, PSA or budget-impact run first; the
  response shape is what `assess_hta_decision_summary()` consumes for its
  readiness domain.
- HTA decision summary over HTTP: `POST /api/hta-summary` (and its FastAPI proxy)
  exposes `assess_hta_decision_summary()` and `build_hta_evidence_priorities()`
  from `eqalb_markov.R`, the same two functions the Shiny HTA decision summary
  tab calls. Every field is optional and means "that analysis has not been run":
  the completed-analysis values are passed through unchanged from
  `/api/base-case` (icer), `/api/psa` (probability, mean NMB),
  `/api/value-of-information` (EVPI, EVPPI table and highest EVPPI) and
  `/api/budget-impact` (cumulative impact and the three components), while the
  six scenario fields behind the priority signals use the usual names, units and
  model base-case defaults. `readiness` carries the same inputs as
  `/api/readiness`; the seven domains are derived inside the endpoint by
  `calculate_readiness()`, so no domain or dashboard status is ever accepted from
  the client and every status is derived by
  `assess_hta_decision_summary()` (the evidence priorities read those statuses
  back out of its result, as Shiny does). The response adds `wtp`, the two full
  R results (`summary` and `evidence_priorities`) and `availability`
  (per-analysis booleans, `missing_inputs`, `not_assessable_domains`,
  `assessed_domains`). An incomplete state keeps R's own wording — "Not
  available" domains, "Not yet assessable" position, "Not yet quantified" and
  "Not yet available" priorities — and never receives a guessed position. The
  endpoint never reruns an analysis.
- The two readiness endpoints share one input parser (`readiness_args()` in
  `api/plumber.R`), so `/api/readiness` and the readiness block of
  `/api/hta-summary` cannot drift.
- Local development control script (`dev.sh`, run from Git Bash or with
  `bash ./dev.sh <command>`): `start`, `stop`, `restart`, `status` and
  `logs [r|api|vue] [lines]` for the browser-stack services. It runs the existing
  launchers unchanged — R Plumber on 8788, FastAPI on 8000 (so both APIs can run
  at once, since the published default 8788 is shared) and the Vue dev server on
  5173 with its proxy pointed at FastAPI — writes the process ids it manages to
  the git-ignored `.dev.pids` and output to the git-ignored `.dev-logs/`, reports
  "already running" instead of starting a service whose port is in use, and stops
  only the recorded ids (or, with no pid file, the listeners on those three
  development ports). `status` also reports whether `/api/readiness` and
  `/api/hta-summary` are reachable on each API and through the Vue proxy.
- Vue DHT readiness tab (phase 2): the seventh browser tab runs
  `POST /api/readiness` behind an explicit "Assess readiness" action and shows the
  R result — the `numbers` table, the seven-row domain assessment with
  traffic-light status badges, the overall interpretation and the simulated-data
  notice. Every control, range, step and level set is read from the `readiness`
  block of `GET /api/defaults`, so no default or threshold is written down in
  TypeScript. The clinical target population and the two engagement values are
  shared assumptions rather than tab controls: the tab displays them read-only and
  sends them, converting engagement from the fraction the scenario inputs store to
  the percentage the endpoint expects. Nothing is scored or thresholded in the
  frontend. The domain table uses the Shiny header wording ("Plain-language
  interpretation"), and an on-demand "Traffic-light rules" disclosure carries the
  exact Shiny rule wording and colour meanings (`DHT_THRESHOLD_NOTE` and
  `DHT_TRAFFIC_LEGEND` copied unchanged from `app.R`); it opens by mouse or
  keyboard, closes with Escape and stays inside a 390px viewport. The old Shiny
  "Readiness overview" card stack was not carried over; `cards` is not rendered.
  Since Batch 4 the inputs are one field per row in a panel-specific stacked
  layout, grouped under the `group` headings R returns for each spec (Population
  and access; Engagement; Workflow burden; Language access; Accessibility) with an
  interoperability and an algorithm-governance group for the two dropdowns, and the
  interoperability control explains itself with the existing R sentence published
  as that choice set's `info` field. No readiness rule, threshold, status or
  interpretation changed. Every analysis tab, this one included, marks a stored
  result as computed from earlier inputs through the shared `StaleNotice`
  component, and Escape closes any secondary-information disclosure app-wide
  through `useDisclosure.ts`; that behaviour is described under "Current
  methodological interpretation".
- Vue HTA Decision Summary tab (phase 2): the eighth browser tab runs
  `POST /api/hta-summary` behind an explicit "Assess HTA summary" action and
  renders that response unchanged — the overall status and provisional position,
  R's interpretation, the five decision-summary domains (Domain, Status as a
  traffic-light badge, current values, plain-language interpretation), the
  evidence-priority table (Priority, Evidence gap, Evidence needed, Current
  status), R's priority summary, and a disclosure with the remaining priority
  columns (current model signal, why it matters, suggested study, dashboard
  domain). A second disclosure lists the availability of the five upstream
  analyses, R's not-assessable domain names and the request fields that were not
  supplied, and the same information is repeated in a visible notice whenever
  something is missing. The request body is assembled only from what the other
  tabs have already produced (base-case ICER, the PSA's probability and mean NMB,
  the value-of-information EVPI/EVPPI rows, the budget-impact totals) plus the
  current scenario signals; the readiness block is sent only once the readiness
  assessment has been run — as in the Shiny app, where the readiness reactive is
  NULL until then. No status, priority, position or missing value is derived in
  TypeScript: R's words "Not available", "Not yet assessable", "Not yet
  quantified" and "Not yet available" are shown as returned. The summary is
  assessed at the threshold the PSA was run with when one exists, otherwise at
  the current reference threshold. Since Batch 4 the position card, R's
  interpretation, R's incomplete-state warning and R's notice are visible and the
  dashboard table and the evidence-priority table sit in the closed "Decision
  dashboard" and "Evidence priorities" disclosures with their R strings beside
  them; when a value-based price result is already stored in the session one extra
  `.insight` block repeats R's maximum acceptable price, current price, headroom
  and `headline.interpretation`. That insight reads existing component state only:
  the value-based price result is not part of this request, its body, its five
  availability flags or its gating.
- Kaplan-Meier interpretation extracted into `eqalb_km_interpretation.R`
  (`km_number()`, `km_p_value()` and `assess_km_interpretation()`, moved verbatim
  from `app.R`), sourced by `app.R` and by `api/plumber.R`, so the Shiny
  Kaplan-Meier tab and the browser tab are classified by one implementation.
  `POST /api/survival` now returns `interpretation` (the complete
  `assess_km_interpretation()` result: `overall_status`, the five `domains` with
  their statuses, `counts`, R's plain-language `interpretation`, the five `rules`
  and `display`, the statistics already formatted by R's own helpers) and
  `logrank_note`, the Shiny tab's descriptive log-rank line with the
  simulated-data notice. Nothing is derived outside R, and no threshold or status
  wording exists anywhere else.
- Vue Kaplan-Meier interpretation panel: the survival tab renders the response's
  interpretation — overall status, R's interpretation paragraph, the counts table
  behind the domains, the hazard-ratio and log-rank lines with R's formatted
  values, the descriptive log-rank note, one traffic-light card per domain with
  R's own explanation, and the five rules in a collapsed disclosure. The panel
  appears only after a simulation has been run, and the tab's chart, risk table,
  diagnostics, action gating and arm-contrast verdict are unchanged.
- Browser Home screen and results package (presentation only): the app opens on a
  minimal centred Home screen (`frontend/src/views/HomeView.vue`) with the eQalb
  wordmark flanked by two decorative ECG segments, one travelling pulse crossing
  all three in the title's colour: the letters rest in a subdued tint of the title
  colour and the signal crosses them as a moving wave, e → Q → a → l → b, each
  brightening into the full title colour with a brief soft bloom and starting back
  toward the resting tint as the next letter rises, so the word is never held fully
  lit. The heading names itself (and is not focusable), the letter spans are
  aria-hidden, and assistive technology hears
  "eQalb" once. Then "By
  Mahmood Alawi", the subtitle "An educational HTA model", the primary "Start
  analysis" action, "Project description" and "Download results", the
  creator/contact links (LinkedIn, GitHub) and a small icon light/dark control at
  the top-right. The whole composition is drawn complete and static — traces drawn
  whole, every letter in the full title colour — when the user prefers reduced
  motion.
  The hosted Shiny tutorial link and the long model-description paragraph were
  removed from Home in Batch 1 of the UX revamp, and the project-level disclaimer
  now lives only in the Project description view: it was removed from Home and
  from the dashboard footer, which no longer exists. Two subviews
  (`ProjectDescriptionView.vue`, `DownloadResultsView.vue`) carry the Shiny
  description wording, contact address and analyses list, and the session's
  exportable results respectively; Back and Escape return Home, and a compact
  persistent "Home" button sits in the dashboard header. Navigation is one shared
  ref (`frontend/src/composables/useAppView.ts`), not a router, and it never
  touches inputs or results. The model contract is fetched only when the dashboard
  is first opened, so Home makes no API request. `frontend/src/export/zip.ts` is a
  dependency-free store-only ZIP writer and
  `frontend/src/export/resultsPackage.ts` formats only values the API already
  returned, for the analyses the session has actually run; a README in the package
  lists what was and was not included and states the remaining backend gap
  (R-rendered chart images). No prompt, no Vue component and no endpoint
  calculates, rescales or reinterprets a model result.
- Browser interface foundation (UX revamp, Batch 1; presentation only): every
  help popover (`InfoTip.vue` — the assumptions, PSA controls, budget controls,
  readiness input, EVPI/EVPPI and the metric hints) is an overlay. The panel is
  teleported to the page body, positioned in viewport coordinates and clamped to
  the visible client area, so opening one never expands or shifts its card, row,
  table or the page, it stays fully visible at 390px, and a tall explanation
  scrolls inside the panel; the position is recomputed while the page scrolls or
  the window resizes. Click, Enter and Space open it, Escape closes it and
  returns focus to the trigger, and an outside click closes it. The dashboard's
  repeated simulated-data banner was removed (the Project description view keeps
  the project-level disclaimer, and the polish pass recorded under Current task
  has since removed the last per-result `notice` lines from the analysis tabs), the footer, the unreachable-service state, the
  assumptions header, the OWSA ranges hint, the Project description "How it is
  built" section and the network-error message no longer name internal files,
  launch commands or ports, the dashboard status chip and theme control are
  presentational only, "Value-based Price" now precedes the final "HTA Decision
  Summary" tab, and that final tab carries a small status marker and a matching
  panel top accent that follow R's overall status once the summary has been
  assessed. Spacing, typography, card, button and transition tokens were
  refreshed; no component library was added and no information architecture
  changed beyond the tab move.
- Input reset and result lifetime in the browser interface (presentation only):
  "Reset model inputs" restores the 16 model assumptions and the reference WTP
  threshold to the R base case, and nothing else — the PSA, Kaplan-Meier,
  budget-impact, readiness and OWSA analysis settings, the shared target
  population and every completed result are kept. It is enabled exactly when
  something in that scope differs from the defaults. Readiness additionally has
  Shiny's own "Reset values", which restores the seven readiness inputs and clears
  the readiness assessment only, as `observeEvent(input$reset_readiness)` does in
  `app.R`. Clearing results is a separate, separately confirmed action
  ("Clear all results", inline confirmation listing what it removes) and is never
  combined with either reset. The readiness and HTA summary tabs remember the
  request that produced the stored result and show the usual warning when their
  own inputs have changed since ("computed from earlier inputs"); no result is
  deleted by editing or resetting an input.
- R's OWSA interpretation (moved into R for both presentations; wording extended in
  the OWSA-interpretation task): the sensitivity tab renders R's interpretation of
  the run inside the closed "How to interpret this result" disclosure, taken from the
  API rather than rebuilt — `POST /api/owsa` returns `summary` (one sentence per
  line, written by `summarize_eqalb_owsa()` in `eqalb_owsa.R`, the function the
  Shiny tab calls) and `summary_note` (the paragraph shown above it,
  `OWSA_SUMMARY_NOTE` in `eqalb_ui_copy.R`); before a run the panel shows
  `owsa_prerun_note` from `GET /api/defaults`, Shiny's own "Set the assumptions and
  click Run sensitivity analysis." R's interpretation states the base case and the
  decision reference it is read against (for INMB, above or below €0 at the selected
  threshold; for ICER, the ICER value against the reference threshold in the wording
  `assess_hta_decision_summary()` already uses; for the incremental cost and QALY
  rankings, the value plus the incremental net monetary benefit the decision is made
  on), names the two or three parameters whose tested range moves that outcome most,
  states whether the decision survives the tested ranges, names any parameter the run
  could not vary, and closes with the one-way limitation. The ranking it names is
  R's `impact_range` for the selected outcome, so the interpretation, the chart and
  the table describe one ranking whatever the ranked-outcome selector is set to —
  the clarification the panel used to show for a non-INMB ranking is gone because
  it is no longer true. Line breaks are kept (Shiny honours them by styling
  `#owsa_summary` with `white-space: pre-wrap`, as the browser panel already did, so
  long lines wrap at 390px instead of overflowing). Every number, rank and
  classification is R's: the robustness sentence reads R's own cost-effectiveness
  flag for each scenario (`eqalb_owsa_cost_effective()`, the one definition of the
  threshold rule). `eqalb_owsa_scenario_rows()` presents a `run_eqalb_owsa()` result
  in the per-scenario shape the interpretation reads, carrying the selected outcome,
  R's flag per scenario and the outcome attributes; the Shiny frame lacks them and
  the interpretation falls back to `inmb`, which is the ranking that tab has.
- Canonical one-way range policy (`eqalb_owsa.R`, R only): the ranges are derived
  for the scenario being analysed instead of being fixed literals.
  `eqalb_owsa_range_specs()` declares one row per parameter (group, unit, domain,
  range mode, R's source label and rationale sentence),
  `eqalb_owsa_range_defaults()` derives the range from the value the parameter has
  in that scenario — an absolute offset for 11 parameters, the documented
  no-discounting/twice-the-rate pair for the two discount rates, and the nearest
  valid distinct whole-year pair for the time horizon — clamped to the parameter's
  domain, and `eqalb_owsa_range_bounds()` applies any supplied range on top and
  labels each row `Model default` or `Adjusted` itself. `POST /api/owsa` and
  `POST /api/owsa-defaults` use it, `GET /api/defaults.owsa_parameters` publishes
  it for the model's own base case, `eqalb_price.R` and the standalone analysis
  block in `eqalb_markov.R` read the same definition through
  `eqalb_owsa_parameters()`, and Shiny's sensitivity-analysis sidebar is built and
  updated from it, so no presentation defines a one-way range of its own.
  A range R cannot derive (a zero rate has no "twice the rate" scenario above it)
  keeps its row with R's own sentence and no numbers rather than being dropped; a
  supplied range that breaks a rule is reported on its row and rejected by the
  analysis endpoint; a usable supplied range that no longer contains the scenario's
  own value stays active with R's observation in `range_warning`, because a range
  is the caller's absolute scenario and is never rebased.
- Per-tab CSV exports (presentation only, `frontend/src/export/tabExports.ts`):
  the base-case tab writes Shiny's `eqalb_cost_effectiveness_results.csv` row for
  row (nine model inputs, then incremental cost, incremental QALYs and ICER, in
  section/parameter/value/unit columns), the sensitivity tab writes the ranked
  table the API returns (one row per parameter with its low and high results,
  named `eqalb_owsa_ranked_table.csv` because Shiny's file is the long
  one-row-per-scenario layout), and the survival tab writes its summary tables —
  arm summary, number at risk, interpretation checks and modelled expectation — as
  `eqalb_km_summary_tables.csv`, deliberately not named like Shiny's
  patient-level dataset export. Each button is disabled until its analysis has
  run, and the shape differences are stated on the tab.
- Interface wording shared by both presentations (`eqalb_ui_copy.R`): `CC_INFO_TEXT`
  (the analysis explanations) and the HTA decision-summary rule constants
  (`HTA_SUMMARY_RULE_NOTE`, `HTA_EVIDENCE_NOTE`, `HTA_RULE_ITEMS`,
  `HTA_RULES_TRIGGER_LABEL`) moved verbatim out of `app.R`, which sources the
  module as before. `GET /api/defaults` publishes the 17 analysis explanations in
  `info_text` and on each `parameters[]`/`readiness.parameters[]` row as `info`
  (`""` where an input has none); `POST /api/hta-summary` publishes `rules`,
  `evidence_note` and `rule_note`. Tutorial/Part 2 entries and the unused
  `willingness_to_pay` key are not published, and the endpoint fails loudly if a
  key it must publish is missing from the dictionary.
- On-demand explanations in the browser interface (`frontend/src/components/InfoTip.vue`):
  every control whose Shiny equivalent carries an `i` control now shows the same
  text — the nine mapped model assumptions, the global reference threshold, the
  budget population and uptake, the readiness clinician-review input, the PSA
  simulation count/seed/mean cost/mean QALYs, and EVPI/EVPPI. The trigger is a
  real button with `aria-label`/`aria-expanded`/`aria-controls`, opens by click,
  Enter or Space, closes on Escape (returning focus) and on an outside click, and
  the panel is laid out in the normal flow so it can never widen the page. The
  HTA summary tab renders the seven rule sentences and both notes the same way its
  readiness counterpart does.
- PSA defaults and permitted range (`api/plumber.R`, `simulation_defaults()`):
  the simulation defaults were aligned with the Shiny PSA control — 1,000 draws
  and seed 12,345 — and the bounds Shiny offers are now part of the contract:
  `psa_n_sim_min` 100, `psa_n_sim_max` 10000, `psa_n_sim_step` 100 and
  `psa_seed_min` 1, published by `GET /api/defaults`. `POST /api/psa` reads its
  own defaults and bounds from that same function, so the range the interface
  offers is the range R validates, and an out-of-range value is rejected by R's
  existing validator (`'n_sim' must be between 100 and 10000.`,
  `'seed' must be between 1 and 2147483647.`). No distribution, draw, threshold
  or calculation changed. That entry recorded the duration estimate the panel
  derived from a previous run; Batch 2 of the UX revamp removed it, so the panel
  now states only that a 1,000-draw PSA takes minutes and that the tab must stay
  open while a run is in flight, and the 10,000-draw ceiling's relationship to the
  FastAPI worker's 15-minute request timeout (`EQALB_R_TIMEOUT`, default 900 s) is
  recorded in this file and in `api/api_contract.md` rather than in the interface.
- Request-body precision in the FastAPI worker (`api/r_worker.R`): the request
  body a client posts is rebuilt for the plumber handler with
  `jsonlite::toJSON(..., digits = NA)`, matching the reply writer's own setting, so
  numbers reach R at the precision the service transmits instead of jsonlite's
  default four decimal places. Verified before and after on the wire: a posted
  `incremental_cost` of 1234.5678901234 arrived as 1234.5679 and now arrives
  unchanged, and the 1,000-draw PSA at seed 12345 now gives EVPI 4.70724749145015
  through FastAPI, identical to plumber and to a direct R call, where the worker
  path previously reported 4.6942935. Everything else in the worker's request and
  reply shaping is untouched, and a `digits = NA` value is only cut beyond 15
  significant digits, which is the precision both services send.
- Value-based price module: `eqalb_price.R` with
  `calculate_value_based_price()`, exposed as `POST /api/value-based-price`, with
  the typed client contract (`ValueBasedPriceResponse`, `postValueBasedPrice()`)
  and its Vue tab, "Value-based Price" (immediately before the final "HTA
  Decision Summary" tab). The tab renders R's response only: the supported annual
  price, the headroom against the current price, the required relative risk
  reduction, the 3 x 3 scan, the availability block and R's sentences, with a
  stored result kept and marked as computed from earlier inputs when the
  assumptions or the threshold change.
  The module solves the annual intervention price at which the model's own
  incremental net monetary benefit is zero from two `run_eqalb_model()` runs,
  confirms the answer with a model run at the solved price (the residual it
  returns is the confirmation), and falls back to a shape-free bisection search if
  the model does not reproduce the straight-line cost response. It also returns
  the relative risk reduction the current price would require (bisection inside
  the model's validated 0-1 domain, with the bracket width reported and the
  requirement compared with the model's one-way range), and the 3 x 3 scan of the
  supported price across the model's existing relative-risk-reduction and year-1
  engagement bounds (`eqalb_owsa_parameters()`).
  Every status band, level label, sentence and reason is R's; unavailable values
  are `null` with R's reason and an `availability` block, never a guessed number.
  With the default inputs at €100,000/QALY the supported price is €155.0298
  (confirmed to −3e-12), €204.97 below the current €360, and the current price
  would need a 24.61% relative risk reduction, above the model's 15% one-way
  bound.

## Current methodological interpretation

- ICER shows incremental cost per additional QALY.
- The cost-effectiveness plane shows incremental costs and QALYs for one
  scenario.
- Deterministic sensitivity analysis changes one input at a time. Its low and high
  values are derived in R from the value each parameter has in the scenario being
  analysed, so they follow the current assumptions; they are illustrative
  scenarios, not confidence intervals.
- A result is a snapshot: no analysis is recalculated by an input change, and
  each tab replaces its own result only through its own action button. When the
  inputs a tab would now send differ from the ones its stored result was produced
  from, the tab says so with the shared `StaleNotice` pattern instead of silently
  presenting the older result; the notice names the button that replaces it and,
  where it applies, reports the threshold or the ranked outcome the stored result
  used. It never states a model conclusion, and it is the same sentence in all
  nine tabs.
- Secondary information is disclosed on demand, and Escape closes the disclosure
  the keyboard focus is inside and returns focus to its summary. That behaviour is
  installed once (`useDisclosure.ts`, from the composable every screen calls), so
  it holds on the dashboard panels and on the standalone Download-results view
  alike; the assumptions sidebar's `details.group` input groups are not
  disclosures and do not close. Mouse, Enter and Space continue to open each
  disclosure, and an open information tip closes on Escape before the disclosure
  behind it.
- PSA varies multiple uncertain inputs together.
- CEAC shows the proportion of PSA simulations with positive net monetary
  benefit at each WTP threshold. Its x-axis limit is `max(2 x reference WTP,
  €100,000)`, computed internally by `psa_ceac_wtp_max()` from the single
  Reference WTP control, so the axis always contains the reference value and the
  default view is unchanged from the previous explicit €200,000 limit.
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
- The browser stack presents the same single model through a second interface:
  the R modules remain the only place where ICERs, QALYs, PSA draws, tornado
  impacts, budget impact and survival curves are computed, and the API returns
  those values unchanged. So the two interfaces cannot disagree about model
  output, only about presentation. Costs stay in EUR and effects in QALYs, the
  reference threshold defaults to €100,000/QALY in both, and the simulated-data
  notice is attached to every API response rather than to each view.
- In the browser stack the PSA, one-way and readiness analyses are explicit user
  actions with their own progress and error state, matching the action-button
  pattern of the Shiny app; results carry the threshold they were computed with,
  and a panel says so when the threshold has since changed.
- Value-of-information results in the browser stack are computed from the draws
  the client already holds, so they are per patient and per threshold exactly as in
  the Shiny app; EVPPI returns an explanation instead of a table when fewer than
  100 successful draws are available.
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
- Tutorial Part 2 is a commissioning case, not a new model. It applies its own
  fixed case facts and its own criteria (ICER ≤ €100,000/QALY with positive
  QALYs, five-year net budget impact ≤ €3,000,000, and no Red readiness domain)
  to the existing model and budget-impact functions. It deliberately does not
  use the full-analysis HTA-summary thresholds or the Part 1 tutorial bands, so
  the same word ("Green", "Pass") does not mean the same rule in the three
  places. Part 2 runs no PSA, so its "Value for money" test is deterministic and
  does not represent decision uncertainty. The value-for-money pass rule is the
  ICER against €100,000/QALY with positive incremental QALYs, so it never tests
  the price against the manufacturer's €150 minimum. The exercise asks for the
  highest price that still passes for the active case, which is read from the
  same ICER curve by `part2_max_acceptable_price()`; the top of the passing band
  is €155 under Case A, €295 under Case B and €170 under Case C, so the answer
  moves with the case rather than being fixed at the €150 manufacturer floor.
  The budget-impact exercise scales the case's budget population by the learner's
  coverage cap and reports the highest permitted coverage step that still fits
  the €3,000,000 five-year ceiling, found by evaluating the steps in R; the cap
  changes the budget result only and never the per-person value-for-money rule.
- The value-based price is the highest annual intervention price whose incremental
  net monetary benefit is zero at the reference threshold. Incremental cost is a
  straight line in that price, so it is solved from two model runs and then
  confirmed by a third run at the solved price; the confirming run's residual is
  returned as `verification_nmb`. A solved price outside the model's own price
  bound, or a scenario whose incremental QALYs are not positive, is reported as not
  available with R's reason rather than as a number.
- The value-based price status is read from the model run at the current price, not
  from the solved price: Green means that run reaches the reference threshold, Red
  means it does not, and Not available means the model did not return the values
  the comparison needs. The required relative risk reduction is the smallest value
  inside the model's validated 0-1 domain that reaches the threshold, reported with
  its bisection bracket width and compared with the model's one-way range (5% to
  15%). These bands, like the VOI and Kaplan-Meier bands, are illustrative
  educational presentation rules.
- The value-based price tab presents that solve; it makes no pricing judgement of
  its own. Each scan cell shows the price R returned for that assumption pair with
  the status R returned for it, and a combination R could not identify reads
  "Not available" with R's note in the scan detail rather than a dash or a zero, so
  the 3 x 3 table cannot turn a missing result into a number. The request sends the
  current scenario and the reference threshold, so the price the model ran at, the
  price the solve used and the headroom all describe the same price.

## Known limitations

- Clinical inputs and economic values are illustrative.
- PSA distributions and assumed standard deviations are not evidence-based.
- Kaplan–Meier data are simulated, not patient-level clinical evidence.
- Kaplan–Meier traffic-light thresholds (hazard ratio, log-rank p, and the 10%
  and 25% censoring-difference bands) are illustrative educational rules.
- The value-based price status is read from the model run at the current price, so
  a Green status can coexist with an unreported maximum acceptable price when the
  solved price lies above the model's own price bound (a threshold above roughly
  €970 million per QALY). The maximum acceptable price, the headroom and the
  required relative risk reduction are illustrative model outputs, not a pricing
  recommendation.
- The Kaplan–Meier survival simulation is a simplified patient-level model:
  engagement is redrawn each year, it stops at the first MI or stroke, and death
  is treated as competing censoring rather than the economic model's explicit
  Death state.
- The Kaplan–Meier curve is only regenerated when "Simulate and update curve" is
  clicked, so changing a global input does not redraw the curve until then; the
  assumptions panel reports the values the plotted run actually used.
- The tutorial step-1 "Fixed post-event utilities used in this tutorial" block is
  static UI text rendered from the model constants (`utility_post_mi`,
  `utility_post_stroke`), so it does not track the editable base-case utility
  inputs in the full analysis; the tutorial calculation itself keeps using those
  live inputs.
- The app-wide loading indicator's busy state is a module-level ref-counted
  counter. Every operation that starts it also ends it through its own completion
  token, called in a `finally`, and a one-hour watchdog recovers a completion that
  never arrives (warning only in development), so the loader cannot stay up for an
  operation that has finished or will never finish. Two limits remain, both
  pre-existing and outside the loader: a request that never settles leaves its own
  panel reporting "Running…" until the page is reloaded (only the app-wide loader
  is recovered), and nothing cancels an in-flight request when its component
  unmounts, so a Part 2 case drawn while leaving the tutorial still completes in
  the background — verified to clear the loader when it settles. One
  development-server run that was serving source updates while a Part 2 case was
  being drawn showed a stale busy state with the card left up; it did not
  reproduce in the nine later development-server runs, the production build or the
  later hang and unmount checks, and no cause was established.
- No active Part 2 copy calls €150 a "minimum acceptable price" or a negotiation
  floor any more. The facts-table row reads "Manufacturer's reference price", the
  Case-facts overlay hint calls that price a starting point for negotiation, the
  Value for Money lever's InfoTip (`part2_price` in `eqalb_ui_copy.R`) says the
  reference price is context rather than the target answer, and `brief.policy` —
  which no component renders and which removal would have required changing the
  `Part2Contract` type — now carries the Case Brief's own framing of €360 as the
  manufacturer's starting proposal. The `manufacturer_minimum_price` field name,
  the €150 value and every case fact are unchanged. The Shiny reference app
  (`app.R`) and the Shiny-facing descriptions in `readme.md` and
  `api/api_contract.md` still use the old wording and were deliberately left
  alone, so the two presentation layers differ in that one respect.
- Formal model validation is deferred until the current modules are stable.
- PSA runtime is relatively long for large simulation counts.
- The CEAC x-axis upper limit is no longer user-selectable: it is derived from
  the Reference WTP control as `max(2 x reference, €100,000)`, so the plotted
  range changes with the reference threshold. The CEAC probability values
  themselves do not depend on the axis limit.
- Budget-impact analysis is deterministic and illustrative; avoided-event
  savings default to €0 and are not linked to the Markov model, and no
  discounting is applied.
- Sensitivity analysis scope is limited in these ways. The one-way ranges are
  illustrative scenario widths derived from the current base-case values, not
  evidence-based uncertainty intervals; there is no confidence interval behind any
  of them. The two discount rates use the model's own policy pair (no discounting
  and twice the current rate), so at the default 3% rate the upper scenario is 6%
  where the previous fixed literal was 5%, which changes those two rows and their
  impact values while every other row of the default analysis is unchanged. A zero
  discount rate has no "twice the rate" scenario above it, so R reports that row as
  having no derivable range instead of inventing one: the row stays in the table
  with R's sentence and no numbers, is left out of the ranking, and can be given a
  range by hand. Near the edge of the permitted domain the time-horizon scenarios
  sit on one side of the current horizon, which R reports as a warning; the row's
  bar then does not cross the base-case line.
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
- Tutorial Part 2 fixes its case facts. Its budget impact is built from
  tutorial-owned values rather than live dashboard inputs — the uptake schedule
  (10% in year 1 rising 5 percentage points a year), the five-year horizon, the
  avoided-event savings (0) and the tutorial's own fixed implementation cost and
  healthcare-saving values — scaled only by the case's population and its own
  follow-up engagement. The readiness exercise is insulated from the dashboard too:
  it passes the tutorial's own fixed digital-access, digital-suitability and
  accessibility values, so a full-analysis input cannot change a Part 2 readiness
  result either. The case's own inputs are the negotiated price, the programme
  coverage cap and the four readiness-exercise answers.
- Part 2 fixes the three utilities at the active case's own values (Case A
  0.86 / 0.80 / 0.60, with Cases B and C differing) rather than at the model
  constants, so unlike the Part 1 tutorial it does not follow the editable
  no-event utility slider. This is intentional: the case facts are declared
  evidence facts, not learner levers.
- Part 2's readiness summary shows all seven readiness domains, including
  Algorithm governance, which the Part 1 tutorial deliberately drops from its
  simplified view. The browser stack renders one card per domain, each carrying
  R's own status, in the Recommendation section; the reference tutorial's five
  summary cards cover Equity and access, Engagement, Workflow burden,
  Interoperability and Algorithm governance, so Language access and Accessibility
  are graded in the seven-domain test there without a card of their own.
- Part 2's readiness inputs are the tutorial's own: the browser stack's exercise
  passes the case's facts and the tutorial's fixed digital-access, digital-
  suitability and accessibility values, so no full-analysis input can change a
  Part 2 readiness result. The reference Shiny exercise still reads those three
  from the live controls, so unchecking "Accessibility features available" there
  would make the case fail its deliverability test with a Red.
  Algorithm governance, interoperability, workflow burden and follow-up
  engagement are the exercise's own answers.
- The readiness exercise's follow-up engagement choices (30% / 60% / 90%) drive
  the readiness Engagement domain and the follow-up reach figures only; the
  economic model and the budget impact keep the fixed 42% case value, so the
  case fact and the exercise can show different follow-up assumptions side by
  side. At High 90% the existing "Engagement retention" row (follow-up / year-1)
  reads above 100%, which is the existing formula rather than a new one. Part 2
  restates the card text from the learner's own answer, so the choice is named
  as "Follow-up engagement is low / moderate / high" rather than echoed as a
  traffic-light band.
- The readiness exercise is a single-radio group per question with correct answer
  "C" in three of the four questions. That is intentional teaching: the options
  describe progressively better implementation positions. The exercise has no
  scoring or feedback of its own, so the only consequence of a weak answer is the
  Recommendation verdict.
- The full-analysis DHT Readiness tab has no engagement control of its own. Its
  engagement domain and the follow-up reach figure read the global year-1 and
  follow-up engagement values, so the same figures serve the economic model and
  the readiness assessment and the two can never disagree. The tab still
  requires "Assess readiness" to be clicked, so a global engagement change is
  reflected only after the next assessment.
- The five-year net budget impact is exactly linear in the Part 2 levers:
  total = covered population x 15,000 x price + 360,000, and the covered
  population is the coverage cap times 100,000. At the minimum price of €150 the
  full-rollout total is 6,660,000, so price alone can never meet the 3,000,000
  ceiling; the coverage cap is what makes affordability reachable. The highest
  affordable coverage is 45% at €150 (2,997,000) and 15% at €360 (2,322,000),
  and at 40% (2,664,000) the budget passes but coverage is not yet maximised.
  The conditional-adoption completion card therefore needs both a value-for-money
  price and the highest affordable cap, not just any affordable cap.
- The coverage cap scales the budget-impact population only, so it deliberately
  does not change the per-person result. A consequence is that the Part 2 Case
  brief fact table shows "Potentially eligible population 100,000" while the
  budget impact works on the covered population, so the two numbers must be
  read together.
- "Maximum affordable coverage" is found by walking the coverage steps downwards
  and returning the first that fits, so it reuses `calculate_budget_impact()`
  rather than an inverted formula and stays correct if the uptake schedule, the
  horizon or the ceiling change. It costs one budget calculation per step (at
  most 19 cheap arithmetic calls, no model runs), and it returns NA when even
  the lowest step does not fit.
- The Part 2 ICER curve costs about 6.5 s to compute because it runs the
  existing model 43 times (one per €5 price step). It is computed once per Part 2
  entry and is not recomputed while either slider moves, so dragging a slider
  only re-renders the stored curve with a new marker. `part2_max_acceptable_price()`
  reads the highest passing value from that same cached curve, so locating the
  answer costs no extra model runs but does mean the Value for money result card
  waits for the curve on first entry to the section.
- The Part 2 value-for-money band differs by case because it is driven by the
  case's relative risk reduction and utilities: €150-€155 under Case A
  (incremental QALYs 0.00816), €150-€295 under Case B (0.01648) and €150-€170
  under Case C (0.00921). The €5 price step is what makes the narrowest of these
  bands visible and what lets the highest passing value be hit exactly; a €10
  step would leave the manufacturer's minimum as the only point on the acceptable
  side of the threshold under Case A. The ICER chart shows this crossing
  graphically, and the result card names only the selected price, so no text
  states the width of the passing band.
- The Part 2 Budget impact section shows only the one-line coverage status, so
  the five-year budget total, the €3,000,000 ceiling and the covered-population
  figure are visible only inside the collapsed "View annual breakdown" and in
  the Recommendation section. A learner who never opens the breakdown cannot see
  the budget amount while setting the coverage cap; that is intentional given the
  request for a leaner section, but it is worth knowing when demonstrating the
  case.
- The Part 2 affordability milestone message ("Affordability achieved...") was
  removed with the budget status card. The former value-for-money milestone
  message was removed with this change as well, because it fired on any passing
  price and would now celebrate a mid-exercise position rather than completion;
  the three-state result card in the Value for money section is the only
  criteria-based live feedback left in the case.
- The Part 2 case facts are shown in two places (the Case brief table and the
  Case facts overlay), both rendered from the same `part2_case_facts()`, so no
  value is duplicated in code, but the facts are intentionally visible twice on
  screen.
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
- The HTA decision-summary tab keeps a small number of simulated-data mentions
  that are *not* duplicates of the removed banner: the "Simulated illustrative
  data" value and explanation on the always-Red clinical-evidence-maturity card,
  and one trailing sentence inside the plain-language interpretation. The
  trailing sentence is produced by `assess_hta_decision_summary()` in
  `eqalb_markov.R` and is also written into the exported results package, so it
  was left unchanged rather than editing a model output and the export contents.
  Plot titles and captions likewise still name the simulated nature of the data
  because they are part of the generated analysis output.
- The traffic-light rules text exists in two forms: `HTA_RULE_ITEMS` (paragraphs
  for the popover) and `HTA_SUMMARY_RULE_NOTE` (the single-line form written into
  the exported package). The exported wording is deliberately untouched.
- The guided tutorial recomputes the base model through the existing model
  function rather than reading the Cost-effectiveness tab's cached result, so a
  tutorial slider changes the tutorial's own numbers and does not alter the full
  analysis inputs. At the default slider values the two agree exactly. The
  tutorial deliberately excludes the PSA, EVPI, EVPPI, tornado diagram and
  Kaplan-Meier modules, so it shows no economic-value or decision-uncertainty
  domain at all. Its decision summary therefore uses the simpler tutorial-only
  rules in `tutorial_ce_status()`, `tutorial_budget_status()` and
  `tutorial_readiness_status()` (cost effectiveness by incremental cost and QALY
  sign; budget impact Green below EUR 5m, Amber to EUR 10m, Red above;
  readiness Green with at least four Green domains unless the existing readiness
  result is Red). These are deliberately different from the full-analysis
  thresholds in `HTA_SUMMARY_THRESHOLDS`, which are unchanged. Clinical evidence
  maturity is always Red and never contributes to the tutorial overall status.
- The reference tutorial's readiness step takes its engagement assumptions from
  the tutorial's own step-1 sliders rather than the full-analysis readiness
  sliders, so the follow-up engagement value carries across steps without a
  second input. It also maps its two yes/no questions onto existing readiness
  inputs (interoperability maturity and the supported-language count) and drops
  the algorithm-governance domain from the tutorial presentation only; the
  browser tutorial carries the same three rules.
- The browser stack's Guided Tutorial Part 1 reproduces the reference tutorial's
  teaching sequence and substantive rules, with the same simplified
  tutorial-only thresholds as the Shiny tutorial (cost effectiveness by
  incremental cost and QALY sign; budget impact Green below EUR 5m, Amber to
  EUR 10m, Red above; readiness Green with at least four Green domains unless the
  shared readiness assessment is itself Red; clinical evidence maturity always Red
  and excluded from the overall status). Those rules live in `eqalb_tutorial.R`
  and are deliberately different from the full-analysis thresholds in
  `HTA_SUMMARY_THRESHOLDS`, which are unchanged. The tutorial's step-1 values are
  shared across its four steps exactly as the reference tutorial shares them (its
  price drives the budget impact, its engagement values drive the readiness
  domains, its eligible population drives the Step-3 reach figures), and its
  readiness assessment drops the algorithm-governance domain from the tutorial
  presentation only, so `calculate_readiness()` still reports all seven domains
  for the full readiness tab. The implementation is verified against an R
  reference fixture rather than against the Shiny application.
- The browser tutorial is the one place in the stack where a session is
  deliberately isolated rather than shared: `eqalb_tutorial.R` owns every value
  the tutorial needs that is not one of its nine controls, including the two
  post-event utilities, so a tutorial result cannot move when the analysis
  dashboard is edited and a tutorial control cannot move a dashboard input or its
  stored results. The reference tutorial read those two utilities from the
  dashboard's own inputs, so the two behaviours differ in that respect by design.
- The welcome prompt is shown once per browser session. It is not stored across
  sessions, so it reappears after a page reload; a persistent "do not show again"
  would need browser storage. Its centring is scoped to a marker class added to
  that one modal, so the global Shiny modal id used by `removeModal()` is intact.
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
- The full-analysis information controls are built by `cc_info()` / `cc_label()`
  and their text lives in `CC_INFO_TEXT`. They are deliberately limited to the
  main inputs and the EVPI and EVPPI headings, plus the five Guided-tutorial
  step-1 sliders (keys `tutorial_price`, `tutorial_rrr`,
  `tutorial_engagement_year1`, `tutorial_engagement_followup`,
  `tutorial_utility_no_event`). No discount-rate control exists in the model, so
  no control was added for it. The icon sits inside the input label, so the
  label's accessible name includes its own explanation. The icon is drawn in CSS
  (a borderless button holding a small circled `i`), so no icon font or extra
  package is needed, and both the information popovers and the
  traffic-light-rules popovers carry a custom class through the popover options
  (`cc-info-popover` and `cc-rules-popover`), which is the hook the scoped CSS
  uses to remove the heading margin that used to leave a light strip above the
  header. On the tutorial sliders the control sits inside the slider label, so
  the popover opens next to the slider it explains.
- Traffic-light rules are now on demand everywhere in the analysis area:
  `cc_rules_popover()` wraps the same bslib popover pattern for the Kaplan-Meier
  tab, the DHT readiness tab, the VOI tab, the tutorial summary and the HTA
  decision summary, so no rules paragraph is permanently visible.
- The three removed analysis-tab notice boxes are gone, but the same wording
  still appears where it is result-level output rather than a repeated banner:
  `BIA_DISCLAIMER` is part of `bia_interpretation` and `DHT_DISCLAIMER` is part
  of the readiness `interpretation` string. Both were left unchanged because
  they are generated output text, not standalone notices.
- Two wording inconsistencies remain by choice, because removing them would
  change either the model file (not editable in a presentation pass) or wording
  approved in earlier tasks: negative money values from `hta_summary_money()`
  and `voi_format_euros()` place the minus after the euro sign (for example
  `€-1,637.08` in the HTA decision-summary text) rather than before it as
  `format_euros_signed()` does, and the app mixes "Clinician-review" with
  "Clinician review" and "Kaplan-Meier" with the en-dash "Kaplan–Meier". The
  same `hta_summary_money()` string is written into `hta_decision_summary.txt`,
  so changing it would also change an export.
- Renaming the on-screen PSA row to "Probability cost-effective at selected
  WTP" was applied to the result table only. The exported `psa_summary.csv`
  keeps its own wording ("at the reference threshold") because exports were out
  of scope for that change.
- The two tutorial collapsible sections (`tags$details`) start collapsed, but
  their contents stay mounted in the DOM so Shiny renders them once. That means
  the annual budget-impact chart and the readiness calculation table are
  computed on entering the step even while hidden, and once a visitor expands a
  section it stays expanded for the rest of the session because the element is
  never removed from the page. The budget-impact step also gained one small
  presentation-only output, `tutorial_bia_linked_price`, so the linked Step-1
  price stays visible.

### Browser stack (api/ and frontend/)

- Status: phase 1 and phase 2 are complete, the P0 Kaplan-Meier interpretation
  fix is in, and all six P1 findings from the approved UI/UX audit are
  implemented — delivered in four batches: reset Option A plus the Shiny-parity
  CSV exports; the per-input help text plus the HTA traffic-light rules and
  evidence note; the PSA default/range alignment; and the OWSA narrative summary.
  The audit's 15 P2 polish findings are triaged: the two approved pre-1.0 fixes —
  the one-way sensitivity ranked-outcome mismatch and the tab-strip and table
  accessibility semantics — are implemented, twelve are deferred (three of them
  needing backend work) and one is closed as not reproducible. No deferred item
  may be started without approval.
- R is the sole source of every calculation, threshold, status, interpretation
  and evidence priority. The API, the R worker and the Vue client only carry,
  format and present what `eqalb_*.R` returns; no domain is scored, no ICER is
  derived and no evidence priority is ranked outside R. The readiness tab's
  "Traffic-light rules" disclosure restates Shiny's rule wording and colour
  meanings, but no numeric threshold and no status is reproduced in the client.
- Validation practice: PSA checks use `n_sim = 100` with `seed = 12345` (about
  20 s). The 1,000-draw default is only run when a full default PSA is explicitly
  requested, because it takes about three minutes.
- Unresolved documentation discrepancy, found while regression-testing the PSA for
  the value-based price task: a 100-draw PSA at `seed = 12345` with the model's
  default inputs now gives mean incremental cost 2417.75112277353, mean
  incremental QALYs 0.00780670525864131, mean NMB −1637.08059690939 and median
  ICER 333632.518831389 (P(CE) 0.00 / 0.01 / 0.07 at 50k / 100k / 150k), whereas
  the validation note recorded 2517.24320161568 / 0.00794926986130171 /
  −1722.31621548551 / 320482.009072636. The payload is deterministic (a rerun is
  bit-identical), matches a direct `run_psa_eqalb()` call exactly, is byte-identical
  between plumber and FastAPI, and is unchanged by loading `eqalb_price.R` (verified
  by running the PSA with and without the module), so the recorded figures came from
  different live inputs (the PSA distributions are centred on them by design) or a
  different draw count; the cause has not been established and no PSA code was
  touched by this task.
- The value-based price endpoint (`POST /api/value-based-price`) and its Vue tab
  both exist. A request costs about 40 model runs (roughly 7 s at the measured
  0.16 s each), so the tab runs only from its own button and marks a stored result
  as computed from earlier inputs when the assumptions or the threshold change. Its
  scan is a one-way analysis of two assumptions at a time (each figure varies one
  assumption at a time within the pair), not a joint-uncertainty estimate, and the
  tab states R's own note to that effect. The built bundle measures about 751 kB
  (252 kB gzipped), which includes this tab; the figure recorded earlier in
  `frontend/README.md` was stale and has been updated.
- The browser stack's Guided Tutorial covers Part 1 in full and all five Part 2
  sections, up to the recommendation and its completion card. The retry flow is
  implemented too: the completion card's "Retry Part 2 with different
  assumptions" draws a case other than the active one (R's `exclude_case_id`
  rule), returns to the Case brief and restores R's own defaults — verified in the
  running app, Case B to Case C, with the price lever back at €360, the coverage
  cap at 100% and the four readiness answers at their defaults.
- A Part 2 case costs about forty-four model runs, because its price curve is one
  model run per lever value; creating or resuming a case is therefore an explicit
  action with progress, and a fresh reload draws a new case (the client holds no
  handle to resume). A price change costs one further model run, because the case's
  curve is posted back for R to re-classify. Posting a curve never lets a caller
  decide a status — R re-derives every classification and the highest acceptable
  price from the model outputs — and a curve is bound to its case, so a curve
  computed for one case is rejected under another.
- The app-wide loading indicator is presentation only and reports waits that are
  already there: `useAppBusy.ts` counts running operations, and
  `AppLoadingIndicator.vue` shows a thin teal bar from 350 ms and a small centred
  card (wordmark, ECG line, status sentence) from 2.5 s, both gone as soon as the
  last operation settles. It is wired to the dashboard service load, the nine
  explicit analysis runs and Part 2's contract load, case draw and evaluation —
  never to short requests, control changes or the Part 1 evaluations. Measured
  operation times at the time of the change: an OWSA run about 5–7 s, a
  value-based price run about 7.6 s, a Part 2 case draw 8.3–14 s, the PSA minutes,
  while a base case (≈0.23 s), a dashboard open (≈0.15 s), a Part 2 evaluation
  (≈0.32 s) and a Part 1 evaluation (≈0.34 s) stay below the bar's grace period.
  The card is not a modal — no backdrop, nothing focusable, `pointer-events: none`
  — so it cannot interrupt focus order, Escape or a disclosure, and the ECG motion
  is off under `prefers-reduced-motion`, where the bar is a still full-width line
  and the trace is drawn complete. The trace's pulse crosses the whole line once
  per 2.8 s cycle and then holds off the path for the rest of it (its dash pattern
  is twice the length of the line, so the dash can be invisible at both ends of the
  sweep and no loop can stall part-way).
- Every operation that starts the busy state ends it, whatever happens to its
  promise: `start(label)` returns that operation's own completion token, the token
  is called in the caller's `finally` (so a rejection, a cancel or a component
  unmount cannot skip it) and calling it twice is a no-op, so it can never
  decrement another operation. Each token also carries one watchdog, set at one
  hour — twice the slowest run the interface can request (a 10,000-draw PSA,
  about 30 minutes at the measured 0.18 s per iteration) and four times the API
  R worker's default 900 s model-run timeout — so a completion that never arrives
  is recovered rather than leaving the loader up, and no genuine calculation is
  hidden early. The watchdog warns only under `import.meta.env.DEV`, and that
  branch is eliminated from the production bundle. The per-panel busy flags are
  separate: a request that never settles still leaves its own panel's button in
  its "Running…" state, which is the panel reporting its own request rather than
  the app-wide loader.
- The analysis tabs no longer render the API's `notice` field. The polish pass
  recorded under Current task removed the last per-result disclaimer lines (and
  the now-unused `.notice` rule), and the survival tab's `logrank_note` is shown
  up to the disclaimer only, using the response's own `notice` string as the cut
  so no wording is written in TypeScript. The `notice` field itself is untouched
  in the contract, and R's substantive wording is unchanged: the Kaplan-Meier
  "Evidence credibility" status text, its overall interpretation and the HTA
  summary's interpretation still contain the words "not clinical evidence" inside
  R's own sentences, which a presentation pass may not reword.
- Three interface-copy subjects exist where R publishes no wording: the sentence
  beside the readiness tab's "Algorithm governance" heading, and the sentences
  beside the assumptions panel's "Event costs", "Discounting" and "Time horizon"
  group headings (R's `CC_INFO_TEXT` defines individual parameters, not group
  headings). Each describes what its subject is and why it matters and states no
  value, range or model rule; a future R-side definition for any of them should
  replace the interface sentence.
- The HTA decision-summary tab's single-entry availability lists were fixed during
  the final validation pass (`HtaSummaryPanel.vue`, `asList()` at the boundary).
  Before that, a response whose `missing_inputs` or `not_assessable_domains` held
  exactly one entry arrived from plumber as a bare JSON string (`auto_unbox`), and
  the panel's `.join` threw, blanking the whole tab. Both halves of that defect are
  reachable through normal use (for example: run the PSA, skip the value of
  information, then assess the HTA summary — `missing_inputs = "evpi"` and
  `not_assessable_domains = "Decision uncertainty"`), and both now render R's own
  wording. The API contract, R modules and the `HtaSummaryAvailability` type are
  unchanged; the normalisation is in the component.
- The PSA confirmation is presentation only: it gates the run button at 1,000
  draws, and the request, the draws and the iteration handling are unchanged.
- The Part 2 price curve's series colours, threshold line and marker are R's
  values, so they keep the reference figure's colours rather than following the
  chart palette; the axes, grid and text of that chart still follow the theme, so
  it stays readable in dark mode. The curve's legend also carries R's own label for
  the marker, drawn inside the plot, which at 390px can sit near the plot edge.
- The tutorial's two parts share one mode flag and nothing else. Part 2 keeps its
  own case, price and evaluation, so a Part 2 price lever cannot move a Part 1
  result and a Part 1 control cannot move a case; the parity check for Part 1
  (26 scenarios) and its browser suite (49 checks) are re-run after any Part 2
  change to keep that boundary honest.
- The tutorial is deliberately isolated from the analysis session rather than
  sharing it: it has its own values for everything it needs (including the two
  post-event utilities, 0.80 post-MI and 0.60 post-stroke, which are tutorial
  constants in `eqalb_tutorial.R`). The reference tutorial read those two values
  from the dashboard's utility inputs, so a client that edits the dashboard's
  utilities while a tutorial is open sees different numbers from the reference in
  that one respect — intentionally, because the reference behaviour let a tutorial
  result change without any tutorial control being touched.
- The Part 1 route is the one place where the two services expose a different
  path: plumber registers the handler as `POST /api/tutorial-part1` because it
  cannot hold a flat route and a nested route that share a prefix (defining
  `/api/tutorial/part1` alongside `/api/tutorial` makes plumber rebuild its route
  table and drop the sibling routes). The published path is
  `POST /api/tutorial/part1`, which FastAPI serves and maps to that handler, and
  both services run the identical `eqalb_tutorial_part1()` code. The browser
  interface always uses the FastAPI service.
- The tutorial's four-step response is re-requested on every control change
  (coalesced by a short debounce), as the reference tutorial's live reactive values
  were, rather than behind a run button. The endpoint is deterministic and costs a
  handful of model runs, so this is cheap, but a control change does make a
  request.
- The tutorial's charts are re-implementations of the reference figures from R's
  own data, labels and sentences, so cosmetic differences are expected; the axis
  padding is client-side chart geometry.
- Two short interface strings inside the tutorial are the client's rather than
  R's, because they describe the request rather than the tutorial's content:
  "Updating results…" and "Results updated." in the live region that reports a
  re-evaluation. Every value, status, interpretation, table row, chart label and
  teaching sentence is R's.
- The tutorial session lives in memory for the life of the page: leaving for Home
  or the full analysis keeps the learner's step and values, and only "Restart
  tutorial" or a page reload resets them. Nothing is persisted to browser storage.
- The API is unauthenticated and binds to the loopback interface only. It is a
  development and teaching service, not a deployed product, and nothing in it is
  hardened for a network.
- The Shiny app remains the reference implementation for both the DHT readiness
  and the HTA decision-summary views.
- The HTA Decision Summary tab has no analyses of its own: it sends what the other
  tabs have already produced, so until they have been run R reports the affected
  domains as not yet assessable, exactly as the Shiny tab does before those
  analyses are run. A run is a snapshot — results stay visible while inputs are
  edited, and only the button replaces them.
- The browser interface has no automated test suite. Verification is manual: the
  production build and type check pass, oxlint passes, and every tab (including
  the phase-2 readiness and HTA decision-summary tabs) is exercised against a
  running API and compared with the same values the R functions return.
- Charts are verified from the values ECharts has actually drawn, not only from
  the props they were given: the tornado's bars were once bound to a correct array
  and still rendered nothing, because ECharts 6 reads a two-element bar item as
  `[x, y]` coordinates rather than as a value range. A pixel-and-geometry check
  (`convertToPixel` against the drawn rectangles) is what catches that class of
  fault, and the tornado is now checked that way.
- The value of information tab's stale-result notice was implemented with the
  same request-snapshot pattern as the other tabs but could not be exercised in
  the polish batch, because a PSA is what produces a value-of-information result
  and that batch was not allowed to run one. Its source path and typing are the
  same as the eight tabs that were exercised.
- The browser tab strip labels one tab "Value-based Price" while its panel
  heading, R's own writing and every other tab label are sentence case. The tab
  strip is in `App.vue`, which was outside the polish batch's allowed files, so
  the label stands as it is and the heading was left aligned with R.
- The readiness tab shows the traffic-light rule wording and colour meanings
  copied from `app.R` (`DHT_THRESHOLD_NOTE`, `DHT_TRAFFIC_LEGEND`) in an
  on-demand disclosure, but not the numeric thresholds: those are not part of the
  API contract, so no numeric threshold is restated in the browser interface.
- Readiness explanations are limited to what R already contains. Only
  `review_minutes` has a definition string in `readiness_parameter_specs()`, and
  the only other readiness wording R holds is the tutorial's interoperability
  sentence, which Batch 4 published as the interoperability choice set's `info`
  field. There is therefore no algorithm-governance definition anywhere in the
  model or the Shiny app, and the browser tab shows none: its field hint simply
  says the levels describe how the model oversight is configured. Adding a real
  definition would mean authoring new clinical/regulatory wording, which is
  outside a presentation-only change.
- The survival tab's interpretation rules are not copied into the interface at
  all: they arrive from R with every response. One sentence is the exception —
  the descriptive log-rank line, which is composed in `api/plumber.R` because
  Shiny builds it inside a `renderText()` in `app.R`. It is copied word for word
  (with the p-value formatted by R's own `km_p_value()`), so a change to that
  sentence in `app.R` has to be mirrored in the endpoint.
- The browser interface opens on a Home screen; the model contract (`/api/health`,
  `/api/defaults`) is requested when the dashboard is first opened rather than on
  page load, so the Home screen itself makes no API call and no analysis runs
  without its own action button.
- The browser results package contains the numeric tables and text summaries the
  session has produced — one file set per analysis the session has run, including
  the value of information and the value-based price — but not the rendered chart
  images the Shiny package
  carries (`write_plot_png` in `app.R`). Reproducing those needs a new endpoint
  that renders a plot from results the client already holds; until then the ZIP
  states that difference in its README and on the Download results page.
- The browser per-tab exports cover three of Shiny's downloads. Still missing, and
  deliberately not faked: the simulated patient-level Kaplan-Meier dataset (Shiny
  writes it from `km_data()`, which no endpoint returns — a dataset endpoint is
  deferred), and every rendered chart (PNG/PDF) for the cost-effectiveness plane,
  tornado and Kaplan-Meier curve, which needs an R rendering endpoint. The
  survival tab states the dataset gap on the page, and the base-case export writes
  an empty cell where R could not compute a value (a non-estimable ICER), where
  Shiny writes `NA`.
- The base-case, PSA, OWSA, budget-impact and survival tabs rely on the existing
  snapshot convention rather than an input snapshot: their results stay as run and
  the run button replaces them, with the threshold-based staleness warnings
  unchanged. Extending the readiness/HTA-summary input-snapshot warning to those
  panels is a known follow-up, not a silent omission.
- Charts in the browser interface are re-implementations of the Shiny plots from
  the same underlying numbers, not the same R plotting code, so cosmetic
  differences (axis limits, label wording, colours within the shared palette) are
  expected.
- Value-of-information endpoints need the PSA draws in the request body, so they
  only work after a PSA has been run in the same browser session. That round trip
  is now exact for any value the API sent: the worker rebuilds the body with
  `digits = NA`, the setting its reply writer already used, so the draws a client
  holds come back to R unchanged. Before the fix the worker imposed jsonlite's
  default of four decimal places, which moved EVPI by about 0.3% at 1,000 draws
  (4.6942935 through FastAPI against 4.70724749145015 through plumber and
  4.70724749145016 in R) while the PSA's own numbers matched. A value needing more
  than 15 significant digits is still rounded, which is the precision both
  services transmit.
- Model requests are serialised through a small pool of R worker processes (two
  by default, each holding a loaded model), so concurrent analyses queue. The
  pool exists because R is single-threaded; a worker that dies with a request is
  replaced and the request is retried once.
- The plumber HTTP service (`api/run_api.R`) and the FastAPI service share port
  8788, so only one can run at a time. If the port is busy, `api/run_api.py` stops
  with an explanatory message instead of failing to bind.
- The browser bundle is a single chunk of about 760 kB (roughly 250 kB gzipped),
  mostly ECharts. It matters only if the interface is ever deployed rather than run
  locally.
- The `renv` library is out of sync with `renv.lock` in the working copy (renv
  reports it). This predates the browser stack and was left for a deliberate
  `renv::snapshot()` by the project owner.

## Current task

Completed: the final repository-release preparation pass, leaving one coherent,
uncommitted snapshot that serves both deployments. (1) `app.R` was reviewed and is
now staged, superseding the earlier note that left it unstaged. The review showed it
is an intended, complete Shiny-reference revision: the diff is 335 insertions and 925
deletions, and every one of the 14 definitions it removes (`HTA_SUMMARY_RULE_NOTE`,
`HTA_RULE_ITEMS`, `HTA_EVIDENCE_NOTE`, `HTA_RULES_TRIGGER_LABEL`, `CC_INFO_TEXT`,
`DHT_DISCLAIMER`, `DHT_ALGORITHM_APPROACHES`, `DHT_INTEROPERABILITY_LEVELS`,
`dht_format_rate`, `dht_format_count`, `calculate_readiness`,
`assess_km_interpretation`, `km_number`, `km_p_value`) is defined instead in
`eqalb_readiness.R`, `eqalb_km_interpretation.R` or `eqalb_ui_copy.R`, which the file
now sources, so the Shiny app and the browser stack share one implementation of that
wording and those helpers. (2) Python dependencies are reproducible:
`api/requirements.txt` pins the two direct dependencies exactly (`fastapi==0.143.0`,
`uvicorn==0.54.0`) and the new `api/requirements.lock.txt` records the whole resolved
closure (14 packages) for a byte-reproducible install. Nothing was committed; the
staged set is left for review.

Completed: the Part 2 Recommendation retry-availability correction, pending visual
review. "Retry Part 2 with different assumptions" was reachable only through the
conditional completion card, so on a Recommendation screen whose R outcome was not
`complete` (for example a case that cannot pass value for money at any price in the
lever range) a learner who had finished all three exercises had no retry action at
all. `Part2Recommendation.vue` now renders the same button in a `v-else` retry row
under the engagement note whenever the completion card is not shown; both buttons
emit the one existing `retry` event, so `retryPart2()` — new draw excluding the
current case, readiness answers and section reset, completions cleared — is
unchanged, and the completion card, the popup, its gating and its actions are
untouched. Frontend only: no R module, API contract, type or client change, and no
notice added.

Completed: the final full-journey validation pass, with one minimal fix. The pass
covered the welcome overlay, Part 1, Part 2 (entry, exercises, completion popup,
Retry, state reset), the nine dashboard tabs, the assumptions panel and the
cross-cutting concerns (desktop, 390 px, light, dark, keyboard, Escape and
outside-click dismissal, reduced motion, loading states, console and page errors).
No model logic, API contract, R module or result behaviour was touched, and no
notice was reintroduced.

One concrete defect was found and fixed minimally: `HtaSummaryPanel.vue` called
`.join` on `availability.missing_inputs` and `availability.not_assessable_domains`,
which plumber serialises as a bare JSON string when the list holds exactly one
entry (`auto_unbox`) — so the whole HTA Decision Summary tab failed to render
(`TypeError: $setup.missingInputs.join is not a function`, blank panel) whenever a
session had exactly one missing request field or one not-assessable domain. That is
the normal state after running the PSA and skipping the value of information
(`missing_inputs = "evpi"`, `not_assessable_domains = "Decision uncertainty"`). A
small `asList()` helper at the component boundary now normalises both shapes to a
list; the rendered text is R's, unchanged, and the API/R/type layers are untouched.
Re-verified afterwards: the one-field state, the one-domain state, the
two-missing-fields state and the fully-supplied state all render R's wording and
raise no page error. Recorded under Known limitations and in the update log.

Observations, not defects and not changed: (1) the Part 2 completion popup is
once per browser session and is reported on the Recommendation screen, while the
completion card that carries "Retry Part 2 with different assumptions" appears only
when R's own `recommendation.complete` is true — so a learner who leaves a case
short of R's criteria (for example Case C, whose value for money cannot be met at
any price in the lever range) sees no Retry until the criteria are met; this is
R's existing completion design and is outside a presentation pass. (2) Case C
(Fragmented deployment) is designed so value for money fails at every price in the
30-360 range, so it cannot reach R's complete outcome; that is R's case design, not
a UI defect.

### Earlier task

Completed: three assumption-group information buttons (presentation only, pending
visual review). The Assumptions panel's "Event costs", "Discounting" and "Time
horizon" group headings each carry an `InfoTip` immediately to the right of the
heading text, inside the group's `<summary>`, with the requested plain-language
copy — each sentence says what the assumption means and why it matters, and none
states a value, range or model rule. The three headings are the groups
`/api/defaults` returns (verified from the contract: `Event costs`,
`Discounting`, `Time horizon`), and R's `CC_INFO_TEXT` has no wording for group
headings — it defines individual parameters — so these three sentences are
interface copy, recorded with the readiness tab's algorithm-governance sentence
under Known limitations rather than presented as R's text. No assumption value,
calculation, API call, model logic, request body or result behaviour changed;
`eqalb_tutorial.R`, `api/main.py`, `api/plumber.R`, the API types and the API
client were not touched, and no notice was added or reintroduced. One rendered
consequence worth noting: the `InfoTip` lives inside the group's `<summary>`, so
it was verified that activating it does not toggle the disclosure (the summary's
own activation behaviour does not run for a nested button), that the heading
itself still toggles the group, and that Escape closes the popover while leaving
the group open.

Files changed: `frontend/src/components/AssumptionsForm.vue` (the `GROUP_INFO`
map, a `groupInfo()` lookup and the button in the summary) and
`frontend/README.md` (the "Explanations are R's text" section now names three
interface-copy subjects), plus this state file.

### Earlier task

Completed: the base-app UI-polish pass (presentation only, pending visual
acceptance). No model, calculation, API contract, R logic, recommendation logic or
result behaviour changed; `eqalb_tutorial.R`, `api/main.py`, `api/plumber.R`, the
API types and the API client were not touched, and no tutorial behaviour,
completion logic, welcome overlay or Part 2 gating was altered.

Loading-screen ECG: the card's pulse used a dash pattern exactly as long as the
line (22 + 78 = 100), so the dash could never be off the path — it swept to the end
and then waited *visible* at the start of the trace, which read as stopping
part-way. The pattern is now twice the line (22 + 178) and the sweep runs 22 → −100
over the first 55% of the 2.8 s cycle and holds just past the last point for the
rest, so the pulse enters from the left, crosses the whole line and rests off the
path; every loop restarts from an invisible dash. The card is still the only loader
and still covers every long operation (the dashboard service load, the nine analysis
runs, Part 2's contract load, case draw and evaluation); the
`prefers-reduced-motion` still states are unchanged.

Project description: the view is centred (`.page--centered`) — heading, prose and
subtitles — with the analyses list left-aligned inside a centred 42 rem column and
the actions row centred.

PSA confirmation: a run at 1,000 draws or more is confirmed before it is sent, with
the requested wording ("Running 1,000 or more iterations may take a few minutes. If
you want a quick PSA, change the number of iterations to 100."), Continue (runs the
PSA) and Cancel (closes the prompt and leaves the iteration field as it is, so the
count can be adjusted). It reuses the app's modal pattern — Escape and the backdrop
cancel, Continue takes focus — and only gates the button: the iteration count, the
request, the draws and the iteration handling are unchanged.

Cost-effectiveness plane legend: the ECharts legend names up to five series and
wraps to several rows at narrow widths; it now has a reserved band of its own (grid
top 104 px, legend text 11 px, item gap 10) so it cannot reach the plot at any
width, and the plot's axes stay readable.

Chart subtext to header information buttons: the muted explanatory lines beneath
the charts in the base case, PSA, simulated survival, value of information and
value-based price tabs moved verbatim into an `InfoTip` beside the chart header
(the `figcaption`), and the chart components no longer render them. Nothing
substantive was dropped — the base-case ICER annotation and decision label, the
plane's threshold note, the CEAC readout, the survival confidence-band note, the
EVPI readout, the EVPPI method caveat and R's headroom sentence all live in the
button, and every number involved is still on a metric card. The CEAC's threshold
probability is now read through one shared function
(`components/charts/ceac.ts`, `probabilityAtThreshold`) by both the chart's marker
and the panel's button, so the two cannot disagree.

Sensitivity analysis: the ranked-outcome selector carries an information button
immediately to its right — "Choose which result is ranked to show which assumptions
have the greatest effect on that outcome."

Information-button placement: the field label is an inline block, so an `InfoTip`
that follows a label sits on the label's own line to its right instead of on a line
below it (`.field > span:not(.infotip)` keeps the old block treatment for anything
else), and the trigger keeps its lowercase "i" inside uppercased headings and metric
labels. Applied to the assumptions form (all ten buttons), the budget-impact
controls, the readiness inputs, the sensitivity selector and — because it is one
shared rule — the tutorial's Part 2 fields. No information content changed.

Algorithm governance: the readiness tab's "Algorithm governance" heading carries an
information button written for the interface, describing how the algorithm's
approach to change is controlled, documented, reviewed and re-validated, because R
publishes no wording for that choice set.

Notice removal: the last `result.notice` lines (base case, PSA, budget impact,
sensitivity analysis, readiness, value of information, HTA summary) and the
survival tab's appended disclaimer are gone, along with the `.notice` rule; the
survival log-rank line is cut at the response's own `notice` string so no wording is
written in TypeScript. R's substantive wording is untouched.

### Earlier task

Completed: the Part 2 narrative and polish pass. Copy and presentation only — no
model, calculation, API contract, case-selection, readiness, recommendation,
navigation or result behaviour was changed, and no R, API, TypeScript-contract or
Part 1 file was touched.

Case Brief (`Part2Brief.vue`): the section now leads with its task, "What funding
position will you recommend?", and the manufacturer's price is framed as a
starting proposal for negotiation — "The manufacturer has proposed a starting
price of €360 per active user per year … Your task is to negotiate a price that the
health service could responsibly fund." The sentence that called €150 the lowest
price the manufacturer would accept is gone; €150 now appears only where it
already belonged to R, as the facts-table row R labels "Manufacturer's minimum
acceptable price". R's per-case `case.summary` is no longer rendered, because two
of R's three summaries end by saying how many prices or how much coverage pass;
Vue's own neutral case-difference line replaces it (keyed by R's own case title,
with a fallback that describes nothing, so a future R case cannot leak an outcome).
The rest of the brief — the payer criteria with their plain-language glosses, the
two levers, the glossary hint and R's fact table — is unchanged, and the facts
table is byte-identical to R's payload.

Task leads: DHT readiness now leads with "Choose the implementation approach you
would recommend, then consider its delivery consequences." and Recommendation with
"Bring the evidence together and recommend a funding position." Value for Money and
Budget Impact already lead with R's own task sentences, so no task was duplicated in
Vue; the four remaining section leads and the brief's are presentation copy.

Polishing: `.part2__task` moved from the orange/red treatment (`rgba(217, 72, 15,
0.1)` background, `#d9480f` border) to the app's teal informational tokens
(`--accent-soft` background, `--accent` border, `--text` colour), which flip
correctly in dark mode; red and amber stay reserved for real failures and warnings.
`Part2View.vue` changed by one prop binding only (the brief's `:summary` became
`:case-title`).

Validation on the production build with the API proxied: build and lint pass. The
brief's narrative carries no "minimum acceptable", "lowest price it will accept",
"value-for-money test", "wider range of prices", "fits the budget" or "less
coverage"; "minimum acceptable" occurs exactly once, in R's own facts-table row.
All three cases' neutral lines were checked against their titles and none carries a
forbidden phrase. Every rendered fact row equals R's payload, as do the price state,
detail, maximum and answer line, the coverage control, maximum affordable coverage,
budget state, all five budget rows, the seven readiness domains, the recommendation
status, headline and message, and the four checklist verdicts. Task leads were
confirmed on Case Brief, Value for Money, Budget Impact, DHT Readiness and
Recommendation. `.part2__task` computed styles are teal in light
(rgb(234, 241, 243) / rgb(23, 107, 115)) and dark (rgb(30, 48, 57) /
rgb(127, 209, 216)). At 390 px there is no horizontal overflow (scrollWidth 390) on
the brief or the value section. Retry, exercised from a conditional-adoption state,
drew a different case (Case B to Case C), returned to the Case brief and restored
R's own defaults (price €360, coverage 100%, the four readiness answers). No console
or page errors. No PSA was run.

Two R-owned strings still call €150 a minimum acceptable price — the facts-table row
label and the Case-facts overlay hint — and both are outside the editable scope of
this task (`eqalb_tutorial.R`); they are recorded under Known limitations as
candidates for a future R-side wording pass.

### Earlier task

Completed: the restrained, thematic loading experience for the Vue app. UI only —
no model calculation, API contract, tutorial logic, case selection, readiness
logic, recommendation logic, navigation behaviour or existing result was changed.

Two new frontend files. `useAppBusy.ts` holds one ref-counted busy state with a
label, exposed as `start(label)`, `finish()`, `isActive` and `label`; while
operations nest the first operation's label is kept, so Part 2's case draw keeps
R's `entry_busy_label` and not the inner evaluation's sentence.
`AppLoadingIndicator.vue` is the only loader: it waits 350 ms before showing a
thin teal bar at the top of the app and 2.5 s before adding a small centred card
carrying the eQalb wordmark, a low-opacity ECG line in the app's own teal (the
home title's trace morphology, one dash in a 2.8 s cycle) and the operation's
status sentence; both levels are removed in the same tick the last operation
settles. It is mounted once in `App.vue`, so every page is covered, and it is
wired only where a wait is real: `useModel`'s service load and its nine explicit
analysis runs, and `useTutorialSession`'s Part 2 contract load, case draw and
evaluation. Short requests are deliberately not wired — a dashboard open
(≈0.15 s), a base case (≈0.23 s), a Part 2 evaluation (≈0.32 s) and the Part 1
evaluations (≈0.34 s) all finish inside the grace period and show nothing. The
card is not a modal: no backdrop, nothing focusable, `pointer-events: none`, so
focus order, Escape, disclosures and navigation are untouched, and
`prefers-reduced-motion` turns the bar into a still full-width line and draws the
ECG trace complete. No new endpoint, dependency, design system or theme engine.

Validation: `npm run build` (vue-tsc + vite) and `npm run lint` pass. Measured on
the production build served with the API proxied: the dashboard open and a base
case showed no loader; OWSA showed the bar at 441 ms and the card at 2.6 s, with
the card reading "Running the sensitivity analysis…", and cleared both at
6.98 s; a Part 2 case draw showed "Preparing the case…" from 2.5 s and cleared
promptly after the case arrived, with the card 304 px wide and centred; at 390 px
the card stayed fully inside the viewport with `scrollWidth` 390; under reduced
motion the bar segment and the trace pulse computed `animation: none` with the
dash removed; an InfoTip opened and closed with Escape while the card was up, Tab
order kept moving, the loader held no focusable element, and no console or page
errors appeared. Part 1's four steps, Part 2's five sections and the dashboard
tabs were exercised during the same runs. No PSA was run.

Follow-up in the same task, a robustness correction to the busy state only (no
visual, threshold, animation, API, tutorial, model or navigation change):
`start(label)` now returns that operation's own completion token, which settles
exactly once and is idempotent, and all five call sites hold the token and call it
in their existing `finally`, so a rejection, a cancel or a component unmount
cannot skip the clear. Each token also carries one one-hour watchdog — twice the
slowest run the interface can request (a 10,000-draw PSA, about 30 minutes at the
measured 0.18 s per iteration) and four times the API R worker's default 900 s
timeout — which clears a completion that never arrives and warns only under
`import.meta.env.DEV`.

Robustness validation: `npm run build` and `npm run lint` pass; the production
bundle contains the watchdog (60 minutes, `36e5`) and not the warning string, so
the warning is development-only. A rejected operation (the request aborted after
900 ms) showed the bar at 401 ms, cleared it at 941 ms, kept the existing
"model service is not reachable" message, left the button usable, and the next
run still showed the bar and card and cleared on completion. An operation whose
completion never arrives was recovered by the watchdog at the clamped 3 s mark
(bar 401 ms, card 2541 ms, cleared 3041 ms) with the warning
`[eQalb] "Running the sensitivity analysis…" was still busy after 60 minutes and
has been cleared.` in development and no warning at all on the production build.
Two unmount checks: leaving the dashboard during a run and leaving the tutorial
during a Part 2 case draw both cleared the loader when the operation settled, with
no page errors. The full visual pass was re-run afterwards and every figure above
still holds, with no console errors.

### Earlier task

Completed: Guided Tutorial Part 2. All five sections are implemented in the
browser stack, and a final cleanup corrected the shared money formatter and
removed a stale contract block.

R: `eqalb_tutorial.R` gained the DHT-readiness exercise — the two readiness level
tables, the workflow-minute and engagement-percentage tables, `eqalb_part2_readiness_choice()`
(an omitted answer takes R's default; an answer outside the accepted ids is R's
error) and `eqalb_part2_readiness()`, which maps the four answers onto the inputs
`calculate_readiness()` already takes and returns the answers used, the mapped
inputs, each domain's status, the five reach and workload figures, the
deliverability verdict and its label, and R's two calculation-dependent sentences.
Part 2 is isolated from the dashboard here too: digital access, suitability and
accessibility are the tutorial's fixed 85 / 75 / TRUE values, the case supplies the
population, year-1 engagement and languages, and `moderate` workflow means the
case's own review minutes. It also gained the recommendation — `eqalb_part2_recommendation()`
chooses one of five outcomes from the three criteria and the coverage cap in the
reference tutorial's own order and wording, and `complete` is true only for
`conditional_adoption`, so the client infers neither the outcome nor completion.
The five sections are all marked available, the contract note no longer says
otherwise, and the stale `later_sections` block is gone.

API: `GET /api/tutorial/part2` publishes all five sections as available.
`POST /api/tutorial/part2/evaluate` accepts the four readiness answers with the
price and the coverage cap, validates each in R, and returns, additively, a
`readiness` block and a `recommendation` block. No new endpoint, request field or
change to any existing field's value; `api/main.py` gained the four optional
choice fields, and `api/plumber.R` needed no change because its handler already
forwards the whole body.

Vue: `useTutorialSession` gained the four readiness answers with Vue-owned
defaults, sent in the same coalesced evaluation the levers use; new
`Part2Readiness.vue` renders the four radio questions, R's reach and workload line
and one closed disclosure, and deliberately shows no traffic light; new
`Part2Recommendation.vue` renders R's outcome card, R's own case-settings
sentence, the four-criterion checklist, the seven readiness domain cards, the
Deliverability card, R's engagement restatement, and a completion card with an
"Open full analysis" action when R completes the case. `Part2View` wires both
sections.

Cleanup: `eqalb_tutorial_money()` now formats with `scientific = FALSE`, so the
€100,000 threshold and the €3,000,000 ceiling no longer render as "€1e+05" and
"€3e+06" in the contract, the case facts table or the budget blocks — a
before/after fixture diff of the Part 1 and Part 2 responses shows 13 changed
strings, all of them those two numbers, and nothing else; the stale
`later_sections` block and its TypeScript field are removed.

Validation: the readiness block was checked against R for the defaults, one answer
changed per question and all four omitted, with R's own error for an invalid id;
the five recommendation outcomes were checked per case against R, headline and
message verbatim, with the four criteria each outcome was chosen from and the
outcome's `complete` flag; the price, curve, maximum and budget fields are
unchanged beside both additions, and the recorded Slice 1 and 2 pins still hold
(€155 / €295 / €170, 2 / 30 / 5 passing points, 15 / 15 / 10 % best coverage,
€15,480,000 / €17,280,000 / €20,720,000). In the browser, 44 checks passed for the
readiness section (later corrected so the section shows no traffic light, verified
by a further 22 focused checks) and 46 for the recommendation, including all five
outcomes reached through the interface, the completion card appearing only for the
conditional-adoption outcome, keyboard radio groups and navigation, Escape and
focus return, 390px without page-level overflow, and no console errors. A final
smoke run confirmed the checklist labels, the readiness section's freedom from
traffic lights, and that Value for Money, Budget Impact, the dashboard and Part 1
still load. `npm run build` and `npm run lint` pass. No PSA was run. The only
unimplemented Part 2 behaviour is the user-visible retry flow.

### Earlier task

Completed: Guided Tutorial Part 2 slice 2 (the R-owned Budget impact section: the
coverage cap, the covered population, the five-year annual rows and chart, the
affordability states and the maximum affordable coverage).

R: `eqalb_tutorial.R` gained the Part 2 budget section — its own constants for the
uptake schedule (10% in year 1, rising 5 percentage points a year), the five-year
horizon, zero avoided-event savings, the €3,000,000 five-year ceiling and the
coverage cap (10–100% in steps of 5, default 100%); the covered-population and
coverage-step helpers; the annual-rows builder, whose every row carries the stable
`year-N` key the chart and the table map on; the affordability test; the maximum
affordable coverage, found by evaluating the permitted coverage steps from the
highest down rather than by inverting the budget formula; the budget wording; and
the contract's budget block. The section is R-owned and isolated: it calls
`calculate_budget_impact()` unchanged with the case's own population, follow-up
engagement and negotiated price plus the tutorial's fixed values, and the coverage
cap scales the case's covered population only, so it cannot move the per-person
value-for-money result.

API: `GET /api/tutorial/part2` now enables the Budget impact section (DHT readiness
and Recommendation are still declared unavailable) and publishes the section's
headings, the coverage control's metadata, explanation and default, and the
budget-impact wording (task, note, scope note, lever, population and coverage
labels, the affordability states' messages and hints, and the annual table and
disclosure labels). `POST /api/tutorial/part2/evaluate` accepts the coverage cap
with the price, validates it in R (R's own message for a non-numeric or
out-of-range cap, and R's default when it is omitted) and returns, alongside the
unchanged Slice 1 outputs, the coverage actually used, the potentially eligible and
covered populations, every annual row with its formatted strings, the chart series,
the five-year total with its horizon wording, the affordability state with its
message and hint, the maximum affordable coverage for the current case and price
with its display string, the current-settings line, the price-return shortcut's
condition, and the annual-breakdown disclosure's title and wording.

Vue: the isolated `useTutorialSession` gained the coverage state, seeded from R's
returned control default and sent with the price in the same coalesced evaluation;
new `Part2Budget.vue` and `Part2BudgetChart.vue` render the section (the R-owned
task and scope notes, the potentially eligible population, the coverage control
carrying R's range, step and InfoTip, the affordability status card, the maximum
affordable coverage, R's summary, the per-year chart and one closed
annual-breakdown disclosure), and `Part2View` enables the third section, keeps DHT
readiness and Recommendation as disabled "Coming next" entries, and wires Back/Next
and the R-owned price shortcut. Case Brief and Value for Money are unchanged, and
nothing was added to `useModel`.

Validation: the Part 2 fixture captured outside the repository gained the budget
block and the coverage scenarios — the default, the minimum, the maximum, the
maximum affordable coverage and one permitted step above it, plus a
value-for-money-failing price — and the parity run (11 steps) matched the live API
with **zero mismatches**, with all three reachable affordability states (over
budget, below the maximum, at the maximum) observed. The run pins Slice 1
byte-for-byte, so a coverage change never moves the price curve, the current-price
status or the highest acceptable price, and it re-confirms that a body carrying
dashboard-style fields changes nothing. In the browser, 71 checks passed (run
twice): the section enabling with the two remaining "Coming next" entries, the
control's R range and default, the status card for each reachable state, R's
maximum affordable coverage, the chart read from the canvas bitmap rather than from
the props, the sampled tooltips matched to R's annual rows by R's own year key, the
annual disclosure opening by mouse/Enter/Space and closing with Escape back to its
summary, local table scrolling at 390px with no page-level overflow, dark mode,
reduced motion, and Part 1 and dashboard isolation. Slice 1's 56 browser checks and
Part 1's 26-scenario parity fixture and 49 browser checks were re-run and are
unchanged. `npm run build` and `npm run lint` pass. No PSA was run, and Part 2's
DHT readiness and Recommendation sections, its completion card and its retry flow
are not implemented.

### Earlier task

Completed: Guided Tutorial Part 2 slice 1 (the R-owned Part 2 contract, case
creation/resume and the Case brief and Value for money sections).

R: `eqalb_tutorial.R` gained the Part 2 section — the tutorial's constants for the
lever (€150–360, step 5, default €360) and the coverage cap it will need, the
three commissioning cases with their own facts (the post-event utilities are the
case's values, not dashboard settings), the 14-row facts table, the
value-for-money rule, the 43-point price curve with R's per-point classification
and the highest acceptable price, the current-price result with its three states,
the static wording and the contract. It reuses `run_eqalb_model()` and
re-implements nothing.

API: `GET /api/tutorial/part2` publishes the contract (five sections with only
Case brief and Value for money available, the instructional copy, the price
control's metadata and explanation, the case-facts headings and overlay labels,
the fixed criteria, the later sections' fixed inputs and the chart's labels,
series colours, threshold line and marker). `POST /api/tutorial/part2/case`
creates a case or resumes the one a client already holds, returning the opaque
handle, the case's label/title/heading/banner, its facts, the brief's
introduction and the case's full curve. `POST /api/tutorial/part2/evaluate`
returns the current-price result, the highest acceptable price, the marker and the
curve for one case and one price, on either the computed path or a posted-curve
path that lets R re-classify a curve instead of re-running it. All three are
mirrored through FastAPI with typed request models.

Vue: `useTutorialSession` gained the Part 2 mode and state (contract, opaque
handle, case, price, evaluation, section) with a single-request guard on case
creation; `Part2View`, `Part2Brief`, `Part2Value` and `Part2PriceCurve` render the
shell, the facts overlay, the brief and the value-for-money exercise, and the
Part 1 completion card gained the Part 2 entry, whose label and sentence come from
the Part 2 contract so Part 1's own response is unchanged.

Validation: an R fixture captured outside the repository (the contract, seeded and
resumed draws for all three cases, each case's facts and later inputs, each case's
full 43-point curve, and 12 case/price scenarios covering the lever minimum,
default, threshold crossing, highest acceptable price and one step above it)
matched the live API with **zero mismatches**; the posted-curve path matched the
computed path in all 12 scenarios; a seeded draw is reproducible; a retry never
returns the excluded case; a curve bound to another case is rejected; R's own
messages are returned for an unknown handle and an out-of-range price; and a body
carrying dashboard-style fields changed nothing. Two defects were found and fixed
by that validation: a part's own mount and the entry both requested a case
(now one request, since two draws raced), and a posted curve was not bound to its
case (now rejected unless its `case_id` matches, because the lever's 43 prices are
identical for every case and an unbound curve would have returned one case's
numbers under another's name). In the browser, 54 checks passed: the Part 2 entry,
R's banner, all fourteen facts matching R row for row, the facts overlay opening
by keyboard and closing with Escape back to its trigger, the two available
sections and three disabled "Coming next" entries, keyboard step switching with
focus on the new heading, the price lever carrying R's range and default, the
state card updating to R's wording and ICER for the new price, R's highest
acceptable price on the page, the drawn curve (R's two series colours, the marker
as a vertical line, the threshold as a horizontal line, read from the canvas
bitmap rather than from the props), sampled tooltips matching R's row for the
price they name, navigation, Part 1 and dashboard isolation, 390/768/desktop with
no page-level overflow, dark mode and reduced motion. Part 1 was re-checked
afterwards and is unchanged: its 26-scenario parity fixture and all 49 of its
browser checks still pass. `npm run build` and `npm run lint` pass. No PSA was
run, and Part 2's budget-impact, readiness and recommendation sections, its
completion card and its retry flow are not implemented.

### Earlier task

Completed: Guided Tutorial Part 1 in the browser stack. `eqalb_tutorial.R` holds
the tutorial's own defaults, control metadata, fixed values (including the
post-event utilities), simplified traffic-light rules, teaching copy and
decision-summary assembly; `GET /api/tutorial` and `POST /api/tutorial/part1`
publish the contract and the whole four-step result set; and the Vue side has an
isolated `useTutorialSession`, a `TutorialView`, a `components/tutorial/` set and
a Home entry point. Verified against a 26-scenario R fixture with zero
mismatches, plus 49 browser checks covering keyboard navigation, disclosures,
focus, restart, isolation, responsive layout, dark mode, reduced motion and all
nine dashboard tabs.

Completed: the approved OWSA range-policy redesign (R model module, Shiny, API
contract and browser stack together). The ranges are no longer fixed literals:
`eqalb_owsa.R` owns one canonical policy that derives each parameter's low and high
value from the value it has in the scenario being analysed, `POST /api/owsa` and
the new `POST /api/owsa-defaults` apply it, `GET /api/defaults` publishes it, Shiny
builds and updates its sidebar ranges from it, and the browser's OWSA editor shows
R's derived ranges with R's rationale, R's domain and R's own `Model default` /
`Adjusted` state. The one-way analysis is now marked as computed from earlier
inputs when the *assumptions*, threshold or ranges change, not only the threshold.
`eqalb_price.R` and the standalone analysis block in `eqalb_markov.R` read the same
definition through `eqalb_owsa_parameters()`, so the previously duplicated range
tables are gone. No PSA was run.

### Earlier task

Completed: Batch 3 of the approved UX revamp (one-way sensitivity analysis,
budget impact and value of information), frontend only
(`frontend/src/components/SensitivityPanel.vue`, `BudgetImpactPanel.vue`,
`ValueOfInformationPanel.vue`, `frontend/src/components/charts/VoiEvpiChart.vue`
(new), `frontend/src/components/charts/EvppiChart.vue` (new) and
`frontend/src/styles.css`). No R model logic, threshold, distribution,
calculation, endpoint, Shiny file, tutorial or export changed, and the only PSA
run was the authorised 100-draw validation at seed 12345.

**OWSA:** R's own narrative and its note moved from a default-visible block into a
closed `<details>` titled "How to interpret this result", where the same two API
strings (R's `summary_note` and `summary`, or `owsa_prerun_note` before a run) are
still rendered verbatim — nothing was deleted, reworded or moved out of R. The
frontend hint that used to say "the narrative above" now names the disclosure.
The tornado, the ranked table, the range editor, the CSV export, the metrics, the
stale/ranked-outcome warnings and the action gating are unchanged.

**Budget impact:** the wrapped inline control row — which at 390px put the
"Clinical target population" information control beside the Year-1 uptake field —
is replaced by a stacked form used only by this panel (`.controls--stacked`),
built from the assumptions panel's own field parts (`label[for]`, InfoTip,
`.field__control`, `.field__hint`): one control per row, its label and its
information control on the label line, the input and its unit below, and the
"Shared with DHT readiness." and avoided-event notes under the control they
belong to. The footer sentences about follow-up engagement and avoided-event
savings were removed; the avoided-event control gained exactly the approved
factual hint and no InfoTip, because R/Shiny publishes no wording for it. Input
bindings, defaults, the shared population, calculations, table, chart and gating
are unchanged.

**Value of information:** EVPI's InfoTip stays where it was (in the metric card's
label); EVPPI's moved into the caption of the table it explains, and the table
keeps its accessible name. The frontend approximation paragraph was removed from
the open panel. A closed "View visual summary" disclosure now holds two charts
built only from returned values: `VoiEvpiChart.vue` draws R's
`expected_nmb_current` and `expected_nmb_perfect` as two bars with R's `evpi` as
the labelled gap, and `EvppiChart.vue` draws R's EVPPI table in the response's own
order (R ranks it) with a dashed line at R's EVPI and the clamped qualifier in the
tooltip. The approximation sentence now sits under the EVPPI chart inside that
disclosure only.

Verification (live at 127.0.0.1:5173 against the running API): OWSA ran once and
the disclosure's text matched R's `summary_note` and `summary` (and, before a run,
`owsa_prerun_note`) after whitespace normalisation, started closed and opened by
click, Enter and Space; the reworded clarification appeared for an ICER ranking.
Budget impact ran once with cards equal to `/api/budget-impact` (€15,480,000 /
€15,120,000 / €1,200,000 / €840,000), five table rows and the chart unchanged; the
stacked layout measured one control per row at 1280, 768 and 390px with each
information control on its own label line, and no page overflow at any width.
One PSA ran at `n_sim = 100`, `seed = 12345`, reproducing the Batch 2 values
(€2,418 / 0.0078 / median ICER €333,633 / 1.0%), and the VOI panel then showed
EVPI €0.11 with the EVPPI table; the EVPI chart's bars read R's
`expected_nmb_current` 0 and `expected_nmb_perfect` 0.110098443012998 (equal to
the EVPPI chart's reference line and to the €0.11 card), the EVPPI bars sat in
R's returned order, the disclosure started closed and opened by mouse and
keyboard, the caveat appeared only inside it, and the EVPPI InfoTip was reachable
by keyboard from the caption and closed with Escape returning focus. All nine
tabs rendered, Home, Project description, Download results and the theme control
worked, light and dark re-rendered both new charts from their tokens, 390px had
no page-level overflow with the EVPPI table scrolling locally, and no console
error appeared. `npm run build` (vue-tsc + vite) and `npm run lint` pass.

Completed: the deterministic base-case plane was made clearer, frontend only
(`frontend/src/components/charts/BaseCasePlane.vue`). The shaded cost-effective
half-plane and its legend entry are gone; the plane keeps the usual-care origin
marker, the eQalb point, the arrow, the zero-crossing guides, the dashed
willingness-to-pay ray and the ICER/status note unchanged, and now carries the
threshold directly on the ray ("€100,000/QALY threshold", built from the same
`result.wtp` the metric card shows) plus one plain-language caption beneath the
chart that is extended with "The current eQalb result lies above the line." only
when R reported the result as not cost-effective. No calculation, threshold,
distribution, endpoint, export or other panel was touched, and no PSA was run.

Verification (live at 127.0.0.1:5173, base case only): the chart has no
`areaStyle` on any series and greenish pixels fell from about 16,700 (the wash) to
349 (the dashed ray alone); the legend lists only "Usual care" and "eQalb + usual
care"; the ray label reads "€100,000/QALY threshold" at the default threshold and
"€500,000/QALY threshold" after the reference threshold was changed and the base
case re-run, matching the metric card in both cases; the caption read "Points below
the threshold line are cost-effective at the selected threshold. The current eQalb
result lies above the line." while the result was not cost-effective (default and
the rrr = 0 dominated path) and the first sentence alone at €500,000/QALY, where R
reports the result as cost-effective; the origin marker, eQalb point, 86%-stopped
arrow and both zero guides were unchanged, and the tooltip over the eQalb point
still read "eQalb + usual care / Incremental QALYs: 0.0082 / Incremental cost:
€2,439 / ICER €298,966 per QALY · Not cost-effective at €100,000/QALY"; the ray
label rendered as a 113x7 px text block centred on its anchor and inside the
canvas in both themes and at 390px; a fresh load at 390px gave `scrollWidth` =
`clientWidth` = 375 with the chart 265px wide; and `npm run build` (vue-tsc +
vite) and `npm run lint` pass. One observation left as it is: with a chart tooltip
open, narrowing the window leaves ECharts' unconfined tooltip node extending the
document until it hides (measured 693 vs 375 in that state only) — that is the
library's default tooltip placement, shared by all five charts and untouched by
this change; `confine: true` in the shared chart config would remove it.

Completed: Batch 2 of the approved UX revamp (base case and PSA), frontend only
(`frontend/src/components/AssumptionsForm.vue`, `BaseCasePanel.vue`,
`CostEffectivenessPanel.vue`, `charts/BaseCasePlane.vue` (new),
`charts/CostEffectivenessPlane.vue`, `charts/CeacChart.vue`,
`frontend/src/views/DownloadResultsView.vue` and `frontend/src/styles.css`). No R
model logic, threshold, distribution, calculation, endpoint, Shiny file, tutorial
or export changed, Vue stayed presentation-only, and no 1,000-draw PSA was run.

**Model-structure wording is gone from the dashboard.** The assumptions sidebar's
`assumptions__meta` line ("German payer, 2025 euros, per person · 10 annual cycles
· states NoEvent, PostMI, PostStroke, Death") and the base-case header's
"Deterministic Markov run over … annual cycles, two strategies, …" sentence were
removed, and the now-unused `.assumptions__meta` rule was deleted. Nothing was
relocated to another view, and the API still publishes `model` — only its
rendering stopped.

**The decompositions are on demand.** Both base-case tables moved into closed
`<details>` disclosures immediately below the metric cards ("How incremental cost
is composed", "How incremental QALYs are composed"). Inside each: the same table
(six cost rows, three QALY rows, same labels, alignment, negative-value tone), its
reconciliation total, and its explanatory note, including the no-event sentence in
the cost disclosure. The visible `<figcaption>` gave way to the `label` prop, so
each table keeps an accessible name without repeating the summary, and the tables
still scroll inside `.table-scroll` at 390px. `baseCaseCsv()` and the results
package read only the response, so no export changed.

**The base case has its own deterministic plane** (`charts/BaseCasePlane.vue`,
frontend-only). From the response alone: usual care at the origin, a zero-crossing
guide pair, the willingness-to-pay ray from `result.wtp` with its own direct label
("€100,000/QALY threshold", built from the response), a segment with an open arrow
head to the eQalb point, a note that repeats the metric card's own wording through
the same `describeIcer`/`costEffectivenessLabel` helpers, and a one-line caption
that says what the two sides of the ray mean — followed by "The current eQalb
result lies above the line." exactly when R reported the result as not
cost-effective. The arrow stops at 86% of the distance to the marker so its head
stays visible beside the point. A non-estimable ICER draws no ratio: the note reads
the helper's wording ("Dominated (costs more, no extra QALYs)") exactly as the
metric card does. No economic value is derived in TypeScript — only axis padding,
the clipped ray and the label anchor, which is chart geometry.

**PSA clutter removed, PSA charts extended.** Gone: the header's model-structure
sentence, "Simulating N iterations in R", the "Simulated output is reproducible…"
sentence that duplicated R's `random_seed` InfoTip, the 15-minute/1,000-draw/value-
of-information hint, the iterations-range caption the input already enforces via
`min`/`max`/`step`, and the whole run-timing estimate (`lastRun`,
`ratePerIteration`, `coarseDuration`, `durationEstimate` and the `run()` wrapper).
Kept: R's `notice`, R's InfoTip text, the result-specific plane/CEAC notes, the
stale-threshold and failed-iteration warnings, the disabled-while-busy button, and
one concise busy line ("A 1,000-draw PSA takes minutes; keep this tab open until it
finishes."). Added: a mean-of-iterations marker on the PSA plane (a hollow accent
diamond, `z` above the deterministic marker, so it stays legible where the two
coincide), zero-crossing guides on that plane, and a dot plus label at the
reference threshold on the acceptability curve. The deterministic marker in the
PSA chart is unchanged. The adjacent duplicate static notice on the Download
results view was removed; R's per-result `notice` and the Project description
disclaimer are untouched.

Verification (live at 127.0.0.1:5173 against the running API): the base case ran
and the chart matched the live `/api/base-case` response (€2,439.2756 /
0.00815905 / ICER €298,965.51 / ray at €100,000), with the region below the ray
shaded in both themes at that time — since replaced by the direct ray label
described above — and the marker and arrow colours matching the
palette; the disclosures started closed and opened by click, Enter and Space with
their tables, totals, notes and `aria-label`s intact and values equal to the API
components; the non-estimable path (rrr = 0, ΔQALYs 0.0000) showed "Dominated
(costs more, no extra QALYs) · Not cost-effective at €100,000/QALY" in both the
card and the chart note with no ratio drawn; one PSA ran at `n_sim = 100`,
`seed = 12345` (100 successful draws) and its plane carried the mean marker at the
returned mean (2417.751 / 0.007807, matching the cards), the zero guides, and the
CEAC dot at (100000, 1%) labelled "1.0%", matching the metric card and the
threshold table; the removed copy was absent while R's notices, InfoTips and
warnings remained; all nine tabs rendered; Home, Project description, Download
results and the theme control worked; light and dark both re-rendered the charts
from their palette tokens; 390px had no page-level overflow on either tab
(`scrollWidth` = `clientWidth` = 375) with the tables scrolling locally; no console
error appeared; and `npm run build` (vue-tsc + vite) and `npm run lint` pass.

Completed: the Home title's letter animation now carries a travelling wave and the
unintended outline around the wordmark is removed, frontend only
(`frontend/src/views/HomeView.vue` and `frontend/src/styles.css`). Title size, the
ECG paths, text, layout, buttons, navigation, colours, tabs, disclaimers and every
other component are unchanged, no R/API/Shiny behaviour was touched, and no PSA was
run.

**Signal passes through, it no longer settles.** A letter now rises to the full
colour, blooms, and begins returning immediately: its whole part in the cycle is
over in the first 10% of the 5.6 s cycle (560 ms), where it previously held full
colour until 48% and cooled at the end of the loop. With the same 140 ms stagger,
each letter therefore starts dimming as the next one rises, so a wave of about
three letters crosses the word instead of the word being held lit. Measured: the
first letter is full at 1.83 s, is already returning at 1.92 s while `Q` is nearly
full, the wave is a three-letter band through the middle of the word, and the last
letter is back at rest at 2.77 s — 50 ms after the trailing pulse enters its
segment at 2.72 s. At no sampled moment are all five letters solid (the maximum
number of simultaneously full letters is one, and of bright letters three).

**The outline was a focus ring, not a decoration.** The heading carried
`tabindex="-1"` and the component focused it on mount so keyboard users would land
on the title. In a real load that programmatic focus matches `:focus-visible`
(Chromium treats script focus as keyboard-like when no pointer interaction has
happened yet), so the existing rule painted a 2px teal ring with a 4px offset
around the 271×106 heading box — the rectangle that appeared on fresh load and
vanished on the first click, because the click moved focus to `BODY`. Confirmed by
focusing the heading with keyboard modality active: it matched `:focus-visible`
with a computed outline of `solid 2px rgb(23,107,115)`, offset `4px`, and the
outline cleared on blur. Fixed by removing `tabindex` and the mount-time focus
(the heading is a title, not a control) and by dropping the wordmark half of the
`focus-visible` rule; the `.page__title:focus-visible` rule was kept for the
subviews, which still focus their own headings and are outside this change.
Measured after the fix: `document.activeElement` is `BODY` on a fresh load, after a
reload and after both theme toggles, the heading has no `tabindex`, no outline and
does not match `:focus-visible`, and Tab never reaches it, while all twelve tab
stops on Home and the dashboard (Start analysis, Project description, Download
results, the two links, the theme control, the dashboard Home button, the status
chip, the assumptions disclosures, the information buttons and the tabs) still
report `:focus-visible` with their existing outlines.

Verification: the wave was sampled across a full cycle in both themes (light 0.66 →
1 → 0.66 with the bloom travelling e→Q→a→l→b; dark 0.5 → 1 → 0.5), the first and
last animation states are byte-identical at the seam, reduced motion reports no
animation with every letter in the full title colour and complete traces, forced
colours stop the animation and use `CanvasText`, the heading box (180×70) and the
Start-analysis box (128×42) were identical in all 45 live samples at 390 px with
`scrollWidth` = `clientWidth` (375), all nine tabs render, Home, Project
description, Download results, Escape and the theme control work, and a reload
produced no console error or warning. `npm run build` (vue-tsc + vite) and
`npm run lint` pass.

Completed: the Home wordmark's fill animation was replaced, frontend only
(`frontend/src/views/HomeView.vue` and `frontend/src/styles.css`). The title size,
the two ECG traces, the layout, buttons, text, navigation, colours, disclaimer
placement, tabs and every other component are unchanged, no R/API/Shiny behaviour
was touched, and no PSA was run.

**What changed.** The word-wide travelling gradient (which read as a solid
rectangular band sliding across the word) is gone. The heading's five characters
are now individual `aria-hidden` spans, and each letter is energised in turn:
it rests in the subdued `--heading-dim` tint and fills to the full `--heading`
colour, with a brief soft bloom (`text-shadow` in the new `--heading-glow` token)
as it arrives, then settles and holds. Only `color` and `text-shadow` animate, so
nothing moves, scales or re-flows. The heading carries `aria-label="eQalb"` and
the spans are hidden, so the word is announced once; the base style on the spans
is the full title colour, which keeps the word readable if animation never runs.

**Timing** stays on the traces' single 5.6 s cycle and the three animations share
one start time. The first letter begins at 1.65 s, when the leading pulse's tip
reaches the end of the left segment (measured 1.64 s); each next letter starts
135 ms later while the previous one is still filling, so three letters are always
mid-transition and the light flows across the word; the last letter reaches full
colour at 2.58 s, before the trailing pulse enters its segment at 2.72 s. Each
letter then cools back to the resting tint (the cycles are staggered by the same
135 ms), all dim by 5.44 s, so the loop restarts with no jump in colour.

Verified in the running app by seeking the animation to exact times: at 0 ms and
5599 ms every letter is the resting `rgba(20,85,92,0.66)`; at 1800 ms only the `e`
is brightening; at 2100 ms the `e` is full colour and blooming while `Q` is at
99.6% and `a` is rising; at 2400 ms `e` has settled and `a`/`l` are blooming; at
2582 ms all five are at full colour with the last one just landing; at 2720 ms all
five are full — before the trailing pulse. Live sampling at 390 px saw 1 to 5
distinct letter colours at once (i.e. a continuous flow, not five flashes); text
colour only ever moves between the two existing tokens, so contrast stays in the
3.45:1 (resting, light) to 10.1:1 (full, dark) range already verified. No layout
shift: the heading box was identical in all 40 samples (180×70 at 390 px, 271×106
at 1440 px; the span wrapping changes the measured width by 0.047 px from lost
kerning across the span boundaries, which rounds to the same box), letter widths
and the Start-analysis button never moved, and the bloom at its peak (17 px blur)
added no overflow. Reduced motion reports `animation: none` on every letter with
the full title colour and no shadow and the traces drawn whole; forced colours
stop the animation and paint `CanvasText`. Nine tabs render, Home, Project
description, Download results, Escape and the theme control all still work, and a
reload produced no console error or warning. `npm run build` (vue-tsc + vite) and
`npm run lint` pass.

Completed: the wordmark now takes part in the Home title's travelling ECG
animation, frontend only (`frontend/src/styles.css`). No text, layout, buttons,
navigation, disclaimer placement, tab, R/API/Shiny behaviour or other component
was touched, `HomeView.vue` needed no change (no new element or class was
required), and no PSA was run.

**How it works.** The wordmark rests in a subdued tint of the title colour and a
soft band of the full title colour sweeps through the letters, left to right,
completing the same signal the two traces carry. The band is a `linear-gradient`
clipped to the text (`background-clip: text`, base `color` still set to the full
title colour so an engine without the property paints solid readable text), so no
markup was added and the element stays real, selectable text. The image is 400% of
the element's width with the band inside the middle half of it, which is what
makes both animation end states paint the element in the resting tint alone:
the loop therefore restarts with no jump in colour. `background-position` animates
100% → 0%, which slides the oversized image leftwards and so carries the band
rightwards across the letters. The two resting/travelling colours are the existing
tokens (`--heading`) plus two new derived ones, `--heading-dim`
(`rgba(20, 85, 92, 0.66)` light, `rgba(127, 209, 216, 0.5)` dark), chosen so the
resting state still clears the 3:1 large-text contrast threshold. Timings are one
shared 5.6s cycle: the sweep runs between 27% and 45% of it, so the light flows
into the first letters as the leading pulse arrives at the wordmark and is clear of
the last ones before the trailing pulse enters its segment. `prefers-reduced-motion`
drops the gradient and paints the wordmark in the full title colour, and the
`forced-colors` guard paints it with the system text colour.

Measured in the running app (playwright, seeking the animation to exact phases):
at both 0 ms and 5600 ms the computed `background-position` is exactly `100%`, the
same state, so the cycle restarts invisibly; the sweep runs 27.1% → 44.3% of the
cycle (1.52 s → 2.48 s) with the position strictly monotonic, i.e. strictly
left to right; at the sweep's start the leading pulse's tip is at 92 of 100 of the
left segment (reaching 100 at 29.3%), and the trailing pulse's tip does not enter
its segment until 48.6%, after the sweep has finished; at the sweep midpoint the
whole wordmark maps into the full-colour core of the gradient (gradient fractions
0.38 to 0.623 across the element), so the letters do reach the full existing teal.
Resting contrast 3.5:1 dark and 3.45:1 light, full-colour contrast 10.1:1 dark and
7.86:1 light. Wordmark box and Start-analysis box were identical across 26 samples
spanning the sweep at 390px (180×70 and 128×42), with no page overflow, and the
gradient was observed live at that width. Reduced motion reported `animation: none`,
`background-image: none` and `color: rgb(20, 85, 92)` with the traces drawn
complete; restoring the preference restored the sweep. Nine tabs render, Home,
Project description, Download results, Escape and the theme control all still work,
and a reload produced no console error or warning. `npm run build` (vue-tsc + vite)
and `npm run lint` pass.

Completed: the two Home-screen follow-up changes, frontend only. No R model,
threshold, calculation, endpoint, Shiny, tutorial or other page was touched, no
analysis result changed, and no PSA was run.

**The project-level disclaimer is now in one place.** It was removed from the
Home screen (the trailing `.home__disclaimer` paragraph) and from the dashboard
footer, and the footer element itself was removed because it held nothing else
(`App.vue`), together with the now-unused `.app__footer` and `.home__disclaimer`
rules in `styles.css`. It remains in the Project description view, untouched: its
own disclaimer paragraphs ("All clinical outcomes, economic results, parameter
values, and decision rules are illustrative or simulated for educational
purposes. The application is not a validated HTA, clinical prediction tool,
regulatory assessment, reimbursement submission, or official recommendation…").
Note the exact sentence quoted in the request ("eQalb is an educational
illustrative model. Every clinical, cost and utility input, and every result, is
simulated or illustrative — not clinical evidence, and not a reimbursement
recommendation.") was the footer wording introduced in Batch 1 and never part of
`ProjectDescriptionView.vue`; that file was outside the allowed list, so it was
left exactly as it was. R's per-result `notice` footnotes on the analysis tabs
and every result-specific warning are untouched.

**The Home title is a new ECG composition.** The wordmark is about 50% larger
(`font-size: clamp(4.35rem, 18vw, 6.6rem)`, was `clamp(2.9rem, 12vw, 4.4rem)`),
and the trace is no longer behind it: two decorative, `aria-hidden` SVG segments
now flank the real `<h1>` text, so the trace enters from the left, the wordmark
interrupts it and it continues to the right, with the beats before and after the
name. Both segments share the same path morphology (a soft P bump, the QRS beat
and a soft T bump) so they read as one trace, and both are `preserveAspectRatio="none"`
with `vector-effect: non-scaling-stroke`, so the line thickness stays constant
while the row's flex space stretches the segments. The animated pulse is one
18-unit dash (`pathLength="100"`) in `currentColor`, which is the heading token —
the same colour as the title text in both themes. It crosses the leading segment
in the first 36% of a 5.6s cycle, the trailing segment is delayed 2.6s so the
pulse resumes just after the wordmark, and the offset is held beyond the segment
for the rest of the cycle, so the pulse appears once per cycle. Under
`prefers-reduced-motion` the animation stops and `stroke-dasharray: none` draws
the trace complete and static. At ≤640px the amplitude and the stroke widths are
reduced so the horizontally compressed beat stays legible; the composition is the
only element in the row, so it cannot shift the layout or reach the buttons, and
`scrollWidth` still equals `clientWidth` at 390px.

Verification (live at 127.0.0.1:5173 against the running API): Home and the
dashboard contain no project-level disclaimer text and no `<footer>`, while the
Project description still renders its disclaimer paragraphs; the composition
measured 736px wide at 1440px (197px segments either side of a 271x106 wordmark)
and 342px at 390px (57x52 segments either side of a 180x70 wordmark) with zero
document overflow; the pulse colour measured `rgb(127,209,216)` in dark mode and
`rgb(20,85,92)` in light mode, byte-identical to the wordmark's computed colour;
the lead pulse crossed at 719-2542ms and the trailing one at 3259-5197ms, a
~0.7s pause at the wordmark, with the title and button boxes unchanged across
samples; `prefers-reduced-motion` set every animation to `none` and the trace to
a complete static line. A rasterised ink map of the 57x52px leading segment
confirmed a distinct beat rather than a filled shape. All nine tabs still render
and select, the base case re-ran unchanged (€2,439 / 0.0082 / €298,966 / −€1,623),
Start analysis, Project description and Download results all still work, the
theme control toggles and persists, and a fresh reload produced no console
message and no page error. `npm run build` (vue-tsc + vite) and `npm run lint`
pass.

Completed: Batch 1 of the approved UX revamp — the global frontend foundation,
frontend only. No R model logic, threshold, calculation, endpoint, Shiny,
tutorial or analysis result was touched, Vue stayed presentation-only, and no
PSA was run.

**Popovers are overlays.** `InfoTip.vue` now teleports its panel to the page body
and positions it in viewport coordinates, clamped to the visible client area (the
stylesheet cap uses `100vw`, which includes the scrollbar, so the binding cap is
set from `document.documentElement.clientWidth` before measuring). Opening one no
longer expands or shifts its card, row, table or the page; a tall explanation
scrolls inside the panel, and the position is recomputed while the page scrolls
or the window resizes. Click, Enter and Space open it, Escape closes it and
returns focus to the trigger, and an outside click closes it; `aria-controls`,
`aria-expanded` and R's verbatim text are unchanged. Measured live: at 390px the
panel is 359px wide inside the 375px client area with no document overflow; a
metric card (290x97) and the PSA control row (816x69) measured identical before
and after opening; Enter and Space opened, Escape closed with focus returned, and
an outside click closed.

**Interface clutter removed.** The dashboard's repeated simulated-data banner
(`.notice--banner` plus its extra frontend sentence) is gone; Home and the
Project description carry the project-level disclaimer, and each analysis panel
renders R's own `notice` with its result so the response-carried disclaimer is
never lost. Two tabs no longer do: the value-based price tab (its R sentence now
ends without a "not clinical evidence or a pricing recommendation" qualifier,
because the Project description states that once for the whole application) and
the simulated-survival results (where R's own traffic-light explanations still
say the data are simulated). The footer no longer names `eqalb_markov.R`, `eqalb_owsa.R`,
`eqalb_survival.R` or `run_app.R`; the unreachable-service state no longer
carries launch commands, file paths or ports; the dashboard status chip no longer
shows a worker count and its tooltip no longer prints an Rscript path; and the
last rendered `eqalb_*.R` references were replaced with plain wording in
`AssumptionsForm.vue`, `SensitivityPanel.vue`, `ProjectDescriptionView.vue` and
`api/client.ts` (the network-error message). Technical detail stays in the
README and API docs.

**Tab order and final-tab identity.** "Value-based Price" now sits immediately
before the final "HTA Decision Summary" tab (tab list and panel order). The final
tab carries a small status marker and `margin-left: auto`, so it sits at the
right end of the tab strip, and its panel carries a matching top accent; both
stay neutral (teal) until the summary has been assessed and then follow R's own
overall status. Verified live: after "Assess HTA summary" returned Red, the
marker and the panel border became the danger token in both the dark and the
light theme, with R's wording and status logic untouched.

**Home.** A minimal centred landing screen: the eQalb wordmark over a decorative
ECG pulse (two SVG paths; `pathLength="100"` turns one accent dash into a
travelling pulse), "By Mahmood Alawi", the subtitle "An educational HTA model",
the primary "Start analysis" action, "Project description" and "Download
results", the project-level disclaimer, LinkedIn and GitHub links, and a small
icon light/dark control at the top-right. The hosted Shiny tutorial link and the
long model-description paragraph were removed. With `prefers-reduced-motion` the
ECG stays as a still full trace (the global reduced-motion rule already stops
animations; an explicit rule draws the whole line instead of a parked dash).

**Visual foundation.** Spacing, the typography scale, card shadow/radius, button
and tab styling and short transitions were refreshed using the existing teal
palette and tokens; no component library was added and no information
architecture changed beyond the tab move.

Verification (live at 127.0.0.1:5173 against the running API): all nine tabs
render, each selected tab shows its panel, and `scrollWidth` equals
`clientWidth` (375) at 390px on Home, the dashboard, Project description and
Download results; the base case ran (€2,439 / 0.0082 / €298,966 / −€1,623,
unchanged) and the one-way sensitivity analysis ran with its tornado canvas at
791x420 and no console error; Home, Project description and Download results
still navigate and Escape returns Home; both themes switch and persist.
`npm run build` (vue-tsc + vite) and `npm run lint` pass.

Four files outside the batch's enumerated list were touched, each to remove the
last rendered internal filename or launch command the batch's requirement named:
`AssumptionsForm.vue`, `SensitivityPanel.vue`, `ProjectDescriptionView.vue` and
`api/client.ts`. R's per-result `notice` footnotes were deliberately kept: they
are R-generated API text, and `api_contract.md` documents `notice` as carried by
every response so a client cannot lose the disclaimer; the removed repeated
banner was the frontend-authored one.

Completed: a final end-to-end integration validation of the complete Vue
full-analysis application, run in the documented order against a live API and R
model, and two defects it found were fixed in the minimum way (frontend only). No
feature was added, no R file, `eqalb_price.R`, endpoint, threshold, distribution,
Shiny or tutorial was touched, and no Python or R code was changed.

**Defect 1 — the results package omitted two analyses.** The download package's
availability list (`frontend/src/export/resultsPackage.ts`) covered seven analyses,
so a session that had run the value of information or the value-based price
produced a ZIP whose README said "nothing has been run yet" while results existed.
Fixed by registering both: their labels and hints, their entries in the store-driven
availability list, and a file set each (`value_of_information.txt` plus
`evppi_by_parameter.csv` when EVPPI is available; `value_based_price.txt` plus
`value_based_price_scan.csv`). The Download-results disclosure and
`frontend/README.md`, `project_state.md` and `FRONTEND_PLAN.md` were updated to
match. Verified live: with all nine analyses run the view lists nine included
analyses, the button reported "Downloaded eqalb_results_2026-10-10_2152.zip with
14 files" with no console error, and a session with nothing run still says so.

**Defect 2 — the stored-results counter was hardcoded.** `AssumptionsForm.vue`
rendered "x of 8 analyses stored" while the store tracks nine results after the
value-based price tab was added. Fixed by deriving the total from the store
(`analysisCount`, the length of the same key list `resultCount` counts), so the
counter cannot drift again. Verified live: it read "1 of 9", then "4 of 9" and
"9 of 9" as the workflow ran, and "0 of 9" after a cold reload.

**Endpoint and transport sweep.** All nine model endpoints through the Vue proxy
(5173) are byte-identical to the FastAPI service (8000): health, defaults,
base-case, owsa, budget-impact, readiness, hta-summary, value-based-price and
survival. Between plumber (8788) and FastAPI, base-case, owsa at two settings,
budget-impact, readiness, hta-summary and value-based-price are byte-identical,
while health differs only by FastAPI's own `r_model` block, `defaults` only by
`"max":null` where plumber omits the key, and `survival` only by
`"median_event_free_survival_years":null` — the three documented pre-existing
representations, confirmed by diffing to the first differing byte.

**Per-tab validation (each button gated its own request; every rendered figure
compared with a fresh authoritative response; zero mismatches).**
Base case: €2,439 / 0.0082 / €298,966 / −€1,623 with both decomposition tables
named. PSA at exactly 100 draws and seed 12345 (the control showed 100/12345 and
the URL carried `n_sim=100&seed=12345`): 100 successful draws, mean cost
2417.75112277353, mean QALYs 0.00780670525864131, median ICER 333632.518831389,
three threshold rows, two canvases (plane and CEAC), two named tables. OWSA: 14
rows, every row's low and high INMB present in the expanded detail table, named
table, range editor present. Budget impact: cumulative €15,480,000 with every
component and all five year rows matching, canvas rendered, population control
100,000 matching the request. Simulated survival: overall Red with five domain
statuses (Green/Amber/Red/Amber/Red), the log-rank note, the interpretation
paragraph, R's five rules in the disclosure, three named tables and the curve
canvas. Value of information: EVPI 0.110098443012998 and all nine EVPPI rows
matching the endpoint at the same 100 draws. DHT readiness: 2 Green / 4 Amber /
1 Red at 63,750 eligible people, quantitative and domain tables named, rules
disclosure present. HTA decision summary: overall Red, position "Conditional
adoption with evidence generation", all five upstream analyses supplied
(`assessed_domains` 5, no missing inputs), dashboard and priority tables named,
seven rules present. Value-based price: €155.03 supported price, −€204.97
headroom, Red, all nine scan cells matching by R's own labels, four named tables.

**Stale results, deletion and error behaviour.** Changing year-1 engagement
70 %→75 % issued no request, left the counter at "9 of 9 analyses stored", and
marked exactly the three input-snapshot tabs (DHT readiness, HTA decision summary,
value-based price); the other six kept their results with no warning, which is
their documented threshold-snapshot behaviour. Changing the reference WTP
100,000→120,000 issued no request and added the threshold warning to the base
case, PSA, OWSA and value-based price tabs while keeping every result. Aborting a
readiness request at the network layer showed the API message with the two
readiness tables preserved, then cleared on a successful re-run. Nothing was
deleted by any edit, reset, error or theme change.

**Views, accessibility, themes and 390px.** Home, Project description and
Download results all render with the simulated-data disclaimer; a cold reload
makes no API call at all (0 requests on Home, then only `GET /api/health` and
`GET /api/defaults` when the dashboard opens, no analysis run, counter "0 of 9").
All nine tabs render from scratch with no error alert and their own pre-run
prompt. The tab strip is a `tablist` labelled "Analysis" with nine tabs, exactly
one `aria-selected="true"` and one tab stop, `aria-controls` on every tab and a
panel named by the selected tab; ArrowRight, End and Home move and select as they
go. Every table on every tab carries an accessible name (0 unnamed of the 18
tables rendered). Escape closes the HTA and readiness rules disclosures when focus
is on the summary, and Enter reopens them. Both themes render every tab: measured
contrast on the value-based price tab is 7.86–13.99 light and 10.1–13.42 dark. At
390px all nine tabs and all three views measure `scrollWidth` 375 =
`clientWidth` 375 (no page-level overflow), the mobile assumptions drawer toggles
correctly and keeps the page within 390px, and the tables scroll inside their own
`.table-scroll` wrappers. `npm run build` (vue-tsc + vite) and `npm run lint` pass.
No PSA other than the 100-draw validation run was executed, and no 1,000-draw PSA
was run.

### Earlier task

Completed: phase 2 of the approved value-based price module — the Vue tab, as the
new last tab "Value-based Price" after the HTA decision summary. Frontend only: no
R file, no `eqalb_price.R`, no endpoint behaviour, no threshold, no Shiny or
tutorial change, and no other tab's behaviour touched. `ValueBasedPricePanel.vue`
renders `POST /api/value-based-price` through the existing `postValueBasedPrice()`
client and `ValueBasedPriceResponse` types; `useModel.ts` gained the
`valueBasedPrice` result, its run function, its stale check and its entry in the
clear/count bookkeeping, and `App.vue` gained the tab.

The tab follows the established analysis pattern. It makes no request until its
"Calculate value-based price" button is used, shows a pre-run note (about 40 model
runs) before that, keeps a stored result visible while the assumptions change,
disables the button with "Calculating…" while a request is in flight, and marks a
stored result as computed from earlier inputs through the same request-snapshot
comparison the readiness and HTA summary tabs use — it is never recalculated
automatically and never deleted by an input change, a reset or an error. An API
error is shown in the tab's danger alert with the previous result left in place.

Everything displayed is R's: the maximum acceptable annual price, the current
price, the headroom in EUR and %, R's status band, the required relative risk
reduction with R's verdict and its comparison with the model's one-way range, the
3 × 3 scan with R's axis names, level labels and per-cell status, the best and
worst identified combination, R's summary, note and method text, the availability
block with R's reasons, the scenario table and the simulated-data notice. The two
tables written as raw markup (the required-effect table and the 3 × 3 scan) carry
`aria-label` names, and the two detail tables render through `DataTable`. Each scan
cell shows the status R returned for it; a combination R could not identify reads
"Not available" with R's note in the scan detail, and no cell is coloured or
labelled by anything the client inferred.

Validation, measured in the running app against the live API: no request before the
button (0 calls, 0 tables, pre-run note shown); after a run, every rendered figure
matched a fresh authoritative response with zero mismatches — the four metric
cards, the required-effect table, all nine scan cells (matched by R's own row and
column labels), R's grid summary, note, method note and interpretation, the notice,
and the scenario table. Favourable case (price €120, risk reduction 15%, year-1
engagement 85%): Green with a positive headroom of €120.01, matching the API, with
the merged axis label "85% (scenario and high bound)" and 2 of 4 cells supporting
the current price. Not-identifiable case (both engagement values 0): R's "Not
available" wording for the price and the required reduction, R's reasons verbatim,
"Not available" in the 2 unidentifiable scan cells, a dash for the headroom, and no
guessed number anywhere. Stale pattern: changing the risk reduction to 11% left the
result and its four tables on screen, added the stale warning and issued no
request; re-running produced €169.07 / −€190.93, matching the API, and cleared the
warning. Error path: with the request aborted at the network layer, the tab showed
the API error and kept the previous result field for field, and a later run
recovered. All nine tabs render with no error alert, each with its own heading and
a panel named by its tab. At 390px every tab measures `scrollWidth` 375 =
`clientWidth` 375 (no page-level overflow) and the scan table scrolls inside its
own `.table-scroll` wrapper. Both themes render; measured contrast on the new tab
is 9.08:1 (panel heading) to 5:1 (status badge) dark and 8.46:1 to 4.23:1 light,
where the 4.23:1 metric-label figure is the shared `MetricCard` style measured
identically (6.28 dark / 4.23 light) on the existing Base case tab. `npm run build`
(vue-tsc + vite) and `npm run lint` pass. No PSA was run.

### Previous task

Completed: phase 1 of the approved value-based price module — the R logic and the
API endpoint, with no Vue tab. `eqalb_price.R` (new) implements
`calculate_value_based_price()`, which answers one payer question from
`run_eqalb_model()` outputs only: how much can be paid per active user per year for
eQalb and still reach the reference threshold. It returns the maximum acceptable
annual price, the headroom against the current price, the relative risk reduction
the current price would require, the 3 x 3 scan of the supported price across the
model's own relative-risk-reduction and year-1 engagement bounds, an
availability block and R's interpretation sentences. `POST /api/value-based-price`
was added to `api/plumber.R` (with `eqalb_price.R` in `MODEL_MODULES` and
`calculate_value_based_price` in `MODEL_FUNCTIONS`) and to `api/main.py` with a
`ValueBasedPriceRequest` model; `api/api_contract.md`, `frontend/src/api/types.ts`
and `frontend/src/api/client.ts` document the contract. Shiny, the tutorials, the
PSA and every existing endpoint, threshold and model function are untouched.

The module solves the price rather than searching for it: incremental cost is a
straight line in the annual intervention price, so two runs give the slope and
level, the price with zero incremental net monetary benefit follows directly, and a
third run at that price confirms it (the residual is returned as
`verification_nmb`). A shape-free bisection search replaces the solve if the model
does not reproduce the straight line, and the required relative risk reduction is
found by bisection inside the model's validated 0-1 domain with its bracket width
reported and the result compared with the model's 5%-15% one-way range. Every
status band, level label, reason and sentence is defined in R; a value that cannot
be identified is returned as `null` with R's reason and an `availability` flag, and
no number is guessed.

Validation: a brute-force €1 price grid in R (`seq(100, 250)`) gives a highest
passing price of €155, and the module returns €155.029800318324, whose confirming
run reports an incremental net monetary benefit of −3e-12; the closed-form check
`360 + NMB / slope` reproduces the same value, matching the €155 already recorded
for Part 2 Case A. The default case gives status Red with a headroom of
−€204.970199681676 (−56.936167%) against €360, a 24.61% required risk reduction
(bracketed by +€6.70 at the reported value and −€9.85 just below it, and outside
the model's one-way range), and a scan from €78.41 (both bounds low) to €240.01
(both bounds high) with 0 of 9 cells supporting €360. A favourable case
(price €120, risk reduction 15%, year-1 engagement 85%) returns Green with a
positive headroom of €120.01, 2 of 4 cells supporting (the duplicate level is
merged), and the required reduction falling to 7.03%. Zero engagement returns
`headline.available: false` with the reason that incremental QALYs are not
positive, `required_effect.available: false` with the reason that even a 100%
reduction does not reach the threshold, and 6 of 9 scan cells identified. A
negative solved price (implementation cost €500, no savings, WTP €1,000) reports no
non-negative price with the raw root −€24.46 in the reason, and a WTP of €1e9
reports the solved price above the model's own bound. `current_price` is applied as
the price the model runs at and warns when it overrides `intervention_price`.
Error paths return R's own messages (400 through FastAPI, 422 for a wrong JSON
type). The plumber and FastAPI responses are byte-identical (9,244 bytes) for the
default request, and the existing endpoints are unchanged: base case, OWSA at two
settings, budget impact, readiness and HTA summary byte-identical between the
services, `defaults` and `survival` differing only in the documented pre-existing
`NA` representation, with ICER €298,965.512965076, cost €2,439.27562235471, QALYs
0.00815905352481128, readiness 2/4/1 at 63,750 and HTA Red with 7 rules. A PSA
regression at `n_sim = 100`, `seed = 12345` was run through both services
(byte-identical) and confirmed against a direct `run_psa_eqalb()` call and against
the same run with and without `eqalb_price.R` loaded; no 1,000-draw PSA was run.
`npm run build` (vue-tsc + vite) and `npm run lint` pass. See the update log for the
unresolved PSA baseline discrepancy found during that regression.

### Earlier task

Completed: the two approved pre-1.0 P2 fixes from the UI/UX audit triage and then
their two cleanup tasks — accessible names on the four raw tables that were still
unnamed, and the status documentation that still called the P2 findings untriaged.
Everything is frontend-only: no R file, API endpoint, threshold, calculation,
Shiny module, tutorial or endpoint response shape was touched, and no package was
added.

The one-way sensitivity tab no longer mislabels its table. The tornado columns are
derived from the result the API returned (`outcome`, `outcome_label`) instead of
from a value captured at component setup, so headers, units and values always
describe the run on screen, and the "Ranked outcome" selector no longer runs the
analysis on change — it shows the same "run the analysis again to apply …"
treatment the tab already used for a changed threshold. R's narrative, the pre-run
sentence, the CSV export, the Run-button gating and the range editor are
unchanged; the INMB clarification now depends on the ranking the result actually
used, so it cannot describe a ranking the table is not showing.

The tab strip and the shared table component are accessible. The eight analysis
tabs are a `tablist`: each tab carries `role="tab"`, `aria-selected`,
`aria-current` when it is the selected one, `aria-controls`, a stable id and a
roving `tabindex`, the panel carries
`role="tabpanel"` named by its tab through `aria-labelledby`, and Left/Right/Home/
End move between tabs while Enter and Space keep the browser's own button
activation. Tables rendered through `DataTable` expose an accessible name taken
from the caption already shown above them, or from a new `label` prop where there
is no visible caption; the one-way range editor's table was named the same way.
Nothing moved visually and `styles.css` was not needed.

Validation: `npm run build` (vue-tsc + vite) and `npm run lint` pass. Measured in
the running app, no `/api/owsa` request is issued when the ranked outcome changes;
a QALYs run shows QALYs headers, formats and chart caption; switching back to INMB
without running keeps the QALYs table with a warning naming the QALYs ranking; and
running again restores the INMB headers and the same numbers as before the change
(the intervention-price row €-198 / €-3,049 / €2,851). The accessibility tree shows
`tablist "Analysis"` with eight tabs, exactly one `aria-selected="true"` at
`tabindex="0"`, and a `tabpanel` named by its tab; ArrowRight twice, End, Home and
ArrowLeft move and select, Tab leaves the strip after one stop and Shift+Tab
returns to the selected tab. Tables report their names ("Cost decomposition (EUR,
incremental)", "QALY decomposition (incremental)", "Full one-way sensitivity
table", "Parameter ranges for the one-way analysis"). All eight tabs render with no
error alert; 390px gives scrollWidth 375 = clientWidth 375 on every tab; both
themes stay readable (active tab 10.1:1 dark and 7.86:1 light, panel heading 9.08:1
dark and 8.46:1 light). The CSV export still writes `eqalb_owsa_ranked_table.csv`
(15 lines, the INMB row equal to the `low_inmb` / `high_inmb` columns). The
endpoint sweep is unchanged: base case, OWSA (default, WTP 200,000 and ICER),
budget impact, readiness and HTA decision summary are byte-identical between
plumber on 8788 and FastAPI on 8000, while `defaults` differs only by FastAPI's
`,"max":null` and `survival` only by `"median_event_free_survival_years":null` —
the documented pre-existing `NA` representation. Baselines unchanged: ICER
€298,965.51, incremental cost €2,439.28, incremental QALYs 0.00816, readiness 2/4/1
with 63,750, HTA Red / "Not yet assessable" with 7 rules. No PSA was run for this
task.

Two cleanup tasks followed the two fixes. The four raw tables that
`DataTable` does not render — the readiness quantitative and domain tables in
`ReadinessPanel.vue`, and the HTA decision dashboard and evidence-priority tables
in `HtaSummaryPanel.vue` — now carry `aria-label` names taken from the caption
shown above each of them, so no visible caption, column, row, style or
`.table-scroll` behaviour changed; every table in the interface is now named. The
stale status statements were corrected in `frontend/README.md` (whose known
limitations now record the finished triage and the two implemented fixes, and
whose conventions list the tab and table accessibility) and in `agents.md`
("Current status"), and `project_state.md` and `FRONTEND_PLAN.md` recorded the
cleanup.

Validation: `npm run build` (vue-tsc + vite) and `npm run lint` pass. Each of the
four tables reports its name in the accessibility tree ("Quantitative outputs,
simulated", "Domain assessment, illustrative", "Decision dashboard, illustrative",
"Evidence priorities, illustrative"), and the readiness and HTA tabs contain no
unnamed table after rendering. All eight tabs render with no error alert and no
console error; 390px gives scrollWidth 375 = clientWidth 375 on every tab; both
themes stay readable (active tab 10.1:1 dark and 7.86:1 light, panel heading
9.08:1 dark and 8.46:1 light). No PSA was run, and no R file, API route, threshold,
calculation, Shiny file or endpoint shape was touched.

Two limitations remain from the P2 triage, both recorded in `FRONTEND_PLAN.md`:
twelve P2 findings are deferred (three needing backend work) with no approval to
start, and the `/api/budget-impact` default population still disagrees with the
readiness default for a bare API call.

### Earlier task

Completed: documentation-only audit and correction of `project_state.md`,
`FRONTEND_PLAN.md`, `frontend/README.md`, `api/api_contract.md` and `agents.md`.
No R file, API route, Shiny file, Vue component, threshold or endpoint behaviour
was modified, and nothing was started or tested for this task; the statements
below were checked against the files they describe.

The documentation now records, once each: phase 1 and phase 2 are complete, the
P0 Kaplan-Meier interpretation fix is in, and all six P1 findings of the approved
UI/UX audit are implemented in four batches; the remaining 15 P2 polish findings
are untriaged and the next task is a read-only triage of them, with implementation
awaiting approval (superseded since by the P2 triage and the two implemented fixes
recorded above); R is the sole source of calculations, thresholds, statuses,
interpretations and evidence priorities; PSA validation uses 100 draws and seed
12345 unless a full default PSA is explicitly requested; the Vue tutorial rebuild
is deferred until the full-analysis Vue app is complete and the final economic
module is added; reset is Option A (the model assumptions and WTP only, every
result preserved); the Kaplan-Meier patient-level dataset export and the R
figure-rendering endpoints remain deferred with their honest limitation notes;
and Shiny is unchanged as both the reference and the tutorial application.

Corrections made while auditing: stale status wording in the `FRONTEND_PLAN.md`
header; the plan's outdated claim that the HTA tab does not restate the numeric
rules (since Batch 2 the tab renders the rule text `POST /api/hta-summary`
returns); the `project_state.md` file map, which predated the browser stack and
the three shared R modules; the stale "Superseded note" left in
`project_state.md`; the duplicated rendering-gap and reset statements in
`frontend/README.md`; and the uppercase `PROJECT_STATE.md` reference in
`agents.md`.

### Earlier task

Completed: Batch 4 of the approved P1 plan, the last one — the OWSA narrative
summary now comes from R for both presentations. No model arithmetic, threshold,
distribution or endpoint response shape changed, and no Shiny behaviour changed.

R: the narrative body moved verbatim out of `app.R`'s `output$owsa_summary` into
`summarize_eqalb_owsa(result)` in `eqalb_owsa.R` (the five moved statements are
token-identical to the removed lines, verified by comparing deparsed statement
digests: `e273d084f25ee77ceee1b1d3ade41391145a324a` on both sides; only the
statement that fetched the reactive, `result <- owsa_result()`, became the call
argument). `app.R` now calls the function, and its two literals moved into
`eqalb_ui_copy.R` as `OWSA_SUMMARY_NOTE` and `OWSA_PRERUN_NOTE` (the paragraph
above the summary, used by the UI, and the pre-run sentence used by the
renderText), so each sentence exists once. A new `eqalb_owsa_scenario_rows()`
presents a `run_eqalb_owsa()` result (one row per parameter, low/high in columns)
in the per-scenario shape the narrative reads, keeping the wording, the INMB
ranking rule and the failure rule in R only.

API: `POST /api/owsa` returns `summary` (the narrative) and `summary_note` (the
paragraph above it); `GET /api/defaults` returns `owsa_summary_note` and
`owsa_prerun_note`. `summarize_eqalb_owsa` joined `MODEL_FUNCTIONS`, so
`/api/health` verifies it.

Frontend: `SensitivityPanel.vue` renders the note and the narrative above the
tornado diagram straight from the API (`white-space: pre-wrap`, so the three lines
keep their breaks and still wrap at 390px), shows Shiny's pre-run sentence when no
run has happened, and adds one factual line when the ranked outcome is not INMB —
R's narrative always ranks by the INMB range, and the chart below may be ranked by
ICER, incremental cost or incremental QALYs instead. `types.ts` carries the new
fields.

Tests performed: the moved block is token-identical to what was removed; `app.R`
sources, builds its UI (the note string appears exactly once, and the OWSA tab's
inputs, `textOutput` and Run button are intact) and defines `server`. All three
required narratives were compared with direct R calls and with the plumber
service, and were byte-identical in every case: the default run; a run at
WTP €200,000 where all three top parameters cross the threshold (the narrative
says "crosses the WTP decision threshold" for each, against "does not cross" in
the default run, and the base line reads "Base-case INMB: €-807 at
WTP €200,000/QALY."); and a run where a scenario fails (the Time horizon low bound
set to 0 gives `low_warning` "Model failed: cycles > 0 is not TRUE" and no INMB
range, so — exactly as Shiny's own `sort()` rule does — the failed parameter drops
out of the ranking and is not named in the narrative, while the panel's existing
bound-warning disclosure still reports the failure and no error is raised). The
failure sentence itself was exercised directly: with a failed parameter placed in
the top three, `summarize_eqalb_owsa()` returns "Time horizon: at least one
scenario failed" — a branch that a normal run cannot reach, in the browser
interface or in Shiny, because a failed scenario has no range to rank by.
In the browser, every rendered narrative line equals the corresponding API line at
the default threshold and at €200,000, the note matches the API string, the
summary sits above the tornado, and the ICER-ranking case shows the INMB
clarification. All eight tabs render with no error alert at 1280px and 390px
(scrollWidth 375/390 on every tab; the narrative element is 293px wide with no
internal overflow and keeps its three lines); narrative contrast measures 13.42 in
dark mode and 13.99 in light. `npm run build` and `npm run lint` pass. The
endpoint sweep is unchanged: base case, OWSA (default, WTP 200,000 and ICER
ranking), budget impact, readiness and hta-summary are byte-identical between
FastAPI and plumber, with ICER €298,965.51, readiness 63,750 with 2/4/1 and HTA
Red / "Not yet assessable" with 7 rules; survival, health and defaults still differ
only in the documented pre-existing `NA` representation, and so does an OWSA run
with a failing bound (only the failed scenario's `null` cells — the `summary` and
`summary_note` are identical on both services).

### Earlier task

Completed: the value-of-information precision defect in the FastAPI worker, found
while validating Batch 3 and now fixed before Batch 4. One line of behaviour
changed; no PSA logic, VOI calculation, threshold, response shape or Shiny file was
touched.

`api/r_worker.R` rebuilds the request body it hands to the plumber handler with
`jsonlite::toJSON()`; that call now passes `digits = NA`, the setting the reply
writer in the same file already used. Before the change jsonlite's default of four
decimal places applied, so a value a client posted back to R was rounded — most
visibly the PSA draws that `/api/value-of-information` accepts, where EVPI at 1,000
draws came back 4.6942935 against 4.70724749145015 through plumber and
4.70724749145016 in R. Everything else in the worker (the empty-body branch, the
`postBody`/`argsQuery`/`REQUEST_METHOD` shape, the reply writer) is unchanged.

Tests performed: on the wire before the fix, a body carrying
`incremental_cost` 1234.5678901234 and `incremental_qalys` 0.00123456789012 came
back as 1234.5679 and 0.0012 through FastAPI while plumber returned both values
unchanged; after the fix FastAPI returns 1234.5678901234 and 0.00123456789012, the
values as sent. Reproducing the documented case end to end (1,000-draw PSA at seed
12345 fetched over HTTP, its draws posted back as a client would) gives EVPI
4.70724749145015 from FastAPI, from plumber and from a direct `voi_evpi()` call,
with the two services' response bytes identical; the pre-fix FastAPI value was
4.6942935. At `wtp` 300,000 with 100 draws, where 8 of the 9 EVPPI rows are
non-zero, every row matches the direct R call at transmitted precision (largest
relative difference 1.75e-15, i.e. the 15-digit transport rounding, not a
calculation difference). The precision nuance was measured rather than assumed:
jsonlite's `digits = NA` writes 15 significant digits, which is exactly what both
services transmit, and a client-held draw set survives the worker rebuild
bit-exactly (`identical()`), so the round trip the VOI endpoint depends on is
lossless. Regression sweep: `/api/base-case` (empty body and a fractional scenario
body), `/api/owsa`, `/api/budget-impact` and `/api/readiness` return bytes
identical to the untouched plumber service, and the key values match the pre-fix
records (ICER 298965.512965076; OWSA 14 rows, top impact range 2851.21104464014;
budget 10,836,000 cumulative with 10,584,000 / 840,000 / 588,000 components and
population 70,000; readiness 63,750 with 2 Green / 4 Amber / 1 Red; HTA Red / "Not
yet assessable" with 7 rules; 100-draw PSA means 2517.24320161568 and
0.00794926986130171, mean NMB −1722.31621548551, median ICER 320482.009072636).
`/api/survival`, `/api/health` and `/api/defaults` differ from plumber only in the
documented pre-existing `NA` representation (FastAPI sends `null` for a
not-reached median, a missing readiness `max` and the FastAPI-only `r_model`
fields, plumber omits those keys) — none of them passes through the edited branch,
which is taken only when a request body is present. In the browser all eight tabs
render with no error alert at 1280px and at 390px (scrollWidth 375 against a 390px
viewport on every tab), and both colour modes measure readable
contrast — dark: headings 9.08, body 8.12, buttons 14.92, labels 6.28; light:
headings 8.46, buttons 13.0, muted secondary text 4.16–4.76 depending on whether
it sits on a card or the page background. `npm run build` (vue-tsc + vite) and
`npm run lint` pass.

### Earlier task

Completed: Batch 3 of the approved P1 plan — the PSA defaults and permitted range
now match the Shiny control. No PSA distribution, draw order, threshold or
calculation changed, and no Shiny file was touched.

R/API: `simulation_defaults()` in `api/plumber.R` now reports 1,000 draws and seed
12,345 (was 200 and 1233) and publishes Shiny's own control limits —
`psa_n_sim_min` 100, `psa_n_sim_max` 10000, `psa_n_sim_step` 100, `psa_seed_min`
1. `POST /api/psa` takes its defaults and its bounds from that same function, so
the numbers the form offers and the numbers R validates cannot drift; an
out-of-range value still fails with R's own message
(`'n_sim' must be between 100 and 10000.`, `'seed' must be between 1 and
2147483647.`) rather than a Python one.

Frontend: `useModel.ts` defaults `psaSims` to 1,000 and `psaSeed` to 12,345 and
exposes a `psaBounds` computed from `/api/defaults`, which
`CostEffectivenessPanel.vue` uses for the three attribute values instead of
hard-coded ones. The invented "roughly 0.27 s per iteration" estimate is gone: the
panel now records the duration of the last completed run and estimates the next
one from that measurement, saying so until it has one ("the first run on this
machine sets the time estimate"). The busy alert states that the browser tab has
to stay open for the run to finish and that the button is disabled meanwhile, and
a practical-limit note records that a run above roughly 5,000 draws exceeds the
API's 15-minute request timeout and that the value-of-information panel needs at
least 100 draws. The action-button gating and result persistence are unchanged.

Documentation: `api/api_contract.md` (the `simulation_defaults` bullet, the
`/api/psa` query line and its cost sentence, the worker-protocol example, and two
new known-limitation entries), `api/main.py` (the two OpenAPI query
descriptions), `api/r_worker.R` (the protocol example line, comment only — the
only file outside the batch's list, changed because it quoted the old default as
documentation), `frontend/README.md` and `FRONTEND_PLAN.md`.

Tests performed: `/api/defaults` reports 1,000/12,345 and all four bounds;
`n_sim` 10001, 10 and 99 and `seed = 0` were rejected with R's messages above;
10000 and 100 were proven accepted through the argument-order validation path
(`?n_sim=10000&wtp=-1` reaches the `wtp` error, `?n_sim=10001&wtp=-1` does not).
A full default PSA (no overrides) ran 1,000 requested, 1,000 successful, 0
failed, in 179.8 s: mean incremental cost 2420.86625982289, mean incremental
QALYs 0.00795785619474315, mean NMB −1625.08064034857, median ICER 331546.182547232,
probability cost-effective 0.001 / 0.015 / 0.075 at €50,000 / €100,000 / €150,000,
201 CEAC points and 1,000 cloud draws, all reproduced by a direct
`run_psa_eqalb(n_sim = 1000, seed = 12345)` call in R (NMB confirmed as the
endpoint's documented `mean_qaly * wtp - mean_cost` derivation). The
value-of-information comparison surfaced a pre-existing difference, now
diagnosed and recorded rather than left silent: a direct R `voi_evpi()` on the
same draws gives EVPI 4.70724749145016, the plumber endpoint 4.70724749145015, and
FastAPI 4.6942935, because `api/r_worker.R`'s `handle_request()` rebuilds posted
bodies with `jsonlite::toJSON()` without `digits = NA`, so jsonlite's default of
four decimal places rounds the draws R receives — measured directly, a posted
`incremental_cost` of 1234.5678901234 arrives as 1234.5679 (the reply writer does
pass `digits = NA`, which is why returned numbers are exact). EVPI is a small
difference of large net-benefit values, so it shows the effect while the PSA's own
means do not; it is not a Batch 3 regression and the one-line fix is `digits = NA`
in that worker call. In the browser the controls
showed 1000/10000/100/12345 with the new hint and note; a 100-iteration run sent
`/api/psa?n_sim=100&seed=1&wtp=100000`, matching the displayed values, with the
busy alert, the disabled button and a "last run: 100 iterations in 19 s" reading;
all eight tabs render with no error; no page-level overflow at 390px; light and
dark both readable; `npm run build` and `npm run lint` pass.

### Earlier task

Completed: Batch 2 of the approved P1 plan — the per-input help text and the HTA
traffic-light rules/evidence note, from one verbatim R copy module.

R: `eqalb_ui_copy.R` now holds `CC_INFO_TEXT` (the whole dictionary, comment
included) and the four HTA rule constants (`HTA_SUMMARY_RULE_NOTE`,
`HTA_EVIDENCE_NOTE`, `HTA_RULE_ITEMS`, `HTA_RULES_TRIGGER_LABEL`), moved out of
`app.R` character for character. `app.R` sources it beside the other modules, so
the Shiny app and its popovers, the tutorial rules and the results-package README
all read the same strings as before. Both blocks were hash-verified before and
after (`ef2ea227…` for the HTA block, `6459d99e…` for `CC_INFO_TEXT`), and the
`HTA_SUMMARY_RULE_NOTE` value digest `c925f4c8…` is identical to the value in the
committed `app.R`, which is what the exported README writes. `app.R` still sources
cleanly, builds its `shiny.tag.list` UI (with the readiness and HTA tabs and the
"Traffic-light rules" triggers present) and defines `server`.

API: `eqalb_ui_copy.R` joined `MODEL_MODULES`, so `/api/health` verifies it.
`GET /api/defaults` publishes `info_text` (the 17 analysis explanations keyed as
the Shiny dictionary keys them; the tutorial/Part 2 entries and the unused
`willingness_to_pay` key are excluded) and an `info` field on every
`parameters[]` row (nine mapped: price, implementation cost, healthcare savings,
RRR, both engagements and the three utilities) and on the readiness
`review_minutes` row; the other seven model parameters and seven readiness rows
carry `""`. A missing key raises an error rather than shipping an empty
explanation. `POST /api/hta-summary` returns `rules` (seven sentences),
`evidence_note` and `rule_note`. Because `""` (not `NA`) marks "no explanation",
the value serialises identically through both the plumber and FastAPI paths.

Frontend: new `InfoTip.vue` (real button, `aria-label`, `aria-expanded`,
`aria-controls`, Escape closes and refocuses the trigger, outside click closes),
attached to the nine model-assumption fields, the reference threshold, the budget
population and uptake, the readiness clinician-review input, the PSA
count/seed/mean cost/mean QALYs and EVPI/EVPPI. `MetricCard`'s hint is now the
same accessible control instead of a non-focusable `title` span. The HTA panel
renders the rules in its own disclosure (Escape closes) with `rule_note` beneath
them, and `evidence_note` under the evidence-priority table. The help panels are
laid out in normal flow: an absolutely positioned panel grown rightwards from the
trigger widened the page at 1024px and 1280px as well as 390px, which the
measurements caught before this was reported as done.

Tests performed: every exposed help key compared with `CC_INFO_TEXT` in R and
again over HTTP — 17 keys, 0 mismatches, and `willingness_to_pay` and the
tutorial/Part 2 keys confirmed absent; all nine mapped parameter strings, the
readiness one and the three HTA strings `identical()` to the dictionary values;
the incomplete HTA state unchanged (`overall_status` Red, `position` "Not yet
assessable"). In the browser, all ten sidebar tips plus the budget, readiness, PSA
and VOI tips were opened and their rendered text compared with the live
`/api/defaults` strings — every one matched; Enter, Space, Escape (focus returned
to the trigger), outside click, `aria-expanded`, `aria-controls` and the panel's
`role="region"` were all verified on a real trigger; the HTA panel rendered
exactly 7 rules plus the evidence and rule notes matching the API; the disclosure
closes on Escape. Layout: 36 measurements across eight tabs plus the sidebar at
390, 768, 1024 and 1280px with every disclosure and help panel open — no page
overflow, no panel beyond the viewport, narrowest panel 263px (169px inside a
metric card at 390px, which still fits). Light and dark both readable for the
panels, the rules list and both notes. All eight tabs render with no error alert;
`npm run build` and `npm run lint` pass; the ten-endpoint regression sweep is
unchanged (ICER €298,965.51, budget €15,480,000, readiness 63,750 with 2/4/1,
HTA Red/"Not yet assessable" with 7 rules, PSA/VOI/OWSA/KM answering).

### Earlier task

Completed: Batch 1 of the approved P1 plan — Reset Option A plus the Shiny-parity
CSV exports. Frontend only: no R file, endpoint, threshold or calculation changed.

Reset: "Reset" became "Reset model inputs" and now restores the 16 model
assumptions and the reference WTP threshold to the R base case and nothing else.
`applyDefaults()` no longer clears results, so the two stored results it used to
destroy survive a reset; the PSA, Kaplan-Meier, budget-impact, readiness and OWSA
analysis settings, the shared target population and the edited OWSA ranges are
untouched, and the button is enabled exactly when something in its scope differs
(so it now also works to undo a WTP change, which it could not before). Readiness
gained Shiny's own "Reset values" control, which restores the seven readiness
inputs and clears the readiness assessment only. Clearing is now a separate
"Clear all results" action with an inline confirmation that lists what it removes,
shows how many of the eight analyses are stored, and is disabled when there is
nothing to clear. Readiness and the HTA summary remember the request that produced
their stored result and show the house warning style when their own inputs have
changed since, instead of silently deleting anything.

Exports: `frontend/src/export/csv.ts` holds the CSV and text-download helpers moved
out of the results package (same quoting rule as `write.csv`), and
`frontend/src/export/tabExports.ts` holds the three per-tab builders. The base-case
button writes Shiny's `eqalb_cost_effectiveness_results.csv` layout row for row;
the sensitivity button writes the ranked table the API returns, named
`eqalb_owsa_ranked_table.csv` with the shape difference stated on the tab; the
survival button writes `eqalb_km_summary_tables.csv` (arm summary, number at risk,
interpretation checks, modelled expectation) and the tab states that Shiny's
patient-level dataset export needs a deferred endpoint. Every button is disabled
until its analysis has run.

Tests performed: the base-case CSV text captured from the button matched Shiny's
own export computed in R from the same inputs, row for row (only the quoting of
strings differs); its button was disabled before the run; the sensitivity CSV
(14 rows) matched the live `/api/owsa` table's shape and first row, and its button
was disabled before the run; the survival CSV (44 rows across four sections) was
compared cell by cell with the live `/api/survival` response for the same seed —
arm summary, number at risk at year 0 and the first interpretation check — with
zero mismatches. Reset: after changing the price to 500 and the threshold to
120,000, reset restored 360 and 100,000, disabled itself, kept the readiness
result and left the readiness input (access 40%) alone as designed; a readiness
input change marked the stored assessment stale without removing it; readiness
"Reset values" restored access 40% → 85%, cleared the readiness assessment only
and left the base case in place; "Clear all results" asked first (the count read
"1 of 8 analyses stored"), Cancel kept everything, and confirming removed all
results, disabled the button and left the inputs untouched. The danger styling was
fixed to sit after the base button rules and is now readable in both themes
(light `#b3261e` on `#f5c6cb`, dark `#e57373` on `#5c2f2f`). All eight tabs render
with no error alert; every tab has `scrollWidth` 375 at a 390px viewport, so no
page-level overflow; the sidebar at 390px shows both controls. `npm run build`
(vue-tsc + vite) and `npm run lint` pass, and the nine-endpoint regression sweep is
unchanged (health ready, base-case ICER €298,965.51, budget €15,480,000, readiness
63,750 with 2/4/1, HTA "Not yet assessable", PSA/VOI/OWSA/KM all answering).

### Earlier task

Completed: the P0 Kaplan-Meier interpretation parity fix from the UI/UX audit, in
three parts.

R and API (the minimum plumbing needed to expose the existing function): the
Shiny Kaplan-Meier interpretation moved verbatim out of `app.R` into a new
`eqalb_km_interpretation.R` holding `km_number()`, `km_p_value()` and
`assess_km_interpretation()`, sourced by `app.R` in place of the inline
definitions (the block hash before and after is identical, and `app.R` still
parses and builds its UI); `api/plumber.R` now lists the module in
`MODEL_MODULES` and the three functions in `MODEL_FUNCTIONS`, so `/api/health`
verifies them. `POST /api/survival` derives the interpretation from the same
simulated statistics it already returns and adds two fields: `interpretation`
(the complete `assess_km_interpretation()` result — `overall_status`, the five
`domains` with `Domain`/`Status`/`Explanation`, `counts`, R's plain-language
`interpretation`, the five `rules`, and `display`, the three statistics already
formatted by R's own helpers) and `logrank_note`, the Shiny tab's descriptive
log-rank line with the simulated-data notice. No status, threshold or wording is
produced outside R.

Frontend: the survival tab now shows that interpretation — overall status, R's
interpretation paragraph, the counts table behind the domains, the hazard-ratio
and log-rank lines using R's formatted values, the descriptive log-rank note as a
separate line, one traffic-light card per domain with R's own explanation wording
and a status badge, and the five rules in a collapsed "Traffic-light rules used"
disclosure. The bare "log-rank p = …" that had no qualifier was removed from the
hazard-ratio metric card. The chart, risk table, arm summary, diagnostics,
action gating and arm-contrast verdict are unchanged, and the panel appears only
after a simulation has been run. `api_contract.md`, `types.ts` and `api/main.py`'s
endpoint docstring document the new fields; `client.ts` needed no change.

Tests performed: the extracted block is byte-identical to the removed lines
(digest `a40b1173…`, 215 lines), and the interpretation for four scenarios
(default, poor, favourable and not-estimable) reproduced the four pre-extraction
digests exactly (`2750788a…`, `ee0294f7…`, `339d41e1…`, `6d8ee20f…`); `app.R`
sourced end to end without error and its interpretation call returned the same
result, so the Shiny tab is unaffected; the endpoint was invoked directly from a
fresh R process (Shiny not loaded, `app.R` not sourced) and returned
`overall_status`, `domains`, `interpretation` and `rules` `identical()` to a
direct `assess_km_interpretation()` call with the same statistics, with `counts`
equal as numbers; over live HTTP (`/api/health` reports `model_ready: true` with
the new module listed) the default run returned 177 vs 192 composite events,
823 vs 808 censored, 190 vs 160 competing deaths, 633 vs 648 administrative
censoring, display 0.936 / 0.526 / 0.117 and the same five domain explanations
word for word. In the browser, every rendered field was compared with the same
response: 5 domains, 5 rules, 2 bullets, counts table, interpretation paragraph,
logrank note and disclosure label all matched with **zero mismatches**; the panel
is absent before the run and present afterwards; all eight tabs still render with
no error alert and the interpretation survives a tab round-trip; at 390px a fresh
load and a 1280→390 resize both leave `document.documentElement.scrollWidth` at
375 (no page-level overflow) with the five domain cards stacked in one column;
light (`#f4f7f9` / `#eef2f6`, badge `#d4edda` on `#2e7d4f`) and dark
(`#101a1f` / `#1e3039`, badge on `#4caf7d` / `#e57373` borders) are both
readable; `npm run build` (vue-tsc + vite) and `npm run lint` pass.

### Earlier task

Completed: the Home / landing experience in the browser interface (frontend only).
The app now opens on a centred Home screen — app title, a short description of the
simplified HTA of the fictional eQalb, a restrained simulated-data disclaimer,
"Start analysis", "Project description" and "Download results" actions, a link to
the hosted Shiny app (new tab, `rel="noopener noreferrer"`), the existing
light/dark control, and the creator credit with LinkedIn and GitHub links — with
two subviews reachable from it (Project description, Download results). The
Project description view carries the Shiny wording, the list of analyses, the
educational-purpose and limitations text, and the feedback/contact address
(`smalawi2018@gmail.com`) with the LinkedIn and GitHub links; Download results
lists which analyses this session has produced and which have not been run and
builds a ZIP from results already held in the session, with the precise remaining
backend gap (R-rendered chart images) stated in the package README and on the
page. A compact persistent "Home" button now sits in the dashboard header, and
Back plus Escape return from the subviews. Navigation is a single shared ref, not
a router: the project has no routing dependency and page changes never touch
inputs or results. The contract is fetched only when the dashboard is first
opened, so Home makes no API request and nothing analyses on its own. Two new
modules do the export work without a new dependency: a store-only ZIP writer
(CRC-32, local headers, central directory) and a results-package builder that
formats values the API already returned. No R file, endpoint, threshold,
calculation, tutorial or analysis tab was touched.
Tests performed: Home renders first with zero `/api/` requests (40 module
fetches, no API call); "Start analysis" opens the dashboard and fetches the
contract (status chip "R model ready · 2 workers"); the header Home button
returns and the dashboard still showed the earlier base-case result
(€298,966 / 0.0082 QALYs) and readiness result (89,250.0) with no automatic
re-run; all eight tabs render and had not auto-run; the description view shows
the Shiny wording, the contact address and the three links, and Escape and Back
both return Home; the theme control switched dark↔light with the expected body
colours and restored the saved value; the ZIP produced by "Download results
package" was captured from the button handler and parsed — `PK\x03\x04`
signature, end-of-central-directory present, name
`eqalb_results_2026-10-10_0549.zip`, containing README.txt,
model_assumptions.csv, cost_effectiveness_summary.csv and
dht_readiness_results.csv for the two analyses that had been run, with the
readiness rows (63,750 / 44,625 / 26,775 / 60.0% / 89,250.0 and the seven
domain statuses) and the ICER (298965.512965076) matching the live API values;
Tab order runs heading → links → actions; no page-level horizontal overflow at
390px on Home, Project description, Download results or the dashboard; build
(vue-tsc + vite) and lint pass.

### Earlier task

Completed: a local development control script, `dev.sh` in the project root, plus
its two git-ignored state paths. It is a development convenience only — no R
model logic, API logic, Shiny file, Vue component or endpoint behaviour was
touched (verified by timestamps). `./dev.sh start` starts whatever is not already
running using the existing launchers (R Plumber on 8788 via
`Rscript api/run_api.R`, FastAPI on 8000 via `api/.venv/Scripts/python.exe
api/run_api.py` with `EQALB_API_PORT`, and the Vue dev server on 5173 via
`npm run dev` with `EQALB_API_URL` pointing its proxy at FastAPI), each in the
background with its output appended to `.dev-logs/<service>.log` and its pid
recorded in `.dev.pids`. FastAPI runs on 8000 because the published default 8788
is shared with the plumber service, so previously only one of the two APIs could
be up; both are now available side by side, and the Vue proxy follows FastAPI
because it is the primary service (it returns JSON `null` where plumber returns
the string `"NA"`). Ports are overridable with `R_PORT`, `API_PORT` and
`VUE_PORT`. A service whose port is already in use is reported as already running
and adopted into the pid file rather than started twice. `stop` stops only the
recorded ids (falling back to the listeners on those three ports when the pid
file is missing) and waits for the ports to be released; `restart` is stop, a
two-second pause, then start; `status` prints each service's URL, running state,
pid and whether `/api/readiness` and `/api/hta-summary` answer, including through
the Vue proxy; `logs [r|api|vue] [lines]` tails one service or all three.
`.gitignore` now covers `.dev.pids` and `.dev-logs/`, and the script is
executable. Nothing in the script uses ports 80 or 443, Docker or deployment
configuration.
Tests performed: `./dev.sh status` before starting correctly showed the
pre-existing 8788 and 5173 processes as running and FastAPI on 8000 as not
running; `start` reported the two existing services as already running, adopted
them, and started FastAPI (health and both endpoints verified afterwards);
`restart` stopped all three and started fresh ones, after which all six endpoint
checks reported ok — including `/api/hta-summary` on 8788, which the
pre-existing process predated, and through the 5173 proxy, whose target is now
FastAPI; `start` run again reported all three as already running (idempotent);
`logs` returned the plumber, uvicorn and Vite output and `logs api 6` /
`logs vue 4` returned single-service tails, with an invalid service name
returning a usage message and exit status 1; `stop` stopped exactly the three
recorded services, released 8788, 8000 and 5173, removed the pid file and left
the unrelated listeners on 7788 (Shiny) and 5174 untouched; deleting `.dev.pids`
and running `stop` again exercised the fallback, which stopped only the listeners
on the three development ports and again left 7788 and 5174 alone. Independent
checks from PowerShell confirmed HTTP 200 for `/api/health` and
`/api/hta-summary` on both APIs, for `/` on 5173 and for `/api/hta-summary`
through the 5173 proxy, with Shiny on 7788 still answering; the Vue app was
reloaded in a browser, reported "R model ready · 2 workers", listed all eight
tabs and ran the HTA decision summary through the new proxy. All three services
were left running: R Plumber 8788, FastAPI 8000, Vue 5173.

Completed: Batch 4 of the approved UX revamp (DHT readiness, value-based price,
HTA decision summary), frontend plus the one approved publication change in the
API contract (`api/plumber.R`, `api/api_contract.md`). No R model logic,
threshold, distribution, calculation, endpoint behaviour, Shiny file, tutorial or
export changed; Vue stayed presentation-only; no new package was added.

**Readiness inputs are grouped and spaced.** The wrapping control row was
replaced by a panel-specific stacked layout (`.controls--readiness`) that builds
one row per control from the assumptions panel's own field parts, with the field
label and its InfoTip on the same line and the input, select or checkbox plus its
unit on the next line. Numbers are grouped under the headings R itself returns in
each spec's `group` field (Population and access; Engagement; Workflow burden;
Language access; Accessibility), and the two dropdowns form an "Interoperability"
and an "Algorithm governance" group. The shared setting note sits beneath the
clinical-target-population control. Every value, range, step, level set, label and
group comes from `GET /api/defaults`; nothing is scored or thresholded in Vue.

**The one interoperability definition that already existed in R is now
published.** `tutorial_interop_definition` — "Interoperability means the
intervention can exchange and use information with other relevant health or
digital systems." — was added to `COLUMN_INFO_KEYS`, so `readiness_choices()`
returns it as the `info` field of the interoperability choice set, and it is
attached to that control as an InfoTip. This is the *only* wording exposed
(`readiness_parameter_specs()` still returns `""` for every readiness number
except `review_minutes`, and `info_text` now documents eighteen explanations with
this single tutorial exception). Algorithm governance deliberately received no
definition: no such wording exists anywhere in R or Shiny, and none was invented,
so the field hint states that the levels themselves describe how the model
oversight is configured.

**Value-based price is decision support, not an implementation description.** The
tab now reads in the order a decision-maker needs: the three cards (maximum
acceptable annual price with R's status band, the current annual price, the price
headroom with its share of the current price), the two-bar comparison chart, R's
plain-language summary of that comparison, and then a callout for the
required-effectiveness figure carrying R's `verdict_label` (`Met` / `Not met`) as
a badge and R's required sentence as its body. Two closed disclosures hold the
rest: "What this price means" (R's `limitation`, the threshold and current price,
R's reasons for anything it could not identify, and the assumptions and model
results the price rests on) and "Explore price scenarios" (the 3 × 3 scan, R's
summary and note, the best and worst combinations, and the per-combination detail
table). Removed from the interface entirely: the solver's name and its
`method_note` (bisection, tolerances, fallback), the availability flag list, the
request-completeness paragraph, the raw solved price and availability columns in
the scan detail, the engineering rows of the scenario table (price cost response,
cost at a price of zero, price contribution), R's raw `not_met` verdict id, and
the duplicated illustrative-data notice. The not-available states, the Calculate
gating, the stale warning and the error path are unchanged; nothing is sent before
the button is pressed.

**Value-based price comparison chart (new, frontend only).**
`charts/ValueBasedPriceComparison.vue` draws two horizontal bars from
`current_price` and `headline.max_acceptable_price` and prints R's
`headroom_eur` / `headroom_pct` sentence beneath them. Bar colour comes from R's
`status` through the same status-to-tone mapping used everywhere else, the axis
maximum is derived only from the two values it is given, and where R did not
identify a price the chart shows R's wording instead of a bar. No value is
computed, classified or reinterpreted in TypeScript.

**HTA decision summary is headline-first with contained detail.** The panel keeps
the R-status accent (`panel--decision is-bad`), shows the overall position and
"n of 5 domains assessed" in a single card, follows it with R's primary
interpretation, the incomplete-state warning and R's notice, and contains the
rest: "Decision dashboard (5 domains)", "Evidence priorities (9)", the unchanged
"Traffic-light rules used" and "Availability of the upstream analyses". Every R
string — position, interpretation, `evidence_priorities.summary`, `evidence_note`,
`rule_note`, `rules` and the notice — is rendered verbatim beside the table it
explains, and no string was duplicated.

**The optional value-based price insight reads existing state only.** When
`model.valueBasedPrice` holds a result from this session the panel adds one
`.insight` block with R's maximum acceptable annual price, current price,
headroom and `headline.interpretation`; when nothing is stored it renders
nothing, shows no "missing analysis" warning and leaves the position untouched.
The value-based price result was deliberately *not* added to the
`/api/hta-summary` request body, its five availability flags or its gating, so
opening the summary still issues no value-based price request and the endpoint's
contract is unchanged.

## Next planned task

Deployment is the next piece of work, and it now has a written plan but no files:
the repository is release-ready (the whole browser stack is tracked, R and Python
dependencies are reproducible), and what remains is the VPS configuration - the
Caddy site block, the `eqalb-api` systemd unit, the server-local environment example
and the deployment runbook. Those templates are not created yet and wait for
explicit approval. The plan's other open items are unchanged: the deployment targets
one domain behind Caddy with FastAPI on `127.0.0.1:8000` and the R worker as its
child process on stdin/stdout, and the legacy Shiny application stays a reference
that is not deployed to the VPS (its Posit Connect manifest is unchanged).

Guided Tutorial Part 2 is complete: all five sections (Case brief, Value for
money, Budget impact, DHT readiness, Recommendation) are implemented in the
browser stack and validated against R, and the user-visible retry flow (the
completion card's "Retry Part 2 with different assumptions") is implemented and
verified as well; R's retry rule is covered by the parity check.

The base-app UI-polish pass recorded under Current task is implemented and
verified, and pauses for visual review; nothing further is planned on it, and any
follow-up change waits for the review's outcome.

Batches 1 to 4 of the approved UX revamp are complete, the polish batch that
followed the final acceptance review is implemented, and the tornado chart defect
found by the follow-up diagnostic is fixed: every analysis tab marks
a stored result as computed from earlier inputs through one shared notice, Escape
closes every secondary-information disclosure app-wide through one composable,
the sidebar helper names all analysis tabs, the two tabs that had no subtitle have
one, and the tornado draws one bar per R-returned parameter at that parameter's own
two bound outcomes (see the update log for the ECharts cause and the fix). No later
batch has been specified or started, and no deferred P2 item
starts without explicit approval (the twelve deferred and one closed P2 findings
are recorded in `FRONTEND_PLAN.md`). The Vue
full-analysis application has been validated end to end. Phase 3 of
`FRONTEND_PLAN.md` (session state, saved scenarios, the remaining exports) is the
next larger unapproved piece, and two smaller follow-ups stay open: the value of
information tab's stale warning could not be exercised without running a PSA, and
the browser tab label still capitalises "Value-based Price" while the panel
heading, R's own writing and every other tab label are sentence case (App.vue is
outside the last batch's file scope). Two further notes are open: the OWSA
interpretation does not yet describe one-sided structural ranges in its own words
(the parameters are named and the robustness conclusion is stated, but a horizon
range that sits wholly above its base is not called out), and population EVPI
remains unimplemented.

## Update log

| Date | Change | Verified? |
|---|---|---|
| 2026-10-13 | Repository-release preparation, repository only, nothing committed; it supersedes the earlier note that left `app.R` unstaged. (1) `app.R` is staged after review: it is a coherent, complete Shiny-reference revision whose 335 insertions and 925 deletions move presentation constants and helpers out of the file into the shared modules rather than changing behaviour. All 14 removed definitions are defined in `eqalb_readiness.R`, `eqalb_km_interpretation.R` or `eqalb_ui_copy.R`, which `app.R` now sources alongside the existing three. (2) Python dependencies are reproducible: `api/requirements.txt` records exact pins for the two direct dependencies (`fastapi==0.143.0`, `uvicorn==0.54.0`) instead of the previous `>=` ranges, and the new `api/requirements.lock.txt` records the complete resolved closure (`annotated-doc==0.0.5`, `annotated-types==0.8.0`, `anyio==4.15.1`, `click==8.5.0`, `fastapi==0.143.0`, `h11==0.16.0`, `idna==3.20`, `opentelemetry-api==1.45.1`, `pydantic==2.14.0`, `pydantic_core==2.50.0`, `starlette==1.7.0`, `typing-inspection==0.4.4`, `typing_extensions==4.16.0`, `uvicorn==0.54.0`) generated with `pip freeze` from the environment that passed the local health check. No dependency-management system was added and no package was added beyond what FastAPI and Uvicorn already resolve | Yes - `app.R` parses (108 top-level expressions) and sources cleanly with every module; a `codetools::findGlobals` sweep of its `server` closure reports 255 global references with 11 unresolved names, and the committed baseline reports the identical 11 (`icer`, `incremental_cost`, `incremental_qalys`, `inmb`, `meets`, `net_budget_impact`, `parameter`, `scenario`, `strategy`, `wtp`, `year`), all pre-existing non-standard-evaluation and nested-formal artifacts, so the revision introduces no new unresolved symbol; every one of the 14 removed definitions resolves to a module definition and none is lost; the relocated "Simulated illustrative data - not clinical evidence" credibility strings are present in `eqalb_km_interpretation.R` (lines 130, 191, 192), and the file's occurrence count fell from 6 to 4 rather than gaining any; a pattern sweep for debug code, secrets, absolute paths, `setwd(`, `runApp`, `Sys.getenv`, TODO/FIXME and hardcoded ports returned zero in both revisions; the Shiny reference was started and served `HTTP 200` in 32.9 s with the title "eQalb interactive model", 121,595 bytes of rendered UI, all six of its tabs, and no runtime error in the log. For Python, a fresh virtual environment (Python 3.14.8, `pip` only) installed `api/requirements.lock.txt` to a set identical to the validated environment, and the API started from it on a spare port reported `status: ok`, `model_ready: true`, one ready R worker of two configured, 17 endpoints and all eight model modules, then answered `POST /api/base-case` with ICER 298,965.51 and `GET /api/defaults` with 16 parameters, the simulated-data `notice` field still present in the JSON. `renv::status()` reports "No issues found -- the project is in a consistent state"; the existing dev API on port 8000 reports `status: ok`, `model_ready: true`, 2 of 2 workers, no startup error; `npm run lint` and `npm run build` (vue-tsc + vite) both exit 0 (704 modules). The temporary virtual environment was removed and the spare port released. No PSA was run, no model calculation, endpoint behaviour, JSON shaping, API contract, tutorial, frontend or UI-styling behaviour was touched, and the simulated-data UI notice decision is unchanged |
| 2026-10-13 | Deployment readiness, repository only, nothing committed. (1) Git tracking: `api/` and `frontend/` were entirely untracked, so a fresh clone had no API, no frontend and only the Shiny-era R files. The staged set now covers `api/` (main.py, r_client.py, r_worker.R, plumber.R, run_api.py, run_api.R, requirements.txt, api_contract.md), the full `frontend/` tree (source, `package-lock.json`, tsconfigs, vite config, `public/`, both `.gitignore` files, `README.md`), the five newer model modules (`eqalb_km_interpretation.R`, `eqalb_price.R`, `eqalb_readiness.R`, `eqalb_tutorial.R`, `eqalb_ui_copy.R`), `dev.sh` and `FRONTEND_PLAN.md`, plus the current revisions of `eqalb_markov.R`, `eqalb_owsa.R`, `readme.md`, `project_state.md`, `agents.md` and `.vscode/tasks.json`. `app.R` is intentionally not staged: it is the Shiny reference, it is not read by `api/plumber.R`'s `MODEL_MODULES`, and it is not deployed. (2) Reproducible R dependencies: `api/r_worker.R` calls `library(plumber)` but `plumber` was absent from `renv.lock`, so a restore-only server would have started with a dead worker; `renv::snapshot()` recorded `plumber` 1.3.3 plus its dependency chain `crayon` 1.5.3, `sodium` 1.4.0, `swagger` 5.32.1 and `webutils` 1.2.3, taking the lockfile from 130 to 135 packages. (3) Hygiene: the root `.gitignore` gained rules for Node and Python dependency directories, local build output, `dist/`, `*.tsbuildinfo`, environment files (with `*.env.example` deliberately left trackable for the deployment templates), private keys and certificates, caches and editor/OS temporaries, with every pre-existing rule preserved | Yes - staged set reviewed with `git ls-files` (111 tracked files, 101 staged changes) and materialised with `git checkout-index --prefix` into a scratch directory, which contains all eight `MODEL_MODULES` named in `api/plumber.R`, `api/main.py`, `api/r_client.py`, `api/r_worker.R`, `api/run_api.py`, `api/requirements.txt`, `.Rprofile`, `renv.lock`, `renv/activate.R`, `renv/settings.json`, the whole `frontend/` source tree and both `.gitignore` files, and contains no `api/.venv`, `frontend/node_modules`, `frontend/dist`, `renv/library`, `.dev-logs` or `.dev.pids`; a pattern scan over the staged content found no private keys or credentials. `renv::status()` reports "No issues found -- the project is in a consistent state"; the lockfile diff is purely additive (169 insertions, 0 deletions) with the recorded R version still 4.5.1; `plumber` 1.3.3 resolves from `renv/library/windows/R-4.5/x86_64-w64-mingw32/plumber` and is recorded as `Source: Repository`, `Repository: CRAN`; every new ignore rule fires for a representative path, while `deploy/api.env.example`, `.env.example`, `frontend/src/main.ts` and `api/requirements.txt` stay unignored. `GET http://127.0.0.1:8000/api/health` returns `status: ok` with `model_ready: true`, `configured_workers: 2`, `ready_workers: 2` and `r_model_error: null` across all 17 endpoints; `npm run lint` and `npm run build` (vue-tsc + vite) both exit 0. No PSA was run, no model logic, endpoint behaviour, JSON shaping, API contract, tutorial, UI or PSA behaviour was touched, and the simulated-data UI notice is unchanged |
| 2026-10-13 | Part 2 Recommendation retry availability, frontend only (pending visual review): the Recommendation screen offered "Retry Part 2 with different assumptions" only inside the completion card, which `Part2Recommendation.vue` renders when R returns `conditional_adoption` (`recommendation.complete`). A learner who had completed all three exercises but whose case returned any other outcome — Case C is built so value for money fails at every price in the 150 to 360 lever range — reached the Recommendation screen with no retry action at all. The component now renders the same button in a `v-else` retry row (`div.tutorial__nav`, `data-part2-retry-row`) after the engagement note, so Retry is available whenever the Recommendation screen is reached; both buttons emit the single existing `retry` event bound to `session.retryPart2()`, so the case draw, the state reset, the return to Case brief and the completion clearing are exactly the completion card's own behaviour. R's recommendation logic, completion definition and outcome values, the completion popup, its gating and its actions, and the completion card itself are unchanged, and no notice was added | Yes - `npm run build` (vue-tsc + vite) and `npm run lint` pass. In the browser: with three exercises done and `recommendation.complete` false (Case B at €300/40%, outcome `do_not_recommend`) the retry row is present with the completion card absent, and the row survives dismissing the popup; activating it drew a different case (Case C to Case B) and returned to "Section 1 of 5. Case brief" with the fixed facts disclosure closed and the popup not re-shown; a second retry drew Case A from Case B, and a third drew Case B from Case C, so the exclusion of the previous case holds. The popup gating still matches the exercises: absent on Recommendation with no exercises and still absent after one, present after all three with both its "Open analysis" and "Back to the recommendation" actions, while the retry row stays available behind it. With `recommendation.complete` true the completion card is unchanged (Retry plus "Open full analysis") and the retry row is absent. At 390 px the button is 269 px wide inside the viewport with no horizontal overflow (`scrollWidth` = `clientWidth`), in dark mode it takes the dark palette (`rgb(230, 237, 241)` text), and keyboard focus plus Enter on the row draws a new case. No console or page errors in any run. No PSA was run |
| 2026-10-13 | Final full-journey validation pass with one minimal fix. The whole user journey was re-verified end to end: no welcome overlay on load, the overlay on the first dashboard open (once per session, Escape/backdrop/Start-tutorial paths, never returning after reload or after entering the tutorial), Part 1 completed with its three completion actions ("Open full analysis" reaches the nine-tab dashboard, "Restart tutorial" returns to Step 1, the green "Start Part 2: Commissioning case" entry), Part 2 with a freshly drawn case and restored brief (Case B, facts collapsed, 14 rows), the five sections, the completion popup gated on genuinely completing value for money, budget impact and DHT readiness (absent while only opening sections), its "Open analysis" landing on the dashboard, Retry drawing a different case (Case B to Case C) with price, coverage and readiness answers reset to the new case's defaults and no popup re-shown, Part 1 defaults restored on reload, the nine dashboard tabs, the centred project description, the PSA prompt at 1,000+ draws with Cancel sending no request and Continue sending it (the request was aborted so no PSA ran), the plane legend's reserved band, the relocated chart subtext in the five tabs, the ranked-outcome and assumption-group information buttons, "Algorithm governance", and the absence of the simulated-data notice. One defect was found and fixed: `HtaSummaryPanel.vue` threw and blanked the whole tab whenever R's `availability.missing_inputs` or `not_assessable_domains` held exactly one entry (plumber `auto_unbox` sends a bare string, and the panel called `.join`) — reachable by running the PSA and skipping the value of information (`"evpi"`, `"Decision uncertainty"`). A 6-line `asList()` boundary normaliser fixes both fields; no API, R, type or copy change. Frontend only | Yes - `npm run build` (vue-tsc + vite) and `npm run lint` pass. In the browser (1440 px and 390 px, light and dark): the welcome overlay appears only on the first dashboard open per session with "Start tutorial" focused, is dismissed by Escape and by the backdrop, and does not return after a reload or after entering the tutorial; Part 1's four steps update their results (price 360 to 370 moved incremental cost to €2,518.48) and its completion card carries "Open full analysis", "Restart tutorial" and the green (`rgb(46,125,79)`) Part 2 entry; Part 2 drew Case B with the facts disclosure closed (opening shows 14 rows) and no "highest acceptable negotiated price"/"maximum affordable coverage" line or traffic-light styling in DHT readiness (0 styled elements there); the popup appeared only after the three exercises produced results from the learner's own changes and offered "Open analysis" and "Back to the recommendation"; Escape closed it and it did not return; Retry drew Case C with price €360, coverage 100% and the four readiness answers at their defaults; completing Case C's exercises led to the popup (fresh session) and its "Open analysis" opened the nine-tab dashboard; the plane's legend text ends at y≈52 with the plot starting at y=104 (≈52 px clearance) at 930 px and the same band at 296 px; the base case, budget impact, survival, sensitivity, readiness, value-based price (10.8 s, loading card shown, €155.03/€360.00/−€204.97) and HTA summary all ran and rendered with no notice element; the PSA prompt showed the exact copy with Continue focused, Cancel left the iteration field and sent nothing, Continue sent the run and Escape dismissed the prompt; every tab reported no horizontal overflow at 390 px (scrollWidth = clientWidth) with no clipped inputs; the description is centred at both widths; keyboard navigation moved and selected tabs with the arrow/Home keys, opened a disclosure and an information button with Enter, closed the popover with Escape (returning focus) and with an outside click; under `prefers-reduced-motion: reduce` the loader bar is a still full-width 0.45-opacity line and the trace has no dash and no animation, while the normal-motion probe shows `app-loading-trace` with `22px, 178px`; the ten assumptions information buttons and the three group headings all measure on their label's line to the right (5 px gap); and the HTA summary fix was re-verified in four states (one missing field, one not-assessable domain, two missing fields, all supplied) with no page error. No PSA was run and no screenshot shows a visual defect; the only page error seen was the reproduced `missingInputs.join` crash before the fix |
| 2026-10-13 | Assumption-group information buttons, presentation only (pending visual review): the Assumptions panel's "Event costs", "Discounting" and "Time horizon" group headings now carry an `InfoTip` inside the group's `<summary>`, immediately to the right of the heading text, opening the requested plain-language sentence for each (event costs and what they do to total cost; discounting and why future value is reduced; the horizon and what a longer one captures). The three sentences are interface copy, because R's `CC_INFO_TEXT` defines individual parameters and publishes nothing for group headings; none states a value, range or rule. No assumption value, calculation, API call, request body, model logic or result behaviour changed, `eqalb_tutorial.R`/`api/main.py`/`api/plumber.R`/API types/client were not touched, and no notice was added. `frontend/README.md`'s "Explanations are R's text" section now lists three interface-copy subjects (chart subtext, the readiness algorithm-governance sentence, and these three group sentences) | Yes - `npm run build` (vue-tsc + vite) and `npm run lint` pass. In the browser, with a real mouse click: each button measures 5 px to the right of its heading's own text box on the heading's line (Event costs / Discounting / Time horizon), the other three groups (Intervention, Clinical, Utilities) carry no button, and each popover opens with the exact requested copy ("Event costs are the costs associated with clinical events…", "Discounting reduces the value placed on costs and outcomes that occur in the future…", "The time horizon is how far into the future the model follows patients…"). Activating a button does not toggle its disclosure (all groups stay open) while clicking the heading itself still toggles and restores its group; the panel also opens with keyboard focus + Enter; Escape and an outside click both close it and leave the group open. At 390 px (sidebar opened through its own toggle) all three buttons keep the 5 px right-hand placement on the heading line with no horizontal overflow (`scrollWidth` 380 = `clientWidth` 380), and at 1280 px in dark mode they sit at the same 5 px gap in the dark accent colour; popovers are fully inside the viewport at 390 px in both themes (light `rgb(255,255,255)`, dark `rgb(22,36,44)`). No console or page errors. No PSA was run and no analysis was run |
| 2026-10-13 | Base-app UI-polish pass, presentation only (pending visual acceptance). (1) Loading ECG: the card's trace pulse used one dash pattern as long as the line (22 + 78 = 100), so the dash could never leave the path and appeared to stop at the start of the trace; it is now 22 + 178 with a 22 → −100 sweep over the first 55% of the 2.8 s cycle and a hold just past the last point, so the pulse enters from the left, crosses the whole line and rests off the path on every loop (the card remains the only loader and the reduced-motion states are unchanged). (2) Project description centred via `.page--centered` (heading, prose, subtitles and actions centred; the analyses list stays left-aligned inside a centred 42 rem column). (3) PSA runs at 1,000 draws or more are confirmed first with the requested wording plus Continue and Cancel; Cancel leaves the iteration field as it is, Escape and the backdrop cancel, Continue takes focus, and the iteration count, request and draws are untouched. (4) The PSA plane's legend (up to five wrapped entries) now sits in a reserved band above the plot (`grid.top` 104, 11 px legend text, item gap 10) so it cannot overlap the chart at any width. (5) The explanatory subtext under the charts in the base-case, PSA, simulated-survival, value-of-information and value-based-price tabs moved verbatim into an `InfoTip` beside each chart's header, and the chart components no longer render it; the CEAC's threshold probability is now read by both the chart's marker and the panel's button through one shared `probabilityAtThreshold` helper (`components/charts/ceac.ts`), and the value-based-price chart's now-unused headroom/availability props were dropped with their bindings. (6) The sensitivity tab's ranked-outcome selector gained an information button ("Choose which result is ranked to show which assumptions have the greatest effect on that outcome."). (7) The shared placement rule: `.field label` is inline-block and `.field > span:not(.infotip)` keeps the block treatment, so an InfoTip after a label sits on the label's line to its right — applied to the assumptions form, budget-impact controls, readiness inputs, sensitivity selector and the tutorial's Part 2 fields — and `.infotip__trigger` keeps its lowercase "i" in uppercased contexts. (8) The readiness tab's "Algorithm governance" heading gained an interface-written information button (R publishes no wording for that choice set). (9) The last per-result `notice` lines (seven panels) and the survival tab's appended disclaimer are gone, with the `.notice` rule and the log-rank line cut at the response's own `notice` string. No model, calculation, API contract, R logic, recommendation logic or result behaviour changed; `eqalb_tutorial.R`, `api/main.py`, `api/plumber.R`, the API types and the client were not touched, and no tutorial behaviour, completion logic, welcome overlay or Part 2 gating changed | Yes - `npm run build` (vue-tsc + vite) and `npm run lint` pass. On the dev server (light and dark, 1280 px and 390 px, no horizontal overflow anywhere): the ECG probe (the component's own markup and classes) sampled over six seconds shows the pulse's offset spanning 22 → −100 with a visible dash length of 0 → 22 → 0 and no stall, and the real card appeared during a value-based-price run with the dasharray `22px, 178px` and the −100 hold; the project description computes `text-align: center` for title, prose and subtitles with the list centred as a block (273.5–945.5 inside 199.5–1019.5 at desktop, 39–341 inside 20–360 at 390 px); the PSA prompt text matches the requested wording exactly, no request leaves before Continue (verified by aborting `/api/psa`), Cancel closes it with no request, Continue sends the run, and 100 iterations sends it with no prompt; the plane's legend (five entries) painted its last row at ≈49 px and the plot's first content at ≈100 px at both 296 px and 378 px canvas widths; every chart header in the five tabs carries its information button with the relocated text (checked by opening each: the base-case ICER + threshold sentence, the plane note, "At €100,000/QALY the model reports 47.5% of iterations cost-effective", the Greenwood band note, the EVPI readout and the EVPPI caveat, and R's headroom sentence) and `.chart__note` counts are zero in all five; the ranked-outcome button sits on the selector's line with the requested sentence; ten assumptions buttons, both readiness row buttons and the tutorial Part 1 field rows all measure on the label's line to its right with the control below; the Algorithm governance button sits beside that heading with its sentence; no `p.notice` remains on any tab and a value-based-price run (the only analysis run for it) shows R's real headroom line in the button, while a readiness run, a budget-impact run, a survival run, a sensitivity run and an HTA-summary run all render with no notice element and no page error; R's own sentences that mention "not clinical evidence" (the KM "Evidence credibility" status and interpretation, the HTA interpretation) are unchanged and were left alone. Two tabs that need a PSA draw (PSA, value of information) were laid out for the checks by writing a synthetic result into the session store in the browser only — no model run, no API call — and the page was reloaded afterwards. No PSA was run; the only analysis runs were the base case, budget impact, survival, sensitivity, readiness, HTA summary and value-based price |
| 2026-10-13 | Part 2 completion gating corrected, frontend only (`useTutorialSession.ts`, `Part2View.vue`). The completion popup now waits for genuine completion of the three exercises instead of a visit: Value for Money and Budget Impact count once a result has come back from the learner's own change to their control, and DHT Readiness once a readiness answer has been submitted and a result has come back. A change is recorded as pending when the control moves and is promoted only when the evaluation it asked for succeeds, so a failed request cannot mark an exercise done; the case's own starting evaluation, which R produces before the learner touches anything, never counts. A new case (including Retry) clears the completions, because they belonged to the case just retired. The popup also gained a second action, "Back to the recommendation", so dismissing it returns to the completion card — whose own "Retry Part 2 with different assumptions" and "Open full analysis" actions are untouched — alongside its existing "Open analysis" and its Escape and backdrop dismissal. No model, calculation, API contract, case-selection, readiness, recommendation or results behaviour changed, and the popup still reports exercise completion rather than R's outcome | Yes - `npm run build` (vue-tsc + vite) and `npm run lint` pass, and the dev server serves the new modules. In the browser: opening all three sections without touching their controls shows no popup; completing Value for Money only shows no popup; completing Value for Money and Budget Impact shows no popup even though R's outcome is already conditional_adoption at that point, which is direct evidence the popup is gated on the exercises rather than on the result; completing DHT Readiness as well makes the popup appear once, offering "Open analysis" and "Back to the recommendation"; dismissing it keeps the learner on the recommendation with "Retry Part 2 with different assumptions" reachable, and it does not return on later visits; Retry drew a different case (p2c-4d81a0 to p2c-13c7d2), returned to the Case brief, reset the price to the new case's €360 default and did not show the popup again; at 390px the popup appears with both actions inside the viewport (panel 16–374 of 390) and Retry is reachable after dismissal; in dark mode the panel is unchanged at rgb(22,36,44); the six previously accepted polish items still hold (welcome overlay on the first dashboard open only, green Part 2 entry rgb(46,125,79), facts disclosure collapsed by default, no highest-price or maximum-coverage lines, InfoTips present, slice sentence absent, Part 1's three actions and nine dashboard tabs); no console or page errors. No PSA was run |
| 2026-10-13 | Welcome-overlay trigger moved, `frontend/src/App.vue` only: the once-per-session question now appears the first time the analysis dashboard is opened — the reference Shiny app's own trigger — instead of on initial app load. Nothing appears on load or on Home; opening the dashboard shows it over the dashboard that is already open behind it; "Start tutorial" opens the tutorial, "Open analysis" simply puts the overlay away (the dashboard is already there), and Escape or the backdrop dismisses it. The session flag is written before the overlay opens, so it cannot reappear later in the session, after a reload, or after entering the tutorial by any other route. Copy, buttons, modal pattern, focus, Escape behaviour, light/dark and 390px support are unchanged, as is every model, calculation, API, tutorial, recommendation, dashboard and Part 1 behaviour | Yes - `npm run build` (vue-tsc + vite) and `npm run lint` pass, and the dev server serves the new module. In the browser: no overlay on initial load, none after a reload on Home, and none when the tutorial is entered by its own button; it appears on the first dashboard open (nine tabs open behind it), focuses "Start tutorial"; Escape dismisses it and it does not return on a later dashboard open or after a reload in the same session; "Start tutorial" opens the tutorial with the overlay gone and it does not return afterwards; "Open analysis" leaves the dashboard open with the overlay gone; the copy and buttons are the exact requested wording; light `rgb(255,255,255)`, dark `rgb(22,36,44)`, and at 390px the panel is 358px wide with `scrollWidth` 390 and Escape still works; no console or page errors. No PSA was run |
| 2026-10-13 | Part 2 UI-polish pass, presentation only (pending visual acceptance): the Part 1 completion card's Part 2 entry is green via one new `.btn--success` class built from the existing success tokens; a once-per-session welcome overlay ("New to health economics?", "Start tutorial" / "Open analysis") reuses the app's modal pattern with Escape and backdrop dismissal; the Case Brief's fixed facts became a collapsed `<details>` (R's own facts heading is the summary, glossary inside, all 14 rows unchanged); the "Highest acceptable negotiated price" and "Maximum affordable coverage" lines were removed from Value for Money and Budget Impact while their state messages, hints and charts stay; explanatory subtext moved into InfoTips (test notes, lever hint into the lever's existing popover, the curve's method note into the caption's, budget scope and phased-adoption notes into the coverage popover, readiness and recommendation intros); the repeated "This slice of the tutorial covers all five sections…" sentence is no longer rendered; and a completion popup appears once, on the Recommendation screen, after Value for Money, Budget Impact and DHT Readiness have each been opened, with "Open analysis" moving straight to the full analysis. No model, calculation, API, contract, case-selection, readiness, recommendation or results behaviour changed | Yes - `npm run build` (vue-tsc + vite) and `npm run lint` pass. On the dev server: the welcome overlay shows the exact requested copy and buttons, focuses "Start tutorial", dismisses with Escape, does not return after a reload in the same session or after entering the tutorial, and fits at 390px (narrowest panel 358px, `scrollWidth` 390) in light and dark; the Part 2 entry computes to `rgb(46,125,79)` on white in light mode and `rgb(76,175,125)` on `rgb(11,20,24)` in dark; the facts disclosure is closed by default with no rows visible, then opens with all 14 rows and the same "Manufacturer's reference price" €150 row; neither removed line appears anywhere while the price state card, budget state card, curve and state hints remain; the value section carries three information controls and the budget section two; the popup does not appear when Recommendation is opened before the three exercises, appears when they have been visited in any order, closes with Escape without navigating, does not return, and its "Open analysis" lands on the dashboard (nine tabs); Part 1's completion card keeps all three actions and Part 1 results still report "Results updated."; no console or page errors. No PSA was run |
| 2026-10-12 | Final Part 2 wording correction, copy only. In `eqalb_ui_copy.R` the `part2_price` InfoTip's floor sentence was replaced with "The manufacturer has proposed a starting price. Your task is to negotiate a price that offers value for money at the payer's threshold. The manufacturer's reference price is provided as context, not as the target answer."; the lever explanation that preceded it is unchanged, as is the entry's id and count (31 InfoTips). In `eqalb_tutorial.R` the unrendered `brief.policy` field, which no component, client or test reads — removal would have required changing the `Part2Contract` type, so the specified fallback was used — now reads "The manufacturer has proposed a starting price of €360 per active user per year. Your task is to negotiate a price that the health service could responsibly fund." No value, case fact, threshold, calculation, readiness/recommendation/value-for-money/budget logic, evaluate or contract shape, `manufacturer_minimum_price` field name, `app.R`, `readme.md` or `api/api_contract.md` was touched | Yes - both R files parse; the module returns the new InfoTip and the new policy string, and neither file contains "minimum acceptable" any more. Through the API and the running dev app: the Value for Money InfoTip matches the new wording exactly (still opening with the lever explanation), no learner-visible text anywhere in Part 2 or the dashboard contains "minimum acceptable" or "floor for the negotiation", the facts table still reads "Manufacturer's reference price | €150.00 per active user per year" across all 14 unchanged rows, the overlay hint keeps the previous pass's wording, and Case Brief, Value for Money (chart), Budget Impact, DHT Readiness, Recommendation, all nine dashboard tabs and Part 1's four steps still render with no console errors. `npm run build` and `npm run lint` pass. No PSA was run |
| 2026-10-12 | Part 2 case-facts wording corrected in R (`eqalb_tutorial.R` only, two strings). The facts-table row label "Manufacturer's minimum acceptable price" became "Manufacturer's reference price", and the Case-facts overlay hint was replaced with "The manufacturer's reference price is a starting point for negotiation. Your task is to recommend a price and initial coverage level that offer value for money, fit the available budget, and can be delivered in practice." The €150 value, all fourteen case facts, every calculation, the evaluate request/response contract, the value-for-money, budget, readiness and recommendation logic, the Case Brief Vue copy, the dashboard and Part 1 are unchanged; `app.R` carries its own copies of both strings and was not touched | Yes - `parse("eqalb_tutorial.R")` is clean, the sourced module returns the new hint and a 14-row payload whose only change is the label, with the old label absent and €150 still the value. Through the running API and browser (dev server, API restarted so the R workers reloaded the module): the facts table shows "Manufacturer's reference price | €150.00 per active user per year", the old label and the old hint are absent from the whole brief, the Case-facts overlay hint matches the new wording exactly and closes with Escape, and the value-for-money chart, all five sections, the recommendation checklist, all nine dashboard tabs and Part 1's four steps still render with no console errors. `npm run build` and `npm run lint` pass. No PSA was run |
| 2026-10-12 | Part 2 narrative and UI-polish pass, frontend only (`Part2Brief.vue`, `Part2View.vue`, `Part2Readiness.vue`, `Part2Recommendation.vue`, `styles.css`). The Case Brief now leads with its task ("What funding position will you recommend?"), frames the manufacturer's €360 as a starting proposal for negotiation ("The manufacturer has proposed a starting price of … Your task is to negotiate a price that the health service could responsibly fund.") and no longer calls €150 the lowest acceptable price; €150 remains only as the facts-table row R labels "Manufacturer's minimum acceptable price". R's `case.summary` is no longer rendered, because two of the three summaries state how many prices or how much coverage pass; a Vue-owned neutral case-difference line keyed by R's own case title replaces it, with a fallback that describes nothing. DHT Readiness and Recommendation gained task leads; Value for Money and Budget Impact keep R's own task sentences, unduplicated. `.part2__task` moved from orange/red to the teal informational tokens (`--accent-soft` / `--accent`), so a task can no longer read as an error. No model, calculation, API contract, case-selection, readiness, recommendation, navigation or result behaviour changed, and no R, API, TypeScript-contract or Part 1 file was touched | Yes - `npm run build` (vue-tsc + vite) and `npm run lint` pass. On the production build with the API proxied: the brief narrative contains none of "minimum acceptable", "lowest price it will accept", "value-for-money test", "wider range of prices", "fits the budget" or "less coverage", and "minimum acceptable" occurs exactly once, in R's own facts-table row; all three cases' neutral lines were checked against their titles with no forbidden phrase and no outcome implication. Every rendered value equals the live R payload: all fourteen fact rows, the price state, detail, maximum and answer line, the coverage control and maximum affordable coverage, the budget state and all five budget rows, the seven readiness domains, the recommendation status, headline and message, and the four checklist verdicts. Task leads confirmed on all five sections. `.part2__task` computes to rgb(234, 241, 243) / rgb(23, 107, 115) in light and rgb(30, 48, 57) / rgb(127, 209, 216) in dark. 390px shows no horizontal overflow on the brief or the value section (scrollWidth 390). Retry, reached from a conditional-adoption state, drew Case C after Case B, returned to the Case brief and restored R's defaults (price €360, coverage 100%, readiness answers). No console or page errors. No PSA was run |
| 2026-10-12 | App loading state made robust, frontend only, `frontend/src/composables/useAppBusy.ts` plus its five call sites. `start(label)` now returns that operation's own completion token: it settles exactly once, is idempotent (a stray second call cannot decrement another operation) and clears the operation's watchdog; `finish()`, `isActive` and `label` stay on the exposed object. All five call sites — `useModel`'s `loadService` and `run`, and `useTutorialSession`'s `loadPart2Contract`, `createPart2Case` and `evaluatePart2` — hold the token and call it in their existing `finally`, so a rejected, cancelled or unmounted operation cannot skip the clear. One one-hour watchdog per operation, chosen as twice the slowest run the interface can request (a 10,000-draw PSA, about 30 minutes at the measured 0.18 s per iteration) and four times the API R worker's default 900 s timeout, clears a completion that never arrives and warns with the operation's label only under `import.meta.env.DEV`. No change to any visual design, threshold, ECG animation, API contract, tutorial logic, model behaviour or navigation | Yes - `npm run build` (vue-tsc + vite) and `npm run lint` pass, and the production bundle contains the watchdog (`36e5`) with the warning string eliminated, so the warning is development-only. A rejected operation (the request aborted after 900 ms) showed the bar at 401 ms, cleared the state at 941 ms, kept the existing not-reachable message, left the button usable and the next run still showed the bar at 381 ms and the card at 2541 ms and cleared on completion. A never-settling operation was recovered by the watchdog with its delay clamped in the harness (never in app code) to 3 s: bar 401 ms, card 2541 ms, cleared 3041 ms, and the development warning `[eQalb] "Running the sensitivity analysis…" was still busy after 60 minutes and has been cleared.`; the same hang on the production build cleared at 3041 ms with no warning. Two unmount checks — leaving the dashboard during an OWSA run and leaving the tutorial during a Part 2 case draw — both cleared the loader when the operation settled, with no page errors. The full production pass was re-run and still holds: no loader for a dashboard open or a base case, OWSA bar 421 ms and card 2582 ms cleared at 5372 ms, Part 2 draw "Preparing the case…" from 2541 ms, 390 px `scrollWidth` 390 with the card fully inside, reduced motion `animation: none` with the dash removed, no focusable element in the loader and no console errors. No PSA was run |
| 2026-10-12 | Restrained app-wide loading experience, frontend only. New `useAppBusy.ts` (one ref-counted busy state with a label, exposed as `start(label)`, `finish()`, `isActive` and `label`, keeping the first operation's label while operations nest) and new `AppLoadingIndicator.vue`: nothing for 350 ms, then a thin teal bar at the top of the app, then from 2.5 s a small centred card carrying the eQalb wordmark, a low-opacity ECG line in the app's own teal (the home title's trace morphology, one dash in a 2.8 s cycle) and the operation's status sentence, with both levels removed in the same tick the last operation settles. Mounted once in `App.vue` and wired only where a wait is real — `useModel`'s service load and its nine explicit analysis runs, and `useTutorialSession`'s Part 2 contract load, case draw (the card shows R's own `entry_busy_label`) and evaluation. It is not a modal (no backdrop, nothing focusable, `pointer-events: none`), and under `prefers-reduced-motion` the bar is a still full-width line and the trace is drawn complete. No model calculation, API contract, tutorial logic, navigation behaviour or existing result was touched, and no endpoint, dependency, design system or theme engine was added | Yes - `npm run build` (vue-tsc + vite) and `npm run lint` pass. On the production build served with the API proxied: the dashboard open and a base case showed no loader; OWSA showed the bar at 441 ms and the card at 2.6 s reading "Running the sensitivity analysis…" and cleared both at 6.98 s; a Part 2 case draw showed "Preparing the case…" from 2.5 s and cleared 3 ms after the case arrived; a Part 2 price change showed nothing; at 390 px `scrollWidth` was 390 with the card 304 px wide and fully inside the viewport; under reduced motion the bar segment and the trace pulse computed `animation: none` with the dash removed (bar full width at 0.45 opacity); an InfoTip opened and closed with Escape while the card was up, Tab order kept moving, the loader held no focusable element, and no console or page errors appeared. Part 1's four steps, Part 2's five sections and the dashboard tabs were exercised in the same runs. No PSA was run |
| 2026-10-12 | Guided Tutorial Part 2 completed, and a final cleanup. `eqalb_tutorial.R` gained the DHT-readiness exercise (its level tables, `eqalb_part2_readiness_choice()` and `eqalb_part2_readiness()`, which map the four answers onto the inputs `calculate_readiness()` already takes and return the answers, the mapped inputs, each domain's status, the five reach and workload figures, the deliverability verdict and R's two calculation-dependent sentences) and the recommendation (`eqalb_part2_recommendation()`, which chooses one of five outcomes from the three criteria and the coverage cap in the reference tutorial's own order and wording, with `complete` true only for `conditional_adoption`); all five sections are marked available and the contract note no longer says otherwise. `api/main.py` gained the four optional readiness answers and `POST /api/tutorial/part2/evaluate` returns, additively, a `readiness` block and a `recommendation` block; no new endpoint and no change to any existing field's value (`api/plumber.R` needed no change). Vue: `useTutorialSession` gained the four answers with Vue-owned defaults, sent in the same coalesced evaluation the levers use; new `Part2Readiness.vue` renders the four questions, R's reach and workload line and one closed disclosure and shows no traffic light, and new `Part2Recommendation.vue` renders R's outcome card, R's case-settings sentence, the four-criterion checklist, the seven readiness domain cards, the Deliverability card, R's engagement restatement and a completion card with an "Open full analysis" action; `Part2View` wires both, and the readiness section was then corrected to remove the traffic-light output that belongs to Recommendation. Cleanup: `eqalb_tutorial_money()` now passes `scientific = FALSE`, so the €100,000 threshold and the €3,000,000 ceiling no longer render as "€1e+05" and "€3e+06" in the contract, the case facts table or the budget blocks, and the stale `later_sections` contract block and its TypeScript field were removed. The user-visible retry flow is still not implemented, and `app.R` and the other Shiny files were not touched | Yes - R fixtures captured outside the repository backed the readiness and recommendation checks: the readiness block matched R for the defaults, one answer changed per question and the four answers omitted, with R's own "must be one of" error for an invalid id, and each of the five recommendation outcomes was checked per case with its headline and message verbatim, its `complete` flag, the four criteria it was chosen from and the outcome re-derived from those criteria; the price, curve, maximum, marker, chart and budget fields are unchanged beside both additions and the recorded Slice 1 and 2 pins still hold (€155 / €295 / €170, 2 / 30 / 5 passing points, 15 / 15 / 10 % best coverage, €15,480,000 / €17,280,000 / €20,720,000). The cleanup's before/after diff of the Part 1 and Part 2 responses shows 13 changed strings, every one of them a rendering of the €100,000 threshold or the €3,000,000 ceiling, and the removed `later_sections` block as the only other difference. Browser: 44 checks for the readiness section, then 22 focused checks after the traffic-light correction, and 46 for the recommendation — all five outcomes reached through the interface, the completion card appearing only for the conditional-adoption outcome with one "Open full analysis" action and no Retry, keyboard radio groups and Back/Next with focus moved to the new heading, the disclosure opening by Enter and closing with Escape back to its summary, the engagement line restated when the follow-up answer changes, 390px with no page-level overflow, and no console errors — plus a final smoke run confirming the checklist reads "Value for money at €100,000/QALY" and "Five-year budget impact within €3,000,000", that the readiness section shows no traffic lights, that Value for Money and Budget Impact still render their own states, and that the dashboard is unchanged. `npm run build` (vue-tsc + vite) and `npm run lint` pass. No PSA was run |
| 2026-10-12 | Guided Tutorial Part 2, slice 2, in the browser stack — the Budget impact section. `eqalb_tutorial.R` gained the Part 2 budget section: its own constants (the uptake schedule 10% in year 1 rising 5 percentage points a year, the five-year horizon, zero avoided-event savings, the €3,000,000 five-year ceiling and the 10–100% coverage cap in steps of 5, default 100%), the covered-population, coverage-step, annual-row, affordability and maximum-affordable-coverage helpers, and the budget wording and contract block; `calculate_budget_impact()` is called unchanged, the cap scales only the case's covered population, and the maximum affordable coverage is found by scanning the permitted steps from the highest down rather than by inverting the budget formula. `api/main.py` accepted `coverage` on the evaluate request and mirrors the extended contract; `api/plumber.R` needed no change because its tutorial handlers already delegate. Vue: `useTutorialSession` gained the coverage state seeded from R's returned default and sends it with the price in the same coalesced evaluation; new `Part2Budget.vue` and `Part2BudgetChart.vue` render the section (R's task and scope wording, the potentially eligible population, the coverage control with R's range and InfoTip, the affordability status card, the maximum affordable coverage, the summary and the per-year chart, and one closed annual-breakdown disclosure); `Part2View` enables the third section, keeps DHT readiness and Recommendation as disabled "Coming next" entries, and wires Back/Next and the R-owned price shortcut. Case Brief and Value for Money are unchanged. Part 2's DHT readiness and Recommendation sections, its completion card and its retry flow are deliberately not implemented, and no PSA was run. `app.R` and the other Shiny files were not touched | Yes - R fixtures captured outside the repository extended the Part 2 parity run to 11 steps (the contract, each case with its budget block, and per-case coverage scenarios at the default, the minimum, the maximum, the maximum affordable coverage and one step above it, plus a value-for-money-failing price) and matched the live API with **zero mismatches**, with all three reachable affordability states (over, below the maximum, at the maximum) observed; the run pins Slice 1 byte-for-byte, so a coverage change never moves the price curve, the current-price status or the highest acceptable price, and re-confirms that a body carrying dashboard-style fields changes nothing. Browser: 71 checks passing, run twice — the third section enabling with the two remaining "Coming next" entries, the control's R range and default, the status card for each reachable state, R's maximum affordable coverage, the drawn chart read from the canvas bitmap rather than the props, sampled tooltips matched to R's annual rows by R's own year key, the annual disclosure opening by mouse/Enter/Space and closing with Escape back to its summary, local table scrolling at 390px with no page-level overflow, dark mode, reduced motion, and Part 1 and dashboard isolation. Slice 1's 56 browser checks and Part 1's 26-scenario parity fixture and 49 browser checks were re-run and are unchanged. `npm run build` and `npm run lint` pass. No PSA was run |
| 2026-10-12 | Guided Tutorial Part 2, slice 1, in the browser stack. `eqalb_tutorial.R` gained the Part 2 section (lever constants, the three commissioning cases with their own facts and case-level post-event utilities, the 14-row facts table, the value-for-money rule, the 43-point price curve with R's per-point classification and highest acceptable price, the current-price result with its three states, the static wording and the contract); `api/plumber.R` publishes `GET /api/tutorial/part2` and the flat-registered `POST /api/tutorial-part2-case` and `POST /api/tutorial-part2-evaluate` handlers, and `api/main.py` mirrors the three published nested paths with typed request models and no R logic. Vue: `useTutorialSession` gained the Part 2 mode and state with a single-request guard on case creation, new `Part2View` / `Part2Brief` / `Part2Value` / `Part2PriceCurve` components render the shell, the read-only case-facts overlay, the brief and the value-for-money exercise, the Part 1 completion card gained a Part 2 entry whose label and sentence come from the Part 2 contract (so Part 1's response is unchanged), and `styles.css` gained the Part 2 styles plus a wrapping control row. Part 2's Budget impact, DHT readiness and Recommendation sections, its completion card and its retry flow are deliberately not implemented. `app.R` and the other Shiny files were not touched. Two defects were found and fixed during validation: a duplicate case request (the Part 2 view's mount and the Part 1 entry both asked for a case, so two draws raced) and an unbound posted curve (a curve computed for one case could be re-classified under another, because the lever's 43 prices are identical for every case; the curve now carries its `case_id` and R rejects a mismatch) | Yes - R fixtures captured outside the repository (contract; seeded and resumed draws for all three cases; each case's facts, later inputs and full 43-point curve; 12 case/price scenarios spanning the lever minimum, default, threshold crossing, highest acceptable price and one step above it) matched the live API with **zero mismatches**; the posted-curve path matched the computed path in all 12 scenarios; seeded draws were reproducible; a retry never returned the excluded case; a cross-case curve, an unbound curve, a short curve, an unknown handle and out-of-range prices each returned R's own message; and a body carrying dashboard-style fields (`utility_post_mi` 0.2, `implementation_cost` 9999, `population` 1, `intervention_price` 900) changed nothing while the three cases kept distinct post-event utilities (0.80 / 0.82 / 0.79). Browser, 54 checks all passing: the Part 2 entry from the Part 1 completion card; R's banner; all fourteen facts matching R row for row; the facts overlay opening by keyboard, closing with Escape and returning focus to its trigger; two available sections with three disabled "Coming next" entries; keyboard section switching with focus moved to the new heading; the lever carrying R's range and default; the state card updating to R's state wording and R's ICER for the new price; R's highest acceptable price on the page; the drawn curve read from the canvas bitmap rather than the props (both R series colours present, the marker a vertical line, the threshold a horizontal line); sampled tooltips matching R's row for the price they name; Back/Next navigation; Part 1 resuming at its completion card with its Step-1 results intact; dashboard inputs and its stored base-case result unchanged after Part 2 use; no page-level overflow at 390px or 768px with local table scrolling; dark mode and reduced motion. Part 1 was re-checked after the change: 26-scenario parity with zero mismatches and all 49 browser checks passing, including the fixture that asserts `contract.part1` is unchanged. `npm run build` (vue-tsc + vite) and `npm run lint` pass. No PSA was run |
| 2026-10-12 | Guided Tutorial Part 1 implemented in the browser stack, R-first. New `eqalb_tutorial.R` holds the tutorial's own defaults and control metadata, its fixed values (including the post-event utilities 0.80 post-MI and 0.60 post-stroke as explicit tutorial constants), its simplified traffic-light rules, its teaching copy and its decision-summary assembly, calling `run_eqalb_model()`, `calculate_budget_impact()`, `calculate_readiness()` and `assess_hta_decision_summary()` unchanged; `api/plumber.R` sources it, publishes it in `MODEL_FUNCTIONS` and adds `GET /api/tutorial` (the contract: defaults, control metadata, fixed values, step titles/objectives, instructional wording, rules, table headings) and the Part 1 handler; `api/main.py` mirrors both routes with a typed `TutorialPart1Request` and no R logic. Part 2, the commissioning cases, the price and coverage exercises and Part 2's readiness work are deliberately not implemented. Frontend: new `useTutorialSession` (an isolated session that never reads or writes `useModel`), `views/TutorialView.vue`, `components/tutorial/` (stepper, control, status card, cost-effectiveness plane, four steps, completion card), `api/types.ts` and `api/client.ts` additions, a Home "Guided tutorial" entry point, the `tutorial` route in `useAppView`/`App.vue`, a theme toggle in the tutorial header and tutorial styles. A control change re-evaluates all four steps in one coalesced request, matching the reference tutorial's live reactive values; the stepper and Next/Back move between steps; Restart restores R's defaults; leaving keeps the session and a reload clears it. `app.R` and the other Shiny files were not touched | Yes - R: `eqalb_tutorial.R` parses and its own R baseline captured 26 scenarios (defaults, one changed value per Step-1 control, changed eligible population, the readiness workflow boundaries 4/5/15/16, both Step-3 answers, and each reachable tutorial status: CE Green/Amber/Red, budget Green/Amber/Red, readiness Green/Amber/Red and overall Green/Amber/Red). Parity: a live FastAPI instance on a spare port returned **zero** mismatches against that baseline for the contract and all 26 scenarios (every value, status, string, table row and chart series compared), the endpoint is deterministic (identical bytes for the same body), and injecting dashboard-style fields (`utility_post_mi` 0.2, `utility_post_stroke` 0.2, `implementation_cost` 9999, `healthcare_savings` 9999, `population` 1, `intervention_price` 900) left `fixed_inputs`, `ce`, `bia`, `readiness` and `summary` unchanged. The plumber route handlers were invoked directly and matched the same baseline with zero mismatches, and an out-of-range price returns R's own `'tutorial_price' must be between 0 and 900.` Browser (49 checks, all passing, against a dev server pointed at that API): step 1-4 content renders from R; the UI's ICER equals R's reference for the default and for price 900; Enter and Space activate stepper buttons and focus moves to the new step heading; a disclosure and an information control each open by Enter, close by Escape and return focus to their trigger; Next/Back/Finish/Restart behave as specified with Restart restoring price 360; the tutorial session survives a dashboard visit with the dashboard's inputs and stored result unchanged, and the tutorial's fixed utilities stay 0.80/0.60 after the dashboard's utilities are set to 0.5/0.45; no page-level horizontal overflow at 390px or 768px with tables scrolling locally; dark mode renders dark surfaces and light text; reduced motion gives `transition: 0s` and `animation: none`; a fresh reload logs no console errors; all nine analysis tabs still render. `npm run build` (vue-tsc + vite) and `npm run lint` pass. No PSA was run |
| 2026-10-12 | Value-based price revamped into decision support, plus three small R wording changes and one R field pair (`eqalb_price.R`, `api/plumber.R`, `frontend/src/api/types.ts`, `frontend/src/components/ValueBasedPricePanel.vue`, `frontend/src/components/charts/ValueBasedPriceComparison.vue`, `frontend/src/styles.css`). The tab now leads with the price cards, the comparison chart, R's plain-language summary and a callout carrying R's new `verdict_label` badge with R's required-effectiveness sentence, then exactly two closed disclosures ("What this price means", "Explore price scenarios"). Removed from the interface: `method` and `method_note` (solver name, bisection, tolerance, fallback — still returned by the API and still in the exported package, now documented as engineering provenance), the availability flag list, the "No request field was missing"/`missing_inputs` paragraph, the raw solved price and availability columns of the scan detail, the three engineering rows of the scenario table (`price_cost_slope`, `cost_without_price`, `price_cost_contribution`), R's raw `not_met` verdict id (replaced by `verdict_label`), and the tab's duplicate illustrative-data notice — the project-level disclaimer on the Project description screen is unchanged and now the single statement of it. R wording: `eqalb_price_headline_interpretation()` no longer appends "The figure is an illustrative model result, not clinical evidence or a pricing recommendation.", its headroom share is omitted rather than printed as "(—)" when the current price is zero, and `eqalb_price_required_interpretation()` now opens "At the current price, the model requires an estimated relative risk reduction of X% among engaged users to meet <threshold>." The four unavailability sentences are also plain language now: the two that reported no non-negative price say "the model's incremental net monetary benefit is already below zero before any price is added" instead of quoting the solved price and the net monetary benefit at a price of zero, the price-bound case says "the annual price the model would need is above €1,000,000 … the highest price this analysis accepts", and the two verification failures say the model did not confirm or did not return a result — `solved_price` is still on the response for an API caller, just no longer read aloud in the sentence. Two new response fields: `limitation` (`EQALB_PRICE_LIMITATION`, the one-way qualification, shown in the first disclosure) and `required_effect.verdict_label`; `eqalb_price.R` is sourced only by `api/plumber.R`, so the Shiny application is untouched by the wording changes. Otherwise nothing moved: no calculation, threshold, solve, scan, status, gating, stale, export or schema value changed | Yes - `eqalb_price.R` and `plumber.R` parse; both services restarted and the endpoint re-run; a leaf-by-leaf diff of the old and new responses shows **zero** numeric differences and no removed fields, with exactly three changed strings (the two interpretations and the combined `interpretation`) and the two additions. Wording verified over HTTP for four states: default (Red, required 24.6% "Not met", outside the one-way range), `current_price` 100 (Green, headroom €55.03 as 55%, required 6.2% "Met" inside the range), `current_price` 1,000,000 (Red, required effect unavailable with R's "Even a relative risk reduction of 100% …" reason) and `current_price` 0 (Green, sentence reads "is €155.03 below that level" with no placeholder). The fifth state — no maximum acceptable price at all — was reached from the interface with the reference threshold at €1,000, implementation cost €500 and healthcare savings €0: the card reads "Not available", the summary switches to the warning style with R's `Red` badge and R's plain-language reason, the chart prints its no-comparison note, the callout shows "Not met" with R's reason, and the first disclosure lists R's two reasons including "Scan: 0 of 9 scan combinations could be identified." A scan of that state's rendered text for "solved price is", "bisection", "tolerance", "affine_price", "pricing recommendation" and "not clinical evidence" found none. Browser at 127.0.0.1:5173: cards €155.03 / €360.00 / −€204.97 (R's −56.9%) with tone from R's status, the chart receiving R's 155.029800318324 and 360 through its props, the summary, the callout badge "Not met" with R's sentence verbatim, exactly two disclosures both starting closed, no `.notice`, and the scenario and scan tables matching the API row for row (0 of 9 combinations support €360.00; grid 78.41 … 240.01). A scan for `affine_price_solve_verified`, `bisection`, `not_met`, `not_available`, "Method R used", "No request field was missing", tolerance and pricing-recommendation wording found **none** in the tab; the Green state was reached at price €100 and the unavailable required-effect state at the €2,000 the sidebar clamps to, both rendering R's exact wording and the availability reason in the first disclosure; `method`/`method_note` absent from the interface in every state. Disclosures: mouse, Enter and Space each toggled, Escape closed and returned focus to the summary. No page-level or panel overflow at 390/768/1280px with the scan table scrolling locally at all three (1301px content in a 267px client at 390px); light and dark both checked (callout accent `#176b73` light, `#7fd1d8` dark); zero console errors or warnings on a fresh reload, a full nine-tab sweep and a value-based-price run; nine tabs render with Value-based Price immediately before HTA Decision Summary; `npm run build` (vue-tsc + vite) and `npm run lint` pass; no PSA was run |
| 2026-10-12 | Global scrollbar polish, presentation only: `frontend/src/styles.css` gains a scrollbars section. Chromium/WebKit take the `::-webkit-scrollbar` family behind `@supports selector(::-webkit-scrollbar)`: a 10 px channel, a transparent track, a rounded pill thumb in `--accent` at 55 % (80 % on hover, full strength while dragged) inset 2 px by a transparent border with `background-clip: padding-box`, no arrow buttons and a transparent corner. Engines without those pseudo-elements (Firefox) fall back to the standard, inherited `scrollbar-width: thin` and `scrollbar-color: var(--accent) transparent`, set once on the root and reaching the page and every local scroll container; the split exists because Chromium ignores `::-webkit-scrollbar` on an element whose `scrollbar-width`/`scrollbar-color` are set. Appearance only: no scrollbar is hidden, no scroll container is resized, and no scrolling behaviour, layout dimension, chart, page content or accessibility semantic changed. The narrower page channel widens the content area by a few pixels, the system channel being roughly 15-17 px | Yes - Chromium (integrated browser, 127.0.0.1:5173): `CSS.supports('selector(::-webkit-scrollbar)')` is true and both `@supports` blocks are parsed in the CSSOM with the exact rules, so the pseudo-element path is the active one; the rendered channel measures 10 px on the page (`innerWidth - clientWidth`) and 10 px on local scrollers (offset minus client minus borders) for the three `.table-scroll` containers at 390 px and for the sticky sidebar; scrolling is intact by wheel (600 to the maximum), PageDown (0 to 787), End (1446, the maximum), Home (0) and thumb drag (0 to 767, held after release), and the local table scroller by wheel deltaX (0 to 275), shift+wheel (to 458) and its own horizontal thumb drag (to 202, held); light resolves `--accent` to `#176b73` and dark to `#7fd1d8`, and the theme toggle is unaffected; no page-level horizontal overflow at 390/768/1280 px; zero console errors or warnings on a fresh reload and navigation; `npm run build` (vue-tsc + vite) and `npm run lint` pass. Not evidenced here: the pixel appearance (automated Chromium screenshots omit the classic scrollbar, so the evidence is the measured channel width, the parsed rules and the resolved tokens), the hover/active states (declared and parsed, not triggerable in a screenshot), and Firefox and Safari rendering, where only the standards path was reviewed and Safari draws its own overlay scrollbars |
| 2026-10-11 | OWSA interpretation rewritten in R (`eqalb_owsa.R`, plus the Shiny caller's styling and factual docs). The repetitive "does/does not cross the WTP decision threshold" list is gone. `summarize_eqalb_owsa()` now writes one sentence per line: the base-case value of the **selected outcome** and the decision reference it is read against (INMB above/below €0 at the selected threshold; ICER against the reference threshold in the wording `assess_hta_decision_summary()` already uses; incremental cost and QALYs with the value plus the incremental net monetary benefit the decision is made on), the two or three parameters whose tested range moves that outcome most ("`<parameter>` produces one of the largest movements in `<outcome>` across its tested range."), one robustness conclusion ("The conclusion remains unchanged across the tested one-way scenarios." or "The conclusion is sensitive to the tested range of X and Y."), any parameter the run could not vary, and the unchanged one-way limitation. New small helpers keep the rules single-sourced: `eqalb_owsa_cost_effective()` (the threshold rule, now also used by `eqalb_owsa_run_scenario()`), `eqalb_owsa_attr_value()`, `eqalb_owsa_number()`, `eqalb_owsa_mid_sentence()`, `eqalb_owsa_sentence_list()` and `eqalb_owsa_format_selected()`. `eqalb_owsa_scenario_rows()` carries the selected outcome, R's cost-effectiveness flag per scenario and the `outcome`/`outcome_label`/`base_outcome` attributes, so the interpretation ranks by R's `impact_range` for the selected outcome — the same ranking as the table and the chart — instead of always by INMB; the Shiny frame, which has only `inmb`, falls back to it. `eqalb_owsa_base_args()` gained the two follow-up event costs so a caller can pass it straight to `run_eqalb_owsa()` without the cost-anchor scenarios failing. `app.R` styles `#owsa_summary` with `white-space: pre-wrap` so the Shiny tab honours R's own line breaks, and the browser panel's now-false clarification ("R's narrative always ranks by the low-to-high INMB range") was removed. No calculation, range, threshold, ranking rule, table, chart, export, gating or endpoint behaviour changed; `api/api_contract.md`, `api/main.py`, `frontend/src/api/types.ts`, `project_state.md`, `FRONTEND_PLAN.md` and `frontend/README.md` were updated factually | Yes - deterministic OWSA only, no PSA. R checks: all four ranked outcomes produce 2-3 driver sentences, exactly one robustness sentence, the one-way limitation last, no trace of the old wording, drivers naming the selected outcome, and plain text with no markup; INMB negative base case reported below €0 and not cost effective; ICER line "Base-case ICER: €298,966/QALY vs reference threshold €100,000/QALY, above the reference threshold, so the base case is not cost effective."; cost and QALY rankings state their value and name the decision reference; a favourable scenario (price €120, RRR 15%, year-1 85%, follow-up 52%) reports a cost-effective base case and "sensitive to the tested range of Annual intervention price" with the flip visible in R's per-scenario flags; a zero cost discount rate is reported as "Not varied in this run: Cost discount rate." and is never named as a driver while the other three remain; a synthetic frame in which nothing could be varied reports that honestly instead of claiming the conclusion is unchanged; the Shiny frame shape (INMB only, no flag columns) reads through the documented fallbacks; a frame with one parameter's scenarios both failed reports that parameter as not varied and keeps the unchanged conclusion. Live API (plumber and FastAPI, byte-identical): base metrics, INMB ranking order, the educational note, the simulated-data notice, table values/ranges and the ranges in force unchanged from the captured baseline apart from the previously approved discount policy pair; all four outcomes' interpretations verified line by line; the favourable and zero-discount scenarios verified over HTTP. Browser at 127.0.0.1:5173: the closed "How to interpret this result" disclosure renders R's text verbatim (6 lines, `pre-wrap`), the interpretation is the API string exactly, the old clarification paragraph is gone (0 matches), the ICER ranking shows the ICER interpretation with the ICER-labelled table columns, chart caption and top row, and Escape closes the disclosure returning focus to its summary; metrics, 14-row table, chart, CSV button, stale-notice behaviour and gating unchanged; no page-level overflow at 390/768/1280px and the text does not overflow its box at any of them, in dark and light; no console errors or warnings on a fresh reload; value-based price byte-identical to its pre-change baseline and the base case unchanged (ICER 298965.512965076); `npm run build` (vue-tsc + vite) and `npm run lint` pass |
| 2026-10-11 | OWSA range-policy redesign, R model module plus Shiny, API and browser stack. `eqalb_owsa.R` gains the one canonical one-way range policy: `eqalb_owsa_range_specs()` (one row per parameter with its group, unit, permitted domain, range mode, and R's own source label and rationale sentence), `eqalb_owsa_frozen_widths()` (the absolute widths the model has always used), `eqalb_owsa_range_defaults()` (derives the range from the value the parameter has in the scenario being analysed: absolute offsets for 11 parameters, no-discounting/twice-the-rate for the two discount rates, and the nearest valid distinct whole-year pair for the time horizon, all clamped to the domain and reported with a status), `eqalb_owsa_range_bounds()` (applies any supplied range, labels every row `Model default` or `Adjusted` itself), `eqalb_owsa_override_error()` (finite, domain, low < high, whole years), `eqalb_owsa_contains_warning()` (a usable range that no longer contains the scenario's own value) and `eqalb_owsa_base_args()`/`eqalb_owsa_parameters()` (the same policy at the model's own constants, which is what `eqalb_price.R` and `eqalb_markov.R`'s standalone analysis block read). `run_eqalb_owsa()` keeps the row of a parameter whose range R cannot derive, with R's sentence in `low_warning`/`high_warning` and no numbers, instead of running an imaginary scenario. `api/plumber.R` derives the ranges from the submitted scenario, rejects an unusable supplied range with R's sentence, returns `bounds` with the new metadata plus `bounds_note`, publishes them on `GET /api/defaults` (`owsa_parameters`, `owsa_bounds_note`) and adds `POST /api/owsa-defaults`, which returns the same block without running a single model run; `api/main.py` mirrors the route and its docstrings. `eqalb_markov.R` no longer defines its own `sensitivity_ranges` table: its analysis block reads `eqalb_owsa_parameters()` (sourcing the module only when the file is run directly), so the drifted duplicate is gone. `app.R` builds its sidebar range controls from `eqalb_owsa_parameters()` instead of 20 literals and keeps them in step with the current global assumptions through one observer that leaves a bound the user edited alone, with the scenario args shared by both callers. The browser's range editor (`frontend/src/components/SensitivityPanel.vue`, `styles.css`, plus `api/types.ts`, `api/client.ts` and `composables/useModel.ts`) is now grouped under R's own headings with one row per parameter showing R's label, unit, rationale (InfoTip), base value, derived low and high, an editable pair per row and R's own state chip; it asks R for the current ranges whenever it is open and the assumptions change, and its reset returns to R's current ranges rather than the last run's bounds (the old fallback defect). One-way staleness now compares the whole request (scenario, threshold and ranges) through the existing fingerprint pattern, with the ranked-outcome notice kept separate. Nothing about the calculation, ranking, table schema, CSV export, metric cards, outcome selector, narrative or gating changed; the value-based price module reads the same static definition as before. Docs: `api/api_contract.md` (new `POST /api/owsa-defaults` section and a range-policy section), `project_state.md`, `FRONTEND_PLAN.md`, `frontend/README.md`, `readme.md` | Yes - deterministic checks only, no PSA. Baseline captured before any edit (default 14-row OWSA for all four rankings plus value-based price, in the session folder). Policy checks in R: ids/labels/order and 12 of 14 default ranges byte-identical to the baseline, the two discount rows differing only through the approved policy pair (0/0.05 → 0/0.06, impacts 479.7719 → 557.8293 and 245.3761 → 284.1861), boundary scenarios for price 0/900/2000, implementation 0/500, savings 0/500, utilities 0/1, engagement 0/1, RRR 0/0.30, discount 0.01/0.05/0.10 and event costs at 0, 13 horizon cases including both domain edges (10 → 5/20, 1 → 6/11, 91 → 81/96, 100 → 90/95, one-sided pairs reported), no derived range breaking its domain, ordering or containment rule over 1,620 scenario combinations, every invalid override rejected with R's own sentence, and overrides preserved absolute and marked `Adjusted` when the base moves. Live API checks on both services: metric fields, R's narrative, the summary note, the simulated-data notice and the ranking order byte-identical to the baseline, the run's `bounds` carrying the derived values and `range_status`/`range_state`, `GET /api/defaults` publishing the same ranges for the model's base case, scenario changes deriving 720/1080 (price 900), 35/50 (horizon 40) and 0.90/1 (utility 1), an override taking effect in the run while R keeps its own default beside it, seven invalid overrides rejected with HTTP 400 and R's message on FastAPI (and the documented plumber 500), the editor endpoint reporting the same violations with HTTP 200 and R's sentence, and the value-based price response byte-identical to its pre-change baseline. Shiny: `app.R` and every R file parse; the ten sidebar defaults equal the previous literals exactly; a direct run of `eqalb_markov.R` completes and writes its CSVs and tornado from the canonical policy (30 rows, base plus 14 × 2; the three output files were deleted afterwards). Browser at 127.0.0.1:5173: the editor renders 14 rows in 6 R-labelled groups with a base value, an InfoTip and a state chip each, follows a global change (price 900 → 720/900/1080), marks a typed range `Adjusted` and shows R's own rejection sentence for one R cannot use, and reset returns every row to R's current defaults. A zero discount rate leaves that one row with no range, R's sentence in the editor and in the "2 bound warnings" disclosure, the row still present in the table with no numbers and the parameter absent from the ranking, and no zero-width bar in the chart (13 usable bars, 30 rectangles). Staleness: no notice after a fresh run, the notice on an assumption change, cleared when the assumption was restored, and present for a threshold-only change. Tornado geometry re-measured against the new ranges: 14 bands with exactly two rectangles each, each band's union equal to `convertToPixel` of its own row's R-returned low/high outcome (worst delta 0px), axis covering the whole range including negatives, and all 14 tooltips matching their table row's label, low, high and range. Layout: no page-level or body horizontal overflow at 390/768/1280px in light and dark, the editor's fields stack full-width at 390px and sit inline above it, and an InfoTip panel at 390px stays inside the viewport (8–367px of 390) without internal scrolling; the only console output was a `value "—" cannot be parsed` warning from a numeric input, which was fixed by leaving an underivable range empty with a placeholder and re-measured clean (no warnings or errors on a fresh reload). `npm run build` (vue-tsc + vite) and `npm run lint` pass; the bundle is 796 kB, about 2 kB above the previous build |
| 2026-10-11 | Tornado chart defect fixed, frontend only: `frontend/src/components/charts/TornadoChart.vue` and one narrow-viewport rule in `frontend/src/styles.css`. The chart's bars were passed to ECharts as two-element arrays `[min, max]`; ECharts 6 reads an array data item as `[x, y]` coordinates, so it drew **no bars at all** and scaled the value axis from the first element alone (the axis read €0–€80,000 while R's rows reached €180,603). The spans are now drawn by a `custom` series (registered in the component, because `useEcharts.ts` registers only the series the other charts use), which is handed R's two bound outcomes for each row and draws one rectangle between them, split at R's base outcome so the established direction colours are preserved: a row wholly on one side gets a single-colour bar and never borrows the other side's colour. The value axis is set from the returned bounds plus R's base outcome, so every bar is fully visible; bars are not extended to reach the baseline. Tooltips resolve the row through `parameter_id`, the identifier R returns, rather than through an array position. `yAxis.inverse` puts R's first row at the top as the table lists it, and the parameter column now narrows on a phone (`containLabel` plus a width read from the chart's own ResizeObserver, with a taller canvas below 520px) so the plot keeps room for the bars. Nothing about the values changed: no sorting, truncation, recalculation or reinterpretation, and no R file, API route, threshold, export or request changed. Docs: `project_state.md`, `FRONTEND_PLAN.md`, `frontend/README.md` | Yes - measured in the running app at 127.0.0.1:5173 against the live API. Two deterministic one-way runs (no PSA): one ranked by ICER and one by INMB, each compared field by field with the API response it returned. For all 14 rows the union of the rendered rectangles equalled `convertToPixel` of that row's `selected_outcome_low`/`selected_outcome_high` to within 1px (0 mismatches in both runs, matched by `parameter_id`), 12 rows were split at the base outcome and 2 lay wholly on one side, and the value axis covered every returned bound plus the base outcome in each run (ICER: axis 28,012-183,595 for data 31,004-180,603; INMB: axis -525 to 2,652 for data -464 to 2,591, i.e. negative values drawn on the correct side). Hovering all 14 bands returned a tooltip matching the corresponding table row exactly (14/14 at desktop and 14/14 at 390px); the chart's parameter order equals the API order and the table order exactly. Table (14 rows, same values and headers), CSV export, metric cards, R's narrative disclosure, stale notice and action gating were all confirmed unchanged, and switching the ranked-outcome selector still re-renders the chart with the existing "computed from earlier inputs" notice. Layout: no page-level horizontal overflow at 390/768/1280px (`scrollWidth` = `clientWidth` at each), the parameter labels stay inside their own band at 390px and at desktop with the narrower column (measured from the rendered pixels), and light mode uses its own palette (`#b3261e` / `#2e7d4f`). A fresh reload produced no console error or warning, and after a clean run no error or warning either; `npm run build` (vue-tsc + vite) and `npm run lint` pass. The bundle grows about 24 kB (768 to 793 kB) because `CustomChart` is now included |
| 2026-10-11 | UX polish batch after the final acceptance review, frontend only: `frontend/src/components/StaleNotice.vue` (new), `frontend/src/composables/useDisclosure.ts` (new), `frontend/src/composables/useModel.ts`, `frontend/src/composables/useAppView.ts`, `AssumptionsForm.vue`, `BaseCasePanel.vue`, `CostEffectivenessPanel.vue`, `SensitivityPanel.vue`, `BudgetImpactPanel.vue`, `SurvivalPanel.vue`, `ValueOfInformationPanel.vue`, `ReadinessPanel.vue`, `HtaSummaryPanel.vue`, `ValueBasedPricePanel.vue`, `charts/TornadoChart.vue`. (1) Staleness is now uniform: one `StaleNotice` renders the same sentence in all nine tabs ("This result was computed from earlier inputs. It is not recalculated automatically: use “<button>” to replace it with the current values.") with one optional factual detail (the threshold a run used, or the ranked outcome a table used). Budget impact, survival and value of information had no source comparison and now use the same request-snapshot pattern as readiness, HTA and value-based price (`budgetRequest()`/`survivalRequest()` added; VOI compares the PSA result object it reused plus the threshold). Gating, errors and the pre-existing threshold-only checks for the base case, PSA and OWSA are unchanged, and no wording was invented where R supplies it. (2) Escape closes disclosures app-wide: `useDisclosure.ts` installs one document listener (from `useAppView()`, the composable every screen calls, including both standalone views), closes the `details.details` the focus is inside, returns focus to its summary, stops the key so the views' "Escape returns Home" does not also fire, and defers to an open InfoTip. It deliberately ignores `details.group`, the assumptions sidebar's input groups. The two per-component handlers in the readiness and HTA panels were removed as duplicates. (3) The sidebar helper now says every analysis tab marks a stored result when the inputs or threshold it used have changed, which covers value-based price. (4) Headings/copy: "Base-case cost effectiveness" → "Base-case cost-effectiveness" and one-line subtitles added to the base case and the PSA tab. (5) `TornadoChart.vue` no longer sorts or truncates: it draws R's returned rows in R's order (the API already ranks by `impact_range`), keeping the documented reverse for top-down drawing, and the tooltip shows R's own `impact_range` value. No R file, API route, threshold, calculation, distribution, export or bundle configuration changed and no dependency was added. Docs: `project_state.md`, `FRONTEND_PLAN.md`, `frontend/README.md` | Yes - measured in the running app at 127.0.0.1:5173. Stale notices: fresh runs showed none, then a change to the relevant input produced exactly the one notice on base case (threshold), sensitivity (threshold and ranked outcome, both present at once), budget impact (uptake and the shared population), survival (seed), readiness (a review-minutes edit and a dropdown change), value-based price (threshold) and HTA summary (after an upstream budget-impact re-run), with the notice cleared when the input was restored, when readiness's "Reset values" cleared its result, and when HTA was re-assessed; the detail sentence named the *stored* threshold/outcome, as intended. Disclosure keyboard behaviour: all 14 disclosures rendered across the nine tabs opened by mouse, toggled by Enter, opened by Space, closed by Escape and returned focus to their summary, with no failures; the Download results view's disclosure behaved identically and Escape inside it no longer navigated Home, while Escape with focus outside a disclosure still does (existing behaviour); the sidebar input groups never closed on Escape and kept focus; an open InfoTip closed on Escape and left the disclosure behind it open. Copy and layout: the base-case heading and both new subtitles render, the sidebar helper reads as intended, and the unified notice measured 290px wide inside a 375px page at 390px with 753/753 at 768px and 1265/1265 at 1280px, and legible in both modes (dark `rgb(224,164,74)` on `rgb(58,47,24)`, light `rgb(178,106,0)` on `rgb(255,243,205)`). The tornado's table holds R's 14 rows in R's order (first "Annual intervention price", last "Cost: post-stroke (year-1 anchor)") and the chart binds that same array with no sort or slice; reading the drawn order back from the ECharts canvas proved unreliable in this environment, so the chart order is verified from the shared data path rather than from pixels. That check was not enough: the bars were in fact not rendering at all, because ECharts 6 reads the two-element range arrays as [x, y] coordinates — the defect and its fix are recorded in the tornado row above. A fresh reload produced no page error and no console error or warning, and `npm run build` (vue-tsc + vite) and `npm run lint` pass. No PSA was run, so the value-of-information notice could not be exercised live - its wiring is type-checked and identical to the other eight |
| 2026-10-11 | Batch 4 of the approved UX revamp (DHT readiness, value-based price, HTA decision summary): `api/plumber.R` (the one approved publication change — `tutorial_interop_definition` added to `COLUMN_INFO_KEYS` and returned as the `info` field of the interoperability choice set), `api/api_contract.md`, `frontend/src/api/types.ts`, `frontend/src/components/ReadinessPanel.vue`, `ValueBasedPricePanel.vue`, `HtaSummaryPanel.vue`, `frontend/src/components/charts/ValueBasedPriceComparison.vue` (new), `frontend/src/styles.css`. (1) Readiness: the wrapping control row became a panel-specific stacked layout (`.controls--readiness`) with one field per row, each label and its InfoTip on the same line, numbers grouped under R's own `group` headings and the two dropdowns in "Interoperability" and "Algorithm governance" groups; the interoperability control now carries an InfoTip holding the *existing* R string verbatim, published through the defaults contract, and no algorithm-governance definition was invented because none exists in R. (2) Value-based price: a one-line subtitle, three cards (maximum acceptable €155.03, current €360.00, headroom −€204.97 with R's percentage and R's own "did not identify" states), the new two-bar comparison chart, R's `headline.interpretation` and R's notice visible, and everything else in exactly three closed disclosures ("What this price means", "Required effectiveness at the current price", "Illustrative price scan"). (3) HTA decision summary: one position card, R's interpretation, the incomplete-state warning, an optional `.insight` built from `model.valueBasedPrice` when a result is stored in the session, and "Decision dashboard (5 domains)" / "Evidence priorities (9)" as closed disclosures beside the unchanged rules and availability disclosures. No chart, table or insight computes, sorts, ranks or classifies anything in TypeScript; no status is derived. No R model logic, threshold, distribution, calculation, endpoint behaviour, Shiny file, tutorial or export changed and no package was added. Docs: `project_state.md`, `FRONTEND_PLAN.md`, `frontend/README.md` | Yes - measured in the running app at 127.0.0.1:5173 against the live API, after restarting FastAPI and the plumber worker because the worker builds `plumber.R` at start-up (both APIs then returned the interoperability sentence byte-identically and `''` for algorithm governance). Readiness: 10 controls in 7 groups, each label's InfoTip at the same vertical position as its own label (264/265 for review minutes, 584/584 for interoperability), the interoperability InfoTip opened by keyboard and read back as R's exact sentence, and one `Assess readiness` run matched `/api/readiness` field for field (7 domains, `Equity and access:Green … Algorithm governance:Amber`, counts 2/4/1, all five numbers, R's interpretation, the notice, 12 table rows). Value-based price: no request before the button (0 → 1), three cards reading €155.03 / €360.00 / −€204.97 with R's `-56.9%`, exactly three closed disclosures, the chart reading R's 155.0298… and 360 with R's `Red` status driving the colours, R's headroom sentence beneath it, R's interpretation visible and the notice last. HTA: with no stored value-based price the panel showed no insight and issued no value-based price request (0 before and after the run); after running value-based price the same run added the insight with R's €155.03 / €360.00 / −€204.97 and R's `headline.interpretation` **without** a new request (count 1 → 1), the endpoint body and its five availability flags unchanged; dashboard and evidence-priority disclosures started closed and opened by mouse, Enter and Space (Batch 4 claimed they also closed on Escape; that was a mis-read, and Escape behaviour was made app-wide and re-verified in the polish batch below); every rendered dashboard cell was found verbatim in R's `summary.domains` (5 rows, no missing cell), all 9 priority rows matched `evidence_priorities.table`, and `position`, `interpretation`, `evidence_priorities.summary`, `evidence_note`, `rule_note` and `notice` were present verbatim. Regression: nine tabs in the approved order (Value-based Price immediately before HTA Decision Summary), Home, Project description, Download results and the theme control worked in light and dark (dark insight `rgb(30,48,57)` on `rgb(230,237,241)`), 390px and 768px showed no page-level horizontal overflow (`scrollWidth` = `clientWidth`) with both tables scrolling locally, and re-armed `error`/`unhandledrejection` listeners recorded nothing while the three rebuilt panels were exercised and every disclosure opened and closed. `npm run build` (vue-tsc + vite) and `npm run lint` pass; no PSA was run in this batch. One diagnostics note: the Vite dev server was serving a stale transform of `HtaSummaryPanel.vue` (its script block without the `formatEuro`/`isNum` import) that a page reload did not clear — touching the file forced a re-transform; the built bundle was correct throughout, so this is a dev-server cache artefact only |
| 2026-10-11 | Batch 3 of the approved UX revamp (one-way sensitivity analysis, budget impact, value of information), frontend only: `frontend/src/components/SensitivityPanel.vue`, `BudgetImpactPanel.vue`, `ValueOfInformationPanel.vue`, `frontend/src/components/charts/VoiEvpiChart.vue` (new), `frontend/src/components/charts/EvppiChart.vue` (new), `frontend/src/styles.css`. (1) OWSA's default-visible narrative block became a closed disclosure, "How to interpret this result", holding the same R strings verbatim (`summary_note` + `summary` after a run, `owsa_prerun_note` before one — nothing was deleted or reworded), and the frontend hint that referred to "the narrative above" now names the disclosure; tornado, ranked table, range editor, CSV export, metrics, warnings and action gating unchanged. (2) The budget-impact controls, which wrapped a label, its input and a separate InfoTip into arbitrary flex rows (at 390px the population trigger rendered beside the Year-1 uptake field), are now a stacked form used only by that panel (`.controls--stacked`) built from the assumptions panel's own field parts (`label[for]`, InfoTip, `.field__control`, `.field__hint`): one control per row, label and its information control together, input and unit on the next line, and the population and avoided-event notes under their own controls. The footer sentences about follow-up engagement and avoided-event savings were removed, and the avoided-event control carries exactly the approved factual hint — no InfoTip, because R/Shiny publishes no wording for it and none was invented. (3) EVPI's InfoTip stayed in its metric card; EVPPI's moved into the caption of its table (the accessible table name is preserved through `DataTable`'s `label`), the frontend approximation paragraph left the open panel, and a closed "View visual summary" disclosure now holds `VoiEvpiChart.vue` (bars for R's `expected_nmb_current` and `expected_nmb_perfect` with R's `evpi` as the labelled gap) and `EvppiChart.vue` (R's EVPPI rows in the response's own order, a dashed line at R's EVPI, the clamped qualifier in the tooltip), with the caveat placed under the EVPPI chart inside the disclosure only. Neither chart sorts, ranks, classifies or computes anything. No R model logic, threshold, distribution, calculation, endpoint, Shiny file, tutorial or export changed; no package added. Docs: `project_state.md`, `FRONTEND_PLAN.md`, `frontend/README.md` | Yes - measured in the running app at 127.0.0.1:5173 against the live API. OWSA: the disclosure's text content matched the API's `summary_note` ("Educational analysis using illustrative parameter ranges.") and `summary` ("Top parameters by absolute low-to-high INMB range: … Base-case INMB: €-1,623 at WTP €100,000/QALY. …") exactly after whitespace normalisation, and the pre-run state matched `owsa_prerun_note` ("Set the assumptions and click Run sensitivity analysis."); it started closed, opened by click, Enter and Space, the narrative was absent from the open panel, the ranked-outcome clarification read "R's narrative in "How to interpret this result" always ranks by the low-to-high INMB range …", the 14-row table and tornado were unchanged and the CSV button stayed enabled. Budget impact: cards matched `/api/budget-impact` (€15,480,000 cumulative, €15,120,000 intervention, €1,200,000 implementation, €840,000 savings, avoided-event 0), five table rows and one chart unchanged, inputs still 100000/10/5/5/0; measured at 1280 (controls 816px, five rows, tips at the same top as their own labels within a pixel of rounding), 768 (668px) and 390px (290px, tip at t=448 beside its own label at t=449 rather than beside the next field as before), with `scrollWidth` = `clientWidth` at every width. VOI: one PSA ran at `n_sim = 100`, `seed = 12345` and reproduced the Batch 2 result exactly (mean €2,418, mean 0.0078 QALYs, median ICER €333,633, 1.0% cost-effective); the VOI run then showed EVPI €0.11 per patient at €100,000/QALY, the EVPI chart's bars read R's values (0 and 0.110098443012998, the latter identical to the EVPPI chart's reference line and to the €0.11 card), the EVPPI chart held 9 bars in R's returned order (Relative risk reduction first), the disclosure started closed and opened by click, Enter and Space, the approximation sentence rendered only inside it (`0` matching nodes outside), the EVPPI InfoTip sat in the table caption (label "Information about EVPPI"), opened by keyboard with R's text "The value of eliminating uncertainty about selected groups of inputs.", closed on Escape and returned focus to its trigger; at 390px both charts re-rendered live (239px containers) with the EVPPI plot area ~75px wide after the responsive narrowing, the table scrolled locally (703 vs 288) and the document did not scroll horizontally. Regression: all nine tabs rendered with no error alert, Home, Project description (disclaimer intact), Download results and the theme control worked, light and dark both re-rendered the new charts from their palette tokens (`#64748b`/`#7fd1d8` dark, `#94a3b8`/`#176b73` light), and a page reload produced no console error or warning. `npm run build` (vue-tsc + vite) and `npm run lint` pass; the 100-draw PSA was the only PSA run |
| 2026-10-11 | Deterministic base-case plane clarified, frontend only (`frontend/src/components/charts/BaseCasePlane.vue`). The shaded cost-effective region was removed together with its legend entry, so the legend now carries only the two strategy markers and the chart is no longer cluttered by a wash whose meaning the reader had to infer. The ray is named directly instead, with a single label anchored 72% along the clipped segment reading "€100,000/QALY threshold" — the value it prints comes from `result.wtp` via `formatEuro`, so it cannot drift from the metric card — and one plain-language caption sits beneath the chart ("Points below the threshold line are cost-effective at the selected threshold."), extended with "The current eQalb result lies above the line." exactly when R reported the result as not cost-effective. That is explanatory geometry over the already-rendered ray and the status R returned; no status is derived and no calculation, threshold, distribution, endpoint, export or other panel changed, and no PSA was run. The `costEffectiveRegion()` polygon-clipping helper and the box it clipped against were deleted with the wash; the usual-care origin marker, the eQalb point, the 86%-stopped arrow, both zero-crossing guides and the ICER/status note are unchanged. Docs: `project_state.md`, `FRONTEND_PLAN.md`, and one factual sentence in `frontend/README.md` | Yes - measured in the running app at 127.0.0.1:5173, base case only. Structure: no series carries an `areaStyle` and only the two markers are named (`legendItems: ["Usual care", "eQalb + usual care"]`); translucent greenish pixels on the canvas fell from about 16,700 before the change to 349, which is the dashed ray's own anti-aliasing. Label: the ray label's formatter returned "€100,000/QALY threshold" at the default threshold and "€500,000/QALY threshold" after the reference threshold was set to €500,000 and the base case re-run, matching the metric card's "Not cost-effective at €100,000/QALY" / "Cost-effective at €500,000/QALY" in each case; it rendered as a 113x7 px text block centred on its anchor (548, 193), sitting just above the ray and inside the canvas in dark and light themes and at 390px. Caption: "Points below the threshold line are cost-effective at the selected threshold. The current eQalb result lies above the line." with the default base case and with the rrr = 0 dominated path (ΔQALYs 0.0000, "Dominated (costs more, no extra QALYs)"), and the first sentence alone at €500,000/QALY where R returns `cost_effective: true`; the two-sentence form therefore tracks R's own flag rather than a value computed in the client. Unchanged: origin data `[[0,0]]`, eQalb data `[[0.00815905352481128, 2439.27562235471]]`, arrow markLine `[[{coord:[0,0]},{coord:[0.007016786031337701,2097.7770352250504]}]]` with `symbol: ["none","arrow"]`, both zero guides `[{xAxis:0},{yAxis:0}]`, and the tooltip over the point reading "eQAlb + usual care / Incremental QALYs: 0.0082 / Incremental cost: €2,439 / ICER €298,966 per QALY · Not cost-effective at €100,000/QALY". Layout: a fresh load at 390px measured `scrollWidth` = `clientWidth` = `body.scrollWidth` = 375 with the chart canvas 265px wide, and the settled state with the assumptions sidebar both hidden and open also measured 375. One pre-existing, app-wide observation: while an ECharts tooltip is open and the window is then narrowed, the library's unconfined tooltip node can extend the document (693 vs 375 in that state); it is the default tooltip placement shared by all five charts and unchanged by this task. `npm run build` (vue-tsc + vite) and `npm run lint` pass; no PSA was run |
| 2026-10-11 | Batch 2 of the approved UX revamp (base case and PSA), frontend only: `frontend/src/components/AssumptionsForm.vue`, `BaseCasePanel.vue`, `CostEffectivenessPanel.vue`, `charts/BaseCasePlane.vue` (new), `charts/CostEffectivenessPlane.vue`, `charts/CeacChart.vue`, `frontend/src/views/DownloadResultsView.vue`, `frontend/src/styles.css`. (1) The model-structure wording was removed from both places that showed it — the sidebar's `assumptions__meta` line and the base-case header's "Deterministic Markov run over … cycles, two strategies, …" sentence — and the dead `.assumptions__meta` rule with them; nothing was relocated, and `GET /api/defaults` still publishes `model`. (2) The cost and QALY decompositions moved into two closed `<details>` directly under the base-case metric cards ("How incremental cost is composed", "How incremental QALYs are composed"), each keeping its table, reconciliation total and note (the no-event sentence in the cost one) and taking its accessible name from `DataTable`'s `label` prop instead of a visible caption, so nothing scrolls the page at 390px. (3) `BaseCasePlane.vue` draws the deterministic result from the response alone: usual care at the origin, zero-crossing guides, the WTP ray from `result.wtp` with the cost-effective half-plane shaded (clipped to the axes), an arrow to the eQalb point that stops at 86% so its head is visible, and an ICER/status note built from the same `describeIcer`/`costEffectivenessLabel` helpers the metric cards use, so a non-estimable ratio is described in words and no ratio is drawn. No economic value is derived in TypeScript. (4) PSA copy was reduced to what running a PSA needs: the header model-structure line, "Simulating N iterations in R", the reproducibility sentence duplicated by R's `random_seed` InfoTip, the 15-minute/timeout/value-of-information hint, the iteration-range caption the input already enforces through `min`/`max`/`step`, and the run-timing estimate (`lastRun`, `ratePerIteration`, `coarseDuration`, `durationEstimate`, `run()`) are gone; R's `notice`, R's InfoTip text, the result-specific chart notes, the stale-threshold and failed-iteration warnings and the disabled-while-busy button remain, with one concise busy line. (5) The PSA plane gained a mean-of-iterations marker (hollow accent diamond above the deterministic marker so it stays legible when the two coincide) and zero-crossing guides, and the acceptability curve gained a dot with its probability label at the reference threshold; the deterministic marker itself is unchanged. (6) The duplicate static simulated-data notice on the Download results view was removed; R's notices and the Project description disclaimer are untouched. No R model logic, threshold, distribution, calculation, endpoint, Shiny file, tutorial or export changed; no package added; no 1,000-draw PSA run. Docs: `project_state.md`, `FRONTEND_PLAN.md`, `frontend/README.md` | Yes - measured in the running app at 127.0.0.1:5173 against the live API. Base case: the panel showed €2,439 / 0.0082 / ICER €298,966 / −€1,623 and the chart note "ICER €298,966 per QALY · Not cost-effective at €100,000/QALY", matching the live `/api/base-case` response (€2,439.2756, 0.008159, ICER €298,965.51, wtp 100000); canvas sampling found the shaded region only below the ray (dark `rgba(76,175,125,0.14)`, light `rgba(46,125,79,0.10)`), the upper-left corner transparent, the eQalb marker in the intervention colour, the usual-care marker in the control colour and a 2px arrow shaft ending in an 11px head 78-87px short of the marker. Disclosures: both started closed and opened by click and by keyboard (Space and Enter), with the six cost rows and three QALY rows equal to the API components (€2,851.21/€39.60/€158.40/€0.00/−€164.84/−€128.30, total €2,439.28; 0.0337/−0.0172/−0.0084, total 0.0082) and `aria-label`s "Cost decomposition (EUR, incremental)" and "QALY decomposition (incremental)". Non-estimable path: with rrr = 0 the card and the chart note both read "Dominated (costs more, no extra QALYs) · Not cost-effective at €100,000/QALY" with ΔQALYs 0.0000 and no ratio drawn. PSA: one run at `n_sim = 100`, `seed = 12345` returned 100 successful draws and the chart's mean series read the returned mean (2417.7511 / 0.0078067, matching the €2,418 and 0.0078 cards) at the resolved pixel for that pair, the CEAC dot sat at (100000, 1%) with the label "1.0%" rendered just above it inside the grid and both matching the metric card and the threshold table. Copy: the removed strings were absent from the base-case and PSA views while R's `notice`, the two R `CC_INFO_TEXT` InfoTips, the result-specific notes and the warnings remained. Regression: all nine tabs rendered, Home, Project description (disclaimer intact), Download results (no static notice) and the theme control worked, light and dark both re-rendered the charts from their tokens (light marker `#176b73`, dark `#7fd1d8`), 390px gave `scrollWidth` = `clientWidth` = 375 on both tabs with only the in-table scrollers wider than the viewport, and no console error appeared. `npm run build` (vue-tsc + vite) and `npm run lint` pass; only the 100-draw PSA was run |
| 2026-10-11 | Home title animation timing corrected and the wordmark's unintended focus outline removed, frontend only (`frontend/src/views/HomeView.vue`, `frontend/src/styles.css`). (1) `home-letter-fill` no longer holds a letter at the full colour: the whole letter part in the cycle now finishes at 10% of the 5.6 s cycle instead of 58%, so after the rise and a brief `--heading-glow` bloom each letter starts back toward `--heading-dim` at once; with the 140 ms stagger (delays 1650/1790/1930/2070/2210 ms) the word carries a travelling wave of one to three brighter letters and is back at the resting tint as the trailing trace starts, rather than being held solid until the end of the loop. The keyframes now carry per-segment easing (`cubic-bezier` for the rise, the bloom and the return) and the comment block records the measured hand-off points. (2) The outline was the focus ring: the heading had `tabindex="-1"` and was focused on mount, which matches `:focus-visible` on a real fresh load (script focus with no prior pointer interaction), so `.home__wordmark:focus-visible` painted a 2px teal rectangle with a 4px offset around the heading box until the first click moved focus to `BODY`. The `tabindex`, the mount-time focus and the now-unused `onMounted`/`ref` import and `heading` ref were removed, and the rule was narrowed to `.page__title:focus-visible` so the subviews' own headings keep their outline. The heading keeps `id="home-title"`, its `aria-label="eQalb"` and the aria-hidden letter spans. No change to title size, ECG paths, text, layout, buttons, navigation, colours, tabs, disclaimers or any other component, and no R/API/Shiny change; no package added, no PSA run. Docs: `project_state.md` and `FRONTEND_PLAN.md` | Yes - measured in the running app at 127.0.0.1:5173 by seeking the animation to exact times and by live sampling. Wave: light theme letter alphas read `0.66 0.66 0.66 0.66 0.66` at 1650 ms, `1 0.83 …` at 1830 ms, `0.92 1 0.91 …` at 2000 ms (a three-letter band), `0.66 0.67 0.89 1 0.93` at 2290 ms, `0.66 0.66 0.66 0.68 0.94` at 2550 ms, `0.66 0.66 0.66 0.66 0.68` at 2700 ms and all `0.66` from 2770 ms; dark theme repeats it with `0.5` resting and `0.5 0.5 0.5 0.5 0.51` at 2720 ms. No sampled frame had all five letters above 0.9, and the most bright letters at any time was three. The bloom was tracked separately and travelled e→Q→a→l→b (peak alpha 0.36 on one letter with the previous one down to 0.03). Seam: the five colours at 0 ms and 5599 ms are byte-identical in both themes (`rgba(20,85,92,0.66)` light, `rgba(127,209,216,0.5)` dark). Outline: focusing the heading with keyboard modality active reproduced the ring (`:focus-visible` true, `solid 2px rgb(23,107,115)`, offset 4px) and it cleared on blur; after the fix a fresh load gives `document.activeElement` `BODY`, no `tabindex`, `outline-style: none` and `:focus-visible` false, unchanged after reload and after both theme toggles, and Tab never reaches the heading. Keyboard tab stops still show their outlines (`:focus-visible` true, `solid 2px` on Start analysis, Project description, Download results, the theme control, the dashboard Home button, the status chip, the assumptions disclosures, the information buttons and the tabs; the two links keep the browser's own `auto 1px`). Fallbacks: `prefers-reduced-motion: reduce` reported `animation: none` on all five letters with a single colour `rgb(127,209,216)`, no shadow, `stroke-dasharray: none` and zero running animations; `forced-colors: active` reported `animation: none`, `color: rgb(0,0,0)` and no shadows; both restored when the emulation was cleared. Layout: the heading box (180x70) and Start-analysis box (128x42) were identical in all 45 live samples at 390 px, letter widths were constant, `scrollWidth` = `clientWidth` (375) with zero overflow, and the desktop heading box stayed 271x106. Functionality: all nine tabs render and select, Home, Project description, Download results, Escape and the theme control work in both directions, and a reload produced no console error or warning. `npm run build` (vue-tsc + vite) and `npm run lint` pass; no PSA was run |
| 2026-10-11 | Home wordmark fill animation replaced, frontend only (`frontend/src/views/HomeView.vue`, `frontend/src/styles.css`). The word-wide travelling gradient — which read as a solid rectangular band sliding across the word — was removed. The heading's five characters are now individual `aria-hidden` spans (`LETTERS` in the component, `v-for` with no whitespace between them) and the heading itself carries `aria-label="eQalb"`, so the accessible name is the word exactly once; a new `--heading-glow` token was added beside the existing `--heading-dim` for the bloom. Each letter rests in `--heading-dim`, fills to `--heading` with an ease-out, gets a brief soft `text-shadow` bloom as it arrives, settles, holds, then cools back to the resting tint; only `color` and `text-shadow` animate, so nothing moves or re-flows. Timing stays on the traces' one 5.6 s cycle with all eight animations sharing a single start time: the first letter begins at 1.65 s as the leading pulse's tip reaches the left segment's end (1.64 s), the stagger is 135 ms so three letters are always mid-fill, the last letter is fully coloured at 2.58 s before the trailing pulse enters at 2.72 s, and every letter is dim again by 5.44 s so the loop seam is invisible. Reduced motion shows the full title colour with no animation and complete traces; forced colours stop the animation and paint `CanvasText`. No package added, no R/API/Shiny change, no PSA run. Docs: `project_state.md` and `FRONTEND_PLAN.md` | Yes - measured in the running app at 127.0.0.1:5173 by seeking the animation to exact times and by live sampling. Sequence (light theme, computed `color` per letter): 0 ms and 5599 ms all `rgba(20,85,92,0.66)` (identical loop endpoints); 1800 ms `e` 0.92 while `Q` starts at 0.694; 2100 ms `e` full with an 8.9 px/0.21-alpha bloom, `Q` 0.996, `a` 0.945, `l` 0.765, `b` 0.66; 2250-2400 ms the bloom travels to `Q`/`a` with the remaining letters still rising; 2582 ms all five at full `rgb(20,85,92)`; 2720 ms all five full and stable. Live 90-140 ms sampling at 390 px observed 1 to 5 distinct letter colours simultaneously, confirming a continuous flow rather than isolated flashes; the same sequence was repeated in dark mode (`rgba(127,209,216,0.5)` resting to `rgb(127,209,216)` full with a 0.45-alpha bloom). No layout shift: the heading box was identical in every sample (180x70 at 390 px, 271x106 at 1440 px, the span wrapping changing the measured width by 0.047 px from lost kerning and rounding to the same box), the five letter widths and the Start-analysis box (128x42) never moved, and the bloom at peak (16.9 px blur) produced zero document overflow. Readability: text colour only interpolates between the two existing tokens, so contrast stays between 3.45:1 and 7.86:1 light and 3.5:1 and 10.1:1 dark. `prefers-reduced-motion: reduce` reported `animation: none`, `color: rgb(127,209,216)` (dark) and `text-shadow: none` on all five letters, `stroke-dasharray: none` on both traces and zero running animations; `forced-colors: active` reported `animation: none`, `color: rgb(0,0,0)` and no shadows; both restored when the emulation was cleared. The accessibility snapshot shows one heading named `eQalb`; the heading's `aria-label` is `eQalb`, its DOM text is `eQalb`, the five spans are `aria-hidden`, and both decorative SVGs remain `aria-hidden`. Nine tabs render, Home, Project description, Download results, Escape and the theme control work in both directions, and a reload produced no console error or warning. `npm run build` (vue-tsc + vite) and `npm run lint` pass; no PSA was run |
| 2026-10-11 | Home title animation refined, frontend only, `frontend/src/styles.css` (no `HomeView.vue` change was needed, and no text, layout, button, navigation, disclaimer, tab, R, API or Shiny change). The eQalb wordmark now takes part in the same travelling signal as the two decorative traces: it rests in a subdued tint of the title colour and a soft band of the full title colour sweeps through the letters left to right. The band is a `linear-gradient` clipped to the text (`background-clip: text`, base `color` kept at the full title colour as a fallback), so the wordmark stays real, selectable text with no extra markup, aria-hidden segments unchanged. Two derived tokens were added, `--heading-dim` (`rgba(20, 85, 92, 0.66)` light, `rgba(127, 209, 216, 0.5)` dark), which keep the resting state at or above the 3:1 large-text threshold while the band's core uses the existing `--heading`. The image is 400% of the element's width with the band in its middle half, so both animation end states paint the element in the resting tint alone and the cycle restarts with no colour jump; `background-position` animates 100% → 0%, carrying the band rightwards. One shared 5.6 s cycle: the sweep runs 27% → 45%, so the light enters the first letters as the leading pulse reaches the wordmark (tip at 92 of 100) and is clear of the last ones before the trailing pulse enters its segment at 48.6%. `prefers-reduced-motion` drops the gradient and paints the wordmark in the full title colour; a `forced-colors` guard paints it with the system text colour. No package added, no PSA run. Docs: `project_state.md` and `FRONTEND_PLAN.md` | Yes - measured in the running app at 127.0.0.1:5173 against the live API by seeking the animation to exact phases: computed `background-position` is exactly `100%` at both 0 ms and 5600 ms (identical end states, no loop jump); the sweep spans 27.1% → 44.3% of the cycle (1.52 s → 2.48 s) with a strictly monotonic position (strictly left to right); the leading pulse's tip is at 92 of 100 at the sweep's start and reaches 100 at 29.3%, and the trailing pulse's tip stays outside its segment for the whole sweep, entering only at 48.6%; at the sweep midpoint the entire wordmark maps into the full-colour core (gradient fractions 0.38-0.623 across the element). Contrast: resting state 3.5:1 dark and 3.45:1 light, full-colour state 10.1:1 dark and 7.86:1 light. The wordmark box stayed 180x70 and the Start-analysis box 128x42 across 26 live samples spanning the sweep at 390px, with `scrollWidth` = `clientWidth` (375) and the gradient observed live at that width; at 1440px the box stayed 271x106. `prefers-reduced-motion: reduce` reported `animation: none`, `background-image: none` and `color: rgb(20, 85, 92)` with `stroke-dasharray: none` traces and zero running animations; clearing the preference restored the sweep. The wordmark's DOM text is still `eQalb`, both decorative segments are still `aria-hidden`, all nine tabs render, Home, Project description, Download results, Escape and the theme control work in both directions, and a reload produced no console error or warning. `npm run build` (vue-tsc + vite) and `npm run lint` pass; no PSA was run |
| 2026-10-11 | Two Home-screen follow-ups, frontend only. (1) The project-level disclaimer was removed from Home (`HomeView.vue`, the `.home__disclaimer` paragraph) and from the dashboard footer, and the footer element itself was removed from `App.vue` because it held nothing else; the now-unused `.app__footer` and `.home__disclaimer` rules were dropped from `styles.css`. `ProjectDescriptionView.vue` was not modified — it was outside the batch's allowed list and keeps its own disclaimer paragraphs, which already state that the results are illustrative or simulated for educational purposes and not a validated HTA, reimbursement submission or official recommendation. The exact sentence quoted in the request was the Batch 1 footer wording and had never been part of the Project description. R's per-result `notice` footnotes and all result-specific warnings are untouched. (2) The Home title was redesigned: the wordmark is ~50% larger (`clamp(4.35rem, 18vw, 6.6rem)`) and the ECG trace is integrated into the composition instead of sitting behind the text — two decorative `aria-hidden` SVG segments flank the real `<h1>`, both drawing the same P-QRS-T morphology, stretched by flex with `preserveAspectRatio="none"` and `vector-effect: non-scaling-stroke` so the stroke stays constant. The animated pulse is a single 18-unit normalised dash in `currentColor` (the heading token, so the same colour as the title text in both themes): it crosses the leading segment in the first 36% of a 5.6s cycle and the trailing segment resumes 2.6s in, just after the wordmark, with the offset held off-segment for the rest of the cycle. `prefers-reduced-motion` stops the animation and draws the trace complete (`stroke-dasharray: none`); at ≤640px the amplitude and stroke widths are reduced so the compressed beat stays legible. No R file, `eqalb_price.R`, Python, endpoint, threshold, distribution, Shiny, tutorial or analysis result was touched; no package was added; no PSA was run. Docs: `project_state.md` and `FRONTEND_PLAN.md` factual status wording | Yes - measured in the running app at 127.0.0.1:5173 against the live API. Disclaimer: Home and the dashboard contain no disclaimer text and no `<footer>` element, while the Project description still renders its disclaimer paragraphs; the base case and every analysis-tab `notice` are unchanged. Composition: 736px wide at 1440px (197px segments either side of a 271x106 wordmark at 105.6px type) and 342px at 390px (57x52 segments either side of a 180x70 wordmark at 70.2px type), with `scrollWidth` = `clientWidth` (375) at 390px and 0 overflow at both widths; the pulse stroke measured `rgb(127,209,216)` in dark mode and `rgb(20,85,92)` in light mode, identical to the wordmark's computed colour, and the track stayed at 0.4 opacity in both. Timing sampled at 100ms: the leading pulse was in flight 719-2542ms and the trailing one 3259-5197ms (a ~0.7s pause at the wordmark), and the title and Start-analysis boxes were identical across four samples during the animation, so nothing shifts. `prefers-reduced-motion: reduce` reported `animation-name: none` for both pulses and `stroke-dasharray: none` (a complete static trace), restored when the preference was cleared. A rasterised ink map of the 57x52px leading segment showed a distinct P bump, QRS spike and T bump rather than a filled shape. All nine tabs still render and select, the base case re-ran unchanged (€2,439 / 0.0082 / €298,966 / −€1,623), Start analysis, Project description and Download results still navigate, the theme control toggled and persisted in both directions, and a fresh reload produced zero console messages and zero page errors. `npm run build` (vue-tsc + vite) and `npm run lint` pass; no PSA was run |
| 2026-10-11 | Batch 1 of the approved UX revamp (global frontend foundation), frontend only. `InfoTip.vue`: the help popover is now an overlay — the panel is teleported to the page body, positioned in viewport coordinates and clamped to the visible client area (the stylesheet cap uses `100vw`, which includes the scrollbar, so the binding cap is set from `documentElement.clientWidth`), so opening one never expands or shifts its card, row, table or the page, stays fully visible at 390px, scrolls internally when tall, and repositions on scroll/resize; click, Enter and Space open, Escape closes and returns focus to the trigger, an outside click closes. `App.vue`: removed the repeated `.notice--banner` disclaimer and its computed; the footer, the unreachable-service state and the status-chip tooltip no longer name internal files, launch commands, ports, `Rscript` paths or worker counts; the tab list now puts "Value-based Price" immediately before the final "HTA Decision Summary" tab, which gets a status marker and `margin-left: auto`; the theme control is a small icon button. `HtaSummaryPanel.vue`: the `panel--decision` top accent follows R's overall status once the summary has been assessed. `HomeView.vue`: a minimal centred landing screen with the eQalb wordmark over an ECG pulse (a still trace under `prefers-reduced-motion`), "By Mahmood Alawi", the subtitle "An educational HTA model", the primary "Start analysis" action, Project description, Download results, LinkedIn/GitHub links and a top-right icon theme control; the hosted Shiny tutorial link and the long description paragraph were removed. `styles.css`: overlay popover styles, Home/ECG styles, the final-tab accent, the reduced-motion ECG rule, and a spacing/typography/card/button/transition refresh using the existing teal palette and tokens. Four files beyond the batch's enumerated list were touched for the same requirement — the last rendered internal filenames and launch command — in `AssumptionsForm.vue` ("Base case from the model's reference assumptions"), `SensitivityPanel.vue` (the ranges hint), `ProjectDescriptionView.vue` (the "How it is built" wording) and `api/client.ts` (the network-error message). R's per-result `notice` footnotes were kept deliberately: they are R-generated API text, and `api_contract.md` documents `notice` as carried by every response so a client cannot lose the disclaimer; the removed repeated banner was the frontend-authored one. No R file, `eqalb_price.R`, Python, endpoint, threshold, distribution, Shiny, tutorial or analysis result was touched; no package was added; no PSA was run. Docs: `project_state.md`, `FRONTEND_PLAN.md` and `frontend/README.md` factual status wording | Yes - measured in the running app at 127.0.0.1:5173 against the live API. Popovers: at 390px the panel measured 359px wide inside the 375px client area, fully inside the viewport, with zero document overflow; a metric card measured 290x97 and the PSA control row 816x69, identical before and after opening; at 768px and 1280px the control row again measured unchanged and the panel stayed inside the viewport; Enter and Space opened, Escape closed and returned focus to the trigger, an outside click closed, and a trigger click toggled. Home: the wordmark (181x70) was centred with the 512px pulse centred behind it and `aria-hidden="true"`; `prefers-reduced-motion: reduce` set the pulse to `animation-name: none` and `stroke-dasharray: none` (a still full trace) and removed the hero rise, both restored when the preference was cleared. Tab order read from the live tab list: Base case, Cost-effectiveness and PSA, Sensitivity analysis, Budget impact, Simulated survival, Value of information, DHT readiness, Value-based Price, HTA Decision Summary (final, `tabs__tab--final`, right-aligned at the strip's right edge, neutral teal marker before assessment); after "Assess HTA summary" returned Red the marker and the panel border took the danger token — dark rgb(229,115,115), light rgb(179,38,30) — with R's status word unchanged. All nine tabs rendered and were selected in turn at 390px with `scrollWidth` = `clientWidth` = 375 and no error alert; the base case ran unchanged (€2,439 / 0.0082 / €298,966 / −€1,623) and the one-way sensitivity analysis rendered its tornado canvas at 791x420. Home, Project description and Download results all navigated, Escape returned Home, and the theme control toggled and persisted the theme in both directions; no console error or Vue warning remained after a fresh reload. `npm run build` (vue-tsc + vite) and `npm run lint` pass. The only model runs were the base case, one OWSA and one HTA summary; no PSA was run |
| 2026-10-10 | Final end-to-end integration validation of the complete Vue full-analysis application, and two frontend defects fixed in the minimum way. (1) `frontend/src/export/resultsPackage.ts`: the download package's availability list covered seven analyses, so a session that had run the value of information or the value-based price produced a README claiming nothing had been run; both are now registered (labels, hints, store-driven availability) and each contributes a file set — `value_of_information.txt` plus `evppi_by_parameter.csv` when EVPPI is available, and `value_based_price.txt` plus `value_based_price_scan.csv`. `DownloadResultsView.vue`'s contents disclosure and the `frontend/README.md`, `FRONTEND_PLAN.md` and `project_state.md` status wording were updated to match. (2) `AssumptionsForm.vue`: the "x of 8 analyses stored" counter was a hardcoded total that the new tab left stale; it now reads `model.analysisCount`, the length of the same key list `resultCount` counts. No R file, `eqalb_price.R`, Python, endpoint, threshold, distribution, Shiny or tutorial change, no feature added, no package added | Yes - the full workflow was run in order in the browser against the live API and compared field by field with fresh authoritative responses, with zero mismatches on every tab: base case (€2,439 / 0.0082 / €298,966 / −€1,623), PSA at exactly `n_sim=100` / `seed=12345` (100 successful draws, mean cost 2417.75112277353, mean QALYs 0.00780670525864131, median ICER 333632.518831389, three threshold rows, plane and CEAC canvases), OWSA (14 rows, every low/high INMB in the expanded table), budget impact (€15,480,000 cumulative, five year rows, all components), simulated survival (Red with Green/Amber/Red/Amber/Red domains, log-rank note, five rules, three named tables, curve canvas), value of information (EVPI 0.110098443012998, nine EVPPI rows), DHT readiness (2/4/1 at 63,750), HTA decision summary (Red, "Conditional adoption with evidence generation", five of five analyses supplied, seven rules) and value-based price (€155.03, −€204.97, nine scan cells by R's own labels). Each tab's own button gated its request; a cold reload made no API call on Home (then only `GET /api/health` and `GET /api/defaults`, counter "0 of 9"). Stale behaviour: a year-1 engagement change issued no request, kept "9 of 9 analyses stored" and marked exactly readiness, HTA and value-based price; a WTP change marked the base case, PSA, OWSA and value-based price; aborting a readiness request showed the API error with both tables preserved and recovered on re-run; nothing was deleted by any edit, reset, error or theme switch. Results-package fix verified live: nine analyses listed as included, the button reported "Downloaded eqalb_results_2026-10-10_2152.zip with 14 files" with no console error, and an empty session still says nothing has been run. Counter fix verified live: "1 of 9", "4 of 9", "9 of 9" and "0 of 9" after a cold reload. Endpoint sweep: all nine endpoints byte-identical through the Vue proxy versus FastAPI; plumber and FastAPI byte-identical for base case, OWSA at two settings, budget impact, readiness, HTA summary and value-based price, and differing only in the three documented pre-existing representations (FastAPI's `r_model` block in health, `"max":null` in defaults, `"median_event_free_survival_years":null` in survival) confirmed by diffing to the first differing byte. Accessibility: `tablist` "Analysis", nine tabs, one `aria-selected` and one tab stop, `aria-controls` everywhere, panel named by the selected tab, ArrowRight/End/Home move and select, 0 unnamed tables of 18 rendered, Escape closes the HTA and readiness rules disclosures from the summary. Themes: 7.86–13.99 light and 10.1–13.42 dark on the value-based price tab. 390px: all nine tabs and all three views `scrollWidth` 375 = `clientWidth` 375, the mobile assumptions drawer toggles and stays within 390px. `npm run build` (vue-tsc + vite) and `npm run lint` pass; the only PSA run was the 100-draw validation, and no 1,000-draw PSA was run |
| 2026-10-10 | Phase 2 of the approved value-based price module, frontend only: the "Value-based Price" tab, last after the HTA decision summary. New `ValueBasedPricePanel.vue` renders `POST /api/value-based-price` through the existing `postValueBasedPrice()` client and `ValueBasedPriceResponse` types (no API logic added); `useModel.ts` gained `valueBasedPrice`, `runValueBasedPrice()`, `valueBasedPriceStale` and the clear/count bookkeeping; `App.vue` gained the ninth tab. The tab runs only from its own "Calculate value-based price" button, shows a pre-run note, keeps a stored result while inputs change, disables the button while in flight, marks a result computed from earlier inputs through the same request-snapshot comparison the readiness and HTA tabs use, and shows an API error without deleting the previous result. It renders R's headline (maximum acceptable price, current price, headroom in EUR and %, status band), the required relative risk reduction with R's verdict and one-way-range comparison, the 3 × 3 scan with R's axis names and per-cell status, R's summary, note, method and interpretation, the availability block with R's reasons, the scenario table and the notice. No R file, `eqalb_price.R`, endpoint, threshold, Shiny or tutorial change, no new package, and no other tab's behaviour touched. Docs: `project_state.md`, `FRONTEND_PLAN.md`, `frontend/README.md` factual status wording (tab exists, nine tabs, bundle size) | Yes - measured in the running app against the live API. No request before the button (0 calls, 0 tables, pre-run note shown); in a fresh load the only calls made were the contract ones. After a run, every rendered figure matched a fresh authoritative response with **zero mismatches**: four metric cards, required-effect table, all nine scan cells matched by R's own row/column labels, R's grid summary, note, method note, headline/required/overall interpretation, notice, and the scenario table. Favourable case (€120, 15%, year-1 engagement 85%): Green, headroom +€120.01, matches the API, merged axis label "85% (scenario and high bound)", 2 of 4 cells supporting. Not-identifiable case (both engagement values 0): R's "Not available" wording and reasons verbatim for both the price and the required reduction, "Not available" in the 2 unidentifiable cells, a dash (not a number) for the headroom. Stale pattern: changing the risk reduction to 11% kept the result and its four tables, added the warning and issued no request; re-running gave €169.07 / −€190.93, matching the API, and cleared the warning. Error path (request aborted at the network layer): the API message shown, previous result preserved field for field, button re-enabled, later run recovered. All nine tabs render with no error alert; each panel named by its tab. 390px: all nine tabs `scrollWidth` 375 = `clientWidth` 375, and the scan table scrolls inside `.table-scroll` (scrollWidth 313 > clientWidth 291) without widening the page. Both themes render; new-tab contrast 9.08:1–5:1 dark and 8.46:1–4.23:1 light, the 4.23:1 metric-label value being the shared `MetricCard` style measured identically (6.28/4.23) on the existing Base case tab. `npm run build` (vue-tsc + vite) and `npm run lint` pass; no PSA was run |
| 2026-10-10 | Phase 1 of the approved value-based price module: R logic and endpoint only, no Vue tab. New `eqalb_price.R` with `calculate_value_based_price()` (plus `eqalb_price_solve()`, `eqalb_price_required_rrr()`, `eqalb_price_grid()` and the module's formatters, status constants, level labels and interpretation sentences), joined to `MODEL_MODULES` and `MODEL_FUNCTIONS` in `api/plumber.R`, which also gained `POST /api/value-based-price` (scenario body fields, `current_price` as an explicit alias for the intervention price, `wtp` from the body or `?wtp=`, a recursive `price_clean()` shaper so no non-finite number leaves the service, and a `warnings` array). `api/main.py` gained the matching `ValueBasedPriceRequest` model and route; `api/api_contract.md` documents the endpoint, its availability block, the status bands, the ~40-run runtime and the validation practice; `frontend/src/api/types.ts` and `client.ts` gained `ValueBasedPriceResponse` and `postValueBasedPrice()` with no component importing them. The module solves the annual price at which the model's own incremental net monetary benefit is zero from two `run_eqalb_model()` runs, confirms it with a third run at the solved price, falls back to bisection if the straight line does not reproduce, finds the required risk reduction by bisection inside the model's validated 0-1 domain, and scans the supported price across `eqalb_owsa_parameters()`' existing risk-reduction and year-1 engagement bounds. No Shiny, tutorial, PSA, threshold, distribution or existing model function changed, and no package was added | Yes - brute-force €1 price grid in R (`seq(100, 250)`) gives a highest passing price of €155 against the module's €155.029800318324 (difference €0.0298, i.e. inside the €1 grid step; the confirming run's incremental net monetary benefit is −2.96e-12 and the closed form `360 + NMB / slope` reproduces the same value), matching the €155 recorded for Part 2 Case A. Default case: status Red, headroom −€204.970199681676 (−56.936167%) against €360, required reduction 24.61% (bracketed by +€6.70 at the reported value and −€9.85 just below it, outside the model's 5%-15% one-way range, precision 9.77e-4), scan €78.41 to €240.01 with 0 of 9 cells supporting €360. Favourable case (€120, 15%, 85%) Green with headroom €120.0058 and 2 of 4 cells (merged duplicate level), required 7.03%. Zero engagement: `headline.available` false ("Incremental QALYs are not positive (0), so the price at which the threshold is reached is not identifiable"), `required_effect` unavailable with the 100%-reduction reason, 6 of 9 scan cells identified, null (FastAPI) for the missing values. Negative solved price (implementation €500, no savings, WTP €1,000) reports no non-negative price with the raw root −€24.46 in the reason; WTP €1e9 reports the solved price above the model's own €1,000,000 bound. `current_price` override applies to the run and returns the documented warning. Error paths: R's messages through FastAPI (400; 422 for a wrong JSON type), and 500 on plumber for every endpoint, measured on base-case/psa/readiness too, which is pre-existing. Plumber and FastAPI responses byte-identical (9,244 bytes) and equal to a direct `calculate_value_based_price()` call. Regression: base case (ICER 298965.512965076, cost 2439.27562235471, QALYs 0.00815905352481128, NMB −1623.37026987359), OWSA at two settings, budget impact, readiness (2/4/1 at 63,750) and HTA summary (Red, "Not yet assessable", 7 rules) byte-identical between the services, `defaults` and `survival` differing only by the documented pre-existing `NA` representation; no existing model function name collides with the 30 names the new module defines. PSA regression at `n_sim = 100`, `seed = 12345`: 100 successful draws, byte-identical between the services, identical to a direct `run_psa_eqalb()` call, and identical with and without `eqalb_price.R` loaded (means 2417.75112277353 / 0.00780670525864131, median ICER 333632.518831389, P(CE) 0.00 / 0.01 / 0.07, VOI 460.262709390992 matching R's 460.26270939099163 at transmitted precision); the recorded 100-draw baseline does not reproduce and is recorded as an unresolved discrepancy in the known limitations. No 1,000-draw PSA was run. `npm run build` (vue-tsc + vite) and `npm run lint` pass; the built bundle contains no trace of the new client function (tree-shaken), so its 739 kB measures the same as before this task |
| 2026-10-10 | Cleanup after the two P2 fixes, frontend-only. The four tables that do not go through `DataTable` now carry an `aria-label` taken from the caption above them: the readiness quantitative and domain tables in `ReadinessPanel.vue`, and the HTA decision dashboard and evidence-priority tables in `HtaSummaryPanel.vue`. No caption, column, row, style or `.table-scroll` behaviour changed, and `DataTable.vue` needed no further change. Status documentation corrected: `frontend/README.md` no longer says the P2 findings are untriaged (its known limitations now record the finished triage and the two implemented fixes, and its conventions list the tab and table accessibility), and `agents.md` "Current status" says the same. No R, API, endpoint shape, threshold or Shiny change; no PSA run | Yes - `npm run build` (vue-tsc + vite) and `npm run lint` pass. Each of the four tables reports its name in the accessibility tree ("Quantitative outputs, simulated", "Domain assessment, illustrative", "Decision dashboard, illustrative", "Evidence priorities, illustrative"), the readiness and HTA tabs contain no unnamed table, and no table's visible caption, columns or rows changed. All eight tabs render with no error alert and no console error; 390px scrollWidth 375 = clientWidth 375 on every tab; contrast unchanged (active tab 10.1:1 dark / 7.86:1 light, panel heading 9.08:1 / 8.46:1) |
| 2026-10-10 | Implemented the two approved pre-1.0 P2 fixes from the UI/UX audit triage, frontend-only. (1) `SensitivityPanel.vue`: the tornado columns are computed from the displayed result (`outcome`, `outcome_label`) instead of a setup-time snapshot, so a table can no longer name one outcome while showing another's numbers; `@change="model.runOwsa()"` was removed from the ranked-outcome selector, so changing it issues no request and instead shows the tab's existing "run the analysis again to apply …" treatment; the INMB clarification is now keyed to the ranking the result used. (2) `App.vue`: the eight tabs are a `tablist` (`role="tab"`, `aria-selected`, `aria-current` on the selected tab, `aria-controls`, stable ids, roving `tabindex`, Left/Right/Home/End, Enter/Space left to the browser) with one `role="tabpanel"` named by its tab. `DataTable.vue`: an accessible name from the visible caption or a new `label` prop, set with `aria-label` so no layout or caption changes; the one-way range-editor table was named too. No R, API, endpoint shape, threshold, calculation, Shiny or tutorial change; no new package; `styles.css` untouched | Yes - build (`vue-tsc` + `vite`) and lint pass. Measured with a fetch counter in the running app: changing the ranked outcome issues no `/api/owsa` request; a QALYs run shows QALYs headers, formats, chart caption and a drawn 795x420 tornado canvas; switching back to INMB without running keeps the QALYs table plus a warning naming the QALYs ranking; a second run restores the INMB headers and the identical pre-change numbers (€-198 / €-3,049 / €2,851). Accessibility tree: `tablist "Analysis"`, eight tabs, exactly one `aria-selected="true"` at `tabindex="0"`, `tabpanel` named by its tab; ArrowRight x2 / End / Home / ArrowLeft move and select, Tab leaves the strip after one stop, Shift+Tab returns; four tables report names. All eight tabs render with no error alert; 390px scrollWidth 375 = clientWidth 375 on every tab; contrast active tab 10.1:1 dark, 7.86:1 light, panel heading 9.08:1 / 8.46:1. CSV export unchanged (`eqalb_owsa_ranked_table.csv`, 15 lines, the INMB row equal to `low_inmb`/`high_inmb`). Endpoint sweep unchanged: base case, OWSA at three settings, budget impact, readiness and HTA byte-identical between plumber 8788 and FastAPI 8000; `defaults` differs only by `,"max":null` and `survival` only by `"median_event_free_survival_years":null` (the documented `NA` representation); baselines ICER 298965.512965076, cost 2439.27562235471, QALYs 0.00815905352481128, readiness 2/4/1 at 63,750, HTA Red with 7 rules. No PSA was run |
| 2026-10-10 | Documentation-only audit of `project_state.md`, `FRONTEND_PLAN.md`, `frontend/README.md`, `api/api_contract.md` and `agents.md`. Recorded: phase 1, phase 2, the P0 fix and all six P1 findings complete (four batches); the 15 P2 findings untriaged with a read-only triage as the next task and implementation awaiting approval; R as the sole source of calculations, thresholds, statuses, interpretations and evidence priorities; PSA validation at 100 draws with seed 12345 unless a full default PSA is requested; the Vue tutorial rebuild deferred until the full-analysis Vue app is complete and the final economic module is added; reset Option A scope; and the deferred KM patient-level dataset and R figure-rendering endpoints. Removed stale wording: the plan's header status and its outdated HTA-rules limitation, the `project_state.md` "Superseded note", the README's duplicated rendering-gap and reset statements, and the uppercase `PROJECT_STATE.md` reference in `agents.md`. Corrected the `project_state.md` file map. No R, API, Shiny, Vue, threshold or endpoint change | Yes - documentation only; every statement was checked against the files it describes (e.g. the readiness panel's rules disclosure carries wording and colour meanings but no numeric threshold, and `HtaSummaryPanel.vue` does render the `rules`/`evidence_note`/`rule_note` returned by `POST /api/hta-summary`), and no code, data or configuration file was touched. No app, build or test run was needed for this task |
| 2026-10-10 | Batch 4 of the approved P1 plan (the last one): the OWSA narrative summary now comes from R for both presentations. The narrative body moved verbatim out of `app.R`'s `output$owsa_summary` into `summarize_eqalb_owsa()` in `eqalb_owsa.R`, and `app.R` calls it; the two sentences it was surrounded by moved into `eqalb_ui_copy.R` as `OWSA_SUMMARY_NOTE` (the paragraph above the summary) and `OWSA_PRERUN_NOTE` (the pre-run line), so each exists once. New `eqalb_owsa_scenario_rows()` presents a `run_eqalb_owsa()` result in the per-scenario shape the narrative reads, keeping the wording, the INMB ranking rule and the failure rule in R only. `POST /api/owsa` returns `summary` and `summary_note`; `GET /api/defaults` returns `owsa_summary_note` and `owsa_prerun_note`; `summarize_eqalb_owsa` joined `MODEL_FUNCTIONS`. The Vue sensitivity tab renders the note and the narrative above the tornado diagram (pre-wrap, so the three lines keep their breaks and wrap at 390px) and shows Shiny's pre-run sentence before a run, plus one factual line when the ranked outcome is not INMB because R's narrative always ranks by the INMB range. `types.ts` and `api/api_contract.md` document the fields; `api/main.py` documents the endpoint. No model arithmetic, threshold, distribution or Shiny behaviour changed | Yes - the five moved statements are token-identical to the removed lines (deparsed-statement digest `e273d084f25ee77ceee1b1d3ade41391145a324a` on both sides; only `result <- owsa_result()` became the call argument); `app.R` sources, builds its UI with the note string exactly once and defines `server`. All three required narratives were byte-identical to a direct R call and to plumber: the default run; WTP €200,000 where all three top parameters cross the threshold ("crosses the WTP decision threshold" each, base line "€-807 at WTP €200,000/QALY"); and a failing scenario (`time_horizon` low bound 0 → `low_warning` "Model failed: cycles > 0 is not TRUE", no INMB range, so the parameter drops out of the ranking exactly as Shiny's `sort()` does, with the panel's existing bound-warning disclosure reporting it and no error raised). The failure sentence was exercised directly ("Time horizon: at least one scenario failed") on a frame with a failed parameter in the top three — a branch a normal run cannot reach, in Shiny either. In the browser every rendered narrative line equals the API line at both thresholds, the note matches, the summary sits above the tornado, and the ICER-ranking case shows the INMB clarification; all eight tabs render at 1280px and 390px with no error and no overflow (scrollWidth 375/390; narrative element 293px with no internal overflow, three lines kept); narrative contrast 13.42 dark / 13.99 light; build and lint pass; the endpoint sweep is unchanged (base case, OWSA at three settings, budget impact, readiness and HTA byte-identical between the services; survival/health/defaults and an OWSA run with a failing bound differ only in the documented pre-existing `NA` representation, where `summary` and `summary_note` still match exactly) |
| 2026-10-10 | Fixed the value-of-information precision defect in the FastAPI worker, ahead of Batch 4. `api/r_worker.R` now rebuilds a posted request body with `jsonlite::toJSON(..., digits = NA)`, the setting the reply writer in the same file already used, instead of jsonlite's default of four decimal places; nothing else in the worker's request or reply shaping changed, and no PSA logic, VOI calculation, threshold, response shape or Shiny file was touched. `api_contract.md`, `project_state.md`, `FRONTEND_PLAN.md` and `frontend/README.md` had the precision limitation removed and corrected (the residual caveat — 15 significant digits, the precision both services transmit — is stated where it belongs) | Yes - before the fix, a posted `incremental_cost` 1234.5678901234 arrived as 1234.5679 through FastAPI while plumber returned it unchanged; after the fix FastAPI returns 1234.5678901234 and 0.00123456789012 as sent. The documented case reproduced end to end (1,000-draw PSA at seed 12345 fetched over HTTP, draws posted back as a client would): EVPI 4.70724749145015 from FastAPI, plumber and a direct `voi_evpi()` call, response bytes identical between the services, pre-fix FastAPI value 4.6942935. At `wtp` 300,000 with 100 draws (8 of 9 EVPPI rows non-zero) every row matches the direct R call at transmitted precision, largest relative difference 1.75e-15. Measured rather than assumed: `digits = NA` writes 15 significant digits and a client-held draw set survives the worker rebuild `identical()`, so the round trip is lossless. Regression: `/api/base-case`, `/api/owsa`, `/api/budget-impact`, `/api/readiness` byte-identical to the untouched plumber service with all key values matching pre-fix records (ICER 298965.512965076, OWSA 14 rows / 2851.21104464014, budget 10,836,000, readiness 63,750 with 2/4/1, HTA Red with 7 rules, PSA means 2517.24320161568 / 0.00794926986130171); `/api/survival`, `/api/health`, `/api/defaults` differ from plumber only in the documented pre-existing `NA` representation, none of which passes through the edited branch; all eight tabs render at 1280px and 390px with no overflow (scrollWidth 375/390); both themes readable (dark 6.28-14.92, light 4.16-13.0); build and lint pass |
| 2026-10-10 | Batch 3 of the approved P1 plan: the PSA defaults and permitted range now match the Shiny control. `simulation_defaults()` in `api/plumber.R` reports 1,000 draws and seed 12,345 (was 200/1233) plus Shiny's control limits (`psa_n_sim_min` 100, `psa_n_sim_max` 10000, `psa_n_sim_step` 100, `psa_seed_min` 1), published by `GET /api/defaults`; `POST /api/psa` takes its defaults and bounds from the same function, so the offered range is the validated range and out-of-range values keep R's own messages. Vue reads those bounds from the contract (`useModel.ts` `psaBounds`, defaults 1,000/12,345) and the PSA panel replaces the invented 0.27 s-per-iteration estimate with one measured from the last completed run, states that the tab must stay open and the button is disabled while running, and carries a practical-limit note (roughly 5,000 draws exceeds the API's 15-minute timeout; the value-of-information panel needs at least 100 draws). No distribution, draw, threshold or calculation changed, and no Shiny file was touched. Docs: `api_contract.md` (defaults bullet, `/api/psa` query line, cost sentence, worker-protocol example, two new limitations), `api/main.py` OpenAPI descriptions, `api/r_worker.R` protocol-example comment, `frontend/README.md`, `FRONTEND_PLAN.md` | Yes - `/api/defaults` reports 1,000/12,345 and the four bounds; `n_sim` 10001/10/99 and `seed` 0 rejected with R's messages; 10000 and 100 accepted (proven through the argument-order validation path); a default PSA ran 1,000/1,000/0 in 179.8 s and every key output (mean cost 2420.86625982289, mean QALYs 0.00795785619474315, mean NMB −1625.08064034857, median ICER 331546.182547232, P(CE) 0.001/0.015/0.075 at 50k/100k/150k, 201 CEAC points) matched a direct `run_psa_eqalb(n_sim = 1000, seed = 12345)` call; the VOI difference against FastAPI (4.6942935 vs R's 4.70724749145016) was traced to the worker's `toJSON()` rounding posted bodies to jsonlite's default four decimal places (measured: 1234.5678901234 arrives as 1234.5679) and was fixed as the next task by passing `digits = NA` there; it is pre-existing and affects no value R returns; browser controls showed 1000/10000/100/12345 and a 100-iteration run sent `/api/psa?n_sim=100&seed=1&wtp=100000` matching the display; all eight tabs render; no 390px overflow; both themes; build and lint pass |
| 2026-10-10 | Batch 2 of the approved P1 plan: interface wording shared by both presentations. New `eqalb_ui_copy.R` holds `CC_INFO_TEXT` and the four HTA rule constants moved out of `app.R` verbatim (hash-verified), sourced by `app.R` and by `api/plumber.R`. `GET /api/defaults` publishes `info_text` (17 analysis explanations, keyed as Shiny keys them; tutorial/Part 2 and unused `willingness_to_pay` excluded) and an `info` field per parameter and per readiness parameter; `POST /api/hta-summary` publishes `rules`, `evidence_note` and `rule_note`. New accessible `InfoTip.vue` (button with aria-label/aria-expanded/aria-controls, Enter/Space open, Escape closes and refocuses, outside click closes, in-flow panel that cannot widen the page) attached to the model assumptions, the global threshold, the budget population and uptake, the readiness review-minutes input, the PSA count/seed/mean cost/mean QALYs and EVPI/EVPPI, replacing the non-focusable metric hint; the HTA panel renders the seven rules in its own disclosure with the evidence and rule notes | Yes - both moved blocks byte-identical before and after (`ef2ea227…`, `6459d99e…`), and `HTA_SUMMARY_RULE_NOTE` digests to the same value as in the committed `app.R` (`c925f4c8…`), so the exported README text is unchanged; `app.R` sources, builds its UI and defines `server`; every exposed help string equals its `CC_INFO_TEXT` entry in R and over HTTP (0 mismatches, forbidden keys absent); all rendered tips matched the live `/api/defaults` text; keyboard, Escape, focus return, outside click and ARIA wiring verified on real triggers; the HTA disclosure rendered exactly 7 rules with both notes matching; 36 layout measurements across eight tabs plus the sidebar at 390/768/1024/1280px with every panel open showed no page overflow (an absolutely positioned panel did overflow at 390, 1024 and 1280px before the fix); light and dark readable; all eight tabs render; build and lint pass; ten-endpoint regression sweep unchanged |
| 2026-10-10 | Batch 1 of the approved P1 plan, frontend only. Reset Option A: "Reset model inputs" restores the 16 model assumptions and the WTP threshold and nothing else; `applyDefaults()` no longer clears results, so readiness and the HTA summary survive it; the PSA/KM/budget/readiness/population/OWSA settings are untouched; the button is enabled whenever its own scope differs; a separate confirmed "Clear all results" action was added, and readiness gained Shiny's "Reset values". The readiness and HTA summary tabs now snapshot their request and warn when their inputs have changed since the stored run. Exports: `export/csv.ts` (+ the CSV helpers moved out of the results package) and `export/tabExports.ts` add the base-case CSV in Shiny's own layout, the OWSA ranked-table CSV and the Kaplan-Meier summary-table CSV, each disabled until its run and each stating its shape difference on the tab. No R file, endpoint, threshold or calculation changed | Yes - the base-case CSV matched Shiny's export computed in R from the same inputs row for row; the survival CSV matched the live API cell by cell (zero mismatches) and the OWSA CSV matched the live ranked table; all three buttons were disabled before their runs; reset restored 360/100,000, kept the stored readiness result, left analysis settings and the shared population alone, and disabled itself; a readiness input change marked the assessment stale without deleting it; readiness "Reset values" restored access 40→85 and cleared readiness only; "Clear all results" required confirmation, Cancel preserved everything, confirming cleared all results with inputs untouched; all eight tabs render; 390px has no page-level overflow on any tab; both themes readable (danger styling fixed to win over the base button rule); build and lint pass; nine-endpoint regression sweep unchanged |
| 2026-10-10 | Implemented the audit's P0 Kaplan-Meier interpretation parity fix. R/API: `km_number()`, `km_p_value()` and `assess_km_interpretation()` moved verbatim from `app.R` into a new `eqalb_km_interpretation.R` sourced by both `app.R` and `api/plumber.R`; the module joined `MODEL_MODULES` and its functions `MODEL_FUNCTIONS`, and `POST /api/survival` now returns `interpretation` (the complete `assess_km_interpretation()` result — `overall_status`, five `domains` with statuses and R's explanations, `counts`, `interpretation`, `rules`, and `display` with R-formatted statistics) plus `logrank_note` (Shiny's descriptive log-rank line with the simulated-data notice). Frontend: the survival tab renders that panel (overall status, R's paragraph, counts table, hazard-ratio and log-rank lines, the descriptive log-rank note, one traffic-light card per domain, the rules in a collapsed disclosure) and the unqualified "log-rank p = …" was removed from the metric card; chart, risk table, diagnostics and action gating unchanged. `api_contract.md` and `types.ts` document the fields; `client.ts` unchanged | Yes - extracted block byte-identical (digest `a40b1173…`), and the four pre-extraction scenario digests (`2750788a…`, `ee0294f7…`, `339d41e1…`, `6d8ee20f…`) reproduced exactly; `app.R` sourced end to end and produced the same result; the endpoint, called directly in a fresh R process with Shiny not loaded, returned `overall_status`, `domains`, `interpretation` and `rules` `identical()` to a direct R call; live HTTP `/api/health` `model_ready: true` and the default run matched the direct call field for field; the rendered panel matched the live response with zero mismatches across 5 domains, 5 rules, counts, both bullets, the logrank note and the interpretation paragraph; panel absent before the run; all eight tabs render with no error; 390px fresh-load and resize both give scrollWidth 375; light and dark both readable; build and lint pass |
| 2026-10-10 | Added a Home screen to the browser interface (`frontend/src/views/`, `frontend/src/export/`, `frontend/src/App.vue`, `styles.css`): the app now opens on a centred landing page (title, description, restrained simulated-data disclaimer, Start analysis, Project description, Download results, theme control, hosted-Shiny tutorial link, creator credit, LinkedIn and GitHub links) with two subviews and Back navigation plus Escape, and a compact persistent "Home" control in the dashboard header. The contract is fetched only when the dashboard is first opened, so arriving at the Home screen makes no API request. Download results assembles a ZIP in the browser from results already held in the session only (dependency-free store-only ZIP writer), lists which analyses are included and which have not been run, and states the remaining backend gap (R-rendered chart images) instead of inventing or dropping output. Presentation shell only: no R file, endpoint, threshold, calculation or analysis tab changed, and all eight tabs keep their state across a visit to Home | Yes - Home renders first with no `/api/` request (40 module fetches, zero API calls); Start analysis opens the dashboard and loads the contract; Home returns and the previous base-case (€298,966 / 0.0082) and readiness (89,250.0) results are still displayed with no re-run; all eight tabs render and had not auto-run; Project description shows the Shiny wording, contact address and LinkedIn/GitHub links; Escape and Back both return Home; theme toggle switches dark↔light and restores; the export ZIP captured from the button handler was a valid archive (`PK\x03\x04`, end-of-central-directory present) named `eqalb_results_2026-10-10_0549.zip` with README.txt plus the three CSVs for the two analyses actually run, and its readiness and cost-effectiveness rows matched the live API values; no page-level overflow at 390px on Home, Project description, Download results or the dashboard; Tab order and focus states work; build and lint pass |
| 2026-10-10 | Added `dev.sh` in the project root, a local development control script for the browser-stack services (`start`, `stop`, `restart`, `status`, `logs [r|api|vue] [lines]`): it starts the existing launchers unchanged (R Plumber on 8788, FastAPI on 8000 so both APIs can run at once, Vue dev server on 5173 with its proxy pointed at FastAPI), runs them in the background with output in `.dev-logs/` and pids in `.dev.pids` (both now git-ignored), reports a service whose port is occupied as already running, stops only the recorded ids (falling back to the three development ports when the pid file is missing), and reports `/api/readiness` and `/api/hta-summary` reachability per service. Development convenience only: no R model logic, API logic, Shiny file, Vue component or endpoint behaviour changed | Yes - start, status, restart, stop and logs all exercised, including the no-pid-file fallback stop and the idempotent re-start; all six endpoint checks reported ok; unrelated listeners on 7788 and 5174 were left untouched; HTTP 200 confirmed independently for both APIs, the Vue app and the proxy; browser reloaded and the HTA tab ran through the new proxy; all three services left running |
| 2026-10-10 | Added the Vue Phase 2 HTA Decision Summary tab (`frontend/` only): an eighth tab calling `POST /api/hta-summary` behind an explicit "Assess HTA summary" action and rendering the response unchanged — overall status and provisional position, R's interpretation, the five-row decision dashboard with traffic-light badges, the evidence-priority table plus a disclosure with the remaining columns, R's priority summary, and an availability block (analyses included, R's not-assessable domains, unsupplied request fields) that is also shown as a visible notice when something is missing. The request body is assembled only from results the other tabs already produced; the readiness block is sent only once readiness has been assessed, and the summary uses the PSA's threshold when one exists. No change to R files, Shiny, endpoints, thresholds or other tabs. Also relaxed `HtaSummaryInputs` to `Partial<ScenarioInputs>` and `missing_inputs` to `string[] | null` | Yes - empty-body state, complete default-analysis state (all five domains, nine priorities, interpretation and priority summary identical to the live response), a Red-readiness state, and an incomplete state with PSA/VOI/readiness absent all rendered R's exact wording; no request before the button (0 counted after five other analyses); previous result kept while analyses ran; failure surfaced the API message and the next run cleared it; keyboard activation, 390px with no page-level overflow, both colour modes; all seven other tabs render; build and lint pass |
| 2026-10-10 | Added the Phase 2 HTA decision-summary API endpoint: `POST /api/hta-summary` in `api/plumber.R` calling `assess_hta_decision_summary()` and `build_hta_evidence_priorities()` unchanged, with optional completed-analysis inputs (icer, PSA probability and mean NMB, EVPI, highest EVPPI, EVPPI table, cumulative budget impact and its three components), the six scenario fields behind the priority signals, and a `readiness` object carrying the `/api/readiness` inputs whose seven domains are derived by `calculate_readiness()`. Returns both R results, `wtp`, `availability` and the notice; absent inputs stay `NA` so R reports its own "Not available"/"Not yet assessable"/"Not yet quantified"/"Not yet available" wording rather than a guessed position. Added the FastAPI proxy model and route, `api_contract.md` docs, and the `types.ts`/`client.ts` contract with `postHtaSummary()`. No change to R logic, `app.R`, Shiny, thresholds, tutorials, exports, frontend components or existing endpoints | Yes - complete default-analysis state compared in one fresh R process against direct calls to both functions: domain rows, overall status, position, interpretation, all nine priority rows and the priority summary identical string for string; a Red-readiness state returned `Implementation readiness = Red` with all priorities High, identical to R; an incomplete state (no PSA/VOI/readiness) returned R's not-yet-assessable wording with `missing_inputs` and `not_assessable_domains` matching, no guessed position; R-derived 400s for out-of-range, invalid-level and wrong-shape inputs with 422 left to the request model; all ten routes answer 200, readiness defaults and the Shiny readiness and HTA tabs unchanged; build and lint pass |
| 2026-10-10 | Three presentation-parity changes to the Vue DHT Readiness tab only (`frontend/src/components/ReadinessPanel.vue`): the domain table header now reads "Plain-language interpretation" as in Shiny, and the old traffic-light pointer became an on-demand "Traffic-light rules" disclosure carrying the exact Shiny rule wording and colour meanings copied unchanged from `app.R` (`DHT_THRESHOLD_NOTE`, `DHT_TRAFFIC_LEGEND`), opening by mouse or keyboard and closing with Escape. No change to R files, Shiny, API endpoints, readiness logic, thresholds, global state or other tabs; pre-run notice and Reset behaviour unchanged | Yes - default (63,750 / 44,625 / 26,775 / 60.0% / 89,250.0, 2G/4A/1R), poor (4,000 / 1,200 / 400 / 33.3% / 14,400.0, 6R) and all-Green (85,500 / 68,400 / 59,850 / 87.5% / 41,040.0, 7G) outputs identical to the API response field for field; header and disclosure wording compared with the DOM and with `app.R` exactly; zero readiness requests before the button; opens by mouse/Enter/Space and closes with Escape; no overflow or internal scrolling at 390px in both colour modes; other six tabs render; build and lint pass |
| 2026-10-10 | Added the Vue Phase 2 DHT Readiness & Implementation tab (`frontend/` only): a seventh tab calling `POST /api/readiness` behind an explicit "Assess readiness" action and showing the R result (quantitative outputs table, seven-row domain table with traffic-light badges, interpretation, notice), with every control, range and level set read from the `readiness` block of `/api/defaults`. The clinical target population and the two engagement values are shared assumptions shown read-only; the population moved to a single `targetPopulation` used by budget impact and readiness (contract default 100000, matching Shiny's single shared control). Two presentation-only CSS additions. No change to `app.R`, Shiny, R model files, endpoints, thresholds, exports or the HTA decision summary | Yes - default inputs returned 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0 and 2 Green / 4 Amber / 1 Red as displayed; a poor scenario showed 6 Red / 1 Green and an all-Green scenario 7 Green; captured request bodies matched the controls; shared engagement changes flowed into the request and output with no duplicated control; an out-of-range input showed R's own 400 message; the six phase-1 tabs still run with no console errors; build and lint pass; no page-level overflow at 390px in either colour mode |
| 2026-10-10 | Added the Phase 2 DHT readiness API contract: `POST /api/readiness` in `api/plumber.R` calling `calculate_readiness()` unchanged (percentages, minutes and level vectors as the R function expects, full calculation object plus `notice` in the response), a `readiness` block in `GET /api/defaults` with the eight full-analysis inputs and the two level sets with their Shiny defaults, the matching FastAPI proxy, and the `types.ts`/`client.ts` contract and `postReadiness()` call. No readiness tab, no HTA endpoint, no change to `app.R`, Shiny, readiness logic, tutorials or other endpoints | Yes - default, all-Red and all-Green scenarios verified over HTTP against `calculate_readiness()` called directly in R (every field identical in JSON), R-derived 400s for out-of-range and invalid-level inputs with 422 left to the existing request model, `/api/defaults` checked against the Shiny readiness sidebar, the other eight endpoints and the full smoke test unchanged, build and lint passing |
| 2026-10-10 | Extracted the reusable DHT readiness logic from `app.R` into a new `eqalb_readiness.R` (the two level vectors, `DHT_DISCLAIMER`, `dht_format_count()`, `dht_format_rate()` and `calculate_readiness()`), sourced it from `app.R` and added it to `api/plumber.R`'s `MODEL_MODULES`. Refactor only: no route, no UI, no threshold, no wording and no calculation changed | Yes - complete returned object hashed before and after for three scenarios (default, all-Red, all-Green): whole-object and per-field digests identical; module sourced standalone and through `api/plumber.R` without Shiny, both reproducing the same digest; DHT Readiness tab, HTA decision summary, Tutorial Part 1 Step 3 and Tutorial Part 2 readiness re-checked in the running app with zero output errors |
| 2026-10-10 | Added the additive browser stack: FastAPI service in `api/` reusing the `api/plumber.R` route handlers through a persistent Rscript worker, and a Vue 3 + Vite frontend in `frontend/` covering the base case, cost-effectiveness plane, PSA and CEAC, tornado with editable ranges, budget impact, simulated Kaplan-Meier and value of information. `app.R` and the model modules were not modified. | Yes - every tab exercised in the browser against a running API, endpoints checked over HTTP, build and lint passing |
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
| 2026-10-06 | Added the creator credit "By Mahmood Alawi" and LinkedIn / GitHub links to the home title screen (subtle subtitle styling, centred wrapping link row, hover and focus states, new tab with `rel="noopener noreferrer"`); CSS and markup only | Yes - tested in the running app, light and dark mode, 1260px / 390px / 300px widths; model outputs unchanged |
| 2026-10-06 | Simplified the HTA decision-summary tab: traffic-light rules moved into an on-demand bslib popover and the evidence-generation plan into a collapsed bslib accordion; removed the duplicated "Simulated illustrative analysis" banners from the analysis tabs and Kaplan-Meier headings | Yes - tested in the running app: accordion collapsed/expanded, popover by mouse and keyboard, light and dark mode, 390px width; model and HTA outputs identical |
| 2026-10-07 | Added a five-step Guided tutorial for beginners plus a once-per-session welcome prompt, reusing the existing model, budget-impact, sensitivity, readiness and HTA functions and sharing the CE plane and BIA chart builders | Yes - tested in the running app: step order, slider updates, Next/Back/Exit/finish, modal buttons and tab switching, light and dark mode, 390px width; tutorial values match the model functions exactly and all existing analysis outputs are unchanged |
| 2026-10-07 | Refined the Guided tutorial and welcome prompt only: added utility and follow-up engagement controls to step 1, a price-carryover note and return-to-step-1 control in step 2, interoperability and language yes/no items replacing algorithm governance in the readiness step, a tutorial decision summary with no "Not available" labels, a tutorial overall status excluding simulated clinical evidence, a short tutorial traffic-light rules popover, a collapsed tutorial evidence-priorities accordion, a Finish tutorial completion note recommending a PSA, and centre-aligned welcome prompt content. The tornado step was removed from the tutorial and remains in the full analysis | Yes - tested in the running app: both new step-1 controls change the result and match `run_eqalb_model()` exactly, price carried into the budget impact, state preserved across the return control, both checklist items change existing readiness domains, tutorial overall status stays Amber while simulated evidence shows Red, popover and accordion open by mouse and keyboard, Finish and both full-analysis routes work, welcome prompt centred and not repeated, no duplicate IDs, 390px width and dark mode fine; full-analysis base case, PSA (seed 12345, n=100), VOI, budget impact, tornado, readiness (7 domains), HTA summary and ZIP export all unchanged |
| 2026-10-07 | Tutorial-only follow-up: step-1 follow-up engagement now drives the step-3 readiness results through `calculate_readiness()`; the tutorial decision summary shows only cost effectiveness, budget impact, clinical evidence maturity and implementation readiness with tutorial-only thresholds (`build_tutorial_summary()`, `tutorial_ce_status()`, `tutorial_budget_status()`, `tutorial_readiness_status()`) and no longer shows economic value or decision uncertainty; step 4 keeps only Finish tutorial; the completion card offers Open full analysis and Restart tutorial and is centre-aligned with CSS scoped to `.cc-tutorial-complete`; the now-unused `main_tab` id and the `Open Value of information` route were removed | Yes - tested in the running app: follow-up 42 to 10 changes active users at follow-up 26,775 to 6,375 and the Engagement domain Amber to Red in step 3, cost-effectiveness bands Green/Amber verified, budget bands EUR 1.548m Green, EUR 6.192m Amber, EUR 15.48m Red, readiness Green at four Green domains and Red when the existing readiness result is Red, no "Not available" or economic-value/decision-uncertainty boxes, completion card centred with Exit tutorial below it, no duplicate IDs (225 elements), light/dark and 390px fine; full-analysis base case ICER EUR 298,965.51, PSA (seed 12345, n=100) mean cost EUR 2,417.75 / mean QALYs 0.00781 / P(CE) 1.0%, EVPI EUR 0.11, readiness 63,750 eligible, tornado, HTA summary and the ZIP export unchanged |
| 2026-10-07 | Tutorial-only wording fix for the Engagement readiness description: `tutorial_engagement_explanation()` names year-1 engagement, follow-up engagement or both according to which input is limiting, so a high follow-up value is no longer described as low. The Green/Amber/Red classification and the shared `calculate_readiness()` text are unchanged | Yes - tested in the running app: year-1 20 / follow-up 90 gives the year-1 wording with status Green, follow-up 20 gives the follow-up wording with Red, both 20 gives the combined wording, both 70 and both 60 give the favourable wording, and 45/45 gives a neutral numeric wording; the full DHT Readiness tab and `dht_readiness_results.csv` still carry the original wording, base case ICER EUR 298,965.51, PSA (seed 12345, n=100) unchanged, ZIP export HTTP 200 with the same file set, 220 element ids with no duplicates, app.R parses |
| 2026-10-07 | Added 20 keyboard-accessible full-analysis information controls (`cc_info()` / `cc_label()` with text in `CC_INFO_TEXT`): 18 next to the main inputs (price, implementation cost, RRR, year-1 and follow-up engagement, the three utilities, PSA simulation count, PSA seed, both WTP thresholds, budget-impact population and uptake, sensitivity-analysis WTP, KM seed, DHT target population and review minutes) plus EVPI and EVPPI on their headings. GUI only, no input renamed, no calculation changed, and the Guided tutorial untouched | Yes - tested in the running app: every icon renders inside the correct existing label (verified by the label's `for` attribute) with the exact requested wording, popovers open by mouse click and by keyboard (Shift+Tab then Enter) with a visible focus outline, no duplicate ids (240 with 0 duplicates, and none created by an open popover), sliders still respond with the icon inside their label, base case ICER EUR 298,965.51 (EUR 2,439.28 / 0.00816), PSA (seed 12345, n=100) mean cost EUR 2,417.75 / mean QALYs 0.00781 / P(CE) 1.0%, EVPI EUR 0.11, readiness 63,750 eligible, tornado and KM modules render, ZIP export HTTP 200 with the same 12 files, tutorial shows 0 info controls and its 4 steps and completion card are unchanged, light and dark mode readable, 390px width with no horizontal overflow and the popover fitting inside the viewport, app.R parses |
| 2026-10-07 | Two visual corrections to those information popovers: the popover now carries `customClass = "cc-info-popover"` and scoped CSS removes the heading top margin, so the header starts at the top with no light strip and the close button sits inside the header band; the plain `ⓘ` character was replaced by a CSS-drawn circular lowercase `i` in the teal brand colour. Popover text, control count, control placement, IDs and behaviour are unchanged, and other popovers keep their original styling | Yes - tested in the running app: header top gap is 1px (the popover border only) with `margin-top: 0`, header width equals the popover content width so it is full-bleed, and the close button (11-26px) lies inside the header (1-36px) in both light and dark mode; the arrow is unclipped; the 20 information controls each render a 14.4px circled `i` with their original aria-labels, keyboard Enter opens and Escape closes the popover with a 2px teal focus outline, the popover fits the 375px viewport with no horizontal overflow, the traffic-light rules popover still has `hasInfoClass: false` and its original 20px header margin, no duplicate ids (240), base case ICER EUR 298,965.51, PSA (seed 12345, n=100) mean cost EUR 2,417.75 / P(CE) 1.0%, EVPI EUR 0.11, ZIP export HTTP 200 with the same file set, tutorial unchanged, app.R parses |
| 2026-10-07 | Applied the same header fix to the two traffic-light-rules popovers, which had kept the white strip: both now pass `options = list(customClass = "cc-rules-popover")` and the scoped CSS selectors were extended to cover that class. No text, ID or behaviour change | Yes - tested in the running app: both the tutorial rules popover and the full-analysis rules popover now report `headerMarginTop: 0px`, a 1px header top gap (the popover border only), a 7px top header radius matching the outer container, and the close button inside the header band in light and dark mode (`#1e3039` header on `#16242c` popover in dark); the arrow stays visible, popover text and item counts are unchanged, the popover fits the 375px viewport with no horizontal overflow, the 20 information popovers still behave as before, no duplicate ids (240), base case ICER EUR 298,965.51 and PSA (seed 12345, n=100) mean cost EUR 2,417.75 / P(CE) 1.0% unchanged, ZIP export HTTP 200 with the same file set, app.R parses |
| 2026-10-07 | Rewrote the Project Description content only: it now distinguishes the fictional intervention `eQalb` from the interactive R Shiny application that simulates a simplified HTA of it, lists the analyses included, states that all outputs and traffic-light rules are illustrative teaching rules, and adds a "Feedback and contact" section with a `mailto:` email link and the LinkedIn link opening in a new tab. Scoped `.cc-desc` CSS adds paragraph spacing and keeps the copy centred with the rest of the view; heading, card layout, Back button, IDs and all other views unchanged | Yes - tested in the running app: all five paragraphs and the contact paragraph read exactly as specified, every paragraph reports `text-align: center` in light and dark mode with a 1.6 line height, the email anchor href is `mailto:smalawi2018@gmail.com` and clicking it produced a `mailto:` request the browser hands to the mail client (`net::ERR_ABORTED`), the LinkedIn anchor href is exactly `https://www.linkedin.com/in/mahmoodalawi` with `target="_blank"` and `rel="noopener noreferrer"`, Back returns to the title screen, one card and one Back button only, at 390px the view has no horizontal overflow and the copy stays readable, 241 element ids with 0 duplicates, base case ICER EUR 298,965.51 (EUR 2,439.28 / 0.00816), PSA (seed 12345, n=100) mean cost EUR 2,417.75 / mean QALYs 0.00781 / P(CE) 1.0%, tutorial unchanged (4 steps, 0 info controls, centred completion card), six dashboard tabs in the same order, Start analysis disclaimer intact, ZIP export HTTP 200 with the same file set, app.R parses |
| 2026-10-07 | Final full-analysis GUI changes: an information control next to Annual healthcare savings; the deterministic sensitivity-analysis ranges moved out of Global Assumptions into the Sensitivity Analysis sidebar with their explanation and unchanged values/IDs; subheader explanations on Sensitivity Analysis, Kaplan-Meier and DHT Readiness; the permanently visible traffic-light explanations in Kaplan-Meier (a `<details>`), DHT Readiness (Traffic-light key list) and Value of information (thresholds paragraph) replaced by the shared `cc_rules_popover()` control; and the budget-impact, PSA-distribution and DHT notice boxes removed. No tutorial, model, ID or export change | Yes - tested in the running app: the savings control carries the exact requested text inside its own label; the four `ow_sa_*utility*` inputs now exist only in the Sensitivity Analysis sidebar with values 0.7/0.9/0.45/0.75 and the explanation appears exactly once, with no range control or explanation left on the Cost-effectiveness tab; all three subheaders present; all three rules popovers open by mouse click and by keyboard Enter, close on Escape, keep the original wording (3 DHT legend items, 5 KM rules, the VOI thresholds split into readable bullets) and report `headerMarginTop: 0px`, a 1px header top gap and the close button inside the header in light and dark mode; the three notice boxes are gone with no `.alert` left on the Cost-effectiveness tab, while the Project description and Start analysis disclaimers remain; base case ICER EUR 298,965.51 (EUR 2,439.28 / 0.00816), PSA (seed 12345, n=100) mean cost EUR 2,417.75 / mean QALYs 0.00781 / P(CE) 1.0%, EVPI EUR 0.11, budget impact, tornado and KM all render, ZIP export HTTP 200 with the same 12 files and sizes, 241 element ids with 0 duplicates, tutorial unchanged (4 steps, own rules button, centred completion card), app.R parses. Narrow-viewport table overflow at 390px was confirmed to be identical in the pre-change HEAD version (DHT scrollWidth 453, KM 1040) and is therefore pre-existing |
| 2026-10-07 | Reduced the PSA willingness-to-pay controls to one: removed the visible "Maximum WTP threshold" input, its `validate()` need and its `run_psa_eqalb(max_wtp = ...)` argument, and added `psa_ceac_wtp_max(reference_wtp)` so the CEAC x-axis limit is `max(2 x reference WTP, EUR 100,000)` internally. The remaining control is relabelled "Reference WTP threshold - Main threshold used for the headline probability of cost-effectiveness" with its own `CC_INFO_TEXT$reference_wtp` explanation, and the CEAC subtitle now explains the curve and its axes before the existing illustrative-uncertainty sentence. GUI and plotting-display only: no PSA sampling, CEAC probability calculation, ID (other than the removed input), export, tutorial or navigation change | Yes - tested in the running app: exactly one WTP input remains (`#psa_reference_wtp`, value 100000) with `#psa_max_wtp` and `#psa_max_wtp_info` absent from the DOM; PSA (seed 12345, n=1000) mean cost EUR 2,420.87 / mean QALYs 0.00796 / P(CE) at the reference EUR 100,000 = 1.5%, identical to a direct `run_psa_eqalb()` call and to `max_wtp = 400000` (the `results` data frame is `identical()`, only the `ceac` rows change), and the reference row of the PSA summary drives the headline probability; CEAC renders after the PSA with x-axis 0-200,000 and breaks 0 / 50,000 / 100,000 / 150,000 / 200,000, so it still contains the reference WTP, and `psa_ceac_wtp_max(30000)` gives a 0-100,000 axis that also contains its reference; the new subtitle string is verified by `strwrap()` (5 wrapped lines: explanation first, then the existing illustrative-uncertainty sentence) and the plot keeps 3.06 in of its 5 in height for the panel; the new information popover opens by mouse click and by keyboard Enter with `aria-label` "Information about the reference WTP threshold" and reads exactly as specified, keeping `cc-info-popover` scoping, `margin-top: 0` and a header-only strip in light (`rgb(30,48,57)`-style dark-mode check) and dark mode; base case ICER unchanged at EUR 298,965.51 (EUR 2,439.28 / 0.00816); all six tabs render in the same order with their subheaders and rules popovers, the tutorial is unchanged (4 steps, step 4 with only Finish tutorial, completion card with Open full analysis and Restart tutorial, centred); 0 duplicate ids in every view; 390px width with no horizontal overflow and the CEAC image fitting its 327px container; ZIP export HTTP 200 with the same file set and no reference to a maximum WTP; app.R parses with `shinyApp(` once and `runApp(` still absent |
| 2026-10-08 | Added one UI-only read-only block to Guided tutorial step 1: directly below the "Utility: quality of life with no event" slider it now shows "Fixed post-event utilities used in this tutorial" with "Post-MI utility: 0.80" and "Post-stroke utility: 0.60" (rendered with `sprintf()` from the model constants `utility_post_mi` and `utility_post_stroke`, not hard-coded) plus the explanation that these fixed values apply to time after MI or stroke when calculating QALYs and that the slider above controls the no-event utility. A small scoped `.cc-tutorial-fixed` style keeps it consistent and mobile-safe. No slider, input, ID, reactive logic, calculation, navigation, step, output or export change | Yes - tested in the running app: the block renders immediately below the slider group (14px below it in document order, one element in the DOM) with the exact requested wording and the two values 0.80 and 0.60 matching `utility_post_mi`/`utility_post_stroke`; the slider still drives the tutorial model (0.86 gives incremental cost EUR 2,439.28 / QALYs 0.00816 / ICER EUR 298,965.51 per QALY, 0.60 gives QALYs -0.00203, and 0.86 restores the original result); styling is a 3px teal left border on a translucent teal tint with 13px text (`rgb(40,125,120)` in light mode and `#7fd1d8` on `rgba(127,209,216,0.12)` in dark mode); tutorial steps 2-4 and the completion card still work with 0 duplicate ids, and the full analysis is unchanged (base case EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51, PSA seed 12345 n=100 mean cost EUR 2,417.75 / mean QALYs 0.00781 / P(CE) at the reference threshold 1.0% with the CEAC rendered and still one WTP input, six tabs in the same order, 241 element ids with 0 duplicates); no horizontal overflow at 390px (block 253px wide, matching the slider group); app.R parses |
| 2026-10-08 | Fixed one tutorial bug: `tutorial_bia()` passed the full-analysis follow-up engagement slider (`input$engagement_followup`) to `calculate_budget_impact()`; it now passes the tutorial input (`input$tutorial_engagement_followup`). One code line plus its comment changed in the Guided tutorial server block; the full-analysis budget impact call, all other tutorial calculations, labels, navigation, outputs, exports and unrelated code are unchanged, and no duplicate parameters or dead code were touched | Yes - tested in the running app: with tutorial follow-up engagement at 42 / 10 / 60 / 90 the tutorial budget impact is EUR 15,480,000.00 / 4,600,000.00 / 21,600,000.00 / 31,800,000.00 with 4,200 / 1,000 / 6,000 / 9,000 active users in year 1, exactly matching a direct `calculate_budget_impact()` probe; with the full-analysis slider at 90 and the tutorial slider at 42 the tutorial budget impact stays at EUR 15,480,000.00 with 4,200 active users (it would have been EUR 31,800,000.00 from the full-analysis value); the full-analysis budget impact still follows its own slider (EUR 31,800,000.00 at 90, EUR 15,480,000.00 at 42); tutorial step 1 is unchanged (EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51 per QALY) and step 3 is unchanged (63,750 eligible, 44,625 and 26,775 active users, 60.0% retention, 89,250.0 clinician hours, Equity Green / Engagement Amber / Workflow Amber / Interoperability Green) even with the full-analysis slider at 90; step 4 still shows Amber / Red / Red / Green with overall Red; full-analysis base case (EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51), PSA (seed 12345, n=100: mean cost EUR 2,417.75, mean QALYs 0.00781, median ICER EUR 333,632.52, P(CE) at the reference EUR 100,000 = 1.0%) and budget impact (EUR 15,480,000.00) are unchanged, as is the HTA decision summary (overall Red, EVPI EUR 0.11), and the export ZIP returns HTTP 200 with the same 10 files; 241 element ids with 0 duplicates in every view; app.R parses |
| 2026-10-08 | Added a read-only global "Assumptions" button in the shared top row next to the Home button, opening a closeable modal titled "Model assumptions and inputs" with five collapsible sections: user-adjustable inputs (current live values for the global, PSA, budget-impact, sensitivity-range, Kaplan-Meier, DHT-readiness and tutorial controls), fixed model inputs (the 14 event-risk, event-cost, discount-rate, horizon and cycle values rendered from the model constants, with the two placeholder costs marked as source-not-documented), model structure, PSA and CEAC (count, seed, distributions, sampled parameters, NMB rule, the internally derived CEAC upper limit), and scope and limitations. New helpers `cc_assumptions_table()` / `cc_assumptions_modal()` plus scoped `cc-assumptions-modal` CSS; one UI line and one observer added. No analysis tab, slider, input, output, calculation, reactivity, navigation or export change | Yes - tested in the running app: the button opens the modal from the landing, tutorial and dashboard views and the Home button remains 47px below it in the same top-right row; the modal closes by the Close button, the Escape key and a backdrop click; the title and all five section headings render exactly as specified and the sections collapse and expand; the fixed table shows 1.5% / 1.0% / 2.0% / 5.0% / 6.0%, EUR 14,315 / 6,000 / 19,677 / 6,496 / 0, 3% / 3%, 10 years and 1 year with the two follow-up costs labelled as placeholders and every fixed row marked "No - fixed in the model file"; the user-adjustable tables show live values (EUR 360 / 40 / 20, 10% / 70% / 42%, 0.86 / 0.80 / 0.60, PSA 1,000 / seed 12345 / EUR 100,000, budget impact, all 11 sensitivity pairs, Kaplan-Meier, DHT readiness and tutorial); changing PSA simulations to 1,100 did not re-open or refresh the open modal and reopening it showed 1,100; the nine sampled PSA parameters render beta/gamma with their sd values and the CEAC paragraph shows 201 points to EUR 200,000 as twice the reference; opening the modal adds no duplicate ids (0 duplicates, 241 page ids) and no horizontal overflow inside the modal at 390px (body scrollWidth equals clientWidth, widest in-modal element 435px, page-level table overflow pre-existing); dark mode is readable (modal #16242c on #e6edf1 text, 13px tables); base case EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51 per QALY, PSA (seed 12345, n=100) mean cost EUR 2,417.75 / mean QALYs 0.00781 / median ICER EUR 333,632.52 / P(CE) at the reference 1.0% with the plane and CEAC rendered, budget impact EUR 15,480,000.00, readiness 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0, KM 192 vs 177 events, tutorial unchanged (20 info controls, one fixed-utilities block, same statuses) and the export ZIP HTTP 200 with the expected file set; app.R parses |
| 2026-10-08 | UI and wording polish only: renamed the PSA result row to "Probability cost-effective at selected WTP"; replaced the assumptions-overlay phrase "No - fixed in the model file" with "Not user-editable in this version" and split the source status into its own column so the two follow-up event costs keep "Illustrative placeholder; source not yet documented"; added cost timing to the three global cost labels ("€ per active user per year", "€ per new user, one-off") and matched the overlay rows; added an ICER interpretation note under the base-case results table; aligned the base-case results table measures with the tutorial table and the export; and added a `currentColor` keyboard focus ring to the assumptions overlay. No value, equation, reactivity, export, navigation or ID change | Yes - tested in the running app: the PSA table reads "Probability cost-effective at selected WTP (€100,000/QALY) = 1.0%" with every PSA value unchanged (n=100 seed 12345: mean cost €2,417.75, mean QALYs 0.00781, median ICER €333,632.52, 0 failed) and the plane and CEAC still render; the overlay fixed table shows 4 columns with all 14 rows reading "Not user-editable in this version" and only the two follow-up costs carrying the placeholder note, with values unchanged (1.5% / 1.0% / 2.0% / 5.0% / 6.0%, €14,315 / €6,000 / €19,677 / €6,496 / €0, 3% / 3%, 10 years, 1 year); the three labels read "Annual intervention price (€ per active user per year)", "Implementation cost (€ per new user, one-off)" and "Annual healthcare savings (€ per active user per year)" and the overlay rows match; the ICER note renders verbatim immediately after the results table and before the plane; base case unchanged at €2,439.28 / 0.00816 / ICER €298,965.51 per QALY with measure labels now identical to the tutorial table and the export CSV; keyboard path verified (Tab reaches the first accordion header, Enter expands it false to true, 5 more Tabs reach Close, Enter closes) with a 2px `currentColor` focus-visible outline rgb(52,65,80) light and rgb(180,186,193) dark, Escape and the Close button both close; dark-mode modal #16242c on #e6edf1 text and 13px tables; at 390px the modal dialog is 374px with equal body scrollWidth and clientWidth (no internal overflow), body scrolls vertically (7358px of content in a 578px viewport) and the Close button stays in the viewport, page has no horizontal overflow; budget impact €15,480,000.00, readiness 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0, KM 192 vs 177 events, HTA summary overall Red with EVPI €0.11, tutorial unchanged (step 1 values, fixed-utilities block, 20 info controls, Assumptions button reachable), export ZIP HTTP 200 with the same 13 files and `psa_summary.csv` keeping its own "at the reference threshold" wording; 242 element ids with 0 duplicates in every view; app.R parses |
| 2026-10-08 | Guided-tutorial UI-only improvement: removed the five permanently visible explanation sentences under the step-1 sliders (price, risk reduction, year-1 engagement, follow-up engagement, no-event utility) and added a small accessible information control beside each matching label, reusing `cc_info()` / `cc_label()` and the `cc-info-popover` styling with the five new texts in `CC_INFO_TEXT` (`tutorial_price`, `tutorial_rrr`, `tutorial_engagement_year1`, `tutorial_engagement_followup`, `tutorial_utility_no_event`). Slider labels, values, ranges and steps unchanged, the fixed post-event utility block preserved, and no calculation, input, reactivity, navigation, output, export, ID or package added | Yes - tested in the running app: only one hint block remains on step 1 (the fixed post-event utility explanation) and all five removed sentences are gone from the source; the five icons render beside the correct sliders with unique popover ids (`tutorial_price_info`, `tutorial_rrr_info`, `tutorial_engagement_year1_info`, `tutorial_engagement_followup_info`, `tutorial_utility_no_event_info`) and aria-labels "Information about the annual price of the technology" / "the risk reduction for engaged users" / "the share of users engaged in year 1" / "the share of users still engaged after the first year" / "the no-event utility"; every popover opens next to its own control by mouse click and by keyboard (Tab/Enter with a 2px teal `:focus-visible` outline) and closes on Escape, and each shows the exact requested wording under its own title; the slider still drives the model (price 360 gives cost EUR 2,439.28 / QALYs 0.00816 / ICER EUR 298,965.51 and price 720 gives EUR 5,290.49 / 0.00816 / EUR 648,419.16, restored on return); at 390px the longest popover measures 276x187 at x=24 and fits inside the 375px viewport with no page overflow, and in dark mode the popover renders #16242c with a #1e3039 header on #e6edf1 text and a #7fd1d8 glyph; full-analysis outputs unchanged (base case EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51, PSA seed 12345 n=100 mean cost EUR 2,417.75 / mean QALYs 0.00781 / median ICER EUR 333,632.52 / P(CE) at the selected WTP 1.0% with plane and CEAC rendered, budget impact EUR 15,480,000.00, readiness 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0, KM 192 vs 177 events, HTA summary overall Red with EVPI EUR 0.11); six tabs in the same order, the Assumptions overlay still opens with its five sections and closes on Escape, and the export ZIP returns HTTP 200 with the same 13 files and sizes; 254 element ids with 0 duplicates; app.R parses |
| 2026-10-08 | Progressive-disclosure layout for Guided-tutorial steps 2 and 3 (UI only): budget impact keeps a two-sentence intro plus an information control holding the three moved bullets, keeps the eligible-population slider with its explanation in a popover beside the label, shows the linked Step-1 price with an "Adjust linked price in Step 1" action (same `tutorial_back_to_price` handler), presents the five-year net budget impact in a compact `.cc-tutorial-summary` card, and moves the annual table and chart into a collapsible "View annual breakdown" section; DHT readiness keeps a two-sentence intro plus an information control holding the three moved bullets, shows the domain statuses first, keeps the clinician-review slider with its explanation in a popover beside the label, keeps a one-line note that engagement is shared with Step 1, groups the two questions into an "Implementation conditions" card with both definitions in popovers beside their labels, and moves the calculation table and per-answer checks into a collapsible "View readiness calculations" section. Six new `CC_INFO_TEXT` keys and six new popover ids, one new presentation-only output `tutorial_bia_linked_price`, and scoped `.cc-tutorial-summary` / `.cc-tutorial-linkrow` / `.cc-tutorial-details` CSS; no slider, checkbox, model input, calculation, status, threshold, export, navigation or package change | Yes - tested in the running app: step 2 shows exactly one intro paragraph, zero bullet lists, the population slider (value 100000), the linked-price line and the "Adjust linked price in Step 1" button, the summary card reading "Net budget impact over 5 years: EUR 15,480,000.00", and a collapsed "View annual breakdown" holding the unchanged annual table (1 4,200 EUR 1,828,000.00 / 2 6,300 EUR 2,342,000.00 / 3 8,400 EUR 3,056,000.00 / 4 10,500 EUR 3,770,000.00 / 5 12,600 EUR 4,484,000.00) and a real chart (694x340 image, naturalWidth 694 = naturalHeight 340, non-blank src); step 3 shows exactly four status cards first (Equity Green, Engagement Amber, Workflow Amber, Interoperability Green) before the review slider, the compact engagement note, the "Implementation conditions" card with both checkboxes checked, and a collapsed "View readiness calculations" holding the unchanged table (63,750 / 44,625 / 26,775 / 60.0% / 89,250.0) and the unchanged per-answer checks line; the four step-3 and two step-2 popovers each open beside the correct label with the moved text and aria-labels "Information about how budget impact is calculated", "the eligible population", "how readiness is assessed", "the clinician review time", "interoperability" and "language availability", all fitting the viewport and closing on Escape; both collapsible sections toggle by click and by keyboard (summary focused, 2px focus-visible outline, Enter opens) and default to collapsed; the review slider still drives the model (10 minutes gives Workflow Amber, 25 gives Red, restoring to Amber) and the price still flows through (EUR 500 gives EUR 21,360,000.00, restoring to EUR 15,480,000.00 at EUR 360); step 4 unchanged (overall Red, Amber/Red/Red/Green); full analysis unchanged (base case EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51, PSA seed 12345 n=100 mean cost EUR 2,417.75 / mean QALYs 0.00781 / median ICER EUR 333,632.52 / P(CE) 1.0% with plane and CEAC rendered, budget impact EUR 15,480,000.00, readiness 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0, HTA summary overall Red with EVPI EUR 0.11); the Assumptions overlay still opens with five sections and closes on Escape; the export ZIP returns HTTP 200 with the same file set and sizes; six tabs in the same order; 390px shows no page overflow (widest element in step 3 is 297px inside a 375px viewport) and popovers fit; dark mode renders the card on rgba(127,209,216,0.12) with a #7fd1d8 border and the details border on rgba(230,237,241,0.25); 258 element ids with 0 duplicates; app.R parses |
| 2026-10-08 | UI-only PSA explanation improvement: the PSA sentence now reads exactly as specified and only the phrase "multiple uncertain parameters" is interactive, implemented as the Shiny action button `psa_parameters_link` styled as an in-sentence link by the new `cc_assumptions_link()` helper (transparent background, no border, underline, brand teal, dark-mode colour, `:focus-visible` outline). Activating it opens the existing "Model assumptions and inputs" modal with the "PSA and CEAC" accordion panel already expanded and the other four collapsed, via a new optional `open_section` argument on `cc_assumptions_modal()`; the "Assumptions" button still opens the same modal fully collapsed. No new modal, package, model input, output or calculation; the nine sampled PSA parameters and every numerical value are unchanged | Yes - tested in the running app: the paragraph renders as "PSA varies [link] together. It does not change the global product assumptions shown above unless the PSA samples those parameters from their specified distributions." with the link text exactly "multiple uncertain parameters" (201x23px, aria-label "Open the model assumptions and inputs overlay at the PSA and CEAC section", tabbable, cursor pointer, underline, rgb(23,107,115) in light mode and rgb(127,209,216) in dark mode with a 2px rgb(47,163,173) focus-visible outline); a real mouse click and keyboard focus + Enter both open the modal titled "Model assumptions and inputs" with exactly one panel expanded - "PSA and CEAC" - and the other four reading aria-expanded false; the nine sampled PSA parameters render unchanged (beta 0.10/0.03, 0.70/0.10, 0.42/0.10, 0.86/0.03, 0.80/0.05, 0.60/0.07 and gamma 360.00/72.00, 40.00/8.00, 20.00/4.00); Close, Escape and backdrop click all close it, and the "Assumptions" button still opens the same modal with 0 of 5 panels expanded; at 390px the link fits the viewport (right edge 298 of 375) with no page overflow, the modal dialog is 374px with a 283px table and the Close button in view; PSA/tutorial/full-analysis outputs unchanged (base case EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51, PSA seed 12345 n=100 mean cost EUR 2,417.75 / mean QALYs 0.00781 / median ICER EUR 333,632.52 / P(CE) 1.0% with plane and CEAC rendered, budget impact EUR 15,480,000.00, readiness 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0, KM 192 vs 177 events, HTA summary overall Red with EVPI EUR 0.11, tutorial step 1 table and its 31 info icons intact); six tabs in the same order; export ZIP HTTP 200 with the same 13 files and sizes; 255 element ids with 0 duplicates; app.R parses |
| 2026-10-08 | Optional Guided Tutorial Part 2 "Commissioning case challenge" (app.R only): new `part2` tutorial step reached from a new "Start Part 2: Commissioning case" button on the Part 1 completion card, with five tutorial-only sections (Case brief / Value for money / Budget impact / DHT readiness / Recommendation) driven by a new hidden `tutorial_part2_step` input; fixed read-only case facts rendered by `part2_case_facts()` (RRR 10%, year-1 70%, follow-up 42%, utilities 0.86/0.80/0.60 read from the model file, population 100,000, review 10 minutes, interoperability and language Yes, WTP EUR 100,000, five-year ceiling EUR 3,000,000, no Red domain); one lever `part2_price` (EUR 0-360, default 360, step 10) passed into the existing `run_eqalb_model()`, `calculate_budget_impact()` and `calculate_readiness()`; new `part2_value_for_money_pass()` / `part2_affordability_pass()` / `part2_deliverability_pass()` criteria driving status cards, two criteria-based milestone messages, a live checklist, four `part2_recommendation()` outcomes and a conditional-adoption completion card with Restart Part 2 / Return to Part 1 completion / Open full analysis / Exit tutorial; new `CC_INFO_TEXT$part2_price`, scoped `.cc-part2-*` CSS, and a `tutorial_step !== part2` wrapper that hides the Part 1 nav only while the case is open. No model file, package, Part 1 slider/output, full-analysis input, PSA/CEAC/VOI rule, export or navigation change | Yes - tested in the running app: Part 1 unchanged (Step 1 heading, four sliders at 360/10/70/42/0.86, the fixed post-event utility block, five info icons, table EUR 2,439.28 / 0.00816 / EUR 298,965.51; Step 2 price line EUR 360.00 and budget impact EUR 15,480,000.00; Back/Next and the completion card work and the completion card now also shows the new optional button); Part 2 defaults to the 13 fixed facts exactly as specified and to the EUR 360 proposed price with the value-for-money card reading "Price remains too high for the health gain at the stated threshold - Not yet achieved"; at EUR 160 Not yet achieved (ICER EUR 104,824.60) and at EUR 150 "Value for money achieved - Pass" (EUR 776.07, 0.00816, ICER EUR 95,117.55) with the "Value for money achieved. Now check whether the programme is affordable at the scale of adoption." milestone; budget at EUR 150 "Above the available five-year budget - Not yet achieved" (EUR 6,660,000.00 vs EUR 3,000,000.00) and at EUR 60 "Within the available budget - Pass" (EUR 2,880,000.00) with the "Affordability achieved..." milestone; the annual breakdown opens to the unchanged five rows (4,200 EUR 946,000.00 / 6,300 EUR 1,019,000.00 / 8,400 EUR 1,292,000.00 / 10,500 EUR 1,565,000.00 / 12,600 EUR 1,838,000.00) and a real 694x340 chart image; readiness at EUR 60 shows all seven domains with four Green and no Red and deliverability "Pass - No readiness domain is Red. 4 of 7 domains are Green." with the calculations table matching Part 1 (63,750 / 44,625 / 26,775 / 60.0% / 89,250.0); the checklist and all four decision messages verified (EUR 360 do-not-recommend, EUR 150 value-yes-affordability-no, accessibility unchecked economic-yes-barriers-remain, EUR 60 conditional adoption) with the completion card "Case complete: You reached a conditional-adoption scenario.", its educational disclaimer and the four requested buttons; the EUR 60 case price left the full-analysis price input and the Part 1 price slider at 360 and the base case at EUR 2,439.28 / 0.00816 / EUR 298,965.51; full-analysis outputs unchanged (PSA seed 12345 n=100 mean cost EUR 2,417.75, mean QALYs 0.00781, median ICER EUR 333,632.52, P(CE) 1.0%; budget impact EUR 15,480,000.00; readiness as above; HTA summary Overall Red with EVPI EUR 0.11); export ZIP HTTP 200 with the expected files; 390px shows no page overflow after fixing the facts table with `table-layout: fixed`, the slider fits and the price popover opens and fits; dark mode renders the lever strip on rgba(127,209,216,0.12) with a #7fd1d8 border; keyboard focus on the section Next button plus Enter advances to the next section; 277-280 element ids with 0 duplicates; app.R parses |
| 2026-10-08 | Focused UI and teaching improvement to Guided Tutorial Part 2 (app.R only): removed the two repeated disclaimer/callout texts from every Part 2 section and from the completion card and deleted the now-unused `PART2_EDUCATIONAL_DISCLAIMER`; changed the global "Assumptions" button to render only when `input.nav_page === "dashboard"` and added a Part 2-only orange "Case facts" button (`show_part2_facts`, `class = cc-btn-orange`) that opens `cc_part2_facts_modal()`, a read-only overlay rendering the same `part2_case_facts()` table through the shared `cc_assumptions_table()` helper and the shared scrollable-body modal pattern; narrowed the `part2_price` slider to `PART2_PRICE_MIN`/`PART2_PRICE_MAX`/`PART2_PRICE_STEP` = 100/360/10 and added `part2_icer_curve()` plus `part2_icer_plot` (deterministic ICER across the slider range from the existing model function, with a 100,000/QALY dashed threshold line, a green/grey coloured curve, an orange marker at the selected price and a legend) with the one-sentence `part2_icer_crossing_note`; added `part2_budget_price_action` so the Budget impact section shows an orange "Change negotiated price" button (`part2_go_value`) only while value for money has not been achieved, returning to the Value for money section. Part 2 keeps sequential Back/Next, no tabs were added, and no model file, model equation, Part 1 element, full-analysis output, PSA, export, threshold or package changed | Yes - tested in the running app: on Home, Part 1 and the Part 1 completion card the top row shows no "Assumptions" button, in the full analysis it shows "Assumptions" and the overlay still opens with its five panels all collapsed; in Part 2 the top row shows the orange "Case facts" button (rgb(217,72,15) with white text) and nothing else, and it opens a modal titled "Case facts" containing exactly the 13 fixed facts with headers Group/Fact/Value, closing by Escape, by the Close button and by backdrop click; every Part 2 section now reports zero visible alert boxes and zero occurrences of either removed disclaimer text; the slider reads min 100 / max 360 with default 360 and the value-for-money card at 360 says "Price remains too high for the health gain at the stated threshold - Not yet achieved" (incremental cost EUR 2,439.28, ICER EUR 298,965.51) and at 150 says "Value for money achieved - Pass" (EUR 776.07, 0.00816, ICER EUR 95,117.55); the ICER chart renders as a real 694x300 image whose pixels contain 372 of the threshold colour, 189 of the orange marker and both coloured curve segments, and the marker centre moved from x = 659 at price 360 to x = 209 at price 150, so the chart tracks the slider; the crossing note reads "The crossing point shows the highest negotiated price that still meets the EUR 100,000.00/QALY value-for-money threshold: EUR 150.00 per active user per year at these case facts."; the "Change negotiated price" button is absent once value for money passes and present (orange) when it fails, and clicking it landed on "Section 2 of 5. Value for money"; sequential Next advanced value -> budget -> readiness -> recommend and Back returned to readiness; full-analysis outputs unchanged (base case EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51 with the price input still 360, PSA seed 12345 n=100 mean cost EUR 2,417.75 / mean QALYs 0.00781 / median ICER EUR 333,632.52 / P(CE) 1.0%, budget impact EUR 15,480,000.00, readiness 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0, KM 192 vs 177 events, HTA summary structure unchanged, six tabs in the same order); Part 1 unchanged (Step 1 of 4, sliders 360/10/70/42/0.86, five info icons, table EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51); export ZIP HTTP 200 with the expected files; 285 element ids with 0 duplicates; at 390px there is no page overflow, the chart fits (right edge 314 of 375), the crossing note is visible and the facts overlay scrolls its body (max-height 68vh) with the Close button visible at top 715 of 850; dark mode renders the orange button unchanged with white text, the crossing note on rgb(244,247,249) and the lever strip on rgba(127,209,216,0.12); app.R parses |
| 2026-10-08 | One controlled affordability lever in Guided Tutorial Part 2 only (app.R only): the Budget impact section now shows "Potentially eligible population: 100,000 people" plus a second case lever `part2_coverage` ("Programme coverage cap (% of eligible population)", 10-100, default 100, step 5, info text in `CC_INFO_TEXT$part2_coverage`) and a hint explaining that full rollout means all 100,000 people and a lower cap is phased adoption rather than an evidence change; added `PART2_COVERAGE_DEFAULT/MIN/MAX/STEP` with `part2_coverage_pct()` and `part2_covered_population()`, and the `part2_bia()` reactive now passes `part2_covered_population(part2_coverage())` into the existing `calculate_budget_impact()` so the annual table, chart, five-year total, affordability status and recommendation checklist all scale together; the coverage cap does not enter `part2_model_args()` so incremental cost, incremental QALYs, ICER and the ICER chart and value-for-money criterion are unchanged; updated `part2_recommendation()` affordability and conditional-adoption messages to the requested wording, added a "Current case settings" line (negotiated price and coverage cap) to the Recommendation section, renamed the facts row to "Potentially eligible population", noted the two levers in the Case brief, Value for money and Case facts overlay text, and made `reset_part2()` reset both sliders. No model file, equation, Part 1 element, full-analysis output, general budget-impact function, PSA/CEAC/VOI, export, threshold or package changed | Yes - tested in the running app: at EUR 150 with 100% coverage the budget card reads "Above the available five-year budget - Not yet achieved" with a five-year impact of EUR 6,660,000.00 against the EUR 3,000,000.00 ceiling, and at 45% coverage it reads "Within the available budget - Pass" with EUR 2,997,000.00, matching the earlier read-only prediction; intermediate points behave linearly (50% = EUR 3,330,000.00 fails, 10% and 30% scale down correctly); the scaled annual table and chart follow (45%: 1,890 EUR 425,700.00 / 2,835 EUR 458,550.00 / 3,780 EUR 581,400.00 / 4,725 EUR 704,250.00 / 5,670 EUR 827,100.00, chart rendered); the coverage slider reports min 10 / max 100 with the default 100 and the "Affordability achieved" milestone appears at 45% but not at 50%; the Recommendation section shows "Current case settings: negotiated price EUR 150.00 per active user per year; programme coverage cap 100%..." or "45%..." as appropriate, gives the exact requested affordability message at 100% and the exact requested conditional-adoption message at 45%, and the completion card appears only at 45%; coverage changed nothing in the per-person result (EUR 776.07, 0.00816, ICER EUR 95,117.55 and "Value for money achieved - Pass" identical at caps of 45%, 10% and 30%, and the ICER chart and crossing note unchanged); Part 1 unchanged (Step 1 of 4, 10 sliders, table EUR 2,439.28 / 0.00816 / EUR 298,965.51, no coverage control leaking into it) and the full analysis unchanged (base case identical with price 360, BIA EUR 15,480,000.00 with its own population input still 100000, readiness 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0); the Case facts overlay still renders the 13 facts, now labelled "Potentially eligible population", with the two-lever note; Restart Part 2 reset price to 360 and coverage to 100 and reopened the brief; export ZIP HTTP 200 with the expected files; 287 element ids with 0 duplicates and every `part2_` id unique; at 390px no page overflow in either colour mode, the coverage slider and hint fit and the coverage popover opens and fits; dark mode readable (hint text rgb(244,247,249)); app.R parses |
| 2026-10-08 | One small Part 2 improvement teaching coverage maximisation (app.R only): added the manufacturer minimum acceptable price (EUR 150 per active user per year) as a new case-brief sentence and a new "Manufacturer's minimum acceptable price" row in `part2_case_facts()`, so it also shows in the Case facts overlay; changed `PART2_PRICE_MIN` from 100 to 150 (max 360, default 360, step 10 unchanged) with the ICER chart and value-for-money rule untouched; added the visible task statement `PART2_COVERAGE_TASK` and a compact live note under the coverage slider (`part2_coverage_message`, messages `PART2_COVERAGE_OVER` / `PART2_COVERAGE_WITHIN`) with scoped `.cc-part2-task` and `.cc-part2-coverage-note` light/dark CSS; added server helpers `part2_bia_for()`, `part2_budget_at()` and `part2_max_affordable_coverage()` (walks the coverage steps through the existing `calculate_budget_impact()`, no inverted formula) and refactored `part2_bia()` onto `part2_bia_for()` so every budget figure uses one path; added a fourth criteria flag `coverage_maximised` (true only when value for money, affordability and readiness pass and the selected cap equals the maximum), a fourth checklist row "Coverage maximised within budget", the "Maximum affordable coverage at the current negotiated price: X%" line, a new `increase_coverage` outcome so wording never claims a maximised rollout when it is not, the updated all-pass message, and `complete` now also requires `coverage_maximised`. No model file, equation, Part 1 element, full-analysis output, general budget-impact function, PSA/CEAC/VOI, export, ceiling or package changed | Yes - tested in the running app: the price slider reports min 150 / max 360 with default 360, and pushing the plugin to 100 clamped the value back to 150, so the floor holds; at EUR 150 value for money passes (EUR 776.07, 0.00816, ICER EUR 95,117.55) and at 360 it fails as before; the Case brief shows the new sentence and the facts table now has 14 rows including "Decision criteria | Manufacturer's minimum acceptable price | EUR 150.00 per active user per year"; the Budget impact task statement reads exactly as specified and the live note flips between "This coverage exceeds the available five-year budget." (class cc-over) and "Within budget. Try increasing coverage to maximise patient access." (class cc-within) at the right points; at EUR 150 the budget fails at 100% (EUR 6,660,000.00) and 50% (EUR 3,330,000.00) and passes at 45% (EUR 2,997,000.00) and 40% (EUR 2,664,000.00); the recommendation checklist shows all four items with the right labels, and "Coverage maximised within budget" is Pass at 45% but Not yet achieved at 40%, with the completion card present only at 45%; the max-coverage line reads 45% at EUR 150 and 15% at EUR 360 (15% = EUR 2,322,000.00 and 20% would exceed), and at EUR 360 the fourth item correctly fails because value for money fails there too; the additional `increase_coverage` outcome reads "Coverage can be increased to 45% to maximise patient access without exceeding the budget." at 40%; coverage changed nothing in the per-person result (identical card text at caps of 45%, 10% and 30%) and Part 1 is unchanged (Step 1 of 4, 10 sliders, table EUR 2,439.28 / 0.00816 / EUR 298,965.51, no coverage control leaking in); the full analysis is unchanged (base case with price 360, BIA EUR 15,480,000.00 which also matches the Part 2 full-rollout figure at price 360, readiness 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0); export ZIP HTTP 200 with the expected files; 288 element ids with 0 duplicates; at 390px the task banner and note sit inside the viewport (x 61 to 314 of 375) with no page overflow in either colour mode and a fresh scan finds no element wider than the viewport; dark mode renders the banner on rgba(217,72,15,0.22) and the within-budget note on rgba(127,209,216,0.15) with light text; app.R parses |
| 2026-10-08 | Focused Part 2 value-for-money and budget-status changes (app.R only): changed `PART2_PRICE_STEP` from 10 to 5 (range 150-360 and default 360 unchanged) so the case shows a passing price range instead of a single acceptable price, with `part2_value_for_money_pass()` left exactly as the ICER-and-positive-QALYs test it already was so Pass is never tied to 150; replaced the single coverage note with a three-state traffic-light status box driven by `PART2_COVERAGE_OVER` ("Above the available five-year budget."), `PART2_COVERAGE_BELOW_MAX` ("Within budget, but coverage can be increased to maximise patient access.") and `PART2_COVERAGE_MAX_MESSAGE` ("Maximum affordable coverage achieved.") - the first constant was renamed to avoid colliding with the existing `PART2_COVERAGE_MAX` slider bound - plus new `.cc-part2-coverage-note.cc-over/.cc-below-max/.cc-max` light and dark styles reusing the status-card colours and removal of the now-unused `PART2_COVERAGE_WITHIN` / `.cc-within`; rewrote the ICER crossing note to report the passing range rather than one highest price; and clarified the price-floor role in the Case brief, the price lever note, `CC_INFO_TEXT$part2_price` and the Case facts overlay note. `part2_budget_at()`, `part2_max_affordable_coverage()`, the EUR 3,000,000 ceiling, the coverage range 10-100/default 100/step 5, the ICER formula, the checklist, the five `part2_recommendation()` outcomes, Part 1, the full analysis, exports, navigation and readiness content are unchanged | Yes - tested in the running app: the price slider reads min 150 / max 360 / step 5 with default 360; value for money at 360 is "Not yet achieved" (EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51), at 155 "Value for money achieved - Pass" (EUR 815.67 / 0.00816 / EUR 99,971.07), at 150 Pass (EUR 776.07 / EUR 95,117.55) and at 160 Not yet achieved (EUR 855.27 / EUR 104,824.60), so Pass follows the ICER and not the price; the crossing note reads "The crossing point shows the range of negotiated prices that meet the EUR 100,000.00/QALY value-for-money threshold at these fixed case facts: EUR 150.00 to EUR 155.00 per active user per year. The manufacturer's minimum acceptable price of EUR 150.00 is a case fact, not the only acceptable answer: any negotiated price that meets the threshold passes the value-for-money test."; at EUR 150 the coverage status box is red `cc-over` at 100% (EUR 6,660,000.00) and at 50% (EUR 3,330,000.00), amber `cc-below-max` at 40% (EUR 2,664,000.00) and green `cc-max` at 45% (EUR 2,997,000.00), and the "try increasing coverage" wording is gone from the DOM; the recommendation still separates the three cases (50% "Value for money is acceptable, but affordability is not"; 40% "Conditional adoption, coverage not maximised" with "Coverage maximised within budget - Not yet achieved"; 45% "Recommended outcome: Conditional adoption" with all four checks Pass and the completion card); dark mode renders the three states on rgba(220,53,69,0.18), rgba(255,193,7,0.16) and rgba(25,135,84,0.2) with light text, and light mode on #f8d7da, #fff3cd and #d4edda; at 390px there is no horizontal overflow (scrollWidth equals clientWidth at 375) and the status box stays visible; Part 1 and the full analysis are unchanged (base case EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51, budget impact EUR 15,480,000.00, readiness 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0); export package download returns HTTP 200 with a valid ZIP; 281 element ids with 0 duplicates; the app server log shows no errors; app.R parses with `shinyApp(` once and no `runApp(` |
| 2026-10-08 | Three small Part 2 UI reductions (app.R only): wrapped the Part 1 tutorial disclaimer alert in a `conditionalPanel` on `input.tutorial_step !== 'part2'` so it is hidden while the commissioning case is open and not replaced, leaving Part 1 unchanged; changed `PART2_COVERAGE_BELOW_MAX` to "Within budget." so the coverage note under the slider reads as three short states; removed the larger `part2_budget_result` pass/fail status card (and its `PART2_MILESTONE_AFFORDABILITY` message, which became unused) so the Budget impact section keeps only the one-line coverage note, the annual breakdown still carrying the five-year figures; and removed the `part2_icer_crossing_note` text output and its renderer so the ICER chart stands alone without the crossing-point paragraph. Budget calculation, coverage slider and range, EUR 3,000,000 ceiling, annual table and chart, price slider, ICER chart, Part 1, the full analysis, DHT readiness, exports and navigation are unchanged | Yes - tested in the running app: the disclaimer text is absent from all five Part 2 sections (0 `.alert` elements inside the Part 2 panel, including once the Part 2 Case brief, Value for money, Budget impact, DHT readiness and Recommendation sections had each been open) while Part 1 still shows it (Step 1 of 4 with sliders 360/10/70/42/0.86 and the base result EUR 2,439.28 / 0.00816 / EUR 298,965.51); the Budget impact section at EUR 150 shows exactly one status line and zero `.cc-part2-card` elements, reading "Above the available five-year budget." at 100% and 50%, "Within budget." at 40% and "Maximum affordable coverage achieved." at 45%, with the phrases "against a ceiling of", "Affordability achieved" and the five-year amount all absent from the section text; the annual breakdown at 45% still holds its five rows (1,890 EUR 425,700.00 / 2,835 EUR 458,550.00 / 3,780 EUR 581,400.00 / 4,725 EUR 704,250.00 / 5,670 EUR 827,100.00, summing to EUR 2,997,000) with a 694x340 chart; the Recommendation checklist still shows all four detailed pass/fail rows and the paragraph "Maximum affordable coverage at the current negotiated price: 45%" with the Conditional adoption outcome and completion card; the ICER chart still renders (694x300) and its image changes between EUR 360 and EUR 150 so the marker tracks the price, while the crossing note and the words "crossing point" are absent from the Value for money section and the value-for-money card still reads EUR 776.07 / 0.00816 / EUR 95,117.55 at EUR 150; Part 2 Next advanced budget -> readiness -> recommend and Back returned to readiness; the Case facts overlay still opens from the orange button with all 14 facts and closes on Escape, and the button stays hidden in the full analysis while "Assumptions" shows; full-analysis outputs unchanged (base case EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51, budget impact EUR 15,480,000.00, readiness 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0 with 2 Green / 4 Amber / 1 Red across 7 domains, six tabs in the same order); the export package is HTTP 200 and a valid ZIP of 9 files; 286 element ids with 0 duplicates; at 390px there is no horizontal overflow (scrollWidth = clientWidth = 375) in light mode, and in dark mode the coverage note renders on rgba(25,135,84,0.2) with rgb(163,207,187) text; the app server log shows no errors; app.R parses with `shinyApp(` once and no `runApp(` |
| 2026-10-09 | UI-only redesign of the Guided Tutorial Part 2 DHT readiness section (app.R only): replaced the read-only readiness display with four learner radio inputs - Interoperability No/Basic/Strong, Algorithm governance Weak/Partial/Strong, Workflow burden High/Moderate/Low, Follow-up engagement Low 30%/Moderate 60%/High 90% - each with one short helper line, and added one live line reporting the reach and clinician hours the choices imply; removed all readiness traffic-light output from the section (the per-domain cards and the Deliverability card now render in the Recommendation section under a new "Readiness with the selected DHT settings" heading) and moved `part2_readiness_cards` / `part2_readiness_result` there unchanged, so the readiness verdict is driven by the learner choices; added `PART2_INTEROP_LEVELS`, `PART2_GOVERNANCE_LEVELS`, `PART2_WORKFLOW_MINUTES`, `PART2_ENGAGEMENT_PCT`, the four `PART2_*_DEFAULT` constants and the pure `part2_readiness_level()` mapper, plus the `part2_readiness_choices()` reactive; `part2_readiness()` now takes interoperability, algorithm governance, review minutes and follow-up engagement from the exercise while digital access, digital suitability, language and accessibility stay as they were, and no choice reaches `run_eqalb_model()`, `calculate_budget_impact()`, the price lever or the coverage cap. `calculate_readiness()` and its thresholds, Part 1, value for money, budget impact, the recommendation rules, exports and the Case facts overlay are unchanged | Yes - tested in the running app: the section renders four radio groups with defaults Strong / Partial / Moderate / Low 30% and the live line reads "At these choices: 44,625 active users in year 1 and 19,125 at follow-up, needing 89,250.0 clinician-review hours a year."; each input changes an existing output (Workflow Low gives 35,700.0 hours and High 178,500.0, Follow-up Moderate gives 38,250 and High 57,375, with the calculations table showing Active users at follow-up 19,125 and Engagement retention 42.9% at Low 30%); the readiness panel contains 0 traffic-light boxes and no Green/Amber/Red word; the Recommendation section shows the five readiness domain cards plus the Deliverability card driven by the choices (defaults give Equity Green, Engagement Amber, Workflow Amber, Interoperability Green, Governance Amber and "Deliverability - Pass - No readiness domain is Red. 4 of 7 domains are Green.", while No / Weak / High / High 90% gives Engagement Green, Workflow Red, Interoperability Red, Governance Red and "Red domains: Workflow burden, Interoperability, Algorithm governance" with the checklist row "No DHT readiness domain is Red - Not yet achieved" and the outcome "Economic criteria are met, but implementation barriers remain"); price, ICER, budget and coverage are unaffected (at EUR 150 the value card reads EUR 776.07 / 0.00816 / EUR 95,117.55 both before and after every readiness change, the coverage note stays "Maximum affordable coverage achieved." at 45% with the same five annual rows summing to EUR 2,997,000, and "Maximum affordable coverage at the current negotiated price: 45%" is identical in both states); Part 1 unchanged (Step 1 of 4, disclaimer intact, sliders 360/10/70/42/0.86, base result EUR 2,439.28 / 0.00816 / EUR 298,965.51); the full analysis unchanged (base case EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51, budget impact EUR 15,480,000.00 with the same five annual rows, DHT readiness tab 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0 and "2 Green, 4 Amber and 1 Red across 7 illustrative domains", six tabs, Assumptions button present); the Case facts overlay opens with all 14 facts and closes on Escape; Part 2 Next/Back still move between sections; dark mode renders the radio labels on rgb(244,247,249) with the controls visible; 292 element ids with 0 duplicates; at 390px the readiness and Recommendation sections have no horizontal overflow (scrollWidth equals clientWidth at 375) with the readiness line visible and the summary cards 253px wide; the app server log shows no errors; app.R parses |
| 2026-10-09 | Part 2 DHT readiness questions rewritten as case-based choices (app.R only): replaced the four No/Basic/Strong and Weak/Partial/Strong style radio groups with four questions - "How would this programme exchange information with existing clinical systems?", "How is the algorithm governed after implementation?", "How would the programme fit into routine clinical work?" and "What level of follow-up engagement should this case assume?" - each with three concrete A/B/C options built with `stats::setNames(codes, descriptions)` so the description is the visible label and the existing code stays the value; added a note under the engagement question that engagement is included for learning and is not fully controllable by the commissioning team. `part2_readiness_choices()`, `part2_readiness_level()`, `calculate_readiness()`, the Recommendation traffic lights, the live reach and clinician-hours line, the collapsed calculations table, the economic calculations, Part 1, budget impact, value for money, exports, navigation and unrelated styling are unchanged | Yes - tested in the running app: the four groups render with the questions above the options and the option text visible (Interoperability A/B/C, Algorithm governance A/B/C, Workflow burden A/B/C, Engagement 30/60/90%), with the descriptions as labels and the codes no/basic/strong, weak/partial/strong, high/moderate/low and low/moderate/high as the underlying values; the weakest option everywhere gives Interoperability Red, Algorithm governance Red, Workflow Red and Engagement Amber with "Deliverability - Not yet achieved - Red domains: Workflow burden, Interoperability, Algorithm governance. 3 of 7 domains are Green." and the checklist row "No DHT readiness domain is Red - Not yet achieved"; the strongest option everywhere gives all five domains Green with "Deliverability - Pass - No readiness domain is Red. 7 of 7 domains are Green." and the checklist row Pass, and at EUR 150 with 45% coverage that state reaches the conditional-adoption completion card with all four checks Pass; an intermediate mix (A interoperability, B governance, C workflow, B engagement) gives only Interoperability Red with "Deliverability - Not yet achieved - Red domain: Interoperability. 5 of 7 domains are Green.", so the three paths are clearly ranked; the follow-up choice changes the existing output (Low 30% gives 19,125 active users at follow-up and 89,250.0 hours with a 42.9% retention row, Moderate 60% gives 38,250, High 90% gives 57,375 and 35,700.0 hours at Low workflow); price, ICER, budget and coverage are identical in the weakest and strongest states (at EUR 150 the value card reads EUR 776.07 / 0.00816 / EUR 95,117.55 in both, at 45% coverage the note reads "Maximum affordable coverage achieved." with the same five rows 1,890 EUR 425,700.00 / 2,835 EUR 458,550.00 / 3,780 EUR 581,400.00 / 4,725 EUR 704,250.00 / 5,670 EUR 827,100.00 and "Maximum affordable coverage at the current negotiated price: 45%"); the readiness panel has 0 traffic-light boxes and no Green/Amber/Red word; Part 1 unchanged (Step 1 of 4, disclaimer, sliders 360/10/70/42/0.86, base EUR 2,439.28 / 0.00816 / EUR 298,965.51); the full analysis unchanged (base case EUR 2,439.28 / 0.00816 / EUR 298,965.51, budget impact EUR 15,480,000.00, DHT tab 63,750 / 44,625 / 26,775 / 60.0% / 89,250.0 with "2 Green, 4 Amber and 1 Red across 7 illustrative domains", six tabs, Assumptions button present); the Case facts overlay opens with all 14 facts and closes on Escape and Next/Back still move between sections; 292 element ids with 0 duplicates; at 390px there is no horizontal overflow in light (scrollWidth equals clientWidth at 375) or dark mode, where the question and option text render light on the dark background; the app server log shows no errors; app.R parses |
| 2026-10-09 | Guided Tutorial Part 2 completion-screen UI change (app.R only): renamed the retry control to "Retry Part 2 with different assumptions" (it keeps the existing `reset_part2()` restart action, so different assumptions and random case selection are not implemented yet), removed the "Return to Part 1 completion" and completion-screen "Exit tutorial" buttons from `part2_completion_card()` so the card holds only the retry button and "Open full analysis", and deleted the two now-orphaned observers `part2_done_return` and `part2_done_exit`. The shared section navigation now hides `part2_exit` on the recommendation step, so the completion screen offers exactly Retry, Open full analysis and Back while Exit tutorial stays available in the other four sections. Case facts, calculations, readiness logic, economic outputs, Part 1, the full analysis, exports and styling outside the completion screen are unchanged | Yes - tested in the running app: on the completion screen the card contains exactly "Retry Part 2 with different assumptions" and "Open full analysis" and the visible button set is those two plus "Back" (Next and Exit tutorial hidden), with the removed ids `part2_done_return` and `part2_done_exit` absent from the DOM; Exit tutorial is still visible on the brief, value, budget and readiness sections; retry works (returns to Section 1 of 5 Case brief with price 360 and coverage 100 while `tutorial_step` stays `part2`); "Open full analysis" moves to the dashboard; Back moves recommend -> budget; Part 1 unchanged (Step 1 of 4, disclaimer, sliders 360/10/70/42/0.86, base EUR 2,439.28 / 0.00816 / EUR 298,965.51); the full analysis unchanged (base case EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51, budget impact EUR 15,480,000.00 with its five annual rows, six tabs in the same order, Assumptions button present); 290 element ids with 0 duplicates (two fewer than before, matching the removed buttons); the app server log shows no errors; app.R parses |
| 2026-10-09 | Randomized Part 2 case facts (app.R only): added `PART2_CASES`, three complete predefined commissioning cases (Case A "Regional roll-out" 10%/70%/42%, utilities 0.86/0.80/0.60, 100,000 people, 10 review minutes, 3 languages; Case B "Integrated pilot" 15%/80%/60%, 0.88/0.82/0.62, 80,000, 8 minutes, 4 languages; Case C "Fragmented deployment" 12%/65%/40%, 0.85/0.79/0.59, 140,000, 14 minutes, 2 languages), each an internally consistent set with the WTP threshold and the five-year ceiling identical across cases so no rule, label or checklist wording depends on the draw; one case is drawn at session start into the new `part2_case_index` reactiveVal and held in session state (`part2_case`) so sliders and section changes never redraw it; `part2_case_facts(case)` now builds the case-fact table from the active case and is the single source of truth, feeding the Case brief table, the Case facts overlay (`cc_part2_facts_modal(case)`, now titled with the case) and the model, budget and readiness calls; `part2_model_args()` takes rrr, year-1 and follow-up engagement and the three utilities from the case, `part2_bia_for()` takes the case follow-up engagement as well as the case population via `part2_covered_population(coverage, population)`, and `part2_readiness()` takes the case population, year-1 engagement and language count; added `part2_case_heading()` plus a short "Active case: ..." banner (`part2_case_banner`, `.cc-part2-case` CSS with a dark-mode override) and case-driven `part2_case_intro`, `part2_population_line` and `part2_full_rollout_hint` so the brief narrative and the population text can never quote another case; `draw_different_part2_case()` excludes the current index so the retry button always draws a different case, then resets both levers and returns to the Case brief; removed the three now-unused constants `PART2_YEAR1_ENGAGEMENT`, `PART2_FOLLOWUP_ENGAGEMENT` and `PART2_LANGUAGE_AVAILABLE_LANGUAGES` so each fact has one source of truth. Part 1, the full analysis, exports, the DHT readiness controls and the Recommendation rules are unchanged | Yes - tested in the running app over two drawn cases and one retry: Case C was drawn first with the banner "Active case: Case C - Fragmented deployment" and all 14 facts matching its definition (RRR 12%, year-1 65%, follow-up 40%, utilities 0.85/0.79/0.59, 140,000 people, 14 review minutes, language availability No), the brief narrative reading "A wider deployment of 140,000 people ... Evidence suggests a 12% relative reduction", the population line and the full-rollout hint both reading 140,000, and its economics matching the model exactly (at EUR 150 incremental cost EUR 736.40, incremental QALYs 0.00921, ICER EUR 79,999.04 - Pass, and the coverage box green "Maximum affordable coverage achieved." at 30% while 35% gave the red "Above the available five-year budget.", so the highest affordable coverage is 30%), with all four recommendation checks Pass at EUR 150 and 30% coverage and the conditional-adoption completion card shown; the case stayed fixed through every section change and both sliders (banner and facts identical after moving price to 150 and coverage to 30 and visiting all five sections - verified against the live DOM, not the accessibility delta); retry then drew a different case (Case A) and reset the levers (price 360, coverage 100) at the Case brief; Case A showed all 14 facts (10%, 70%, 42%, 0.86/0.80/0.60, 100,000, 10 minutes, language Yes) with its own economics (EUR 776.07 per person, 0.00816 QALYs, ICER EUR 95,117.55, max affordable coverage 45% at EUR 150) and the population line and rollout hint both reading 100,000; the Case facts overlay for Case C was titled "Case facts - Case C - Fragmented deployment" and listed exactly those 14 facts, and the overlay closed on Escape; a third case (Case B, 15%/80%/60%, 80,000 people) was verified only by the offline model probe (passing prices EUR 150-295, highest affordable coverage 40% at EUR 150), so it has not been exercised in the browser; Part 1 unchanged (Step 1 of 4, disclaimer, sliders 360/10/70/42/0.86, base EUR 2,439.28 / 0.00816 / EUR 298,965.51); the full analysis unchanged (base case EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51, budget impact EUR 15,480,000.00, six tabs in the same order); 292 element ids with 0 duplicates; at 390px no horizontal overflow in light or dark (scrollWidth equals clientWidth at 375) with the case banner 253px wide; dark mode renders the banner on rgba(127,209,216,0.12) with light text; the app server log shows no errors; app.R parses |
| 2026-10-09 | Part 2 DHT readiness answer ordering (app.R only): reordered the visible A/B/C choices in the readiness exercise so the strongest answer is not always the last option - Interoperability now reads A. Limited connection / B. Standards-based connection (strongest) / C. No connection, and Algorithm governance now reads A. Ongoing governance (strongest) / B. No formal oversight / C. Initial review only, while Workflow burden (A. High / B. Moderate / C. Low, strongest at C) and Follow-up engagement (A. Low 30% / B. Moderate 60% / C. High 90%, no level presented as correct) are unchanged. Only the order of entries in the `stats::setNames()` label vector changed: the underlying value vectors keep the same three codes per question (basic/strong/no, strong/weak/partial, high/moderate/low, low/moderate/high), so `part2_readiness_level()`, `part2_readiness_choices()`, the defaults, the option values, every input ID, the readiness mappings, the Recommendation logic, the case facts, the economic outputs and the layout are untouched. A short comment records why the strongest answer sits in a different position in each question | Yes - tested in the running app: the strongest answer now sits at position B for Interoperability, A for Algorithm governance and C for Workflow burden (unchanged), so all three differ; the checked defaults are unchanged in meaning (`part2_interop` still defaults to `strong`, now shown as the B label, `part2_governance` to `partial` shown as C, `part2_workflow` to `moderate` shown as B, `part2_engagement` to `low` shown as A); the underlying value vectors are the same three codes in a new order (interop basic/strong/no, governance strong/weak/partial, workflow high/moderate/low, engagement low/moderate/high); clicking the visible labels still maps to the same readiness category - clicking the weakest descriptions by label text (No connection, No formal oversight, High burden, Low engagement 30%) produced Interoperability Red, Algorithm governance Red, Workflow Red and Engagement Amber with "Deliverability - Not yet achieved - Red domains: Workflow burden, Interoperability, Algorithm governance", identical to the pre-change weakest result, and clicking the strongest descriptions for the three scored questions produced Interoperability Green, Algorithm governance Green and Workflow Green with "Deliverability - Pass"; 292 element ids with 0 duplicates; each question still renders three radios and four labels (the question label plus the three options, unchanged structure); at 390px there is no horizontal overflow (scrollWidth equals clientWidth at 375); the app server log shows no errors; app.R parses |
| 2026-10-09 | Part 2 follow-up-engagement linkage fix (app.R only): `part2_readiness()` was still passing the case fact (`case$followup_engagement`) as `readiness_followup_engagement`, so the learner`s Follow-up engagement answer was inert and the readiness Engagement domain never responded to it. It now passes `choices$followup_engagement`, the existing learner-selected value from `part2_readiness_choices()` (Low 30 / Moderate 60 / High 90 via `PART2_ENGAGEMENT_PCT`), so the selected answer drives the Engagement domain, the "Active users at follow-up" row and the live reach line while the case follow-up engagement stays a displayed case fact only. No thresholds, mappings, option values, IDs, case facts, price, ICER, budget-impact or coverage logic changed, and `calculate_readiness()` is untouched, so Part 1 and the full analysis are unaffected | Yes - tested in the running app on Case C (140,000 people, case follow-up 40%, eligible 89,250): the live line now tracks the answer - Low 30% gives 26,775 active users at follow-up (89,250 x 0.30), Moderate 60% gives 53,550 (x 0.60) and High 90% gives 80,325 (x 0.90), where previously all three showed the case value of 35,700; the Recommendation Engagement domain now responds - Low 30% gives "Engagement - Amber" with the existing Amber wording, Moderate 60% gives "Engagement - Green" and High 90% gives "Engagement - Green", all under the unchanged thresholds (>=60 Green, >=30 Amber, else Red); the other four domains were identical at every engagement level (Equity and access Green, Workflow burden Amber, Interoperability Green, Algorithm governance Amber), so nothing else moved; price, ICER, coverage and budget were byte-identical at Low and High (EUR 150 price, value card EUR 736.40 / 0.00921 QALYs / ICER EUR 79,999.04, coverage note "Maximum affordable coverage achieved." at 30%); Part 1 unchanged (Step 1 of 4, base EUR 2,439.28 / 0.00816 / EUR 298,965.51); full analysis unchanged (base case EUR 2,439.28 / 0.00816 / EUR 298,965.51, budget impact EUR 15,480,000.00); 292 element ids with 0 duplicates; at 390px no horizontal overflow (scrollWidth equals clientWidth at 375); the app server log shows no errors; app.R parses. Note: because the shared thresholds are >=60 Green and >=30 Amber, the spec`s Low 30 / Moderate 60 / High 90 values collapse to Amber / Green / Green, so the exercise shows only two distinct engagement messages and the Amber wording says "moderate"; distinguishing all three levels would need either different learner percentages or Part 2-specific thresholds, neither of which was in scope |
| 2026-10-09 | Part 2 value-for-money exercise changed to ask for the highest price that still passes, not any passing price (app.R only): added `PART2_PRICE_TASK` as a visible task line, `PART2_PRICE_BELOW_MAX` / `PART2_PRICE_AT_MAX` / `PART2_PRICE_OVER` as the three result states, and `part2_max_acceptable_price()`, which reads the highest passing slider value from the already-cached `part2_icer_curve()` so no model run was added and the answer never depends on the learner's slider; rewrote `output$part2_value_result` to report above-threshold, passing-below-maximum or maximum-reached, and removed the now-unused `PART2_MILESTONE_VALUE` constant whose message fired on any passing price; replaced the Case brief sentence and price lever note that described the passing band as the answer, and refreshed the stale price-lever comment. ICER formula, WTP threshold, case selection, budget impact, coverage, DHT readiness, Part 1 and full analysis unchanged. Targeted validation in the running app: Case A highest passing price EUR 155 (150 passes, 155 passes, 160/200/355/360 fail; ICER EUR 99,971.07 at 155) and multiple passing prices above EUR 150; Case B highest EUR 295 (290 passes, 295 passes, 300/360 fail); Case C highest EUR 170 (165 passes, 170 passes, 175/360 fail); each case shows the top-of-band message only at its own highest value; ICER still the existing formula (incremental cost / incremental QALYs); recommendation checklist, budget one-line status and readiness traffic lights unchanged; 292 element ids with 0 duplicates; no horizontal overflow at 390px (scrollWidth 375 = clientWidth 375); dark mode toggles and the section stays readable; full analysis still EUR 2,439.28 incremental cost, 0.00816 incremental QALYs, EUR 298,965.51 ICER and EUR 15,480,000.00 five-year budget impact; app server log shows no errors; app.R parses. | Yes - tested in the running app |
| 2026-10-09 | Fix of the two confirmed Part 2 audit findings (app.R only): `reset_part2()` now also calls `updateRadioButtons()` for `part2_interop`, `part2_governance`, `part2_workflow` and `part2_engagement`, returning them to `PART2_INTEROP_DEFAULT` / `PART2_GOVERNANCE_DEFAULT` / `PART2_WORKFLOW_DEFAULT` / `PART2_ENGAGEMENT_DEFAULT`, so "Retry Part 2 with different assumptions" no longer carries the previous case's DHT answers; and `part2_readiness()` now restates the Engagement explanation from the learner's own answer via a new `part2_engagement_level()` helper, so the Recommendation card reads "Follow-up engagement is low." at 30%, "moderate." at 60% and "high." at 90% instead of always using the traffic light's band wording. The statuses, thresholds and colours are unchanged, `calculate_readiness()` and its shared text are untouched (the DHT Readiness tab still shows its original sentence), and case facts, case selection, economic formulas, price logic, budget logic, Part 1, the full analysis, exports and layout were not changed. Targeted validation in the running app: with non-default answers (no / weak / high / high) plus price EUR 200 and coverage 30%, clicking Retry moved Case B to Case C and returned all four answers to strong / partial / moderate / low with price 360, coverage 100% and section 1 of 5, and the banner changed with it; engagement wording verified exactly at all three levels (30% -> Amber "Follow-up engagement is low.", 60% -> Green "moderate.", 90% -> Green "high."); Case C still shows its highest passing price of EUR 170 and maximum affordable coverage of 30% (25% within budget, 35% above); full analysis still EUR 2,439.28 incremental cost, 0.00816 incremental QALYs, EUR 298,965.51 ICER and EUR 15,480,000.00 five-year budget impact; 293 element ids with 0 duplicates; no horizontal overflow at 390px (scrollWidth 375 = clientWidth 375); dark mode toggles with no overflow; app server log shows no errors; app.R parses. | Yes - tested in the running app |
| 2026-10-09 | Focused cleanup of the full-analysis "DHT Readiness & Implementation" tab (app.R only): removed the tab's own Year-1 and Follow-up engagement sliders so Global Settings is the only place engagement is adjusted, and pointed `calculate_readiness()` at `input$engagement_year1` / `input$engagement_followup` with a comment explaining why, so the next "Assess readiness" click uses the latest global values; removed the two now-dead `updateSliderInput()` lines from the Reset values handler so it no longer targets missing inputs; removed the duplicated "Readiness overview" section and its `output$readiness_cards` renderer plus the unused `uiOutput("readiness_cards")` call, leaving the compact seven-row Domain assessment table, the quantitative outputs table, the traffic-light rules control and every other readiness control; updated the `readiness_inputs` table in the read-only Assumptions overlay to read the global engagement inputs so it cannot show a blank value; and wrapped the four-column Domain assessment table in a `.cc-readiness-domain` wrapper with a new scoped fixed-layout CSS rule matching the existing `.cc-part2-facts` approach, because that table was the only element in the app that overflowed at 390px. `calculate_readiness()` and its thresholds, the traffic-light rules, Part 1, Part 2, value for money, the budget impact, the VOI and HTA-summary tabs, the economic outputs and exports are unchanged | Yes - tested in the running app: the sidebar has no engagement control and no duplicate id (0 matches for `readiness_year1_engagement` / `readiness_followup_engagement` in the DOM) and the "Readiness overview" text is gone; changing Global Settings to 70/20 and assessing gives Engagement Red with "Follow-up 20.0% (year-1 70.0%)" and 12,750 active users at follow-up, while 70/90 gives Engagement Green with 57,375, and the Assumptions overlay shows the live values (55% / 80% when set so); the Domain assessment table renders all seven rows with the expected statuses (Equity Green, Engagement Amber, Workflow Amber, Language Red, Accessibility Green, Interoperability Amber, Governance Amber) and "2 Green, 4 Amber and 1 Red across 7 illustrative domains"; the base case and budget impact are unchanged (EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51 and EUR 15,480,000.00) and the HTA decision summary still reads 2 Green, 4 Amber, 1 Red from the DHT assessment; Part 1 step 3 and Part 2 (Case B, four readiness questions, Recommendation cards) both still work; 290 element ids with 0 duplicates in the full analysis and 288 in Part 2; at 390px every tab now has scrollWidth equal to clientWidth (the DHT tab went from 453 to 375 with 0 overflowing elements and the table at 327px), and dark mode is readable (`rgb(180,186,193)` table text); the app server log shows no errors; app.R parses |
| 2026-10-09 | DHT readiness engagement linkage: verified, no code change needed (project_state.md only). A read-only trace of the full-analysis path shows `observeEvent(input$assess_readiness, ...)` passes `readiness_year1_engagement = input$engagement_year1` and `readiness_followup_engagement = input$engagement_followup` (app.R:6135-6136), so every argument to `calculate_readiness()` from the full-analysis observer comes from the live Global Settings sliders; there is no literal 70 or 42 anywhere in the full-analysis readiness path (the only remaining ones are the Global Settings slider defaults themselves, the separate `tutorial_engagement_*` sliders, the Case A case facts, and tutorial info text). The quantitative outputs table, the Engagement row of the Domain assessment table, the HTA decision summary implementation-readiness domain and the `dht_readiness_results.csv` export all read the single cached `readiness_state()` result, so they cannot diverge from each other. Verified in the running app: 55%/80% -> 35,062 active users at year 1, 51,000 at follow-up, retention 145.5%, Engagement Green "Follow-up 80.0% (year-1 55.0%)"; 70%/20% -> 44,625 / 12,750, retention 28.6%, Engagement Red "Follow-up 20.0%"; restoring 70%/42% returns 44,625 / 26,775, retention 60.0%, Engagement Amber; the HTA summary followed from Amber "2 Green, 4 Amber, 1 Red" to Red "2 Green, 3 Amber, 2 Red" after the same change. Part 1 still has its own engagement sliders (70/42) and Part 2 still uses its case facts (Case C 65%/40%). No app.R change was made, so the reported symptom in an already-open session is explained by the running instance predating the change (Shiny does not hot-reload app.R) or by reading the tab without re-clicking Assess readiness, which is button-gated by design | Yes - verified in the running app |
| 2026-10-09 | Value of information tab UI only (app.R only): replaced the permanently visible "What this means" well panel under the EVPI traffic-light result with a green on-demand "Decision context and interpretation" popover button. Added one reusable helper `cc_context_popover(trigger, title, intro, items, aria_label)` (same bslib popover pattern as `cc_rules_popover()`), the constant `VOI_CONTEXT_TRIGGER_LABEL`, trigger class `.cc-context-trigger` (light: #155724 text and border on rgba(21,87,36,0.06); dark: #8fdca8 on rgba(143,220,168,0.10), hover/focus variants and a 2px #2f7d4f focus-visible outline) and the popover class `.cc-context-popover` added to the three existing scoped popover selector groups so it inherits the same header, body-radius and close-button treatment. The popover body keeps the existing dynamic `assessment$what_this_means` text and appends only the four requested lines, built from `input$psa_reference_wtp` and `result$n_successful` with the simulations line omitted when the count is unavailable. EVPI, EVPPI, PSA, thresholds, all calculations, exports, layout outside that box and the other tabs are unchanged | Yes - tested in the running app: the "What this means" text is absent from the VOI tab while the new button renders with `class="btn btn-default cc-context-trigger"` and a descriptive aria-label; the popover opens by mouse and by keyboard (focus then Enter, with a solid 2px rgb(47,125,79) focus-visible outline) and closes with Escape; the panel shows the full dynamic interpretation plus "Decision: eQalb plus usual care versus usual care.", "Reference threshold: €100,000.00 per QALY.", "PSA simulations: 1,000 successful." and the EVPI-is-per-patient upper-bound line, and the threshold line tracked a change to €75,000.00 before being restored; dark mode renders the trigger at rgb(143,220,168) and the popover on rgb(22,36,44) with rgb(230,237,241) text; at 390px the popover stays inside the viewport (276px wide) with scrollWidth equal to clientWidth and no overflowing element, and closing it keeps the same; the base case (EUR 2,439.28 / 0.00816 / ICER EUR 298,965.51), budget impact (EUR 15,480,000.00), the traffic-light rules button, the EVPPI section and the Download results view are unchanged; 287 element ids with 0 duplicates and 0 overflowing elements in all six tabs; the app server log shows no errors; app.R parses |
| 2026-10-09 | Value of information tab presentation only (app.R only): removed the decision-uncertainty red/amber/green result card and the "Traffic-light rules" button from the tab, so decision uncertainty is now shown only in the HTA decision summary (which keeps its own traffic light, its own rules button and the shared `voi_uncertainty_status()` helper in eqalb_markov.R, all untouched); reshaped `cc_context_popover()` to take an arbitrary `body` instead of an intro plus bullet list and dropped the now-unused `VOI_RULES_TRIGGER_LABEL` constant; the green "Decision context and interpretation" button now opens a panel with one dynamic headline (`assessment$label`, e.g. "Low-to-moderate decision uncertainty"), one plain-language paragraph built from `assessment$preferred`, the current EVPI and a magnitude word mapped from `assessment$magnitude` (negligible/modest -> low, moderate -> moderate, material -> substantial), and the one requested example sentence, with no bullets for the decision name, WTP threshold, PSA count or the upper-bound/research-budget statement; and the permanently visible "Method and limitations" heading and list were replaced by a collapsed-by-default bslib accordion (`voi_method_accordion`) holding the same six items with their wording preserved. EVPI, EVPPI, PSA, thresholds, traffic-light rules, exports, calculations and other tabs are unchanged | Yes - tested in the running app: the VOI tab shows no traffic-light card, no "AMBER —"/"GREEN —"/"RED —" heading and no "Traffic-light rules" button, while the HTA decision summary still shows "Decision uncertainty - Amber" with its own rules button; the popover opens by mouse click and by keyboard (focus then Enter) and closes with Escape, and its body has 0 list items with the headline "Low-to-moderate decision uncertainty", the paragraph "usual care is preferred on average, but some uncertainty remains. Perfect information would be worth about €4.71 per patient. This means further research could be useful, but the potential benefit of removing all uncertainty appears low in this illustrative analysis." and the example sentence; the Method and limitations accordion is collapsed by default (`aria-expanded=false`, 0px) and opens to 6 items then closes again; EVPI per patient €4.71, the EVPPI section, the PSA summary (mean incremental cost €2,420.87) and the base case (€2,439.28 / 0.00816 / €298,965.51) plus budget impact (€15,480,000.00) are unchanged; at 390px the popover stays inside the viewport (276px, left 11, right 287) with scrollWidth equal to clientWidth and 0 overflowing elements, both with the popover open and with the accordion open; dark mode renders the trigger at rgb(143,220,168) and the popover on rgb(22,36,44) with rgb(230,237,241) text and the accordion text at rgb(180,186,193); 289 element ids with 0 duplicates and 0 overflowing elements in all six tabs; the app server log shows no errors; app.R parses |
| 2026-10-10 | True PSA mean component decomposition (eqalb_markov.R + app.R). Model: added nine extra heemod value variables to both strategies in `run_markov()` - the six cost parts (`cost_no_event`, `cost_post_mi`, `cost_post_stroke`, `cost_intervention`, `cost_implementation`, `cost_savings`) and the three QALY parts (`qaly_no_event`, `qaly_post_mi`, `qaly_post_stroke`) - each using the same expression as the corresponding part of the existing `cost`/`effect` total, which are left byte-identical, so every existing output is unaffected; added the shared `PSA_COMPONENT_NAMES` constant; `summarize_model()` now also returns the nine eQalb-minus-usual-care component differences; `run_eqalb_model()` passes them through as `components`; `run_psa_eqalb()` stores one column per component per successful simulation (rejecting non-finite components), computes `mean_components` and `component_cost_names` from the same `successful` frame as the headline means, and stops with a clear message if the cost parts or the QALY parts do not reconcile with `mean_incremental_cost` / `mean_incremental_qalys` (tolerance 1e-8). App: added `psa_mean_cost` and `psa_mean_qalys` to `CC_INFO_TEXT`; replaced `output$psa_summary` with a `renderUI` two-column table built from `tags$table` using the same `table shiny-table table-striped table-hover table-bordered spacing-s` classes (needed because `renderTable`/xtable cannot carry the popover markup inside a cell), and two new `bslib::popover` triggers with ids `psa_mean_cost_info` and `psa_mean_qalys_info` reuse the existing `cc-info-trigger` / `cc-info-popover` styling. The popovers show the component table with a total row, the "Mean eQalb minus usual-care difference across successful PSA simulations." note and, for cost, the "Positive values increase eQalb costs; negative values indicate lower costs under eQalb." note. A `validate()` in the renderer fails clearly if either displayed total stops matching its headline value. `psa_summary.csv` was deliberately left unchanged, as were all costs, effects, transitions, PSA, CE plane, CEAC, EVPI, EVPPI, budget impact, HTA summary, tutorials, Part 1, Part 2 and exports | Yes - tested in the running app: `Rscript` reconciliation probe over seeds 111/222/333 gave cost-part sums equal to the stored mean incremental cost to within 4.6e-13 and QALY-part sums equal to within 5e-17; in the app the popover total rows exactly reproduce the summary rows for seeds 12345 (€2,417.75 / 0.00781, median ICER €333,632.52, P(CE) 1.0%), 7777 (€2,525.02 / 0.00761) and 31337 (€2,480.65 / 0.00825); the cost popover at seed 12345 shows eQalb intervention cost €2,830.94, one-off implementation cost €41.04, healthcare-use savings €160.11, post-MI state cost -€165.42, post-stroke state cost -€128.71 and total €2,417.75, and the QALY popover shows 0.03365 / -0.01750 / -0.00835 with total 0.00781; both popovers open by real mouse click and by keyboard (focus then Enter) and close with Escape; base case still €2,439.28 / 0.00816 / €298,965.51, budget impact still €15,480,000.00, EVPI per patient €0.11 at seed 12345 n=100 (unchanged for that setting), the EVPPI table, the HTA summary (Economic value Red, Decision uncertainty Amber, Budget impact Red) and the VOI context button and Method accordion are all unchanged; 294 element ids with 0 duplicates in all six tabs; at 390px the PSA summary table is 327px and the cost popover sits fully inside the viewport (276px, left 64, right 340) with no inner overflow; light mode popover is rgb(244,247,249) on rgb(52,65,80) and dark mode is rgb(22,36,44) on rgb(230,237,241); the app server log shows no errors; app.R and eqalb_markov.R both parse |
| 2026-10-10 | Moved the full-analysis Clinical target population control into Global Settings (app.R only). The `target_population` numericInput (same ID, min 0, step 1000, default 100000, same `cc_label` and info control) now sits in a new "Population" block of the "Global eQalb assumptions" panel with a note that it is shared by Budget Impact and DHT Readiness; the duplicate `bia_population` control was removed from the Budget-impact controls, and `bia_result` now reads `population = input$target_population` so Budget Impact and DHT Readiness use one shared input. The removed duplicate's label row in the read-only Assumptions overlay was repointed to `target_population` and relabelled "Clinical target population (shared with DHT readiness)", so it no longer shows a blank value. A short muted note was added to the DHT sidebar stating that the population is set in Global Settings. Part 1 was made independent: `tutorial_readiness()` previously read `input$target_population` and now reads its own `input$tutorial_population`, so the tutorial keeps its own eligible-population learning input; Part 2 already used `case$population`. The Budget-impact uptake, increase, horizon and avoided-event inputs (and their IDs, values and ranges) were not touched, and no calculation, threshold, model formula, PSA, CEAC, EVPI/EVPPI, export, tutorial step or Part 2 case fact changed | Yes - tested in the running app: exactly one visible Clinical target population control exists, in Global Settings, with 0 duplicate ids (286 ids in every view) and only one `#target_population` element in the DOM; setting it to 50,000 changed Budget Impact from EUR 15,480,000.00 to EUR 7,740,000.00 (exactly half, with Year-1 new users 5,000 and the same 10/15/20/25/30% uptake path) and DHT readiness from 63,750 / 44,625 / 26,775 / 89,250.0 to 31,875 / 22,312 / 17,786 / 44,625.0, and restoring 100,000 returned both to the documented values; with the shared population at 7,777 Tutorial Part 1 step 3 still showed 63,750 / 44,625 / 26,775 with its own input at 100,000 and Part 2 still showed Case A with 100,000 potentially eligible people and unchanged case facts, so neither tutorial inherits the shared value; at population 100,000 versus 50,000 the PSA summary rows, both component popovers and every VOI row were byte-identical (mean incremental cost EUR 2,420.87, mean incremental QALYs 0.007958, median ICER EUR 331,546.18/QALY, P(CE) 1.5%, EVPI EUR 4.71 per patient at seed 12345 n=1000), confirming the per-person base case, PSA, CEAC, EVPI and EVPPI are unaffected, and the base case stayed EUR 2,439.28 / 0.00816 / EUR 298,965.51; the Assumptions overlay shows "Clinical target population (shared with DHT readiness) 100,000" under Budget impact with no blank or NA value; the HTA decision summary still reports the readiness domain as "2 Green, 4 Amber, 1 Red across 7 illustrative domains"; the DHT tab has no population control but still produces all seven domains, and its sidebar note is readable in dark mode (rgb(159,178,189)); at 390px the DHT tab has scrollWidth equal to clientWidth with 0 overflowing elements; the app server log shows no errors; app.R parses |
