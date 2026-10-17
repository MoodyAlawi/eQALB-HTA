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
- Browser-tab branding in the frontend (static title and the title table only):
  `frontend/index.html` carries `<title>OpenHealth</title>` and
  `useAppView.ts`'s `PAGE_TITLES` gives the landing page and the eQalb application
  (`/app`, which every in-app screen shares) the same "OpenHealth" title, so the tab
  reads the same from the first paint through the Home screen, the tutorial, the
  project description, the download view and all nine analysis tabs. It is the only
  pair of title sources in the frontend: the two dynamic setters are that table (the
  one the app uses on every move) and `BlogPostView.vue`, which titles an open post
  with the post's own name, so nothing overwrites the app's title. The two public
  documents that are pages of their own keep titles that name them — `/about` is
  "About OpenHealth" and `/blog` is "Blog — OpenHealth" — and the metadata
  description, favicons, landing copy and in-app eQalb branding are unchanged.
- OpenHealth public shell: the public addresses are published on top of the same
  dependency-free view store (`frontend/src/composables/useAppView.ts`) — `/`,
  `/blog` and `/blog/<slug>`, `/about` and `/app`. `/` is
  the landing page
  (`frontend/src/views/OpenHealthHomeView.vue`): one scrolling page in three
  panels — eQalb first (the hero, with the single action "Open the app"), then
  OpenHealth and About me — beneath a compact floating navigation panel that
  smooth-scrolls, tracks the visible panel with an `IntersectionObserver` and
  marks it with `aria-current`. The two sections below the hero fade with the
  scroll rather than on a timer: the view writes a `--reveal` value from 0 to 1 onto
  each section's inner element, from the section wrapper's own untransformed bounds
  — the entry reads its top edge (0 at 90% of the viewport, 1 at 55%, linear
  between, with a 16px lift driven separately by `--reveal-lift`) and the exit
  reads its bottom edge (still 1 until only the top 22% of the screen holds it, 0
  at the top), with opacity the lower of the two. So a group fades in, holds
  through a wide central band, and fades out as it leaves; the effect reverses when
  the reader scrolls back up and repeats on every pass, and nothing latches.
  Reading the bottom edge for the exit is what keeps a tall block legible, and a
  group that cannot reach the exit range — the last one, which the document ends
  beneath — simply stays visible. Stopping halfway holds the intermediate opacity
  and continuing completes it. The wrapper is never transformed and the inner
  element is what is painted, so the measurement cannot be skewed by the animation;
  the work is batched into one `requestAnimationFrame` from passive `scroll` and
  `resize` listeners; focus inside a group paints it fully in the same turn and the
  scroll value returns when focus leaves; and the hero is outside the mechanism
  entirely, so it and its
  button are visible from the first paint. Each panel's content is a centred block
  — the hero centres its own text, the OpenHealth column takes a 40rem measure with
  its text centred too and its heading composed as two deliberate lines, and the
  About group a 56rem measure with its prose left-aligned — with the page footer
  sharing the About measure. The hidden state of the reveal is scoped to a
  `landing--armed` class the view sets only when it can drive the reveal, so every
  section is readable outright in a browser without the features, or if the setup
  fails; focus inside a group overrides the scroll so a link is never focused while
  invisible;
  `prefers-reduced-motion` and print override it outright; and scroll snapping was
  removed because it pulled small wheel notches back to a panel boundary and so
  made an intermediate position impossible to hold. The page has its
  own light/dark choice
  (`frontend/src/composables/useLandingTheme.ts`, stored as
  `openhealth.landing.theme` and published as `<html data-landing-theme>`, set
  before the first paint on the landing addresses and removed when the page
  unmounts), so it shares neither the app's teal palette nor `eqalb.theme`; all
  of its styles are namespaced in `frontend/src/landing.css`, and it carries no
  simulated-data notice of its own (that wording lives inside the app). The one
  action, "Open the app", is still the real `/app` link — modified and middle
  clicks open it in a new tab — and a plain left click plays the crossing
  instead: `frontend/src/composables/useAppLaunch.ts` holds the sequence
  (about 1.2s: reveal pass, then the light's looping state, then the hand-over)
  and `frontend/src/components/LaunchTransition.vue` shows a still copy of the
  Home screen's eQalb composition wiped in behind a passing band of light, both
  fades being CSS animations so a delayed frame never leaves the overlay hidden
  or stuck. `/about` is About OpenHealth
  (`frontend/src/views/AboutView.vue`), and `/app` is the whole eQalb application,
  so its Home screen, tutorial, project description, download view and dashboard
  share one address and keep their existing behaviour; an unrecognised path opens
  the landing page and is rewritten to `/`. Links between the public pages carry a
  real `href` and are handled by the store unless the click is modified, so
  open-in-new-tab and copy-link still work; the external LinkedIn and GitHub links
  keep `target="_blank"` and `rel="noopener noreferrer"`. The browser-tab icon is
  the OpenHealth mark, generated from `frontend/src/assets/onlylogo.png` (1024 x
  1024 RGBA, genuinely transparent) into `frontend/public/favicon.ico` (16, 32 and
  48 px), `favicon-16x16.png` and `favicon-32x32.png` by cropping to the mark's
  bounding box plus a 3% margin and box-averaging down with premultiplied alpha;
  `frontend/index.html` declares them and no longer declares an SVG icon, the stock
  Vite `favicon.svg` having been deleted, and the single `index.html` means `/`,
  `/app` and `/about` all carry it. The landing page's footer link is "Blog"
  (`pagePath('blog')`), which is the one change the blog made to the page. No
  router was introduced
  and no dependency was added.
- OpenHealth blog: `/blog` is the posts newest first and `/blog/<slug>` is one
  post at its own address, published by the same view store that owns every other
  public address — the store carries the slug (`postSlug`), resolves
  `/blog/<anything>` to the blog rather than rewriting it, and exposes
  `blogPostPath()` and `followPostLink()`, so a post address survives a direct
  load, a reload and Back/Forward and the address always names what is on screen.
  The views are `frontend/src/views/BlogIndexView.vue` (title, date and optional
  summary per entry, separated by a quiet rule; no cards or thumbnails) and
  `frontend/src/views/BlogPostView.vue` (a link back to the index, the title and
  date, then the post's blocks in a narrow reading column, or a readable
  "Post not found" state naming the address). The shell is
  `frontend/src/components/blog/BlogLayout.vue` — the wordmark back to `/`, the
  `Blog` link, the landing page's own light/dark control and the same footer note
  — and it is where the blog's landing theme is owned and where a followed page
  returns to the top (`cameFromHistory()` distinguishes a followed page from a
  Back/Forward entry, so a history entry keeps the position the browser restores).
  The wordmark that leaves the blog for the landing page carries the same rule at
  the link (`followLandingLink`, beside `followLink` and `followPostLink` in
  `useAppView.ts`): it navigates to `/` and then scrolls that page to its top once
  it has replaced the blog, because the landing page has no scroll reset of its own
  — without it the reader arrived part-way down a page they had just asked for.
  Only a followed link goes through it, so Back and Forward are still left to the
  browser's own restoration, and the landing page's section anchors are untouched.
  Posts live in `frontend/src/content/blog/` as typed data: `types.ts` defines the
  closed block set (paragraph, heading, list, quote, with link segments inside a
  paragraph), each post is a module, and `posts.ts` is the registry that publishes
  them (a file that is not listed is a draft) and the only place a post is looked
  up; `frontend/src/components/blog/date.ts` renders a `YYYY-MM-DD` date as text
  from UTC parts. There is no Markdown parser, no HTML and no CMS, so nothing is
  sanitised and no dependency was added; the registry holds the one published post
  (the release of eQalb and the introduction of OpenHealth, dated 2026-10-14), and
  the index shows a restrained empty state (with a dev-server-only note pointing at
  the content README) whenever the registry is empty. `frontend/src/blog.css`, scoped under
  `.blog` and keyed on nothing else, holds the blog's layout and declares no
  palette of its own: it reads the landing tokens, so the blog is the landing
  page's palette and typography rather than the app's. `useLandingTheme.ts` now
  counts its mounted pages and removes `<html data-landing-theme>` only when the
  last of them unmounts, which is what keeps it on the page that has just arrived
  when the landing page and the blog hand over to each other — without it, Vue's
  end-of-flush unmounted hook took the attribute off the arriving page — while
  still removing it for every `/app` screen.
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
  Mahmood Alawi", the subtitle "An educational HTA model", the four-button menu —
  "Open analysis workspace" and "Guided tutorial" full-width on their own rows,
  with "Project description" and "Download results" side by side beneath them, the
  pair and its gap adding up to the row above, centred as one group under the
  credits, and the first two marked by an accent outline and a soft accent tint —
  followed by the
  creator/contact links (LinkedIn, GitHub) and a small icon light/dark control at
  the top-right. The whole composition is drawn complete and static — traces drawn
  whole, every letter in the full title colour — when the user prefers reduced
  motion.
  The two entry points do not explain themselves on the screen: each opens the
  app's own dialog (`modal modal--menu`, the shared `dialog` transition, the shared
  focus containment from `useModalFocus`) with a short title, one sentence and two
  actions — "Open workspace" or "Start tutorial", and "Close" — and only that
  action navigates, so the menu stays behind it inert and unchanged and Escape, the
  Close control or the backdrop returns to it. One explanation can be open at a
  time, opening or closing one runs no analysis and touches no state, and the two
  secondary destinations keep their direct navigation without a prompt in front of
  them.
  The hosted Shiny tutorial link and the long model-description paragraph were
  removed from Home in Batch 1 of the UX revamp, and the project-level disclaimer
  now lives only in the Project description view: it was removed from Home and
  from the dashboard footer, which no longer exists. Two subviews
  (`ProjectDescriptionView.vue`, `DownloadResultsView.vue`) carry the Shiny
  description wording, contact address and analyses list, and the session's
  exportable results respectively; Back and Escape return Home, and a compact
  persistent "Home" button sits in the dashboard header. The Download results page
  is one centred group in the app's content area — `page--centered page--fill`:
  the title, the introduction and the two actions are centred, the two result
  lists stay left-aligned inside a width-limited column, and `margin: auto` in a
  flex column (never a height of its own) centres the group while it fits and
  resolves to nothing when it does not, so a long list starts at the top and
  scrolls. Navigation is one shared
  ref (`frontend/src/composables/useAppView.ts`), not a router, and it never
  touches inputs or results. The model contract is fetched only when the dashboard
  is first opened, so Home makes no API request. `frontend/src/export/zip.ts` is a
  dependency-free store-only ZIP writer and
  `frontend/src/export/resultsPackage.ts` formats only values the API already
  returned, for the analyses the session has actually run; a README in the package
  lists what was and was not included and states the remaining backend gap
  (R-rendered chart images). No prompt, no Vue component and no endpoint
  calculates, rescales or reinterprets a model result.
- Base-case presentation mode in the browser interface (prototype, first iteration;
  presentation only): the Base-case tab's own actions gain one compact "Present"
  control, shown only once a valid base-case result exists, and it opens a
  viewport-sized overlay for a screen share — the app's own dialog (the shared
  `.modal` markup, the shared `dialog` transition and the focus containment from
  `useModalFocus`) with one scoped `modal--present` class for a larger panel. It
  shows a small eQalb identity line with the analysis name, a Close control, the
  four headline figures at `clamp(1.5rem, 3vw, 2.05rem)`, the ICER sentence the
  workspace keeps on its information control, the deterministic plane (a second
  `BaseCasePlane` instance in its own container, so the workspace chart's DOM is
  never moved), the run's assumption snapshot in a closed disclosure, and R's own
  `notice` line. It is a view of an existing result and nothing else: no request is
  issued (verified with a fetch/XHR spy), no figure is derived, no input, default,
  threshold or export state is touched, and opening it snapshots the result object,
  so a run that lands while it is open replaces the panel's result without
  replacing the presented one. The assumptions are read from
  `BaseCaseResponse.inputs` — the scenario R received — through the contract's
  labels, and shown with the form's own conversion, so a field edited after the run
  can never be printed as one the run used; a truthful line names what has moved
  since the run (the threshold, the scenario inputs, or both) whenever anything
  has. Only this tab has it: no other analysis tab or the main menu gained a
  Present control, and there is no browser-fullscreen call, slide, auto-advance or
  toolbar. Below 640px the panel stacks and scrolls inside itself, and under
  `prefers-reduced-motion` it is simply present (the global rule leaves it no
  motion to run).
- Presentation mode in the browser interface (frontend only, all nine analysis
  tabs): one compact "Present" action beside each tab's existing result actions,
  shown only when that tab has a valid result, opens a viewport-sized overlay that
  shows one completed analysis for a screen share. `components/presentation/`
  carries it: `PresentationOverlay.vue` is the shell every tab renders (the app's
  own `.modal` markup, the shared `dialog` transition and the focus containment from
  `useModalFocus`, one scoped `modal--present` class for the larger panel, the small
  eQalb identity line with the analysis title, the Close control, the line naming
  what has moved since the run, the line saying a later run has replaced this one,
  the settings disclosure and R's notice), `PresentationSettings.vue` renders one row
  per setting, and `settings.ts` holds the two sentences plus the two row builders
  (`movedSentence`, `supersededSentence`, `scenarioSettingRows`, `settingRow`) so no
  panel invents wording. No row shows an internal identifier: a request field the HTA
  summary reports as not supplied is named through `availabilityFieldLabel`
  ("Probability cost-effective", "EVPI per patient", "ICER", "Cumulative net budget
  impact", "DHT readiness"; an unknown future field loses its underscores rather than
  appearing as one), and the value-of-information overlay's EVPPI table leaves out the
  workspace's "Model argument" column, whose cells are R's own call arguments
  (`scenario_rrr`, …), because the parameter column already names each row in words.
  Each panel passes its own figures, charts and R-owned text
  through slots, and each overlay keeps the response object it was opened with, so a
  later run cannot change what is shown. Opening and closing runs nothing: no
  request, no derived figure, no change to inputs, defaults, thresholds, results or
  exports. There is no browser-fullscreen call, no slide, auto-advance, comparison
  or toolbar, no new chart animation and no new dependency; the charts inside an
  overlay are ordinary instances of the existing components in their own containers.
  The two tabs whose run is a request rather than a response — one-way sensitivity
  and readiness — keep that request (`useModel` holds `owsaRun` and `readinessRun`
  as the request records themselves: the ranked outcome, threshold, scenario body
  and range overrides for one-way, the readiness values and choices for readiness)
  and their settings disclosures list exactly those, so a control edited after the
  run is never printed as one the run used; the disclosure's own line says so, and
  the moved-since-run line appears whenever the tab would now send something
  different. The other seven tabs read their snapshot from the response R returned,
  which already carried the inputs it ran.
- Analysis-tab orientation in the browser interface (presentation copy only):
  each of the nine analysis tabs opens with one question sentence in place of the
  longer description it used to carry — "Is eQalb cost-effective at these
  assumptions?" on the base case, "How much does the answer change when the
  assumptions are uncertain?" on the PSA, "Which assumptions influence the result
  most?" on the sensitivity tab, "What could implementation mean for the budget —
  deterministic, undiscounted, per year?" on the budget tab, "How might
  event-free survival compare between the arms?" on the survival tab, "How much
  could resolving uncertainty be worth?" on the value of information, an
  explicitly illustrative question on the readiness tab, "What annual price would
  the model support at the reference threshold, and how does the current price
  compare?" on the value-based price tab and "What do the analyses run so far add
  up to?" on the HTA summary. The guidance shown before a result exists is one
  line naming the tab's own action ("Start with the default assumptions, then
  select Run base case."), and the value of information tab is the only tab with a
  real prerequisite, which it states ("Run PSA first to use this analysis; it
  reuses those draws, so the simulation is not repeated."). Every line sits in the
  placeholder the tab already had, keeps its existing `.hint`/`.muted` styling — no
  warning or error styling for a normal not-yet-run state — and disappears as soon
  as its own result is committed. The tab strip's hint line, the `InfoTip`
  controls and every disclosure are unchanged, and a unit, warning or model
  assumption that no control, caption or R wording already carried was kept inside
  the one sentence rather than dropped.
- Analysis-run states in the browser interface (frontend only; no calculation, API or
  execution behaviour changed): every explicit analysis action has one shape of state.
  The store's `run()` refuses a second request for an analysis that is already running
  — the belt to each panel's disabled action — so no double click, keyboard
  activation or twice-confirmed dialog can start a duplicate. Only that analysis'
  own action is disabled while it waits: the inputs, selectors, Present and the
  download buttons stay usable, and a run that depends on another analysis (the value
  of information needs the PSA) states the prerequisite instead of failing. The
  previous result is never cleared by a new run: it stays on screen with its stale
  notice while the request waits and is replaced only when R answers, so a failure
  leaves it exactly as it was with one `role="alert"` message beside it (R's own
  message, or the client's own "Cannot reach the model service…"), the action
  re-enabled and every input untouched for a straight retry. The five states are
  distinct and share one vocabulary: no result yet (`<p class="hint" role="status">`
  with the tab's guidance), in flight (the same element carries the wait sentence
  while the button's pending label and the app-wide loader say the same thing), result
  available (the figures, with the placeholder gone), request failed (the alert above
  it) and result from earlier settings (the existing stale notice, still
  `alert--warning` and still informational). Every pending label names its own
  analysis — "Running the base case…", "Running the sensitivity analysis…",
  "Running the budget impact…", "Simulating survival…", "Calculating the value of
  information…", "Assessing readiness…", "Calculating the value-based price…",
  "Assessing the HTA summary…" — and the PSA names the run's own iteration count
  ("Running 100 iterations…"), captured when the run starts so editing the iterations
  field while it waits cannot relabel the run that is going; the PSA's in-flight line
  (`role="status"`, the one place the older wording claimed "a 1,000-draw PSA takes
  minutes" for every run, including a 100-draw one) now says "Running 100 iterations.
  Keep this tab open until it finishes." and keeps the minutes warning only at or
  above the size the confirmation dialog warns about. The rotating lighthearted line
  is unchanged and stays where the pattern already existed — the app-wide loader card
  under the factual status (`useLoadingMessages`: 7 s rotation, opacity-only
  crossfade, one static message under reduced motion) — and was not copied into the
  panels. No state uses red or orange except a genuine failure; no retry, polling,
  background run or new trigger was added; nothing new is a container, so no state
  change moves the layout, and the longest pending label still fits on one line at
  390 px.
- Workspace wording audit in the browser interface (frontend presentation copy only,
  no calculation, API wording, export content or presentation-mode change): four
  pieces of static text were reduced to what a reader needs on the way to a result.
  (1) The assumptions sidebar's reset hint was three sentences that repeated the
  "Reset model inputs" button's own title and the stale notice every tab shows in
  situ ("results are snapshots and re-run from their own button", "every analysis tab
  marks a stored result as computed from earlier inputs"); it is now the one fact the
  hint alone carries — "Reset restores the 16 model assumptions and the threshold
  only; every completed result is kept." — with the full scope still in the button's
  title and the snapshot behaviour still stated by each tab's own result notice.
  (2) The sensitivity tab's permanently visible paragraph about the downloaded CSV
  (and how the Shiny export lays the same numbers out differently) moved unchanged
  into the "Full one-way sensitivity table (N parameters)" disclosure, where the
  table it describes already sits, so the open panel shows the ranked table, the
  tornado and R's interpretation without a file-format aside. (3) The survival tab's
  export note, which the download button's own title already covered in part and
  which named the API ("the API does not return that dataset yet") and the Shiny
  tab's extra download, is now one plain sentence that keeps the limitation: "The
  simulated patient-level dataset is not available here yet, so the download offers
  the summary tables instead." (4) The HTA summary's partial-assessment alert said
  the same thing twice for one result — "Not yet included: …", R's not-assessable
  domain names, and then the raw API request fields
  ("Request fields not supplied: probability_cost_effective, evpi") — and the raw
  field list also appeared again inside the availability disclosure; the prominent
  copy is gone and the field list remains in that disclosure alone, so nothing a
  reader is told is lost. Deliberately unchanged: every R-generated string (R's
  interpretations, summaries, notes, warnings, thresholds, availability wording and
  the simulated-data notices), the export strings and the text written into exported
  files, every result-specific notice (stale, bound, excluded-iteration,
  missing-analysis, failed-run), the readiness traffic-light disclaimer, the
  value-based price insight's "it is not an input to this summary" clarification, and
  each tab's one-sentence introduction.
- Per-chart PNG export in the browser interface (frontend only, local review first):
  every interactive ECharts chart in the analysis workspace carries one compact
  "Download chart" action under it, inside the figure that holds that chart
  (`components/ChartDownload.vue`). It saves the chart exactly as it is on screen —
  the live instance is asked for its own image via `getDataURL`, looked up from the
  chart's own container with `getInstanceByDom` (which returns undefined rather than
  initialising a chart) — so nothing is rerun, no result is recomputed, no option is
  changed and no second chart is created for the export. The current theme travels
  with it: the live palette's panel colour is painted behind the image, so a
  dark-theme chart exports as readable text on the dark panel and a light-theme one
  as dark text on white. The image is written at twice the on-screen pixels, so it
  stays sharp when enlarged. Nine charts are covered — the base-case plane, the PSA
  plane and acceptability curve, the tornado, the budget-impact chart, the survival
  curves, the EVPI and EVPPI charts and the value-based-price comparison; the
  readiness and HTA summary tabs have tables rather than charts, so they get nothing,
  and the tutorial's own charts are outside this workspace and were not touched. Files
  are named for the analysis and the chart
  (`base-case-cost-effectiveness-plane.png`, `psa-cost-effectiveness-plane.png`,
  `psa-acceptability-curve.png`, `sensitivity-tornado-diagram.png`,
  `budget-impact-net-and-cumulative.png`, `survival-event-free-survival.png`,
  `value-of-information-evpi.png`, `value-of-information-evppi.png`,
  `value-based-price-comparison.png`). The button is a real `<button>` with an
  `aria-label` naming its chart ("Download the … chart as a PNG") and a `title` naming
  the file, reached by Tab, activated by Enter or Space, and painted with the app's
  ordinary focus ring; it is always present while its result is, so the figure's
  height never changes when it is used. Outcomes go through the app's single download
  notice (`prepareDownload`): "Download prepared." with the file name, or, when the
  chart is not on screen, "The download could not be prepared. The chart is not on
  screen yet." as a `role="alert"` — the chart and the result are left exactly as they
  were. Presentation mode is untouched (its overlays build their own captions and do
  not render this component), the consolidated results ZIP is untouched (it still
  carries the numeric tables and no chart images), and the base64 payload is decoded
  for the download without reading or re-encoding a pixel
  (`export/png.ts`).
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
- Backend deployment automation (2026-10-17): implemented and locally validated,
  but no live deployment has completed. The first manual run failed in the old
  preflight before any change because it required `/etc/eqalb/api.env`, which the
  host does not have; the rewritten preflight resolves the inline systemd
  configuration or a genuine `EnvironmentFile`. SSH login, pinned host-key login
  and the application-account sudo grant for `eqalb-backend-deploy` are confirmed
  on the host; the workflow stays manual-only until a live deploy and a live
  rollback both pass. The live host reports two R workers while
  `deploy/api.env.example` records one; the workflow deliberately leaves that
  server-local setting unchanged.
- The public addresses are resolved in the browser, not by the server, so a host
  serving `frontend/dist` must return `index.html` for an unmatched path. Vite's
  dev server and `vite preview` both do this already, which is how `/`, `/blog`,
  `/blog/<slug>`, `/app` and `/about` were verified; on a host that does not, a
  direct load or a reload of any of them would return 404. The repository's
  `deploy/Caddyfile` now carries `try_files {path} /index.html`, added by the
  frontend-deployment work recorded in Current task rather than by the public-shell
  task, so the fallback these addresses need is part of the deployment
  configuration instead of outstanding. eQalb's internal
  screens deliberately have no deep links, so `/app` is the only eQalb address.
- The blog is published with one post: *Release of eQalb & The introduction of
  OpenHealth!* (2026-10-14), the author's own text published exactly as written,
  with no wording edited and no links added — the slug `release-of-eqalb-and-openhealth`
  is derived from the title, and the date was given as 14/10/2026 and written in the
  format's `YYYY-MM-DD`. The article path, the index and the not-found state were
  verified against this post and with temporary posts that were deleted afterwards.
  A post is typed data in `frontend/src/content/blog/`; there is no Markdown renderer
  and no HTML, which keeps the blog dependency-free, so Markdown would be one small
  dependency plus its approval if it is wanted later.
- The landing page no longer links to `/about`: the footer's "About OpenHealth"
  link was replaced by "Blog", as instructed. `/about` itself is unchanged, still
  resolves directly and still links back to `/`, but it has no entry point on the
  landing page until that is decided.
- The blog's shell starts a followed page at its top and leaves a history entry
  where the browser restores it — and the wordmark that leaves the blog for `/`
  does the same for the landing page (`followLandingLink`), which otherwise keeps
  whatever position it is left in. The landing page is still not reset when it is
  reached some other way from a scrolled public page: `/about`'s "Back to
  OpenHealth" link inherits the position, exactly as it did before the blog
  existed. That is pre-existing behaviour and was out of scope.
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
- The `renv` library was out of sync with `renv.lock` in the working copy until the
  deployment-readiness pass took a deliberate `renv::snapshot()`; `renv::status()`
  now reports the project is in a consistent state.
- The project requires R 4.5.1 (`renv.lock`), and **CRAN no longer publishes R 4.5
  binaries for any current Ubuntu LTS release**, so R is **not** installed from an
  apt repository on the deployment host. The official instructions at
  `https://cloud.r-project.org/bin/linux/ubuntu/` (read 2026-10-13) list 26.04
  ("resolute"), 24.04 ("noble") and 22.04 ("jammy") as supported, but all of them
  serve "the current R 4.6.* release"; the page states that `cran40` "denotes a
  binary compatibility break by the R 4.0.* release, it does not install R 4.0.*
  but the current R 4.6.* series". The suite name is correct - the version it
  delivers is not. The linked `olderreleasesREADME.html` confirms R 4.5 binaries
  are "no longer being updated... available for archival purposes" and documents
  only `focal-cran40` for Ubuntu 20.04, so reimaging to 24.04 would not restore
  4.5.1 either. **Decision taken: build R 4.5.1 from the official source archive
  into the isolated prefix `/opt/R/4.5.1`** (`deploy/DEPLOY.md` "DECISION" and
  §1.2), leaving any system R untouched. The archive is pinned to
  `https://cran.r-project.org/src/base/R-4/R-4.5.1.tar.gz` with SHA-256
  `b42a7921...ee8f444`, taken from the R Core Team's release announcement on the
  official r-announce list (`https://stat.ethz.ch/pipermail/r-announce/2025/000713.html`),
  because CRAN ships no per-file checksum file beside the tarball. The API reaches
  that R through the existing `EQALB_RSCRIPT` variable, so `/usr/bin/Rscript` is
  not a requirement. Maintenance consequence, recorded deliberately: the
  source-built R receives no updates through `apt upgrade` and must be rebuilt as
  a deliberate act.
- The production install path is now deployed and smoke-tested at
  `https://openhealth.ngo` - not fully validated. The stack was developed and
  validated on Windows with R 4.5.1 and
  Python 3.14, while a VPS deployment means **Ubuntu 26.04 LTS (resolute)**
  compiling R 4.5.1 from source, restoring the 135 locked packages against it, and
  installing `api/requirements.lock.txt` under the Python 3 that release provides.
  That has since been done on the host, and `deploy/DEPLOY.md` keeps it a
  controlled compatibility check with a stop-and-verify checkpoint after
  `renv::restore()`: deployment proceeds only when the restore completes,
  `/opt/R/4.5.1/bin/Rscript --version` reports exactly R 4.5.1, the release's
  Python 3 virtual environment installs the lock file, the API service starts, and
  `/api/health` reports `model_ready: true` with one ready R worker. Anything else
  stops before DNS, Caddy or any public exposure, collects the systemctl and
  journalctl output, and waits for a deliberate decision rather than substituting
  a different R version or installing packages outside renv.
- The smoke test confirmed the deployed stack: `https://openhealth.ngo` serves the
  frontend over HTTPS with a Caddy-obtained certificate, the proxied `/api/health`
  check returned HTTP 200 with `model_ready: true` and 2 of 2 R workers ready, and
  a browser pass found no console errors, no failed API requests and working core
  interactions. Caddy needs read and traverse access to the static frontend build
  directory. Operational performance testing remains open, along with formal load
  and security testing, clinical or model validation, and exhaustive functional
  testing.
- The deployment templates (`deploy/`) are written from the repository rather than
  from a completed install, so the 4 GB-host build (`make -j"$(nproc)"`, reduced to
  `-j2` if memory is tight), the systemd hardening (`ProtectHome=read-only` with
  `StateDirectory=eqalb` and a redirected `HOME`/`XDG_CACHE_HOME`), and the R
  source build itself are still to be confirmed on the host.
- The frontend deployment automation is configured server-side and on GitHub,
  and one end-to-end automated deployment has succeeded. The workflow
  (`.github/workflows/deploy-frontend.yml`), the server script
  (`deploy/frontend-deploy.sh`) and its runbook (`deploy/FRONTEND_DEPLOY.md`)
  exist and were validated locally; the GitHub `production` environment and its
  six secrets are configured; the passphrase-free CI-only Ed25519 key has been
  created, installed behind the restricted forced-command wrapper, tested,
  rotated into the `DEPLOY_SSH_KEY` secret and the old key removed; and the
  one-time public-pointer and Caddy migration has been performed and verified on
  the VPS (`/opt/eqalb/public/dist` ->
  `/opt/eqalb/frontend/releases/initial-20261013`, `/etc/caddy/Caddyfile` root
  `/opt/eqalb/public/dist`, `https://openhealth.ngo/` returning HTTP 200 and
  `https://openhealth.ngo/api/health` reporting `status: ok` with
  `model_ready: true`). The server-side bootstrap is in place: dedicated deploy
  account, fixed directories, root-owned script and forced command, and narrow
  per-user ACLs (`eqalb-deploy` and `caddy` traverse-only on `/opt/eqalb` and
  `/opt/eqalb/frontend`; `caddy` read-and-traverse on `/opt/eqalb/public` and
  `/opt/eqalb/frontend/releases`) that leave `/opt/eqalb` at its existing
  restrictive `750 eqalb:eqalb` mode rather than widening it. The first
  automated workflow run was then attempted and **failed before activation**, at
  the `scp` upload step, because the upload command and the server's
  forced-command wrapper disagreed (see Current task); the corrected upload -
  the archive and its checksum as two separate single-file legacy SCP transfers -
  has since carried a successful end-to-end automated deployment, which also
  exercised the pinned action SHAs. The operator has confirmed the `production`
  environment's required-reviewer/approval rule. What remains untested is
  rollback: neither the automatic rollback after a failed validation nor the
  manual rollback has been exercised. The successful release was built from
  `main`, so the OpenHealth public shell on `feature/openhealth-landing` is not
  part of a deployed release. The workflow's only automatic trigger is a push to
  `main`, and this work is still uncommitted on that branch, so
  `https://openhealth.ngo` necessarily serves a bundle from before the landing
  page existed: its JS and CSS are `index-DHn5KSsW.js` / `index-DoeXKmoo.css`
  (title "OpenHealth — accessible, practical health learning") and neither
  contains `--reveal`, `landing__reveal-inner`, `landing--armed` or
  `mahmood-portrait`, while the local build ships
  `index-Di0v34KJ.js` / `index-BlmOXbwG.css` with all four. The live site
  therefore cannot be used to review the landing page at all; use the dev server
  on `http://127.0.0.1:5173` until this branch is merged and deployed.
- The redesigned landing page is a first draft for the author's review, and its
  constraints are honest ones. Its navigation is the three section links plus the
  theme control: the OpenHealth wordmark is hidden below 700px so the floating
  panel stays compact. The About me portrait ships as a 640 x 591 PNG (346 kB)
  derived from the author's original, which is kept beside it as
  `frontend/src/assets/mahmood.png` (1305 x 1206, 962 kB) as the source of any
  future re-export; the shipped file has to stay a PNG because the original is a
  cut-out with a transparent background and Windows' image encoders offer no WebP
  to convert it to, so 346 kB is the floor reachable without a new dependency. The
  serif is a local font
  stack (`Iowan Old Style`, `Palatino Linotype`, Georgia) rather than a webfont,
  so the exact face depends on the visitor's machine, and the copy, the contact
  details and the `/app` route are decisions for the author to approve. The About
  page at `/about` still uses the app's teal theme while the landing page uses its
  own palette: that is deliberate (only the landing page carries the landing
  identity), but it is a visual jump worth settling one way or the other, and
  `AboutView.vue` still calls the founder "a health economist" where the landing
  page now says "a health economics graduate" — the landing page is what was
  asked for, so the About page was left alone and the wording is the author's to
  settle. The landing page reaches the application only through the one "Open the
  app" link, so it makes no API request of its own. The crossing into the app is
  decoration that owns no navigation: the page is mounted and interactive as soon
  as the sequence hands it over, and the overlay can never take a click, hold the
  keyboard or outlive its own timers. Two consequences of the scroll fade being
  reversible are worth stating rather than discovering later: the About Me group
  never fades out, because the document ends beneath it and its bottom edge never
  rises to the exit threshold — that is the specified behaviour, and forcing a fade
  would mean adding blank scrolling space, which was ruled out; and because the
  effect is now a function of position in both directions, a reader who scrolls
  back up sees content fade out above them, which is the intended reversal rather
  than a lost state. How the fade feels at speed is a judgement about the reveal
  range rather than a defect, and the numbers that set it (`ENTER_FROM`,
  `ENTER_DONE`, `EXIT_START`, `EXIT_DONE`) are named constants at the top of
  `frontend/src/views/OpenHealthHomeView.vue` for exactly that reason. The tab icon
  is raster-only — `.ico` at 16,
  32 and 48 px plus 16 and 32 px PNGs, generated from `onlylogo.png`; there is no
  scalable SVG icon, because the mark is a raster cut-out and nothing in the
  project can trace one, so a context that needs a vector or a much larger icon
  would show the mark scaled from those bitmaps. The source PNG's own faint halo
  (pixels at alpha 1 or 2 of 255 carrying saturated leftover colour) survives into
  the icons at the same opacity; it is imperceptible and was left rather than
  stripped, since removing pixels is not the generator's business.
- The result entrance and the tutorial step transition are decoration. Both are
  verified by DOM, computed-style, animation-timing and geometry measurements on
  the dev server plus the three build checks, and the rendered frames of the trace
  were also looked at (frozen mid-sequence, at real size and enlarged, in both
  themes); how the effect feels is still the author's to judge locally, and the
  durations (240 ms fade, 780 ms draw and pass, 180 ms fade-out, and the tutorial
  move's 180/220 ms) with the travel (10 px) are the values to adjust if they feel
  wrong. The result entrance is deliberately the same restrained treatment for the
  top-level summary of each of the nine analysis panels and nothing else: no table
  row, chart, nested card or tutorial result animates, tutorial steps get the
  transition and not the trace, and there is deliberately no counting, pulsing or
  chart animation because those would imply a calculation that never happened. The
  tutorial's Part 1 to Part 2 switch is a page-level hand-over rather than a step,
  so it is not animated; only the moves inside each part are. The trace's strip is
  reserved in the heading block at every state and is transparent between runs:
  that is what keeps a run, and the decoration ending, from shifting anything, and
  it means every panel heading carries about 18px more space between its text and
  its description than it did before the strip existed (19.2px of reserved strip,
  with the heading's own bottom margin removed). Under `prefers-reduced-motion` the
  strip is simply never drawn; in print it is removed outright and the heading
  spacing is restored.
- The interaction-polish pass is presentation only, and two parts of its
  verification have limits worth naming. First, the animated disclosure exists
  only where the engine has both `::details-content` and `interpolate-size`; the
  machine this was built on has only Chromium (Electron 150), so what was observed
  is that path, and the fallback — an ordinary instant open and close — is
  reasoned from the `@supports` guard rather than seen in a browser without it.
  Second, the loading messages were measured against a request held open by the
  test side rather than by making a real model run longer, as instructed — and in
  this environment a response deferred on the test side does not reach the page: a
  `continue()` delayed by nine seconds left the request pending for good (the
  handler ran, the card stayed), which is what an earlier attempt to watch a
  completion land inside a crossfade mistook for the app's behaviour. The
  completion-time checks were therefore made by answering the request from a fetch
  wrapper inside the page, with a real payload captured from one genuine run. What
  that measures is the app's own behaviour — the 1 s grace, a change every 7 s, the
  280 ms crossfade, the card's height across messages, the frame in which a
  completion removes it — while the messages' own wording, and how the crossfade
  reads at full speed, are still the author's to judge.
- **Every dialog now contains its own focus, and the defect that stopped the
  previous release is fixed (2026-10-15).** Until this fix the four `.modal`
  dialogs carried `role="dialog"` and `aria-modal="true"` without containing the
  focus or blocking the page behind them: on the PSA confirmation ("Run the PSA
  with 1,000 iterations?", controls Continue and Cancel, 57 tabbable controls
  behind it) focus started on Continue, one Tab reached Cancel, and the next Tab
  left the dialog for the dashboard header, the status chip, the theme button and
  the assumptions panel. The pointer could not follow it (the backdrop covers the
  page, verified with `elementFromPoint`), but the keyboard could, and activating a
  control behind the dialog dismissed it and navigated the app away
  mid-confirmation. `frontend/src/composables/useModalFocus.ts` now supplies the
  keyboard half of the same modal pattern the dialogs already had for motion: the
  focus moves in on open, Tab and Shift+Tab wrap inside, every element outside the
  dialog is `inert` (through the dialog's relatives, never through an ancestor, so
  a dialog can never inert itself), and the focus returns to whatever opened it —
  with the welcome question's fallback being the selected analysis tab, since it is
  asked on arrival rather than opened from a button, and with a disabled opener
  (Continue, which disables the run button as it starts the run) leaving the focus
  where the dialog left it rather than on a control that cannot take it. The
  elements made inert remember their own prior state, so an element that was
  already inert stays inert, and a dialog that closes, unmounts or has its page
  taken away underneath it cannot leave the app inert. Measured in the running app
  on all four dialogs: opener → contained Tab/Shift+Tab → every close path
  (Confirm, Cancel, Close, Escape, backdrop) → focus returned, and the background
  unusable by keyboard while open. Continue's own disabled-opener case and the
  unmount-while-open case were measured with the button pre-disabled and with a
  Back navigation respectively, so no 1,000-draw PSA was run for a focus check.
- The download notice reports preparation, never a saved file, because a browser
  cannot tell the interface whether a download completed; and the loading messages
  are decoration by design — they are `aria-hidden`, so a screen-reader user hears
  only the factual operation status. Their list is the one place to edit the
  sentences (`LOADING_MESSAGES` in `frontend/src/composables/useLoadingMessages.ts`),
  and under `prefers-reduced-motion` one message is shown still for the whole wait
  instead of rotating.

## Current task
Uncommitted (2026-10-17): **backend deployment preflight fixed for the live
systemd configuration** (deployment script and documentation only; no R model,
API, frontend, analysis, default or production unit changed).

- Root cause: the first manual workflow run stopped before checkout because the
  preflight unconditionally read `/etc/eqalb/api.env` as `eqalb`. The live host
  has no `/etc/eqalb` directory: `eqalb-api.service` sets
  `EQALB_RSCRIPT=/opt/R/4.5.1/bin/Rscript` inline, declares no
  `EnvironmentFile=`, runs two workers and is healthy.
- `deploy/backend-deploy.sh`: configuration is resolved read-only, in systemd's
  order: inline `Environment=` (with drop-ins), then each `EnvironmentFile=` in
  order (later wins, `-` optional, missing required or unreadable is a stop),
  then `ExecStart` (uvicorn: `--host`/`--port`, then `UVICORN_*`, then
  `127.0.0.1:8000`; `run_api.py`/`main.py`: `EQALB_API_*`, else
  `127.0.0.1:8788`; unrecognised launcher: explicit settings, else the observed
  listener), then `EQALB_RSCRIPT` or a service-`PATH` lookup, with
  `EQALB_R_WORKERS` defaulting to 2. Files are parsed as data, never sourced;
  only allowlisted values are printed. The running process is cross-checked: an
  R-path or listener mismatch stops before any change, a worker-count difference
  warns. `EQALB_DEPLOY_RSCRIPT/API_HOST/API_PORT` overrides cover a host that
  cannot be resolved read-only. The `status` action prints the resolved unit, R,
  listener, workers and health URL.
- `.github/workflows/deploy-backend.yml` is unchanged and remains manual-only;
  the `push` trigger is still commented out.
- `deploy/BACKEND_DEPLOY.md`: records the first-run failure, the two supported
  configuration sources and their precedence, the `eqalb-backend-deploy` account
  with its two sudo grants, the read-only inspection commands, the
  `Environment=` vs `EnvironmentFiles=` caveat, and the remaining open question
  about the live launcher and port.
- Verified locally: `bash -n`, `shellcheck -x -S style` and `actionlint` (with
  shellcheck) clean; 30 configuration-parser tests and 30 stubbed-systemd
  resolver scenarios pass (inline-only, EnvironmentFile override, missing,
  optional and unreadable files, unset/conflicting settings, R and listener
  mismatches, unknown launchers, IPv6/wildcard/UDS listeners, worker warning,
  fail-before-change ordering). Not verified: the live host and the first
  successful deploy.

Uncommitted (2026-10-16): **browser-tab title changed to "OpenHealth"** (frontend,
two lines of source).

| Where | Before | After |
|---|---|---|
| `frontend/index.html`, the static `<title>` | `eQalb — an interactive introduction to health-economic modelling` | `OpenHealth` |
| `useAppView.ts`, `PAGE_TITLES[LANDING_PATH]` (`/`) | the same old title | `OpenHealth` |
| `useAppView.ts`, `PAGE_TITLES[APP_PATH]` (`/app`, every in-app screen) | `eQalb — illustrative HTA model` | `OpenHealth` |

`/about` ("About OpenHealth"), `/blog` ("Blog — OpenHealth") and an open blog post
(its own name plus " — OpenHealth", set by `BlogPostView.vue`) were deliberately left
alone: they are separate public documents with titles that name them, not the
workspace's tab. The metadata description, favicons, landing copy, in-app eQalb
branding, tutorial content and model naming are unchanged, and nothing else in the
frontend writes `document.title` — the two setters found by a repo-wide search are
that title table and the blog post view.

Verified before leaving it in the tree: `npm run typecheck`, `npm run lint`,
`npm run build` (`index-DwadKxDr.js`) and `git diff --check` all pass, and the built
`dist/index.html` carries `<title>OpenHealth</title>`. In the browser the tab showed
exactly "OpenHealth" on the landing page, on `/app` from the first paint, through the
"Open analysis workspace" explanation overlay, on all nine analysis tabs, on the Home
screen, the tutorial, the Project description and the Download results views, while a
presentation overlay was open and after it closed; `/about` and `/blog` and a blog
post kept their own titles. No regression: the base case still ran (€2,439), the
chart export still produced `base-case-cost-effectiveness-plane.png` with one canvas
and no extra request, presentation mode opened and closed with the workspace intact,
the API reported `ok`, and no analysis request came from any navigation.

Uncommitted (2026-10-16): **presentation-mode wording follow-up** (frontend copy
only, local review first): the two places where a presentation still showed an
internal identifier now show the reader's word for it, and nothing else about a
presentation changed.

| Where | Before | After |
|---|---|---|
| HTA summary overlay, settings disclosure | Row "Request fields not supplied" with the endpoint's own identifiers as its value: `probability_cost_effective, evpi` (and `icer`, `cumulative_budget_impact`, `readiness` when those are the ones missing). | Row "Values not supplied" with the workspace's own names for the same fields: "Probability cost-effective, EVPI per patient" (and "ICER", "Cumulative net budget impact", "DHT readiness"). Every field R reports is still listed; nothing is dropped, renamed in R, or guessed, and a field a future contract adds is written with its underscores removed rather than shown as an identifier. |
| Value of information overlay, EVPPI table | Four columns, including "Model argument", whose cells are the R call's argument names (`scenario_rrr`, `scenario_engagement_year1`, …). | Three columns: Parameter, EVPPI per patient, Unclamped estimate — the same nine rows with the identifier column left out, since the parameter column already names each row in words. |

Both are presentation-only, and the workspace's own copies are untouched: the HTA
summary's "Availability of the upstream analyses" disclosure still lists the request
fields, and the tab's EVPPI table still carries its "Model argument" column, so
nothing about the desktop workspace changes. The mapping lives in
`components/presentation/settings.ts` (`availabilityFieldLabel`) so no panel invents
a name, and the overlay's column set is derived from the panel's own columns rather
than duplicated.

Verified before leaving it in the tree: `npm run typecheck`, `npm run lint`,
`npm run build` (`index-Dg4e6nwv.js`) and `git diff --check` all pass. In the browser
with all nine results stored, every overlay was opened with all of its disclosures
expanded and its text scanned for identifiers: **zero** snake_case names and no
"Request fields" phrase in any of the nine, while each overlay still showed its own
figures, tables and settings rows (base case 4 metrics / 17 rows, PSA 4 / 4, tornado
4 / 20, budget 4 / 9, survival 4 / 4, VOI 4 / 4 with its 9-row table, readiness 4 /
15, value-based price 3 / 18, HTA summary 1 / 7); the value-of-information overlay's
EVPPI table now reads Parameter | EVPPI per patient | Unclamped estimate with the
same nine parameters, and its workspace table still reads all four columns including
"Model argument"; the HTA summary overlay's settings show "Values not supplied:
Probability cost-effective, EVPI per patient, DHT readiness" in the partial state
(2 of 5 domains) and no such row when everything is included — the row appears
exactly when R reports a field missing. No analysis request was issued while opening
or closing any overlay (a fetch spy recorded none); Close and Escape returned the
focus to that tab's Present action with zero overlays and zero `[inert]` left behind.
No chart-export control appears inside an overlay (0 in all nine), and a workspace
PNG export still produced a valid 163 KB image. At 390 px the value-of-information
overlay had no page or panel overflow and its three-column table scrolled inside its
own container (488 px content in 297 px). The wording audit is intact (the shortened
sidebar hint still renders) and the HTA summary's workspace disclosure is unchanged.

Uncommitted (2026-10-16): **per-chart PNG export for the workspace's interactive
ECharts charts** (frontend only, local review first).

Each of the nine workspace charts gained one small action — "Download chart", under
the chart inside its own figure (`components/ChartDownload.vue`) — and nothing else
about a chart changed: the composable, the chart components and their options are
untouched, so the workspace and presentation-mode renderings are the same bytes they
were.

How it works, and why it is not a second chart: the button resolves the chart's live
instance from its own container (`getInstanceByDom`, which never initialises
anything) and asks that instance for its image (`getDataURL`, `type: 'png'`,
`pixelRatio: 2`, with the live palette's panel colour as the background). Nothing is
rerun, no result is recomputed, no option is modified, no instance or canvas is
created for the export, and the image is the chart as currently rendered in its
current theme and with its current data. The base64 payload is decoded to bytes
(`export/png.ts`) and handed to the browser by the existing download helper, and the
outcome is reported by the app's existing single notice (`prepareDownload`), so no
new notice system and no new dependency were introduced.

| Chart | File |
|---|---|
| Base case, deterministic cost-effectiveness plane | `base-case-cost-effectiveness-plane.png` |
| PSA, cost-effectiveness plane | `psa-cost-effectiveness-plane.png` |
| PSA, acceptability curve | `psa-acceptability-curve.png` |
| Sensitivity, tornado diagram | `sensitivity-tornado-diagram.png` |
| Budget impact | `budget-impact-net-and-cumulative.png` |
| Survival, event-free survival | `survival-event-free-survival.png` |
| Value of information, EVPI chart | `value-of-information-evpi.png` |
| Value of information, EVPPI chart | `value-of-information-evppi.png` |
| Value-based price, price comparison | `value-based-price-comparison.png` |

Deliberately out of scope: presentation mode (its overlays build their own captions
and do not include the action — verified zero buttons and no "Download chart" text in
an open overlay), the tutorial's own charts, the readiness and HTA-summary tabs (they
have tables, not charts), the consolidated results ZIP (its file list is unchanged
and still carries no chart images), the R models, the API, the calculations, the
input defaults and the existing CSV exports.

Verified before leaving it in the tree: `npm run typecheck`, `npm run lint`,
`npm run build` (`index--hTHQU07.js`) and `git diff --check` all pass. In the browser
(model API on 127.0.0.1:8788, Vite on 127.0.0.1:5173) with all nine results stored,
all nine buttons were clicked and every produced file was read back and decoded: each
is a valid PNG with a non-empty payload (46–163 KB), many distinct colours
(214–1067), non-zero ink, and dimensions exactly twice the canvas measured at click
time (e.g. the base case 956x320 -> 1912x640, the tornado 956x420 -> 1912x840, the
two value-of-information charts 930x320/930x420 -> 1860x640/1860x840), with the panel
colour in the corner (dark theme `rgb(22,36,44)`, light theme `rgb(255,255,255)`), so
each image is that chart in that theme rather than a blank or a shared frame. No API
request was issued by any export (a fetch spy recorded none across all nine, the
repeat runs and the keyboard run). Three repeated exports of one chart left the canvas
count, the zrender root count and the figure height unchanged (1 canvas, 1 instance,
402 px), so nothing leaks and nothing shifts. The button is reachable by Tab with
`outline: 2px solid rgb(127,209,216)` and `:focus-visible` matching, and Enter
downloads. With the chart's container removed, the action reported
"The download could not be prepared. The chart is not on screen yet." as a
`role="alert"` with zero downloads and the four result figures intact; leaving the tab
and returning re-rendered the chart and the export worked again. Under
`prefers-reduced-motion: reduce` the button has a 0 s transition and still exports. At
390 and 1440 px on all seven chart tabs: no page overflow, no figure outside the
viewport, no button outside its figure. The results package still builds 14 entries
with no `.png` among them, presentation mode opens with no download action, and the
stored results and figures are unchanged (base case €2,439 / 0.0082 / €298,966 /
−€1,623). Not verified: the Shiny application (untouched), the hosted deployment
(unchanged), a real screen reader (the label and role were read from the
accessibility tree, not announced), and browsers other than Chromium.

Uncommitted (2026-10-16): **conservative wording audit across the analysis
workspace** (frontend copy only, local review first): four static texts reduced
where the same information already lived somewhere a reader can reach it, with
nothing removed that explains a result.

The rule applied was one of replacement rather than deletion: a sentence could go
only when the fact it carried is still available in the project description, an
information popover, a collapsible section, the button's own title, or a
result-specific notice. What changed:

| Where | Before | After |
|---|---|---|
| Assumptions sidebar (`.assumptions > p.hint`) | "Reset restores the 16 model assumptions and the threshold only, and keeps every completed result; results are snapshots and re-run from their own button. Every analysis tab marks a stored result as computed from earlier inputs when the inputs or the threshold it used have changed." | "Reset restores the 16 model assumptions and the threshold only; every completed result is kept." The scope detail stays in the "Reset model inputs" title; the snapshot and stale behaviour is what each tab's own stale notice says, in the tab where it matters. |
| Sensitivity analysis, permanently visible under the tornado | "The downloaded CSV holds that table: one row per parameter, with the low and high results in separate columns. The Shiny export writes the same results in a long layout instead — one row per parameter and scenario — so the two files carry the same numbers in different shapes." | Moved unchanged into the "Full one-way sensitivity table (N parameters)" disclosure, beside the table it describes; the open panel no longer carries a file-format aside (the download button's title still names the CSV's shape). |
| Simulated survival, above the controls | "This export holds the summary tables above. The Shiny tab additionally downloads the simulated patient-level dataset; the API does not return that dataset yet, so it is not offered here rather than reconstructed with a different method." | "The simulated patient-level dataset is not available here yet, so the download offers the summary tables instead." The limitation is kept; the API reference, the Shiny comparison and the engineering rationale are gone, and what the export holds is already the download button's title. |
| HTA decision summary, partial-assessment alert | "Not yet included: PSA, Value of information. R reports these domains as not assessable: Economic value, Decision uncertainty. Request fields not supplied: probability_cost_effective, evpi." | "Not yet included: PSA, Value of information. R reports these domains as not assessable: Economic value, Decision uncertainty." The raw request-field list — the only internal API vocabulary in the workspace — is gone from the prominent alert and still available inside the "Availability of the upstream analyses" disclosure, where it also appeared. |

Two follow-up pieces of the same rule landed in **presentation mode only**, because a
presentation is read by someone who has never seen the contract and the workspace's own
copies are deliberate (the availability disclosure keeps the field list, and the
value-of-information table keeps its model-argument column): the HTA summary's settings
disclosure now names each not-supplied request field with the workspace's own wording
(`availabilityFieldLabel` in `components/presentation/settings.ts` — `icer` → "ICER",
`probability_cost_effective` → "Probability cost-effective", `evpi` → "EVPI per patient",
`cumulative_budget_impact` → "Cumulative net budget impact", `readiness` → "DHT
readiness", and an unknown future field written with its underscores removed rather than
as an identifier) under the row label "Values not supplied"; and the value-of-information
overlay's EVPPI table drops the "Model argument" column, whose cells are R's own call
arguments (`scenario_rrr`, …), since the parameter column already names every row in
words. Neither omits a value: the same fields are listed, and the same nine EVPPI rows
are shown, with three reader-facing columns instead of four.

Deliberately unchanged, and why: every string R writes (interpretations, summaries,
`summary_note`/`bounds_note`/`event_note`/`logrank_note`/`evidence_note`/`rule_note`,
thresholds, availability wording, the simulated-data notices) because R owns all
wording about a result; the export strings and the text written into exported files,
including the CSV button titles and `resultsPackage.ts`'s README and gap text; every
result-specific notice (the stale notice, bound warnings, excluded-iteration counts,
the value-of-information draw warning, failure messages); the readiness
traffic-light disclaimer and legend; the value-based price insight's "it is not an
input to this summary and does not change the position above", which no other line
carries; the eight one-sentence tab introductions; and "held in this browser"
phrasing, which distinguishes this session's PSA draws from a server-side rerun.
Presentation mode's own settings rows were out of scope for that pass and were
handled in the follow-up below.

Verified before leaving it in the tree: `npm run typecheck`, `npm run lint`,
`npm run build` (`index-_4G5NO3w.js`) and `git diff --check` all pass. In the
browser (model API on 127.0.0.1:8788, Vite on 127.0.0.1:5173) with all nine results
stored: the shortened sidebar hint renders; the sensitivity note is absent from the
open panel (`0` matching nodes) and present and visible once the table disclosure is
opened, absent from `innerText` and `checkVisibility() === false` while it is closed;
the survival note reads the new sentence and the panel contains no "the API does not
return" text; the HTA summary alert renders the two plain-language sentences with no
`<code>` field list in the panel; at 1440, 1024, 768 and 390 px the base case,
sensitivity, survival and HTA summary tabs report `scrollWidth === clientWidth` with
no paragraph escaping the panel; base-case figures are unchanged (€2,439 / 0.0082 /
€298,966 / −€1,623) with one canvas and no request issued; and the edited strings
render in the light theme in the muted hint colour (`rgb(100, 116, 139)` on
`rgb(244, 247, 249)`) as they do in dark. Not verified: the Shiny application
(untouched), the hosted deployment (unchanged), and browsers other than Chromium.

Uncommitted (2026-10-16): **loading, in-flight, success, error and
cancellation-adjacent states audited and made consistent across all nine analysis
actions** (frontend only, local review first), on top of the same day's presentation
mode (all nine tabs), the Base-case prototype, the snapshot-metadata follow-up, the
minimal-clutter orientation pass, the main-menu layout and the Download results
centring — all preserved, and nothing about the R models, the API contract, the
calculations, the input defaults, the exports or the analysis execution changed.

What was wrong and what it is now, in one place per state:

- **Duplicates.** The store's `run()` now returns early when that analysis is
  already running, so a second submission cannot start a second identical request
  even if it reaches the handler (a triple click in one tick fired exactly one
  request; a programmatic click on the disabled action fired none). Each panel still
  disables only its own action — the inputs, the ranked-outcome selector, Present and
  the download buttons stay usable while a run waits, which is what makes it possible
  to keep exploring while a long PSA runs.
- **The previous result survives a new run.** Nothing is cleared when a request
  starts: the earlier result stayed on screen with its stale notice through a
  re-run of the one-way analysis (its 14-row table and its chart) and was replaced
  only when R answered.
- **Failure.** A failed request leaves the previous result, one `role="alert"`
  message (R's own detail, or the client's own unreachable-service sentence), the
  action re-enabled and every input as the user left it; the retry then succeeded and
  the message cleared. No automatic retry, no polling, no background run.
- **The five states read differently, in the one element each tab already had.**
  "No result yet" and "request in flight" are the same `<p class="hint" role="status">`
  slot, which now carries the wait sentence while the run goes
  ("Running the budget impact with these inputs.") and the tab's guidance otherwise,
  so the guidance is replaced rather than added to and it disappears the moment the
  result lands. "Result available" is the figures with that line gone; "request
  failed" is the alert above them; "result from earlier settings" is the existing
  stale notice and is still informational, not an error.
- **Loading text is analysis-specific, and honest about what is running.** Each
  pending label names its own analysis, and the PSA's names the run's own iteration
  count, captured when the run starts: editing the iterations field from 100 to 1,000
  while a 100-draw run was in flight left both the button and the in-flight line
  saying 100. The PSA's in-flight line — the one place the old wording claimed "a
  1,000-draw PSA takes minutes" for every run — now reads "Running 100 iterations.
  Keep this tab open until it finishes." for a small run and keeps the minutes warning
  only at or above the size the confirmation dialog warns about.
- **The lighthearted rotation was left where it already existed.** The app-wide
  loader card (`useLoadingMessages`, 7 s rotation, opacity-only crossfade, one static
  message under reduced motion) still turns over during a long analysis run and was
  not copied into the panels or duplicated anywhere; under
  `prefers-reduced-motion: reduce` the ECG dash in the pending button is stilled too
  (`animation: none`), and no transition runs.

Verified before leaving it in the tree: `npm run typecheck`, `npm run lint`,
`npm run build` (`index-BaxIfIJZ.js`) and `git diff --check` all pass. In the browser
(model API on 127.0.0.1:8788, Vite on 127.0.0.1:5173) each of the nine analyses was
started and driven through its states — the placeholder sentence and its
`role="status"`, the in-flight sentence and pending label, the result, and (for the
budget impact) a deliberate 500 to prove the failure path; the slow analyses (PSA at
the documented 100 draws, one-way, value-based price, value of information, HTA
summary) supplied the in-flight samples directly and the fast ones were held with
emulated latency so their in-flight line could be read rather than assumed. A run
navigated away from and back mid-flight still showed its pending state, its disabled
action and its previous result; a triple click fired one request and a click on the
disabled action fired none; the workspace was driven from 0 to 9 of 9 stored and
back to the no-result state using the app's own "Clear all results", with each tab's
placeholder returning exactly as before. At 390 px no state produced page-level
overflow, every pending label stayed on one line (the longest, "Calculating the
value of information…", at 266 px) and the in-flight line was shorter than the
guidance it replaced, so nothing moved. Presentation mode opened on the base case
(€2,439, 17 settings rows) and the value-based price (€155.03, 18 rows) with no
request, focus back on Present and no leftover overlay or `[inert]`; the Download
results view was still absent from the dashboard and still rendered on
`page === 'export'` through its menu action, with the same included/not-yet-run
lists; charts drew as before (one canvas on the base case after open/close, two on
the PSA and the value of information). Not verified: the Shiny application
(untouched), the hosted deployment (unchanged), a 1,000-draw PSA (the wording branch
at or above the confirmation size was read in the code and not run, per the standing
policy on PSA sizes), browsers other than Chromium, and a real screen reader (the
live regions and the alert roles were read from the accessibility tree, not
announced).

Uncommitted (2026-10-16): **presentation mode extended to all nine analysis tabs**
(frontend only, local review first), on top of the same day's Base-case prototype,
minimal-clutter orientation pass, main-menu layout and Download results centring
(all preserved, including the approved Base-case design and its chart-entry
behaviour). A shared presentation shell carries the parts every analysis shows the
same way — the small eQalb identity line and analysis title, the Close control,
the line naming what has moved since the run, the line saying a later run has
replaced this one, the run-settings disclosure and R's own simulated-data notice —
and each panel supplies its own figures, charts and R-owned wording through slots.
One compact "Present" action sits beside each tab's existing result actions, shown
only when that tab has a valid result and absent from the main menu, the tutorial,
the loading states and the empty placeholders. No new dependency, no browser
fullscreen, no slides, auto-advance, comparison or toolbar, and no chart animation
was added or removed: each overlay's charts are ordinary instances of the existing
components in their own containers, and they animate exactly as the workspace
instances do.

What each tab presents, all read from the presented response:

- Base case — the four headline figures, the ICER sentence and the deterministic
  plane (the approved prototype, unchanged).
- Cost-effectiveness and PSA — mean cost, mean QALYs, median ICER and the
  probability cost-effective at the run's own threshold, with the plane and the
  acceptability curve side by side, the excluded-iteration warning and the
  iteration-cloud note.
- Sensitivity analysis — the base outcome in the run's own ranking, base cost, base
  QALYs and base NMB, the tornado, R's narrative for the run and the range count
  with R's bounds note.
- Budget impact — cumulative net impact, intervention and implementation cost and
  healthcare savings, the yearly chart, the deterministic/undiscounted sentence and
  the yearly table, with population, horizon and the settings R reports.
- Simulated survival — patients per arm with the run's seed and follow-up, events
  per arm and the hazard ratio, the curves, number at risk and arm summary, the
  definitions/diagnostics/log-rank lines and R's traffic-light interpretation.
- Value of information — EVPI per patient at the run's threshold, mean cost and
  QALYs, the draws reused, the two visual summaries, the EVPPI table and the
  per-patient, approximation and population-value qualifications.
- DHT readiness — population and active users, R's own status counts (no new
  overall score or ranking), R's interpretation, the domain table with R's statuses
  and the quantitative outputs.
- Value-based price — the supported price with R's status band, the current price
  and headroom, the comparison chart, R's interpretation, the required-effect
  verdict, R's limitation, any warnings and the 3 x 3 scan.
- HTA decision summary — R's overall position and domain count, R's interpretation,
  the domain dashboard, the explicit not-yet-included list, the evidence priorities
  and the traffic-light rules.

Snapshot integrity: each overlay snapshots the response object when it opens, so a
later run cannot change what is shown; the settings it prints come from that
response (its own inputs, thresholds, seeds, draw counts and availability flags), or
— only while the tab's own comparison says the stored run still matches the panel's
controls — from the settings that produced it, and never from an unrun control. When
anything has moved the overlay says so and omits the control-derived rows; when a
later run lands behind an open overlay it says that too, and neither changes the
figures. Opening and closing issues no request, derives no figure and changes no
input, result or export.

Verified before leaving it in the tree: `npm run typecheck`, `npm run lint`,
`npm run build` and `git diff --check` all pass, and every tab was driven in the
browser (model API on 127.0.0.1:8788, Vite on 127.0.0.1:5173). Present is absent on
all nine tabs before their own result exists and present afterwards; each overlay's
figures matched its panel exactly (PSA €2,418 / 0.0078 / €333,633 / 1.0% at
€100,000; budget €15,480,000 over 5 years; readiness 63,750 eligible with the domain
counts; value-based price €155.03 with headroom −€204.97; VOI €0.11 per patient over
100 reused draws); no request was issued while opening or closing any overlay (a
fetch/XHR spy recorded none); each overlay's charts drew in their own containers —
one canvas where the panel has one, two for the PSA and the value of information —
and the workspace instances stayed live afterwards, with five rapid open/close cycles
leaving no extra canvas or ECharts instance; Close, Escape and the backdrop all
closed the overlay, returned the focus to that tab's Present action and left zero
`[inert]`; Escape inside an open disclosure closed that first; a later run landing
behind an open overlay left the presented run on screen (the 5-year budget
€15,480,000 shown while the panel moved to the 8-year €33,216,000) together with the
"a later run has replaced this result" line; changing an assumption after a run added
the "controls have changed" line while the figures stayed the run's; the panel stacks
and scrolls inside itself at 390 px with both charts 275 px wide and no page
overflow; light and dark both render; under `prefers-reduced-motion` the overlay is
present at once with 0 s transitions and no transform; navigating away while open
unmounted cleanly with no `[inert]` left and the menu usable; and the approved
Base-case overlay, the main-menu explanations, the centred Download results page, the
analysis-tab wording and the stored results were all unchanged, with no console or
page error. Not verified: the Shiny application (untouched), the hosted deployment
(unchanged), a real screen-share capture, browsers other than Chromium, and print
rendering of the overlays beyond the global print rules.

**Snapshot-metadata limitations (resolved).** The response is the only per-run record the app
keeps: the base case, PSA, budget impact, survival, value of information,
value-based price and HTA summary all carry their own run metadata, so those
presentations need nothing from the controls. The one-way sensitivity analysis does
not report the scenario it ran, and the readiness assessment does not report its
seven values, so the store keeps the request each of those two runs was sent —
`owsaRun` holds the `OwsaRunRequest` record (threshold, `scenario_*` body and the
range overrides, or `null` when R derived them) and `readinessRun` holds the
readiness request body, both beside their result — and the presentation lists
exactly that, never the controls; the disclosure says so, and the store's staleness
comparison reads the same stored record, so what is shown and what is compared
cannot disagree. Nothing is invented for a run that predates the retained record, and
no settings history, undo or cross-run comparison exists.

Already in the tree from earlier the same day: the minimal-clutter orientation pass
over the browser interface, frontend only, in its revised form. The Home screen's
menu is the two
entry points ("Open analysis workspace", "Guided tutorial") full-width on their
own rows with the two secondary destinations ("Project description", "Download
results") side by side beneath them, the pair and its 8 px gap adding up to the
row above, the whole group capped at a compact width and centred under the
credits, and the two entry points marked only by an accent outline and a soft
accent tint; the two-line filled buttons of the first attempt were removed, along
with the rules that existed only for them. Labels stay on one line down to a
370 px viewport and wrap to a second line (equal heights, no clipping, no
overflow) below that, since the grid's `min-width: 0` lets the columns shrink. Each of the nine analysis tabs opens with a single question
sentence in place of its longer description, and the guidance shown before a
result exists is one line naming that tab's own action, with the value of
information tab stating its genuine PSA prerequisite. The two entry points now
open a small centred explanation of their own instead of navigating at once — the
app's own dialog, with a short title, one sentence, one action ("Open workspace" /
"Start tutorial") and a "Close" control, closable by Escape, the Close control or
the backdrop, navigating only from its action, one overlay at a time, and running
nothing while it opens or closes — while "Project description" and "Download
results" keep their direct navigation. The Download results page is now one
centred group in the app's content area, horizontally and — while it fits —
vertically, with its two result lists left-aligned inside it and natural scrolling
when it is taller than the window. No calculation, input, default, endpoint,
export, tutorial step, animation, landing page, blog, favicon, theme, route or
deployment file was touched, `app.R` is untouched, and nothing was committed,
pushed or deployed.

Verified before leaving it in the tree: `npm run typecheck`, `npm run lint`,
`npm run build` and `git diff --check` all pass, and the running app (model API on
127.0.0.1:8788, Vite on 127.0.0.1:5173) was checked in the browser. The menu
renders as three rows — the two entry points full width and the secondary pair
side by side, with the pair plus its 8 px gap adding up to the row above
(384 = 188 + 188 + 8 at 768 px and wider, 342 = 167 + 167 + 8 at 390 px) — centred
under the credits with the LinkedIn/GitHub line still centred, no clipped label and
no horizontal overflow at 320, 360, 370, 375, 390, 430, 768, 1240 and 1440 px;
every label is one line down to 370 px and the two secondary labels wrap to a
second line (equal heights, still no overflow) at 360 and 320 px; its four
destinations still resolve, and hover and press
were exercised on a hover-capable pointer (the choices fill to the accent on
hover, the secondary pair go accent-soft, the press is scale(0.98) and returns on
release). Both explanations open with the right title, sentence and action; Close,
Escape and the backdrop each return to the unchanged menu with the focus on the
button that opened it; Continue navigates once (nine tabs for the workspace, Part
1 step 1 for the tutorial); six rapid opens leave one overlay and four rapid
Continue clicks still navigate once; Tab and Shift+Tab wrap inside the overlay, a
programmatic focus on the menu behind it is refused, opening and closing issues no
HTTP request, the stored results count is unchanged, and no console or page error
appeared anywhere. Under `prefers-reduced-motion` the overlay appears at once
(0 s transitions) and the press transform is removed rather than stilled. The
Download results page was measured at 390, 820, 1024, 1240 and 1440 px: the group
is centred while it fits (equal auto margins inside the content area), starts at
the top and scrolls when it does not, keeps its padding below 1024 px with the
vertical centring dropped, and shows no horizontal overflow; the title,
introduction and actions are centred with the lists left-aligned — checked with no
analyses run and with two stored — and `#export-title` is absent from the
dashboard and the tutorial in every case. The nine analysis tabs still render the
previous pass's introductions and guidance unchanged. The menu's touch behaviour
was checked as far as this Chromium allows: it would not emulate the `hover` media
feature (CDP reported `(hover: hover)` regardless), so the block's declarations
were applied with the condition stripped, and the choice button kept its resting
accent look while the secondary button stayed neutral — the rule itself and its
order were read back from the served CSSOM, and the touch branch was not exercised
on hardware. Not verified: the Shiny application (untouched), the hosted
deployment (unchanged), and any browser other than Chromium.

Completed and released (2026-10-15): the frontend presentation work — the result
entrance and its ECG trace, the tutorial step transitions, the five interaction-polish
additions, the 24-message loading line, the page-entry fade and the dialog focus
containment — is merged into `main` as `ea192dd` (PR #4) and live at
`https://openhealth.ngo` as release `7-ea192dd5fb193a6ada5ceb88929adebc1d92fef2`.
The paragraphs below record the blog task that preceded it.

Completed: the OpenHealth blog exists as a frontend-only addition at `/blog` and
`/blog/<slug>`, and the landing page's bottom-right footer link is now "Blog".
Frontend only; no R, API, server configuration, model logic, dependency or
deployment file was touched, and nothing was committed. `/blog` is a
reverse-chronological list of the posts (title, date, optional summary, quiet
rules between entries — no cards or thumbnails) and `/blog/<slug>` is one post at
a stable address in a narrow reading column, with a heading, a date, paragraphs,
lists and quotes; an address naming no post shows a readable "Post not found"
state at that address. The blog is laid out in `frontend/src/blog.css`, scoped
under `.blog`, which declares no palette of its own and reads the landing tokens
from `landing.css`, so it is the landing page's earthy light / near-black dark
identity, typography and stored preference rather than the app's teal. Posts are
content in `frontend/src/content/blog/`: one typed module per post plus
`types.ts`, the registry `posts.ts` (a post is published by being listed there; a
file that is not listed is a draft) and a `README.md` documenting the format and
the add / preview / publish workflow. No Markdown renderer was added and no HTML
is rendered, so nothing needs sanitising; the list is empty until a first post is
approved, so the index shows a restrained empty state instead of a placeholder
article. Post addresses are resolved by the existing view store
(`useAppView.ts`), which now also carries the post slug, the `/blog` title and the
`blogPostPath()`/`followPostLink()` helpers — no router and no dependency was
introduced, and `page` gains one value (`'blog'`) that the shell renders as two
named branches. The blog's shell (`components/blog/BlogLayout.vue`) owns the
landing theme for its pages and starts a followed page at the top, leaving a Back
or Forward entry where the browser restores it.

One real defect was found and fixed while verifying, in the shared theme
composable: `useLandingTheme.ts` removed `<html data-landing-theme>` from every
unmounting component, but Vue runs an unmounted hook at the end of the flush —
after the arriving page's setup has already set the attribute — so handing over
between the landing page and the blog stripped the attribute from the page that
had just arrived, leaving either page in the application's palette (the landing
page's `.landing` background fell through to the app's `#101a1f`). The composable
now counts the mounted landing-themed pages and removes the attribute only when
the last of them unmounts; the landing page alone behaves exactly as before, and
the attribute still leaves `/app` when either page unmounts. Also verified: the
"Download results" view still names itself and renders nothing under the
dashboard, light and dark both apply, `/about` still resolves directly, and
`/app` keeps `eqalb.theme` and `<html data-theme>` untouched by any blog choice.

Left for the author: the landing page no longer links to `/about` (the instructed
replacement — `/about` itself is unchanged and still resolves at its address); and
the empty state was verified with temporary posts that were deleted afterwards.
The first post has since been added; see the paragraph below.

Completed after that: one focused navigation correction to the blog. Following
the blog's wordmark — an explicit link to `/` — now navigates to the landing page
and starts it at the top, through a third link handler beside the other two,
`followLandingLink` in `useAppView.ts` (it is the only caller; `BlogLayout.vue`'s
wordmark uses it). The scroll is written in the same turn as the address, exactly
as `followPostLink` writes its own: the landing page is taller than anything the
blog shows, so the position the reader arrives at is already the top and the page
that replaces the blog keeps it — and deferring it past the turn instead let the
browser record the page being left as having been at its top, which cost that
entry its Back position. That was the whole change: two files plus documentation.
Nothing global was added — the store still forces no navigation to the top,
`popstate` still only resolves the page and the slug, and the blog shell's own
reset is unchanged — so browser Back and Forward keep the browser's own
restoration. Verified both directions over repeated runs: with the blog's index
scrolled to 191 of a 411px document and a post scrolled to 120, following the
wordmark landed on `/` with the document at 0 and the landing page's first panel
at the top of the viewport, and Back then returned to the blog index at 191 and to
the post at 120; `/` scrolled to 1200, the footer "Blog" link and Back returned to
`/` at 1208 with its `#about-me` hash intact; and the landing page's section links
(`eQalb`, `OpenHealth`, `About me`, `Back to top`) still scroll and set the hash
as before. One measurement caveat, recorded because the first pass reported it as
a defect: an automated click scrolls its target into view before dispatching it,
so driving the wordmark with the harness's own click appeared to lose the blog's
Back position. Dispatching the click without that scroll-into-view — the state a
real reader is in — showed the position is kept, so nothing about it is a defect
in the page. `/about` and the app were not touched, and no theme, design,
content-format, animation or unrelated work was changed.

Completed after that: the blog's first post, *Release of eQalb & The introduction
of OpenHealth!* (2026-10-14). One new content module,
`frontend/src/content/blog/release-of-eqalb-and-openhealth.ts`, registered in
`posts.ts`; the only other changes were the documentation statements that said the
blog had no posts. The text is the author's own, published exactly as written —
no wording edited, nothing added, and no links invented (the body is nine plain
paragraphs, including the "Till next time!" / "Mahmood" sign-off as its own two).
The slug is derived from the title because none was preferred, and the date the
author gave as 14/10/2026 is written in the format's `YYYY-MM-DD`. The index shows
it newest first with `14 October 2026`, and the post page renders all nine
paragraphs character-for-character against the supplied text (checked by comparing
each rendered paragraph with the expected string, typographic apostrophes
included), with the title, the `<time datetime="2026-10-14">` element, the "← All
posts" link, the correct document title and no summary (none was supplied). No
style, component or application code changed.

Completed: the Download results view no longer renders outside the eQalb page it
belongs to. Frontend only, one file: `frontend/src/App.vue`. The page chain's last
branch was a bare `<DownloadResultsView v-else />`, so it was the fall-through for
every page the five named branches did not match — and `dashboard` matches none of
them. The panel therefore rendered in the dashboard's own document, directly below
the dashboard body, so scrolling down inside any analysis tab reached it, and its
controls sat in the tab order there. The branch is now
`v-else-if="page === 'export'"`: each page names itself, and the download view
exists only on its own page. It is still reached only from Home ("Download
results"), and its Back button and Escape still call `goHome()`. Because changing
`page` is what unmounts a view, entering the dashboard or the tutorial removes the
panel and its controls from the document rather than hiding them, and a history
Back or Forward that resolves `/app` to `home` leaves no download state behind. No
CSS was added: the defect was the rendering boundary, not visibility. No export
code, model call, R file, API file or dependency changed.

Released: committed as `9d3c7e8` on the branch
`fix/download-results-view-visibility`, fast-forwarded into `main` (`f0b82b4` ->
`9d3c7e8`) and deployed by the existing `Deploy frontend` workflow, whose run
[#5 / 38617581685](https://github.com/MoodyAlawi/eQALB-HTA/actions/runs/38617581685)
succeeded on that commit. The live defect was captured on
`https://openhealth.ngo/app` before the release and is absent after it.

Completed: the landing page's scroll fade is now reversible and repeats, instead of
revealing each group once and latching it visible. Frontend only, left uncommitted
on `feature/openhealth-landing`. The alignment, copy, portrait, palette, themes,
favicon, navigation and app-launch transition are unchanged.

`frontend/src/views/OpenHealthHomeView.vue` no longer has a `settled` set or a
`settleTarget()`: nothing latches, so the value written each paint is purely a
function of where the content is, and it fades in and out on every pass in both
directions. `revealProgress()` is replaced by `enterProgress()` and
`exitProgress()` plus `revealFor()`, which keeps two separate ranges so the
fade-out cannot steal reading time from long content:

- **Entry** is read from the wrapper's top edge: transparent at 90% of the
  viewport height, fully opaque at 55%, linear between (previously the single
  range ended at 47.5%).
- **Exit** is read from the wrapper's **bottom** edge: still 1 until only the top
  22% of the screen still holds the group, 0 once that edge reaches the top. This
  is the part that protects legibility - a centre-point or top-edge formula would
  start fading a tall block while the reader was still in it - and a group whose
  bottom edge never gets that high, which is the last section because the document
  ends beneath it, stays at 1 with no blank space added to force a fade.
- Opacity is `min(entry, exit)`, so the two gradual ends meet in a wide
  fully-visible band.

The 16px lift moved to its own `--reveal-lift` property, written from the entry
only: tying it to the opacity would have drifted the content downwards again while
it was leaving. `frontend/src/landing.css` reads
`translateY(calc((1 - var(--reveal-lift, 1)) * 16px))`, so the `var(..., 1)`
fallback is still the visible, untransformed state and nothing depends on a frame
to become readable.

Focus is the one thing that outranks the scroll, and it is painted in the same
turn rather than through a frame: `paintFocusChange()` cancels any pending frame
and repaints, `paintReveal()` treats a group as focused when it matches
`:focus-within` **or** when it contains `document.activeElement`, and `focusout` is
listened for alongside `focusin` so the scroll value comes back the moment focus
leaves. That last part was found by testing rather than assumed: with the
scheduled repaint alone, blurring a contact link left the group at the focused
value because the queued frame had not run, so a one-off event like a focus change
is now painted synchronously.

The landing page's reveal diagnostic is now its own component,
`frontend/src/components/RevealDiagnostic.vue`, reached from the view through a
dynamic import behind `import.meta.env.DEV`. It used to be markup inline in the
view behind a `v-if`; the flags that drove it were compiled away, so it could never
render in production, but the compiled template - every label, heading and column
name as a string - stayed in the bundle, permanently false. Moving it out means a
production build emits no chunk for it at all, so it is now genuinely absent rather
than merely unreachable: the built bundle carries no `Reveal diagnostic`,
`landing-debug`, `debugReveal`, `debugState`, `Wrapper top`, `bottom / vh`,
`Reveal armed` or `Scrolling element`, the CSS shrank by about 1 kB and the JS by
about 1.6 kB, and the build emits only one JS chunk, one CSS file and the portrait.
Its `?debugReveal=1` panel was also brought in line with the reversible fade, since
its old "Latched" column would now be a lie: it reports wrapper top, top/vh,
bottom/vh, Entry, Exit and Opacity, and its hint explains that opacity is the lower
of the two ends and that focus holds a group at 1. The animation itself was not
touched - the diagnostic only ever read from it.

Completed: the browser-tab icon is now the OpenHealth mark. Frontend only, left
uncommitted on `feature/openhealth-landing`.

The source is `frontend/src/assets/onlylogo.png`, identified by inspection as the
only newly added file in that directory (1024 x 1024, `Format32bppArgb`) rather than
either portrait. It has **genuine transparency, not a white background**: 55.45% of
its pixels are fully transparent, 38.51% fully opaque and 6.04% partially so, and
all four corners are `A=0 R=0 G=0 B=0`; its centre is `#D5A77D` and its commonest
opaque tones are `#D0B080`, `#C09870`, `#D8B888`, `#B89068` and `#B87050`, so the
warm sand-and-clay design is its own. The file is unmodified, checked by SHA-256
before and after generation (`A0E3025A...36CFD9`).

`frontend/public/favicon-16x16.png`, `favicon-32x32.png` and `favicon.ico`
(16, 32 and 48 px, 32 bpp) were generated with `System.Drawing` through a compiled
throwaway C# helper - no dependency, no new tooling. The mark's content bounding
box is 889 x 888 px at (66, 67) inside 1024 px, so each icon is cropped to that box
plus a 3% margin (a 943 px square from (38, 39)), leaving the mark filling 94.3% of
the square, and then box-averaged down. The averaging is done with **premultiplied
alpha**: colours and coverage are accumulated as `colour x alpha` and the colour is
divided back out at the end, which is what stops a cut-out's edges taking a dark or
light fringe. A first pass saturated every painted pixel to white by scaling RGB by
255 and then multiplying by 255 a second time; the regenerated files carry the real
palette (89 distinct 5-bit colours at 16 px, 154 at 32 px; clay centre tones
`#AC6D4E` and `#B07150`; brightest fully-visible pixel `#DBC091`/`#DEC399`, the
sand tone rather than white).

`frontend/index.html` replaced its single
`<link rel="icon" type="image/svg+xml" href="/favicon.svg">` with the ICO first
(`sizes="16x16 32x32 48x48"`, the sizes it actually holds rather than `any`, which
would claim a scalable icon it is not) and then the two PNGs by size, and
`frontend/public/favicon.svg` - the stock Vite lightning bolt in `#863bff`, whose
only reference in the whole repository was that one declaration - was deleted so
nothing can take precedence over the mark. `index.html` is the only document the
build produces and `/`, `/app` and `/about` are all resolved from it by
`useAppView.ts`, so the same icon is used on the landing page and in the app. No
web manifest, PWA setup, image plugin or dependency was added, and no
landing-page, app-theme, transition, copy, reveal or R/API/deployment file was
touched.

Completed: diagnosed why the scroll fade is not visible when the author browses,
and added the development-only diagnostic the brief asked for. Frontend only, left
uncommitted on `feature/openhealth-landing`.

**The confirmed cause is the address, not the code.** The reveal is working. The
author was looking at `https://openhealth.ngo`, which serves a bundle built before
the landing page existed, so there is nothing there to fade. The deployed JS and
CSS are `index-DHn5KSsW.js` / `index-DoeXKmoo.css` with the title "OpenHealth —
accessible, practical health learning", and a search of the deployed JavaScript
finds no `--reveal` (0), no `landing__reveal-inner` (0), no `landing--armed` (0)
and no `mahmood-portrait` (0); the local build is `index-Di0v34KJ.js` /
`index-BlmOXbwG.css` and carries 3, 3, 1 and 1 respectively. The deployment
workflow's only automatic trigger is a push to `main` and this work is uncommitted
on `feature/openhealth-landing`, so nothing that has been built here can have
reached the public site. Nothing needed fixing for this; the fix is to review on
the dev server.

Every other candidate in the brief was inspected on the page and ruled out with
evidence rather than assumed: `prefers-reduced-motion: reduce` is `false`;
`document.scrollingElement` is the document element with `overflow: visible`, so
the document scrolls and the listener is on the right target; the wrappers
measured are the ones painted; the reveal is armed (`landing--armed` present) and
the initial state is a truthful `--reveal: 0` / `opacity: 0` on both sections; no
stylesheet rule overrides the animated element's opacity or transform, because the
value is written inline on the element whose computed opacity was read back; and
there is exactly one painted content element per section, so nothing fades behind
a duplicate that stays solid. One genuine prior observation was explained rather
than left open: the author's tab once showed `--reveal: 1` on both sections while
at `scrollY: 0`, which is not a latch firing early but the latch working — both had
been scrolled through earlier in that page visit, and reaching full opacity settles
a section for the rest of the visit by design.

Driving real keyboard input in the author's own browser tab reproduces the effect
they could not see, ~0.11 of opacity per `ArrowDown` with no jumps: OpenHealth at
wrapper top 781px is `--reveal 0`; 745px gives `0.0797`; 705px gives `0.1891`;
665px gives `0.2986`; 623px gives `0.4135`; 584px gives `0.5202`; 542px gives
`0.6351`; 502px gives `0.7445`, with the transform tracking it exactly
(`translateY(12.01px)` at 0.2493, `6.10px` at 0.6187, `0` at 1). About Me behaves
identically, sampled through `0.041`, `0.258`, `0.323`, `0.342`, `0.348`, `0.351`
as the scroll stops approaching its target, so an intermediate value is held rather
than completed. Reaching 1 and scrolling back to the top leaves the section at
`opacity: 1`, `transform: none`, latched `true`, while the panel's geometric
progress column truthfully reads `0` — the visible state and the measured position
are allowed to disagree, and the latch is what the author's earlier session was
showing.

Three screenshots of the author's own tab were taken to judge the fade as an image
rather than only as a number, capturing the OpenHealth content element at
`--reveal 0.2493` (borderline ghosted), `0.6187` (mid) and `1` (solid), and the
About Me content element at `0.3505`; the same element at increasing progress reads
progressively darker. A screencast/video capture was **not** possible with the
tools available, so the fade is evidenced by those stills plus the per-step
readings above, not by a recording.

Reduced motion was verified by driving the real setting in the author's browser
(`page.emulateMedia({ reducedMotion: 'reduce' })`, reload, then reading it back)
rather than by reading the stylesheet: `matchMedia` reports `true`, both reveal
sections compute `opacity: 1` with `transform: none` at the top of the page and
after scrolling to 900, i.e. the value 0 and 0.35 a normal page would paint at,
while the hero is not part of the mechanism at all — `#eqalb` has no
`.landing__reveal-inner` and its "Open the app" button is at opacity 1 from the
first paint.

The `?debugReveal=1` diagnostic is `frontend/src/views/OpenHealthHomeView.vue`
plus the `.landing-debug` rules in `frontend/src/landing.css`. (Both have since
moved: see the newest Current task entry — the panel is now its own
`RevealDiagnostic.vue`, loaded behind a dynamic `import.meta.env.DEV` import, and
its rules moved with it.) It reports the
section in view, the reduced-motion preference, the scrolling element and offset,
the armed state, and a row per section with the wrapper top, that top over the
viewport height, the calculated progress, the latch, and the computed opacity of
the painted element, and it is read inside an `import.meta.env.DEV` guard. It was
confirmed to render with the flag on the dev server (reporting `Scroll offset 0px
of 1720px`, both sections `progress 0` / `opacity 0` / `latched false`), to be
absent without the flag, and to be absent from the production build even with the
flag set — the overlay is not rendered on `vite preview` at `?debugReveal=1`.

Completed: the reveal is now scroll-linked rather than timed, and the OpenHealth
heading is composed as two lines. Frontend only, left unstaged on
`feature/openhealth-landing`.

The timed reveal is gone, not layered over. `frontend/src/views/OpenHealthHomeView.vue`
no longer carries `revealed`/`is-revealed`/`revealObserver` at all: it writes a
`--reveal` number (0 to 1) onto an inner element, computed from the section
wrapper's top edge as a fraction of the viewport height - 0 while that edge is at
or below 90%, 1 once it reaches about 47.5%, linear in between, with a 16px lift -
so the fade is a function of where the content is rather than of elapsed time.
Stopping halfway holds the intermediate opacity; continuing completes it; a
section that reaches full opacity is settled for the rest of the visit and never
fades again on the way back up. Two elements do two jobs: `.landing__reveal` is
the untransformed wrapper the geometry is measured from, `.landing__reveal-inner`
is what is painted, so the animation cannot skew its own measurement. Work is
batched into one `requestAnimationFrame` behind passive `scroll` and `resize`
listeners, both removed with any pending frame on unmount; the position is
measured fresh each paint so a resize or reflow cannot leave it stale; `focusin`
settles a section before a Tab can reach a link inside it; the hero is outside the
mechanism so it and its button are visible from the first paint; and
`landing--armed` plus the `var(--reveal, 1)` fallback mean a browser without the
features, or a setup that throws, simply shows every section.

Scroll snapping was removed rather than worked around: `scroll-snap-type: y
proximity` pulled a small wheel notch back to a panel boundary, so the reader
could not hold a position inside the reveal range at all. The three-panel layout
and normal scrolling are unchanged.

`frontend/src/landing.css` replaces the transition with
`opacity: var(--reveal, 1)` and `translateY(calc((1 - var(--reveal, 1)) * 16px))`,
and gives the OpenHealth heading two block lines
(`.landing__heading-line`) instead of one run left to wrap. It also fixes a
centring bug the new geometry exposed: the heading box carried `max-width: 34rem`
with `margin: 0`, so it sat 48px left of its container's centre and the two
composed lines were offset from the label and paragraphs; `margin: 1.5rem auto 0`
puts the box on the same axis as everything else.

Verified with `npm run typecheck`, `npm run lint` and a production `vite build`
(all clean; the built CSS carries `--reveal`, `landing__heading-line` and the
print block, with no `scroll-snap` and no `700ms` transition left anywhere).
Measured in the browser at a 900px viewport, reading each section's content-top as
a fraction of the viewport against the inner element's computed opacity:

- OpenHealth: transparent above 0.949vh; `0.893vh -> 0.016`, `0.838 -> 0.147`,
  `0.782 -> 0.277`, `0.727 -> 0.408`, `0.671 -> 0.539`, `0.615 -> 0.670`,
  `0.560 -> 0.800`, `0.504 -> 0.931`, and fully opaque from `0.449vh`.
- About Me: the same shape, `0.890vh -> 0.024` through `0.501 -> 0.939`, fully
  opaque from `0.445vh`.

The steps are even (~0.13 per 50px of scroll), so the change is spread across the
range rather than front-loaded. Stopping mid-reveal at scrollY 435 held opacity
`0.238` unchanged when sampled at 0ms, 400ms, 1200ms and 2400ms - it does not
complete on its own - then reached `1` on further scrolling and stayed `1` after
reverse-scrolling 400px and after returning to the top. The heading renders as two
blocks reading "Practical learning." and "Fewer barriers.", each occupying exactly
one visual line at 320, 390, 430, 768, 1024 and 1440px, each centred on its
container to 0px, in the serif face, with `overflowX: 0` at every width and the
About panel still `text-align: start`. Reduced motion leaves both sections at
opacity 1 with no transform at the top and after scrolling, with the hero visible
on load and the button still pointing at `/app`; print media does the same. The
"Open the app" crossing is unchanged and still runs end to end (overlay with its
sheen, `/app` with the light looping, overlay gone, landing unmounted), and a
fresh load logs no error, no console warning and no failed request.

The four access paths the brief names were then driven directly and the opacity
read back, rather than inferred from the code: a real mouse click on the
navigation's "About me" link took both sections from `0.000` to `1.000` as the
page scrolled to 1800; focusing the About panel's contact link - which lives in
content that was at `0.000` a moment earlier - put it at `1.000` with the link
both focused and painted, and it stayed at `1.000` after blurring and scrolling
away, so no link can ever receive invisible focus; a scroll position restored to
1500 (both by scrolling after load and by a reload with the offset applied) gave
About Me its truthful intermediate `0.808`, matching the value the sweep predicts
for that position, rather than being stuck at 0; and loading `/#about-me` directly
landed with the section at the top of the viewport, fully readable, at `1.000`.
**Not claimed:** running the browser's own wheel was not part of the final
measurement - the positions were stepped and read, which is what the reveal is a
function of - and no pixel-level judgement of the fade's feel was made. No R, API,
deployment, app-theme, dependency, copy or transition file was touched, and
nothing was committed, staged, pushed or deployed. All one-off harnesses and their
browser profiles were deleted.

Completed: two frontend-only corrections to the landing page, left unstaged on
`feature/openhealth-landing`. The structure, palette, navigation, portrait, copy,
themes and the "Open the app" crossing are unchanged.

1. The scroll fade-in is now actually visible, which took finding why it was not.
   The reveal observer watched each section's *panel* — a full viewport tall, with
   its content centred inside it — at a 0.15 threshold. Measured on the page, the
   OpenHealth panel crossed that threshold at 129px of scroll while its content did
   not reach the fold until 248px: the whole transition therefore played and
   finished while the content was still off screen, which is why it read as no
   animation at all. It watched the wrong element; the fix is to watch the
   *content*, and to trigger on its leading edge crossing the bottom fifth of the
   viewport (`rootMargin: '0px 0px -18% 0px'`, `threshold: 0`) rather than on a
   ratio of the panel's area. That also makes the trigger independent of section
   height, so it holds at every width and for content taller than the viewport.
   The effect itself was strengthened as asked: `opacity: 0` with
   `translateY(20px)` to `opacity: 1` and `translateY(0)`, over 700ms with
   `cubic-bezier(0.22, 1, 0.36, 1)`, once per section, entries unobserved as they
   fire. Two small robustness additions came with it: content already on screen
   when the page settles is revealed immediately rather than waiting for the
   observer's first callback, and a print rule shows the whole page, since
   "reveal it when it scrolls into view" has no meaning on paper.

2. The OpenHealth section's text is now centre-aligned, not just its block: the
   label, the heading and the paragraphs all centre, matching the hero, while the
   `40rem` measure keeps every line comfortably short. Its copy is untouched. The
   About Me section is deliberately left exactly as it was — centred as a group,
   prose left-aligned — as is the hero.

Verified in the browser at frame resolution rather than by reading the code. A
fresh load produces no page errors and no failed requests (the
`sectionNodes is not defined` message the dev server logged was a hot-reload
artifact of an intermediate edit and does not reproduce). A stepped scroll journey
down the page and back up, sampled every frame inside the page at 60fps, recorded
for both OpenHealth and About Me: the trigger firing with the content **on screen**
(content top 497px and 593px in a 749px viewport, against 129px-of-scroll-early
before the fix), 33 intermediate frames per section, a ~530ms visible fade, an
opacity trace of 0.106 → 0.534 → 0.783 → 0.905 → 0.961 → 0.986 → 0.996, and the
transform interpolating in step (ty=17.88 → 3.70 → 0.52); neither section
replayed after settling, including after returning to the top. A real trusted
mouse-wheel run (CDP `Input.dispatchMouseEvent`) showed the fade mid-flight for
About Me (0.463 → 0.703 → 0.905 → 0.953) before proximity snapping pulled the
small notches back, and an isolated in-page test confirmed the stylesheet
interpolates (13 distinct opacity values over a smooth trace) with the observer
and the wheel out of the picture. Reduced motion, emulated over CDP, leaves all
three sections at opacity 1 with no transform and a 0s transition — including the
two off screen and never revealed — with their text present. Alignment measured
live: the OpenHealth label, heading and first paragraph each have their last line's
centre exactly on the block's centre (delta 0) with `text-align: center`, while
About Me still reports `start` and the hero still reports `center`; the reveal
computes to `0.7s` with `cubic-bezier(0.22, 1, 0.36, 1)`; and there is no
horizontal overflow. Light and dark were both checked visually, with the landing
theme and the app's own `data-theme` independent as before.

`npm run typecheck`, `npm run lint` and a production `vite build` are all clean,
and the built CSS carries the new values (`translateY(20px)`, `.7s`,
`cubic-bezier(.22,1,.36,1)`, `text-align:center`, the print block). **Not
claimed:** the wheel-driven measurement in this headless environment is
unreliable — small wheel notches are undone by the page's own proximity snapping
and the frame loop idles unless something forces a paint, which is why the
journey was stepped and sampled in-page instead — so "obvious during ordinary
mouse-wheel scrolling" is supported by the frame-level recording and the partial
wheel run rather than by a full wheel-driven trace. No R, API, deployment,
app-theme, dependency, copy, navigation or transition file was touched, and
nothing was committed, staged, pushed or deployed. All one-off harnesses and their
browser profiles were deleted.

Completed: three frontend-only refinements to the landing page, left unstaged on
`feature/openhealth-landing`. The structure, palette, navigation, themes,
portrait, copy and "Open the app" crossing are unchanged; what changed is
alignment, the portrait's box and how the entrance is armed.

1. The OpenHealth and About me sections are now centred blocks, so the three
   panels read as one page instead of two left-aligned ones. The hero already
   centred its own text; the OpenHealth column takes a 40rem measure
   (`landing__inner--prose`, matching the measure its own paragraphs already
   used) and the About group a 56rem one, and the page footer shares that same
   measure so its rule lines up with the content it closes. The text inside each
   block stays left-aligned, because a paragraph reads better that way. Nothing
   was added around the content: no card, border, background or container.

2. The portrait's box is gone. Its rule lost the `1px solid
   var(--landing-divider-strong)` border and the 0.8rem radius, leaving no
   border, border-radius, background, outline or shadow, so the cut-out sits
   directly on the landing background in both themes. The file, its import path,
   its intrinsic `width`/`height`, its alt text, its 18rem cap and its layout are
   untouched.

3. The reveal is the same `IntersectionObserver` pattern, made robust rather than
   reworked: 480ms and a 14px lift, once per section, consistent across all
   three. The hidden state is now scoped to a `landing--armed` class on the page
   root, which the view sets only when an `IntersectionObserver` exists to reveal
   a section again, and the observer setup is wrapped so a failure there reveals
   every panel instead of leaving one blank. `prefers-reduced-motion` forces the
   end state (opacity 1, no transform, no transition) rather than shortening the
   animation, so nothing waits on an observer to become readable.

Verified with `npm run typecheck`, `npm run lint` and a production `vite build`
(all clean; the built CSS carries `landing--armed` and `landing__inner--prose`,
and the build is otherwise unchanged at 353.80 kB for the portrait). Measured in
the browser and in same-origin 390 / 768 / 899 / 900 / 1440px viewports: the
OpenHealth block is centred in its panel at every width (gaps 305/305 at 1260px,
395/395 at 1440, 59/59 at 768, 20/20 at 390) and so is the About group
(177/177 at 1260, 267/267 at 1440, 24/24 at 900 and below), with the About's two
columns 320 + 520 at 1440 and 320 + 466 at 900, stacking to a single column below
900; the footer matches the About group's left and right edges at every width;
the portrait measures 0px border, 0px radius, `box-shadow: none`, a transparent
background and `outline-style: none` in both themes (its computed 3px
outline-width is Chrome's unpainted initial value, identical on control elements);
and no viewport showed any horizontal overflow. The entrance was sampled through
a full scroll cycle - `eqalb` revealed at load, `openhealth` as it came into
view, `about-me` as it did, and all three still revealed after scrolling back up
and returning to the top, so it plays once and never replays. `prefers-reduced-
motion` was emulated over CDP (`Emulation.setEmulatedMedia`): all three sections
report opacity 1 with no transform and a 0s transition, including the two that
were off-screen and had never been revealed, with `scroll-behavior: auto`,
`scroll-snap-type: none` and the scroll hint's animation off, and the crossing a
quick fade that reaches `/app` in about 340ms. A second CDP run deleted
`IntersectionObserver` before the page's scripts ran: the page root then carried
no `landing--armed` class and all three sections - two of them off-screen - sat
at opacity 1 with their text present, and the call to action and portrait were
both visible. The "Open the app" crossing was re-timed end to end after the
changes (`/` with the overlay at 120ms, `/app` with the light looping at 1100ms,
overlay gone by 1800ms). **Not claimed:** the portrait was not visually diffed
against the original beyond the alpha and geometry measurements made earlier.
No R, API, deployment, app-theme, dependency, copy or transition file was
touched, and nothing was committed, staged, pushed or deployed.

Completed: the About me portrait shipped as a web-ready derivative, frontend
only, left unstaged on `feature/openhealth-landing`.

The author's original (`frontend/src/assets/mahmood.png`, 1305 x 1206, 962 kB) is
kept in place as the source, and the app now ships
`frontend/src/assets/mahmood-portrait.png`: the same image resized to 640 x 591
(346 kB, a 64% reduction), which is a little over twice the 288px the layout can
display it at. It has to stay a PNG, because the original is a cut-out with a
transparent background - about 60% of its pixels are fully transparent and all
four corners are alpha 0 - which a JPEG would flatten; Windows' image encoders
offer no WebP to convert it to, so 346 kB is the floor reachable without adding
a dependency, and adding one was not warranted for a single image. The resize
(Bicubic, `SourceCopy`, `TileFlipXY` against edge artefacts) preserves the alpha
channel, the cut-out edge and the aspect ratio, and the landing view imports the
derivative with the matching `width="640" height="591"` attributes. Nothing else
about the section changed: the alt text, the narrow-column placement, the
side-by-side desktop and stacked-below-900px behaviour, the copy and the reveal
animation are all as they were. (The border that the portrait then carried has
since been removed - see the refinement entry below.)

Verified with `npm run typecheck`, `npm run lint` and a production `vite build`
(all clean; the bundle now carries `dist/assets/mahmood-portrait-BCiKK700.png`
at 353.80 kB instead of the 985.19 kB original, which is no longer emitted at
all), and in the browser: the image resolves to the derivative and decodes at
natural 640 x 591, rendering 288 x 266 at ratio 1.082 (the original's 1.0821), so
the layout is unchanged; a canvas readback of the served file reports the four
corners at alpha 0 and the centre at alpha 253, confirming the cut-out survived;
the shipped file measures 99.97% transparent-background character in the same
proportion as the source (59.6% fully transparent before, 59.8% after); and
measured in same-origin 390, 899, 900 and 1440px viewports the image is above the
text below 900 and beside it at 900 and 1440 (320px column against 466px and
840px text columns), with no horizontal overflow at any width. Both themes were
re-checked (light `1px rgba(39, 35, 31, 0.26)`, dark `1px rgba(236, 231, 223, 0.24)`,
no shadow, 12.8px radius) and the "Open the app" crossing and the panel reveal
were confirmed unaffected.

No R, API, deployment, app-theme or dependency file was touched, and nothing was
committed, staged, pushed or deployed.

Completed: the About me portrait, frontend only, left unstaged on
`feature/openhealth-landing`.

The author's own file is used as supplied (`frontend/src/assets/mahmood.png`,
1305 x 1206, 962 kB). It is imported by the landing view rather than referenced
from `public/`, so the build fingerprints it and a missing file fails the build
instead of 404ing at runtime, and it is emitted as its own asset file (985 kB in
`dist/assets/`) rather than being inlined into the JavaScript bundle. The markup
is a plain `<img class="landing__portrait" alt="Portrait of Mahmood Alawi">`
carrying the intrinsic `width="1305"`/`height="1206"`, plus `loading="lazy"` and
`decoding="async"`; the intrinsic pair is what reserves the box, so the box is the
right size from the markup alone and neither the name above it nor the prose
beside it can move as the file arrives. Its rule is in `frontend/src/landing.css`
and follows the page's existing restraint: a hairline `--landing-divider-strong`
border, a 0.8rem radius, no shadow and no frame, `width: 100%` capped at 18rem so
it fills the narrow column without becoming a banner. It sits in the About panel's
first column under the name, so it is beside the prose on desktop and stacks above
it below 900px, and the About copy and the panel's reveal animation are unchanged.

Verified with `npm run typecheck`, `npm run lint` and a production `vite build`
(all clean; the build emits `dist/assets/mahmood-a5TepQJk.png`), and in the
browser: the element renders with the exact alt text and the source resolves to
the PNG; the rendered box is 288 x 266 from the attributes alone while
`naturalWidth` is still 0, then 288 x 266 again once loaded at natural 1305 x
1206, so the aspect ratio is preserved and there is no layout shift; at 1260px the
image sits inside the first column (right edge 312 against the text column's left
edge 400) and overlaps it vertically, so it is beside the text; measured in
same-origin 390 x 844, 768 x 900 and 1440 x 900 viewports the image is above the
text (image bottom at or before the text top) below 900 and beside it at 1440
(320px column against an 840px text column), with no horizontal overflow in the
page, the About grid, the contacts, the footer or the navigation at any of the
three widths; and at the 899/900px boundary the layout switches exactly as
specified (899px one 841px column with the image above the text, 900px 320 + 466
side by side, still no overflow). Both themes were checked - the border reads
`1px rgba(39, 35, 31, 0.26)` in light and `1px rgba(236, 231, 223, 0.24)` in dark,
with no shadow in either - and the "Open the app" crossing was re-checked after
the edit (the app is reached at 820ms with the light looping and the overlay gone
by ~1.2s), together with the About panel's reveal still firing.

`prefers-reduced-motion` was then verified at the browser level rather than by
inspection: a one-off harness drove the Playwright-cached Chromium over CDP with
`Emulation.setEmulatedMedia` set to `prefers-reduced-motion: reduce` (the browser
tooling in this environment cannot set it), and the page reported the setting as
active and behaved as specified - `scroll-behavior: auto` and `scroll-snap-type:
none`, every panel at `opacity: 1` with `transform: none` and a `0s` transition
duration, the scroll hint's animation `none`, the crossing's light
`display: none` and the logo wipe `animation: none` with no clip path, the app
reached by 360ms with no overlay left, and the app itself unaffected
(`data-landing-theme` absent, `data-theme` still `dark`, teal `--accent` intact).
The harness and its temporary browser profile were deleted afterwards.

No R, API, deployment, app-theme or dependency file was touched, and nothing was
committed, staged, pushed or deployed.

Completed: six frontend-only refinements to the landing page, left unstaged on
`feature/openhealth-landing`.

1. "Open the app" now plays a crossing into the app instead of swapping the page
   outright. The landing page fades, an overlay in the app's own palette wipes in
   a still copy of the Home screen's eQalb composition (the same `home__*`
   classes, so the two are one design) behind a band of light, the light falls
   into its looping state, and the overlay dissolves as the app's existing
   `home-rise` entrance fades the interface in — no second, competing entrance
   animation. The sequence lives in `frontend/src/composables/useAppLaunch.ts`
   (reveal at 820ms, dissolve by ~1.18s, one safety clear at 2.4s) and the look in
   the new section of `frontend/src/styles.css`; `frontend/src/components/LaunchTransition.vue`
   renders it. Both fades are CSS animations rather than Vue `<Transition>`
   classes, which a first attempt used and which left the overlay stuck at
   opacity 0 whenever the browser stalled its animation frames; a CSS animation is
   timed by the document's clock, so a late frame shows the crossing further
   along instead of not at all. The overlay is decoration: `aria-hidden`, nothing
   focusable, `pointer-events: none`, and the app is mounted and interactive from
   the moment the sequence hands over, so an interrupted, failed or skipped
   animation can never block the app. Modified and middle clicks still open the
   real `/app` link in a new tab, and reduced motion drops the sweep and the wipe
   for a quick fade (app reached at ~300ms). 2. The hero's simulated-data note is
   removed from the landing page only. 3. The OpenHealth copy is replaced with the
   supplied three paragraphs, and 4. the About me copy with the supplied two
   paragraphs ("a health economics graduate" replaces "a health economist"), both
   verbatim and both keeping the section's plain paragraph layout. 6. The
   per-panel entrance reveal is kept and refined: 480ms and a 14px lift, threshold
   0.15, once per panel, unobserved after it fires, and dropped under reduced
   motion.

Verified with `npm run typecheck`, `npm run lint` and a production `vite build`
(all clean; the built CSS carries every new rule, 6 `prefers-reduced-motion`
blocks, and no `landing__note`), and in the browser: the crossing sampled at
60/600/900/1150/1800/2600ms (veil opaque with `launch-veil-in`, landing faded to 0,
the logo wipe progressing behind the light, `/app` reached at 820ms with the light
in `launch-sheen-loop`, the Home screen's hero at opacity 0 and then 1 as the
overlay dissolved, overlay gone and the app interactive afterwards); a Ctrl-click
leaving the link to the browser with no overlay; the reduced-motion branch landing
on `/app` by 300ms with no sweep; panel 1 revealed by the observer at load and the
About panel revealed on scroll, with the nav's `aria-current` following; light
(theme switched: page #F4F0E8, title #27231F, clay #8C503B) and dark (#090909,
#ECE7DF, terracotta #D39477) palettes; and 390 / 768 / 1440px layouts with no
horizontal overflow in the page, the About grid, the contact list, the footer or
the navigation, and one viewport per panel. **Not verified:** the portrait image
of item 5 — no image file exists in the repository, so the section stands
without one and the author is asked to supply the file rather than use a
placeholder — and OS-level reduced-motion emulation, which this environment
cannot perform. Nothing was committed, staged, pushed or deployed.

Completed: the frontend-only redesign of the OpenHealth landing page, left
unstaged on `feature/openhealth-landing`.

The mission-heavy landing page is replaced by one scrolling page in three panels,
with eQalb first. The hero carries the large `eQalb` title, the single line "An
interactive introduction to health-economic modelling.", the one action "Open the
app" pointing at the existing `/app` address, a one-line simulated-data note and a
discreet scroll link to the next panel; section 2 introduces OpenHealth as a
personal project with eQalb as its first step; section 3 is About me - Mahmood
Alawi, one paragraph and the Email, GitHub and LinkedIn details already used
elsewhere in the project - with the page's footer inside that last panel, so the
page ends at the panel boundary and each section stays one screen. A compact
floating navigation panel holds a quiet OpenHealth wordmark, the three section
links and the landing page's own light/dark control: the links smooth-scroll,
an `IntersectionObserver` marks the visible panel with `aria-current`, and the
wordmark is hidden below 700px so the panel stays compact. Section 3 carries the
author's portrait in the narrow column under the name, so it sits beside the prose
on desktop and stacks above it below 900px; the shipped file is a 640 x 591 PNG
(`frontend/src/assets/mahmood-portrait.png`, 346 kB) derived from the author's
original (`frontend/src/assets/mahmood.png`, 1305 x 1206, 962 kB), which is kept
beside it unused as the source of any future re-export.

The landing page is deliberately separate from the app's identity. Its palette
(warm ivory and clay in light mode, near-black and terracotta in dark mode), serif
headings, spacing and motion live in the new `frontend/src/landing.css`, every rule
scoped under `.landing` or `html[data-landing-theme]`, and its theme lives in
`frontend/src/composables/useLandingTheme.ts` under its own key
(`openhealth.landing.theme`). That attribute is set while the page is mounted and
removed when it unmounts, and `index.html` sets it before the first paint for the
landing addresses only, so `eqalb.theme` / `<html data-theme>` and the app's teal
theme are neither read nor written by the landing page. The replaced page's styles
(the `.oh*` block) were removed from `frontend/src/styles.css`, which gains
`.app--landing`; `App.vue` adds that class for the landing page; and fonts are
local stacks, so no dependency and no external font request were added.

Verified with `npm run typecheck`, `npm run lint` and a production `vite build`
(all clean), and in a browser against the running dev server: the three panels and
the floating navigation, nav clicks scrolling to their section and moving
`aria-current` (a scroll to the OpenHealth panel measured `scrollY` equal to the
panel's offset, with the active link following it), the entrance reveal firing
once per panel, the landing theme toggling from #090909 to #F4F0E8 while
`eqalb.theme`, `<html data-theme>` and the app's own colours stayed put and
`data-landing-theme` was absent on `/app`, a direct load of `/#about-me` starting
in place, "Open the app" reaching `/app`, `/about` rendering unchanged, and
390 x 844, 768 and 1440 px layouts each with no horizontal overflow (snapping off
and the wordmark hidden at 390 px, one viewport per panel at every width). No R,
API, deployment, lockfile or generated file was touched, and nothing was committed,
pushed or deployed.

Completed: the SCP upload-command fix for the first failed workflow run. The
first automated run reached the deploy job - SSH public-key authentication and
pinned host-key verification succeeded - and failed at "Upload the bundle to the
incoming directory" with "lost connection", before activation, so no release was
published and the live site kept serving `initial-20261013`. Cause: the step
uploaded the archive and its checksum in one multi-file `scp` call, and a
multi-file request makes the client send the legacy `-d` flag
(`scp -d -t /opt/eqalb/frontend/incoming` in a verbose local reproduction), while
the server's forced-command wrapper allowlists exactly
`scp -t /opt/eqalb/frontend/incoming` and refused it (exit 64). Fix: "Upload the
bundle to the incoming directory" now makes two separate single-file legacy SCP
invocations - one for `bundle/frontend-<release-id>.tar.gz`, one for its
`.sha256` - each keeping `scp -O`, the explicit `-P "${DEPLOY_SSH_PORT:-22}"`,
the deploy key, `IdentitiesOnly=yes`, `BatchMode=yes` and
`StrictHostKeyChecking=yes`, with the same
`${DEPLOY_SSH_USER}@${DEPLOY_SSH_HOST}:${REMOTE_INCOMING}` destination, and the
step keeps `set -euo pipefail` so a failed upload still prevents activation. No
wrapper, activation-script, permission, secret, approval-gate or rollback change.
A successful end-to-end automated deployment remains outstanding: the corrected
upload is not yet proven by a passing run.

Completed: the one-time server migration and CI key rotation, operator-performed
on the VPS; the only repository change that followed is documentation plus the
tracked `deploy/Caddyfile` root line, now set to match the live configuration.
Caddy runs as user and group `caddy`; `/opt/eqalb` remains `750 eqalb:eqalb` and
was not widened; `/opt/eqalb/public` exists at mode `0755`, owned by
`eqalb-deploy:eqalb-deploy`; the per-user ACLs are `eqalb-deploy` `--x` on
`/opt/eqalb` and `/opt/eqalb/frontend`, `caddy` `--x` on those same two paths,
and `caddy` `r-x` on `/opt/eqalb/public` and `/opt/eqalb/frontend/releases`,
with no write access for Caddy anywhere; `/opt/eqalb/public/dist` is an
`eqalb-deploy`-owned symlink to
`/opt/eqalb/frontend/releases/initial-20261013`; `/etc/caddy/Caddyfile` uses
`root * /opt/eqalb/public/dist`; Caddy was validated and reloaded and
`systemctl is-active caddy` reports `active`; and public verification returned
HTTP 200 at `https://openhealth.ngo/` and `"status":"ok"` with
`"model_ready":true` at `https://openhealth.ngo/api/health`. The
`initial-20261013` release is still the active one. The CI key rotation is
complete: a new passphrase-free CI-only Ed25519 key was created locally, its
public half installed in `/home/eqalb-deploy/.ssh/authorized_keys` behind the
same `restrict,command="/opt/eqalb/bin/eqalb-frontend-deploy-wrapper"`
restriction, tested for the legacy `scp -O` upload path and for refusal of
arbitrary commands, the new private half stored as the `production` environment
secret `DEPLOY_SSH_KEY`, and the old `eqalb GitHub Actions frontend deploy`
authorized-keys entry removed so only the new `eqalb frontend CI deploy` key
remains. Still outstanding: the `production` environment's
required-reviewer/approval rule must be confirmed with the operator, and a
successful end-to-end automated workflow run - the first attempt reached the
upload step and failed there, and the corrected upload is not yet proven - has
not happened.

Completed: the approved corrective pass on the same automation, left unstaged.
The deployment's only mutable path moved from `/opt/eqalb/frontend/dist` to the
deploy-owned `/opt/eqalb/public/dist` so the deploy account never needs write
access to `/opt/eqalb/frontend` or the source checkout: the script's constant,
its refusal of a non-symlink at that path and its lock file
(`/opt/eqalb/public/.deploy.lock`) follow the new topology while the release tree
and the incoming directory keep their fixed paths and all validation, staging,
immutability and output behaviour is unchanged. `deploy/FRONTEND_DEPLOY.md` now
carries the ordered one-time server migration - create `/opt/eqalb/public`, grant
`eqalb-deploy` and the Caddy service account narrow per-user ACL traverse (and,
for Caddy, read) access while `/opt/eqalb` keeps its existing `750` `eqalb:eqalb`
mode, point the pointer atomically at the currently live release, move Caddy's
static root to it, validate and reload, verify `/`, `/app`, `/about` and
`/api/health`, prove the deploy account can move the pointer but cannot write the
checkout, and roll the Caddy root back if the migration fails - plus the
passphrase-free CI-only Ed25519 key decision with its no-lockout rotation
procedure, and the canonical `DEPLOY_KNOWN_HOSTS` naming with the redundant
`DEPLOY_SSH_KNOWN_HOSTS` recorded only as a secret to delete manually after a
successful deployment.
`deploy/DEPLOY.md` §7 states the one-time Caddy root move as the single adoption
step, and the workflow's header comment names the new public pointer. At the time
of that pass nothing in the corrected topology had been deployed on the VPS; the
migration and key rotation recorded at the top of this section have since been
performed and verified (2026-10-14), and the tracked `deploy/Caddyfile` root line
was updated to `/opt/eqalb/public/dist` to match the live configuration. The
GitHub `production` environment and its six secrets are configured; the first
automated workflow run remains outstanding.

Completed: the deliberately small Version 1 frontend-only deployment automation,
left unstaged for review. It deploys a completed Vue/Vite static bundle and
nothing else - no R, renv or Python/API change, no systemd, Caddy or environment
file, no DNS, no git operation on the VPS, and no API restart.

- `.github/workflows/deploy-frontend.yml` (new): builds only on pushes to `main`
  that touch `frontend/**`, `deploy/**` or the workflow itself, on Node 22, with
  `npm ci --ignore-scripts`, `npm run typecheck`, `npm run lint` and
  `npm run build`; rejects a bundle containing any `.map` file; packages
  `frontend-<run-number>-<commit-sha>.tar.gz` with a SHA-256 checksum that is
  verified before upload; uploads both files to the fixed incoming directory with
  `scp -O`; invokes only the fixed remote command `activate <release-id>
  <archive> <checksum>`; validates the public `/`, `/app` and `/about` pages
  (HTTP 200 and a content-hashed asset from the new bundle) plus read-only
  `/api/health`; and, if any check fails, invokes the fixed `rollback` command
  with the previous release id the server reported, then fails the run. The
  deploy and rollback jobs sit behind the `production` GitHub Environment, a
  single concurrency group allows one deploy at a time and never cancels a
  running one, `permissions` is `contents: read`, every action is pinned to a
  full commit SHA, and the six environment secrets (`DEPLOY_SSH_HOST`,
  `DEPLOY_SSH_PORT`, `DEPLOY_SSH_USER`, `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS`,
  `DEPLOY_PUBLIC_BASE_URL`) are documented and configured in that environment
  (required reviewers to be confirmed with the operator). `workflow_dispatch`
  exists only for a manual rollback and takes one optional input,
  `rollback_release_id`, which only reaches the script's validated rollback mode.
- `deploy/frontend-deploy.sh` (new): root-owned when installed, exactly two
  operations. `activate` requires the caller's release id to match
  `[A-Za-z0-9][A-Za-z0-9._-]{0,63}`, requires the archive and checksum to be the
  exact derived paths under `/opt/eqalb/frontend/incoming/`, verifies the
  SHA-256, refuses absolute or parent-relative archive entries and archives
  containing symbolic links, extracts into a staging directory under
  `/opt/eqalb/frontend/releases/`, requires `index.html`, removes every
  group/world write bit, renames the staging directory into place and replaces
  the only mutable path, the Caddy-served `/opt/eqalb/public/dist` symlink, in
  one rename; the previous release is retained and reported as
  `PREVIOUS_RELEASE_ID`. `rollback` re-validates the id and the release's
  `index.html` and repoints the same public pointer in one rename. The script
  uses `set -euo pipefail`, `umask 022`, `flock` on
  `/opt/eqalb/public/.deploy.lock`, a staging directory and a cleanup trap, and
  contains no shell evaluation, wildcard deletion, download, package install,
  git, sudo, systemd, Caddy or API command. The frontend checkout is never
  written by it: per the approved topology, `eqalb-deploy` owns only
  `/opt/eqalb/public`, the release tree and the incoming directory.
- `deploy/FRONTEND_DEPLOY.md` (new): the manual bootstrap (dedicated
  `eqalb-deploy` account, fixed directories and modes, installation of the
  root-owned script and of a root-owned forced-command wrapper that accepts only
  `activate`, `rollback` and the exact `scp -t <incoming dir>` upload, a
  dedicated passphrase-free CI-only Ed25519 key in a `restrict,command=...`
  `authorized_keys` entry with its safe rotation procedure, the six environment
  secrets, required reviewers), the one-time migration of an existing hand-built
  `dist` directory into the first release (§4.6), the one-time manual Caddy
  migration of the static root to `/opt/eqalb/public/dist` with its own rollback
  (§4.7), the normal deploy sequence, automatic rollback on a failed validation,
  the one-command manual rollback, re-run clean-up, retention, and the unverified
  status.
- `deploy/Caddyfile` (updated): `try_files {path} /index.html` is now active and
  the stale no-router/deep-link commentary is corrected; the API proxy,
  certificate handling, logging, compression, headers and TLS settings are
  unchanged, and the `root` line deliberately still names the current path until
  the §4.7 migration is performed and accepted.
- `deploy/DEPLOY.md` (updated): a new §7 explains the automation, states that
  §1-§6 remain the install path for everything non-frontend, names the one-time
  Caddy root move as the single migration the adoption needs, and warns that once
  the live build sits behind a symlink the in-place `npm run build` of §3.4 must
  not be used.
- `frontend/vite.config.ts` (updated): the production build sets
  `sourcemap: false`, so no `.map` files are published.
- `frontend/README.md` (updated): a short "Deployment" section points at the
  workflow and the runbook and records the same unverified status.

Validation, all repository-local: `bash -n deploy/frontend-deploy.sh` clean; the
workflow YAML parsed and passed 44 structural checks (triggers, concurrency,
permissions, pinned SHAs, the four build commands, the no-`.map` guard,
checksum verification before upload, the environment gate, the fixed
`activate`/`rollback` commands, the four URL checks, the six secret names) and
all 18 `run:` blocks passed `bash -n`; `npm ci --ignore-scripts`,
`npm run typecheck`, `npm run lint` and `npm run build` all pass and the built
`dist` contains no `.map` file; the script's behavioural suite (sandboxed copy,
`flock` stub and junction-backed `ln` shim because this Windows checkout has
neither) passed 46 of 46 checks before the corrective pass and 50 of 50 after it,
covering the public pointer, the missing public directory and the
real-directory-at-the-pointer refusal; `git diff --check` clean. Nothing was
committed, staged, pushed, deployed or run against GitHub, the VPS or any other
remote service.

Completed: the OpenHealth public shell around the eQalb frontend, frontend only,
left unstaged on `feature/openhealth-landing`.

Three public addresses are served from the existing dependency-free view store
(`frontend/src/composables/useAppView.ts`), which now resolves the pathname on
load, writes one History API entry per public move, follows Back/Forward through
`popstate` and keeps the document title with the page. `/` is the new OpenHealth
landing page (`frontend/src/views/OpenHealthHomeView.vue`), `/about` is the new
About OpenHealth page (`frontend/src/views/AboutView.vue`), and `/app` is the whole
existing eQalb application: its own Home screen, the tutorial, the project
description, the download view and the dashboard all keep their present behaviour
on that one address, so no internal eQalb screen has a deep link of its own. An
unrecognised path opens the landing page and is rewritten to `/`. `App.vue` renders
the two new views in front of its existing branches; the dashboard, the tutorial,
the API client, the R model, the model-startup timing, the ECharts `v-if` handling
and the once-per-session welcome question are untouched, and no router or new
dependency was added.

The landing page and About page reuse the existing tokens, typography, button
patterns, light/dark behaviour and standalone-view conventions (labelled regions,
a focusable H1 focused on arrival, Escape from About back to the landing page).
Both state plainly that eQalb is illustrative and educational and that OpenHealth
is an early-stage, education-first initiative with one tool released, and they use
the LinkedIn and GitHub addresses already present in the interface.

Verified with `npm run typecheck` and `npm run lint` (both clean), a production
`vite build` into a temporary output directory (the tracked, generated `dist/` was
deliberately left untouched), and browser checks against a local dev server:
direct loads and reloads of `/`, `/app` and `/about`, Back/Forward across them,
an unknown path, `/app/` with a trailing slash, the landing's Explore eQalb and
Our mission links, Escape from About, light and dark themes, a 390 px viewport with
no horizontal overflow, and the eQalb flow (Home, dashboard with the base case
returning R's own numbers, tutorial, project description, download view) with no
console error of its own. No model, API, deployment, lockfile or generated output
was touched.

Committed on this branch as `f3acd2a`; not merged into `main` and not deployed.

Completed: the frontend interaction-polish pass, presentation only and left
unstaged. Five approved additions, plus the lighthearted loading messages:

- **Sliding active-tab indicator** (`composables/useTabUnderline.ts`, `.tabs__indicator`
  in `styles.css`, `App.vue`). It is one absolutely positioned 3 px bar, placed from
  the selected tab's own box by a post-flush watch, so its width is the label's
  width including the selected weight. It animates for 190 ms only between two
  tabs on the same row and only when the distance is a real move; a wrap, a resize,
  a font change or the first placement jumps into place instead of sliding, and the
  measurement is deferred by one frame, so nothing is ever drawn in the wrong place.
  A `ResizeObserver` and `document.fonts.ready` re-place it without animation. It is
  `aria-hidden` and `pointer-events: none`; the tab semantics, roving tabindex and
  keyboard selection are untouched, and the destination panel renders in the same
  tick as the click.
- **Smooth disclosures** (`styles.css`). Native `<details>` is kept, and the
  expansion is animated only inside `@supports selector(::details-content)`, using
  `interpolate-size: allow-keywords` with `block-size: 0 → auto` and
  `transition-behavior: allow-discrete`, so the height is the content's real height
  — no guessed maximum, nothing clipped, and `content-visibility: hidden` lands on
  the collapsed end state, which is what takes the contents out of layout, the tab
  order and the accessibility tree. The chevron is the existing marker, now a
  `summary::after` that rotates 150 ms (the native marker is hidden). Where the
  engine lacks either feature the disclosure opens and closes exactly as before.
- **Analysis-button pending states** (`components/ButtonLabel.vue`, all nine run
  buttons). Idle and pending labels are two spans in one grid cell, so the button's
  box and its accessible name are exactly one label at a time — the inactive label is
  `visibility: hidden`, which also keeps it out of the accessibility tree (verified
  with accessibility snapshots: `Run PSA` → `Running 100 iterations…` [disabled] →
  `Run PSA`). The pending label carries the app's ECG at small size, `aria-hidden`,
  one dash-drawn pass. The buttons disable from the store's own `busy` flag, which
  prevents duplicate submissions, and the label restores on success, failure and
  cancellation.
- **Quiet download feedback** (`composables/useDownloadNotice.ts`,
  `components/DownloadNotice.vue`). One corner card, `role="status"` for a prepared
  download and `role="alert"` for a failure, with a fade and 4 px of movement, a
  Dismiss button that never takes focus, and an auto-dismiss of 7 s that applies only
  to successes — a failure waits to be dismissed. Wording is honest: "Download
  prepared." plus the filename is a claim about the hand-off, never that a file was
  saved; a failure keeps the underlying reason. `DownloadResultsView` keeps its own
  in-page line ("Results package prepared: … , with N files." / "The results package
  could not be prepared in this browser: …"), so no action is reported twice.
- **Dialog transitions** (`composables/useDialogTransition.ts`, the welcome, PSA
  confirm, case facts and congratulation dialogs). The backdrop fades and the panel
  moves 4 px while fading, over 190 ms; the leaving dialog is marked `inert` and its
  backdrop gets `pointer-events: none`, so an outgoing dialog cannot keep the focus
  or block the page.
- **Dialog focus containment** (`composables/useModalFocus.ts`, the same four
  dialogs). The keyboard half of `role="dialog"` + `aria-modal="true"`: on open the
  focus moves to the dialog's own first action (`Continue`, the facts close button,
  the congratulation's "Open analysis", "Start tutorial" for the welcome question),
  Tab and Shift+Tab wrap inside the dialog (a dialog with no control keeps the focus
  on its own panel), and every element outside it is `inert` while it is up, so the
  page behind it takes no click, no key press and no focus. The background is
  inerted through the dialog's *relatives* — each ancestor's other children, from the
  dialog up to the body — so an ancestor of the dialog is never switched off and the
  dialog can never inert itself; each element remembers whether it was already inert
  and is left exactly as it was found, so a dialog that closes, unmounts or has its
  page taken away underneath it cannot leave the app inert. On close the focus goes
  back to whatever opened it; the welcome question's fallback is the selected
  analysis tab, because it is asked on arrival rather than opened from a button; and
  an opener that is present but unusable — the PSA run button that `Continue` has
  just disabled — leaves the focus where the dialog left it instead of sending it to
  a control that cannot take it. Nothing is restored into a page that has been left,
  which is a page whose controls went with it. A dialog whose leave was cancelled by
  a quick reopen clears its own `inert` on the way back in, so the reopened dialog is
  never left switched off.
- **Loading messages** (`composables/useLoadingMessages.ts`). The approved
  sentences — 24 of them (the original six plus eighteen more), in one list — shown
  as a second line under the factual status once the wait has outlived a 1 s grace,
  changing every 7 s from a shuffled cycle that shows every message before any
  repeats and never repeats the message just shown. Each change is a crossfade
  rather than a swap: the composable hands the component the message on screen and,
  for the length of the swap, the one it is replacing, and the two fade over each
  other — opacity only, the outgoing over 150 ms and the incoming over the same
  150 ms after a 130 ms delay (280 ms in all, `FADE_MS`). Every message is rendered
  in the same grid cell, so the line's area is as tall as the longest of them at the
  current width and neither the first message arriving nor a change of message can
  resize the card, which keeps one height from its first frame to its last. The
  factual label is the live region; the message block is decorative, `aria-hidden`,
  with nothing focusable in it, so nothing changing is announced. Timers are cleared
  when the wait starts, when it ends and on unmount; a request that finishes inside
  the grace shows nothing at all; and a completion removes the card in the frame it
  lands in, mid-crossfade or not. Applies where the wait is real (the loading card,
  which appears after 2.5 s) and not to the buttons, so one operation has one
  secondary line. Under reduced motion one message is shown still and nothing
  rotates — including when the preference is turned on during a wait, which stops
  the rotation and drops the crossfade in flight, and turning it off again resumes
  the rotation.

Also fixed, found while verifying this pass: the global `prefers-reduced-motion`
rule is `* { transition: none; animation: none }`, and `*` is elements only, so the
two pseudo-elements this pass added — the disclosure's chevron and the animated
`::details-content` box — were still animating. Both are now stilled under reduced
motion (the chevron by an added rule beside the `*` rule, the content box inside its
`@supports` block), verified by measuring a disclosure that opened in one step at its
natural height instead of growing.

Verified: `npm run typecheck`, `npm run lint` and `npm run build` all pass; browser
checks against the running dev server — the indicator's placement, move, jump on
wrap, resize and 390 px behaviour, and the panel arriving before the indicator moves;
disclosures opening, collapsing and staying unclipped, with the collapsed contents
out of the tab order; button labels, dimensions and accessibility names across idle,
pending, success, failure and cancellation, including a real pointer click on a
pending button starting no second request; the download notice's life cycle, its
failure path (a forced blob failure) and the package view's own status; the four
dialogs' enter, leave, rapid open/close/reopen, Escape, `inert` and post-close
usability, and then, after the containment fix, all four dialogs' keyboard
behaviour: the focus arriving on the dialog's own first action, Tab and Shift+Tab
wrapping at both ends, the background header, tab strip, assumptions panel and
tutorial controls refusing the focus while a dialog is up (and a real pointer click
over a background control reaching only the backdrop), every close path — Confirm,
Cancel, Close, Escape, the backdrop — returning the focus to the opener or to the
welcome question's tab fallback, a disabled opener leaving it alone instead, a Back
navigation while a dialog is open unmounting the page and leaving no `inert` behind,
the same dialog usable again after a reopen inside its own leave fade, and the whole
set repeating correctly under reduced motion (where the dialog element is removed
24 ms after closing rather than waiting on a fade it does not have); the loading messages' grace, a change every 7 s over four changes in one
controlled 40 s wait, no consecutive repeat, `aria-hidden`, a completion landing
mid-crossfade removing the card in the same frame, one rotation interval per wait
created and cleared, and the single static message under reduced motion — including
a preference turned on and off during a wait; the approved result trace (still
224 × 19.2 px, one element even when a run lands mid-animation, replayed per
successful run, not on theme or tab changes) and
the approved tutorial transitions (leave 180 ms, enter 220 ms, opposite directions,
one step in the document at a time, arriving heading focused, rapid Next landing on
the last requested step, inputs and results kept across Back and Forward, immediate
under reduced motion). Two limits to that verification are recorded in Known
limitations.

### Earlier task

Completed: the minimal production-deployment templates, under `deploy/` and
committed-ready but not committed. Four files, all placeholders only:

- `deploy/Caddyfile` - the site block. Serves the Vue build from
  `/opt/eqalb/frontend/dist`, reverse-proxies only `/api/*` to `127.0.0.1:8000`
  with timeouts above the R model's own 900 s, enables zstd/gzip compression,
  keeps HTTP/3 off so no UDP port is needed, and carries the optional SPA
  fallback as a commented `try_files` line because the app still has no router.
- `deploy/eqalb-api.service` - one unit for the whole model layer. `User`/`Group`
  `eqalb`, `WorkingDirectory=/opt/eqalb`, `ExecStart` through `/opt/eqalb/.venv`,
  `EnvironmentFile=/etc/eqalb/api.env`, `Restart=on-failure` with `RestartSec=5`,
  `After`/`Wants=network-online.target`. It starts `api/run_api.py`, so there is
  no `--reload`, no debug mode, no `workers=` and no `0.0.0.0`. Hardening stops
  at what R and renv tolerate: `NoNewPrivileges`, `PrivateTmp`, `PrivateDevices`,
  `ProtectSystem=full`, `ProtectHome=read-only`, `StateDirectory=eqalb` with
  `HOME`/`XDG_CACHE_HOME` pointed at it so renv has a writable cache, and
  `KillMode=control-group` so the R worker child stops with the API.
- `deploy/api.env.example` - the six environment variables the code actually
  reads (`EQALB_API_HOST`, `EQALB_API_PORT`, `EQALB_R_WORKERS`,
  `EQALB_R_TIMEOUT`, `EQALB_RSCRIPT`, `EQALB_LOG_LEVEL`), with
  `EQALB_R_WORKERS=1` for the 4 GB host and 8000 rather than the
  development-only 8788. No new configuration was invented and no
  domain, IP, key, certificate or token appears.
- `deploy/DEPLOY.md` - the Ubuntu 26.04 LTS (resolute) runbook: packages
  (a merged build/library list for compiling both R and the 135-package
  `renv::restore()` set, followed by the §1.2 source build of R 4.5.1 into
  `/opt/R/4.5.1` with its archive and SHA-256 pinned - no apt R is installed,
  because CRAN's `resolute-cran40` suite serves the current R 4.6.x series rather
  than the R 4.5.1 `renv.lock` requires),
  server baseline (non-root user, SSH keys,
  UFW with only OpenSSH/80/443, unattended upgrades), install from tag
  `v1.0.0-rc1`, DNS/Caddy, validation (private health first, then HTTPS, then a
  100-iteration PSA before any 1,000-iteration run, memory and log checks, and
  confirmation that 8000 and 8788 are unreachable), and rollback plus routine
  operations (including rebuilding R as a deliberate act, since a source build
  receives no apt updates). It presents the first installation as a controlled
  compatibility check rather than a proven procedure - the R source build, the
  restore against it and the install of the pinned lock file under the release's
  Python 3 are all unverified on the target -
  and §3.2 ends in a stop-and-verify checkpoint that must be green before DNS,
  Caddy or any public exposure, with a failure protocol that collects
  `systemctl`/`journalctl` output and forbids substituting a different R version
  or installing packages ad hoc.

`readme.md` gained a short "Deploying it yourself" section and a `deploy/` row in
the repository layout, both documentation only. The `.gitignore` needed no
change: `deploy/api.env` is already covered by the existing `*.env` rule while
`deploy/api.env.example` stays tracked.

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

**Result reveal and tutorial step transitions (frontend presentation only).** Two
restrained animations were added to the Vue app. (1) An analysis result now fades
in over 240 ms when it is committed, and a short ECG trace in a slim strip between
the panel heading and its description draws itself over 780 ms as a soft teal
highlight travels along it, after which the whole strip fades away over 180 ms and
the heading is left clean — no permanent icon and no animated underline. It replays
on each new successful run and for nothing else: not a tab switch, a theme change
or an input edit, not a failed or cancelled request, and not another tab's run.
`useModel.ts` counts committed results per analysis (`resultRevisions`, bumped
only after a run resolves, inside `run()`), which is the only signal used — the
result objects cannot express "new" because two runs can return identical
numbers. `composables/useResultEntrance.ts` turns that revision into an
alternating CSS animation class, once per revision, remembering at module scope
what it has already shown so mounting a tab again does not replay it;
`components/ResultTrace.vue` renders the strip, and all nine analysis panels carry
the class on a `.result-reveal` wrapper around the block their own `v-if="result"`
already guarded, with the strip directly under their own `h2`. The draw and the
highlight are two dashes on one path sharing a duration and a linear timing, so
the drawn tip and the highlight's leading edge are the same point. (2)
Tutorial steps and Part 2 sections now cross-fade with 10 px of horizontal travel
(180 ms out, 220 ms in, Forward and Back in opposite directions) on
`components/tutorial/TutorialStepStage.vue`, which replaces both views' focus
watchers. Vue's `<Transition mode="out-in">` was deliberately not used: an
interrupted out-in can leave the outgoing element in the document, which would
duplicate the step heading's `id` and leave the outgoing step's controls
focusable. A move that arrives during a fade therefore only replaces the step
that is about to be shown, so rapid Next/Back land on the step the learner is
actually on, and a move back onto the step already on screen cancels the fade.
Focus still moves to the arriving step's heading once it is on screen, except in
Part 2, where the congratulation keeps the focus it takes when it opens. Under
`prefers-reduced-motion: reduce` nothing animates at all: the existing global rule
removes the animations, the entrance class is inert, and the stage swaps in one
frame. `@media print` removes the entrance and the strip's reserved space, so a
printed panel is laid out exactly as it was before the strip existed. Nothing else
changed: no request, input, calculation, threshold,
routing, dependency, export or R/API file was touched, the tutorial session and
R's own values are untouched by a move, and the Download results view still
renders only on its own page. See the update log for what was verified.

**Interaction polish (frontend presentation only).** Five routine interactions
were refined without touching any meaning. (1) The analysis tab strip carries one
absolutely positioned 3 px indicator, placed from the selected tab's own box
(`composables/useTabUnderline.ts`): it slides for 190 ms only between two tabs on
the same row and jumps into place across a wrap, on resize, on a font change and
on its first placement, and it is `aria-hidden` with `pointer-events: none`, so it
is decoration over tab semantics that are unchanged. (2) The existing `<details>`
disclosures keep their native semantics and animate only where the engine supports
`::details-content` with `interpolate-size`, growing to the content's real height
(so nothing is clipped by a guessed maximum) while the existing marker becomes a
chevron that rotates 150 ms — and the collapsed state still leaves the contents
out of layout, the tab order and the accessibility tree. (3) Each analysis run
button's two labels are two spans in one grid cell (`components/ButtonLabel.vue`),
so the button's box and its accessible name are exactly one label at a time; the
pending label states the operation (and, for the PSA, the iteration count) with a
small `aria-hidden` ECG, and the button's disabled state is the store's own, so a
second submission is not possible while a request is in flight. (4) An export that
has been prepared reports once through `components/DownloadNotice.vue` — a corner
card, `role="status"` for a prepared download and `role="alert"` for a failure,
auto-dismissed only when it is good news, with a Dismiss button that never takes
the focus — and `views/DownloadResultsView.vue` keeps its own in-page line, so
nothing is reported twice; neither claims a file was saved, only that the hand-off
to the browser happened. (5) The four dialogs fade their backdrop and move a few
pixels while fading, over 190 ms, through `composables/useDialogTransition.ts`,
which also marks the leaving dialog `inert` so an outgoing dialog cannot keep the
focus or block the page; Escape, initial focus and the case-facts overlay's focus
return are unchanged and no trap was added. Beyond the five, the lighthearted
second line under a long operation's factual status is
`composables/useLoadingMessages.ts`: 24 sentences in one list, one shown after a
1 s grace, changing every 7 s from a shuffled cycle that never repeats the one on
screen, each change a 280 ms opacity-only crossfade in which the message on screen
and the one replacing it fade over each other, `aria-hidden` so nothing changing is
announced, held still under reduced motion (including when the preference changes
mid-wait), with every timer cleared when the wait ends or the component unmounts.
The area the line sits in is as tall as the longest message at the current width, so
neither the first message nor a change of message moves the card.
The motion values live in the `--motion-fast` / `--motion-base` / `--ease-move`
tokens in `styles.css`.

**Page entries (frontend presentation only).** A page fades in when an internal link
or button moves the visitor to it: opacity only, 160 ms, on the wrapper `App.vue`
puts around the page content (`.page-entry`) — never on the shell, which holds the
loading indicator, the download notice and the launch overlay, all fixed to the
window and all of which a sub-full-opacity ancestor would re-anchor. The class is
toggled by `composables/usePageEntrance.ts` in the same microtask as the DOM update,
so the arriving page is never first painted at full strength and then faded, and its
end state is full opacity, with a safety clear so a stalled animation cannot leave a
page invisible. It plays once per entry, where an entry is the page plus the post's
slug on the blog — so the index, one post and another post are three arrivals, while
a rerender, an input, a theme change, a loading message, a tutorial step and an
analysis-tab switch replay nothing. Five arrivals are shown immediately instead, each
because a fade would be wrong rather than merely unnecessary: a first paint (the
browser has already shown the page), a Back or Forward move (the browser's own, and
one it is still restoring the scroll of), the landing page's crossing into the app
(`useAppLaunch` owns that sequence and the fade must not be a second entrance over
it), any arrival while a dialog is open (a page's own dialog is fixed-positioned
inside the wrapper), and any arrival the document is already scrolled into — which,
together with the app's Home screen being listed to skip, is what keeps the landing
page's header and the Home screen's pinned theme button exactly where they are.

## Next planned task

The backend deployment preflight now supports the live inline-systemd
configuration (no `/etc/eqalb/api.env`) and is locally validated. The next step is
the first live run: keep the `backend-production` environment and its five
secrets, install the CI key and the documented sudoers/state-directory entries on
the VPS, run `backend-deploy.sh status` over SSH to confirm the resolved R path,
listener and workers, then one manual `deploy` and one manual `rollback`, and only
then uncomment the `push` trigger. See `deploy/BACKEND_DEPLOY.md`. The live host
reports two R workers while `deploy/api.env.example` records one; confirm the
intended server-local setting separately.

The animation work, the interaction-polish pass, the page-entry fade and the dialog
focus containment are implemented, verified locally, merged into `main` as `ea192dd`
and **live**: the release is
`7-ea192dd5fb193a6ada5ceb88929adebc1d92fef2` in production (see the update log for
what was verified there). Nothing is waiting on a decision. The author's
review copy for how it all feels is the dev server, `http://127.0.0.1:5173/app`. The
things to look at are the result
entrance ("Start analysis" then "Run base case": the summary fades in while the ECG
trace draws under the heading and its teal highlight passes — run it twice to see it
replay), the tutorial step transitions (Home then "Guided tutorial", which are
approved and unchanged), and the five additions of the polish pass — the underline
that slides between analysis tabs, a disclosure opening and closing under a
rotating chevron, a run button reading "Running…" with a small ECG while it works, a
"Download prepared." card after a per-tab export, and the PSA confirm dialog's
entrance and exit, and the lighthearted line under the loading card's factual line,
which changes every 7 s with a crossfade (it needs an operation that lasts a few
seconds — a 100-iteration PSA is about twenty seconds). The values to move if any of
it feels wrong are the
durations, the highlight's length and the travel in `frontend/src/styles.css` (the
`--motion-fast` / `--motion-base` / `--ease-move` tokens with the `.result-reveal`,
`.result-trace`, `.tabs__indicator`, `.btn-label`, `.dialog-*`, `.notice-*`,
`.download-notice`, `.app-loading__quip*` and `.tut-stage` blocks, with the
tutorial's leave/enter timings
mirrored in `LEAVE_MS` / `ENTER_MS` in
`frontend/src/components/tutorial/TutorialStepStage.vue`, the reserved strip's
height in `.result-trace`, and the grace, the 7 s interval, the 280 ms crossfade and
the message list in
`frontend/src/composables/useLoadingMessages.ts`). The dialog focus containment that
was the previous release blocker is now implemented in
`frontend/src/composables/useModalFocus.ts` and verified in the running app, so
nothing named under Known limitations is waiting on a decision.

The landing page's scroll fade is reversible and scroll-linked - it fades in as a
group arrives, holds at full strength through a wide central band, fades out as the
group leaves, reverses on the way back up and repeats on every pass, with no latch
and no timer - and it is implemented and validated on
`feature/openhealth-landing`, waiting for the author's review. The two-line
OpenHealth heading, the centring, the portrait, the palette, the navigation and the
arrival into the app are unchanged.

**Review it on the dev server, not the live site.** `https://openhealth.ngo`
serves a bundle built before the landing page existed (its JS contains none of
`--reveal`, `landing__reveal-inner`, `landing--armed`, `--reveal-lift` or
`mahmood-portrait`), and the deploy workflow only runs on a push to `main`, so the
public site cannot show any of this until the branch is merged and deployed. The
page to review is `http://127.0.0.1:5173/`, or `http://127.0.0.1:5173/?debugReveal=1`
for the development-only diagnostic panel, which reports each group's entry, exit
and painted opacity side by side.

One thing is worth confirming on the author's own machine, because it is a judgement
about feel rather than correctness and cannot be made from here: whether the exit
fade starts late enough for long content on a phone. The value to move is
`EXIT_START` in `frontend/src/views/OpenHealthHomeView.vue` (currently `0.22`, the
fraction of the viewport height its bottom edge must rise above before the fade
begins); raising it makes the content linger longer, and the other three constants
`ENTER_FROM` (0.9), `ENTER_DONE` (0.55) and `EXIT_DONE` (0) sit beside it. The `16px`
in `.landing--armed .landing__reveal-inner`'s transform still sets the entry lift,
and note that `--reveal-lift` now drives it independently of `--reveal`.

The About Me group deliberately does not fade out, because the document ends beneath
it and its bottom edge never rises to the exit threshold. That is the specified
behaviour rather than a gap, so it needs no work; forcing a fade would mean adding
blank scrolling space, which the brief ruled out.

The one item still open from the earlier portrait work is optional and unchanged:
the shipped PNG is 346 kB for a display of at most 288px, so a smaller export or a
WebP/JPEG derivative would trim the transfer further — the author's call, and not
started.

Still the author's to decide: the section copy, the local serif stack, the three
contact details, the `/app` route the single action points at, whether the About
page at `/about` should follow the landing page's palette or wording (it still
says "a health economist"), and whether the OpenHealth wordmark should stay
hidden in the navigation below 700px. The landing page's crossing into the app is
tuned in one place — `LAUNCH_TIMING` in `frontend/src/composables/useAppLaunch.ts`
with the matching `--launch-sheen` / `--launch-fade` tokens — so the roughly 1.2s
end-to-end timing can be adjusted after local review without touching anything
else.

The OpenHealth public shell is implemented in the frontend and verified locally,
and is committed on `feature/openhealth-landing` as `f3acd2a`; it is not merged
into `main` and not deployed. The single-page fallback these addresses need is
now part of the deployment configuration rather than outstanding (the tracked
`deploy/Caddyfile` carries `try_files {path} /index.html`, and the one-time
Caddy root migration recorded in Current task has been performed and verified on
the host). Giving eQalb's internal screens their own addresses was not requested
and remains deliberately unbuilt, so `/app` stays the only eQalb address until
it is asked for.

Deployment templates are complete: `deploy/Caddyfile`, `deploy/eqalb-api.service`,
`deploy/api.env.example` and `deploy/DEPLOY.md` now describe the whole VPS
deployment, and the repository is release-ready (the browser stack is tracked, and
the R and Python dependency sets are both reproducible). What remains is executing
that runbook on the host, which is deliberately outside the repository: the only
values a deployment introduces are the real hostname in the Caddyfile and the
server-local `/etc/eqalb/api.env`, neither of which is ever committed. No further
repository work is planned on deployment. The R-version blocker is resolved by
decision rather than by a repository change: the application's R stays at the
4.5.1 recorded in `renv.lock`, and the runbook now compiles that exact version from
the official source archive into the isolated prefix `/opt/R/4.5.1` instead of
installing any distribution R, with the API pointed at it through the existing
`EQALB_RSCRIPT` setting. The remaining item to confirm while running it is that the
pins in `api/requirements.lock.txt` were validated on Python 3.14 while the host's
Python 3 is whatever Ubuntu 26.04 provides, and the lock file must be regenerated
whenever `api/requirements.txt` changes. The legacy
Shiny application stays a reference that is not deployed to the VPS (its Posit
Connect manifest is unchanged).

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

The Version 1 frontend deployment automation is deployed and has completed one
end-to-end automated run (see Current task): the server-side bootstrap, the
public-pointer/Caddy migration and the CI key rotation are complete and were
verified on 2026-10-14, the tracked `deploy/Caddyfile` root line matches the live
`/opt/eqalb/public/dist`, the first workflow attempt's SCP upload failure was
corrected by uploading the archive and its checksum as two separate single-file
transfers, and that successful run exercised the pinned action SHAs. The operator
has confirmed the `production` environment's required-reviewer/approval rule. What
remains is the rollback path: neither the automatic rollback after a failed
validation nor the manual rollback has been exercised, and the automatic one also
performs a live public-pointer swap under a running Caddy, so it is worth watching
once through §5 before the automation is treated as fully supported. The manual
frontend path in `deploy/DEPLOY.md` §3.4 and §6 remains the fallback for a host
that does not use the automation. The served-path sentence in `frontend/README.md`
was corrected to name `/opt/eqalb/public/dist` and to record the deployment
status. No other repository work on deployment is planned, and the frontend
surfaces the automation deliberately does not cover (Caddy configuration changes,
API/R changes, DNS) are unchanged.

The blog's first post is published, so the decisions left are two rather than
three: whether `/about` should regain an entry point on the landing page, since
the instructed link replacement leaves it reachable only by its address; and
whether later posts should be written in Markdown, which would mean one small
renderer dependency and its approval, in place of the typed content model
documented in `frontend/src/content/blog/README.md`. Nothing is required for
another post beyond writing it and listing it in `posts.ts`.

## Update log

| Date | Change | Verified? |
|---|---|---|
| 2026-10-17 | Backend deployment preflight fixed for the live systemd configuration, deployment script and documentation only. The first manual run failed before checkout with `error: /etc/eqalb/api.env is not readable by eqalb`; the host has no `/etc/eqalb`, keeps `EQALB_RSCRIPT` inline in `eqalb-api.service`, declares no `EnvironmentFile=` and runs two workers. `deploy/backend-deploy.sh` now resolves settings read-only in systemd's order — inline `Environment=` and drop-ins, then each `EnvironmentFile=` (later wins, `-` optional, missing required or unreadable stops), then `ExecStart` (uvicorn `--host`/`--port` → `UVICORN_*` → 8000; `run_api.py`/`main.py` → `EQALB_API_*` → 8788; unknown launcher → observed listener), then `EQALB_RSCRIPT` or a service-`PATH` lookup, with `EQALB_R_WORKERS` defaulting to 2 — parses environment files as data (never sourced), prints only allowlisted values, cross-checks the running process (R-path and listener mismatches stop, worker count warns) and exposes `EQALB_DEPLOY_RSCRIPT/API_HOST/API_PORT` overrides plus the resolved values in `status`. `deploy/BACKEND_DEPLOY.md` documents both configuration sources and their precedence, the dedicated `eqalb-backend-deploy` account and its two sudo grants, the `Environment=` vs `EnvironmentFiles=` caveat and the read-only inspection commands. The workflow is unchanged and remains manual-only. No R model, API behaviour, frontend, analysis, production unit, Caddy or default was changed | Partial - locally validated only. `bash -n`, `shellcheck -x -S style`, `actionlint` (with shellcheck) and `git diff --check` pass; 30 parser tests and 30 stubbed-systemd resolver scenarios pass (inline-only, EnvironmentFile override, missing/optional/unreadable file, unset/conflicting config, R and listener mismatch, unknown launchers, IPv6/wildcard/UDS listeners, worker warning, fail-before-change ordering). Not verified: the live host, the first successful deploy and the first rollback |
| 2026-10-17 | Backend production deployment automation added, deployment files only. New `.github/workflows/deploy-backend.yml` (manual `workflow_dispatch`, `deploy`/`rollback` modes, `backend-production` environment, pinned SSH host key, public `/api/health` check, SHA/time summary; `push` trigger commented out), `deploy/backend-deploy.sh` (server-side deploy/rollback/status, current/previous/pending SHA state in `/var/lib/eqalb-backend-deploy`, Python lock sync, `renv::restore`/`renv::status` with R 4.5.1, `eqalb-api.service` restart, 180 s loopback health poll, no automatic rollback) and `deploy/BACKEND_DEPLOY.md` (secrets, one-time SSH/sudoers/state-directory setup, first run, rollback, risks). `deploy/DEPLOY.md` section 6 and `readme.md` point to the new guide. No R model, API, frontend, analysis or default was changed | Partial - locally validated only. `bash -n`, `shellcheck -x -S style`, `actionlint` (with shellcheck) and YAML parsing pass; the health parser accepted the live production response and rejected degraded/zero-worker/startup-error/invalid-JSON responses; workflow resolve/secrets/key/SSH-command/result/summary steps were dry-run locally. Not verified: live SSH and secrets, sudoers/state directory, first deploy, first rollback, public health after a real deploy. `backend-production` and its five secrets are outstanding; the workflow remains manual-only |
| 2026-10-16 | Browser-tab title changed to "OpenHealth", frontend only. The static `<title>` in `frontend/index.html` was `eQalb — an interactive introduction to health-economic modelling`; it is now `OpenHealth`. The two entries of `PAGE_TITLES` in `frontend/src/composables/useAppView.ts` that would have overwritten it are now `OpenHealth` as well — the landing address `/` (which carried the old title) and the application address `/app`, which every in-app screen shares (Home, tutorial, project description, download view and the dashboard), so the tab reads "OpenHealth" throughout the product rather than switching to "eQalb — illustrative HTA model" on the workspace. The comment above the table now records that. `/about` ("About OpenHealth"), `/blog` ("Blog — OpenHealth") and an open blog post (titled by the post in `BlogPostView.vue`) are unchanged, as are the metadata description, the favicons, the landing copy, the in-app eQalb branding, the tutorial content, the model naming, the API, the R files, the exports and every analysis behaviour | Yes - frontend, local review first. `npm run typecheck`, `npm run lint`, `npm run build` (`index-DwadKxDr.js`, 934.73 kB) and `git diff --check` pass; `frontend/dist/index.html` carries `<title>OpenHealth</title>` and the description untouched. Browser at 127.0.0.1:5173: the tab showed exactly "OpenHealth" on `/`, on `/app` before and after the menu's explanation overlay, on all nine analysis tabs, on the Home screen, the tutorial, the Project description and the Download results views, with a presentation overlay open and after Escape; `/about` read "About OpenHealth", `/blog` read "Blog — OpenHealth" and the published post read "Release of eQalb & The introduction of OpenHealth! — OpenHealth". No regression: the base case ran to €2,439, the chart export produced `base-case-cost-effectiveness-plane.png` with one canvas, the only requests during the pass were the app's own health/defaults load and that one analysis run, presentation mode opened and closed cleanly, and `/api/health` returned `ok`. Limitation: verified in the Vite dev server and the production build output; the hosted deployment was not redeployed |
| 2026-10-16 | Presentation-mode wording follow-up to the audit, frontend copy only. Two internal identifiers that were still visible in an overlay now read as the reader's word for them. (1) The HTA summary's settings disclosure listed the endpoint's own request-field names under "Request fields not supplied" (`probability_cost_effective`, `evpi`, and `icer`, `cumulative_budget_impact`, `readiness` when those are the missing ones); the row is now "Values not supplied" and each field is named with the workspace's own wording through a new `availabilityFieldLabel` in `components/presentation/settings.ts` ("Probability cost-effective", "EVPI per patient", "ICER", "Cumulative net budget impact", "DHT readiness", with an unknown future field written with its underscores removed rather than left as an identifier), so every field R reports is still listed and none is guessed. (2) The value-of-information overlay's EVPPI table carried the workspace's "Model argument" column, whose cells are R's own call arguments (`scenario_rrr`, …); the overlay now uses a `presentedColumns` set derived from the panel's columns with that one column left out, since the parameter column already names each row in words — same nine rows, three reader-facing columns. Both changes are presentation-only: the HTA summary's "Availability of the upstream analyses" disclosure and the tab's own EVPPI table (four columns) are unchanged, and no figure, table value, notice, layout, transition, focus behaviour or chart-export control was touched | Yes - frontend, local review first. `npm run typecheck`, `npm run lint`, `npm run build` (`index-Dg4e6nwv.js`, 934.81 kB) and `git diff --check` pass. Browser at 127.0.0.1:5173 with all nine results stored: all nine overlays opened with every disclosure expanded and scanned for `[a-z]+(_[a-z]+)+` identifiers — zero in all nine, and no "Request fields" phrase — while each still showed its own metrics, tables and settings rows (4/17, 4/4, 4/20, 4/9, 4/4, 4/4 with its 9-row EVPPI table, 4/15, 3/18, 1/7); the VOI overlay table read Parameter | EVPPI per patient | Unclamped estimate with the same nine parameters while the workspace table kept all four columns including "Model argument"; the HTA summary overlay showed "Values not supplied: Probability cost-effective, EVPI per patient, DHT readiness" in the partial state (2 of 5 domains) and no such row when all five were included; a fetch spy recorded no request while opening or closing any overlay, and Close/Escape returned focus to Present with 0 overlays and 0 `[inert]`; no overlay contained a chart-export control (0 in all nine) and a workspace PNG export still produced a valid 163 KB image; at 390 px the VOI overlay had no page or panel overflow and its table scrolled locally (488 px in 297 px). Limitation: Chromium only; the workspace's own request-field list and model-argument column were deliberately left as they are, since the request scoped this to presentation mode |
| 2026-10-16 | Per-chart PNG export for the workspace's interactive ECharts charts, frontend only and local review first. New `components/ChartDownload.vue` renders one compact "Download chart" action inside the figure that holds a chart (nine charts: base-case plane, PSA plane and acceptability curve, tornado, budget impact, survival curves, EVPI and EVPPI charts, value-based-price comparison) and saves that chart as it is on screen: the live instance is resolved from the chart's own container with `getInstanceByDom` (which never initialises one) and asked for its own image with `getDataURL({ type: 'png', pixelRatio: 2, backgroundColor: panel })` using the live theme palette, so nothing is rerun, no result is recomputed, no option is changed and no second chart or canvas is created for the export; the base64 payload is decoded in the new `export/png.ts` and written through the existing `downloadBytes`, and the outcome is reported by the existing single download notice via `prepareDownload`. New `.chart-figure__actions` rule in `styles.css` gives the action its own row under the chart (right-aligned, always present, so the figure's height never changes when it is used). The button is a real `<button>` with an `aria-label` naming its chart and a `title` naming the file, keeps the app's focus ring, works with Enter/Space, and on failure (chart not on screen) reports "The download could not be prepared. The chart is not on screen yet." as a `role="alert"` while leaving the chart and the result untouched. Presentation mode (no export controls), the tutorial charts, the readiness and HTA-summary tabs (no charts), the consolidated results ZIP, the CSV exports, the R models, the API and the calculations were all left unchanged; no dependency was added | Yes - frontend, local review first. `npm run typecheck`, `npm run lint`, `npm run build` (`index--hTHQU07.js`, 934.53 kB) and `git diff --check` pass. Browser at 127.0.0.1:5173 against the model service on 127.0.0.1:8788 with all nine results stored: all nine actions clicked and every produced file read back and decoded — each a valid PNG of 46-163 KB with 214-1067 distinct colours, non-zero ink and dimensions exactly twice the canvas measured at the click (base case 956x320 -> 1912x640, tornado 956x420 -> 1912x840, VOI charts 930x320/930x420 -> 1860x640/1860x840), the panel colour in the corner in both themes (dark `rgb(22,36,44)`, light `rgb(255,255,255)`); the file names matched the per-chart convention (`base-case-cost-effectiveness-plane.png` … `value-based-price-comparison.png`); a fetch spy recorded no API request across all nine, three repeats of one chart and a keyboard export; three repeated exports left the canvas count, the zrender root count and the figure height unchanged (1/1/402 px); Tab reaches the button with `outline: 2px solid rgb(127,209,216)` and `:focus-visible` matching, and Enter downloads; with the chart container removed the failure notice appeared as a `role="alert"` with zero downloads and the four result figures intact, and returning to the tab re-rendered the chart and the export worked again; `prefers-reduced-motion: reduce` gave a 0 s transition with the export still working; at 390 and 1440 px on all seven chart tabs there was no page overflow, no figure outside the viewport and no button outside its figure; the results package still built its 14 unchanged entries with no `.png`, presentation mode opened with zero download actions and no "Download chart" text, and the stored results were unchanged (base case €2,439 / 0.0082 / €298,966 / −€1,623). Limitation: Chromium only; no real screen reader (the label and role were read from the accessibility tree); the Shiny app and the hosted deployment were not touched |
| 2026-10-16 | Conservative wording audit across the analysis workspace, frontend copy only. Four static texts were reduced or moved, each only where the same fact stays reachable: the assumptions sidebar's reset hint collapsed from three sentences to one ("Reset restores the 16 model assumptions and the threshold only; every completed result is kept."), since the rest repeated the "Reset model inputs" title and the stale notice each tab already shows; the sensitivity tab's permanently visible CSV/Shiny-layout paragraph moved unchanged into the "Full one-way sensitivity table (N parameters)" disclosure beside the table it describes; the survival tab's export note became "The simulated patient-level dataset is not available here yet, so the download offers the summary tables instead.", dropping the API reference, the Shiny comparison and the engineering rationale while keeping the limitation; and the HTA summary's partial-assessment alert lost its raw request-field list ("Request fields not supplied: probability_cost_effective, evpi") — the only internal API vocabulary in user-facing copy — which remains inside the "Availability of the upstream analyses" disclosure where it also appeared, next to the plain-language "Not yet included" and not-assessable-domain sentences. Every R-generated string, export string, result-specific notice, disclaimers and the tab introductions were left as they were, and presentation mode, calculations, defaults, exports and the API contract were untouched | Yes - frontend, local review first. `npm run typecheck`, `npm run lint`, `npm run build` (`index-_4G5NO3w.js`, 932.73 kB) and `git diff --check` pass. Browser at 127.0.0.1:5173 with all nine results stored: the new sidebar sentence renders; the sensitivity note has 0 matching nodes in the open panel, sits in the closed table disclosure where `innerText` excludes it and `checkVisibility()` is false while closed, and is visible once opened; the survival panel shows the new sentence and contains no "the API does not return" text; the HTA summary alert shows the two plain sentences and the panel has no `<code>` field list; base-case figures unchanged (€2,439 / 0.0082 / €298,966 / −€1,623), one canvas, no request issued; `scrollWidth === clientWidth` with no paragraph escaping its panel at 1440, 1024, 768 and 390 px on the base case, sensitivity, survival and HTA summary tabs; the edited strings render in light (`rgb(100, 116, 139)` on `rgb(244, 247, 249)`) and dark. Limitation: Chromium only; the Shiny app and the hosted deployment were not touched |
| 2026-10-16 | Loading, in-flight, success, error, empty and stale states audited and made consistent for every explicit analysis action, frontend only and local review first. `useModel.run()` now returns early when that analysis is already running, so no double click, repeat key activation or twice-confirmed dialog can start a duplicate request; each panel still disables only its own action, leaving inputs, the ranked-outcome selector, Present and the download buttons usable while a run waits. `runPsa()` captures the iteration count and the seed once, before the request is built, publishes the count as `psaInFlight` and clears it in a `finally`, so the request, the pending label and the in-flight line all describe the run that is going rather than whatever the fields say while it waits. Every panel's placeholder became one `<p class="hint" role="status">` that carries the wait sentence while the request is in flight and the tab's own guidance otherwise (the guidance is replaced, not added to, and it disappears when the result lands); the PSA's in-flight line, which used to claim "A 1,000-draw PSA takes minutes" for every run including a 100-draw one, is now "Running N iterations. Keep this tab open until it finishes." with the minutes warning only at or above `PSA_CONFIRM_MIN`; every error paragraph gained `role="alert"`; and every pending label now names its own analysis ("Running the base case…", "Running the sensitivity analysis…", "Running the budget impact…", "Simulating survival…", "Calculating the value of information…", "Assessing readiness…", "Calculating the value-based price…", "Assessing the HTA summary…"), matching the app loader's own sentences. No result is cleared by a new run, a failure keeps the previous result with one message, the action re-enabled and the inputs untouched for a straight retry, and nothing new is a container or a colour. No calculation, API contract, input default, threshold, export, presentation-mode behaviour or tutorial flow changed, and the rotating lighthearted line was left where the pattern already existed (the app loader's card) rather than copied into the panels | Yes - frontend, local review first. `npm run typecheck`, `npm run lint`, `npm run build` (`index-BaxIfIJZ.js`, 933.18 kB) and `git diff --check` pass. Browser at 127.0.0.1:5173 against the model service on 127.0.0.1:8788, all nine analyses driven through their states: each new placeholder sentence and in-flight sentence read with `role="status"` and each error with `role="alert"`; the slow analyses (PSA at the documented 100 draws, one-way, value-based price, value of information, HTA summary) supplied in-flight samples directly and the fast ones (base case, budget, survival, readiness) were held with emulated latency; a triple click in one tick fired exactly one base-case request and a programmatic click on a disabled action fired none; a run navigated away from and back mid-flight kept its pending label, disabled action and previous result; the previous result stayed on screen through a one-way re-run (14-row table plus chart) and was replaced only on success; an injected HTTP 500 on the budget impact left the previous result, showed one message with `role="alert"`, kept the edited input at 18 and allowed a retry that then succeeded and cleared the message; editing the PSA iterations from 100 to 1,000 while a 100-draw run was in flight left the button and the in-flight line saying "Running 100 iterations", and the app loader's quip rotated between two samples 8 s apart under normal motion and stayed one static message with `transition-duration: 0s` and `animation: none` on the pending ECG under `prefers-reduced-motion: reduce`; the workspace was taken from 0 to 9 of 9 stored and back to the empty state with the app's own "Clear all results", each placeholder returning as before; at 390 px every state had 0 page overflow, the longest pending label stayed on one line at 266 px and the in-flight line was shorter than the guidance it replaced; presentation mode opened on the base case (€2,439, 17 rows) and the value-based price (€155.03, 18 rows) with no request, focus back on Present and no leftover overlay or `[inert]`; the Download results view stayed absent from the dashboard and still rendered only on `page === 'export'` via its menu action with the same included/not-yet-run lists; charts drew as before with one canvas on the base case after open/close and two on the PSA and the value of information. Not verified: a 1,000-draw PSA (the minutes-warning branch was read in the code, not run, per the standing PSA-size policy), a real screen reader, browsers other than Chromium, and the Shiny app and hosted deployment, which were not touched |
| 2026-10-16 | Presentation-mode snapshot metadata follow-up, frontend only, in place of the fallback that read the panel's live controls. `useModel` now keeps the exact request a one-way sensitivity run and a readiness assessment were sent beside their results: `owsaRun` holds the `OwsaRunRequest` record (the threshold, the `scenario_*` body and the range overrides the run carried, or `null` when R derived them) and `readinessRun` holds the readiness request body, both in `shallowRef`s with the `OwsaRunRequest` interface exported; `owsaStale` and `readinessStale` compare that stored record with what the tab would send now, so the displayed settings and the staleness verdict cannot diverge. `SensitivityPanel.vue` snapshots the stored request when Present opens and builds its disclosure from it (the run's own scenario values through `scenarioSettingRows`, the range count from the run's own bounds, the ranked outcome and threshold from the request) and `ReadinessPanel.vue` lists the run's readiness values, booleans and choice levels read from its stored body; both disclosures gained one line saying every row is the request that run was sent, kept with its result, and the moved-since-run line names the difference whenever the controls have changed since. No API contract, R calculation, input default, threshold, export or execution behaviour changed, no settings history, undo or comparison feature was added, and the approved Base-case design is untouched | Yes - frontend. `npm run typecheck`, `npm run lint` (89 files, 114 rules, 0 diagnostics), `npm run build` (`index-CTTfZYWF.js`, 931.93 kB) and `git diff --check` pass. Browser at 127.0.0.1:5173 against the live model service: a sensitivity run from a clean page reports no moved-since-run line and its disclosure lists the run's own annual intervention price 500, which stays 500 after the control is edited to 640 — with the moved line ("the scenario, threshold or ranges") and the changed-controls note appearing instead — and the workspace result unchanged; readiness does the same (stored smartphone access 55% with its control at 80%, 15 rows read from the stored request); a fetch spy records no request when either overlay opens or closes; all nine tabs' overlays open and close with their own metrics, charts in their own containers, focus back on Present and no leftover overlay node or inert attribute; 390px with reduced motion gives no transform, no transition and no horizontal overflow. One earlier "stale after a fresh run" reading was traced to a run that had not finished when Present was opened, not to the comparison. Limitation: Chromium only, and no PSA larger than the documented 100-draw validation run was started |
| 2026-10-16 | Presentation mode extended to every analysis tab, frontend only and local review first, building on the approved Base-case prototype without redesigning it or removing its chart-entry behaviour. Two new files carry the shared structure — `frontend/src/components/presentation/PresentationOverlay.vue` (the app's own dialog and transition, the focus containment from `useModalFocus`, one scoped `modal--present` class, the eQalb identity line and analysis title, the Close control, the moved-since-run line, the later-run line, the settings disclosure and R's notice) and `PresentationSettings.vue` plus `settings.ts` (one row per setting, and the `movedSentence`/`supersededSentence`/`scenarioSettingRows`/`settingRow` helpers, so no panel words these itself) — and each of the nine panels gained one compact Present action beside its existing result actions (shown only when that tab has a valid result) plus its own content: four headline figures, its charts where it has them (one canvas where the panel has one, two for the PSA and the value of information, none for readiness and the HTA summary), R's own interpretation, warnings and limitations where they exist, the run's settings in a disclosure, and tables for the budget year rows, the survival risk table and arm summary, the readiness domains and numbers, the value-based price scan and the HTA decision dashboard and evidence priorities. Every overlay snapshots the response object when it opens, so a later run cannot change what is shown; the settings it prints come from that response, or — only while the store's own staleness comparison says the stored run still matches the controls — from the settings that produced it, and never from an unrun control, with the two tabs whose responses do not echo their inputs (one-way sensitivity and readiness) saying so in the disclosure instead. Opening and closing issues no request, derives no figure and changes no input, result or export. `styles.css` gained the overlay's own panel shape, the two-column chart grid and the settings-row rules; no other file changed | `npm run typecheck`, `npm run lint`, `npm run build` and `git diff --check` all pass. In the running app (model API on 127.0.0.1:8788, Vite on 127.0.0.1:5173): Present is absent on all nine tabs before their own result exists and present afterwards; each overlay's figures matched its panel exactly (PSA €2,418 / 0.0078 / €333,633 / 1.0% at €100,000/QALY; budget €15,480,000 over 5 years; survival 1,000 per arm, seed 20261004, 192 events in usual care; readiness 63,750 eligible with R's status counts; value-based price €155.03 with headroom −€204.97 and the required-effect verdict; VOI €0.11 per patient over 100 reused draws; HTA summary "Not yet assessable" with the not-included list); no request was issued while opening or closing any overlay (a fetch/XHR spy recorded none); each overlay's charts drew in their own containers and the workspace instances stayed live, with five rapid open/close cycles leaving no extra canvas or ECharts instance; Close, Escape and the backdrop all closed the overlay, returned the focus to that tab's Present action and left zero `[inert]`, and Escape inside an open disclosure closed that first; a later run landing behind an open overlay left the presented run on screen (the 5-year budget €15,480,000 while the panel moved to the 8-year €33,216,000) with the later-run line shown, and reopening after that showed the newest run with no line; changing an assumption after a run added the controls-have-changed line while the figures stayed the run's; the panel stacks and scrolls inside itself at 390 px with both charts 275 px wide and no page overflow; light and dark both render; under `prefers-reduced-motion` the overlay is present at once with 0 s transitions and no transform; navigating away while open unmounted cleanly with no `[inert]` left and the menu usable; and the approved Base-case overlay, the main-menu explanations, the centred Download results page, the analysis-tab wording and the stored results were unchanged, with no console or page error. Not verified: the Shiny application (untouched); the hosted deployment (unchanged); a real screen-share capture; browsers other than Chromium; and print rendering of the overlays beyond the global print rules. No PSA larger than the documented 100-draw validation run was started |
| 2026-10-16 | The base-case presentation-mode prototype, frontend only, first iteration and scoped to the Base-case tab. One compact "Present" action is added beside that result's existing actions (shown only once a valid result exists) and it opens a viewport-sized overlay for a screen share: the app's own dialog — the shared `.modal` markup, the shared `dialog` transition and the shared focus containment from `useModalFocus`, with one scoped `modal--present` class for the larger panel — carrying a small eQalb identity line and the analysis name, a Close control, the four headline figures at `clamp(1.5rem, 3vw, 2.05rem)`, the ICER sentence the workspace keeps on its information control, the deterministic plane in a second `BaseCasePlane` instance with its own container, the run's assumption snapshot in a closed disclosure, and R's own `notice` line. It is a view of an existing result and nothing more: no request (verified with a fetch/XHR spy), no derived figure, no change to inputs, defaults, thresholds, results or exports, and the result object is snapshotted on open so a run that lands while it is open replaces the panel's result without replacing the presented one. The assumptions shown are read from `BaseCaseResponse.inputs` — the scenario R received — through the contract's labels with the form's own conversion, so an edited control can never be printed as one the run used, and a line naming what has moved (threshold, scenario inputs, or both) appears whenever anything has. No browser-fullscreen call, slide, auto-advance or toolbar; no other tab or the main menu gained the control. Three files: `frontend/src/components/BaseCasePanel.vue` (the action, the snapshot, the overlay and its wording), `frontend/src/styles.css` (the `modal--present` panel shape and the `.present__*` rules, with a two-column mobile row rule) and `project_state.md`. No R, API, calculation, export, tutorial, landing, blog, routing, dependency or deployment file was touched, no `app.R` line changed, and nothing was committed, pushed or deployed | `npm run typecheck`, `npm run lint`, `npm run build` and `git diff --check` all pass. In the running app (model API on 127.0.0.1:8788, Vite on 127.0.0.1:5173): Present is absent before a run and joins the other two actions after one; opening it issued no request and started no run; the four figures and the sentence matched the workspace exactly (€2,439 / 0.0082 / €298,966 / −€1,623 at €100,000/QALY); the disclosure listed 17 rows (threshold plus the 16 parameters with their contract labels and units) from the response rather than the controls; the plane drew in its own container (painted pixels sampled) while the workspace chart kept its own 796 × 320 canvas, painted, through five open/close cycles that left exactly one canvas and one ECharts instance in the document; Close, Escape and the backdrop each closed the overlay, returned the focus to Present and left zero `[inert]`, and Escape with the focus inside the assumptions disclosure closed that first; a threshold change after the run added the "controls have changed" line while the figures stayed the run's; a new run landing while the overlay was open (the request visible in the spy) left the presented €50,000/QALY run on screen with the newest run behind it; the panel measured 1088 × 727 with a 1025 × 329 chart and no internal scroll at 1169 px, and stacked and scrolled inside itself at 390 and 360 px with no page overflow (charts 275 and 245 px wide, figures 24 px); light and dark both read correctly; under `prefers-reduced-motion` the overlay was present at once with 0 s transitions and no transform; and the main-menu explanations, the centred Download results page, the analysis-tab wording and the stored-results state were all unchanged, with no console or page error. Not verified: the Shiny application (untouched); the hosted deployment (unchanged); a real screen-share capture; browsers other than Chromium; and a genuinely long assumption list at phone width, which the panel's own scroll would handle but which was not exercised beyond the 17-row snapshot |
| 2026-10-16 | The minimal-clutter orientation pass over the browser interface, frontend presentation copy and layout only, in its revised form. The Home screen's menu is four compact one-line buttons laid out as three rows — "Open analysis workspace" and "Guided tutorial" full-width on their own rows, with "Project description" and "Download results" side by side beneath them in a two-column grid whose pair plus its 8 px gap adds up to the row above (384 = 188 + 188 + 8 px at 768 px wide and beyond, 342 = 167 + 167 + 8 px at 390 px), the group capped at 24rem and centred under the credits — with the two entry points marked only by an accent outline (`--accent`) and a soft accent tint (`--accent-soft`) and their label weight, and the two-line filled buttons of the first attempt removed together with the rules that existed only for them (`.home__choice`, `.home__choice-note`, `align-items: center`). Hover, press and scoping: the four menu buttons declare their own feedback (background, border and text colour over 120 ms; a `scale(0.98)` press that returns on release and never delays the click) through `.home__actions`, which is also what outranks the shared `.btn` rules declared further down the sheet; the menu's hover is declared under `@media (hover: hover)` and the shared `.btn:hover` rule is neutralised for these four under `@media (hover: none)`, so a touch screen is never left holding a hover state; disabled buttons keep the shared `.btn:disabled` treatment. Each of the two entry points now opens a small centred explanation instead of navigating at once: it is the app's own dialog (the shared `.modal` markup, the shared `dialog` transition and the shared focus containment from `useModalFocus`, with one scoped `modal--menu` class carrying a 170 ms timing inside the 150-180 ms asked for and the same button feedback for its two actions), it shows one short title, one sentence and two controls ("Open workspace" or "Start tutorial", and "Close"), and it navigates only from its own action — Escape, the Close control and the backdrop each return to the unchanged menu, one overlay can be open at a time, the menu behind it is inert, and opening or closing it runs nothing: no analysis, no request, no input or tutorial-session change. "Project description" and "Download results" keep their direct navigation. The nine analysis tabs keep the pass's single question sentence in place of their longer descriptions, and the pre-result guidance keeps its one line naming that tab's own action, with the value of information tab stating its PSA prerequisite. The Download results page is now one centred group in the app's content area (`page--centered page--fill`): the title, introduction and actions centred, the two result lists left-aligned inside a width-limited column, `margin: auto` in a flex column (never a height of its own) centring the group while it fits and resolving to nothing when it does not, and the vertical centring dropped below 1024 px in favour of padding and natural scrolling. Twelve files: `frontend/src/views/HomeView.vue`, `frontend/src/views/DownloadResultsView.vue`, `frontend/src/styles.css`, the nine analysis panels (`BaseCasePanel`, `CostEffectivenessPanel`, `SensitivityPanel`, `BudgetImpactPanel`, `SurvivalPanel`, `ValueOfInformationPanel`, `ReadinessPanel`, `ValueBasedPricePanel`, `HtaSummaryPanel`) and `project_state.md`. No calculation, input, default, endpoint, export, tutorial step, animation, landing page, blog, favicon, theme, route or deployment file was touched, `app.R` is untouched, no dependency was added, and nothing was committed, pushed or deployed | `npm run typecheck`, `npm run lint`, `npm run build` and `git diff --check` all pass. In the running app (model API on 127.0.0.1:8788, Vite on 127.0.0.1:5173): the menu renders as the three rows described above, centred under the credits with the LinkedIn/GitHub line still centred, no clipped label and no horizontal overflow at 320, 360, 370, 375, 390, 430, 768, 1240 and 1440 px; every label stays on one line down to a 370 px viewport and the two secondary labels wrap to a second line of equal height (still no overflow) at 360 and 320 px; and the four destinations still resolve; hover and press were exercised on a hover-capable pointer (the choices fill to the accent, the secondary pair go accent-soft, the press measures `matrix(0.98, …)` and returns to `none` on release with no navigation). Both explanations open with the right title, sentence and button labels ("Explore the model" / "Open workspace", "Learn by doing" / "Start tutorial", each with Close); Close, Escape and the backdrop each return to the unchanged menu with the focus on the button that opened it; Continue navigates once (nine tabs for the workspace, Part 1 step 1 with "Results updated." for the tutorial); six rapid opens leave exactly one overlay and four rapid Continue clicks on the same button still navigate once; Tab and Shift+Tab wrap inside the overlay (Open workspace → Close → Open workspace), a programmatic focus on the menu behind it is refused, the background menu buttons report inert while it is open and zero `[inert]` remain after every close path; a fetch/XHR spy recorded no request while opening or closing either overlay and the sidebar still reported "2 of 9 analyses stored" afterwards; no console or page error appeared. Under `prefers-reduced-motion` the overlay is present with 0 s transitions and the press transform computes to `none` instead of a jump. The Download results page was measured with no analyses run and with two stored: the group is centred while it fits (equal auto margins inside the content area — 47.4 px at 1000 px tall), starts at the top and scrolls when it does not (a 777 px card in a 620 px viewport leaves the top at 48 px with `scrollHeight` 905), keeps its 32/40 px padding with the vertical centring dropped below 1024 px, and shows no horizontal overflow at any width; `#export-title` is absent from the dashboard and from the tutorial in every case, and Escape and Back both return Home. The welcome question and the app's other dialogs are unchanged (its own `modal` classes, 0.19 s timing, focus contained and returned to the selected tab). Not verified: the Shiny application (untouched); the hosted deployment (unchanged, nothing was committed, pushed or deployed); the touch branch of the menu's hover handling beyond the declaration-level check described above, since this Chromium would not emulate the `hover` media feature and no real touch device was used; the app under `prefers-reduced-motion` beyond the two behaviours above (the overlay appearing at once and the press transform being dropped); and any browser other than Chromium |
| 2026-10-15 | The frontend release, through the existing workflow: the accumulated presentation work (`fe0ebd0`) and the dialog focus containment (`213072e`) were merged into `main` as `ea192dd` (PR #4, no branch protection and no required checks on `main`) and published by `Deploy frontend` run 7 — release `7-ea192dd5fb193a6ada5ceb88929adebc1d92fef2`, replacing `6-38aa15e…`. The `Deploy to production` job waited for the production environment's approval (00:40:55 to 00:43:00) and then activated the release, verified the bundle checksum, and validated the public site: `GET /`, `/app` and `/about` each returned 200 *and* each served the new bundle, and `/api/health` reported `status: ok` | Production verification, done independently of the workflow's own step. `https://openhealth.ngo` serves `/assets/index-B8vbHfDF.js` (896,467 bytes) and `/assets/index-DZqI3MQc.css` (51,486 bytes), both byte-identical (sha256) to a local build of the merged commit; the bundle carries `page-entry`, `result-trace`, `tabs__indicator`, `tut-stage`, `download-notice`, the loading-line block and the containment code (`[inert]`, `focusin`), and neither `debugReveal` nor `RevealDiagnostic`, and `/?debugReveal=1` renders no diagnostic. Live in the browser: the landing page with its footer `Blog` link; blog index → post and post → index each with the 160 ms page-entry fade measured mid-move (`is-entering-b` / `is-entering-a`, opacity 0.91 / 0.96), with the published post at `/blog/release-of-eqalb-and-openhealth`; `/app` Home → dashboard with a base-case run returning €2,439.00 incremental cost, 0.0082 QALYs and an ICER of €298,966, the 224 × 19 px ECG trace animating under the heading and the per-analysis export button present; the welcome question containing the focus (its first action focused, the page entry and dev script inert, the header refusing the focus, Tab wrapping, "Open analysis" returning the focus to the selected analysis tab) and the PSA confirmation containing the focus (Continue focused, the app header, sidebar and tab strip inert, Tab wrapping, Escape returning the focus to the Run PSA button with **no run started**); Download results rendering only on its own view, reached from the app Home screen with the focus moved to its heading, and absent from the dashboard; the tutorial loading and a Next move playing `is-leaving is-forward` → `is-idle is-forward` with one step in the document and the arriving heading focused; and a 100-iteration PSA (~14 s) showing the factual `Running the probabilistic sensitivity analysis…` line over three different lighthearted lines with no consecutive repeat, the card holding one height (167 px) and being removed as the run completed. Not verified on production, and stated as such: the tutorial Part 2 dialogs (case facts, congratulation), reduced-motion and print behaviour, the disabled-opener and unmount-while-open containment cases, and any browser other than Chromium (the deployed JS and CSS are byte-identical to the locally verified build), and the model inputs a browser session changes are session-local |
| 2026-10-15 | The dialog focus containment the previous release stopped for, frontend only: the four real modals (the welcome question, the PSA confirmation, the case facts and the congratulation) now keep the keyboard to themselves. One new composable, `composables/useModalFocus.ts`, and one wiring line plus a `ref` per dialog in `App.vue`, `CostEffectivenessPanel.vue` and `Part2View.vue`; the dialogs' existing motion, Escape, Cancel, Confirm, close-button and backdrop behaviour, wording and requests are untouched, and the focus moves that used to sit in each dialog's open path (four `nextTick` calls) now belong to the composable. On open the focus moves to the dialog's own first action; Tab and Shift+Tab wrap inside; every element outside the dialog becomes `inert` — through the dialog's relatives, never through an ancestor, so a dialog can never inert itself — with each element's prior state remembered and restored; on close the focus returns to the opener, or to the selected analysis tab for the welcome question (which is asked on arrival and has no button to return to), or stays where it is when the opener is the run button `Continue` has just disabled. Nothing is restored into a page that was left. A dialog whose leave is cancelled by a quick reopen clears its own `inert` on the way back in, so a reopened dialog can never be left switched off | `npm run typecheck`, `npm run lint` and `npm run build` pass and `git diff --check` is clean. Measured in the running app on all four dialogs: opener → contained Tab and Shift+Tab (PSA: Continue → Cancel → Continue wraps; facts: Tab stays on Close) → background controls refused the focus (the app header's Home button, a tab, the assumptions panel, the stepper, the tutorial's Exit) → every close path (Confirm, Cancel, Close, Escape, the backdrop) returned the focus (the PSA run button, the Case facts trigger, the stepper's Recommendation button, the welcome question's fallback tab) with zero `[inert]` left → a real pointer click over the header's Home button reached only the backdrop and did not navigate → a disabled opener left the focus on the body instead of on a disabled button → a Back navigation while the facts overlay was open unmounted the page with zero `[inert]` left and the app usable again → the facts overlay reopened inside its own leave fade was not inert, focused, tab-trapped and closable → under reduced motion the same containment held and the dialog element was removed 24 ms after closing, behind no fade. No console or page errors during two full dialog cycles. No 1,000-draw PSA was run for a focus check |
| 2026-10-15 | The page-entry fade, frontend only: a page now fades in when an internal link or button moves the visitor to it, over 160 ms and opacity only, and the accumulated frontend polish work — the result ECG trace and its summary entrance, the tutorial step transitions, the sliding tab indicator, the disclosure expansion, the analysis-button pending states, the download feedback, the dialog transitions, the 24-message loading line with its 7 s rotation and crossfade — is released with it. Three files carry the fade: `composables/usePageEntrance.ts` (new: which entries fade, and the five that do not), the `.page-entry` wrapper and the composable wiring in `App.vue` (the wrapper holds the page content only; every fixed overlay stays outside it), and the `.page-entry` rules in `styles.css`. Two identical keyframes are alternated, because an animation only replays when its name changes. Nothing about navigation, history, scroll restoration, inputs, results or the address was touched | `npm run typecheck`, `npm run lint`, `npm run build` and `git diff --check` all pass. In the browser, per frame: the class lands with the DOM update and the animation's own duration measured `160ms` with opacity 0 → 1 (`page-entry-b`, currentTime 0→122 ms of 160 ms, full at 144 ms), then the class clears at 480 ms — the safety window, not the animation. The moves verified with the fade: blog index → post, post → index, blog → landing, landing → blog, Home → dashboard, Home → tutorial, Home → download results (`is-entering-a`/`-b` alternating, opacity 0 → 1). The moves verified *without* it, each by design: a first paint (0 animations on load), a same-entry click ("Blog" while on the index), Back/Forward (landing scrolled to 1500 → blog → Back restored 1500 with 0 animations), the landing page's crossing into the app (the wrapper stayed class-less through the whole launch, which ran its own `launch--looping`/`launch--leaving` and handed over at 831 ms), the Home screen (dashboard → Home: no fade) and a scrolled arrival (About at 260 → landing: no fade, scroll preserved, header still at top 0). Rapid navigation (three moves inside one fade) ended on the last page at opacity 1 with one wrapper and no leftover class. Reduced motion: 0 animations, `animationDuration: 0s`, opacity 1 immediately; print: `animation: none`. Fixed chrome: on blog → landing the landing page's header measured top 0, left 0, width 890 on every frame of the fade; the download notice is outside the wrapper and still sat in the window corner after a CSV export. No regression found: the result trace is still one 224 × 19.2 px strip with its three animations and the same values, a tutorial Next still ran `is-leaving is-forward` → `is-entering is-forward` with one step in the document and focus on the arriving heading (the wrapper stayed class-less), the tab indicator stayed aligned with no page fade, the CSV export notice still reported `Download prepared.` with `role="status"`, the download results view still renders only on its own page (absent from the dashboard), and 390 px had no horizontal overflow. Not claimed: no second published post exists, so post → post could not be exercised in the app — the slug is the only thing that differs in the entry key, and the index → post move is the same path; and the earlier finding that a dialog does not contain the focus is unchanged and is now recorded as a release blocker (see Known limitations) |
| 2026-10-15 | The rotating loading messages refined, frontend only and left unstaged; nothing else of the approved polish pass was touched (the only three files written were `composables/useLoadingMessages.ts`, `components/AppLoadingIndicator.vue` and the `.app-loading__quip` block of `styles.css`). The pool grew from six sentences to 24 — the original six plus the eighteen the author supplied, in one list, with the playful lines kept away from anything clinical, validated or resembling progress. The interval became **7 s**, measured between the starts of two changes, with the 1 s grace unchanged, and a change is now a **crossfade**: the composable hands the component the message on screen plus, for the length of the swap, the one it is replacing, and the two fade over each other — the outgoing over 150 ms and the incoming over the same 150 ms after a 130 ms delay, 280 ms in all (`FADE_MS`) — so the two are never both legible and the swap never leaves a blank gap. Every message is rendered in one grid cell, so the line's area is as tall as the longest of them at the current width and neither the first message arriving nor a change of message resizes the card; a new `matchMedia` listener on the motion preference stops the rotation and cancels a crossfade in flight when reduce is turned on during a wait, and resumes it when the preference is turned off again | `npm run typecheck`, `npm run lint` and `npm run build` all exit 0 (the pre-existing >500 kB chunk notice unchanged). Verified in the browser on the dev server, with the wait held open by the page's own `fetch` wrapper answering from a payload captured in a genuine run — a deferred response on the test side never reaches the page here, which is itself recorded in Known limitations. **Cadence:** the card at 2.53 s, the first message visible at 3.81 s (1 s grace + the fade), then changes at 10.84 s and 17.83 s — gaps of 7024 ms and 6993 ms — and a 40 s wait produced four changes in all, each 7 s after the last. **Crossfade:** sampled every 10 ms around each change, the outgoing line runs 1 → 0 over 150 ms while the incoming runs 0 → 1 from 130 ms to 280 ms; across every sample the two never exceeded **0.06 opacity together** (no legible overlap) and no frame in the whole 40 s had the card up with nothing readable on it (`blankFramesAfterFirst: 0`, over 3200 sampled frames). **Lifecycle:** 1 rotation interval created for a whole wait and 1 cleared when it ended (`activeLeft: 0`), no interval restarted by a render or by navigating Home mid-wait, the card and its messages carried on across that navigation (200 ms of them still visible after the click), and a response landing **inside** a crossfade removed the card in the same frame the result committed (`resultCommittedAt` 10684 ms, `cardGoneAt` 10684 ms, 0 ms apart). **Rest of the requirements:** a request that finished before the grace showed no bar, no card and no message at all (151 samples, card 0); the pool showed no consecutive repeat in any run; a 360 px viewport had zero frames of horizontal overflow, the card held one height (146.3 px) for the whole wait and the line's area equalled its tallest line (37.4 px), and the same held at 1280 px; under `prefers-reduced-motion` one static message appeared after the grace with 0 animations and opacity exactly 1 for 54 samples, and turning reduce **on** during a wait cleared the interval at 7044 ms with the crossfade cancelled and no message change for 8 s, while turning it **off** re-created the interval and produced the next message 7 s later. Not claimed: the crossfade was measured frame by frame, not watched at speed |
| 2026-10-15 | The approved interaction-polish pass, frontend only and left unstaged: a sliding active-tab indicator, smooth expansion of the existing disclosures, pending states for the nine analysis buttons, quiet feedback after a download is prepared, and refined dialog entrances and exits, plus the lighthearted loading messages. New: `composables/useTabUnderline.ts`, `composables/useLoadingMessages.ts`, `composables/useDownloadNotice.ts`, `composables/useDialogTransition.ts`, `components/ButtonLabel.vue`, `components/DownloadNotice.vue`; `styles.css` gains the `--motion-fast` / `--motion-base` / `--ease-move` tokens and the `.tabs__indicator`, `.btn-label`, `.dialog-*`, `.notice-*`, `.download-notice` and `@supports selector(::details-content)` disclosure blocks; the nine panels swap their run buttons to `ButtonLabel` and the three CSV buttons report through `prepareCsvDownload`; `App.vue`, `CostEffectivenessPanel.vue` and `Part2View.vue` put their four dialogs behind the shared transition; `DownloadResultsView.vue` reports preparation honestly (`role="status"` on success, `role="alert"` on failure). One defect found and fixed while verifying: the global `* { transition: none; animation: none }` reduced-motion rule does not reach pseudo-elements, so the new chevron and the animated `::details-content` box were still animating under `prefers-reduced-motion`; both are now stilled, the content box inside its `@supports` block | `npm run typecheck`, `npm run lint` and `npm run build` all exit 0 (the pre-existing >500 kB chunk notice unchanged). **Indicator:** placed from the selected tab's own box (left/width deltas ≈ 0 including the selected weight, measured after fonts are ready), sliding 190 ms between two tabs on the same row and jumping in one frame across a wrap, on resize (2 rows at 900 px, 5 rows at 390 px with the bar 167 px matching the active tab and no overflow) and on the first placement; `aria-hidden`, `pointer-events: none`, roving tabindex and keyboard selection unchanged, and the destination panel arrives in the same tick as the click (before the indicator moves). **Disclosures:** sampled per frame, an open grew 0 → 335 px of content box (29 distinct heights, ~205 ms) to the details' real 399 px with `scrollHeight === clientHeight` and the last child 23.4 px inside the box (nothing clipped or scrolled), the chevron rotated 45° → −135° through its own 150 ms, and a collapse ran 399 → 40.7 px with `content-visibility` landing on `hidden`; closed, the 243 px table inside is out of layout and cannot take focus. **Buttons:** idle, pending and restored sizes identical to a tenth of a pixel (208.4 × 36.5 for the PSA, 177.8 × 36.5 for survival) and the accessibility name is exactly one label at a time (`Run PSA` → `Running 100 iterations…` [disabled] → `Run PSA`; `Run survival simulation` → `Simulating…` → back), with the inactive label `visibility: hidden`; a real pointer click on a pending button produced no second request, and a failed request restored the label, showed the existing "Cannot reach the model service…" message and left the result in place. **Download notice:** "Download prepared." with the filename, `role="status"`, focus unmoved, entered through the Vue `notice-enter-*` classes with its 150 ms opacity and 4 px transforms, gone by ~7 s; a forced blob failure produced "The download could not be prepared." with `role="alert"` and no auto-dismiss; the package view reported "Results package prepared: …, with N files." (`role="status"`) and "The results package could not be prepared in this browser: …" (`role="alert"`) with no duplicate corner notice. **Dialogs:** a fade plus a few pixels over 190 ms, initial focus on `Continue`, Escape and the backdrop both closing, the leaving element `inert` with `pointer-events: none` on its backdrop and removed from the document afterwards, three rapid open/close cycles leaving no stray modal, no leftover `[inert]` and a fully usable page, and reopen working. Not claimed: no focus trap and no focus return exist in these dialogs (unchanged, documented in Known limitations); the entrance/leave were measured frame by frame rather than watched at speed. **Loading messages:** against a request held open by a test-side delay — the bar at ~450 ms, the card at 2.5 s, the first message at ~3.6 s (1 s grace), four distinct messages at ~8 s intervals, `aria-hidden="true"` on the message with `role="status"` on the factual label and none on the card, and prompt removal when the request settled; a request that finished in ~1 s showed no bar, no card and no message at all; a 100-iteration PSA run repeated 5 of the 6 sentences with no back-to-back repeat. **Reduced motion:** tabs, chevrons, the disclosure content box, the notice and the launch at `0s`/`none`, a disclosure opening in a single step at 399 px, the result trace never drawn with its summary at opacity 1 on the first frame, no bar and no card for a fast run, one static message held for the whole 14 s wait, and a tutorial Next with no `is-leaving` phase, arriving immediately with focus on the new heading. **Approved work preserved:** the result trace is still one 224 × 19.2 px element even when a run lands mid-animation, replays on each successful run and never on a theme or tab change; the tutorial still leaves in 180 ms and enters in 220 ms with opposite directions, one step in the document, the arriving heading focused, rapid Next landing on the last requested step, and inputs, results and open state kept across Back and Forward; the Download results view still renders only on its own page and the landing page, `/blog` and the favicon are untouched (no file of theirs appears in `git status`) |
| 2026-10-15 | The result animation was replaced with the requested treatment; the approved tutorial step transitions are untouched. `frontend/src/components/ResultAccent.vue` (deleted) and its `.result-accent` styles are gone, and `frontend/src/components/ResultTrace.vue` puts a slim reserved strip **between each panel heading and its description**: one short line carrying a single P-QRS-T complex in the app's own teal, whose draw and a soft teal highlight (a 14-unit round-capped dash with a two-pixel local drop shadow) run along the same path over the same 780 ms with the same linear timing, so the drawn tip and the highlight's leading edge are the same point; the strip then fades away over 180 ms and the heading is left clean — no icon, no underline, nothing left behind. The nine panels each lose the element from inside their `h2` and gain it under it; `styles.css` replaces the accent block with `.result-trace*` (and changes the summary fade from 220 ms to 240 ms within the requested range), and `@media print` now removes the strip outright and restores the heading's own bottom margin so a printed panel keeps the spacing it had before the strip existed. Nothing else changed: the trigger (`useResultEntrance` + `resultRevisions`) is reused unchanged, no file of the tutorial work was touched, and no request, input, calculation, threshold, routing, dependency, export or R/API file was modified | `npm run typecheck`, `npm run lint` and `npm run build` all exit 0 (the pre-existing >500 kB chunk notice unchanged). Verified in the browser on the dev server (127.0.0.1:5173, started outside this session and left alone). **The effect, per animation frame:** a run produced the three animations (`result-trace-a`, `result-trace-line-a`, `result-trace-pass-a`), the strip's opacity went 0 → 1 → 0, and over the whole pass the line's drawn tip and the highlight's leading edge agreed to the frame (largest gap 0.0 of 100 normalised units); all three finished at their full durations (960 / 780 / 780 ms) with the strip back at opacity 0 and the line parked off-path (offset 101). **Trigger:** a second identical run switched to the `-b` names and played again; a run landing while the previous sequence was still playing restarted it on the same element with **never more than one strip and never more than three animations** (`maxStripElements` 1, `maxAnimationsOnStrip` 3, `maxTracesInHeader` 1, and only the two name-sets ever appeared); an aborted request and an HTTP 500 both left the class and the finished animation untouched with their error messages shown, and the next healthy run played normally; a tab switch removed the class entirely (fresh mount, already-shown revision), and a theme change and an input edit left `result-trace` with no animations, with the staleness notice shown as before. **All nine panels:** base case, PSA (100 draws), sensitivity analysis, budget impact, simulated survival, value of information, DHT readiness, value-based price and HTA decision summary each ran and each played the sequence, each with exactly one strip in its header and no `<svg>` left inside its `h2`; the old `.result-accent` count is 0 everywhere. **No shift or overflow:** the heading's width and the metrics grid's top were constant on every frame of a run; the strip's box is 224 × 19 px with opacity 0 in the idle state before any result exists, and at 390 px it stayed inside the panel (`x` 43, width 224) with `scrollWidth` equal to `clientWidth` (380) on every frame, in both themes. **Heading spacing:** the reserved strip is 19.2 px with the heading's own bottom margin removed, so a panel heading now sits ~24 px above its description instead of ~6 px; the frames were looked at in both themes at real size and enlarged, and the space reads as deliberate heading spacing rather than a gap. **Rendered frames were looked at, not only measured:** the sequence was frozen at 150 / 400 / 700 / 950 ms through the animation objects and captured — at real size and at ~3.4× — in light and dark, showing the trace appearing under the highlight, the single P-QRS-T complex reading clearly, the highlight's soft glow, the line visible in both themes, and the strip gone at the end. **Reduced motion:** with `prefers-reduced-motion: reduce` emulated the strip reported `animationName: none`, 0 animations, opacity 0 and its parked offsets, while the summary was at opacity 1 with `animationName: none` and the metrics visible on the first frame — results immediate, nothing drawn. **Print:** with print media emulated the strip reported `display: none`, the summary had no animation, and the heading-to-description gap was exactly the 5.6 px it was before the strip existed. **Tutorial unchanged:** `TutorialStepStage.vue`, `TutorialView.vue`, `Part2View.vue` and `useModel.ts` were not written during this change (file mtimes prove it), the tutorial contains zero strip elements, and a Part 1 Next/Back still reported `is-leaving` → `is-entering` → `is-idle` with one step in the document, a horizontal transform, focus on the arriving heading and no overflow. **Regression surfaces:** the Download results view still renders only on its own page (absent from the dashboard, one strip present), the landing page, `/blog` and the post all load unchanged with `/favicon.ico`, and no console error or warning was logged in any of these flows beyond the two deliberate failures. Not claimed: the production bundle was built but not previewed, and the frozen frames are captures of the rendered effect rather than a live viewing of the ~1 s animation at full speed |
| 2026-10-15 | Two restrained animation enhancements to the Vue app, frontend only and deliberately uncommitted: a one-shot result entrance with a decorative ECG accent, and smooth tutorial step transitions. Three new files — `frontend/src/composables/useResultEntrance.ts`, `frontend/src/components/ResultAccent.vue` and `frontend/src/components/tutorial/TutorialStepStage.vue` — plus an additive per-analysis `resultRevisions` counter in `useModel.ts` (bumped only when a run resolves, inside `run()`), the same four-line change in each of the nine analysis panels, the two tutorial views (whose step/section chains moved inside the stage and whose focus watchers were replaced by it), and the new `.result-reveal`, `.result-accent` and `.tut-stage` blocks in `styles.css`. All patient-visible behaviour, wording, calculations, inputs, thresholds, exports and routes are untouched; the ECG is `aria-hidden` decoration, not a signal or a progress indicator | `npm run typecheck`, `npm run lint` and `npm run build` all exit 0 (the pre-existing >500 kB chunk notice unchanged). Verified in the browser on the dev server already running for this repository (127.0.0.1:5173, started outside this session and left alone). **Result entrance:** a first `Run base case` produced the class `is-entering-a` and, sampled per animation frame, opacity 0 → 1 over the 220 ms fade with the accent's `stroke-dashoffset` running 100 → 0 over its 560 ms draw, ending still; a second run (identical numbers, same request) switched to `is-entering-b` and animated again; leaving the tab and returning re-mounted the panel with no entrance class and no animation object, so a tab switch does not replay it; an input edit that made the result stale, a light/dark change and a second module's run all left the class and the finished animation untouched. **Failure paths:** with `POST /api/base-case` aborted by request interception the panel showed "Cannot reach the model service…" and kept its class and finished animation; fulfilled with HTTP 500 it showed the simulated R message and did the same; the next healthy run then animated normally, so a failure neither plays the entrance nor consumes it. **No layout shift:** the `h2`, its subtitle, the panel actions and the metrics grid had byte-identical viewport boxes before and after a run, and at 390 px the accent (38 × 12 px box, teal `rgb(127, 209, 216)` at opacity 0.5, 1.4 px stroke) sat inside a one-line heading and inside the panel with no horizontal overflow. **Tutorial:** Next and Back on Part 1 both swapped the step with the stage at `is-leaving is-forward` / `is-leaving is-back` then `is-entering` (Forward travelling −x, Back +x), never more than one `.tutorial__step` in the document on any frame, no `scrollWidth` > `clientWidth` on any frame, no network request from a move (`fetch` instrumented), and focus on the arriving step's heading each time; three rapid Next clicks coalesced into Step 3 then Step 4 with the same guarantees and focus on Step 4's heading; a Next followed by a Back inside the fade cancelled the move with no `is-entering` and no content change; the step-4 "Finish tutorial" button moved to the completion card and "Restart tutorial" moved back to Step 1, both with the heading focused; a tutorial slider change persisted across Next/Back (370 and its updated ICER still shown on return) and re-evaluated once, while the moves themselves requested nothing. **Part 2:** all four section moves (brief → value → budget → readiness → recommendation) transitioned with the strip and navigation outside the stage, one section in the document, focus on each arriving heading; changing the price, the coverage and a readiness answer marked the three exercises done, and entering the recommendation opened the congratulation, which kept the focus ("Open analysis") through the section's `is-entering` and `is-idle`; "Back to the tutorial summary" returned to Part 1 with its completion card, step strip and results intact. **Reduced motion:** with `prefers-reduced-motion: reduce` emulated, a run left the summary at opacity 1 with `animationName: none` and the accent undrawn, and a tutorial Next swapped the step on the next frame (~41 ms) with no `is-leaving` phase and no animation at all; with motion restored, the leaving stage reported `pointer-events: none`. **Regression surfaces:** the Download results view still renders only on its own page (absent from the dashboard's DOM), the landing page, `/blog` and `/blog/release-of-eqalb-and-openhealth` all load unchanged with `/favicon.ico`, and no console error or warning was logged across any of the flows above (the only two logged events were the deliberate aborted request and the simulated 500). Not claimed: the checks are DOM, computed-style, animation-timing and geometry measurements rather than a look at the rendered page, so how the effects feel is the author's review; the production bundle was built but not previewed |
| 2026-10-14 | The blog's first post, *Release of eQalb & The introduction of OpenHealth!*, dated 2026-10-14. One new module, `frontend/src/content/blog/release-of-eqalb-and-openhealth.ts`, registered in `posts.ts`; the only other edits were documentation statements that said the blog had no posts (`frontend/README.md`, `FRONTEND_PLAN.md`, `frontend/src/content/blog/README.md` and this file). The text is the author's own, published exactly as written: no wording edited, nothing added, no links invented, and no summary — the body is nine plain paragraphs of the one block kind, with the "Till next time!" / "Mahmood" sign-off kept as its own two paragraphs. The slug `release-of-eqalb-and-openhealth` is derived from the title because none was preferred, and the date the author gave as 14/10/2026 is written in the format's `YYYY-MM-DD`. No style, component, composable, application or content-format code was touched, and the file was not committed or deployed | `npm run typecheck`, `npm run lint` and `npm run build` all exit 0 (the >500 kB chunk notice unchanged; the bundle grew by about 2 kB for the content). Verified in the browser on the dev server already running for this repository (127.0.0.1:5173, started outside this session and left alone). **Content format:** the post is one `BlogPost` with `slug`, `title`, `date` and a `body` of `{ kind: 'paragraph' }` blocks; it type-checks against `types.ts`, and the registry's newest-first ordering is a no-op with one post. **Index:** `/blog` lists it as `Release of eQalb & The introduction of OpenHealth!` linking to `/blog/release-of-eqalb-and-openhealth`, dated `14 October 2026` inside `<time datetime="2026-10-14">`, with no summary line — and the empty-state paragraph and dev-only note are gone. **Post page:** all nine paragraphs render character-for-character against the supplied text, checked by comparing every rendered paragraph with the expected string rather than by eye (typographic apostrophes in "I’ve" and "It’s" included); the titles are `Release of eQalb & The introduction of OpenHealth! — OpenHealth` and the `h1` is the title; the "← All posts" link points at `/blog`; the article contains no heading, list, quote or link elements, which is what the content asks for. **Navigation:** index → post and the back link both changed the page in place (a `window` marker survived), Back returned to the index and Forward re-rendered the post with all nine paragraphs. **Presentation:** the article was read at 1280×800 and 390×844 in both themes — dark `rgb(9, 9, 9)` on `rgb(236, 231, 223)`, light `rgb(244, 240, 232)` on `rgb(39, 35, 31)` — with no horizontal overflow at either width (`scrollWidth` 1270/1270 and 380/380), paragraphs left-aligned at ~17px/1.78 with no clipping of the long lines, and both the header links and the theme control visible at 390px. **Untouched surfaces:** a direct load and a reload of the post address both render it; `/blog/nope` still answers with the not-found state; the landing page still shows its three panels with the footer "Blog" link; `/app` still loads its Home screen with no landing attribute — and no console error or warning was logged at any point. Not claimed: the checks are DOM, computed-style and History measurements rather than a look at the rendered page, and the production bundle was built but not previewed |
| 2026-10-14 | Focused navigation correction to the blog, before publishing: following the blog's wordmark — an explicit link to `/` — now opens the landing page **at its top**, instead of leaving the reader at whatever scroll position the blog put the document in. Two files of code plus documentation: `frontend/src/composables/useAppView.ts` gains a third link handler beside the existing two, `followLandingLink(event)`, which pushes the landing page and then scrolls to the top **in the same turn** as the address — the shape `followPostLink` already used, and deliberately so: the landing page is taller than anything the blog shows, so the position the reader arrives at is already the top and the page that replaces the blog keeps it, whereas deferring the scroll past the turn let the browser record the leaving page as having been at its top and cost that entry its Back position (found by A/B testing the two shapes against each other). The scroll is explicitly `behavior: 'instant'`, so the landing palette's smooth `scroll-behavior` cannot animate it — and `frontend/src/components/blog/BlogLayout.vue`'s wordmark calls the handler instead of `followLink`. Nothing global changed: the store still forces no navigation to the top, `popstate` still only resolves the page and the slug, the blog shell's own mount reset is untouched, and the landing page's section anchors were not touched. Back and Forward are deliberately left to the browser's restoration, which was the point of putting the rule at the link rather than on the landing page; `/about` was left unchanged with no new entry point, and no theme, design, content format, app animation or unrelated file was touched | Repository-local: `npm run typecheck`, `npm run lint` and `npm run build` all exit 0 (the pre-existing >500 kB chunk notice unchanged). Verified in the browser on the dev server (127.0.0.1:5174), with a temporary post used only for this and deleted afterwards. **Explicit Home navigation, on its own:** with the blog index scrolled to 191 of a 411px document and the post scrolled to 120 — both times at a viewport where the header is off-screen above, so the page really is scrolled — following the wordmark put `/` at `scrollY` 0 with the landing page's first panel at the top of the viewport (`.landing` top 0), the document 1708px tall, the landing title set and `data-landing-theme` intact; repeated twice, identical. **Browser Back/Forward, separately, over repeated runs:** Back returned the blog index to **191** and the post to **120**, i.e. exactly where each had been, so the correction costs no history position; `/` scrolled to 1200, then the footer `Blog` link, then Back returned to `/` at 1208 with `#about-me` still in the address and the section still at the top of the viewport; Forward returned to the entry's own recorded position (0) rather than being forced anywhere; Back and Forward across `/`, `/blog`, `/blog/<slug>` and `/app` all left the document in one piece with no reload (a `window` marker set before each navigation survived it); and the post link's own path through the index was checked the same way (index 191 → post at 0 → Back → 191). A Control-click on the wordmark did **not** navigate in place (still `/blog`, same marker), so modified and middle clicks remain the browser's. **Measurement caveat, recorded because the first pass mistook it for a defect:** driving the wordmark with the harness's own click appeared to lose the blog's Back position (index returned to 0 instead of 191). Instrumenting `history.pushState` and `window.scrollTo` showed the scroll to 0 happened *before* the app's handler ran, because an automated click scrolls its target into view first — the header is at the top of the document, so bringing it into view scrolls the page there. Dispatching the click without that scroll-into-view, which is the state a real reader is in, keeps the position; the first pass's A/B comparison was therefore invalid and nothing about the page is at fault. **Landing-page section links:** `About me` scrolled the section to the top of the viewport and set `#about-me` with its `aria-current` marker, `Back to top` returned to `#eqalb` at 0, and a section position then survived the footer `Blog` link and a Back. **Untouched surfaces:** `/about` still resolves to the same page and title, `/app` loads its Home screen with no landing attribute and its four actions, and no console error or warning was logged across any of these steps. Not claimed: the checks are DOM, computed-style and History measurements on the dev server rather than a look at the rendered page, and the production bundle was built but not previewed |
| 2026-10-14 | The OpenHealth blog was added as a frontend-only surface at `/blog` and `/blog/<slug>`, and the landing page's bottom-right footer link is now "Blog" (it was "About OpenHealth"). Frontend only: no R, API, server-configuration, model, `package.json`, dependency or workflow file was touched, and nothing was committed. New files: `frontend/src/views/BlogIndexView.vue` (reverse-chronological list — title, date, optional summary, a quiet rule between entries), `frontend/src/views/BlogPostView.vue` (a link back to the index, the title and date, then the post's blocks in a narrow reading column, or a readable "Post not found" state naming the address), `frontend/src/components/blog/BlogLayout.vue` (the shell: wordmark to `/`, the `Blog` link, the landing page's own light/dark control, the same footer note, the blog's landing theme and the start-at-top rule for a followed page), `frontend/src/components/blog/date.ts`, `frontend/src/blog.css` (scoped under `.blog`, declaring no palette of its own and reading the landing tokens), and `frontend/src/content/blog/` — `types.ts` (the closed block set: paragraph, heading, list, quote, with link segments inside a paragraph), the registry `posts.ts` (a post is published by being listed there; an unlisted file is a draft) and `README.md` (the format and the add / preview / publish workflow). Changed: `useAppView.ts` (a `blog` page value, the `postSlug` ref, `/blog` in the title table, `blogPostPath()` and `followPostLink()`, `cameFromHistory()`, and `/blog/<anything>` recognised as an address instead of being rewritten to `/`), `App.vue` (two named branches, plus `app--landing` for the blog's full-bleed layout), `main.ts` (`blog.css`), `styles.css` (one comment), `useLandingTheme.ts` (a mounted-page count — see the fix below) and the three documents. Posts are typed data rendered block by block: no Markdown renderer and no HTML, so nothing is sanitised and no dependency was added. The registry is empty, so `/blog` shows a restrained empty state rather than a placeholder article, with a dev-server-only note pointing at the content README. **Defect found and fixed during verification:** `useLandingTheme` removed `<html data-landing-theme>` from every unmounting component, but Vue runs an unmounted hook at the end of the flush — after the arriving page's setup has set the attribute — so the landing page ↔ blog hand-overs stripped it from the page that had just arrived (the landing page's `.landing` background fell through to the app's `rgb(16, 26, 31)`). It now counts the mounted landing-themed pages and removes the attribute only when the last of them unmounts; the landing page alone behaves exactly as before | Repository-local: `npm run typecheck`, `npm run lint` and `npm run build` all exit 0 (the pre-existing >500 kB chunk notice is unchanged). Verified in the browser on the dev server (127.0.0.1:5174 — 5173 was already in use by another process, which was left alone and untouched). **Addresses:** a direct load and a reload of `/blog` give the title `Blog — OpenHealth`, the `Blog` heading and the empty state; `/blog/` resolves to the index; `/blog/does-not-exist` and `/blog/a/b` both render `Post not found — OpenHealth` at the address asked for, with `← All posts` back to the index; the landing page's footer link reads `Blog` with `href="/blog"`; `/about` still resolves directly and `/app` is unchanged. **Article path**, verified with two temporary posts (dated 2026-02-28 and 2025-01-01, deleted afterwards so no content is published): the index listed them newest first with `28 February 2026` and `1 January 2025`; the article rendered the heading, `<time datetime="2026-02-28">`, the summary, a section heading, paragraphs, a list and a quote with its source, an external link with `target="_blank" rel="noopener noreferrer"` and an internal link with neither, and the title `<title> — OpenHealth`. **Navigation:** the landing ↔ blog and index ↔ post links navigate in place (a `window` marker survived every step), Back and Forward moved between `/`, `/blog`, `/blog/<slug>` and `/app`, and a scrolled index (155px) opened the followed post at 0 while Back restored 155 and Forward reopened the post at 0. **Theme:** `data-landing-theme` is present as light and as dark on `/blog` and on a post, the blog's body renders `rgb(244, 240, 232)` / `rgb(9, 9, 9)` with the clay accent `#8c503b`, the landing page's own toggle still switches and stores the choice, and `/app` carries no landing attribute at all — its body stays on the app palette (`rgb(16, 26, 31)`) and `eqalb.theme` / `data-theme` stay `dark` whatever the blog is set to. The five hand-overs (landing→blog, blog→landing, index→post, post→index, blog→landing) all keep the attribute, and leaving for `/app` still removes it. **Layout:** no horizontal overflow at 390×844 and at 1280×800 (`scrollWidth === clientWidth`, no element past the viewport edge), paragraphs left-aligned (`text-align: start`) at ~17px with a 1.78 line-height, headings in the landing serif, and the navigation and theme control still visible at 390px. **No regression:** "Download results" still names itself and renders with no tablist, tabpanel or sidebar beneath it, and no console error or warning was logged across the blog, a post, a not-found address, the landing page, `/app` and `/about`. Not claimed: the checks are DOM, computed-style and History measurements against a source-checkout dev server, not a look at the rendered pages (no screenshot could be inspected in this environment) and not the production bundle or a deployed host; the About entry point on the landing page is gone by design, so `/about` is now reachable only by its address until that is decided |
| 2026-10-14 | The "Download results" view no longer appears under the analysis dashboard, and is now reachable only from Home. Frontend only, one file: `frontend/src/App.vue`. Root cause: the eQalb page chain in the shell ended with a bare `<DownloadResultsView v-else />`, so the view was the fall-through for every page the five named branches did not match — and `page === 'dashboard'` matches none of them, so the whole download panel (heading, "Available now" / "Not yet run" lists, its buttons) was rendered into the dashboard's own document directly below the dashboard body. The chain now names the page (`v-else-if="page === 'export'"`), so each page names itself and the download view exists only on its own page; how it is reached and what it does are unchanged (still only Home's "Download results", with Back and Escape returning Home). Because the page value is what mounts a view, entering the dashboard or the tutorial unmounts the panel and takes its controls out of the document instead of hiding them, and a history Back/Forward that resolves `/app` to `home` leaves no download state visible. No CSS, overflow, height or positioning change was made — the defect was the rendering boundary, not visibility — and no export, model, R, API, landing-page, transition or deployment file was touched. The view's own header comment now records that a page must not be the chain's leftover branch | Repository-local validation: `npm run typecheck`, `npm run lint` and `npm run build` all exit 0 (the build's pre-existing >500 kB chunk notice is unchanged). Reproduced and re-checked in the browser on the dev server (127.0.0.1:5173) and again on `vite preview` of the production build (127.0.0.1:4173). **Before:** on the dashboard, `#export-title`, both lists and the download button were in the DOM as siblings after `.app__body` (dashboard 104–933, export 933–1784, document bottom 1784) and the download button was at tabIndex 0. **After:** all nine analysis tabs, each scrolled to the document bottom with tab switching in between, report no export markup at all (`#export-title` absent, no "Download results package" button, zero focusable export controls) and the page bottom coincides with the tab panel (e.g. DHT readiness 1460 of a 1500 document). Home -> Download results shows the view and nothing else; Back returns to Home; Home -> dashboard shows no export markup; the tutorial's entry and exit never render it; 140 Tab presses on the dashboard reached no export control; dark (`rgb(16, 26, 31)`) and light (`rgb(244, 247, 249)`) themes and 390x844 plus desktop widths checked; landing page -> "Open the app" -> Download results -> browser Back (landing page, no export) -> Forward (`/app` resolves to Home, no export). **Export behaviour unchanged:** with the base case run the view listed 1 included and 8 pending and the download reported "Downloaded eqalb_results_2026-10-14_2035.zip with 3 files."; after a reload with nothing run it showed "Nothing has been run yet, so the package would contain only the README that lists what is missing." with all 8 analyses listed as not yet run. **Not claimed:** the automation harness captured no browser download event, so the ZIP's bytes were not inspected — the success sentence, which is written only after `buildZip` and `downloadBytes` return, is the evidence, and the export code itself is untouched. Published to `main` (fast-forward `f0b82b4` -> `9d3c7e8`) from the branch `fix/download-results-view-visibility`, and released by the existing `Deploy frontend` workflow: run [#5 / 38617581685](https://github.com/MoodyAlawi/eQALB-HTA/actions/runs/38617581685) succeeded in 2m43s on that commit, so production now serves `/assets/index-D3kOreHs.js` in place of the previous `index-DRJJWZjb.js`. Live re-check on `https://openhealth.ngo/app` against the deployed bundle: the defect was captured there **before** the release (the dashboard's document ran to 1763px and ended in "Download results package Back What the package contains, and what it does not") and is absent after it, on all nine tabs, at the document bottom, under both themes, at 390x844 and on desktop, in the tutorial, and across a browser Back/Forward round trip; Home's "Download results" still opens the view, Back still returns Home, the base case's per-tab CSV button and the package download ("Downloaded eqalb_results_2026-10-14_2048.zip with 3 files.") still work, and 60 Tab presses reached no export control. No deployment configuration, server permission, backend service, API code or R model changed |
| 2026-10-14 | The landing page's scroll fade is now reversible and repeats, replacing the one-time reveal that latched each group visible. Frontend only, left uncommitted on `feature/openhealth-landing`; alignment, copy, portrait, palette, themes, favicon, navigation and the app-launch transition are untouched. `frontend/src/views/OpenHealthHomeView.vue` drops the `settled` set and `settleTarget()` entirely, so nothing latches: `revealProgress()` becomes `enterProgress()` plus `exitProgress()` and a `revealFor()` that returns `min(entry, exit)`. Entry reads the wrapper's top edge (transparent at 90% of the viewport, fully opaque at 55%, linear between); exit reads the wrapper's **bottom** edge (1 until only the top 22% of the screen holds the group, 0 at the top), which is what stops a tall block being faded while it is still being read and what leaves the last section - which the document ends beneath - fully visible with no space added to force a fade. The lift moved to its own `--reveal-lift`, written from the entry alone, so content does not drift downwards as it leaves; `frontend/src/landing.css` reads `translateY(calc((1 - var(--reveal-lift, 1)) * 16px))` with the visible state still the `var(..., 1)` fallback. Focus outranks the scroll and is painted in the same turn rather than through a frame: `paintFocusChange()` cancels any pending frame and repaints, `paintReveal()` accepts either `:focus-within` or containment of `document.activeElement`, and `focusout` joins `focusin` so the scroll value returns when focus leaves. The `?debugReveal=1` panel now reports top, top/vh, bottom/vh, Entry, Exit and Opacity instead of a "Latched" column. `frontend/README.md` and this file were updated to match, including correcting a stale claim that the page still used proximity scroll snapping | Repository-local validation only: `npm run typecheck`, `npm run lint` and `npm run build` all exit 0, with the built CSS carrying the new `--reveal-lift` rule and no `latched` string anywhere in the JS. Verified with **real wheel input** (22 notches down, 20 up) at 1440x900, reading the painted opacity each step: OpenHealth 0.000 through y=260, then 0.041, 0.317, 0.594, 0.867, 1.000 (fade in), a 606px plateau of solid 1.000 from y=693 to y=1299, then 0.990, 0.555, 0.116, 0.000 as its bottom edge rose past 0.22vh (fade out) - all three phases in one traversal. Scrolling back up reversed it exactly (0.000 -> 0.212 -> 0.646 -> 1.000, plateau, 1.000 -> 0.810 -> 0.533 -> 0.257 -> 0.000) and a third downward pass faded it out again, so there is no latch. Stopping inside the exit ramp held 0.555 unchanged at 0ms, 600ms, 1200ms and 2400ms, and inside the entry ramp held 0.435 at 0ms, 1500ms and 3000ms, then completed on further scrolling - it is position, not a timer. About Me fades in the same way but never fades out: at the document's end its bottom sits at 0.706vh, above the 0.22vh exit threshold, so it stays at 1.000 - the required "keep it readable" case. Mobile checked at 390x844 (no horizontal overflow, About Me solid from 0.591 at entry through 1.000 to the end) and at 390x600 where the group is 1.33x the viewport: it passes 0.540, then holds 1.000 from 49% screen coverage to the document bottom, while OpenHealth on the same viewport runs the full fade in / 600px plateau / fade out. Reduced motion verified by emulating the real setting: everything at opacity 1 with `transform: none`, at the top and after scrolling to 1400, where the normal page reads 0.919 and 0.664. Print verified by emulating print media at a scrolled position where the screen shows 0.555 and 0.892: both read 1 with no transform. Keyboard verified with real Tab presses (focus reached "Email" after 3 presses, painted at opacity 1 and no transform) and with `focus({ preventScroll: true })` so the page did not move: 0 before focus, 1 while focused, 0 again after blur. The app-launch transition still runs end to end (overlay with `launch-veil-in`, `.landing.is-leaving`, then `/app` with the overlay and landing gone and the title changed), two full mount/unmount cycles logged no console or page errors and re-armed the reveal correctly, the OpenHealth label, heading and body all still centre on the same axis (centre 715 at 1440x900) with the heading still two lines, About Me still `text-align: start` in its grid, the portrait still borderless, and no horizontal overflow at either width. **Not claimed:** the screenshots are of the page content only, so the fade was judged from captured mid-fade stills plus the per-step opacity readings, not from a recording. No R, API, deployment, app-theme, dependency, copy, portrait, alignment or transition file was touched; nothing was committed, staged, pushed or deployed |
| 2026-10-14 | Corrected one attribute of the favicon markup: the `.ico` declaration's `sizes="any"` became `sizes="16x16 32x32 48x48"`, the sizes the file actually holds - `any` claims a scalable icon, which a raster `.ico` is not. `frontend/index.html` only, one line; the two PNG declarations and every generated image file are unchanged and were not regenerated. `frontend/README.md` and this file were updated to quote the new value | Repository-local validation only: `npm run typecheck`, `npm run lint` and `npm run build` all exit 0, and the built `dist/index.html` and the served HTML from both the dev server and `vite preview` carry `sizes="16x16 32x32 48x48"` on the `.ico` with the two PNG declarations unchanged. No image file, no other markup and no other work in the tree was touched; nothing was committed, staged, pushed or deployed |
| 2026-10-14 | The browser-tab icon is now the OpenHealth mark. Frontend only, left uncommitted on `feature/openhealth-landing`. The source, identified by inspection as the only newly added file in `frontend/src/assets/` and distinct from either portrait, is `onlylogo.png` (1024 x 1024, `Format32bppArgb`) with **genuine transparency rather than a white background** - 55.45% of pixels fully transparent, 38.51% opaque, 6.04% partial, all four corners `A=0`, centre `#D5A77D`, commonest opaque tones `#D0B080` / `#C09870` / `#D8B888` / `#B89068` / `#B87050` - and it is left unmodified. `frontend/public/favicon-16x16.png`, `favicon-32x32.png` and `favicon.ico` (16/32/48 px, 32 bpp) were generated with `System.Drawing` via a compiled throwaway C# helper, adding no dependency: each is cropped to the mark's content bounding box (889 x 888 at (66,67)) plus a 3% margin, so the mark fills 94.3% of the square, and box-averaged down with **premultiplied alpha** so the cut-out's edges take no fringe. A first pass was discarded because it scaled RGB by 255 and multiplied by 255 again, saturating every painted pixel to white (one distinct colour, luminance 254-255); the shipped files carry the real palette (89 distinct 5-bit colours at 16 px, 154 at 32 px, clay centres `#AC6D4E`/`#B07150`). `frontend/index.html` replaced its single SVG-favicon declaration with the `.ico` first (`sizes="16x16 32x32 48x48"`) then `favicon-32x32.png` and `favicon-16x16.png`, and `frontend/public/favicon.svg` (the stock Vite lightning bolt, `#863bff`, referenced nowhere else in the repository) was deleted so nothing takes precedence. `frontend/README.md` and this file were updated to match | Repository-local validation only: `npm run typecheck`, `npm run lint` and `npm run build` all exit 0. `dist/` contains `favicon.ico` (15086 B), `favicon-16x16.png` (991 B) and `favicon-32x32.png` (2841 B) with `favicon.svg` absent, and `dist/index.html` carries exactly the three new declarations with the title unchanged. The ICO was re-parsed byte by byte: header `reserved=0 type=1 entries=3`, each entry 32 bpp, planes 1, DIB heights 32/64/96 as required, and offsets running 54 -> 1182 -> 5446 with the last entry ending exactly at the file length; its pixel bytes match the standalone PNGs to within a delta of 1. The browser's PNG decoder was used as an independent check of the generator's own: no visible (alpha >= 128) pixel in the 16, 32 or 48 px icon exceeds luminance 235, and the brightest fully-visible pixel is the sand tone `#DBC091`/`#DEC399`; the only bright pixels are 14 at 32 px and 30 at 48 px carrying alpha 1 or 2 of 255 (<= 0.8% opacity), which are the source's own faint halo reproduced faithfully and are imperceptible, so the data was deliberately left as the source has it rather than stripped. Legibility was judged from rendered images, not from numbers alone: the source mark and the generated 16 and 32 px icons were displayed at actual size and magnified with `image-rendering: pixelated` against white, ivory `#F4F0E8`, stone `#E8E1D5`, `#090909`, `#121211` and simulated light and dark tab strips, and the mark reads as a clean circular form at both sizes with its detail and warm palette intact. Loading `/` in the shared browser tab, `document.querySelectorAll('link[rel~="icon"]')` returns exactly the three new links, `link[href*="favicon.svg"]` returns 0, and the browser itself requested all three with `responseStatus 200`; the icon URLs were also confirmed over HTTP against the dev server (`/favicon.ico` 200 `image/x-icon` 15086 B, `/favicon-16x16.png` 200 `image/png` 991 B, `/favicon-32x32.png` 200 `image/png` 2841 B). The same three URLs were then confirmed against the **production build** served by `vite preview` (200 `image/x-icon` 15086 B; 200 `image/png` 991 B; 200 `image/png` 2841 B), the served production HTML carries exactly the three declarations, and a browser loading it resolves those three links with no SVG reference and no dev diagnostic. `/app` was loaded and carries the identical three links with no SVG reference, its `data-theme` still `dark` with no landing theme attribute and its title unchanged, so the app's own theme and the landing page's isolation are untouched. **Not claimed:** the browser's own chrome was not captured - the screenshot tooling records page content only, so the mark was judged in a simulated tab strip rather than in a real one; and a `favicon.svg` request now falls through to the SPA shell, which is harmless because nothing references it. No R, API, deployment, app-theme, landing-page, transition, copy or reveal file was touched; nothing was committed, staged, pushed or deployed; the throwaway C# helper, the preview folder and its inspection page were deleted |
| 2026-10-14 | Diagnosed why the landing page's scroll fade is invisible to the author, and added the development-only diagnostic the brief asked for. Frontend only, left uncommitted on `feature/openhealth-landing`. **The cause is the address, not the code:** `https://openhealth.ngo` serves a bundle built before the landing page existed, so there is nothing there to fade. The deployed `index-DHn5KSsW.js` / `index-DoeXKmoo.css` (title "OpenHealth — accessible, practical health learning") contains no `--reveal` (0 occurrences), no `landing__reveal-inner` (0), no `landing--armed` (0) and no `mahmood-portrait` (0), while the local build's `index-Di0v34KJ.js` / `index-BlmOXbwG.css` carries 3, 3, 1 and 1; the deploy workflow's only automatic trigger is a push to `main` and this work is uncommitted on `feature/openhealth-landing`, so nothing built here can have reached the public site. No animation code was changed — the brief forbade another timing or range change before the cause was found, and none was warranted. Added `?debugReveal=1` in `frontend/src/views/OpenHealthHomeView.vue` plus `.landing-debug` styles in `frontend/src/landing.css`: a dev-only panel reporting the section in view, the reduced-motion preference, the scrolling element and offset, the armed state, and a row per section with wrapper top, top over viewport height, calculated progress, latch and computed opacity, behind an `import.meta.env.DEV` guard. `frontend/README.md` and this file were updated to match | Repository-local validation only: `npm run typecheck`, `npm run lint` and a production `vite build` all clean. The diagnostic was confirmed to render with the flag on the dev server, to be absent without it, and to be **absent from the production build even with the flag set** (verified on `vite preview`, itself confirmed to return the stale-free local build). Every other suspect in the brief was inspected on the live page and ruled out with evidence rather than assumed: reduced-motion `false`; `document.scrollingElement` is the document element with `overflow: visible`, so the listener is on the element that actually scrolls; the wrappers measured are the ones painted; the reveal is armed with a truthful initial `--reveal: 0` / `opacity: 0`; nothing overrides the painted element's opacity, which was read back from the element carrying the inline value; and there is exactly one painted content element per section. A previously unexplained observation was explained rather than left open: `--reveal: 1` at `scrollY: 0` in the author's tab is the latch working after an earlier scroll-through, not a premature trigger. Driving real keyboard input in the **author's own browser tab** reproduces the effect: OpenHealth steps `top 781px -> 0`, `745 -> 0.0797`, `705 -> 0.1891`, `665 -> 0.2986`, `623 -> 0.4135`, `584 -> 0.5202`, `542 -> 0.6351`, `502 -> 0.7445`, about 0.11 per key press with no jumps and the transform tracking exactly (`translateY(12.01px)` at 0.2493, `6.10px` at 0.6187, `0` at 1); About Me sampled at `0.041`, `0.258`, `0.323`, `0.342`, `0.348`, `0.351` while the scroll approaches its target, so an intermediate value is held rather than completed; reaching 1 and returning to the top leaves `opacity: 1`, `transform: none`, latched `true` while the geometric progress column reads `0`. Three screenshots of the author's own tab captured the OpenHealth content element at `--reveal 0.2493`, `0.6187` and `1` and the About Me element at `0.3505`, each state reading progressively darker. Reduced motion verified by driving the real setting in the author's browser (`emulateMedia({ reducedMotion: 'reduce' })`, reload, read back), not by reading the stylesheet: `matchMedia` `true`, both reveal sections `opacity: 1` / `transform: none` at the top and after scrolling to 900 (values of 0 and 0.35 a normal page would paint at), the hero outside the mechanism with its button at opacity 1. **Not claimed:** a screencast/video recording of the fade was not possible with the tools available, so the visual evidence is the three stills plus the per-step readings, not a recording; the live site was never a valid place to review this work, so no claim is made about how the landing page looks when deployed. No R, API, deployment, app-theme, dependency, copy, alignment, portrait or transition file was touched; nothing was committed, staged, pushed or deployed |
| 2026-10-14 | The landing page's reveal was replaced with a scroll-linked one, and the OpenHealth heading composed as two lines. Frontend only, left unstaged on `feature/openhealth-landing`. The timed system is removed outright rather than layered over: `frontend/src/views/OpenHealthHomeView.vue` drops `revealed`/`is-revealed`/`revealObserver` and instead writes a `--reveal` number (0 to 1) onto each section's inner element, computed from the section wrapper's top edge as a fraction of the viewport height (0 at 90%, 1 at about 47.5%, linear between, 16px lift), so the fade follows the scroll position instead of a duration; `frontend/src/landing.css` replaces the transition with `opacity: var(--reveal, 1)` and `translateY(calc((1 - var(--reveal, 1)) * 16px))` and adds `.landing__heading-line` blocks with the heading box centred (`margin: 1.5rem auto 0`, fixing a 48px offset the new block geometry exposed). Two elements do two jobs so the measurement cannot be skewed by the animation; work is batched into one `requestAnimationFrame` behind passive `scroll`/`resize` listeners cleaned up with any pending frame on unmount; the position is measured fresh each paint; `focusin` settles a section before a Tab reaches a link in it; the hero is outside the mechanism; and `landing--armed` plus the `var(--reveal, 1)` fallback keep every section visible if the enhancement cannot run. Scroll snapping was removed because it pulled small wheel notches back to a panel boundary and made an intermediate position impossible to hold. `frontend/README.md` and this file were updated to match | Repository-local validation only: `npm run typecheck`, `npm run lint` and a production `vite build` all clean, with `--reveal` and `landing__heading-line` in the built CSS and no `scroll-snap` or `700ms` transition anywhere. Measured at a 900px viewport, content-top (as a fraction of the viewport) against the inner element's computed opacity: OpenHealth `0.893vh -> 0.016`, `0.838 -> 0.147`, `0.782 -> 0.277`, `0.727 -> 0.408`, `0.671 -> 0.539`, `0.615 -> 0.670`, `0.560 -> 0.800`, `0.504 -> 0.931`, fully opaque from `0.449vh`; About Me the same shape from `0.890vh -> 0.024` to `0.501 -> 0.939`, fully opaque from `0.445vh`; steps even at about 0.13 per 50px, so nothing is front-loaded. Stopping mid-reveal at scrollY 435 held opacity `0.238` at 0ms, 400ms, 1200ms and 2400ms, then reached `1` on further scrolling and stayed `1` after reverse-scrolling and after returning to the top. Both heading lines occupy exactly one visual line at 320/390/430/768/1024/1440px, each centred on its container to 0px, in the serif face, with no horizontal overflow at any width and the About panel still `text-align: start`. Reduced motion and print both leave the sections at opacity 1 with no transform, the hero visible on load and the button still at `/app`. The "Open the app" crossing still runs end to end, and a fresh load logs no error, warning or failed request. The four access paths the brief names were driven directly rather than inferred: a real mouse click on the nav's "About me" link took both sections from 0.000 to 1.000 at scrollY 1800; focusing the About panel's contact link from `0.000` put it at 1.000 with the link focused and painted, and it stayed at 1.000 after blurring and scrolling away; a scroll position restored to 1500 - both by scrolling and by a reload with the offset applied - gave About Me its truthful intermediate 0.808 rather than sticking at 0; and loading `/#about-me` landed readable with the section at the top of the viewport at 1.000. **Not claimed:** the browser's own wheel was not part of the final measurement (positions were stepped and read, which is what the reveal is a function of), and no pixel-level judgement of the fade's feel was made. No R, API, deployment, app-theme, dependency, copy or transition file was touched; nothing was committed, staged, pushed or deployed; all one-off harnesses and browser profiles were deleted |
| 2026-10-14 | Two frontend-only landing-page corrections, left unstaged on `feature/openhealth-landing`. (1) The scroll fade-in was invisible because the reveal observer watched each section's full-viewport *panel* at a 0.15 threshold while the content is centred inside it: measured on the page, the OpenHealth panel fired at 129px of scroll but its content only reached the fold at 248px, so the transition ran to completion off screen. `frontend/src/views/OpenHealthHomeView.vue` now resolves each section's panel *and* content (`sectionNodes()`), keeps the nav observer on the panel and points the reveal observer at the **content**, triggering on its leading edge crossing the bottom fifth of the viewport (`rootMargin: '0px 0px -18% 0px'`, `threshold: 0`) so the trigger no longer depends on a ratio of panel area and holds at any section height. It also reveals anything already on screen at load instead of waiting for the observer's first callback. `frontend/src/landing.css` strengthens the effect to `opacity: 0` / `translateY(20px)` → `opacity: 1` / `translateY(0)` over 700ms with `cubic-bezier(0.22, 1, 0.36, 1)` and adds an `@media print` block so the whole page is shown on paper. (2) `.landing__inner--prose` gains `text-align: center`, so the OpenHealth label, heading and paragraphs centre to match the hero while keeping the 40rem measure; the About Me section and the hero are untouched, and no copy changed. `frontend/README.md` and this file were updated to match | Repository-local validation only: `npm run typecheck`, `npm run lint` and a production `vite build` all clean, with `translateY(20px)`, `.7s`, `cubic-bezier(.22,1,.36,1)`, `text-align:center` and the print block present in the built CSS. A fresh load logs no page error and no failed request (the `sectionNodes is not defined` console message was a hot-reload artifact of an intermediate edit and does not reproduce). A stepped scroll journey sampled every frame inside the page at 60fps recorded, for OpenHealth and About Me, the trigger firing with the content on screen (content top 497px and 593px in a 749px viewport), 33 intermediate frames each, a ~530ms visible fade with opacity 0.106 → 0.534 → 0.783 → 0.905 → 0.961 → 0.986 → 0.996 and the transform interpolating (ty=17.88 → 3.70 → 0.52), and no replay after settling or after returning to the top. A trusted CDP mouse-wheel run caught the fade mid-flight for About Me (0.463 → 0.703 → 0.905 → 0.953), and an isolated in-page test with the observer and wheel removed confirmed the stylesheet interpolates (13 distinct opacity values). Reduced motion, emulated over CDP, leaves all three sections at opacity 1 with no transform and a 0s transition, including the two off screen, with their text present. Live alignment check: OpenHealth label, heading and first paragraph all `text-align: center` with each last line's centre exactly on the block centre (delta 0); About Me still `start`; hero still `center`; no horizontal overflow; landing and app themes still independent. **Not claimed:** the wheel-driven measurement is unreliable in this headless environment - small wheel notches are undone by the page's own proximity snapping and the frame loop idles unless a paint is forced - so "obvious during ordinary mouse-wheel scrolling" rests on the frame-level recording and the partial wheel run rather than a full wheel-driven trace. No R, API, deployment, app-theme, dependency, copy, navigation or transition file was touched; nothing was committed, staged, pushed or deployed; and all one-off harnesses and their browser profiles were deleted |
| 2026-10-14 | Three frontend-only refinements to the landing page, left unstaged on `feature/openhealth-landing`. (1) The OpenHealth and About me sections are centred blocks: `landing__inner--prose` gives the OpenHealth column a 40rem measure and `.landing__about` a 56rem one, both centred by the `margin: 0 auto` they already inherited from `.landing__inner`, with `.landing__footer` sharing the About measure so its rule lines up with the content above it; the text inside each block stays left-aligned, and no card, border, background or container was added. (2) `.landing__portrait` lost its `1px solid var(--landing-divider-strong)` border and its 0.8rem radius, leaving no border, radius, background, outline or shadow, so the cut-out sits directly on the landing background; the file, import path, intrinsic size, alt text, 18rem cap and layout are unchanged. (3) The reveal is the same IntersectionObserver pattern - 480ms, a 14px lift, once per section, all three - but its hidden state is now scoped to a `landing--armed` class that `frontend/src/views/OpenHealthHomeView.vue` sets only when an IntersectionObserver exists to reveal a section again, its observer setup is wrapped so a failure reveals every panel instead of leaving one blank, and the `prefers-reduced-motion` block forces the end state rather than merely shortening the transition. `frontend/README.md` and this file were updated to match | Repository-local validation only: `npm run typecheck`, `npm run lint` and a production `vite build` all clean, with `landing--armed` and `landing__inner--prose` present in the built CSS and the bundle otherwise unchanged. Measured in the browser and in same-origin 390 / 768 / 899 / 900 / 1440px viewports: the OpenHealth block centred in its panel at every width (305/305 at 1260px, 395/395 at 1440, 59/59 at 768, 20/20 at 390) and the About group likewise (177/177 at 1260, 267/267 at 1440, 24/24 at 900 and below), the About columns 320 + 520 at 1440 and 320 + 466 at 900 and a single column below 900, the footer matching the About group's left and right edges at every width, and no horizontal overflow anywhere. The portrait measures 0px border, 0px radius, `box-shadow: none`, transparent background and `outline-style: none` in light and dark (its 3px computed outline-width is Chrome's unpainted initial value, the same on control elements). The entrance was sampled across a full scroll cycle: `eqalb` revealed at load, `openhealth` and then `about-me` as they came into view, and all three still revealed after scrolling back up and returning to the top, so it plays once and never replays. `prefers-reduced-motion` was emulated over CDP: all three sections at opacity 1, transform none and a 0s transition - including the two off-screen and never revealed - with `scroll-behavior: auto`, `scroll-snap-type: none` and the scroll hint's animation off, and the crossing a quick fade reaching `/app` in about 340ms. A second CDP run deleted `IntersectionObserver` before the page's scripts ran: the root then carried no `landing--armed` class, all three sections (two off-screen) sat at opacity 1 with their text present, and the call to action and portrait were visible. The "Open the app" crossing was re-timed after the changes (`/` with the overlay at 120ms, `/app` with the light looping at 1100ms, overlay gone by 1800ms). **Not claimed:** the portrait was not visually diffed against the original beyond the earlier alpha and geometry measurements. No R, API, deployment, app-theme, dependency, copy or transition file was touched; nothing was committed, staged, pushed or deployed; and the temporary probe page, the two one-off harnesses and their browser profiles were deleted |
| 2026-10-14 | The About me portrait is shipped as a web-ready derivative, frontend only, left unstaged on `feature/openhealth-landing`. The brief asked for an appropriately sized image rather than an unnecessarily large original, so `frontend/src/assets/mahmood.png` (the author's 1305 x 1206, 962 kB master) is now kept in place unused as the source, and the app imports the new `frontend/src/assets/mahmood-portrait.png` - the same image resized to 640 x 591 at 346 kB, a 64% reduction and a little over twice the 288px the layout can display it at - with the matching `width="640" height="591"` attributes in `frontend/src/views/OpenHealthHomeView.vue`. It had to stay a PNG: the original is a cut-out whose background is transparent (about 60% of its pixels, all four corners alpha 0), which JPEG would flatten, and Windows' image encoders expose no WebP to convert it to, so no dependency was added for one image. The resize preserves the alpha channel, the cut-out edge and the aspect ratio; the alt text, narrow-column placement, desktop/mobile layout, border treatment, copy and reveal animation are all unchanged, and `frontend/README.md` and the limitations and working-modules notes were updated to describe which file ships and why | Repository-local validation only: `npm run typecheck`, `npm run lint` and a production `vite build` all clean, with the bundle now emitting `dist/assets/mahmood-portrait-BCiKK700.png` at 353.80 kB instead of the 985.19 kB original, which is no longer emitted. Browser checks: the image resolves to the derivative and decodes at natural 640 x 591, rendering 288 x 266 at ratio 1.082 against the original's 1.0821; a canvas readback of the served file reports corners at alpha 0 and centre at alpha 253, so the cut-out survived the resize; the alpha histogram shows the same character as the source (59.6% fully transparent before, 59.8% after) and the centre pixel still opaque at alpha 253; in same-origin 390 / 899 / 900 / 1440px viewports it is above the text below 900 and beside it at 900 and 1440 (320px against 466px and 840px text columns) with `scrollWidth == clientWidth` throughout; both themes measure a hairline border with no shadow (light `rgba(39, 35, 31, 0.26)`, dark `rgba(236, 231, 223, 0.24)`); and the "Open the app" crossing and the panel reveal were re-checked as unaffected. **Not claimed:** the derivative was not visually diffed pixel by pixel against the original beyond the alpha and aspect measurements above, so a human should confirm the portrait still reads well at full size. Nothing was committed, staged, pushed or deployed, and the temporary probe page and one-off harnesses were deleted |
| 2026-10-14 | The About me portrait on the landing page, frontend only, left unstaged on `feature/openhealth-landing`. The author's own file is used as supplied (`frontend/src/assets/mahmood.png`, 1305 x 1206, 962 kB): `frontend/src/views/OpenHealthHomeView.vue` imports it (so the build fingerprints it, a missing file fails the build, and it is emitted as a separate 985 kB asset rather than inlined into the JS bundle) and renders `<img class="landing__portrait" alt="Portrait of Mahmood Alawi" width="1305" height="1206" loading="lazy" decoding="async">` in the About panel's first column under the name; `frontend/src/landing.css` gains the `.landing__portrait` rule (width 100% capped at 18rem, height auto, a hairline `--landing-divider-strong` border, a 0.8rem radius, no shadow). The intrinsic width/height reserve the box, so the prose beside the image cannot shift as the file loads; the image is beside the prose on desktop and stacks above it below 900px; the About copy and the panel's reveal animation are unchanged; and the previous note that asked the author for the file was replaced now that it exists | Repository-local validation only: `npm run typecheck`, `npm run lint` and a production `vite build` all clean (the build emits `dist/assets/mahmood-a5TepQJk.png`). Browser checks: the element renders with the exact alt text and the PNG resolves (200, `image/png`, 985,193 bytes); the box renders 288 x 266 from the attributes alone while `naturalWidth` is 0, then 288 x 266 again at natural 1305 x 1206 once loaded, so the ratio is preserved and there is no layout shift; at 1260px the image (right edge 312) sits inside the first column, left of the text column (left edge 400) and overlapping it vertically, so it is beside the prose; in same-origin 390 x 844, 768 x 900 and 1440 x 900 viewports it is above the text below 900 and beside it at 1440 (320px column against an 840px text column) with `scrollWidth == clientWidth` in the page, the About grid, the contacts, the footer and the navigation at every width; at the boundary, 899px gives one 841px column with the image above the text and 900px gives 320 + 466 side by side, still without overflow; the border measures `1px rgba(39, 35, 31, 0.26)` in light and `1px rgba(236, 231, 223, 0.24)` in dark with no shadow in either; and the "Open the app" crossing still reaches `/app` at 820ms with the light looping and the overlay gone by ~1.2s, with the About panel's reveal still firing. `prefers-reduced-motion` was verified by emulation rather than inspection: a one-off harness drove the Playwright-cached Chromium over CDP with `Emulation.setEmulatedMedia({ features: [{ name: 'prefers-reduced-motion', value: 'reduce' }] })`, and the page reported the media query as matching with `scroll-behavior: auto`, `scroll-snap-type: none`, all three panels at `opacity: 1` with `transform: none` and a `0s` transition, the scroll hint's animation `none`, the crossing's light `display: none` and the logo wipe `animation: none` with `clip-path: none`, `/app` reached by 360ms with no overlay left, and the app unaffected (`data-landing-theme` absent, `data-theme` still `dark`, `--accent` still `#7fd1d8`); the harness and its temporary browser profile were deleted. **Not claimed:** the image's weight — 962 kB displayed at ~288px is heavier than it needs to be, so a smaller export would still be worth having, and none was made because the author supplied this file. Nothing was committed, staged, pushed or deployed, and the temporary probe pages used for the responsive and motion checks were deleted again |
| 2026-10-14 | Six frontend-only landing-page refinements, left unstaged on `feature/openhealth-landing`. (1) "Open the app" now plays a crossing into the app: the landing page fades out, an overlay in the app's own palette wipes in a still copy of the Home screen's eQalb composition (the same `home__*` classes) behind a band of light, the light enters its looping state, and the overlay dissolves as the app's existing `home-rise` entrance fades the interface in; the new `frontend/src/composables/useAppLaunch.ts` owns the sequence (`LAUNCH_TIMING`: reveal at 820ms, dissolve by ~1.18s, safety clear at 2.4s) and `frontend/src/components/LaunchTransition.vue` renders it with the new "Landing page to app transition" section of `frontend/src/styles.css`. Both fades are CSS animations rather than Vue `<Transition>` classes: the first attempt used `<Transition>` and the overlay stayed at opacity 0 whenever the browser stalled its animation frames, which the rework fixes. The overlay is `aria-hidden`, holds nothing focusable and is `pointer-events: none`, the app is mounted and interactive as soon as the sequence hands over, modified/middle clicks still open the real `/app` link, and reduced motion drops the sweep and wipe for a quick fade. (2) The hero's simulated-data note is removed from the landing page only (the app keeps its own notices). (3) The OpenHealth copy is the supplied three paragraphs verbatim, and (4) the About me copy the supplied two paragraphs ("a health economics graduate"), both keeping plain paragraph spacing. (6) The per-panel entrance reveal is refined to 480ms with a 14px lift at threshold 0.15, once per panel, and is dropped under reduced motion. Item (5), the portrait, is outstanding by design: no image file exists in the repository, so no placeholder or generated image was used and the author is asked to supply one. `frontend/README.md` and `project_state.md` record the new files, the transition and the reason the portrait is absent | Repository-local validation only: `npm run typecheck`, `npm run lint` and a production `vite build` all clean, and the built CSS carries every new rule (5 launch animations, 6 `prefers-reduced-motion` blocks) with no `landing__note` left. Browser checks: the crossing sampled at 60/600/900/1150/1800/2600ms (veil opaque on `launch-veil-in`, landing at opacity 0, the logo wipe progressing, `/app` at 820ms with the light in `launch-sheen-loop`, the Home hero at opacity 0 then 1, overlay gone and the app interactive); a Ctrl-click left to the browser with no overlay started, `href` still `/app`; the reduced-motion branch on `/app` by 300ms; panel 1 revealed by the observer at load and the About panel on scroll with `aria-current` following; the landing theme toggling to light (page #F4F0E8, title #27231F, CTA #8C503B) while `eqalb.theme`/`data-theme` stayed dark; dark palette measured (#090909, #ECE7DF, #D39477); 390 / 768 / 1440px layouts with no horizontal overflow in the page, About grid, contacts, footer or navigation. **Not claimed:** the portrait image (no asset exists; not fabricated or substituted), and OS-level `prefers-reduced-motion` emulation, which this environment cannot perform (the media rules were confirmed in the CSS and through a stubbed preference). Nothing was committed, staged, pushed or deployed. A temporary probe page used for the responsive check was deleted again |
| 2026-10-14 | Frontend-only redesign of the landing page at `/`, left unstaged on `feature/openhealth-landing`. The mission-heavy OpenHealth landing page is replaced by one scrolling page in three panels - eQalb (the hero: the title, one line of description, the single action "Open the app" to `/app`, a simulated-data note and a scroll link), OpenHealth (a personal project, eQalb as its first step) and About me (Mahmood Alawi, one paragraph and the email/GitHub/LinkedIn details already in the project) - under a compact floating navigation panel that smooth-scrolls to each section, tracks the visible panel with an `IntersectionObserver` and marks it with `aria-current`, with a one-off fade-and-lift entrance per panel and the page footer inside the last panel. The landing page has its own light/dark theme (`frontend/src/composables/useLandingTheme.ts`, key `openhealth.landing.theme`, published as `<html data-landing-theme>`, set before the first paint on the landing addresses only and removed when the page unmounts), so it shares neither the app's teal palette nor `eqalb.theme`, and all of its styles are namespaced in the new `frontend/src/landing.css`; `frontend/src/styles.css` loses the now-unused `.oh*` block and gains `.app--landing`, `App.vue` adds that class for the landing page, and the landing page's document title and meta description were updated. Fonts are local stacks: no dependency, no external font request, no lockfile change. No R, API, deployment or generated file was touched | Repository-local validation only: `npm run typecheck`, `npm run lint` and a production `vite build` all clean. Browser checks against the running dev server: the three panels and the floating navigation; nav clicks scrolling to their section and moving `aria-current` (scrolling to the OpenHealth panel measured `scrollY` equal to that panel's offset, with the active link following); the entrance reveal firing once per panel; the theme toggle switching the landing palette from #090909 to #F4F0E8 while `eqalb.theme`, `<html data-theme>`, the body background and the app's teal `--accent` were unchanged, `data-landing-theme` absent and scroll snapping off on `/app`; a direct load of `/#about-me`; "Open the app" reaching `/app`; and `/about` unchanged. Layout measured in same-origin 390 x 844, 768 x 900 and 1440 x 900 viewports: no horizontal overflow at any width, one viewport per panel, proximity snapping on at 768 and 1440 and off at 390, the wordmark hidden at 390. The reduced-motion path was checked three ways: the rules parse under `@media (prefers-reduced-motion: reduce)` in the live CSSOM (smooth scrolling and snapping off, the reveal shown outright, the scroll hint's animation removed), they survive minification in the production bundle (5 `prefers-reduced-motion` blocks, `scroll-snap-type:none` in both the reduce and the 700px block, the reveal rules and the scroll-hint keyframes all present), and with the preference stubbed true the nav click jumped straight to the panel offset instead of animating. **Not claimed:** no pixel-level design review by the author yet; OS-level media emulation was not available in this environment, so the media query was verified in CSS and through the stubbed preference rather than by emulating the setting; and nothing was committed, staged, pushed or deployed |
| 2026-10-14 | Workflow-only fix for the first failed automated run, plus the state file. The first workflow reached the deploy job, where SSH public-key authentication and pinned host-key verification succeeded, then failed at "Upload the bundle to the incoming directory" with "lost connection"; activation and validation were skipped and nothing was published. Cause: the step uploaded `bundle/frontend-<release-id>.tar.gz` and its `.sha256` in a single multi-file `scp` call, and a multi-file legacy request also sends the `-d` flag (`scp -d -t /opt/eqalb/frontend/incoming` in the operator's verbose local reproduction), while the server's forced-command wrapper allowlists exactly `scp -t /opt/eqalb/frontend/incoming` and refused it with exit 64. Change: that step now makes two separate single-file legacy SCP invocations, one per file, each preserving `scp -O`, `-P "${DEPLOY_SSH_PORT:-22}"`, `-i "$HOME/.ssh/deploy_key"`, `-o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes` and the `${DEPLOY_SSH_USER}@${DEPLOY_SSH_HOST}:${REMOTE_INCOMING}` destination, with `set -euo pipefail` kept so either failed upload still prevents activation, and a short comment recording the wrapper's exact `scp -t` allowlist and the `-d` reason. The forced-command wrapper, activation script, permissions, secrets, concurrency, approval gate, validation and rollback steps are unchanged; `project_state.md` Known limitations, Current task, the migration entry's outstanding line and Next planned task were updated to record the failed attempt, the identified mismatch and the corrected upload, and that a successful end-to-end deployment remains outstanding | Repository-local validation only: `git diff --check` clean; changed files exactly `.github/workflows/deploy-frontend.yml` and `project_state.md`. **Not claimed:** the corrected workflow has not been re-run, so the two-transfer upload is unproven; no VPS, GitHub, secret, key or network access was used, and nothing was staged, committed, pushed or deployed |
| 2026-10-14 | Server-side migration and CI key rotation completed on the VPS, operator-performed, and recorded in the repository; the only repository change is documentation plus the tracked `deploy/Caddyfile` root line, now `root * /opt/eqalb/public/dist` to match the live file. Evidence recorded: Caddy runs as user and group `caddy`; `/opt/eqalb` remains `750 eqalb:eqalb` and was not widened; `/opt/eqalb/public` exists at mode `0755`, owned by `eqalb-deploy:eqalb-deploy`; ACLs are `eqalb-deploy` `--x` on `/opt/eqalb` and `/opt/eqalb/frontend`, `caddy` `--x` on those same two paths, and `caddy` `r-x` on `/opt/eqalb/public` and `/opt/eqalb/frontend/releases`, with no write access for Caddy anywhere; `/opt/eqalb/public/dist` is an `eqalb-deploy`-owned symlink to `/opt/eqalb/frontend/releases/initial-20261013`, and that release is still the active one; `/etc/caddy/Caddyfile` uses `root * /opt/eqalb/public/dist`; Caddy was validated and reloaded and `systemctl is-active caddy` reports `active`; public verification returned HTTP 200 at `https://openhealth.ngo/` and `/api/health` returned JSON with `"status":"ok"` and `"model_ready":true`. Key rotation: a new passphrase-free CI-only Ed25519 key was created locally, its public half installed in `/home/eqalb-deploy/.ssh/authorized_keys` behind the same `restrict,command="/opt/eqalb/bin/eqalb-frontend-deploy-wrapper"` restriction, tested for the legacy `scp -O` upload path and for refusal of arbitrary commands, the `production` environment secret `DEPLOY_SSH_KEY` updated to the new private half, and the old `eqalb GitHub Actions frontend deploy` authorized-keys entry removed so only the new `eqalb frontend CI deploy` key remains. `deploy/FRONTEND_DEPLOY.md` status block, §4.5, §4.7 and §10 and this file's Known limitations, Current task and Next planned task updated so the migration, ACL setup, public-pointer creation and key rotation are no longer described as outstanding, with the server state and verification recorded | Verified from the operator's own evidence, which is the source of every server fact recorded here. **Not claimed:** no automated workflow run has happened, the `production` environment's required-reviewer/approval rule is still to be confirmed with the operator, the pinned action SHAs are still to be confirmed with `git ls-remote`, and a live public-pointer swap under a running Caddy has not been exercised. Repository-local validation only in this pass (`git diff --check` clean; changed files exactly `deploy/Caddyfile`, `deploy/FRONTEND_DEPLOY.md` and `project_state.md`). Nothing was staged, committed, pushed or deployed by this pass |
| 2026-10-14 | Documentation-only correction of the Caddy service account's ACL on `/opt/eqalb/public`: it is now `r-x` (read-and-traverse) instead of traverse-only (`--x`), because Caddy must resolve the `dist` symlink name inside that directory, and the change is stated wherever the split is described (the §2 overview and the §4.2 traversal rule). The remaining split is unchanged: `eqalb-deploy` keeps traverse-only (`--x`) ACLs on `/opt/eqalb` and `/opt/eqalb/frontend`; Caddy keeps traverse-only (`--x`) on those same two parents and `r-x` on `/opt/eqalb/frontend/releases`, gains `r-x` on `/opt/eqalb/public`, and receives no write permission anywhere; `/opt/eqalb` stays mode `750 eqalb:eqalb`; and no broad `chmod` or world-access recommendation is added. §4.7's ACL block now applies `setfacl -m u:"$CADDY_USER":--x /opt/eqalb /opt/eqalb/frontend` and `setfacl -m u:"$CADDY_USER":r-x /opt/eqalb/public /opt/eqalb/frontend/releases` with the reason in its comment, and both verification blocks (step 2 before Caddy is touched, step 7 after activation) now prove Caddy can traverse and read `/opt/eqalb/public` and resolve the pointer with `readlink`, and that it can read the live release's `index.html` | Documentation-only: repository-local `git diff --check` clean; the changed-file list remains exactly the two documentation files from the previous pass. **Not verified and not claimed:** no ACL command has been run on the server, the Caddy service account has not been read on the server, the migration has not been performed, and no deploy, key, secret or GitHub setting was touched. Nothing was staged, committed, pushed or run |
| 2026-10-14 | Documentation-only correction of two facts, in `deploy/FRONTEND_DEPLOY.md` and `project_state.md` only; no workflow, script, Caddyfile or other file touched. (1) All instructions that would widen `/opt/eqalb` to `0755` are removed: the deployed server keeps `/opt/eqalb` at its existing restrictive `750` `eqalb:eqalb` mode, and the one-time Caddy migration (§4.7) now grants the deploy account `--x` traverse and the Caddy service account `--x` traverse plus `r-x` read/traverse of the release tree with **per-user ACLs** (`setfacl`, from the `acl` package, with `getfacl` evidence and `sudo -u <user> test` proofs), adds a read-only step to identify the Caddy service account first (`systemctl show -p User --value caddy`, `systemctl cat caddy`, `getent passwd caddy`) rather than guessing its name, notes that release directories are created 755/644 so no per-release ACL is needed, and records that the ACLs are additive and revertible (`setfacl -x`). (2) Every statement claiming no environment secret exists is corrected: the GitHub `production` environment and its six secrets are configured, while the corrected public-pointer topology, the CI key rotation, the Caddy migration and the first workflow run remain untested. The design is otherwise preserved exactly: `eqalb-deploy` still owns only `/opt/eqalb/public`, `frontend/releases` and `frontend/incoming`, with ACL traverse access to parents only, and Caddy gets exactly the traverse/read access it needs | Documentation-only: repository-local diff validation only (`git diff --check` clean; the changed-file list is exactly the two documentation files). **Not verified and not claimed:** the ACL commands have not been run on the server, the Caddy service account has not been read on the server, the migration has not been performed, and no deploy, key, secret or GitHub setting was touched. Nothing was staged, committed, pushed or run |
| 2026-10-14 | Corrective pass on the frontend deployment automation, repository-side only and left unstaged, implementing the approved public-pointer topology and the CI key decision. `deploy/frontend-deploy.sh`: the mutable path constant is now the Caddy-served `/opt/eqalb/public/dist` (plus `PUBLIC_DIR=/opt/eqalb/public`), the lock moved to `/opt/eqalb/public/.deploy.lock` inside the deploy-owned directory, a new `require_public_dir()` gives a friendly refusal when the directory is missing (called before the lock is opened and from `assert_dist_usable()`, which still refuses any existing non-symlink at the pointer), and the previous-error/notes wording now says "public pointer"; release-id, incoming-path, checksum, archive-content, staging, immutability, atomic-rename, two-operation and output behaviour are unchanged. `deploy/FRONTEND_DEPLOY.md`: layout and ownership updated to `/opt/eqalb/public` (deploy-owned) with `/opt/eqalb/frontend` traverse-only, the "do not chown the frontend tree" rule, no pre-created lock file, §4.4 rewritten for a passphrase-free CI-only Ed25519 key stored only as the protected `production` secret `DEPLOY_SSH_KEY` with refusal tests and a no-lockout rotation procedure, §4.6 converts a hand-built `dist` as root without chowning the frontend tree, new §4.7 is the ordered one-time Caddy migration (create `/opt/eqalb/public`, atomic pointer to the live release, move Caddy's root, validate and reload, verify `/`, `/app`, `/about` and `/api/health`, prove the permission split, roll the Caddy root back if it fails, remove the old symlink only after acceptance), §7 and §9 use the public pointer, and §10 records the outstanding migration, the deploy-owned blast radius and the releases' ownership caveat. `deploy/DEPLOY.md` §7 names the one-time Caddy root move as the sole adoption step and states `deploy/Caddyfile` stays unchanged until then. `.github/workflows/deploy-frontend.yml`: header comment only. `deploy/Caddyfile` deliberately untouched. `project_state.md` updated (Known limitations, Current task, Next planned task, this row) | Repository-local validation only, and it passed: `bash -n deploy/frontend-deploy.sh` clean; the script's behavioural suite, updated to the public-pointer topology, passed **50 of 50** checks (including the new missing-public-directory refusal and the real-directory-at-the-pointer refusal) in a sandbox whose only substitutions are `/opt/eqalb` -> a temporary prefix, a `flock` stub and a junction-backed `ln` shim, both gaps of this Windows checkout; the workflow YAML re-parsed and passed the 44 structural checks and its 18 `run:` blocks passed `bash -n`; `npm run typecheck` (one transient Windows crash on the first run, clean on re-run), `npm run lint` and `npm run build` all pass and the built `dist` contains no `.map` file; `git diff --check` clean. **Not verified and not claimed:** the topology has never run on a Linux host with real `flock` and the real forced-command wrapper, the one-time §4.7 Caddy migration has not been performed, no Caddy command was executed, and no secret, key or Environment setting was touched. `frontend/README.md` was left untouched because it is outside the approved file scope; its "serves ... from `/opt/eqalb/frontend/dist`" sentence becomes stale when the Caddy migration is accepted, at which point it should be updated. Nothing was staged, committed, pushed, deployed or run, and no package or lockfile changed |
| 2026-10-13 | Frontend-only deployment automation, Version 1, repository-side only and left unstaged. Added `.github/workflows/deploy-frontend.yml` (push to `main` on the `frontend/**`, `deploy/**` and workflow paths; Node 22; `npm ci --ignore-scripts`, `npm run typecheck`, `npm run lint`, `npm run build`; refuses `.map` files; packages `frontend-<run-number>-<commit-sha>.tar.gz` with a SHA-256 checksum verified before upload; `scp -O` into the fixed incoming directory; one fixed `activate`/`rollback` SSH command; `/`, `/app`, `/about` and read-only `/api/health` validation with automatic rollback to the reported previous release on any failure; `production` environment gate; single non-cancelling concurrency group; `contents: read`; all actions pinned to full commit SHAs; six placeholder environment-scoped secret names; `workflow_dispatch` limited to an optional `rollback_release_id`), `deploy/frontend-deploy.sh` (two fixed operations; validated release id; SHA-256 check; staging extraction under `releases/`; `index.html` requirement; no absolute or parent-relative archive entries and no symbolic links; group/world write bits removed; atomic `dist` symlink swap; previous release retained and reported; `flock`, `umask 022`, cleanup trap; no shell evaluation, wildcard deletion, download, package install, git, sudo, systemd, Caddy or API command) and `deploy/FRONTEND_DEPLOY.md` (manual bootstrap with a dedicated deploy account, directories, root-owned script, root-owned forced-command wrapper restricted to `activate`, `rollback` and the exact `scp -t` upload, key and `authorized_keys`, environment secrets and required approval, migration of an existing hand-built `dist`, deploy sequence, automatic and one-command manual rollback, retention, unverified status). `deploy/Caddyfile` now enables `try_files {path} /index.html` and corrects its stale no-router/deep-link commentary (API proxy, certificates, logging, compression, headers and TLS untouched); `deploy/DEPLOY.md` gains §7 and the warning not to run the in-place build once `dist` is a symlink; `frontend/vite.config.ts` sets `sourcemap: false`; `frontend/README.md` gains a Deployment section; this file records the same facts | Repository-local validation only, and it passed: `bash -n deploy/frontend-deploy.sh` clean; the workflow YAML parsed (no duplicate keys, no tabs) and passed 44 structural checks covering triggers, concurrency, permissions, pinned SHAs, the four build commands, the no-`.map` guard, checksum verification before upload, the environment gate, the fixed `activate`/`rollback` commands, the four URL checks and the six secret names; `npm ci --ignore-scripts`, `npm run typecheck`, `npm run lint` and `npm run build` all pass and the built `dist` contains no `.map` file; `git diff --check` clean; the changed-file list matches the approved scope exactly. **Not verified and not claimed:** no workflow run, no GitHub environment, secret or approval, no server installation, no deploy and no rollback has happened; the action pins are written from the actions' published releases and must be confirmed with `git ls-remote` on first use; the design assumes Caddy resolves the `dist` symlink per request. Nothing was committed, staged, pushed, deployed or run against GitHub or the VPS, and no package dependency or lockfile changed |
| 2026-10-13 | Frontend-only: the OpenHealth public shell. `frontend/src/composables/useAppView.ts` gained a pathname resolver for the three public addresses, a `history.pushState` entry per public move, a `popstate` listener, a rewrite of an unrecognised path to `/` and a document title kept with the page; `frontend/src/App.vue` renders two new views in front of its existing branches; `frontend/src/views/OpenHealthHomeView.vue` is the landing page at `/` and `frontend/src/views/AboutView.vue` is About OpenHealth at `/about`, while `/app` carries the whole existing eQalb application so its own Home screen, tutorial, project description, download view and dashboard keep their present behaviour and no internal screen has a deep link. `frontend/index.html` now carries the generic OpenHealth title and description, `frontend/src/styles.css` gained an additive OpenHealth block (the `.oh` rules and one 1023 px rule) and nothing existing was edited, and `frontend/README.md` records the three addresses plus the host fallback they need. The new copy states that eQalb is illustrative and educational and that OpenHealth is an early-stage education initiative, uses only the LinkedIn and GitHub addresses already in the interface, and claims no service, blog, community, partner, funder, user or achievement. No router and no new dependency; no model, API, R, Python, deployment, Caddy, systemd, environment, lockfile or generated `frontend/dist` change; every change left unstaged | Yes - `npm run typecheck` and `npm run lint` both clean; a production `vite build` into a temporary directory succeeded (removed afterwards, `dist/` untouched); browser checks against a local dev server covered direct load and reload of `/`, `/app` and `/about`, Back and Forward across them, `/nonsense/path` resolving to `/`, `/app/` with a trailing slash, the landing's Explore eQalb and Our mission links, Escape from About, light and dark themes with the choice persisting across a reload, a 390 px viewport with zero horizontal overflow, no console error from the new views, and the existing eQalb paths (the dashboard base case returned R's own €2,439 incremental cost, 0.0082 QALYs and €298,966 ICER from the local API, plus the tutorial, project description and download view). Not run: any PSA. No VPS, DNS, domain registrar, remote service or credential was accessed. The tutorial's Part 1 results request returned HTTP 404 in that session, which was traced to the local API process that was already running (started hours earlier and returning the same 404 to a direct `curl`), not to this change |
| 2026-10-13 | Documentation-only deployment closeout. `deploy/DEPLOY.md` §1.1 records the four system packages the first Ubuntu 26.04 compatibility run needed (`libuv1-dev` for `fs`, `cmake` for `nloptr`, `libsodium-dev` for `sodium`, `pandoc` for knitr/rmarkdown) and that the source-built R 4.5.1 restored all 135 packages. A short "Deployment closeout" section records that the stack is deployed and smoke-tested at `https://openhealth.ngo` but not fully validated: the frontend is served over HTTPS with a Caddy-obtained certificate, the proxied `/api/health` check returned HTTP 200 with `model_ready: true` and 2 of 2 R workers ready, browser smoke testing found no console errors, no failed API requests and working core interactions, and Caddy needs read and traverse access to the static frontend build directory. `project_state.md` records the same bounded facts and that operational performance testing remains open | Yes for the smoke-test facts, which come from the operator's own evidence. Deliberately **not** claimed: formal load, performance or security testing, clinical or model validation, or exhaustive functional testing. Documentation only - no application, model, API, frontend, Caddy, systemd, lockfile or environment change, and no simulated-data notice added. `git diff --check` clean, clean before commit |
| 2026-10-13 | Documentation-and-template pass: the source-build path for R 4.5.1 on Ubuntu 26.04, taken as a deliberate decision to preserve the runtime recorded in `renv.lock`. `deploy/DEPLOY.md` replaces the earlier "BLOCKING" section with a "DECISION: R 4.5.1 is built from official source into `/opt/R/4.5.1`" section that keeps the CRAN finding as its justification (this release's suite `resolute-cran40` serves the current R 4.6.x series; R 4.5 binaries are archived and documented only for Ubuntu 20.04; reimaging does not help). §1 is renumbered into §1.1-§1.5: one merged dependency list covering both base R and renv compilation (zlib1g-dev, libbz2-dev, liblzma-dev, libpcre2-dev, libreadline-dev, libcurl4-openssl-dev, libssl-dev, libxml2-dev, libpng-dev, libjpeg-dev, libtiff-dev, libcairo2-dev, libfontconfig1-dev, libfreetype6-dev, libharfbuzz-dev, libfribidi-dev, libicu-dev, build-essential, gfortran, pkg-config, texinfo), then §1.2 which downloads the pinned official archive `https://cran.r-project.org/src/base/R-4/R-4.5.1.tar.gz`, verifies SHA-256 `b42a7921400386645b10105b91c68728787db5c4c83c9f6c30acdce632e1bb70` with `sha256sum -c -` before extracting, checks the single top-level directory and the `VERSION`/`VERSION-NICK` markers, builds with `./configure --prefix=/opt/R/4.5.1 --enable-R-shlib --with-x=no` and `sudo make install`, verifies via `/opt/R/4.5.1/bin/Rscript --version` and `sessionInfo()`, and states the maintenance trade-off (no apt security updates; deliberate rebuilds). No apt R is installed at all - the CRAN repository, its key and the `r-base`/`r-base-dev` step are gone. §3.2, the failure-protocol evidence commands, the §5 binding audit and the §6 re-restore path now use the absolute `/opt/R/4.5.1/bin/Rscript`; checkpoint condition 2 demands exactly R 4.5.1 from that prefix; the failure protocol now explains how to read each condition instead of listing three options. `deploy/api.env.example` sets `EQALB_RSCRIPT=/opt/R/4.5.1/bin/Rscript` with the reasoning, and `deploy/eqalb-api.service` needed **no** change because it contains no R path and inherits the setting. `project_state.md` updated (Known limitations, Current task, Next planned task). No application code, model logic, frontend, Caddy configuration, request/response contract or Shiny file was touched | Yes - the archive URL and the checksum source were verified from primary sources before editing. `R-4.5.1.tar.gz` returns HTTP 200 with Content-Length 40518816 and Last-Modified Fri, 13 Jun 2025 07:12:01 GMT; CRAN publishes no per-file checksum or signature beside it (`R-4.5.1.tar.gz.md5`, `.sig`, `.asc`, `md5sum.txt`, `MD5SUMS`, `/src/checksums/` and `/bin/checksums/` all return 404), so the authoritative values were taken from the R Core Team's own release announcement at `https://stat.ethz.ch/pipermail/r-announce/2025/000713.html` ("[Rd] R 4.5.1 is released", Peter Dalgaard, 13 June 2025), which lists `R-4/R-4.5.1.tar.gz` as SHA-256 `b42a7921...ee8f444` and MD5 `e22eee30af90ec66eb179b66d122ffd9`. Those values were then confirmed against the actual artifact: the downloaded file hashes to the same SHA-256 and MD5, and its size matches the published Content-Length, so `sha256sum -c` is a genuine publisher-to-artifact check rather than a self-computed value. The archive was inspected without installing anything: it contains exactly one top-level directory `R-4.5.1/`, 5379 entries, `R-4.5.1/VERSION` reads `4.5.1`, `R-4.5.1/VERSION-NICK` reads `Great Square Root` (the codename in the announcement), and `R-4.5.1/configure` is 1788095 bytes at mode `-rwxr-xr-x`. The dependency list is grounded in the official R-admin manual (`https://cran.r-project.org/doc/manuals/r-release/R-admin.html`, "Essential and useful other programs under a Unix-alike"), which states that zlib, libbz2 and liblzma are "required", that libcurl "is required", that PCRE2 is preferred, that readline's headers are needed for command-line editing, that the jpeg/png/tiff devices "need the appropriate headers and libraries", and that the modern X11/jpeg/png/tiff devices use Cairo - which is why X11/Tcl/Tk is deliberately omitted (`--with-x=no`) and no LaTeX is installed. `git diff --check` reports no whitespace errors, and the document still has balanced code fences with its heading tree intact. The downloaded tarball and all temporary query files were deleted afterwards. Nothing was installed, no PSA was run, and no VPS, DNS, registrar, remote or credential was touched |
| 2026-10-13 | Documentation-only verification of the R installation section against the official CRAN instructions, with one blocking finding recorded. Source of truth: `https://cloud.r-project.org/bin/linux/ubuntu/` ("Install R" / "Installation Steps") and its linked `fullREADME.html` ("Installing R" / "# Installation") and `olderreleasesREADME.html`, read 2026-10-13. Two facts came out of it. First, Ubuntu 26.04 ("resolute") **is** a supported CRAN binary release for amd64 and arm64, and the suite really is `resolute-cran40`, so the name the runbook used was right. Second, and blocking, that suite serves the **current R 4.6.x series, not R 4.5.1**: the page states "Packages for the current R 4.6. release are available for Ubuntu 'Long Term Support' releases" and that "cran40 denotes a binary compatibility break by the R 4.0.* release, it does not install R 4.0.* but the current R 4.6.* series"; the R 4.5 entry is documented only as `focal-cran40` for Ubuntu 20.04, "no longer being updated... available for archival purposes", and the same applies to `noble-cran40`, so reimaging to 24.04 does not deliver 4.5.1 either. `deploy/DEPLOY.md` now carries a "BLOCKING" section stating this and keeping R 4.5.1 as the project requirement; §1 replaces the previous hand-rolled repository block with the official commands (software-properties-common + dirmngr, the signing key written to `/etc/apt/trusted.gpg.d/cran_ubuntu_key.asc` with a `gpg --show-keys` fingerprint check against E298A3A825C0D65DFD57CBB651716619E084DAB9, `add-apt-repository "deb ... $(lsb_release -cs)-cran40/"`, `r-base` plus `r-base-dev` with `--no-install-recommends`), and marks the stop point plus a warning never to point apt at another codename; checkpoint condition 2 now says plainly that it is expected to fail on a stock 26.04 install and is the decisive gate; the failure protocol gains three safe options - build R 4.5.1 from the official CRAN source directory with its reproducibility caveats, or move the project to the R series CRAN publishes via a `renv::snapshot()` re-run and model re-validation, or reimage to 24.04 only as support for one of those - and the Notes repeat the prohibitions. The PPM speed-up note now records that PPM tracks the same current series and is no route to 4.5.1. `project_state.md` gained the blocking finding as a Known limitation, corrected the earlier bullet that described the CRAN codename suite as a path to 4.5.1 (it is not), and updated the deployment bullet's codename-resolution detail from `/etc/os-release` to the official `lsb_release -cs`. `readme.md` needed no change: it states the Ubuntu release but asserts nothing about an R installation path | Yes - every claim above is quoted or paraphrased from the two official pages fetched for this pass, with the page and section named in the runbook itself; no external assumption was added. `git diff --check` was run after the edits and reports no whitespace errors, and `git diff --name-only` confirms the only files touched are `deploy/DEPLOY.md` and `project_state.md`, both Markdown, with no application code, Caddy, systemd, API setting, frontend file, dependency or Shiny file modified. The document structure was re-checked: its code fences remain balanced, the six numbered sections and the checkpoint table with all five condition rows are intact, and the checkpoint's failure protocol plus the five conditions are preserved. No build, lint, PSA or VPS command was run, and nothing was committed |
| 2026-10-13 | Documentation-only compatibility correction: the deployment target is **Ubuntu 26.04 LTS (resolute)**, not Ubuntu 24.04 (noble). `deploy/DEPLOY.md` no longer hard-codes a release: the title, the compatibility-check section and every installation instruction now name 26.04 LTS, and §1 derives the codename from the running system with `CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-$UBUNTU_CODENAME}")"`, uses it for the CRAN entry (`.../${CODENAME}-cran40/`), and guards against an empty codename. The `noble-cran40` literal is gone, the Posit PPM speed-up now names the same `$CODENAME` instead of `noble`, and both places warn that a release this new may not yet have published CRAN/PPM binaries - in which case that is a checkpoint finding, not a reason to mix another release's packages. Because the release's own Python and Node versions are unknown rather than 3.12/18, the Python block reads `python3 --version`, the Node block checks `node --version` before installing NodeSource's 22.x line, and §3.3 records the interpreter instead of asserting one. The R version policy is untouched - `renv.lock` still requires R 4.5.1 and checkpoint condition 2 still demands the recorded 4.5.x - and the stop-and-verify checkpoint keeps its five conditions, failure protocol and prohibition on substituting an R version or installing packages ad hoc. `readme.md` says Ubuntu 26.04 LTS, and `project_state.md`'s Known limitations, Current task and Next planned task carry the same corrected fact. No application code, Caddy, systemd, API setting, frontend file, model logic or dependency was touched | Yes - `git diff --check` reports no whitespace errors. `deploy/DEPLOY.md` was scanned for `noble`, `24.04`, `Python 3.12`, `3.12.x`, `Node 18` and `R 4.3.3`: zero matches remain, while `26.04`/`resolute` appear only as the target statement and the two expected-value comments. The codename snippet was executed in bash against four synthetic `/etc/os-release` files - 26.04/resolute yields `resolute`, 24.04/noble yields `noble` (proving the value is read, not hard-coded), a file with only `UBUNTU_CODENAME` yields `resolute` through the fallback, and a file with neither yields an empty string where the guard fires - and the generated apt line renders as `deb ... /bin/linux/ubuntu resolute-cran40/`. The document still has 30 balanced code fences, its six numbered sections, and the checkpoint table with its header plus all five condition rows. The rows above describe earlier passes and keep their original 24.04 wording as a record of what was true when they were written; this row supersedes that assumption |
| 2026-10-13 | Documentation-only correction to `deploy/DEPLOY.md`, so the runbook no longer presents the Ubuntu 24.04 + R 4.5.1 + 135-package `renv::restore()` path, or the Python 3.12 install of the pinned lock file, as already proven on the target server. A new "The first installation is a controlled compatibility check" section states that the runbook was written from the repository rather than from a completed install, that the stack was validated on Windows with R 4.5.1 and Python 3.14 while the target is Ubuntu 24.04 with R 4.5.1 and Python 3.12, and that the required R version stays the 4.5.1 recorded in `renv.lock`. §1's R block now calls CRAN's `noble-cran40` repository an intended setup path rather than a guaranteed one, adds `Rscript --version` to confirm what actually arrived, and frames the compiler/library list as what gives the restore a chance to build the packages rather than a certainty; the Posit Public Package Manager speed-up carries the same caveat. §3.2 now ends in a prominent stop-and-verify checkpoint listing the five conditions - `renv::restore()` completes, `Rscript --version` reports the recorded 4.5.x, the Python 3.12 virtual environment installs `api/requirements.lock.txt`, the API service starts, and `curl http://127.0.0.1:8000/api/health` reports `model_ready: true` with one ready R worker - with the failure protocol being to stop before DNS/Caddy/public exposure, collect `systemctl` and `journalctl` output first, and treat any change of R version or ad-hoc package install as a separate targeted decision. §3.7 closes conditions 4 and 5, §4 carries the green-checkpoint prerequisite, §5 says it applies only to a host whose checkpoint was green, and §6's Notes repeat the prohibition. `project_state.md` gained the matching limitation, corrected its now-stale "renv library out of sync" bullet (the earlier `renv::snapshot()` resolved it) and added the untested-hardening and `EQALB_RSCRIPT` items. No code, Caddy configuration, systemd configuration, environment-variable handling, model logic, API behaviour, frontend behaviour or Shiny file was touched | Yes - `git diff --no-pager` confirms `deploy/DEPLOY.md` is the only file with working-tree changes from this correction (exactly 14 hunks, 99 insertions, 13 deletions, all inside that file). The document still holds 30 balanced code fences with the one blockquoted `bash` fence pair correctly prefixed; the checkpoint table has its header plus all five condition rows; the file is valid UTF-8 with no BOM, no mojibake and a byte-identical decode/encode round-trip at 19961 bytes. `renv::diagnostics()`, `renv::status()`, `renv::restore()` and `renv::snapshot()` were confirmed exported by the installed renv 1.3.1 before being cited. `renv::status()` re-run for this pass reports the project is in a consistent state, which is what makes the corrected limitation bullet accurate. No build, lint, PSA or VPS access was performed |
| 2026-10-13 | Minimal production-deployment templates, repository preparation only, nothing committed. Four new files under `deploy/`, all placeholders only: `Caddyfile` (static Vue build from `/opt/eqalb/frontend/dist`, `/api/*` reverse-proxied to `127.0.0.1:8000` with a `try_files` SPA fallback left commented because the app still has no router, zstd/gzip, `protocols h1 h2` so HTTP/3 needs no UDP rule, hashed-asset caching headers, a Caddy access log, and no TLS weakening), `eqalb-api.service` (one unit for the whole model layer: `User`/`Group` `eqalb`, `WorkingDirectory=/opt/eqalb`, `ExecStart` from `/opt/eqalb/.venv` running `api/run_api.py`, `EnvironmentFile=/etc/eqalb/api.env`, `Restart=on-failure`/`RestartSec=5`, network-online ordering, `KillMode=control-group`, and hardening limited to what R and renv tolerate with `StateDirectory=eqalb` plus `HOME`/`XDG_CACHE_HOME` so renv keeps a writable cache under `ProtectHome=read-only`), `api.env.example` (only the six variables the code reads, `EQALB_R_WORKERS=1`, port 8000, and an explicit warning that 8788 is development-only), and `DEPLOY.md` (the Ubuntu 24.04 runbook: packages including CRAN's R repository and the compile-time libraries the 135-package `renv::restore()` needs, server baseline, install from tag `v1.0.0-rc1`, DNS/Caddy, validation, rollback). `readme.md` gained a documentation-only "Deploying it yourself" section and a `deploy/` layout row. No `.gitignore` change was needed. No model logic, calculation, API contract, request/response shape, tutorial or UI behaviour, and no legacy Shiny code was touched; no Docker, CI/CD, database, Redis, monitoring, analytics or auth was added; no PSA was run | Yes - `deploy/*` scanned for live values: no domain, no public IP, no email address, no token, no password, no private key and no certificate (the only `https://` hosts are the Caddy and NodeSource install URLs, and the only `gpg.key` hit is Caddy's public apt-repo key). The only IP literals are `127.0.0.1` and a `0.0.0.0` mention inside a comment. Caddyfile braces balance 11/11; the SPA `try_files` line is commented so the active config cannot rewrite a missing asset, and `reverse_proxy 127.0.0.1:8000`, `root * /opt/eqalb/frontend/dist`, `file_server`, `encode zstd gzip` and the four long timeouts are all present and active. The unit's active (non-comment) lines contain no `0.0.0.0`, no `--reload`, no `workers=` and no 8788 - those tokens appear only in the comment that states they are absent - while `User=eqalb`, `Group=eqalb`, `WorkingDirectory=/opt/eqalb`, `EnvironmentFile=/etc/eqalb/api.env`, the `/opt/eqalb/.venv` ExecStart, `Restart=on-failure`, `RestartSec=5`, `After`/`Wants=network-online.target`, `KillMode=control-group`, `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=full` and `WantedBy=multi-user.target` are all present. `deploy/api.env.example` declares exactly the six variables found by scanning `os.environ.get(...)` in `api/main.py`, `api/run_api.py` and `api/r_client.py` - nothing invented and nothing missing. Exactly one `.service` file exists, so the R worker is not separately managed; every 8788 or plumber reference in the templates is a "do not use / expect refused" instruction, and the Shiny app is explicitly excluded from the deployment. `api/run_api.py` and `api/main.py` were re-read to confirm the ExecStart path works and that `uvicorn.run(app, host, port)` starts a single process with no reload. `npm run lint` and `npm run build` (vue-tsc + vite) both exit 0. No PSA was run and the simulated-data UI notice was not touched |
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
