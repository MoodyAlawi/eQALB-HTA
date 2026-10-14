# eQalb frontend (Vue 3 + Vite)

Presentation layer for the eQalb illustrative HTA model. It contains **no model
logic**: every number is produced by the R model and reaches the browser through
the FastAPI service in [`../api`](../api). Costs are shown in EUR, effects in
QALYs. Every response still carries R's simulated-data notice, but the interface
no longer renders it: the panels show only R's substantive wording, and the
`notice` field itself is left in the contract for other clients.

## Running it

Two processes are needed. In separate terminals, from the project root:

```powershell
# 1. The model API (R via FastAPI), http://127.0.0.1:8788
api\.venv\Scripts\python.exe api\run_api.py

# 2. This dev server, http://127.0.0.1:5173
cd frontend
npm install
npm run dev
```

Open <http://127.0.0.1:5173> for the OpenHealth landing page, or go straight to
`/app` for eQalb and `/about` for About OpenHealth: the dev server resolves all
three from the same `index.html`, so any of them can be loaded or reloaded
directly. The dev server proxies `/api` to the API, so the browser stays on a
single origin and no CORS work is needed. Point it elsewhere with `EQALB_API_URL`
(for example when the API runs on another port):

```powershell
$env:EQALB_API_URL = 'http://127.0.0.1:8799'; npm run dev
```

VS Code tasks are provided for both processes.

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Dev server with hot reload on 127.0.0.1:5173. |
| `npm run build` | `vue-tsc -b` type check, then a production build into `dist/`. |
| `npm run typecheck` | Type check only, including the `.vue` templates. |
| `npm run preview` | Serve the production build on 127.0.0.1:4173. |
| `npm run lint` | oxlint over the TypeScript sources. |

`vue-tsc` is what type-checks the single-file components, which is why it runs in
`build`. oxlint does not parse `.vue` files, so lint covers the `.ts` sources.

## Layout

```
index.html              # mounts the app; applies the stored theme before first paint
src/
  main.ts, App.vue      # shell: the public OpenHealth pages, then the eQalb app (Home button, status, theme, assumptions, tabs)
  api/
    types.ts            # response contracts, transcribed from live responses
    client.ts           # typed fetch client; no defaults, no model arithmetic
  composables/
    useModel.ts         # shared store: inputs, results, busy/error state, runs
    useTheme.ts         # light/dark state and the chart palette
    useEcharts.ts       # ECharts instance lifecycle for a Vue ref
    useAppView.ts       # which page is shown, plus the /, /app and /about addresses, the history entries and the document title
    useDisclosure.ts    # Escape closes the disclosure the focus is inside, app-wide
    useAppBusy.ts       # the app-wide busy state the loading indicator shows: ref-counted start/finish, label, isActive
    useTutorialSession.ts  # Guided Tutorial: Part 1's inputs/results/step and Part 2's case, price, coverage, readiness answers and section; never touches useModel
  views/
    OpenHealthHomeView.vue      # public landing page at / : what OpenHealth is, eQalb as its first flagship tool, what is planned, how to collaborate
    AboutView.vue               # About OpenHealth at /about : the founder, the motivation, and how to get involved
    HomeView.vue                # eQalb's own start screen at /app : eQalb wordmark with ECG pulse, credit, actions, links
    TutorialView.vue            # Guided Tutorial: Part 1 (four steps, completion) and the Part 2 shell
    ProjectDescriptionView.vue  # what the model is, what it covers, contact
    DownloadResultsView.vue     # what this session produced, and the ZIP download
  export/
    zip.ts              # dependency-free store-only ZIP writer (CRC-32)
    csv.ts              # CSV quoting/joining and text download (shared)
    resultsPackage.ts   # results-package files built from the store
    tabExports.ts       # per-tab CSV builders (base case, OWSA, KM summary)
  components/
    AppLoadingIndicator.vue # the only loader: a thin teal top bar after 350 ms and a small eQalb/ECG card after 2.5 s, its trace pulse crossing the line once per cycle
    AssumptionsForm.vue # the 16 model inputs + the reference WTP threshold
    BaseCasePanel.vue   # base case: metrics, deterministic plane, decompositions on demand
    CostEffectivenessPanel.vue  # PSA, plane, CEAC, threshold table
    SensitivityPanel.vue        # tornado diagram, R-derived OWSA ranges, R's interpretation on demand
    BudgetImpactPanel.vue       # per-year budget impact, stacked controls
    SurvivalPanel.vue           # simulated Kaplan-Meier, risk table, diagnostics
    ValueOfInformationPanel.vue # EVPI, EVPPI table, and the on-demand visual summary
    ReadinessPanel.vue          # DHT readiness: grouped stacked inputs, numbers, domains, statuses
    HtaSummaryPanel.vue         # HTA position + interpretation, dashboard and evidence priorities on demand
    ValueBasedPricePanel.vue    # supported annual price, headroom, required effect, 3x3 scan
    tutorial/           # Guided Tutorial: stepper, control, status card, plane, Part 1's four steps and
                        # completion card, and Part 2's shell, case brief, price curve, value-for-money,
                        # budget-impact, readiness and recommendation sections
    charts/             # one component per chart, options only
    DataTable.vue, MetricCard.vue, InfoTip.vue, StaleNotice.vue, table.ts
  format.ts             # EUR/QALY/percent formatting; `null` becomes a dash
  styles.css            # tokens reproducing the Shiny app's teal palette
```

## Conventions that matter

- **The R model owns the model.** R is the sole source of every calculation,
  threshold, status, interpretation and evidence priority. Parameters, ranges,
  steps and validation messages come from `/api/defaults` and from the R error
  responses; the client never re-derives a default, a status or a threshold, and
  an input R rejects surfaces R's own message.
- **`null` is not zero.** The API returns `null` for values it cannot compute (an
  infinite ICER, a median never reached). `format.ts` renders those as a dash, and
  the ICER helper explains a dominated strategy in words instead of printing
  infinity.
- **Expensive analyses need an explicit action.** The base case takes under a
  second, but a PSA measured about 0.18 s per iteration on the development
  machine — roughly three minutes for the Shiny default of 1,000 draws — and the
  one-way analysis needs two model runs per parameter, so both stay behind their
  own button with their own busy and error state. A PSA run at 1,000 draws or more
  is confirmed first, by a prompt that can continue with the run or cancel back to
  the iteration field; the count itself, the request and the draws are unchanged.
  While a PSA is running the panel
  says that a 1,000-draw run takes minutes and that the tab has to stay open, and
  it names no duration it cannot know. Results always correspond to the assumptions
  that produced them; every analysis tab says so, through the shared
  `StaleNotice.vue`, when the inputs or the threshold its stored result used have
  changed (the readiness, HTA summary, budget-impact, survival, value-of-information,
  value-based-price and one-way tabs compare the request their stored result came
  from; the base case and the PSA compare the threshold, and the one-way tab's
  ranked-outcome selector keeps its own separate notice).
- **PSA controls match Shiny's.** Defaults (1,000 draws, seed 12345) and bounds
  (100–10,000 in steps of 100, seed minimum 1) are read from `/api/defaults` and
  enforced by the input's own `min`, `max` and `step`, so the range the form offers
  is the range R validates and no separate range caption is needed. Reaching the
  10,000-draw ceiling exceeds the FastAPI worker's request timeout; that operating
  limit is documented here and in `../api/api_contract.md`, not shown in the
  interface.
- **Reset and Clear are separate actions.** "Reset model inputs" (Option A)
  restores the 16 model assumptions and the WTP threshold only and never removes a
  result; the "Clear all results" action is separately confirmed and names what it
  removes. Readiness has Shiny's own "Reset values" (seven readiness inputs,
  readiness result only).
- **Explanations are R's text.** The small "i" controls (`InfoTip.vue`) show the
  wording `GET /api/defaults` publishes (`info_text` and each parameter's `info`),
  which is `CC_INFO_TEXT` from `eqalb_ui_copy.R` — the same strings Shiny shows.
  The HTA tab renders `rules`, `evidence_note` and `rule_note` from
  `/api/hta-summary` the same way, and the Guided Tutorial renders the tutorial
  copy — control labels and explanations, step titles, teaching paragraphs,
  traffic-light rules and table headings — from `GET /api/tutorial`. Three kinds of
  text are not from `/api/defaults`: the explanatory subtext a chart used to carry
  beneath it, moved verbatim into the information button beside that chart's
  header (base case, PSA, simulated survival, value of information and
  value-based price); one sentence written for the interface that sits beside
  the readiness tab's "Algorithm governance" heading, because R deliberately
  publishes no wording for that choice set; and one sentence each beside the
  "Event costs", "Discounting" and "Time horizon" group headings in the
  assumptions panel, because `CC_INFO_TEXT` defines individual parameters and not
  group headings. Each of those interface sentences describes what its subject is
  and why it matters and states no value, range or model rule. Nothing else is
  paraphrased or
  shortened in
  TypeScript, and the controls are buttons, so they work by keyboard, close on
  Escape and on an outside click, open as a viewport-clamped overlay so they never
  shift the layout, and are not hover-only.
- **The sensitivity interpretation is R's.** `POST /api/owsa` returns `summary`,
  written by `summarize_eqalb_owsa()` in `eqalb_owsa.R` — the function the Shiny tab
  calls — plus `summary_note`, the paragraph shown above it. Before a run the panel
  shows `owsa_prerun_note` from `/api/defaults`. The panel renders R's lines as they
  arrive (one sentence per line, with `white-space: pre-wrap`, so they wrap at 390px
  where Shiny's `<pre>` would not) and never composes a sentence of its own. R's
  interpretation follows the ranked outcome the result was run with — the base case
  and its decision reference, the parameters that move that outcome most, whether
  the conclusion survives the tested ranges, and the one-way limitation — so the
  summary, the chart and the table describe one ranking.
- **Numbers survive the round trip.** The value-of-information panel posts the PSA
  draws it holds back to R, so the FastAPI worker rebuilds request bodies with
  `jsonlite::toJSON(..., digits = NA)`: the numbers R receives are the numbers the
  API sent, never rounded to four decimal places on the way in. That is the
  precision both services transmit (15 significant digits), and FastAPI and plumber
  return the same EVPI for the same draws.
- **Percentages.** The model stores fractions; the form shows percentages and
  converts on commit. That conversion is the only arithmetic in the client.
- **One-way ranges are R's, derived for the current scenario.** `POST
  /api/owsa-defaults` returns one row per parameter with the value it has in the
  submitted scenario, the low and high value R derives for it, R's rationale and
  source label, the domain a range has to stay inside and R's own `Model default`
  or `Adjusted` state. A range the user sets is sent as an absolute `{id, low,
  high}` row and R decides whether it can be used; it is never rebased here, and
  the ranges in force are always echoed back by the API.
- **Charts** are ECharts options computed from the response
  (`src/components/charts/`). Colours come from `useTheme`, never from hard-coded
  hex values in a chart, so light and dark mode stay consistent. Tabs render with
  `v-if` so a chart is never initialised inside a hidden container.
- **The interface is reachable by keyboard and assistive technology.** The nine
  analysis tabs are a `tablist` (a `role="tab"` button per panel, with
  `aria-selected`, `aria-current`, `aria-controls`, one tab stop and arrow-key
  movement), the visible panel is a `tabpanel` named by its tab, and every table
  carries an accessible name — `DataTable` takes it from the caption shown above
  the table or from a `label` prop, and the readiness, HTA and value-based price
  tables (including the 3 × 3 scan) name themselves with `aria-label`. Names are
  set with `aria-label` rather than a
  `<caption>`, so no table gains a visible extra row and the responsive
  `.table-scroll` wrapper is unchanged.

## Deployment

Caddy serves a static build of this app from
`/opt/eqalb/public/dist` on the VPS, and a release never reloads Caddy or
restarts the API. A frontend-only change can be shipped by the GitHub Actions
workflow [`deploy-frontend.yml`](../.github/workflows/deploy-frontend.yml), which
runs `npm ci --ignore-scripts`, `npm run typecheck`, `npm run lint` and
`npm run build` on Node 22, packages the bundle with a SHA-256 checksum, and
activates it as an immutable release behind the `dist` symlink. The production
build sets `sourcemap: false` in [`vite.config.ts`](./vite.config.ts), so no
`.map` files are published. Server bootstrap, environment secrets, approval and
rollback are documented in [`../deploy/FRONTEND_DEPLOY.md`](../deploy/FRONTEND_DEPLOY.md);
the full host runbook remains [`../deploy/DEPLOY.md`](../deploy/DEPLOY.md).

The deployment server and the GitHub `production` environment are configured,
the operator has confirmed the environment's required-reviewer/approval rule, and
one end-to-end automated deployment has succeeded. Neither the automatic rollback
after a failed validation nor the manual rollback has been exercised yet, so both
remain untested. That successful release was built from `main`: the OpenHealth
public shell on this branch is not part of a deployed release.

## Known limitations

- No automated test suite yet; the app was verified by hand against a running
  API.
- The parity audit is complete for P0, P1 and the P2 triage. The P0 finding and
  all six P1 findings are implemented, and the 15 P2 polish findings are triaged:
  the two approved pre-1.0 fixes are implemented (the one-way sensitivity
  ranked-outcome mismatch, and the tab-strip and table accessibility semantics —
  a `tablist` with `role="tab"`, `aria-selected`, `aria-current` and
  `aria-controls`, a `tabpanel` named by its tab, and an accessible name on every
  table, including the four raw readiness and HTA tables), and the remaining
  findings are deferred, three of them needing backend work. No deferred item is
  started without approval. See [`../FRONTEND_PLAN.md`](../FRONTEND_PLAN.md).
- The Guided Tutorial Part 1 is implemented in Vue and is a self-contained
  session: it has its own screen, its own inputs and its own results, and it never
  reads or writes the `useModel` store. Its defaults, labels, ranges, statuses,
  thresholds, interpretations and formatted strings all come from
  `eqalb_tutorial.R` through `GET /api/tutorial` and `POST /api/tutorial/part1`,
  so no tutorial rule, wording or number is reproduced in TypeScript. Leaving the
  tutorial keeps the session (so the learner returns to the same step and values);
  "Restart tutorial" restores R's own defaults, and a page reload clears it.
- The Guided Tutorial Part 2 (the commissioning case challenge) implements all five
  sections — Case brief, Value for money, Budget impact, DHT readiness and
  Recommendation — reached from the Part 1 completion card. It is a mode of the
  same isolated tutorial session,
  so it shares nothing with the analysis dashboard, and returning to Part 1 leaves
  Part 1's step, values and results exactly as they were. R draws the case and
  returns an opaque handle; the client stores and echoes that handle and never
  selects, infers or names a case. A case's facts, its post-event utilities, the
  43-point price curve, every pass/fail classification, the highest acceptable
  price, the chart's labels and colours and all instructional wording come from
  `eqalb_tutorial.R` through `GET /api/tutorial/part2`,
  `POST /api/tutorial/part2/case` and `POST /api/tutorial/part2/evaluate`. Two
  points are worth stating plainly:
  - **A case's facts are its own.** The reference tutorial's Part 2 case read the
    implementation cost, the healthcare savings, the budget-impact settings, the
    digital-access settings and the two post-event utility fields from the
    dashboard, so a case could change when unrelated analysis assumptions were
    edited. Here every one of those is an R-owned tutorial value or a case fact,
    and the parity check asserts that a request carrying dashboard-style fields
    changes nothing.
  - **The price curve is bound to its case.** Re-running the curve on every price
    change would cost forty-four model runs, so the case's curve is posted back for
    R to re-classify, and a price change costs one model run. R re-derives every
    classification in that path — a caller cannot supply a status — and R rejects a
    curve that belongs to a different case, because the lever's 43 prices are the
    same for every case.
  - **The budget impact is the case's own, and the cap only touches it.** The
    coverage cap scales the case's budget population and nothing else, so it never
    moves the per-person value-for-money result. R computes the covered population,
    the five-year annual rows and chart series, the affordability status against the
    case's own ceiling and the maximum affordable coverage (found by scanning R's
    permitted coverage steps, not by inverting the budget formula). The full annual
    table and breakdown sit in one closed disclosure.
  - **The readiness exercise asks; the recommendation reports.** The four readiness
    answers reach the readiness assessment only, and the exercise itself shows no
    traffic light: the seven domain statuses and the Deliverability card render in
    the Recommendation section, which also carries R's outcome for the case, the
    four-criterion checklist, R's restatement of the selected follow-up engagement
    level, and a completion card with "Retry Part 2 with different assumptions" and
    an "Open full analysis" action when R's outcome completes the case. Retry is
    not tied to that outcome: when the completion card is not shown, the same button
    renders in a retry row under the engagement note, so the action is available on
    every Recommendation screen.
  - **The Case brief's narrative is the client's; every fact in it is R's.** The
    section task, the payer framing and the one neutral sentence that describes the
    case are presentation copy in `Part2Brief.vue`, and R's own `case.summary` is
    deliberately not rendered: two of R's three summaries end by saying how many
    prices or how much coverage pass, which would give away the answer the exercise
    asks for. The neutral line is keyed by R's own case title and falls back to a
    sentence that describes nothing for a title it does not know, so a case R adds
    later cannot leak an outcome through it. The manufacturer's price is presented
    as a starting proposal for negotiation; €150 appears only as R's facts-table
    value.
- The retry flow is implemented: "Retry Part 2 with different assumptions" draws a
  case other than the active one through R's `exclude_case_id` rule, returns to the
  Case brief and restores R's own defaults for the price, the coverage cap and the
  four readiness answers.
- The app opens on the Home screen and fetches the model contract only when the
  analysis dashboard is first opened, so Home itself makes no API request and
  nothing is analysed before its own action button is pressed.
- Results are snapshots, so each tab re-runs from its own button. The readiness,
  HTA summary and value-based price tabs additionally flag a stored result as
  computed from earlier inputs when their own inputs have changed, and no result
  is removed by editing or resetting an input.
- **The value-based price tab presents R's solve, it does not make one.** The
  supported annual price, the headroom, the required relative risk reduction, the
  3 × 3 scan and every status band, axis label, reason and sentence come from
  `calculate_value_based_price()` (eqalb_price.R) through
  `POST /api/value-based-price`. Each scan cell is shown with the status R
  returns for it and nothing else: a combination R could not identify reads
  "Not available" with R's note in the scan detail, so the table never turns a
  missing price into a number. The request sends the current scenario and the
  reference threshold, so the price the model ran at, the price the solve used and
  the headroom all describe the same price. The tab is laid out as decision
  support: the cards, the comparison chart, R's plain-language summary and the
  required-effectiveness callout are visible, and only "What this price means" and
  "Explore price scenarios" are disclosures. R's solver name and method note are
  in the response for anyone auditing how the price was produced but are
  deliberately not rendered, and the required-effect verdict is shown in R's own
  words (`verdict_label`, e.g. "Not met") rather than as the machine value.
- Three per-tab CSV exports exist, and each is named after what it holds: the
  base case matches Shiny's file row for row, the sensitivity export is the
  ranked API table (one row per parameter with low/high columns, where Shiny's
  file is one row per scenario), and the survival export is the summary tables.
  Shiny's patient-level Kaplan-Meier dataset has no endpoint yet, so that export
  is deferred and the survival tab says so instead of imitating it.
- The help panels ("i" controls) open as overlays: the panel is teleported to the
  page body and positioned in viewport coordinates, clamped to the visible client
  area, so opening one never expands or shifts the card, row or table it belongs
  to and it stays fully visible at 390px. An explanation taller than the viewport
  scrolls inside its own panel, and the position is recomputed while the page
  scrolls or the window resizes.
- The base-case tab draws the deterministic result as a plane of its own (usual
  care at the origin, an arrow to the eQalb point, the zero axes, and the
  willingness-to-pay ray the response was produced at, labelled with that
  threshold; the explanation of which side of the line is cost-effective, and the
  ICER annotation the chart used to print beneath it, sit in the information
  button beside the chart header), and keeps the cost and QALY
  decompositions in two closed disclosures under the metric cards. The tables,
  their reconciliation totals and their notes are unchanged; only their default
  visibility is. A non-estimable ICER is described in words, as the metric card
  does, and no ratio is drawn.
- The PSA plane marks the mean of the iterations with a hollow diamond (hollow so
  it stays legible where it coincides with the deterministic marker) and the zero
  axes, and the acceptability curve carries a dot and its label at the reference
  threshold. All three read values the PSA response already carries; none of them
  is recomputed.
- The one-way sensitivity tab keeps R's narrative in a closed "How to interpret
  this result" disclosure (the same strings as the API returns, verbatim), and the
  value-of-information tab keeps its two visual summaries in a closed "View visual
  summary": bars for R's expected NMB with current evidence and with perfect
  information, and R's EVPPI table as bars in the response's own order against a
  line at R's EVPI. Both charts read only returned fields — the ranking is R's —
  and the approximation caveat and each chart's own readout sit in the information
  button beside that chart's header inside the disclosure.
  The budget-impact inputs use a stacked form so each label keeps its own
  information control on narrow screens.
- **The tornado draws ranges with a custom series.** ECharts does not accept a
  two-element array as a bar's value range (it reads one as `[x, y]`), so
  `charts/TornadoChart.vue` registers `CustomChart` itself and draws one rectangle
  per R-returned row, from that row's own low to high outcome, split at R's base
  outcome so the direction colours keep their meaning and a row lying wholly on one
  side never borrows the other colour. The value axis is set from the returned
  bounds, R's row order is drawn top-down through `yAxis.inverse`, and tooltips
  resolve the row through `parameter_id` rather than an array position. Its
  parameter column narrows with the chart's own width (and the canvas is taller
  below 520px) so the bars stay readable at 390px.
- Disclosures are used for secondary detail throughout, and they behave the same
  way everywhere: a native `<details>` (styled `.details`) opens by mouse, Enter
  and Space, and Escape closes the one the keyboard focus is inside and returns
  focus to its summary. That behaviour is installed once by
  `composables/useDisclosure.ts` from the composable every screen already calls, so
  it also covers the Download-results view; the assumptions sidebar's `details.group`
  input groups are not disclosures and stay open. An open information tip closes on
  Escape first, leaving the disclosure behind it open.
- "Download results" packages the results this session has already produced. It
  does not contain the rendered chart images the Shiny package carries: those need
  a new endpoint that renders a plot from results the client already holds. Until
  then the ZIP's README states that difference on every download, and the view
  lists which analyses were and were not included. That list is derived from the
  store, so it covers every result-producing tab — the value of information and
  the value-based price included — and the sidebar's "x of y analyses stored"
  counter takes the same total from the store rather than from a number written
  into the template.
- The readiness/implementation, HTA decision-summary and value-based price views
  exist (`ReadinessPanel.vue`, `HtaSummaryPanel.vue`,
  `ValueBasedPricePanel.vue`). The decision-summary tab has no analyses of its
  own: it sends what the other tabs have already produced, and R reports anything
  missing in its own not-yet-available wording. The value-based price tab has no
  result until its own button is used, and R reports a price it could not identify
  as "Not available" with its own reason rather than as a number. See
  [`../FRONTEND_PLAN.md`](../FRONTEND_PLAN.md) for what is still planned.
- The readiness tab inherits the population and the two engagement values from the
  shared assumptions instead of holding its own copies, so changing them there
  changes the readiness request too. Its "Traffic-light rules" disclosure carries
  the rule wording and colour meanings copied from `app.R`, but not the numeric
  thresholds, which stay in the R module and are not part of the API contract.
- Readiness inputs are one field per row, grouped under the headings R returns in
  each spec's `group` field. Three readiness InfoTips appear: R's own definitions
  for `review_minutes` and for the interoperability choice set (the tutorial's
  interoperability sentence, which the API publishes as that choice set's `info`
  field), plus one interface-written sentence beside the "Algorithm governance"
  heading. R deliberately holds no definition for the algorithm-governance
  control — its four approach levels carry their own meaning — so the heading
  sentence describes what that domain assesses rather than restating a model
  definition.
- A posted number is preserved at the 15 significant digits both services
  transmit, so the PSA draws the value-of-information panel sends back reach R
  unchanged; a value carrying more digits than that would still be rounded.
- CSV downloads are written without a UTF-8 byte-order mark, which Shiny's writer
  adds. The column names and values are identical, so this only affects an Excel
  user who opens the file by double-clicking.
- The bundle is a single chunk of roughly 750 kB (about 250 kB gzipped), mostly
  ECharts. Code splitting is a later optimisation, not needed for a local tool.
- The `/`, `/app` and `/about` addresses are resolved in the browser, not by the
  server. Vite's dev server and `vite preview` both serve `index.html` for any of
  them, so all three can be loaded or reloaded directly; a production static host
  must be given the same fallback (serve `index.html` for an unmatched path), or a
  direct load of `/app` or `/about` would return a 404.
