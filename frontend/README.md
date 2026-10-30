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

Open <http://127.0.0.1:5173> for the OpenHealth landing page, `/blog` for the
blog, or go straight to `/app` for eQalb and `/about` for About OpenHealth: the
dev server resolves all of them from the same `index.html`, so any of them can be
loaded or reloaded directly. The dev server proxies `/api` to the API, so the
browser stays on a single origin and no CORS work is needed. Point it elsewhere
with `EQALB_API_URL` (for example when the API runs on another port):

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
| `npm run lint` | oxlint over the `.ts` sources and the `<script>` blocks of `.vue` files. |

`vue-tsc` is what type-checks the single-file components, which is why it runs in
`build` and in `typecheck` — including the `.vue` templates.

`npm run lint` is not a substitute for that. oxlint is configured with its `vue`
plugin, so it does lint the `<script>` block of each `.vue` file alongside the
`.ts` sources; the lint run reports 94 files (60 `.vue`, 34 `.ts`). It does not
validate template markup, and passing lint says nothing about runtime behaviour,
accessibility or visual design. The three commands check different things:

- `typecheck` covers TypeScript in `.ts` files **and** in `.vue` templates.
- `lint` covers `.ts` files and `.vue` `<script>` blocks, and reports warnings
  without failing the command.
- `build` repeats `typecheck` and then bundles.

None of them exercises the running application against the R API, renders a
template, or checks appearance.

One further command checks something the three above cannot: the mathematics in
the method notes. Given a JSON export of the note dictionary — `module_methods`
from `GET /api/defaults`, or `MODULE_METHOD_NOTES` written straight from R — it
typesets every display formula and every `$…$` span in it with the same KaTeX
build the app uses:

```
node scripts/check-math.mjs ../math-notes.json
```

It prints the failing note, block and expression, and exits non-zero, so a
malformed equation is caught before it reaches a browser. It checks the TeX
only; it does not check the surrounding prose or appearance.

## Layout

```
index.html              # mounts the app; applies the stored theme before first paint (the app's
                        # eqalb.theme, and the landing page's own openhealth.landing.theme on the
                        # landing addresses), and declares the browser-tab icons
public/
  favicon.ico           # the OpenHealth mark at 16, 32 and 48 px, generated from
                        # src/assets/onlylogo.png
  favicon-16x16.png     # the same mark at 16 and 32 px, for the tab icon and its density variant
  favicon-32x32.png
src/
  main.ts, App.vue      # shell: the public OpenHealth pages, then the eQalb app (Home button, status, theme, assumptions, tabs)
  api/
    types.ts            # response contracts, transcribed from live responses
    client.ts           # typed fetch client; no defaults, no model arithmetic
  composables/
    useModel.ts         # shared store: inputs, results, busy/error state, runs
    useTheme.ts         # the app's light/dark state and the chart palette (eqalb.theme / data-theme)
    useLandingTheme.ts  # the landing page's and the blog's own light/dark choice (openhealth.landing.theme /
                        # data-landing-theme), alive only while one of those pages is mounted
    useAppLaunch.ts     # the landing page's transition into the app: the sequence, its timings and
                        # its safety clears; the look is in landing.css/styles.css
    useEcharts.ts       # ECharts instance lifecycle for a Vue ref
    useAppView.ts       # which page is shown, plus the /, /blog, /blog/<slug>, /app and /about addresses, the history entries and the document title
    useDisclosure.ts    # Escape closes the disclosure the focus is inside, app-wide
    useAppBusy.ts       # the app-wide busy state the loading indicator shows: ref-counted start/finish, label, isActive
    useTutorialJourney.ts  # The Journey's own session: chapter/screen, reveal state, one price lever, the initial and moved base case, the provisional view and the price the learner called reasonable; separate from useModel
    useResultEntrance.ts   # the one-shot result entrance: an analysis's committed revision becomes an alternating animation class, once per revision, remembered across a panel's unmount
    useTabUnderline.ts     # places the analysis tab strip's indicator from the selected tab's own box: 190 ms slide between tabs on one row, a jump across a wrap, a resize or a font change, cleaned up on unmount
    useLoadingMessages.ts  # the lighthearted line under a long operation's factual status: one list of 20 sentences, a 1 s grace, a 7 s interval, a 280 ms opacity-only crossfade, and a static line under reduced motion
    useDownloadNotice.ts   # the prepared-download notice: one module-level notice, prepared/failed wording, a 7 s auto-dismiss only for successes
    useDialogTransition.ts # the shared dialog transition's name and its leave hook, which makes the outgoing dialog inert
    useModalFocus.ts       # a dialog's keyboard containment: focus moved in on open, a Tab loop inside, the page behind it inert (through the dialog's relatives, each element's prior state restored), focus returned to the opener when it closes
    usePageEntrance.ts    # the page-entry fade: one 160 ms opacity animation on the page wrapper, once per entry (page + post slug), skipped on a first paint, on Back/Forward, during the launch, while a dialog is open and on a scrolled arrival
  views/
    OpenHealthHomeView.vue      # the landing page at / : one scrolling page in three panels - the eQalb
                                # hero (its large centred title, subtitle and "Open the app", plus two
                                # side arrows that reveal an SQL for Healthcare Managers teaser with
                                # its SVG-grid and typographic logo lockup), OpenHealth, About me
                                # (with the portrait)
                                # - under a floating section navigation, with the landing page's own
                                # theme, a scroll-spy and the per-panel entrance reveal; it hands over
                                # to the app through LaunchTransition rather than swapping the page
                                # straight away
    AboutView.vue               # About OpenHealth at /about : the founder, the motivation, and how to get involved
    BlogIndexView.vue           # the blog at /blog : every published post, newest first, as text with a rule
                                # between the entries - no cards, no thumbnails
    BlogPostView.vue            # one post at /blog/<slug> : the title, its date and the post's own blocks in a
                                # narrow reading column, or a readable not-found state when the slug names no post
    HomeView.vue                # eQalb's own start screen at /app : eQalb wordmark with ECG pulse, credit, actions, links
    JourneyView.vue             # The Journey at /app?journey=1 : the shell, the notice and the chapter navigation
    ProjectDescriptionView.vue  # what the model is, what it covers, contact
    DownloadResultsView.vue     # what this session produced, and the ZIP download
  export/
    zip.ts              # dependency-free store-only ZIP writer (CRC-32)
    csv.ts              # CSV quoting/joining and text download (shared)
    resultsPackage.ts   # results-package files built from the store
    tabExports.ts       # per-tab CSV builders (base case, OWSA, KM summary)
  content/
    blog/               # the blog's posts: one module per post, the registry that publishes them
                        # (posts.ts) and the content model they are built from (types.ts); README.md
                        # documents the format and how to add, preview and publish a post
  components/
    AppLoadingIndicator.vue # the only loader: a thin teal top bar after 350 ms and a small eQalb/ECG card after 2.5 s, its trace pulse crossing the line once per cycle
    EcgOverlay.vue          # the one overlay box: perimeter + interior + one reveal sequence, used by every overlay
    EcgFrame.vue            # the ECG perimeter a box wears instead of a border: four sides of one trace, seeded from
                            # the south-west and north-east corners, then a signal passing along the same path for ever
    LaunchTransition.vue    # the landing page's arrival into the app: a still copy of the Home screen's
                            # eQalb composition, wiped in behind a passing band of light (decoration only)
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
    ResultTrace.vue              # the ECG trace that passes under a panel heading: one short line whose draw follows a teal highlight, then gone
    ButtonLabel.vue              # the two-label run button: idle and pending in one grid cell, with the small ECG on the pending label
    DownloadNotice.vue           # the prepared-download card in the corner, role="status" / role="alert"
    tutorial/           # the two pieces The Journey reuses: TutorialControl (a labelled input control)
                        # and TutorialStepStage (the fade between steps)
  journey/            # the redesigned tutorial: the case brief, the guided Chapter 1 beats, the
                        # cost-effectiveness plane the beats reveal one element at a time, the later
                        # chapters' own figures (the one-way tornado, the price track, the budget bars,
                        # the readiness chips and — reused from components/charts/ — the simulated
                        # survival curves) and the guide ring that points at the next action
    charts/             # one component per chart, options only
    DataTable.vue, MetricCard.vue, InfoTip.vue, StaleNotice.vue, table.ts
    BlogLayout.vue, date.ts     # in components/blog/: the blog's header, footer and reading column shell
                                # (the one place its landing theme is owned), and a post date as text
  format.ts             # EUR/QALY/percent formatting; `null` becomes a dash
  styles.css            # tokens reproducing the Shiny app's teal palette
  landing.css           # the landing page only: its own palette, typography, panels and motion, all
                        # scoped under .landing and html[data-landing-theme]
  blog.css              # the blog only: its layout and reading column, scoped under .blog; it declares
                        # no palette of its own and reads landing.css's tokens
  assets/
    mahmood-portrait.png # the About me portrait the app ships (640 x 591, 346 kB); keeps the
                         # cut-out's alpha, imported so the build fingerprints it, rendered at
                         # <= 288px and lazy-loaded
    onlylogo.png         # the OpenHealth mark (1024 x 1024 RGBA, genuinely transparent - the
                         # corners and 55% of the pixels are fully see-through, with no white
                         # background), the source of the tab icons in public/; not referenced by
                         # the build, so the master stays untouched
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
- **Illustrative scenarios.** Three numbered buttons under "Reset model inputs"
  (1 red: eQalb clearly not preferred; 2 yellow: uncertain, borderline; 3 green:
  eQalb clearly preferred) each set all 16 model inputs and the reference WTP
  threshold in one action through `model.setInput`. A scenario names only the
  inputs it moves (`src/content/presets.ts`); every other input takes R's
  base-case default and the threshold is R's reference. Applying one runs
  nothing and changes no calculation, and the button reads as chosen while the
  inputs match it. They are illustrative starting points, not validated clinical
  cases.
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
- **A new result fades in under a passing ECG trace, and the tutorial moves
  between steps.** Two restrained animations, both decoration and both driven by
  state that already exists. When an analysis commits a result, its top-level
  summary fades in over 240 ms while, in a slim strip between the panel heading
  and its description, a short ECG trace draws itself as a soft teal highlight
  travels along it (780 ms); the strip then fades away (180 ms) and the heading is
  left clean. The trigger is the per-analysis revision counter in
  [`useModel.ts`](./src/composables/useModel.ts) (bumped only when a run
  resolves), [`useResultEntrance.ts`](./src/composables/useResultEntrance.ts)
  turns a revision into an alternating animation class once per revision and
  remembers at module scope what it has shown, so a second run replays the
  entrance even when its numbers are identical, while a tab switch, a theme
  change, an input edit and a failed request never do.
  [`ResultTrace.vue`](./src/components/ResultTrace.vue) is the trace
  (`aria-hidden`, so it adds nothing to a heading's accessible name), and its
  strip is reserved in the heading block at every state — hidden it is only
  transparent — so nothing shifts when it draws or leaves. Tutorial steps and
  Part 2 sections cross-fade with a few pixels of horizontal travel through
  [`TutorialStepStage.vue`](./src/components/tutorial/TutorialStepStage.vue),
  which renders exactly one step at a time (Vue's own `out-in` transition can
  leave the outgoing step in the document when a second move interrupts it, which
  would duplicate the step heading's `id`), lands on the newest step however fast
  Next and Back are repeated, moves focus to the arriving step's heading, and
  takes no request, input or result with it. `prefers-reduced-motion: reduce`
  removes both outright — the stage swaps in one frame — and `@media print`
  removes the entrance.
- **Routine interactions are refined, not reinvented.** Five small things, all
  presentation: the analysis tab strip carries one sliding teal indicator
  ([`useTabUnderline.ts`](./src/composables/useTabUnderline.ts)) that measures the
  selected tab's own box, slides for 190 ms only between two tabs on the same row
  and jumps into place across a wrap, a resize or a font change, so it is never
  drawn in the wrong place (it is `aria-hidden` and takes no pointer events, and
  the tab semantics, roving tabindex and keyboard selection are untouched); the
  existing `<details>` disclosures grow to the content's real height where the
  engine supports `::details-content` with `interpolate-size`, with the existing
  marker becoming a chevron that rotates 150 ms, and open instantly where it does
  not; the nine run buttons use
  [`ButtonLabel.vue`](./src/components/ButtonLabel.vue), whose idle and pending
  labels are two spans in one grid cell, so the button's box and its accessible
  name are exactly one label at a time and the box does not move between states
  (the pending label states the operation — and the PSA's iteration count — beside
  a small `aria-hidden` ECG, and the button's own disabled state is what prevents a
  second submission); a prepared export reports once through
  [`DownloadNotice.vue`](./src/components/DownloadNotice.vue), a corner card that
  is `role="status"` when the download was handed to the browser and `role="alert"`
  when it could not be prepared, auto-dismissed only in the first case, with a
  Dismiss button that never takes the focus and wording that never claims a file
  was saved (`DownloadResultsView` keeps its own in-page line, so nothing is
  reported twice); and the four dialogs fade their backdrop and move a few pixels
  while fading through
  [`useDialogTransition.ts`](./src/composables/useDialogTransition.ts), which also
  marks the leaving dialog `inert` so an outgoing dialog cannot keep the focus or
  block the page; [`useModalFocus.ts`](./src/composables/useModalFocus.ts) is their
  keyboard half, moving the focus to the dialog's own first action, looping Tab and
  Shift+Tab inside it, making everything outside it inert, and returning the focus
  to whatever opened it. Under a long wait, the loading indicator adds one lighthearted
  sentence beneath its factual line
  ([`useLoadingMessages.ts`](./src/composables/useLoadingMessages.ts)): 24
  sentences in one list, the first shown after a 1 s grace and the next every 7 s
  from a shuffled cycle that never repeats the sentence on screen. A change is a
  crossfade — the outgoing sentence fades out over 150 ms and the incoming one
  fades in over the same 150 ms after a 130 ms delay, 280 ms in all, opacity only
  — and every sentence is rendered in the same grid cell, so the line's area is as
  tall as the longest of them and neither the first sentence nor a change of
  sentence moves the card. The block is `aria-hidden` so nothing changing is
  announced, it is held still under `prefers-reduced-motion` (including when the
  preference is turned on mid-wait, which stops the rotation and cancels the
  crossfade in flight), and every timer is cleared when the wait ends or the
  component unmounts.
- **A page fades in when a link or button moves you to it.** One 160 ms opacity
  fade, on the `.page-entry` wrapper the shell puts around the page content — not
  on the shell, which holds the loading indicator, the download notice and the
  launch overlay, all fixed to the window. The class is toggled in the same
  microtask as the DOM update, so the arriving page is never painted at full
  strength and then faded, and its end state is full opacity, with a safety clear
  so a stalled animation cannot leave a page invisible. It plays once per entry,
  where an entry is the page plus the post's slug on the blog, so the index, one
  post and another post are three arrivals, while a rerender, an input, a theme
  change, a loading message, a tutorial step and an analysis-tab switch replay
  nothing. Five arrivals are shown as they are instead, each because a fade would
  be wrong rather than merely unnecessary: the first paint, Back and Forward, the
  landing page's crossing into the app (the launch sequence owns that), any move
  made while a dialog is open, and any arrival the page is already scrolled into —
  which, with the Home screen's own pinned theme button, is what keeps fixed
  chrome exactly where it is. See
  [`usePageEntrance.ts`](./src/composables/usePageEntrance.ts).
- **The landing page is a page of its own.** `/` is one scrolling page whose three
  panels (eQalb, then OpenHealth, then About me) are reached through its floating
  navigation, which smooth-scrolls, tracks the visible panel with an
  `IntersectionObserver` and marks it with `aria-current`. The first panel keeps
  its `#eqalb` anchor and its original centred hero composition: the small
  section label, the very large title, one short subtitle and the "Open the app"
  action. Two discreet side arrows — thin, subdued artwork on a transparent hit
  area, with no visible button frame — cycle to an SQL for Healthcare Managers
  teaser and back, wrapping in both directions. eQalb is shown on first load,
  nothing rotates on a timer, there is no visible counter, and the inactive
  slide is inert and hidden, so its link or action has no focusable controls;
  switching keeps focus on the arrow that was pressed. The hero keeps the
  taller slide's height, so the arrows and the content below never move. The page
  keeps its own light/dark choice in [`landing.css`](./src/landing.css) and
  [`useLandingTheme.ts`](./src/composables/useLandingTheme.ts), which publish it
  as `<html data-landing-theme>` and take that attribute away when the page
  unmounts: the app's `eqalb.theme` and `<html data-theme>` are neither read nor
  written there, and no landing rule outlives the page. Scrolling is the
  browser's own and nothing is snapped, trapped or hijacked — scroll snapping was
  removed because it pulled small wheel notches back to a panel boundary and made
  an intermediate position impossible to hold — and the one action that matters,
  "Open the app", is the existing `/app` address.
- **The SQL teaser carries a typographic logo lockup.** The 3×3 query grid is
  inline SVG; "SQL" and "for Healthcare Managers" are ordinary HTML text in the
  page's existing sans stack, at semibold and regular weights, so the letterforms
  come from a real typeface rather than drawn paths and the lockup's width
  follows the typography. In the accepted composition the grid stands marginally
  taller than the wordmark's cap height (measured at about 1.02×), about
  three-quarters of a grid-cell of clear space sits before the wordmark, and the
  two visual centres are aligned; the supporting line is not stretched or
  width-forced. Its blue accent, dark/pale lettering and one highlighted grid
  cell come from colours sampled from the approved reference, declared as
  `--sql-logo-*` custom properties on `.landing__sql-logo` only; no global
  accent, typography or page background changes. Every internal size is a
  fraction of the eQalb title's line box, which is what keeps the shared title
  band and the default hero unchanged.
  This mark is an **accepted provisional teaser identity, not a final
  cross-platform brand asset**. Two considerations were deferred rather than
  resolved: the text resolves through the system sans stack, so the exact
  letterforms and widths vary by operating system (a bundled webfont would make
  them identical everywhere), and the supporting line measures about 11 px on
  viewports 384 px wide and below, which stays readable but is small. Both were
  left as they are deliberately; changing either would be a separate decision.
- **The landing page's three sections are centred, and the two below the hero
  fade with the scroll.** Each panel's content is a centred block —
  the hero centres its own text, the OpenHealth column takes a `40rem` measure
  with its text centred to match the hero, and the About group a `56rem` measure
  with its prose left-aligned, since a paragraph reads better that way — and the
  page footer shares the About measure so the rule above it lines up with the
  content it closes. The OpenHealth heading is two deliberate lines
  (`.landing__heading-line` blocks), not one run left to wrap.
- **The reveal is linked to the scroll, not to a timer, and it fades both ways.**
  The view writes a `--reveal` value from 0 to 1 onto each group's inner element,
  read from the wrapper's own untransformed bounds: the entry looks at its top
  edge, transparent at 90% of the viewport and fully opaque by 55%, and the exit
  looks at its bottom edge, still opaque until only the top 22% of the screen holds
  it and fully transparent once that edge reaches the top. Opacity is the lower of
  the two, so a group fades in as it arrives, holds at full strength through a wide
  central band, and fades out as it leaves — and the whole thing reverses when the
  reader scrolls back up and repeats on every pass. Nothing latches: there is no
  "seen it once" state, so a group that has been read is faded again on the way
  back. Using the bottom edge for the exit is what keeps long content legible — a
  tall block stays fully readable all the way through instead of being faded while
  it is still being read — and a group that cannot reach the exit range at all
  (the last section, which the document ends beneath) simply stays fully visible,
  with no blank space added to force a fade. The stylesheet has no duration and no
  easing on purpose, so the fade is a function of where the content is: stopping
  halfway holds the intermediate opacity and continuing from there finishes it.
  Two elements do two jobs — `.landing__reveal` is the wrapper the geometry is
  measured from and is never transformed, `.landing__reveal-inner` is what is
  painted, so its own transform cannot feed back into the measurement. `--reveal`
  drives opacity and a separate `--reveal-lift` drives the 16px rise, which belongs
  to the entry alone so content does not drift downwards as it leaves. Work is
  batched into one `requestAnimationFrame` from a passive `scroll` and `resize`
  listener (both removed, with any pending frame, on unmount) and the position is
  measured fresh each paint so a reflow cannot leave it stale. Focus is the one
  exception to "the scroll decides": a group holding keyboard focus is painted
  fully in the same turn, because a link must never be focused while it is
  invisible, and the scroll value comes straight back when focus leaves. The hero is
  deliberately outside all of this: it is the doorway to the app, so it is fully
  visible from the first paint and its button is never behind a scroll.
- **The reveal has a diagnostic, and it is development-only.** Opening
  [`/`](./src/views/OpenHealthHomeView.vue) with `?debugReveal=1` on the dev
  server adds a fixed panel reporting the section in view, the reduced-motion
  preference, the element that actually scrolls and the offset within it, whether
  the reveal is armed, and then a row per group giving the wrapper's top edge, its
  top and bottom edges as fractions of the viewport height, the entry and exit
  progress, and the computed opacity of the element that is actually painted. It
  lives in
  [`RevealDiagnostic.vue`](./src/components/RevealDiagnostic.vue), reached through
  a dynamic import behind `import.meta.env.DEV`, so a production build emits no
  chunk for it: neither its markup, nor any of its wording, nor its rules reach a
  deployed bundle. An inline `v-if` on the same flag would not have achieved that —
  the compiled template and its label strings would have stayed in the bundle,
  permanently false but present. The panel is `aria-label`led, is not focusable and
  adds nothing to the page otherwise. It exists because "the fade is invisible" and
  "the fade is right there" are claims about a machine that cannot always be
  inspected directly, and the panel lets the two be told apart from a screenshot.
- **Nothing can leave a group hidden.** The scroll-driven state is scoped to a
  `landing--armed` class the view sets only when it can drive the reveal, the
  `var(--reveal, 1)` fallback in the stylesheet is the visible state, a failure
  while setting up shows everything, focus inside a group overrides the scroll,
  and `prefers-reduced-motion` and print both override the rule outright.
  **Scroll snapping is gone**: the page used
  `scroll-snap-type: y proximity`, and a small wheel notch near a panel boundary
  was pulled back to the boundary — measured — so the reader could not hold an
  intermediate position and the fade had no scroll distance to travel across.
- **The landing page hands over to the app with one transition, not a second
  animation.** "Open the app" is still the real link to `/app`, so a modified or
  middle click opens it in a new tab as before; a plain left click plays the
  crossing instead: the landing page fades, an overlay in the app's own palette
  wipes in a still copy of the Home screen's eQalb composition behind a band of
  light, the light falls into its looping state, and the overlay dissolves as the
  app's existing `home-rise` entrance fades the interface in. The sequence is in
  [`useAppLaunch.ts`](./src/composables/useAppLaunch.ts) (timings in one place,
  about 1.2s end to end) and the look is the "Landing page to app transition"
  section of [`styles.css`](./src/styles.css). Both fades are CSS animations
  rather than `<Transition>` classes, so a delayed frame shows the crossing
  further along instead of not at all; the overlay is `aria-hidden`, holds
  nothing focusable and is `pointer-events: none`, so the app is live underneath
  it from the moment it is swapped in; and reduced motion drops the sweep and the
  wipe for a quick fade.
- **The landing page carries no disclaimer.** The simulated-data and educational
  wording lives inside the app, where the results are, so `/` does not repeat it.
- **The About me portrait** ships as
  [`src/assets/mahmood-portrait.png`](./src/assets/mahmood-portrait.png), a
  640 × 591 image imported by the landing view so the build fingerprints it and
  a missing file fails the build. It has to stay a PNG: it is a cut-out with a
  transparent background (about 60% of its pixels), which a JPEG would flatten. It
  sits in
  the About panel's narrow column under the name, carrying no box of its own — no
  border, background, frame or shadow — so the cut-out sits directly on the
  landing page's own background in either theme; its intrinsic `width`/`height`
  attributes reserve the box, so nothing shifts as it loads, and the panel stacks
  it above the prose below 900px. The landing page's reduced-motion behaviour —
  including the portrait's panel, which shows its content immediately rather than
  fading it in — was verified by emulating the setting over CDP, not by reading
  the stylesheet.

- **The browser-tab icon is generated from the OpenHealth mark, not drawn.**
  [`src/assets/onlylogo.png`](./src/assets/onlylogo.png) (1024 × 1024, RGBA) is a
  circular mark on a genuinely transparent background — 55% of its pixels are
  fully transparent and all four corners have alpha 0 — so there was no white
  background to remove and none was touched. The files in `public/` are generated
  from it by cropping the transparent surround to the mark's bounding box plus a
  3% margin (the mark then fills 94% of the square) and box-averaging down with
  **premultiplied alpha**, which is what keeps a cut-out's edges from picking up a
  dark or light fringe. The source is kept unmodified and is not part of the build.
  [`index.html`](./index.html) declares the `.ico` first with
  `sizes="16x16 32x32 48x48"` — the sizes it actually contains, rather than `any`,
  which would claim a scalable icon it is not — and then the two PNGs, and no
  longer declares an SVG icon: the stock Vite
  lightning-bolt `favicon.svg` was deleted along with its declaration, so nothing
  can take precedence over the mark. A single `index.html` serves `/`, `/blog`,
  `/app` and `/about`, so all of them carry the same icon. There is no web manifest
  and no PWA setup.

## Blog

`/blog` is a reverse-chronological list of the posts and `/blog/<slug>` is one post
at its own address. The blog is the landing page's sibling rather than an eQalb
screen: it uses the landing palette, typography and stored theme preference, but
its own layout — its rules live in [`blog.css`](./src/blog.css), scoped under
`.blog`, and it declares no palette of its own, reading the landing tokens
instead. The theme choice is shared with the landing page through
[`useLandingTheme.ts`](./src/composables/useLandingTheme.ts); the app's
`eqalb.theme` and `<html data-theme>` are neither read nor written, and
`<html data-landing-theme>` is removed as soon as the last landing-themed page
unmounts, so nothing leaks into `/app`. An address that names no post shows a
readable "Post not found" state at that address rather than redirecting.

Navigation keeps two separate things intact. A page reached by **following a
link** is read from its top: the blog's shell does that for its own pages, and
the wordmark that leaves for `/` asks the view store for the same thing at the
link ([`followLandingLink`](./src/composables/useAppView.ts)), because the
landing page has no scroll reset of its own and would otherwise keep the position
the reader had in the blog. A page reached by **Back or Forward** is left exactly
where the browser restores it — `cameFromHistory()` distinguishes the two, and
nothing forces a history navigation to the top. The landing page's own section
links (`eQalb`, `OpenHealth`, `About me`, `Back to top`) are anchors inside that
page and are untouched by any of this.

Posts are content with no pipeline of their own: each one is a module in
[`src/content/blog/`](./src/content/blog) — typed data, rendered block by block,
with no Markdown parser, no HTML and no CMS — and it is published by being listed
in [`posts.ts`](./src/content/blog/posts.ts). One post is published — the release
of eQalb and the introduction of OpenHealth, 14 October 2026 — and the index shows
a restrained empty state whenever the list is empty rather than a placeholder
article.
[`src/content/blog/README.md`](./src/content/blog/README.md) documents the format
and the whole workflow:

- **Add a post.** Write `src/content/blog/<slug>.ts` with one `BlogPost` (slug,
  date, title, optional summary, and a body of paragraphs, headings, lists and
  quotes), then import it and add it to `POSTS` in
  [`posts.ts`](./src/content/blog/posts.ts). A file that is not listed is a draft:
  it is type-checked, linted and built with the rest of the sources, but no address
  shows it and the index does not mention it.
- **Preview it.** `npm run dev`, then `/blog` and `/blog/<slug>` on
  127.0.0.1:5173. Run `npm run typecheck`, `npm run lint` and `npm run build`
  before publishing, since there is no automated test suite.
- **Publish it.** The blog is part of the frontend bundle, so a post ships with
  the next frontend release: merge to `main` and the existing
  [`deploy-frontend.yml`](../.github/workflows/deploy-frontend.yml) workflow
  type-checks, lints, builds and publishes it behind the same `dist` symlink. Its
  `on.push.paths` already lists `frontend/**`, which contains the content
  directory, so **no workflow change is needed**, and Caddy's
  `try_files {path} /index.html` already serves `/blog` and `/blog/<slug>`
  directly, so no server change is needed either.

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

The deployment server and the GitHub `production` environment are configured, and
one end-to-end automated deployment has succeeded. Neither the automatic rollback
after a failed validation nor the manual rollback has been exercised yet, so both
remain untested. That successful release was built from `main`, and the workflow
only deploys on a push to `main` or a manual dispatch: a build from another branch
is **not** part of any deployed release, so the live site serves an older bundle
that cannot show a newer landing page, palette, portrait or scroll reveal. Review
such work on the dev server (`http://127.0.0.1:5173`) until it is merged and
deployed.

## Known limitations

- No automated test suite yet; the app was verified by hand against a running
  API.
- The blog has one post, *Release of eQalb & The introduction of OpenHealth!*
  (2026-10-14), which is the author's own text published as written. The article
  path was verified against it; the empty state and the not-found state were
  verified with temporary posts that were deleted afterwards. There is no Markdown
  renderer — a post is typed data in [`src/content/blog/`](./src/content/blog) —
  so if Markdown is wanted later it needs one small dependency and its approval.
- The landing page's footer link is now "Blog"; it used to be "About OpenHealth".
  `/about` is unchanged, still resolves directly and still offers "Back to
  OpenHealth", but the landing page no longer links to it. That was the requested
  change rather than an oversight, and it needs a decision before `/about` gains
  an entry point again.
- The blog's shell starts a followed page at the top, and the wordmark that leaves
  the blog for `/` does the same for the landing page; a Back or Forward entry is
  left where the browser restores it (`cameFromHistory()` in
  [`useAppView.ts`](./src/composables/useAppView.ts) distinguishes the two).
  The landing page is still not reset when it is reached some other way from a
  scrolled public page — `/about`'s "Back to OpenHealth" link inherits the
  position, as it did before the blog existed. Pre-existing behaviour, out of
  scope here.
- The parity audit is complete for P0, P1 and the P2 triage. The P0 finding and
  all six P1 findings are implemented, and the 15 P2 polish findings are triaged:
  the two approved pre-1.0 fixes are implemented (the one-way sensitivity
  ranked-outcome mismatch, and the tab-strip and table accessibility semantics —
  a `tablist` with `role="tab"`, `aria-selected`, `aria-current` and
  `aria-controls`, a `tabpanel` named by its tab, and an accessible name on every
  table, including the four raw readiness and HTA tables), and the remaining
  findings are deferred, three of them needing backend work. No deferred item is
  started without approval. See [`../FRONTEND_PLAN.md`](../FRONTEND_PLAN.md).
- **Historical — retired from the frontend.** The next three items describe the
  legacy Guided Tutorial (Part 1 and Part 2) as it was delivered. Its screen had no
  route after The Journey replaced it, and its Vue view, session and components
  have since been removed. The R module (`eqalb_tutorial.R`) and its
  `/api/tutorial`, `/api/tutorial/part1` and `/api/tutorial/part2*` endpoints
  remain; the browser app no longer calls them.
- The Guided Tutorial Part 1 was implemented in Vue as a self-contained
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
- The redesigned Guided Tutorial's first slice is implemented behind
  `/app?journey=1` (at the time, the tutorial described above stayed the default
  entry; The Journey has since replaced it), and the legacy tutorial was left
  unchanged at that stage. It covers the case brief and Chapter 1 (base case): `JourneyView`
  renders the shell, `useTutorialJourney` holds the session, and
  `components/journey/` holds the brief, the chapter's screens and the
  cost-effectiveness plane. R owns the case, the wording, every reveal sentence and
  the interpretation: `eqalb_tutorial_journey.R` publishes
  `GET /api/tutorial/journey`, and `POST /api/tutorial/journey/base-case` returns
  the base case through `eqalb_tutorial_ce()`, so its values are the same values
  Part 1 returns for the same price.

  The chapter is one continuous guided sequence, not a set of screens. A guide ring
  and caret point at the single thing to act on and everything else is softened, and
  a completed action is the advance: selecting eQalb reveals the extra cost and
  hands attention to the health action, revealing the health hands it to the ratio,
  revealing the ratio hands it to the price. There is no forward button between
  those four stages — the chapter has no timer either, so nothing advances except
  the learner's own action. The learner may move the price as often as they like;
  the one explicit Continue is a quiet control that appears once they have moved it,
  and it carries the unchanged-health observation and the reflective question with
  the price exploration rather than as stages of their own. A quiet Back revisits an
  earlier stage without erasing anything, and Resume returns to where the learner
  was. Every reveal stays on screen, so the chapter accumulates one picture instead
  of replacing it. There is no table, no traffic light and no threshold line; text
  is dimmed by opacity, never blurred, and the guide is `aria-hidden`,
  `pointer-events: none` and never focusable. Focus is moved only when the control
  the learner used has left the document, so dragging the price never loses focus.
  Reduced motion removes the pulse, the sweep and the chart animation while keeping
  every reveal.
- The journey now runs eight chapters behind that same shell: the base case, one-way
  sensitivity, the uncertainty view, the value of information, the price, the budget,
  the readiness check and the time to a first heart attack or stroke. Each is one
  component in `components/journey/` and each is
  computed by the R function the matching dashboard tab uses, so no chapter carries a
  calculation of its own. The readiness chapter is the only one that runs
  no model: it asks four scenario-worded questions about the deployment, passes those
  answers with the case's six fixed inputs to `calculate_readiness()`, and draws the
  seven domains as labelled chips with the status counts as a secondary summary rather
  than a score. No state requires a Green. The journey's handoff card (R's
  `journey.end`: one sentence, then Open the analysis app / Start the journey again /
  Exit to Home) follows the closing statement of the last chapter — the time-to-event
  view — because the chapter list has nothing after it, so a chapter added later moves it
  automatically; it is never shown in a standalone explainer.
  The last chapter is the same comparison drawn as time to a first MI or stroke: one
  `simulate_eqalb_survival()` run at the case's effect assumption and the model's own
  annual risks, with the tab's own chart component rendering the two curves and their
  bands unchanged. Three states read the same curves at a time the learner chooses (1, 5
  or 10 years): the two estimates, what a downward movement is, and the two estimates
  compared in percentage points. One response carries all three times, so changing the
  time asks R for nothing, and no p-value, hazard ratio or median is published. The
  downward-movement state passes the chart an optional `highlight` — the arm, the two
  years and the level R's sentence names — so the interval being described is shaded on
  the curve; with no highlight (every other caller, including the tab) the chart draws
  exactly as it always did. In a standalone lesson the first advance fetches the curves
  and stays on the first state, so the two estimates are read before the lesson moves on;
  the next two advances walk the remaining states. The
  panel keeps the title, a qualifier saying the estimates are simulated and other-cause
  deaths are censored, and the sentence each state adds; the hypothetical reading of a
  censored estimate and the limit on what the curves say are in its disclosure.
  The readiness lesson is also reachable on its own: `ReadinessPanel` carries an
  "Explain this" control that opens `/app?journey=1&explain=readiness`, where the same
  chapter renders without the chapter list, the progress line, the earlier-chapter Back,
  the restart control or the bridges, under R's one orientation sentence and a "Back to
  analysis" control. Opening it requests nothing — the lesson's first advance calls the
  readiness endpoint — and it keeps its own answers, leaving the journey's chapter,
  stage, answers, cached results, price and score untouched. Returning sets the
  dashboard tab (kept in the navigation store, which is why a direct link that never had
  a dashboard behind it still lands on readiness) and leaves every dashboard input and
  result exactly as it was. A lesson also offers "Read the whole journey", which closes
  the lesson (restoring the journey's saved position and cached results) and then opens
  the journey through the store's `showJourney()` — the one entry that clears the
  `explain` flag as well as the page, so the address cannot keep asking for a lesson that
  is no longer open. The budget and survival modules use the same pattern; the
  survival lesson's curves are cached against R's key for every input the simulation
  reads, so neither the price nor the score can invalidate them and a reopened lesson
  reuses a stored set instead of simulating again.
  Every chapter keeps one panel of teaching copy — the caption, the feedback its action
  produced, and the labels, units and assumptions needed to read the figure, including
  the two utilities the QALY control holds fixed and the one-line definitions of EVPI
  and EVPPI — and puts its methodological caveats, qualifications and scope limits in a
  single closed disclosure under a chapter-specific heading ("How this check works",
  "What this ranking does and does not show", "What these figures cover", "What this
  total covers", "How this score is used"). The sentences are R's and were moved rather
  than rewritten, so nothing is printed twice. The QALY step is the one chapter whose
  disclosure is the panel's information button rather than a second closed block: it
  carries the scale, the role of the score, the one-year line, R's answer at the score on
  screen, the note for the one score the uncertainty analysis cannot draw exactly and the
  reset control, so the step has one disclosure rather than two and its visible panel is
  the caption, the definition, the slider and its value and the two held utilities.
  `FRONTEND_PLAN.md` and `api/api_contract.md` carry the detail.
- **What has been verified in the running app, and what has not.** These are kept apart
  deliberately, because "the code says so" is not the same claim as "it was seen working".
  *Observed:* the survival chapter's time marker sits at the selected time, its interval
  shading covers exactly the years R's sentence names, and its comparison beat marks both
  curves and prints both estimates; the completion overlay is the shared box (no border,
  no radius, four measured ECG perimeter edges, interior revealed, focus on its primary
  action); Escape and the close control dismiss it and it does not reopen on its own;
  "Open analysis workspace" returns to the dashboard with every input unchanged; "Restart
  The Journey" returns the journey to its first chapter and clears its cached curves while
  leaving the dashboard untouched; and none of those three actions issued an API request.
  The overlay's opening sequence was sampled on the shared component — content `inert` and
  transparent until the perimeter closes at about 0.8 s, then revealed, then the primary
  action takes focus. *Code-only:* one chapter-transition bridge. A bridge is the recap at
  a chapter's last state and always leads into a chapter whose own calculation must run
  first, and after the survival chapter none is reachable without another simulation, so it
  was not exercised in a browser. It renders the shared `EcgOverlay` (`centre`, `role="group"`,
  `aria-labelledby="recap-heading"`), and `leaveRecap()` opens the awaiting chapter once its
  answer is held or shows the app-wide loader while it waits, never asking twice for the
  same answer. That bridge is the one runtime gap in the tutorial.
  Two behaviours are intended rather than defects: the completion overlay opens as soon as
  the final survival beat is reached, so that beat is read after dismissing it (closing
  returns to the chart, still interactive); and journey position is in-memory session state
  that a page reload clears, which is why the Home control reads "The Journey (resume)"
  during a journey and "The Journey" afterwards.
- The teaching beat is one component (`JourneyBeatCallout`): a compact blue-tinted
  callout with an accent edge and a small step indicator, holding R's sentence for the
  state and, where the state introduces a measure, R's one-line explanation. It replaces
  the plain paragraphs and the accent strip the chapters used to print, so the changing
  lesson text has one shape everywhere it appears; the plane chapters keep theirs inside
  the plane's anchored card, where it points at the region it describes. The callout
  plays a single brief tint when the sentence changes — on Next and on Back — and
  nothing at all under `prefers-reduced-motion`. The figure keeps step with it: the
  Kaplan-Meier chart takes an optional `highlight` (a shaded interval, a time mark, or
  one level per arm), which the survival chapter sets from the beat and no other caller
  passes, so the tab's own drawing is unchanged.
- The end of the journey is an overlay (`JourneyOverlay`), not an inline card: the app's
  own dialog behaviour (focus trap, inert background, focus restore, Escape) with the
  journey's surface — a dimmed page and a dark blue panel that fades in. Its content and
  actions are R's (`journey.end`: `title`, `body`, `open_label`, `restart_label`); a close
  control returns to the final chart without reopening it, and the restart keeps its
  journey-only semantics. The shell is built for reuse, but only the end of the journey
  opens it.
- Every overlay in the app is one box (`EcgOverlay`): the dialogs (the welcome prompt, the
    Home menu and the PSA confirmation), the journey's
    completion overlay, the chapter-transition bridges and the floating information panels.
    Its outline is a rounded ECG perimeter and nothing else — no card border and no second
    frame inside a frame: the box's four sides are the four sides of one ECG line, 9px inside
    the box and joined by corners on a 16px radius, with one heartbeat of the same size centred
    on each side that has room for it, so a box shows four identical deflections rather than a
    repeating comb. The interior surface sits exactly on that line, with the same inset and
    radius and a soft shadow, so the line is the card's own edge; it draws no edge of its own.
    A long box scrolls inside that edge, with a thin, muted scrollbar. The loading card is
    deliberately not one of these and keeps its own treatment.
- The opening is one sequence, run by `EcgOverlay` and timed by the constants `EcgFrame`
    exports: the two origins light at the south-west and north-east corners (220 ms), the four
    traces leave them and close the perimeter (180 ms delay, 620 ms travel), then at
    `ECG_REVEAL_MS` (800 ms) the interior, the words and the actions arrive together (260 ms),
    and the signal keeps passing along that same perimeter — the Home trace's `18 182` dash,
    one diagonal pair and then the other, 4.4 s, infinite. It is the same geometry lit in turn,
    never a second track. No host can time itself differently, and the sequence is identical in
    a 27rem dialog, a 30rem bridge and a small information popover.
- While the perimeter is still forming the content is genuinely unreachable: the stack is
    `inert`, so neither a click nor the keyboard can land on it, and `visibility: hidden` keeps
    it out of the accessibility tree. On reveal the focus goes to the box's own first control
    (`[data-overlay-initial]` where a host marks one) — but only if nothing has claimed it
    first, so a learner who already tabbed to the close control keeps it. Under
    `prefers-reduced-motion: reduce` there is no sequence at all: the perimeter is complete, the
    signal is hidden and the content is live from the first frame.
- Layout is shared with the box: one padding (`2.15rem 2.1rem 1.9rem`, and
    `2.25rem 2.4rem 2rem` for a centred box), one type scale (1.12rem/700 heading, 0.92rem body),
    one rhythm (0.5rem under the heading, 1.25rem above the actions). `centre` boxes size to
    `min(27rem, 100%)` and centre the heading, the sentence and the action group — the completion
    overlay, the chapter bridges, the welcome prompt, the menu explanation and the PSA
    confirmation; `reading` boxes stay left-aligned in the host's column (presentation mode);
    `dense` is the floating popover. On a narrow screen the
    centred box's actions stack at full width rather than shrinking. The close control sits at one
    consistent inset (16px from the top and right) above the content and clear of the trace.
- The chapter-transition boxes are the bridges rendered by `JourneyChapter.vue` (`.recap`),
    not the completion overlay: they are the same shared box. `TutorialStepStage` is only the
    fade between steps and draws nothing.

Ordinary cards, in-place clarifications, method panels and chart panels are content, not
overlays, and are not framed.
- The Home menu offers the narrative tutorial, "The Journey", in place of the legacy
  guided tutorial, and offers it once: the separate Start/Resume button is gone. The
  choice keeps the explanation-before-navigation pattern the workspace entry uses, and
  its action reads "Start" or "Resume" from the journey's own session without making a
  request. The legacy tutorial is no longer reachable: its route was removed, and its
  frontend code has since been deleted.
- On the first arrival at the `/app` Home screen, a welcome overlay asks "New to health
  economics?" and offers "Start The Journey" or "Explore on my own". Either answer, Escape
  or the backdrop settles it, and entering The Journey by any route (the Home menu, a direct
  link, Back or Forward) settles it too. The choice is kept in `localStorage` under
  `eqalb.welcome.v2`, so it persists across browser sessions rather than being asked once
  per session; a browser that answered the earlier per-session question is asked this one
  once.
- Each analysis module's heading carries a "How this is calculated" control
  (`MethodInfo`), a muted periwinkle button distinct from the teal accent, that opens R's
  method note in place. The note is written for a reader who knows mathematics and nothing
  about this codebase, so it carries the mathematics and no implementation, and it carries
  only the blocks that add something: a lead sentence naming the question, then the formula,
  the computation in order, what each symbol means (with its unit and scope), how to read
  the result, only the assumptions that change how the result reads, and a breakdown only
  where it adds something the steps do not. Where a note gives an ICER comparison it states
  it as the incremental net monetary benefit `INMB = λ·ΔE − ΔC` and marks the
  ICER-threshold equivalence as holding only when `ΔE > 0`. It names no function, file,
  endpoint or internal check, and never presents a model default as the reader's current
  input; every note states the model's own method, so it cannot become a textbook
  calculation the app does not perform. The note is R's (`MODULE_METHOD_NOTES`), the same
  dictionary the journey contract republishes, so a module and its chapter describe a
  method identically; the remaining headings are the same in every note ("The relation",
  "How it is computed", "What the symbols mean", "Reading the result"), so a reader who has
  seen one can find the same thing in the next. "How this works" labels the non-economic
  modules, "Explain this" stays the separate interactive-lesson action, and the HTA
  decision summary has no note because its rules are already a disclosure.
- The mathematics in those notes is typeset, not transcribed. R writes each expression as
  TeX inside the ordinary string it already authors, so the wording and the equation are
  one value and cannot drift apart; a principal equation is the note's `formula` and inline
  symbols sit between `$…$` in the prose, the steps and the symbol table. `MathText` is the
  single renderer: it typesets **only** the piece a caller hands it, never the page, and it
  emits KaTeX's HTML *and* MathML. The visual HTML is `aria-hidden` and the MathML carries
  the accessible reading, so the equation is announced once and correctly; `trust: false`
  means no authored expression can introduce a link, an embed or raw HTML; and a malformed
  expression throws, is caught per piece, and shows its own source in a plain fallback
  rather than vanishing or taking the sentence around it down with it. KaTeX is a local
  dependency (`katex@0.18.10`, with its fonts bundled from `katex/dist/katex.min.css`), so
  no equation is fetched from a third party. The pin is deliberate: 0.18 is the first line
  that patches both GHSA-cg87-wmx4-v546 (HTML attribute injection, patched at 0.16.21) and
  GHSA-238p-pmpm-9mq7 (a `trust` bypass, patched only at 0.18.2), and within that line
  0.18.10 is the newest release the publisher has not withdrawn — 0.18.11 is deprecated as
  an accidental breaking release. From 0.18 the package ships its own declarations, which
  is why no local module declaration is checked in. A display equation never widens its
  column: it is split at the break points its author chose (`aligned` rows) and, if it still
  cannot fit, scrolls inside its own box. That box is what keeps the whole page still: every
  flex item between the panel and the equation (`panel__header`'s children,
  `panel__title-row`, the note's own panel) carries `min-width: 0`, because a flex item
  otherwise takes its min-content width — the whole expression — as its minimum and widens
  the page at 320px instead of letting the equation scroll. That fix was measured in the
  running app at 320, 330, 340 and 390 px with the widest note open and closed: no
  page-level overflow at any of them, and the equation scrolls inside its own box only
  where the column is too narrow for it. `node scripts/check-math.mjs
  <notes.json>` typesets every expression in an exported note dictionary and exits non-zero
  on the first malformed one, so a bad equation is caught before it ships rather than in the
  browser.
- The app opens on the Home screen and fetches the model contract only when the
  analysis dashboard is first opened, so Home itself makes no API request and
  nothing is analysed before its own action button is pressed.- Results are snapshots, so each tab re-runs from its own button. The readiness,
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
- The economic domain of that summary is decided by the incremental net monetary
  benefit, not by the ICER: the summary request carries the base case's
  `incremental_cost` and `incremental_qalys` alongside `icer`, and
  `assess_hta_decision_summary()` compares `wtp × incremental_qalys −
  incremental_cost` with zero. A ratio cannot decide that comparison safely — a
  negative ICER is below every positive threshold whether eQalb costs less and adds
  health or costs more and adds none — so the ICER is reported only where it is
  interpretable (positive incremental health) and never sets a colour on its own.
  The other four domains, the 50%/5% probability bands and the overall/position
  wording are unchanged, and the disclosure that explains the rules says the same
  thing as the code. The availability block follows the same rule: `base_case` is
  true when either the ICER or the two differences arrived, and `missing_inputs`
  names the two differences rather than the ICER, so a verdict that did not need an
  ICER is never presented as an assessment whose base case was missing.
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
- Every dialog contains its own focus and returns it on close
  (`src/composables/useModalFocus.ts`). Until 2026-10-15 the four modals announced
  themselves as `aria-modal="true"` while nothing contained the focus and nothing
  behind them was `inert`; measured on the PSA confirmation (Continue and Cancel, 57
  tabbable controls behind it) one Tab reached Cancel and the next left the dialog
  for the dashboard, where a control could be focused and activated — doing so
  dismissed the dialog and navigated away mid-confirmation. That is fixed: the focus
  moves to the dialog's own first action, Tab and Shift+Tab wrap inside it, the page
  behind it is inert (through the dialog's relatives, never an ancestor, with each
  element's prior state remembered and restored), and the focus returns to the
  opener — or, for the welcome question, to the Home screen's first menu choice, since
  it is asked on arrival rather than opened from a button. An opener that is present but
  disabled (Continue, which disables the run button as it starts the run) leaves the
  focus where the dialog left it, and nothing is returned into a page that has been
  left. A dialog whose leave is cancelled by a quick reopen clears its own `inert`
  on the way back in.
- The disclosure expansion is conditional by design: it animates only where the
  engine supports `::details-content` (with `interpolate-size` and
  `transition-behavior: allow-discrete`), and where it does not, a disclosure
  opens and closes instantly exactly as it did before. Nothing about the contents,
  their semantics, their tab order or their accessibility depends on the
  animation.
- The prepared-download notice reports that the download was handed to the
  browser, because a web page cannot confirm that a file was saved; a failure
  notice stays until it is dismissed, and the message itself is announced politely
  rather than taking the focus. The lighthearted loading line is decoration: it is
  `aria-hidden`, so a screen-reader user hears only the operation's factual status,
  and it is shown still rather than changing under `prefers-reduced-motion`.
- The loading line's area is reserved for the card's whole life (all 24 sentences
  are rendered in one grid cell and sized by the longest at the current width), so
  the card keeps a single height while it is up; the reserved space is used in every
  card, because the card only appears after 2.5 s and the first sentence follows a
  second later.
