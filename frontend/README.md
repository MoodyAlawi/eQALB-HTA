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
| `npm run lint` | oxlint over the TypeScript sources. |

`vue-tsc` is what type-checks the single-file components, which is why it runs in
`build`. oxlint does not parse `.vue` files, so lint covers the `.ts` sources.

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
    useTutorialSession.ts  # Guided Tutorial: Part 1's inputs/results/step and Part 2's case, price, coverage, readiness answers and section; never touches useModel
    useResultEntrance.ts   # the one-shot result entrance: an analysis's committed revision becomes an alternating animation class, once per revision, remembered across a panel's unmount
    useTabUnderline.ts     # places the analysis tab strip's indicator from the selected tab's own box: 190 ms slide between tabs on one row, a jump across a wrap, a resize or a font change, cleaned up on unmount
    useLoadingMessages.ts  # the lighthearted line under a long operation's factual status: one list of 24 sentences, a 1 s grace, a 7 s interval, a 280 ms opacity-only crossfade, and a static line under reduced motion
    useDownloadNotice.ts   # the prepared-download notice: one module-level notice, prepared/failed wording, a 7 s auto-dismiss only for successes
    useDialogTransition.ts # the shared dialog transition's name and its leave hook, which makes the outgoing dialog inert
    usePageEntrance.ts    # the page-entry fade: one 160 ms opacity animation on the page wrapper, once per entry (page + post slug), skipped on a first paint, on Back/Forward, during the launch, while a dialog is open and on a scrolled arrival
  views/
    OpenHealthHomeView.vue      # the landing page at / : one scrolling page in three panels - eQalb
                                # (the hero, and "Open the app"), OpenHealth, About me (with the
                                # portrait) - under a floating section navigation, with the landing
                                # page's own theme, a scroll-spy and the per-panel entrance reveal; it
                                # hands over to the app through LaunchTransition rather than swapping
                                # the page straight away
    AboutView.vue               # About OpenHealth at /about : the founder, the motivation, and how to get involved
    BlogIndexView.vue           # the blog at /blog : every published post, newest first, as text with a rule
                                # between the entries - no cards, no thumbnails
    BlogPostView.vue            # one post at /blog/<slug> : the title, its date and the post's own blocks in a
                                # narrow reading column, or a readable not-found state when the slug names no post
    HomeView.vue                # eQalb's own start screen at /app : eQalb wordmark with ECG pulse, credit, actions, links
    TutorialView.vue            # Guided Tutorial: Part 1 (four steps, completion) and the Part 2 shell
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
    tutorial/           # Guided Tutorial: stepper, step stage (the transition between steps), control, status card,
                        # plane, Part 1's four steps and completion card, and Part 2's shell, case brief, price
                        # curve, value-for-money, budget-impact, readiness and recommendation sections
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
    mahmood-portrait.png # the About me portrait the app ships (640 x 591, 346 kB), derived from the
                         # author's original; keeps the cut-out's alpha, imported so the build
                         # fingerprints it, rendered at <= 288px and lazy-loaded
    mahmood.png          # the author's original (1305 x 1206, 962 kB), kept as the source of any
                         # future re-export; not referenced by the build
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
  block the page. Under a long wait, the loading indicator adds one lighthearted
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
  `IntersectionObserver` and marks it with `aria-current`. The page keeps its own
  light/dark choice in [`landing.css`](./src/landing.css) and
  [`useLandingTheme.ts`](./src/composables/useLandingTheme.ts), which publish it
  as `<html data-landing-theme>` and take that attribute away when the page
  unmounts: the app's `eqalb.theme` and `<html data-theme>` are neither read nor
  written there, and no landing rule outlives the page. Scrolling is the
  browser's own and nothing is snapped, trapped or hijacked — scroll snapping was
  removed because it pulled small wheel notches back to a panel boundary and made
  an intermediate position impossible to hold — and the one action that matters,
  "Open the app", is the
  existing `/app` address.
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
  [`src/assets/mahmood-portrait.png`](./src/assets/mahmood-portrait.png) — a
  640 × 591 derivative of the author's [`mahmood.png`](./src/assets/mahmood.png)
  (1305 × 1206), imported by the landing view so the build fingerprints it and a
  missing file fails the build. It has to stay a PNG: the original is a cut-out
  with a transparent background (about 60% of its pixels), which a JPEG would
  flatten, and Windows' image encoders offer no WebP to convert it to. It sits in
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

The deployment server and the GitHub `production` environment are configured,
the operator has confirmed the environment's required-reviewer/approval rule, and
one end-to-end automated deployment has succeeded. Neither the automatic rollback
after a failed validation nor the manual rollback has been exercised yet, so both
remain untested. That successful release was built from `main`, and the workflow
only deploys on a push to `main` or a manual dispatch: the landing page on this
branch is **not** part of any deployed release, so `https://openhealth.ngo`
serves a build from before this work and cannot show the landing page, its
palette, its portrait or its scroll reveal. Review it on the dev server
(`http://127.0.0.1:5173`) until this branch is merged and deployed.

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
- No dialog traps focus, and only the tutorial's case-facts overlay returns focus
  to the control that opened it (the Welcome, PSA-confirm and congratulation
  dialogs leave focus on the document). That is the existing behaviour — the
  facts overlay documents itself as trapping nothing — and the interaction-polish
  pass changed none of it; it only made a leaving dialog `inert`, so an outgoing
  dialog cannot keep the focus. **A release blocker, measured 2026-10-15:** on the
  PSA confirmation (Continue and Cancel, 57 tabbable controls behind it) one Tab
  reaches Cancel and the next leaves the dialog for the dashboard behind it, and a
  control back there can be focused and activated — doing so dismissed the dialog
  and navigated away mid-confirmation. The dialogs announce themselves as
  `aria-modal="true"` while nothing contains the focus and nothing behind them is
  `inert`, so a keyboard or screen-reader user is not held in the modal it claims
  to be. The fix is small and local (contain the focus in the four dialogs and
  return it to the control that opened each one) but it is a separate change to
  approve, not part of the animation work.
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
