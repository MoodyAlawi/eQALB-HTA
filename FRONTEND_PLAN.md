# eQalb frontend stack plan

Status: phases 1 and 2 are complete with **R model + FastAPI + Vue 3 (Vite)**,
including the Home screen, its two subviews, the shared interface wording, the
Shiny-parity CSV exports and the OWSA narrative summary. The P0 Kaplan-Meier
interpretation fix and all six P1 findings from the approved UI/UX audit are
implemented (four batches), and the audit's 15 P2 polish findings are triaged: the
two approved pre-1.0 fixes — the one-way sensitivity ranked-outcome mismatch and
the tab-strip and table accessibility semantics — are implemented, twelve are
deferred and one is closed. The approved value-based price module is complete in
both phases: `eqalb_price.R` with `calculate_value_based_price()`,
`POST /api/value-based-price`, the typed client contract
(`postValueBasedPrice()`) and its Vue tab, "Value-based Price", immediately before
the final "HTA Decision Summary" tab. Batch 1 of the approved UX revamp (global
frontend foundation) is implemented: the help popovers open as viewport-clamped
overlays that never shift their surroundings, the repeated dashboard disclaimer
banner is gone, the internal filename and launch-command references no longer
appear in the interface, "Value-based Price" precedes the final decision tab,
which carries a status-aware accent, and Home is a minimal centred landing screen
whose title is the eQalb wordmark flanked by two decorative ECG segments, with a
top-right theme icon. A frontend-only follow-up moved the project-level
disclaimer to the Project description view alone — it was removed from Home and
from the dashboard footer, which no longer exists — and rebuilt the Home title
composition, so the beats now fall before and after the name rather than behind
it. A second frontend-only follow-up made the wordmark part of that same signal:
the letters rest in a subdued tint of the title colour and a travelling wave
energises them in turn, e → Q → a → l → b, each brightening into the full title
colour with a brief soft bloom and starting back toward the resting tint as the
next letter rises, using per-letter spans and CSS animations only. The heading is
deliberately not focusable, so no focus ring is painted around the wordmark.
Batch 2 of the revamp (base case and PSA) is implemented, again frontend-only: the
model-structure wording is gone from the assumptions panel and the base-case
header, the cost and QALY decompositions sit in two closed disclosures under the
base-case metric cards, the base case draws its own deterministic
cost-effectiveness plane from the response, the PSA plane marks the mean of the
iterations and the zero axes, the acceptability curve marks the reference
threshold with a dot and its label, and the PSA's frontend-authored wording is
reduced to what running a PSA needs. No calculation, threshold, distribution,
endpoint or export changed. Batches 3 and 4 of the revamp are also implemented,
all frontend-only except for publishing one existing R sentence: Batch 3 moved the
OWSA narrative into a closed disclosure, restacked the budget-impact controls and
gave the value-of-information tab its EVPPI InfoTip in the table caption plus a
closed visual summary; Batch 4 grouped the readiness inputs under R's own headings
and attached the existing R interoperability definition to that control,
restructured value-based price around a headline, three cards and one comparison
chart, and made the HTA decision summary headline-first with its dashboard and
evidence priorities in closed disclosures. A later pass turned the value-based
price tab into decision support: R's plain-language summary is visible, the
required-effectiveness figure is a callout carrying R's own verdict word, the
solver name and method note, the request-completeness paragraph, the engineering
scenario rows and the duplicate illustrative-data notice are gone from the
interface, and what remains sits in exactly two closed disclosures. Details are in
`project_state.md`.
The existing Shiny application (`app.R`, `run_app.R`, `eqalb_*.R`) is unchanged
and still runs on `127.0.0.1:7788`; it is read-only historical reference
behaviour. The Vue application is the supported user-facing product, and the
Guided Tutorial (Part 1 in full, and all five Part 2 sections) is available from
its Home screen. Part 1 was delivered as
its own R module (`eqalb_tutorial.R`), two endpoints (`GET /api/tutorial` and
`POST /api/tutorial/part1`) and an isolated Vue session
(`useTutorialSession`) plus a `views/TutorialView.vue` and a
`components/tutorial/` set; Part 2 added three more endpoints
(`GET /api/tutorial/part2`, `POST /api/tutorial/part2/case`,
`POST /api/tutorial/part2/evaluate`) and the Part 2 shell with its case brief,
value-for-money, budget-impact, DHT-readiness and recommendation sections to the
same isolated session. It reuses
`run_eqalb_model()`, `calculate_budget_impact()`, `calculate_readiness()` and
`assess_hta_decision_summary()`, and no tutorial rule, wording or number is
reproduced in TypeScript. It is documented in `api/api_contract.md`.

## 1. Goal

Give the eQalb HTA model a browser-based frontend stack without rewriting or
breaking the working Shiny application:

- A separate TypeScript frontend in `frontend/`, built with Vue 3 and Vite.
- A thin HTTP API in `api/`, built with FastAPI, that reuses the existing R model
  functions (`eqalb_markov.R`, `eqalb_owsa.R`, `eqalb_survival.R`,
  `eqalb_readiness.R`, `eqalb_km_interpretation.R`) so no
  economic-model logic is ever duplicated outside R.
- The Shiny app stays the reference implementation throughout.

## 2. Stack (and why)

| Layer | Choice | Why |
|---|---|---|
| Language | **TypeScript** | The model has ~30 numeric parameters and result objects with exact names (`incremental_cost`, `incremental_qalys`, CEAC points, OWSA rows). Typed request/response contracts turn contract drift into a compile error instead of a silently blank chart. |
| UI framework | **Vue 3** | Single-file components fit a form-heavy model UI, and `<script setup>` keeps each panel short. The API layer, TypeScript contracts and chart approach are framework-agnostic, so this choice costs nothing else. |
| Build tool / dev server | **Vite** | Instant dev server, one-command production build, first-class TypeScript, and a proxy option so the browser can call the API without CORS work. |
| Charts | **Apache ECharts** | Needs the cost-effectiveness plane, CEAC, tornado, budget-impact chart and simulated Kaplan-Meier curves. ECharts covers all five with tooltips and confidence bands. Imported modularly, so only line, bar and scatter ship. |
| Runtime / package manager | **Node.js LTS + npm** | Already present (Node 24, npm 11). |
| API service | **FastAPI + uvicorn** | Small, typed and self-documenting: `/docs` lists every endpoint, and `openapi_extra` documents the query parameters without duplicating the R validation. |
| Model execution | **R, unchanged** | The value of this repository is the verified R model. `api/r_worker.R` keeps a long-lived Rscript process alive and calls the `plumber.R` route handlers directly over a JSON-lines pipe, so endpoint logic exists exactly once. |

Explicit non-recommendations for this project:

- Do **not** port the Markov model, PSA, OWSA or survival simulation to
  TypeScript or Python.
- Do **not** start with Next.js, SSR or a meta-framework. The app is a local,
  interactive model explorer; SSR adds complexity with no benefit.
- Do **not** add a component library with its own design language (MUI, Ant
  Design, Vuetify). Plain CSS with tokens reproduces the existing teal palette and
  light/dark modes deliberately.
- Do **not** introduce a state-management library (Pinia, Redux). One `reactive`
  store plus a thin API client is enough at this size.

### Alternatives considered

The options commonly suggested for a project like this were each assessed. All
four belong to the same stack family, so the differences are about fit, not
capability:

| Option | Verdict | Reasoning |
|---|---|---|
| **TypeScript** | Adopted | See the table above. It is a language-level decision that the other options do not replace; it is what makes the response contracts checkable. |
| **Vue 3 + Vite** | Adopted | Chosen UI framework. Best fit here: `<script setup>` keeps the eleven panels close to the size of the Shiny modules they mirror, and the reactive store maps cleanly onto Shiny's `reactive`/`reactiveVal` model, which makes side-by-side comparison of the two front ends easier. |
| **React + Vite** | Viable, not chosen | Equally capable, and TypeScript support is comparable. It would not have changed the API, the contracts or the chart layer. Vue 3 was preferred because the template syntax reads closer to the existing Shiny UI code and the learning material here is a form-heavy model explorer rather than a complex component tree. Switching later means re-scaffolding `frontend/` with `npm create vite@latest frontend -- --template react-ts` and rewriting the components; `src/api/`, `src/composables/` logic (`useModel`, `useTheme`) and `styles.css` port over almost unchanged. |
| **Node.js + npm** | Adopted | The runtime and package manager. This is not an alternative to the frontend framework, it is required by it; Node 24 and npm 11 are already installed. |

One correction worth noting: a frontend stack does not replace the economic
model. Whichever of Vue or React is used, the Markov model, PSA, OWSA and
survival simulation stay in R, because re-implementing them in JavaScript would
put the verified results at risk for no gain.

## 3. Architecture

```
Browser (Vue 3 + TS, http://127.0.0.1:5173)
        |
        |  fetch /api/...
        v
Vite dev server  --proxy /api-->  FastAPI  (api/main.py, http://127.0.0.1:8788)
                                        |
                                        |  JSON lines on stdin/stdout
                                        v
                          api/r_worker.R  (persistent Rscript, one or more)
                                        |
                                        |  takes the handlers out of the plumber router
                                        v
                    api/plumber.R -> eqalb_markov.R / eqalb_owsa.R / eqalb_survival.R
                                     / eqalb_readiness.R / eqalb_km_interpretation.R
                                        ^
                                        |  source()
                          app.R (Shiny, 127.0.0.1:7788) - unchanged
```

One model, two presentation layers. Neither `api/` nor `frontend/` contains model
arithmetic: the API validates nothing itself and the frontend derives nothing, so
defaults, ranges and error messages cannot drift from R.

The same endpoints can also be served without Python at all — `api/run_api.R`
runs `plumber.R` as an ordinary plumber service.

### API endpoints

| Method | Path | R function | Purpose |
|---|---|---|---|
| GET | `/api/health` | module check | Liveness, model root, worker-pool state. |
| GET | `/api/defaults` | constants, `eqalb_owsa_range_bounds()` | Base-case parameter values and the UI contract: ranges, steps, units, percent flags, the one-way ranges derived for that base case with R's rationale and state, simulation defaults. |
| POST | `/api/base-case` | `run_eqalb_model()` | Incremental cost, incremental QALYs, ICER, net monetary benefit and the reconciled cost/QALY decomposition. |
| POST | `/api/psa?n_sim=&seed=&wtp=&max_wtp=` | `run_psa_eqalb()` | Mean results, the simulation cloud, the CEAC, the probability map and every draw. |
| POST | `/api/owsa?outcome=&wtp=` | `run_eqalb_owsa()`, `eqalb_owsa_range_bounds()`, `summarize_eqalb_owsa()` (eqalb_owsa.R) | Ranked tornado table plus the base outcome; the ranges are derived from the submitted scenario and optional `bounds` rows replace them. Returns the ranges in force with R's own source, rationale and `Model default` / `Adjusted` state, plus R's interpretation of the run (base case and decision reference, largest movers, whether the decision survives the tested ranges) and the paragraph above it. |
| POST | `/api/owsa-defaults` | `eqalb_owsa_range_bounds()` (eqalb_owsa.R) | The same range block derived for the submitted scenario without running a single model run, so the range editor always shows the ranges in force for the assumptions in the form. |
| POST | `/api/budget-impact` | `calculate_budget_impact()` | Per-year eligible population, uptake, costs, savings, and the net and cumulative budget impact. |
| POST | `/api/value-of-information?wtp=` | `voi_evpi()`, `voi_evppi()` | EVPI and regression-based EVPPI from PSA draws supplied by the client, so the expensive PSA is not rerun. |
| POST | `/api/survival` | `simulate_eqalb_survival()` and its summaries, `assess_km_interpretation()` (eqalb_km_interpretation.R) | Simulated Kaplan-Meier steps with confidence bands, risk table, diagnostics, expected events, the arm contrast, and the traffic-light `interpretation` (five domains with statuses, counts, wording and rules) plus the descriptive `logrank_note`, so the browser tab shows the same interpretation panel as Shiny. |
| POST | `/api/readiness` | `calculate_readiness()` (eqalb_readiness.R) | The seven-domain DHT readiness assessment: quantitative figures, `numbers`, `domains`, `cards`, status `counts` and the interpretation, with the interoperability levels and governance approaches offered by `/api/defaults`. |
| POST | `/api/hta-summary` | `assess_hta_decision_summary()`, `build_hta_evidence_priorities()` | The traffic-light decision summary (five domain rows, overall status, position, interpretation) and the evidence-priority table, from the analyses the caller has already run plus the readiness inputs; every field is optional and means "not run yet", so an incomplete state keeps R's own not-yet-available wording. Also returns the rule text (`rules`, `evidence_note`, `rule_note`) from eqalb_ui_copy.R, so no client restates a threshold. |
| POST | `/api/value-based-price?wtp=` | `calculate_value_based_price()` (eqalb_price.R) | The highest annual intervention price the model supports at the reference threshold, the headroom against the current price, the relative risk reduction the current price would require, and the 3 x 3 scan of the supported price across the model's own risk-reduction and year-1 engagement bounds. Every figure is solved from `run_eqalb_model()` outputs and confirmed by a model run at the solved price; `availability` reports which values could be identified and why an unavailable one is unavailable. |

Every response carries `notice` —
"Simulated illustrative data — not clinical evidence" — so the disclaimer cannot
be lost by a new client. The Vue interface does not render it: this polish pass
moved the last notice lines out of the panels, while R's substantive wording
(interpretations, `logrank_note`'s descriptive sentence) is untouched. Contract
details, error codes and the worker protocol are
in `api/api_contract.md`.

## 4. Phased delivery

| Phase | Scope | Status |
|---|---|---|
| 0 | Plan, stack decision, folder layout, dev tasks. | Done. |
| 1 | `api/` service wrapping the model; `frontend/` Vite + Vue 3 + TS shell with a typed API client, the global assumptions form, base case, interactive cost-effectiveness plane, CEAC and PSA cloud, tornado diagram with R-driven ranges, budget-impact chart, simulated Kaplan-Meier curve with risk table, value of information, light/dark mode and the simulated-data disclaimer. | Done. The one-way sensitivity tab also shows R's own interpretation of the run in a closed disclosure, built in R by `summarize_eqalb_owsa()` and returned by `/api/owsa`. |
| 2 | Parameterisation parity with the Shiny UI: readiness and implementation domain assessment, HTA decision summary. | Done: the `/api/readiness` endpoint with its `/api/defaults` contract and the Vue DHT readiness tab, and the `/api/hta-summary` endpoint with its typed client function and the Vue HTA Decision Summary tab. The PSA control also matches Shiny now (1,000 draws, seed 12,345, 100-10,000 in steps of 100), with its defaults and bounds published by `/api/defaults` and enforced by `/api/psa`. |
| 3 | Session state, saved scenarios, per-tab CSV/PNG export, downloadable results package parity. | Partly done: the Home screen's "Download results" view builds a ZIP containing the results this session has already produced — one file set per analysis that has been run, including the value of information and the value-based price — lists what has and has not been run from the store, and states the remaining gap (R-rendered chart images, which need a new rendering endpoint). Three per-tab CSV exports now exist (base case in Shiny's layout, the OWSA ranked table, the Kaplan-Meier summary tables); the remaining PNG/PDF charts and the patient-level Kaplan-Meier dataset need new endpoints and are deferred. Session state and saved scenarios are still to come. |
| 4 | Optional: retire the Shiny UI once parity is confirmed, keeping the R model modules as-is. | Decision point, not committed. |

Phase 1 pulled value of information forward from phase 2: it needs no extra model
run (it reuses the PSA draws already in the browser) and it exercises the one
endpoint whose response is a union, which is worth having typed early.

### Audit status and next steps

- The UI/UX audit produced 1 P0 finding, 6 P1 findings and 15 P2 findings. The P0
  finding and all six P1 findings are implemented, the six P1 findings in four
  batches: reset Option A plus the Shiny-parity CSV exports; the per-input help
  text plus the HTA traffic-light rules and evidence note; the PSA default and
  range alignment; and the OWSA narrative summary. The value-of-information
  precision fix landed between Batch 3 and Batch 4.
- The 15 P2 findings are triaged (2026-10-10, read-only). Two were approved for
  1.0 and are implemented: **the OWSA ranked-outcome mismatch** (the tornado
  columns now come from the result's own `outcome`/`outcome_label` rather than a
  setup-time snapshot, and changing the ranked outcome no longer runs the
  analysis — it shows the tab's existing "run the analysis again to apply …"
  note) and **tab-strip and table accessibility** (a `tablist` with `role="tab"`,
  `aria-selected`, `aria-current` on the selected tab, `aria-controls`, roving
  `tabindex` and arrow-key movement; one
  `role="tabpanel"` named by its tab; an accessible name for every `DataTable`,
  from its caption or a `label` prop). Both were frontend-only and are recorded in
  `project_state.md`.
- The approved UX revamp is being delivered in batches; Batch 1 (global frontend
  foundation) is implemented and recorded in `project_state.md`: viewport-clamped
  overlay help popovers, the repeated dashboard disclaimer banner removed, internal
  filenames and launch commands removed from the interface, the
  Value-based Price tab moved immediately before the final HTA Decision Summary
  tab with a status-aware accent on both, a minimal centred Home screen whose
  eQalb wordmark is flanked by two decorative, reduced-motion-aware ECG segments,
  and a visual-foundation pass over spacing, typography, cards, buttons and
  transitions. A frontend-only follow-up made the Project description view the
  only user-facing location of the project-level disclaimer (removed from Home
  and from the dashboard footer, which was deleted) and rebuilt the Home title
  composition so the trace enters from the left, is interrupted by the wordmark
  and continues to the right, animating in the title's own colour. The wordmark
  itself is now part of that signal: its letters rest in a subdued tint of the
  title colour and a travelling wave energises them in turn, each brightening into
  the full colour with a brief soft bloom and beginning its return as the next
  letter rises, timed so the word is back at rest as the trailing pulse enters.
  The heading is not focusable, so no focus ring is drawn around the wordmark. Batch 2
  (base case and PSA) is implemented and recorded in `project_state.md`: the
  model-structure line was removed from the assumptions panel and the base-case
  header, the two decompositions moved into closed disclosures under the base-case
  metric cards (tables, reconciliation totals, notes and accessible names kept),
  the base case gained a deterministic plane (usual care at the origin, an arrow to
  the eQalb point, the zero axes, the response's own WTP ray with its direct label
  and the caption that explains the two sides of it, and the ICER/status annotation
  the metric card uses), the
  PSA plane gained a mean-of-iterations marker and zero-crossing guides, the
  acceptability curve gained a dot and label at the reference threshold, and the
  PSA's frontend-authored simulated-data, implementation, timeout and telemetry
  wording was removed while R's notice, R's InfoTip text and the result-specific
  warnings were kept. Frontend-only: no calculation, threshold or endpoint changed.
  A follow-up made that plane clearer without changing anything else: the shaded
  cost-effective region and its legend entry were removed, the dashed WTP ray now
  carries its own label ("€100,000/QALY threshold", from the response) and a
  one-line caption beneath the chart states what the two sides of the line mean,
  naming that the current result lies above the line only when R reports it as not
  cost-effective. Batch 3 (one-way sensitivity analysis, budget impact, value of
  information) is implemented and recorded in `project_state.md`: OWSA's narrative
  moved into a closed "How to interpret this result" disclosure with R's strings
  unchanged, the budget-impact controls became a panel-only stacked form so each
  label keeps its own information control (with the footer sentences replaced by
  one factual avoided-event hint), and the VOI tab moved EVPPI's InfoTip into its
  table caption, removed the default-visible approximation paragraph and added a
  closed "View visual summary" holding two frontend-only charts built purely from
  returned values (expected NMB current/perfect with R's EVPI as the gap, and R's
  EVPPI rows in R's own order against R's EVPI line, with the caveat inside the
  disclosure). Frontend-only again: no calculation, threshold or endpoint changed.
  Batch 4 (DHT readiness, value-based price, HTA decision summary) is implemented
  and recorded in `project_state.md`: the readiness inputs became a panel-only
  grouped stacked form built from R's own `group` field with every InfoTip on its
  label line, and the interoperability control now carries the existing R
  sentence, published as that choice set's `info` field — the single approved
  contract change, with no algorithm-governance definition invented because none
  exists in R; value-based price leads with three cards and a new two-bar
  frontend-only comparison chart (R's current and maximum acceptable price, R's
  headroom sentence, R's status driving the colour) with all secondary material in
  three closed disclosures, a structure a later pass reduced to two after moving
  R's summary and the required-effectiveness figure out of the disclosures and
  removing the solver, request-completeness and engineering wording from the tab
  altogether; and the HTA decision summary keeps its position card,
  R's interpretation, the incomplete-state warning and R's notice visible while
  the dashboard, the evidence priorities, the traffic-light rules and the
  availability block are closed disclosures, plus one optional insight that repeats
  R's stored value-based price result without requesting it. A polish batch
  followed the final acceptance review, still frontend-only and recorded in
  `project_state.md`: one shared `StaleNotice` sentence marks a stored result as
  computed from earlier inputs in all nine tabs (budget impact, survival and value
  of information gained the request-snapshot comparison they were missing), one
  `useDisclosure` listener gives every secondary-information disclosure the same
  Escape behaviour with focus returned to its summary, the sidebar helper names
  every analysis tab, the base case and PSA tabs gained short subtitles (and
  "Base-case cost-effectiveness" was hyphenated as Shiny writes it), and the
  tornado chart no longer repeats R's ranking with its own sort and truncation.
  The follow-up diagnostic that found the tornado's bars missing was fixed after
  that batch, still frontend-only: ECharts 6 reads a two-element bar item as
  `[x, y]` coordinates rather than as a value range, so every bar had been dropped
  and the value axis scaled from one element. `TornadoChart.vue` now draws each
  parameter's span with a custom series (one bar per R-returned row, from that
  row's own low to high bound, split at R's base outcome so the direction colours
  are preserved, tooltips resolved through `parameter_id`, and a value axis taken
  from the returned bounds), and its parameter column narrows with the chart width
  so the bars stay readable on a phone. No R file, API route, threshold, export or
  request changed. No later batch is started.
- The twelve deferred findings need no 1.0 action and were not implemented. Three
  of them need backend work when they are scheduled: re-thresholding a finished
  PSA without re-running it, the Kaplan-Meier assumptions table (the API does not
  return `p_mi`/`p_stroke`/`p_other_death`), and the exploratory engaged versus
  non-engaged curves. The other nine are small and mostly frontend-only: the
  PSA conventional-threshold rows under a custom threshold, the PSA mean-QALY
  components, the unrendered Kaplan-Meier diagnostics tables, the editable model
  constants, the displayed precision, the quiet pre-run states, first-visit
  guidance, the budget-impact cumulative-users column, and the `/api/budget-impact`
  population default that disagrees with the readiness default. One finding — the
  landing animation state — was closed: it is not reproducible and
  `prefers-reduced-motion` is already honoured.
- Every table in the interface now has an accessible name: `DataTable` takes it
  from the caption shown above the table or from a `label` prop, and the tables
  that are written as raw markup — the readiness quantitative and domain tables
  in `ReadinessPanel.vue`, the HTA decision dashboard and evidence-priority tables
  in `HtaSummaryPanel.vue`, and the required-effect and 3 × 3 scan tables in
  `ValueBasedPricePanel.vue` — name themselves with
  `aria-label`. Names are set with `aria-label` rather than a `<caption>`, so no
  table gained a visible extra row and the responsive `.table-scroll` wrapper is
  unchanged.
- Deferred with honest limitation notes on the affected tabs, in the results
  package README and in `frontend/README.md`: the Kaplan-Meier patient-level
  dataset export and the R figure-rendering (PNG/PDF) endpoint.
- The Guided Tutorial Part 1 is implemented in Vue. It is a self-contained
  session — its own screen, inputs, results and step — driven entirely by
  `eqalb_tutorial.R` through `GET /api/tutorial` and `POST /api/tutorial/part1`,
  which publish the tutorial's defaults, control metadata, fixed values
  (including its own post-event utilities), teaching copy, simplified
  traffic-light rules and the complete four-step result set. It never reads or
  writes the `useModel` store, so no tutorial value can be moved by the analysis
  dashboard or vice versa. Part 2 is complete: R-owned case creation/resume (an
  opaque handle the client only stores and echoes), the case's own facts, the
  43-point price curve with R's classifications and marker, the R-owned coverage cap
  with the covered population, the annual budget rows and chart, the affordability
  states and the maximum affordable coverage R finds by scanning its permitted
  coverage steps, the four-answer readiness exercise, and R's recommendation outcome
  with its completion card, which carries "Retry Part 2 with different assumptions"
  and "Open full analysis"; a case whose outcome does not complete the exercise gets
  the same Retry button in a retry row, so the retry flow is reachable from every
  Recommendation screen. `/api/defaults` still
  omits the tutorial keys: the tutorial has its own contract endpoints.

## 5. Folder layout

```
api/
  main.py              # FastAPI app: endpoints, docs, error mapping - no model arithmetic
  r_client.py          # worker pool: subprocess lifecycle, JSON-lines protocol, retries
  r_worker.R           # persistent Rscript; reuses the plumber.R route handlers
  plumber.R            # the route handlers and response shaping (single implementation)
  run_api.py           # FastAPI launcher, pinned to 127.0.0.1:8788
  run_api.R            # alternative plumber HTTP launcher (same port, same endpoints)
  requirements.txt     # fastapi, uvicorn
  api_contract.md      # request/response contract, worker design, error codes
eqalb_ui_copy.R        # CC_INFO_TEXT and the HTA rule text, shared with app.R verbatim
eqalb_price.R          # value-based price: supported annual price, headroom and scan
eqalb_tutorial.R       # Guided Tutorial: Part 1 (defaults, statuses, wording, decision summary) and
                       # Part 2 (cases, facts, price rules and curve, value-for-money, budget-impact,
                       # readiness and recommendation results)
frontend/
  index.html
  vite.config.ts       # /api proxy to the model API
  src/
    main.ts, App.vue   # shell
    api/client.ts      # typed fetch client
    api/types.ts       # response contracts mirroring the R return shapes
    composables/       # useModel (state), useTutorialSession (isolated tutorial state),
                       # useTheme (palette), useEcharts (charts), useAppView (which page is shown, and the
                       # /, /app and /about addresses with the history entries and document title),
                       # useAppBusy (the app-wide loading state)
    components/        # presentation only; charts/ holds the chart options; tutorial/ the four Part 1 steps and Part 2's five sections; InfoTip is the help control; AppLoadingIndicator is the loading indicator
    views/             # OpenHealth landing (/), the eQalb Home screen (/app, with the Guided tutorial,
                       # Project description and Download results subviews) and About OpenHealth (/about)
    export/            # results package + per-tab exports: ZIP writer, CSV builders
    format.ts          # EUR/QALY formatting; null becomes a dash
    styles.css         # teal palette + light/dark tokens
  README.md
```

## 6. Ground rules carried over from the project conventions

- R is the sole source of calculations, thresholds, statuses, interpretations and
  evidence priorities. No model arithmetic is written in TypeScript or in `api/`;
  `api/plumber.R` shapes responses and `api/r_worker.R` carries them, and both
  call `eqalb_*.R`. No client derives a status, a threshold or an evidence
  priority, and no interpretation is composed outside R.
- All simulated output is labelled "Simulated illustrative data — not clinical
  evidence".
- Costs in EUR, effects in QALYs, thresholds default to €100,000/QALY.
- Expensive analyses stay behind an explicit action button, exactly as in the
  Shiny app, and simulated outputs keep user-adjustable seeds.
- Resetting model inputs is Option A: it restores the 16 model assumptions and the
  WTP threshold, and never deletes a result. Clearing results is a separate,
  confirmed action, and a stored result whose own inputs have changed is marked as
  computed from earlier inputs rather than removed.
- An export is named after what it contains. Where a file cannot match Shiny's
  shape or scope yet (the OWSA layout, the Kaplan-Meier summary tables versus the
  patient-level dataset, the rendered charts), the difference is stated on the tab
  and in the README rather than hidden behind Shiny's file name.
- Explanatory wording is R's, never the client's. Help text, traffic-light rules
  and the HTA notes come from `CC_INFO_TEXT` and the HTA constants in
  `eqalb_ui_copy.R` (sourced by both `app.R` and `api/plumber.R`) and are rendered
  as returned, so the browser interface and Shiny cannot explain the same control
  differently.
- The Shiny app remains runnable, unmodified, and is both the reference
  implementation and the tutorial application.

## 7. How to run

```powershell
# Terminal 1 - model API (127.0.0.1:8788)
api\.venv\Scripts\python.exe api\run_api.py

# Terminal 2 - frontend dev server (127.0.0.1:5173)
cd frontend; npm run dev

# Terminal 3 (optional) - existing Shiny app (127.0.0.1:7788)
& 'C:\Program Files\R\R-4.5.1\bin\Rscript.exe' '.\run_app.R'
```

VS Code tasks: "eQalb: run model API (127.0.0.1:8788)",
"eQalb: run frontend dev server (127.0.0.1:5173)" and
"eQalb: run app (127.0.0.1:7788)".

There is also a small control script for the two browser-stack services, so they
can be started, stopped, restarted and inspected with one command each
(`./dev.sh start | stop | restart | status | logs`). It runs the R Plumber API on
8788, FastAPI on 8000 (so both APIs can be up at once) and the Vue dev server on
5173 with its proxy pointed at FastAPI, writing pids to the git-ignored
`.dev.pids` and output to the git-ignored `.dev-logs/`. Run it from Git Bash or
with `bash ./dev.sh <command>`. It is a development convenience only: it starts
the existing launchers and does not change any service code.

If the plumber service (`api/run_api.R`) is already using 8788, stop it first, or
set `EQALB_API_PORT` and start the dev server with `EQALB_API_URL`.

## 8. Dependencies added

Frontend (inside `frontend/`, and irrelevant to the Shiny app): `vue`, `vite`,
`@vitejs/plugin-vue`, `typescript`, `vue-tsc`, `echarts`, `oxlint`,
`@types/node`.

Python: `fastapi` and `uvicorn` in `api/.venv` (see `api/requirements.txt`). No
Python package computes model output.

R: `plumber` (plus its dependencies) in the project `renv` library — it is needed
for its request parsing and route handlers, which `api/r_worker.R` reuses.
`renv.lock` is intentionally left for a deliberate `renv::snapshot()` by the
project owner.

## 9. Known limitations

- The API is unauthenticated and binds to localhost only; it is a development and
  teaching service, not a deployed product.
- The HTA Decision Summary tab renders the rule text `POST /api/hta-summary`
  returns (`rules`, `evidence_note` and `rule_note` from `eqalb_ui_copy.R`); no
  rule wording is written in TypeScript. The numeric thresholds themselves are not
  published, exactly as in the Shiny decision summary, so the tab does not restate
  them.
- `/api/hta-summary` has no results of its own: the tab sends the outputs of the
  analyses it has run, otherwise the dashboard reports R's own "Not available" /
  "Not yet assessable" wording, exactly as the Shiny tab does before those
  analyses are run.
- The readiness tab shows the traffic-light rule wording and colour meanings
  copied from `app.R` (`DHT_THRESHOLD_NOTE`, `DHT_TRAFFIC_LEGEND`) in an
  on-demand "Traffic-light rules" disclosure, but not the numeric thresholds:
  those are not part of the API contract, and the disclosure derives no status
  from the wording.
- Value-of-information endpoints need PSA draws in the request body, so they only
  work after a PSA has been run in the same browser session. The round trip is
  exact for the values the API sends: `api/r_worker.R` rebuilds a posted body with
  `jsonlite::toJSON(..., digits = NA)`, so FastAPI and plumber return the same
  result (EVPI at 1,000 draws: 4.70724749145015 in both, matching R, where the
  FastAPI path previously reported 4.6942935 because the body was rebuilt at
  jsonlite's default of four decimal places). A value carrying more than 15
  significant digits would still be rounded, which is the precision both services
  transmit. See `api/api_contract.md`.
- The PSA permits 10,000 draws in the form because Shiny's control does, but at
  the measured 0.18 s per iteration that exceeds the FastAPI worker's 15-minute
 request timeout (`EQALB_R_TIMEOUT`, default 900 s). That limit is documented here
 and in `api/api_contract.md`; since Batch 2 of the UX revamp the interface no
 longer states it, because it is an operating limit of the development service
 rather than something the person running an analysis acts on.
- Charts are re-implementations of the Shiny plots using the same underlying
  numbers, not the same R plotting code, so cosmetic differences are expected.
- The frontend has no automated test suite yet; it has been verified manually
  against the R API. Its type check (`vue-tsc -b`) and lint (`oxlint`) pass, and
  the production build succeeds.
- Requests are serialised through a small worker pool (two R workers by default),
  so a third simultaneous analysis waits for a free worker.
- The value-based price module is complete: its R logic (`eqalb_price.R`), its
  endpoint (`POST /api/value-based-price`), its typed client function
  (`postValueBasedPrice()`) and its Vue tab, "Value-based Price". A request costs
  about 40 `run_eqalb_model()` calls (roughly 7 s at the measured 0.16 s each), so
  the tab runs only from its own action button, keeps a stored result while the
  assumptions change and marks it as computed from earlier inputs. Every scan cell
  is shown with the status R returns for it; a combination R could not identify
  reads "Not available" with R's note in the scan detail, and the tab contains no
  price, threshold or status of its own.
