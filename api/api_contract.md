# eQalb model API — contract

HTTP wrapper around the eQalb R model. Every cost, QALY, ICER, readiness status,
Kaplan-Meier interpretation status, HTA decision status, value-based price,
tutorial status, label and interpretation in this project is computed by
`eqalb_markov.R`, `eqalb_owsa.R`, `eqalb_survival.R`, `eqalb_readiness.R`,
`eqalb_km_interpretation.R`, `eqalb_price.R` and `eqalb_tutorial.R`; the interface
wording it publishes (input explanations, traffic-light rules and notes) comes
from `eqalb_ui_copy.R`. This service validates
nothing about model values and computes nothing: it forwards each request to the
R route handlers in `api/plumber.R` and returns the JSON that R produced,
unchanged.

Two front ends share the service: the Vue application in `../frontend` (the
supported user-facing product) and, for comparison, the Shiny app (`../app.R`,
the reference implementation).

## Running it

```powershell
# One-time: create the virtual environment
py -3.14 -m venv api\.venv
api\.venv\Scripts\python.exe -m pip install -r api\requirements.txt

# Start the API on http://127.0.0.1:8788  (interactive docs at /docs)
api\.venv\Scripts\python.exe api\run_api.py
```

VS Code task: **eQalb: run model API (127.0.0.1:8788)**.

`api/requirements.txt` pins the two direct dependencies exactly (FastAPI and
Uvicorn) instead of naming version ranges, so a reinstall cannot drift onto a
newer major version. `api/requirements.lock.txt` records the same two packages
plus their whole transitive set, as resolved in the environment the API was
validated in; installing that file instead reproduces the environment exactly,
which is what a deployment wants:

```powershell
api\.venv\Scripts\python.exe -m pip install -r api\requirements.lock.txt
```

The plain plumber HTTP service is still available and serves the identical
endpoints; it is documented as a no-Python fallback:

```powershell
& 'C:\Program Files\R\R-4.5.1\bin\Rscript.exe' '.\api\run_api.R'
```

Environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `EQALB_API_HOST` | `127.0.0.1` | Bind address. |
| `EQALB_API_PORT` | `8788` | Port. Also used by the plain plumber service, so run one at a time. |
| `EQALB_R_WORKERS` | `2` | R worker processes. Each holds the loaded model. |
| `EQALB_R_TIMEOUT` | `900` | Seconds to wait for one model response. |
| `EQALB_RSCRIPT` | auto-detected | Full path to `Rscript.exe` if R is not on `PATH`. |
| `EQALB_LOG_LEVEL` | `INFO` | Log level for the API process. |

## How the R model is reached

```
browser  ──/api──▶  Vite dev server  ──proxy──▶  FastAPI (api/main.py)
                                                      │
                                        JSON lines over stdin/stdout
                                                      ▼
                                          api/r_worker.R (persistent Rscript)
                                                      │ parses once with plumber, then
                                                      │ calls the route handlers directly
                                                      ▼
                                     api/plumber.R  ──▶  eqalb_*.R
```

`api/r_worker.R` builds the plumber router from `plumber.R` at start-up and takes
the endpoint handler functions out of it, so each endpoint has exactly one
implementation and no request shaping is duplicated in Python. Requests arrive as
one JSON object per line:

```json
{"id": 1, "endpoint": "psa", "query": {"n_sim": "1000"}, "body": {"rrr": 0.1}}
```

and are answered with:

```json
{"id": 1, "ok": true, "result": { ... }}
{"id": 1, "ok": false, "error": "'rrr' must be between 0 and 1."}
```

Because each handler is called with exactly the fields plumber would have given
it (`postBody`, `argsQuery`, `REQUEST_METHOD`), the handlers stay free of HTTP
server assumptions. R is single-threaded, so one worker serves one request at a
time; the pool lets independent analyses run side by side. Requests are pure
functions of their inputs, so a request that dies with its worker is retried once
on a fresh one. Anything the model prints is captured and forwarded to stderr, so
stdout carries protocol lines only.

## Conventions

- **One source of truth.** Scenario parameters are optional everywhere. An
  omitted value means "use the base-case constant in `eqalb_markov.R`". The R
  layer owns all defaults, ranges and validation messages, so the two services
  cannot drift.
- **`notice`.** Every response carries
  `"Simulated illustrative data — not clinical evidence"`, so a new client cannot
  lose the disclaimer.
- **`null` means not interpretable.** Non-finite results (an ICER of infinity, a
  median that is never reached) are returned as JSON `null`, never as
  `"Infinity"`/`"NaN"`. Clients must render a dash rather than a number.
- **Full precision.** Numbers are not rounded to four digits, in either direction.
  Responses carry the double the model produced, and a request body a client posts
  back is rebuilt with `digits = NA` too, so it reaches R unchanged. Formatting is
  the client's job.
- **Reconciled decompositions.** `base-case` and `psa` return component values
  that sum to the incremental totals. The R layer verifies this and fails the
  request if it ever breaks.

### Status codes

| Code | Meaning |
|---|---|
| 200 | Model result. |
| 400 | The R layer rejected the input. The body's `detail` is R's message, e.g. `'rrr' must be between 0 and 1.` |
| 422 | FastAPI rejected the request shape, e.g. a field of the wrong JSON type. |
| 503 | The R model is unreachable (R missing, no free worker, worker died). |

`GET /api/health` answers 200 even when the model is down, with
`status: "degraded"` and an `error` field, so a client can explain the problem
instead of showing a transport error.

## Endpoints

### `GET /api/health`

Liveness, the model root, which modules loaded, and the worker pool state
(`r_model.ready_workers`, `r_model.startup_error`).

### `GET /api/defaults`

The form contract, read from the R constants so the client cannot drift:

- `parameters[16]` — `{id, label, group, unit, default, min, max, step, percent,
  info}`. `percent: true` means the model stores a fraction (0.1) that the UI
  shows as a percentage (10%). `info` is the input's explanation from
  `CC_INFO_TEXT` (eqalb_ui_copy.R) verbatim, or `""` when the input has none
  (the event costs, the discount rates and the time horizon).
- `owsa_parameters[14]` — the one-way ranges in force for the model's own
  base-case scenario, in the same shape `POST /api/owsa` echoes them:
  `{id, parameter, model_arg, group, unit, range_mode, range_source,
  range_rationale, min, max, step, integer, editable, base_value, low_default,
  high_default, low, high, range_status, range_note, range_warning,
  range_state}`. `low_default`/`high_default` are the range R derives for that
  scenario from the value the parameter has in it; `low`/`high` are the values a
  run would use, which equal the derived range unless a range was supplied; and
  `range_state` is R's own verdict, `"Model default"` or `"Adjusted"`. A caller
  with its own scenario asks `POST /api/owsa-defaults` instead. See the one-way
  range policy section below.
- `owsa_bounds_note` — `EQALB_OWSA_RANGE_NOTE` from `eqalb_owsa.R`, R's sentence
  that the default ranges follow the current base-case assumptions and are
  illustrative scenarios rather than evidence intervals.
- `simulation_defaults` — `psa_n_sim`, `psa_seed`, `psa_n_sim_min`,
  `psa_n_sim_max`, `psa_n_sim_step`, `psa_seed_min`, `reference_wtp`,
  `km_n_per_arm`, `km_followup_years`, `km_seed`. The PSA entry is Shiny's own
  PSA control (app.R): 1,000 draws, seed 12,345, 100–10,000 in steps of 100, seed
  at least 1. `POST /api/psa` enforces exactly these bounds, so the form and the
  endpoint cannot disagree about what is allowed.
- `info_text` — the 18 analysis explanations from `CC_INFO_TEXT`, keyed exactly
  as the Shiny dictionary keys them (`intervention_price`, `intervention_cost`,
  `healthcare_savings`, `relative_risk_reduction`, `year1_engagement`,
  `followup_engagement`, `utility`, `population_size`, `uptake`,
  `review_minutes`, `reference_wtp`, `psa_simulations`, `random_seed`, `evpi`,
  `evppi`, `psa_mean_cost`, `psa_mean_qalys`, `tutorial_interop_definition`).
  Every string is byte-identical to
  the Shiny dictionary, so the browser interface cannot show different wording.
  The remaining tutorial and Part 2 entries, and `willingness_to_pay` (the Shiny
  OWSA threshold control, which the browser OWSA tab does not have), are
  deliberately not exposed here — `tutorial_interop_definition` is the one
  exception, because it is the only interoperability definition that exists in R
  and the readiness tab shows it on that control rather than restating it. The
  guided tutorial's own explanations are published by `GET /api/tutorial`
  instead, so the full-analysis contract stays free of tutorial keys. An endpoint
  that cannot find a key fails loudly rather than
  shipping an empty explanation.
- `owsa_summary_note` and `owsa_prerun_note` — the sensitivity-analysis copy from
  `eqalb_ui_copy.R`: the paragraph Shiny shows above that tab's summary, and the
  sentence it shows until the analysis has been run. Both are byte-identical to
  the strings `app.R` renders, and the narrative itself comes back with
  `POST /api/owsa` as `summary`.
- `module_methods` — the method note behind each module's "How this is calculated"
  control, from `MODULE_METHOD_NOTES` in `eqalb_ui_copy.R`, keyed by the module id
  the interface already uses for its own tab: `base_case`, `sensitivity`,
  `uncertainty`, `voi`, `price`, `budget`, `readiness` and `survival`. The note is
  written for a reader who knows mathematics and nothing about this codebase, so it
  carries the mathematics and no implementation. Every note has `label` ("How this is
  calculated" for a module that computes an economic result, "How this works" where it
  does not), `summary` (the lead: the question the module answers, in one or two
  sentences) and `steps` (the computation, in order); the rest are optional and present
  only where they add something the other blocks do not — `formula` (one short relation
  in symbols), `definitions_title` + `definitions` (`symbol` / `meaning` rows, with each
  symbol's unit and the scope it refers to, and only for symbols not already defined
  where they are introduced), `interpretation` (how to read the number, including the
  decision rule), `assumptions` (only those that change how the result reads) and
  `table_title` + `table` (`label` / `value` rows). The two character lists (`steps`
  and `assumptions`) are marked AsIs in R, so a note that carries only one of either
  still serialises as an array rather than as a bare string. The base case states the
  general decision rule as the incremental net monetary benefit `INMB = λ·ΔE − ΔC` —
  positive favours eQalb, zero means equal net monetary benefit — and gives the
  ICER-threshold equivalence only with its `ΔE > 0` condition; no note presents an ICER
  comparison as the rule without it. No function name, file name, endpoint or internal
  check appears in any of it, and a model default is never presented as the reader's
  current input. Each note states the model's own method — the annual cycles and their
  transitions, the discounting, the price-only slope the break-even price is solved
  from, the budget's two savings terms and undiscounted horizon, the seven readiness
  rules and the Kaplan-Meier product — so it cannot drift into a textbook calculation
  the app does not perform. The caveats stay in each module's own
  disclosure, so the method note and the limitations are not
  two copies of one paragraph. Mathematics travels as TeX, not as Unicode: `formula` is one
  display expression (long ones use `aligned` rows so a narrow screen has a break point
  before it has to scroll) and the prose fields carry inline expressions between `$…$`.
  R writes each `\\` as a doubled backslash, which JSON escapes once more, so the client
  receives the single backslash TeX expects; a consumer must render only the pieces
  designated as mathematics and pass every other character through unchanged. The HTA decision summary publishes none: its rules are
  already a disclosure (`HTA_RULE_ITEMS`) and repeating them here would duplicate it.
  A module that published nothing shows no control rather than a guessed note. The
  journey contract republishes the same dictionary as `journey.methods`, so a lesson
  and its dashboard tab cannot describe a method differently.
  The only module the interface shows without a note is therefore `hta`; the
  `Assumptions` form is not a module of its own and carries none either.
- `readiness` — the DHT readiness contract, so the client cannot drift from it:
  - `parameters[8]` — `{id, label, group, unit, type, default, min, max, step,
    percent, info}` for the numeric readiness inputs plus the accessibility
    checkbox (`type: "boolean"`, whose `default` is 1 or 0). A `null` bound means
    the input has no such bound in the Shiny tab. The engagement rows default to
    the shared Global Settings engagement slider expressed as a percentage, and
    are the same values the readiness endpoint uses when a field is omitted.
    `info` carries the clinician-review explanation from `CC_INFO_TEXT`; the
    other seven are `""`, exactly as in the Shiny readiness sidebar.
  - `choices.interoperability` — `{label, default, levels, info}`, where `levels`
    is `DHT_INTEROPERABILITY_LEVELS` from eqalb_readiness.R and `default` is
    `"PDF/manual export"`, the value the Shiny readiness tab preselects. `info` is
    the interoperability definition from `CC_INFO_TEXT`
    (`tutorial_interop_definition`), the only definition of it that exists in the
    R layer; it is published here because the readiness tab shows it on the
    interoperability control.
  - `choices.algorithm_governance` — `{label, default, levels, info}`, where
    `levels` is `DHT_ALGORITHM_APPROACHES` and `default` is
    `"Periodic controlled updates"`. `info` is `""`: no explanation for this
    control exists in `CC_INFO_TEXT`, and none is invented here — the four
    approach names carry their own meaning, exactly as in Shiny.
  These are the full-analysis readiness defaults only. Values that belong to the
  tutorials or to the Part 2 commissioning cases are deliberately not exposed.
- `model` — cycles, states, strategies and the stated perspective.

### `POST /api/base-case`

`run_eqalb_model()`. Query: `wtp` (default 100000).

Body: any of the 16 `ScenarioInputs` fields (`intervention_price`,
`implementation_cost`, `healthcare_savings`, `rrr`, `engagement_year1`,
`engagement_followup`, `utility_no_event`, `utility_post_mi`,
`utility_post_stroke`, `cost_post_mi_year1`, `cost_post_mi_followup`,
`cost_post_stroke_year1`, `cost_post_stroke_followup`, `discount_rate_cost`,
`discount_rate_effect`, `cycles`).

Returns `incremental_cost`, `incremental_qalys`, `icer`,
`net_monetary_benefit`, `wtp`, `cost_effective`, `cost_components`
(`intervention`, `implementation`, `savings`, `no_event`, `post_mi`,
`post_stroke`, `total`), `qaly_components` (`no_event`, `post_mi`,
`post_stroke`, `total`) and the resolved `inputs` under their R argument names.

### `POST /api/psa`

`run_psa_eqalb()`. Query: `n_sim` (100–10000, default 1000), `seed` (default
12345, minimum 1), `wtp` (default 100000), `max_wtp`
(default `max(150000, 2 × wtp)`). The bounds are Shiny's own PSA control limits
and are published by `GET /api/defaults`, so a client renders the range the
endpoint enforces. A value outside them is rejected by the R validator with its
existing message, e.g. `'n_sim' must be between 100 and 10000.`

Returns the summary (`mean_incremental_cost`, `mean_incremental_qalys`,
`mean_net_monetary_benefit`, `median_icer`, `mean_components`), the
`probability_cost_effective` map keyed by the formatted threshold, `ceac`
(`[{wtp, probability}]`), `cloud` (per-iteration cost, QALYs, ICER) and `results`
— every draw with its sampled parameters, which is what
`/api/value-of-information` consumes.

A PSA is expensive. Measured on the development machine: 1,000 draws take about
three minutes (0.18 s per iteration), so it stays behind an explicit button and
the client only estimates the duration from a run it has actually observed. The
FastAPI worker answers a request within 15 minutes (`EQALB_R_TIMEOUT`, default
900 s), so a run above roughly 5,000 draws needs a larger timeout; the browser
interface states that limit next to the control.

Validation practice: check this endpoint with `n_sim = 100` and `seed = 12345`
(about 20 seconds). The 1,000-draw default is only run when a full default PSA is
explicitly requested, because it costs about three minutes and is not needed to
confirm a contract or parity change.

### `POST /api/owsa`

`run_eqalb_owsa()`, ranked by the outcome. Query: `outcome` (one of `inmb`,
`icer`, `incremental_cost`, `incremental_qalys`; default `inmb`), `wtp`.

Body: the scenario plus optional `bounds: [{id, low, high}]`. The ranges are
derived by the canonical policy below from the submitted scenario; a supplied row
replaces the derived range for the parameter it names, and anything omitted keeps
R's derived range. Returns the `table` (base value, low/high value, outcome at
each bound, `impact_range`, per-bound warnings) plus the `bounds` actually used,
each row carrying R's source, rationale, domain, `range_state` and status.

A supplied range R cannot use is an error with R's own sentence (HTTP 400 through
FastAPI, with the message in `detail`; HTTP 500 with plumber's masked body, as
for every other R rejection — see the status table above). A range that is usable
but no longer contains the scenario's own value stays active and carries R's
observation in `range_warning`: a range is a scenario the caller owns and is never
silently rebased. A parameter whose range R cannot derive at all keeps its row in
`table` with R's sentence in `low_warning`/`high_warning` and no numbers, so it is
reported rather than dropped from the analysis.

Also returns the Shiny tab's plain-language summary and the paragraph above it:

- `summary` — `summarize_eqalb_owsa()` from `eqalb_owsa.R`, the same function the
  Shiny sensitivity-analysis tab calls, with one sentence per line. Nothing in it is
  composed or reworded in Python, R-plumbing or TypeScript. It states the base-case
  value of the **selected outcome** and the decision reference it is read against
  (for `inmb`, whether the base case sits above or below €0 at the selected
  threshold; for `icer`, the ICER value against the reference threshold, in the
  wording `assess_hta_decision_summary()` already uses; for the incremental cost
  and QALY rankings, the value plus the incremental net monetary benefit the
  decision is made on), names the two or three parameters whose tested range moves
  that outcome most, states whether the decision survives the tested ranges
  ("The conclusion remains unchanged across the tested one-way scenarios." or
  "The conclusion is sensitive to the tested range of X and Y."), names any
  parameter the run could not vary, and closes with the one-way limitation.
  Every number, rank and classification is R's: the ranking is R's `impact_range`
  for the selected outcome, and the robustness sentence reads R's own
  cost-effectiveness flag for each scenario, so the interpretation, the table and
  the chart always describe the same ranking.
- `summary_note` — `OWSA_SUMMARY_NOTE` from `eqalb_ui_copy.R`, the paragraph
  Shiny shows above the summary.

Before any run the client shows `owsa_prerun_note` from `GET /api/defaults`,
which is Shiny's own "not run yet" sentence for the same panel.

### `POST /api/owsa-defaults`

The same `bounds` block `POST /api/owsa` returns, derived for the submitted
scenario and **without running a single model run**, so a range editor always
shows the ranges that are in force for the assumptions in the form. Body: the
scenario plus the same optional `bounds: [{id, low, high}]`. Returns `bounds`,
`bounds_note` (`EQALB_OWSA_RANGE_NOTE`) and `notice`. An optional `outcome` and
`wtp` are accepted and ignored: the ranges do not depend on the ranking or the
threshold.

A supplied range that breaks a rule is reported **on its row** rather than failing
the request — `range_status` `"invalid"`, R's sentence in `range_note`, and R's
own derived range as the active values — because an editor needs the sentence
while the caller is still choosing values. The analysis endpoint rejects the same
input as described above. An unknown `id` is a request error on both endpoints,
since there is no row to report it on.

### One-way range policy (`eqalb_owsa.R`)

`eqalb_owsa_range_specs()` holds one row per parameter: its id, label, model
argument, interface group and unit, the domain an override stays inside, the
planned range mode, and R's own source label and rationale sentence.
`eqalb_owsa_range_defaults(base_args)` derives the ranges from the values in the
scenario being analysed:

- **frozen width** (11 parameters) — an absolute offset around the current value,
  clamped to the domain. The offsets are the widths the model has always used, so
  the model's own default scenario reproduces the ranges the app has always shown.
- **policy pair** (the two discount rates) — no discounting and twice the current
  rate, kept inside 0–0.10. At the model's default 3% rate this derives 0–6%,
  where the previous fixed literal was 0–5%; that is the one intended change to
  the default analysis, and it restores the 0%–6% pair the model's own comments
  describe.
- **structural scenarios** (the time horizon) — the nearest valid, distinct,
  whole-year pair around the current horizon. At the default 10 years that is 5
  and 20; at the edge of the domain the pair sits on one side of the base and R
  reports that in `range_warning`, because no distinct pair can bracket it.

`eqalb_owsa_range_bounds(base_args, supplied)` applies this policy and any
supplied ranges, and is the only thing the endpoints use. `eqalb_owsa_parameters()`
is the same policy evaluated at the model's own base-case constants, which is what
the value-based price module and the standalone analysis block in `eqalb_markov.R`
read, so there is exactly one definition of a one-way range in the project.

`eqalb_owsa_override_error()` decides whether a supplied range is usable (finite,
inside the domain, low below high, whole years for the horizon) and
`eqalb_owsa_contains_warning()` reports a usable range that no longer contains the
scenario's own value. Neither derives, clamps or rebases anything. Shiny's
sensitivity-analysis sidebar calls the same policy through `eqalb_owsa_parameters()`
and `eqalb_owsa_range_defaults()` and leaves a bound it has edited alone, so the
Shiny tab and the browser editor show the same ranges for the same assumptions.

### `POST /api/budget-impact`

`calculate_budget_impact()`. Body: the scenario plus `population` (default
70000), `year1_uptake_pct` (10), `annual_uptake_increase_pp` (5),
`horizon_years` (5), `avoided_event_savings_per_active_user` (0) and
`followup_engagement_pct` (defaults to the scenario's follow-up engagement).

Returns the per-year `table` plus totals and the `inputs` used. Follow-up
engagement deliberately has no separate control in the UI: it follows the one
engagement assumption in the scenario, as in the Shiny app.

### `POST /api/value-of-information`

`voi_evpi()` and `voi_evppi()`. Query: `wtp`. Body: `results` — the draw array
returned by `/api/psa`, so the expensive simulation is never repeated.

Returns `evpi` (per patient) and `evppi`. EVPPI is a union: either
`{available: true, table: [{parameter, model_argument, evppi, evppi_raw,
clamped}]}` or `{available: false, reason}` when fewer than 100 successful
draws are available. Clients must handle both.

### `POST /api/tutorial/journey/uncertainty`

`eqalb_journey_uncertainty()`, the third chapter: repeats of the comparison. Body:
`price` and `utility_no_event` — the two levers the base case set, so the repeats are
drawn for the same scenario the earlier chapter showed. The repeats come from
`run_psa_eqalb()` with this journey's own seed and count, so the same scenario always
produces the same cloud. The score enters as the **mean of the analysis's existing
beta** for that parameter (`psa_parameter_table()`); its spread is the analysis's own
and is not chosen here. At every score the beta represents exactly; at exactly `1.00`
its own validity guard applies, so the deterministic model uses 1.00 while the draws
centre marginally below it and are narrower — `variation.utility_sentence` says so, and
is an empty string at every other score.

Returns `n_repeats`, `seed`, `cloud` (one `{cost, qalys}` pair per successful
repeat, for the chart), **`draws`** (the successful simulation rows themselves,
including every sampled parameter column the analysis stored, so the
value-of-information chapter can value exactly these comparisons without simulating
them again), `mean`, `base_case`, `spread`, `sides`, `variation` (the quiet
disclosure's contents, derived from the analysis's own tables) and `notes`.
`draws` and `cloud` are the same rows: the drawn values and the plotted values
cannot disagree.

### `POST /api/tutorial/journey/voi`

`eqalb_journey_voi()`, the fourth chapter: what better evidence would be worth.
Body: `price` (optional, validated against the price control's range),
`threshold` (optional, defaulting to the case's own reference) and `results` —
the `draws` array the uncertainty chapter returned, posted back unchanged and
validated by the same helper `/api/value-of-information` uses. **No simulation is
run**: the posted rows, which include the sampled parameter columns, go straight to
`voi_evpi()` and `voi_evppi()`, the functions the value-of-information tab calls,
and every figure is per person over the model's horizon.

- `voi.evpi` — `per_person` and `display` (EVPI), `choose_now` / `choose_now_display`
  (the balance of choosing on today's information, relative to usual care, whose
  own net benefit is the axis's zero), `perfect` / `perfect_display` (the balance if
  the included parameter uncertainty were resolved), `mean_nmb` and `preferred`
  (R's own name for the option ahead on average, or an empty string).
- `voi.evppi` — `available`, `reason` (R's own sentence when it is not), `rows`
  (each with `parameter_id`, `label`, `plot_label`, `value`, `value_display` and the
  `zero` / `small` flags that separate an exact zero from an estimate too small to
  print), `largest`, the `zero` and `small` counts, and `clamped` / `exceeds`.
- `voi.axis` — `max` and `evppi_max`, so revealing a bar never rescales one already
  drawn and the two panels keep separate scales.
- `voi.disclosure` — the quiet disclosure: per-person scope, that the model's
  horizon is not a research horizon, that population-level value is not calculated
  here, and the qualifications of the two measures — what the imagined certainty
  includes, that the EVPI figure is an upper limit and the gap rather than a bar, and
  that each EVPPI bar leaves the others uncertain. The **short definitions** are not
  here: "EVPI is what it would be worth to know every uncertain assumption exactly" and
  "EVPPI asks that question for one assumption at a time" are the `aside` of the two
  states that introduce the measures, so a learner never has to open a disclosure to
  know what the figure in front of them is called.
- `voi.notes` — one sentence per state, each opening with that state's caption.
- `notice`.

The eligible population is never multiplied in, and no threshold test, verdict or
recommendation is produced.

### `POST /api/tutorial/journey/sensitivity`

`eqalb_journey_sensitivity()`, the one-way chapter: the same comparison ranked twice.
Body: `price` and `utility_no_event`, both optional and validated as above. The two
are applied to `eqalb_owsa_base_args()` as the analysed scenario *before*
`eqalb_owsa_range_bounds()` derives the tested ranges from it, so the ranges and the
rankings describe the comparison the learner built rather than the model's global
defaults. Both rankings are `run_eqalb_owsa()`, unchanged; the willingness-to-pay value
it requires is passed so it can run and is neither used nor returned.

`contract.sensitivity.disclosure` — `title` and `lines`: the method's name, what a
flat bar means, and what a long bar does not mean. These were the states' own notes
beside the bars and now open a closed disclosure, so the panel keeps the caption and
the bars.

### `POST /api/tutorial/journey/budget`

`eqalb_journey_budget()`, the sixth chapter: what adoption would cost the payer.
Body: `price` (optional, defaulting to the case's price and validated against the
price control's range) — the same field and the same value the other chapters read, so
there is one name for the journey's price. There is no second price and therefore no
selection between prices.

`utility_no_event` is **not** accepted, and is ignored if sent:
`calculate_budget_impact()` charges the annual price to active users and has no
quality-of-life term, so the score cannot move a budget figure and the chapter does not
claim it does.

**No model runs.** Every figure is `calculate_budget_impact()` — the function the
budget-impact tab and Part 2 use — evaluated at each of the coverage lever's 19
steps for the journey's one price. One response therefore carries the whole sweep, and
moving the coverage cap selects a row R has already computed instead of asking
again. No PSA and no one-way analysis runs here.

**The two payment conventions are kept apart, on purpose.**
`calculate_budget_impact()` charges the annual price for **active users only**
(`active_users = cumulative_users × followup_engagement`), while the Markov model
behind the earlier chapters charges **everyone receiving eQalb** in every cycle. The
same price is therefore applied here under a different payment assumption, a total
here is *not* the Chapter 5 per-person result multiplied by a population, and the
slice does not harmonise the two. The difference is stated on screen in the
chapter's first state and recorded again in its disclosure as a model limitation.

- `budget.population` and `population_display` — the case's 100,000 eligible people,
  passed to `calculate_budget_impact()` explicitly rather than relying on the
  budget-impact route's 70,000 default.
- `budget.horizon_years` — five years.
- `budget.coverage_control`, `coverage_steps` (19 values, highest first) and
  `coverage_default` (100).
- `budget.assumptions` — the constants the calculation uses: year-1 uptake 10%, an
  annual increase of 5 percentage points, follow-up engagement 42%, implementation
  cost €40, healthcare savings €20 per active user, avoided-event savings **0**.
- `budget.candidates[]` — the journey's one price: `key` (`journey`), R's `label`,
  `price`, `price_display`, and `coverages[]`. The list shape is kept so the sweep, the
  cache key and the client's read are unchanged in structure, but a list of one has
  nothing to choose between and the chapter shows no selection.
- `budget.candidates[].coverages[]` — per coverage step: `coverage`,
  `coverage_display`, `covered_population` / `covered_display`, the five `rows`
  (`year`, `year_label`, `enrolled`/`new_users`/`active_users` with displays,
  `uptake_pct`, the four cost components, `net` with `net_display`, and `cumulative`
  with `cumulative_display`), `years`, `cumulative` / `cumulative_display` (the last
  running value, not a second sum), `totals` (each component's five-year total in
  R's formatting), `components` / `components_period` and `notes` (`population`,
  `cumulative`) — the sentences that depend on the cap, so the client renders a
  description R has already written.
- `budget.candidates[].coverages[].components[]` — the amount beside each visual
  component, in the order the calculation applies them: `key` (`programme` /
  `setup` / `savings` / `net`), R's `label` and `sub`, `amount_display` and `amount`,
  and the `tone` (`cost` / `saving` / `net`) that says whether it is added or
  subtracted. `components_period` is R's own statement of what the four amounts
  cover ("All 5 years added together, not discounted"), so a five-year component
  cannot be read as a year's. The chapter reveals them one at a time and keeps all
  four from the net state onward; a zero-valued component is not given a card, so
  avoided-event savings appear only in the disclosure.
- `budget.axis` — `annual` and `cumulative` extents, both fixed from the whole sweep,
  so changing the cap never rescales a figure the learner is already reading.
- `budget.notes` — `adoption`, the one sentence that depends on neither the cap nor the
  price. The chapter's limits are published in `budget.disclosure` instead, because its
  "limits" state carries no `note_key`; there is no per-state limits sentence to map.
- `budget.disclosure` — `title` and `lines`: the payment assumption as a model
  limitation, the five undiscounted years, what "net" subtracts, and that no budget
  ceiling is applied.
- `budget.copy` states each carry R's `advance_label`, the text of the journey's
  arrow control. The chapter's last state is labelled "What delivery would take"
  because it opens the readiness chapter's bridge.
- `notice`.

Net budget impact is spending minus the savings the model expects, so a positive
figure is extra spending and says nothing about value. The figures are **not
discounted**, unlike the model's ten-year per-person results. No budget ceiling is
applied and no affordability verdict is produced: Part 2's €3,000,000 ceiling is
Part 2's assumption and is not carried into the journey.

### `POST /api/tutorial/journey/readiness`

`eqalb_journey_readiness()`, the seventh chapter: what would have to be in place for
the modelled intervention to be delivered. Body: `answers` (optional object keyed by
question id; a key that is not one of the four questions is ignored) and
`focus_question` (optional, naming the question the learner just answered). Both are
optional, so a bare request returns the chapter's start: the case's own values for all
four questions.

**No model runs.** The whole chapter is `calculate_readiness()` — the function the
DHT readiness tab and Part 2 use — called once per request. The question set, the
seven domains, the seven traffic-light rules, their thresholds, the `numbers` table
and the per-domain sentences are all that function's; nothing is re-implemented and no
new scoring framework is introduced.

**Four questions are asked, six inputs are fixed.** The study can only ask about
choices that describe a deployment: how data is exchanged with the clinical record
system, how the algorithm changes after deployment, how much clinician review each
patient takes each month, and how many languages are offered — three scenario-worded
options each, so a reader who does not know what "FHIR" means can still choose. The
other six inputs `calculate_readiness()` needs (`target_population`, `digital_access`,
`digital_suitability`, `readiness_year1_engagement`,
`readiness_followup_engagement`, `accessibility_features`) are the case's own values
and are read in R, so no answer can move them. In particular the two engagement values
are the journey scenario's, never an answer, so the readiness result cannot contradict
the engagement the economic chapters computed with.

- `inputs.answers` — the four answers R used, by question id.
- `inputs.readiness_key` — one opaque key naming **all ten** inputs the assessment
  received, so a result always says which inputs it describes rather than only which
  four fields a learner could edit.
- `readiness.questions[]` — the four questions: `id`, `domain`, `focus` (the figure's
  spotlight target), `caption`, `label`, and three `options[]` with `id`, `label`
  (the scenario wording), `input_display` and `input` (the string or number
  `calculate_readiness()` accepts).
- `readiness.answers[]` — the answer set echoed back: `question_id`, `domain`,
  `caption`, `label`, `option_id`, `option_label` and `input_display`, so the
  interface prints R's wording for the answer on screen instead of remembering it.
- `readiness.domains[]` — all seven domains, each with `domain`, `status`,
  `input_display`, `explanation` (that domain's own `Interpretation` from
  `calculate_readiness()`, returned unchanged) and the `question_id` / `focus` it
  belongs to, or JSON null for the three domains that are not asked about.
- `readiness.counts` — `green`, `amber`, `red` and `total`, straight from the
  assessment's own `counts`. They summarise seven separate judgements; R publishes no
  overall score and the chapter shows none.
- `readiness.changed` — the one answer whose area the figure should bring forward:
  `focus_question` when that answer differs from the case's value, otherwise the first
  answer that differs, and JSON null when every answer is the case's own. An answer
  equal to the case's value is not a change.
- `readiness.numbers`, `readiness.assessment` — the assessment's quantitative table and
  its own summary reading, unchanged.
- `readiness.fixed[]` — the six held values as `label` / `value_display` rows, so the
  interface shows them on demand without formatting a percentage or a population.
- `readiness.notes` — `statuses` (the counts written out, naming any Red, else any
  Amber, area). The chapter's limits are published in `readiness.disclosure` instead,
  because its limits state carries no `note_key`; there is no per-state limits sentence
  to map.
- `readiness.disclosure` — `title` and `lines`: that the areas and rules come from the
  shared assessment, that the six fixed inputs are the case's, that the thresholds are
  illustrative teaching assumptions rather than official HTA, DiGA, regulatory,
  cybersecurity or reimbursement standards, plus `DHT_DISCLAIMER`.
- `notice`.

An answer naming an option the chapter does not offer is refused with R's own message
(`'interoperability' must be one of: none, basic, strong.`), never coerced to a nearest
option; an `answers` key that is not one of the four questions is ignored.

The chapter's own wording is separate from the assessment's: no state requires a Green,
no state says the areas should be optimised, and the governance question is about how
the algorithm changes rather than about who controls it, so a Red under that rule reads
as an area needing attention rather than a verdict on adaptive technology.

### `POST /api/tutorial/journey/survival`

`eqalb_journey_survival()`, the eighth and last chapter: the same comparison drawn as
time to a first event. Body: none — the route ignores it, because every input is fixed
in R. The same request therefore always returns the same figure, which is what lets a
client cache it.

**No model, PSA or one-way analysis runs.** The dataset is
`simulate_eqalb_survival()` — the function the Simulated survival tab runs — at the
case's own effect assumption (`rrr_pct`, `engagement_year1_pct`,
`engagement_followup_pct` from `eqalb_journey_fixed_assumptions()`) and the model's own
annual risks (`p_mi_usual_care`, `p_stroke_usual_care`, `p_other_death` from
eqalb_markov.R), with 1,000 people per arm, 10 years and one seed. The step coordinates
come from the same `survival::survfit()` estimator `summarize_eqalb_survival()` uses, so
the figure, the sentences and the tab cannot describe different runs.

**What the curves estimate.** A Kaplan-Meier estimate of the time to a **first MI or
stroke**, with other-cause death carried as a **censored** observation rather than an
event. The complement of a curve is therefore a cause-specific quantity, not the
real-world probability of an event, and the chapter never labels it as one. The
chapter's own wording says the curves are simulated estimates and that other-cause
deaths are censored; the hypothetical reading, the bands' meaning and the limit on what
the curves say are in `survival.disclosure`.

**Three times, one response.** `reads[]` carries 1, 5 and 10 years, so choosing another
time selects a reading R has already computed and never asks again. The comparison is
the two event-free estimates at the chosen time and the gap between them in percentage
points; **no p-value, hazard ratio or median is published**, because the chapter
compares two readings rather than testing them.

- `inputs` — the nine inputs the simulation read, echoed, plus `survival_key`: one
  opaque key naming all of them. The same key is published with the contract, so a
  stored answer is reused only while it describes the same simulation and a contract
  that changed any input could not be served the old one. The price and the
  quality-of-life score are **not** in that key: the curves read neither, so moving
  either lever elsewhere in the journey cannot invalidate them.
- `survival.steps[]` — the two step sets the chart draws (`treatment`, `time_years`,
  `survival`, `lower`, `upper`, `n_risk`, `n_event`), the same shape
  `/api/survival` returns, so the tab's chart component renders it unchanged.
- `survival.followup_years` — the x-axis extent.
- `survival.reads[]` — per time: `id`, `years`, `label`; `arms[]` with `treatment`,
  `estimate` and R's `display` (one decimal place); `reading` (R's sentence for both
  curves at that time); `difference_points` (eQalb minus usual care, in percentage
  points of the event-free estimate) and `compare` (R's sentence for it, which reads
  the sign from the numbers and says "level to one decimal place" when the gap rounds
  to zero); and `step` — the movement the second beat teaches. `step` carries
  `treatment` (the arm its sentence is about), `from_years` / `to_years` (the interval,
  in the same numbers the x-axis is drawn in) and `to_estimate` (the level the curve
  reads at its end), so the figure can shade exactly the interval the sentence names;
  then `from_label`, `to_label`, `from_display`, `to_display`, `events` (the first
  events that arm recorded in the year) and `note`, R's sentence naming the fall and
  the mechanic.
- `survival.disclosure` — `title` and `lines`: what each curve estimates, why a
  censored estimate is not the real-world chance of an event, what the 95% band
  describes, how the two groups were simulated, and that the curves are not a test of
  the economic results.
- `survival.note` — `SIMULATED_EVENT_NOTE`, R's statement of the event proxy and the
  competing-death treatment.
- `notice`.

The chapter states the illustrative nature of its data with the journey's shared notice
plus the visible qualifier `survival.graph.qualifier`; it makes no claim about
affordability, effectiveness or the ICER.

### `POST /api/tutorial/journey/price`

`eqalb_journey_price()`, the fifth chapter: where the price has to sit for the
balance to hold. Body: `price` (optional, validated against the price control's
range), `utility_no_event` (optional, the scenario's score, so the balance is computed
for the same comparison as every chapter before it), `threshold` (optional,
defaulting to the case's own reference) and `solve` (optional).

**There is no price lever in this chapter.** The price it compares is the one the
learner chose in the base case; the chapter places it on a track beside the
manufacturer's proposal and beside the price at which the balance reaches zero.

**No simulation runs.** The balance is `eqalb_price_run()` at the submitted price
and score and `eqalb_price_nmb()` at the reference — one `run_eqalb_model()` call —
and the price at which that balance reaches zero is `eqalb_price_solve()`, the solver
the value-based-price analysis uses. It is reached through the same
`run_psa_eqalb()`-free path as the other chapters: no PSA and no one-way analysis
runs here.

**Solve reuse is scenario-bound.** A posted `solve` is used only when its
`scenario_key` matches the key R computes from the submitted price and score, and its
threshold matches the one requested; otherwise R refuses it. Because the key folds in
every fixed assumption including the score, a solve computed at one score cannot
supply the marker at another. The balance beside the marker is always computed fresh.

**Units.** The price is an annual rate **per person per year** — the model charges
it to every person in the eQalb arm in every cycle, and engagement scales the
modelled benefit rather than the charge — which is the unit of Part 1's own price
control. The balance is a **total per person over the model's horizon**, so the two
figures on screen are never the same unit and the disclosure says so. The
`/api/value-based-price` section above uses the same unit, per treated person per
year.

- `price.range` — the lever's own bounds, `min` and `max`. `price.unit` is the unit
  as a sentence reads it ("per person per year") and `price.unit_label` the same unit
  in the control's label form ("EUR per person per year"), so a caller never decides
  which one an amount is in.
- `price.ticks` — whole-hundred ticks inside that range, each with `value` and R's
  `display`.
- `price.proposal` — the manufacturer's proposed annual price (`value`,
  `display`), the case's own figure.
- `price.solved` — `available`, `price`, `display`, `within_range`, `outside`
  (`"above"`, `"below"` or `""` when it is inside or unavailable), `method`,
  `verified` and `reason`. `price` is JSON null when the solve is unavailable.
  The solved price is the annual price at which the model's **incremental net
  monetary benefit is zero** at the reference; it is not a negotiated price, a
  recommendation or an affordability verdict.
- `price.balance` — `nmb`, `display` (R's signed formatting), `positive`,
  `incremental_cost`, `incremental_qalys` and `axis` (`min`/`max`, always
  containing usual care's zero).
- `price.notes` — `balance`, `crossover` and `scope`, one sentence each, the last
  of which states that a different price changes the balance without removing the
  uncertainty, and that the earlier chapters' results stay at the price they were
  computed for.
- `price.limitation` — `EQALB_PRICE_LIMITATION`, unchanged.
- `price.disclosure` — the quiet disclosure's `title` and `lines`.
- `notice`.

**The posted `solve`.** When the request carries the `solve` this endpoint
returned, R reuses it instead of solving again, so moving the slider costs one
model run rather than a solve. The payload is validated before it is used: its
`scenario_key` must equal `eqalb_journey_price_scenario_key()` (every input the
solve depends on, composed in R), its `threshold` must equal the requested
reference, `available` must be a single logical, an available solve must carry a
finite non-negative `max_acceptable_price`, and an unavailable one must carry R's
own `reason`. A payload that fails any of these is an R error, never a number
silently accepted. The solve supplies **only the marker**: the balance beside it is
always a fresh model run at the submitted price.

No net monetary benefit is ever drawn on the price axis, no population total is
computed, and no ratio between the two figures is produced.

### `POST /api/survival`

`simulate_eqalb_survival()` and its summarising helpers. Body: the scenario plus
`n_per_arm` (10–20000, default 1000), `followup_years` (default 10), `seed`
(default 20261004), `p_mi`, `p_stroke`, `p_other_death`.

Returns `steps` (the Kaplan-Meier coordinates with 95% confidence bounds, drawn
from the same estimator as the summary), `risk_table`, `summary`, `diagnostics`
(`summary` and `yearly`), `expected_events`, `arm_contrast` (`checks`,
`logrank_p`, `hazard_ratio_cc_vs_uc`, `verdict`), `interpretation`,
`logrank_note` and `event_note`.

`interpretation` is the unchanged result of `assess_km_interpretation()` from
`eqalb_km_interpretation.R` — the same function the Shiny Kaplan-Meier tab calls
— derived from the diagnostics summary and the arm contrast of the run that just
finished. It carries `overall_status`, the five `domains` (`Domain`, `Status`,
`Explanation`), the `counts` those statuses were derived from (JSON null where a
statistic is not estimable), R's plain-language `interpretation`, the five
`rules` sentences, and `display`: the three statistics already formatted by R's
`km_number()` / `km_p_value()`, so a client prints R's own text instead of
re-formatting a number. No status, threshold or wording is produced outside R.

`logrank_note` is the Shiny tab's own descriptive log-rank line, word for word
("Descriptive log-rank p-value (simulated data only): …" followed by the
simulated-data notice), so the p-value is never displayed without its qualifier.

### `POST /api/readiness`

`calculate_readiness()` from eqalb_readiness.R, the same function the Shiny DHT
Readiness & Implementation tab and Tutorial Part 1 Step 3 and Part 2 call, so the
scoring rules exist once. Body (every field optional, omitted fields take the
readiness defaults from `/api/defaults`):

| Field | Unit | Accepted range |
|---|---|---|
| `target_population` | people | ≥ 0 |
| `digital_access` | percent | 0–100 |
| `digital_suitability` | percent | 0–100 |
| `readiness_year1_engagement` | percent | 0–100 |
| `readiness_followup_engagement` | percent | 0–100 |
| `review_minutes` | minutes per patient per month | ≥ 0 |
| `supported_languages` | languages | ≥ 1 |
| `accessibility_features` | boolean | `true` / `false` (also accepts 1/0) |
| `interoperability` | level | one of `readiness.choices.interoperability.levels` |
| `algorithm_governance` | level | one of `readiness.choices.algorithm_governance.levels` |

The four share/engagement fields are **percentages**, not the fractions the
scenario inputs use, because that is the unit `calculate_readiness()` expects and
the unit the Shiny sliders show. Nothing is rescaled on the way in or out, and
the range and level checks are R's own (a value outside them returns R's message
with HTTP 400).

Returns the calculation object unchanged, plus `notice`:

- `eligible_population`, `active_users_year1`, `active_users_followup`,
  `engagement_retention_pct`, `annual_clinician_hours` — figures at full
  precision. `engagement_retention_pct` is `null` when year-1 engagement is 0
  (the R value is `NA_real_`), which `numbers` and `interpretation` report as
  "NA (year-1 engagement is 0)".
- `numbers[5]` — `{Measure, Value, "Illustrative basis"}`, the quantitative
  summary, formatted in R.
- `domains[7]` — `{Domain, Status, "Current input", Interpretation}`, the
  seven-domain assessment; `Status` is `Green`, `Amber` or `Red`.
- `cards[5]` — `{Domain, Status, Explanation}`, the status cards the Shiny tab
  shows.
- `counts` — `{Green, Amber, Red}`, the domain counts.
- `interpretation` — the plain-language summary, built in R from the same
  values.

The response is independent of every other analysis: it needs no base case, PSA,
budget-impact or survival run. The HTA decision summary is the reverse case: it
consumes readiness inputs and derives its own statuses from them (see
`POST /api/hta-summary` below), which is why `domains` is shaped as a data frame
of `Domain`/`Status` rows.

### `POST /api/hta-summary`

`assess_hta_decision_summary()` and `build_hta_evidence_priorities()` from
eqalb_markov.R — the same two functions the Shiny HTA decision summary tab calls,
so the traffic-light rules, the position wording and the evidence-priority
ratings exist once. Every field is optional: an omitted field means "that
analysis has not been run", and R then reports its own `Not available` /
`Not yet available` / `Not yet quantified` wording instead of a guessed value.

Completed analyses, passed through unchanged from the other endpoints:

| Field | Unit | Produced by |
|---|---|---|
| `wtp` | EUR per QALY, ≥ 0 (default 100000) | the reference threshold; also accepted as `?wtp=` |
| `icer` | EUR per QALY | `/api/base-case` |
| `incremental_cost` | EUR per patient (may be negative) | `/api/base-case` |
| `incremental_qalys` | QALYs per patient (may be negative) | `/api/base-case` |
| `probability_cost_effective` | probability, 0–1 | `/api/psa`, at the same threshold |
| `mean_incremental_nmb` | EUR per patient | `/api/psa` (`mean_net_monetary_benefit`) |
| `evpi` | EUR per patient | `/api/value-of-information` |
| `highest_evppi` | EUR per patient | `/api/value-of-information` (`evppi.table[0].evppi`) |
| `evppi_table` | rows `{parameter, evppi}` | `/api/value-of-information` (`evppi.table`) |
| `cumulative_budget_impact` | EUR | `/api/budget-impact` |
| `bia_intervention_cost`, `bia_implementation_cost`, `bia_healthcare_savings` | EUR, ≥ 0 | the budget-impact totals |

The economic rule compares the **incremental net monetary benefit** —
`INMB = wtp × incremental_qalys − incremental_cost` — with zero, not the ICER
with the threshold. `incremental_cost` and `incremental_qalys` are therefore what
the verdict reads; `icer` is still accepted because the summary reports it when it
is interpretable, and it never decides a status on its own. The distinction
matters because a ratio's sign is the sign of the cost difference divided by the
sign of the health difference, so one negative ICER covers both a dominant option
(cheaper, more health) and a dominated one (dearer, less health). When the two
differences are absent the comparison falls back to `mean_incremental_nmb`, which
is the same quantity averaged over the PSA draws; with neither available the
domain is `Not available`. Equality is reported as equality: an INMB of zero
leaves the domain Amber whatever the probability of cost-effectiveness is.

The scenario inputs behind the evidence-priority signals use the same names and
units as everywhere else (`intervention_price`, `implementation_cost`,
`healthcare_savings`, `rrr`, `engagement_year1`, `engagement_followup`); an
omitted value takes the model's base-case constant.

`readiness` is the same object `/api/readiness` accepts (the ten readiness
inputs). When it is present the seven domains are derived inside the endpoint by
`calculate_readiness()`; when it is absent, readiness counts as not assessed.
Domain statuses are never accepted from the client, so the dashboard and the
evidence priorities cannot be told what to say.

Returns:

- `wtp` — the reference threshold actually used.
- `summary` — `assess_hta_decision_summary()` unchanged: `domains[5]`
  (`{Domain, Status, Measure, Basis, Interpretation}`, `Status` being `Green`,
  `Amber`, `Red` or `Not available`), `overall_status`, `position` and
  `interpretation`.
- `evidence_priorities` — `build_hta_evidence_priorities()` unchanged:
  `table[9]` (`Evidence gap`, `Current model signal`, `Current status`,
  `Why it matters`, `Evidence needed`, `Suggested study or data source`,
  `Priority`, `Dashboard domain affected`) and `summary`. `Priority` is `High`,
  `Medium`, `Low` or `Not yet available`.
- `availability` — which upstream analyses were supplied: `base_case`, `psa`,
  `value_of_information`, `budget_impact` and `readiness` booleans,
  `missing_inputs` (the request fields behind the unassessed domains),
  `not_assessable_domains` and `assessed_domains`. The two domain lists are read
  back from the R summary rather than recomputed here. `base_case` is true when
  either `icer` or the pair `incremental_cost` / `incremental_qalys` arrived, and
  `missing_inputs` names the two differences — never the ICER — because the
  economic rule reads the differences: an option with no incremental health has no
  ICER by construction, and one that costs more and adds none has a negative ratio.
  A request that sends only an ICER is therefore reported as having supplied the
  base case while still asking for the two values its verdict needs.
- `rules[7]` — `HTA_RULE_ITEMS` from eqalb_ui_copy.R, the rule sentences the
  Shiny dashboard shows in its on-demand popover, verbatim.
- `evidence_note` — `HTA_EVIDENCE_NOTE`, the note the Shiny tab shows under the
  evidence-priority table, verbatim.
- `rule_note` — `HTA_SUMMARY_RULE_NOTE`, the single-paragraph rule summary that
  the Shiny results package writes into its README, verbatim.
- `notice`.

The three rule fields exist so a client never has to restate a threshold: the
wording, including the €1m/€10m budget bands and the 40%-of-simulations rule,
comes from R on every response.

`Clinical evidence maturity` is always `Red` in this app because the clinical
inputs are simulated, so even an empty body returns an `overall_status` — that is
R's own rule, unchanged from the Shiny tab. `position` stays `Not yet assessable`
until both `probability_cost_effective` (from the PSA) and `evpi` (from the value
of information, which reuses the PSA's draws) have been supplied. The base case,
the budget impact and readiness each add their own row but are not needed for a
position; without the base case, the economic comparison falls back to the PSA's
`mean_incremental_nmb`. The
endpoint never reruns an analysis, exactly as the Shiny tab does not.

### `POST /api/value-based-price`

`calculate_value_based_price()` from eqalb_price.R — the module that answers how
much the model supports paying per treated person per year at the reference
threshold. The price is charged for each year a treated person is alive, whether
or not they stay engaged, exactly as in the cost-effectiveness model. It reads
`run_eqalb_model()` outputs only, so the supported price
comes from the same model every other endpoint uses, and it re-runs the model at
the price it solves for and reports the verification residual rather than
asserting the answer.

Query: `wtp` (default 100000, minimum 0). The body may carry it as well, like
`/api/hta-summary`.

Body: any of the 16 `ScenarioInputs` fields, plus:

| Field | Unit | Meaning |
|---|---|---|
| `current_price` | EUR per treated person per year, 0–1,000,000 | The annual intervention price the analysis runs at and compares the supported price against. It is an alias for `intervention_price` and takes precedence over it (the response's `warnings` says so when the two differ). Omitted, the scenario's own price — or the model's base-case constant — is used, so the model run, the price solve and the headroom always describe one price. |
| `wtp` | EUR per QALY, ≥ 0 | The reference threshold, as the query parameter. |

Returns, with every number, status, band, label and sentence computed in R:

- `method` — engineering provenance: `affine_price_solve_verified` when the model
  confirmed the solved price, `bisection_fallback` when a shape-free bisection
  search replaced it, or `not_available`. `method_note` explains the method in
  R's own words. Both are part of the contract for API callers and for the
  exported results package — they exist so a number can be audited — and the
  browser interface deliberately does not render either of them (no solver name,
  bisection, tolerance or fallback wording appears anywhere in the tab).
- `status` — the band for the current price: `Green` when the model run at
  `current_price` reaches the reference threshold, `Red` when it does not,
  `Not available` when the model did not return the values the comparison needs.
  It is read from that run, not from the solved price, so it stays true when a
  maximum price cannot be reported.
- `scenario` — the run the analysis is based on: the assumed risk reduction and
  engagement (fractions and percentages), incremental cost, incremental QALYs,
  ICER, incremental net monetary benefit, the model's cost response to the annual
  price (`price_cost_slope`), the incremental cost at a price of zero
  (`cost_without_price`) and the price contribution to the incremental cost.
- `headline` — `max_acceptable_price` (the highest annual price with an
  incremental net monetary benefit at or above zero; `null` when no non-negative
  price reaches the threshold), `solved_price` (the raw root, reported even when
  it is negative or above the model's own price bound), `price_supported`,
  `headroom_eur` and `headroom_pct` (against `current_price`; `null` when no
  maximum price is reported or the current price is 0), `verified` and
  `verification_nmb` (the net monetary benefit of the confirming model run),
  `reason` (R's explanation when no price could be identified) and
  `interpretation`.
- `required_effect` — the relative risk reduction the current price would need
  (`required_rrr`, `required_rrr_pct`), the scenario's own value (`current_rrr`,
  `current_rrr_pct`), `verdict` (`met`, `not_met` or `not_available`),
  `verdict_label` (the same state in R's user-facing words — `Met`, `Not met`,
  `Not available` — which is what the interface shows, so no caller maps the
  machine value), `within_sensitivity_range` (whether the requirement lies inside
  the model's own one-way range for that input) and `precision_rrr` (the
  bisection bracket width, 0.001 by default), plus `interpretation`. A
  requirement that cannot be identified inside the model's validated 0–1 domain
  for that input is reported as `null` with R's reason instead of being guessed.
- `grid` — the 3 x 3 illustrative scan of the maximum acceptable price across the
  model's own bounds: `row_axis` (relative risk reduction) and `column_axis`
  (year-1 engagement), each with its levels (`{value, role, label}`, where
  `label` is R's, e.g. `5% (low bound)`, and `role` merges to `low bound and
  scenario` when a value appears twice), then `cells` (one row per pair, with the
  incremental values, the maximum acceptable price, the raw solved price, the
  headroom against `current_price`, the status, `available` and R's `warning`),
  `cells_total`, `cells_available`, `cells_supporting_current_price`,
  `best`/`worst` (named in R) and the `summary` and `note` sentences.
- `availability` — which results were identified (`max_acceptable_price`,
  `required_effect`, `grid`), the scan counts, `reasons` (R's explanation per
  unavailable result) and `missing_inputs`: the request fields the analysis needs
  that were not supplied and have no model default. Over HTTP every model input
  falls back to its base-case constant, so it is empty for every request; it is
  populated when `calculate_value_based_price()` is called directly without an
  intervention price.
- `inputs` — the scenario the model ran, under R's argument names.
- `warnings` — request-level notes from R's endpoint. Currently one: a
  `current_price` that overrides a supplied `intervention_price`.
- `interpretation` — R's headline and required-effect sentences together. The
  headline sentence states the supported price, the current price and how far
  apart they are (in EUR and as a share of the current price), so it answers the
  three questions a reader has without any client-side comparison; the required
  sentence states what would have to change for the current price to reach the
  threshold. R no longer appends a "not clinical evidence or a pricing
  recommendation" qualifier to these sentences: that disclaimer is the
  application's, stated once on the Project description screen.
- `limitation` — R's one-way qualification of both figures ("Illustrative
  one-way analysis: … so neither represents joint uncertainty across the model's
  inputs"). It is separate from `method_note` because it belongs with the
  results: the interface shows it in the "What this price means" disclosure.
- `notice`.

A request costs about 40 `run_eqalb_model()` calls (the scenario, two runs per
price solve, the confirming run, the bisection search for the required reduction
and one solve per distinct scan assumption pair), so it takes roughly 7 s at the
0.16 s a model run measures on the development machine. It is an explicit action
in the browser interface, like the PSA and the one-way analysis.

Validation practice: this endpoint involves no simulation, so its regression is
checked against a brute-force €1 price grid in R (the highest grid price whose
incremental net monetary benefit is non-negative) and against a direct
`calculate_value_based_price()` call through both services; a PSA is only needed
where a change touches PSA code, and then at `n_sim = 100` with `seed = 12345`.

### `GET /api/tutorial`

> The browser application no longer calls this endpoint, `POST /api/tutorial/part1`
> or the three `/api/tutorial/part2*` endpoints: its legacy Guided Tutorial screen
> was retired in favour of The Journey (`/api/tutorial/journey*`). The endpoints and
> `eqalb_tutorial.R` remain available and are documented as they are. The module
> could not be removed with the screen in any case: `eqalb_tutorial_journey.R`
> calls its helpers (among them `eqalb_tutorial_ce()`, the tutorial defaults and
> formatting, and `eqalb_tutorial_contract()` for the base-case table headings).

`eqalb_tutorial_contract()` from eqalb_tutorial.R: the Guided Tutorial Part 1
contract, returned as `part1`, so the browser interface cannot drift from the
tutorial's own values or wording. Building it runs no model.

- `title`, `kicker`, `disclaimer` — the heading, the line under it and the
  simulated-data limitation the tutorial shows above the steps.
- `progress` — `{total: 4, step_template, completed_template}`. The templates are
  R's sentences with `{step}` / `{total}` / `{title}` placeholders, so the
  progress line reads the same as the reference tutorial's.
- `navigation` — `back`, `forward` and `exit` button labels.
- `completion` — the completion card's heading, paragraph and the two button
  labels. Part 2 is not part of this contract, so the card offers exactly those
  two routes.
- `controls[9]` — `{id, step_index, type, label, unit, info_topic, info, default,
  min, max, step}` for the tutorial's own nine controls (`type` is `slider` or
  `checkbox`; a checkbox carries no bounds and no step). `info` is the control's
  explanation from `CC_INFO_TEXT`, verbatim, and `info_topic` is the phrase the
  interface's information control names itself with.
- `defaults` — every control's tutorial default, keyed by control id, and typed:
  a checkbox default is a JSON boolean. This is what the client seeds its inputs
  with and what "Restart tutorial" restores.
- `headings` — the two explanations that belong to a step heading rather than to
  a control (`tutorial_bia_explain`, `tutorial_readiness_explain`), keyed as the
  steps name them.
- `table_headings` — R's own column headings for the tutorial's tables.
- `fixed.values` — the tutorial's fixed R-owned values, including
  `utility_post_mi` (0.8), `utility_post_stroke` (0.6), the implementation cost
  and healthcare savings it passes to the model, and the budget-impact and
  readiness settings it uses. None of them is a full-analysis control.
- `fixed.post_event_utilities` — the read-only block Step 1 shows: its heading,
  the two formatted values and the sentence explaining that they are fixed.
- `steps[4]` — each step's `id`, `title`, `progress` name, `intro`, `explain`
  bullets and the headings and disclosure labels it renders. Which keys a step
  carries depends on the step.
- `rules` — the tutorial's simplified traffic-light rules: the popover title, the
  trigger's accessible label and the six sentences.
- `evidence` — the tutorial's simplified evidence-generation priorities: the
  heading and the four items.
- `labels` — the short labels the summary and Step 3 reuse
  (`current_values`, `readiness_checks`, `overall_status_prefix`,
  `overall_note`, `overall_fallback_status`).
- `notice`.

### `POST /api/tutorial/part1`

`eqalb_tutorial_part1()`, the whole of Guided Tutorial Part 1 in one response.
Body: any of the nine tutorial controls. Every other value the tutorial needs is
a tutorial-owned default in R, so a request cannot read or move a full-analysis
setting, and a control outside its own range is rejected with R's message, e.g.
`'tutorial_price' must be between 0 and 900.` The endpoint is deterministic: the
same body returns the same response, and it runs no simulation.

Returns:

- `inputs` — the values the response was evaluated with, after R applied its
  defaults.
- `fixed_inputs` — the tutorial's fixed values, echoed so a caller can see at a
  glance that they are tutorial constants rather than dashboard settings. The two
  post-event utilities are here in particular: they are explicit tutorial
  constants, so editing a full-analysis utility cannot move a tutorial result.
- `ce` — the base case: `incremental_cost`, `incremental_qalys`, `icer` (JSON
  `null` when R reports it as not interpretable), `icer_display` (R's own
  rendering, including its wording for an uninterpretable ratio), `table[3]`
  (`{measure, value}`, formatted in R) and `chart` (`title`, `subtitle`,
  `x_label`, `y_label` and the two labelled `points`). The chart's axis padding is
  client-side chart geometry; the chart's data, labels and sentences are R's.
- `bia` — the budget-impact result: `horizon_years`, `total`, `total_display`,
  `total_sentence`, `linked_price_sentence` (R's own sentence naming the Step-1
  price it used), `rows` (the same row shape `POST /api/budget-impact` returns,
  for the chart), `table` (the annual rows formatted in R) and `chart` (the
  figure title, subtitle and axis names).
- `readiness` — `cards[4]` (`{domain, status, explanation}`, the domains the
  tutorial shows; the Engagement explanation is rewritten for the tutorial so it
  names the engagement input that is actually the concern), `domains[6]` (the
  assessed domains, with algorithm governance excluded from the tutorial
  presentation only), `numbers[5]` (`{measure, value, basis}`, formatted in R),
  `checks_sentence` (R's sentence naming the two domains the Step-3 answers set),
  `green_domain_count` and `domain_count`.
- `summary` — the tutorial decision summary: `overall_status`, `overall_title`,
  `rows[4]` (`{domain, status, measure, interpretation}`) and the plain-language
  `interpretation`. Cost effectiveness and budget impact use the tutorial's own
  simplified rules; clinical evidence maturity is always Red and is excluded from
  the overall status; implementation readiness reuses the status the shared
  readiness assessment produced, so the tutorial never re-implements that rule.
- `notice`.

Two rules of the response are worth stating explicitly, because they are what
keeps the tutorial R-owned:

- **Nothing is derived outside R.** Every status, threshold, interpretation,
  table row, chart label and formatted string above is produced by
  `eqalb_tutorial_part1()`; the client renders them and formats nothing.
- **The four steps come from one request.** The reference tutorial evaluated its
  steps from the same live inputs, so the client may re-request this endpoint as
  a control changes rather than combining the general-purpose endpoints and
  reproducing a tutorial decision in TypeScript.

Validation practice: no simulation is involved, so this endpoint is checked
against a direct `eqalb_tutorial_part1()` call in R with the same body — every
value, status, string, table row, chart series and decision-summary output must be
identical string for string — and against `eqalb_tutorial_contract()`. A PSA is
not needed for the tutorial and is not run to validate it.

### `GET /api/tutorial/part2`

`eqalb_tutorial_part2_contract()` from eqalb_tutorial.R: the Guided Tutorial
Part 2 contract, returned as `part2`. Building it runs no model and draws no case.

Part 2 is the commissioning case challenge, the case-based continuation of
Part 1. This contract and the two endpoints below cover all five of its sections
— the case brief, the value-for-money exercise, the budget-impact exercise, the
DHT-readiness exercise and the recommendation — and the contract says so: each of
the five sections carries `available`, and all five are true.

- `title`, `kicker` — the section heading and the line under it.
- `sections[5]` — `{key, name, available}` for `brief`, `value`, `budget`,
  `readiness`, `recommend`, in teaching order.
- `available_sections`, `coming_next_label`, `coming_next_note` — which sections
  are implemented and the wording the interface uses for the others.
- `entry_label`, `entry_note`, `entry_busy_label` — the Part 1 completion card's
  Part 2 entry. They live here, not in the Part 1 contract, so Part 1's own
  response is unchanged.
- `progress` — `total` and the two templates (`step_template`,
  `available_template`).
- `navigation` — `back`, `forward`, `exit`.
- `case_banner_template` — R's sentence for the active case, with `{label}` and
  `{title}` placeholders.
- `case_facts` — the overlay's button label, title template, close label, table
  headings and the fixed-facts hint.
- `brief` — the heading, the facts heading, the introduction template, the policy
  paragraph, the levers paragraph, the facts hint and the start label.
- `value` — the two headings the value-for-money section renders.
- `fixed` — the threshold and its display string, the five-year ceiling, and the
  manufacturer's minimum acceptable price.
- `price_control` — the negotiated-price lever: `{id, type, label, unit,
  info_topic, info, default, min, max, step}`. `info` is the lever's explanation
  from `CC_INFO_TEXT`.
- `price` — the value-for-money wording: `task`, `note`, `lever_hint`,
  `method_note`, the three price states (`at_max`, `below_max`, `over`) with their
  labels and messages, the `below_max_hint`, `maximum_label`, `threshold_label`
  and the `chart` block (title, caption, axis names, the two legend entries with
  their keys, labels and colours, the threshold line's value, colour, dash and
  label, and the marker's colour and label).
- `budget` — the budget-impact section's two headings and its `coverage_control`
  lever metadata `{id, type, label, unit, info_topic, info, min, max, step}`. The
  explanation is the coverage cap's own entry in `CC_INFO_TEXT`.
- `budget_impact` — the budget-impact wording: `task`, `note`, `scope_note`, the
  lever and coverage labels, the population, covered, full-rollout and
  coverage-sentence templates, the three affordability states (`over`,
  `below_max`, `at_max`) with their labels and messages, `maximum_label`,
  `maximum_none`, `maximum_reached_hint`, `increase_hint`, `summary_template`, the
  annual and cumulative series labels, `cost_label`, `saving_label`, the `chart`
  block, the `table` block (disclosure label, caption and column headings) and the
  price shortcut's label and note.
- `status_available`, `icer_unavailable`, `limitation`, `notice`.
  The five readiness level sets are not part of this contract: R validates the
  four answers the client sends and maps them onto the readiness inputs itself,
  and the question and answer wording is the client's own presentation copy.

### `POST /api/tutorial/part2/case`

`eqalb_tutorial_part2_case()`: creates a case, or returns the one the caller
already holds.

Body: `case_id` (optional — the handle R issued), `exclude_case_id` (optional —
the retry rule: R never returns the excluded case), `seed` (optional — pins the
draw, for a fixture; the interface never sends one).

- **With no `case_id`** R draws a case for a new session. A reload starts a new
  case, because a fresh page holds no handle to send.
- **With a `case_id`** R returns that same case unchanged, so a client resumes
  rather than re-draws. An unknown handle is an R error
  (`Unknown or expired Part 2 case id '…'.`) rather than a silent re-draw, so one
  case's facts can never appear beside another case's numbers.

The handle is opaque: it carries no meaning a client could select on, and only the
R module knows which case it belongs to.

Returns `case` (`case_id`, `label`, `title`, `heading`, `banner`, `summary` and
`facts[14]` as `{group, fact, value}` rows), `brief.intro`, `price.control` (the
lever with its starting value) and `price.curve`, `budget` (the coverage lever
with its starting value and the case's budget-impact result at the starting price
and cap), `later_inputs` (the case's own population, review time, engagement
values, language count and language availability), `strings` (the value-for-money
wording and the chart block) and `selection` (`rule`, `candidates`, `excluded`).

`budget` carries the cap actually used, the potentially eligible and covered
populations, the horizon in years, the five-year total with its display string,
the affordability `state` with its message and hint, the maximum affordable
coverage for that price with its display string, the budget ceiling, R's five
annual rows (`key`, `year`, `active_users_display`, `net_budget_impact`,
`net_budget_impact_display`, `cumulative_budget_impact`, `cumulative_display` and
the underlying cost components) and the lever's own `control` block. The
exploratory sentences the section prints (`summary`, `population_sentence`,
`covered_sentence`, `full_rollout_sentence`, `coverage_sentence`,
`lever_sentence`), its `price_shortcut` and its `strings` are assembled by
`evaluate`, which is the response the budget section renders; the case response
exists so a section has a result the first time it is opened.

The curve is one model run per lever value, so this call costs about forty-four
model runs and belongs behind an explicit action with progress.

The case's three post-event utilities are its own values, so a case's per-person
result cannot change when the application's assumptions are edited. This is the
correction to the reference tutorial, which read those two fields from the
dashboard's editable utility inputs.

### `POST /api/tutorial/part2/evaluate`

`eqalb_tutorial_part2_evaluate()`: the value-for-money and budget-impact results
for one case at one negotiated price and one coverage cap.

Body: `case_id` (required), `price` (optional; defaults to the lever's starting
value, and must be inside the lever's own range), `coverage` (optional; defaults
to the coverage cap's own default, and must be inside the cap's own range — a
value outside it is an R error rather than a silently clamped number), four
optional readiness answers (`interoperability`, `governance`, `clinical_workflow`,
`patient_engagement`, each a short level id that R validates against the levels it
accepts, mapping it onto the readiness input it represents; an omitted answer takes
R's default for that question) and an optional `curve`.

Returns:

- `case` — the case identity and facts, so a response can be verified against the
  case it describes.
- `price` — the current-price result: `price` and `price_display`, `passed`,
  `at_max`, the `state` (`at_max`, `below_max` or `over`), R's `state_label`,
  `state_message` and `state_hint`, the model detail (`incremental_cost`,
  `incremental_qalys`, `icer`, `icer_display`), R's own `detail` sentence and the
  threshold.
- `maximum` — the highest acceptable negotiated price: its `value`, its `display`
  string, its `label` and whether the current price `reached` it.
- `curve` — the full price curve: `case_id`, `point_count`, `threshold`, each
  point's `price`, stable `key`, model outputs, `icer`, `icer_display`,
  `series_key` and `meets`, and the `max_acceptable_price` with its display string.
- `marker` — R's marker for the current price: its `price`, `key`, `colour` and
  `label`.
- `chart` — the same chart block the contract publishes.
- `budget` — the budget-impact result at the same price and the coverage cap: the
  cap used, the potentially eligible and covered populations, the horizon, R's
  annual rows (each with a stable `year-N` `key`, the year's active users and net
  budget impact with their display strings, and the cumulative position), the
  five-year total with its display string, the affordability `state` (`at_max`,
  `below_max` or `over`) with its message and hint, the maximum affordable
  coverage with its display string, the budget ceiling, the annual table's
  headings, the exploratory sentences (`summary`, `population_sentence`,
  `covered_sentence`, `full_rollout_sentence`, `coverage_sentence`,
  `lever_sentence`), the `strings` block and the `price_shortcut`.
- `readiness` — the DHT-readiness exercise's result at the four answers this
  request carried: the answers R used, the readiness inputs R mapped them onto,
  each domain's `domain` and `status`, the reach and workload figures
  (`measure` and `value`), the deliverability verdict with its own label, and R's
  two calculation-dependent sentences (`note`, `engagement_note`).
- `recommendation` — R's commissioning outcome for the same results and coverage
  cap: its `status` (`do_not_recommend`, `negotiate_price`, `resolve_barriers`,
  `increase_coverage` or `conditional_adoption`), its `headline` and `message`, and
  `complete`, which is true only for `conditional_adoption`. R chooses the outcome
  from the value-for-money, affordability and readiness results and the coverage
  cap; the client renders it and infers nothing.
- `answer`, `strings`, `section`, `limitation`, `curve_source` and `notice`.

Every classification is R's: which points meet the payer's threshold, the highest
acceptable price, the three price states, which affordability state the coverage
cap produces, and the maximum affordable coverage. The client renders them.

The coverage cap scales the case's budget-impact population only. The same
response's value-for-money fields — the current-price result, the curve, the
highest acceptable price and the marker — are byte-identical whatever cap is sent,
which the parity check asserts. `price_shortcut.show` is R's own value-for-money
answer for the negotiated price (`TRUE` while that price has not achieved value for
money), not a client judgement.

The maximum affordable coverage is found in R by scanning the permitted coverage
steps from the highest down and testing each against the case's five-year budget
ceiling, so the answer is R's own search over R's own steps rather than an
inverted formula a client could reproduce. Even the lowest step's total can exceed
the ceiling, in which case the display string is R's not-available wording.

**The optional `curve`.** A Part 2 evaluation is one model run per lever value
plus the run at the current price, so recomputing the curve on every price change
would cost about forty-four runs. A caller may therefore post the curve the same
case already returned; R then re-derives the classifications and the highest
acceptable price from those model outputs instead of re-running them, and the
response is identical to the computed path. The curve is bound to its case: a
posted curve carries the `case_id` it was computed for, and R rejects a curve that
does not match the requested case, because the lever's 43 prices are the same for
every case and an unbound curve would otherwise return one case's numbers under
another case's name. A curve that is not the lever's own price list, or whose
model outputs are not usable numbers, is also an R error.

### `GET /api/tutorial/journey`

`eqalb_journey_contract()` from eqalb_tutorial_journey.R: the redesigned
tutorial's contract, unchanged by a model run.

- `journey` — `title`, `kicker`, `progress` (the chapter count and R's
  "Chapter {step} of {total}. {title}" template), `navigation`, `methods`, `end` and
  `chapters`.
  `methods` is the same `MODULE_METHOD_NOTES` dictionary `/api/defaults` publishes,
  republished here so a chapter can show its module's method note without a second
  request and so a lesson and its tab cannot describe a method differently.
  `end` is the journey's handoff, not a verdict: `title` and `body` (the completion
  overlay's two lines), `sentence` and `note` (R's longer handoff sentences), and
  `open_label` / `restart_label` / `exit_label`. The interface opens it as an
  overlay after the last state of the last chapter the list has, so a chapter added
  later moves it with the contract and no published wording has to change; it is
  never shown in a standalone explainer. The overlay renders `title`, `body`,
  `open_label` and `restart_label`, plus its own close control that returns the
  learner to the final chart; `exit_label` stays published for the contract's sake
  but is not one of the overlay's actions.
  `chapters` lists only the chapters that exist — the case brief and eight chapters:
  the base case, one-way sensitivity, the uncertainty view, the value of
  information, the price, the budget, the readiness check and the simulated
  time-to-event view — so the navigation never advertises an unbuilt chapter. The
  time-to-event view is last, and the end overlay follows it because nothing follows
  it in this list. Each entry's `title` is composed from its own position, so the
  heading and the interface's `Chapter {step} of {total}` line always agree: the
  brief is entry 1 and names itself, the base case is entry 2 and is headed
  "Chapter 2. …", and the last chapter is numbered by the length of the list.
- `case` — the fixed case: the decision, the two options, the proposed price,
  the task, and the two explainers the brief keeps behind disclosures (the payer's
  perspective, and the time horizon with its discounting). `start_label` names the
  chapter the brief opens by its number in the list ("Start Chapter 2"), because the
  brief itself is entry 1. QALYs are deliberately
  not explained here: they arrive on the screen that first plots health, after the
  learner has seen the relationship.
- `base_case.copy` — Chapter 2 as one continuous sequence of eight stages on one
  plane: `usual_care`, `add_eqalb`, `more_health`, `additional_cost`, `both`,
  `qaly`, `ratio` and `price`. Each stage carries a `caption` (its one sentence,
  shown until a result arrives and used as the fallback if a note does not
  resolve), the `focus` it points the guide at — `origin`, `lead`, `health` or
  `cost`, naming a region of the plane rather than a result — and, where the stage
  reports a value, a `note_key` into `base_case.notes`. `interactive` marks the two
  stages whose own control is the thing on screen (the QALY score and the price),
  so activating the graph does not skip them, and `advance_label` names what the
  forward control does from that stage. The chapter publishes no separate forward
  control: the graph is the way forward, so `advance_label` is the accessible name
  of that activation. `usual_care` and `both` name no note because they introduce a
  position rather than report a value. The stages carry no computed value and no
  answer list, so this chapter asks no question and shows no table.
  The `qaly` stage carries the one interactive explanation of the chapter, and
  `ratio` is the stage that reads the incremental cost-effectiveness ratio: it names
  the term, states the division and quotes this result in euros per additional QALY
  gained, which is the written intent that QALY and ICER are both explained on the
  screen that uses them.
- `journey.navigation` — `back`, `forward`, `exit` and `restart`. A chapter's
  forward control is its own graph; `back` steps one beat out of the chapter's stage
  list and, at the first beat, leaves the chapter.
- `base_case.graph` — the graph's own labels: `title`, the two axis names, the two
  point names, the two leg names, and the empty-state hint. Deliberately minimal:
  there is no threshold line, no status colour and no annotation beyond what the
  learner asks to reveal.
- `base_case.controls` — the one price lever, in the tutorial's own control shape
  but under the id `price`. Its range is narrowed to R's journey bounds (40–440)
  so the point visibly changes its position inside the range the learner can
  reach; the label, unit, step, default and explanation stay the tutorial's.
- `base_case.qaly` — the QALY lesson's copy and its control. **The score is a model
  input**, not an illustration: `control` (`min` 0.80, `max` 1.00, `step` 0.01,
  `default` = the model's own no-event utility), `heading` (the one sentence
  explaining what a QALY is), `formula_label` (the label that marks the one-year line
  as the illustration it is), `formula` (the words the one-year line is composed
  from), `fixed_title` and `fixed` (the post-MI and post-stroke utilities the
  interaction holds fixed — these stay visible beside the slider, because a learner
  comparing scores needs them to read the interaction), `info_title` ("How this score
  is used") and `info` (one paragraph: what the scale means, that the score is one of
  the model's assumptions, how the model turns scores into QALYs and what the extra
  QALYs are), `reset_label` and `ceiling_note` (the sentence for the one score the
  uncertainty analysis cannot draw exactly). The panel keeps only the state's caption,
  the definition, the slider and its value and the two held values; the one-year line,
  the response's `utility_note` for the score on screen, the `ceiling_note` and the
  reset control all sit inside the information button with `info`, so there is no
  second disclosure and no in-panel calculation example.
- `base_case.verdict_options` — the three provisional views the learner records.
- `base_case.table_headings` — R's column names, taken from the tutorial's own
  contract. The chapter itself shows no table; the headings stay published so the
  response and the tutorial cannot diverge if a later chapter tabulates.
- `sensitivity` — the third chapter's `copy`, `graph` and `disclosure` (`title` and
  `lines`: the method's name, what a flat bar means, what a long bar does not mean).
  Those three sentences used to be states' notes beside the bars; they are published
  here so the panel's caption stays the teaching sentence and the caveats are one
  click away.
- `uncertainty.copy` publishes `variation_title`, and the chapter's own result
  publishes `variation.method_sentence` (what the repeat simulation is called) with the
  sentences describing which assumptions it varied.
- `price` — the fifth chapter's `copy` (its six states), `graph` (the two displays'
  labels), `control` (the price lever's bounds and unit, used for the track and the
  request; this chapter has no slider of its own), `threshold`, `threshold_display` and
  `scenario_key`. `scenario_key` names every input the price solve depends on —
  including the no-event utility — and is composed in R; the client treats it as
  opaque, so a stored solve cannot outlive the scenario or the reference it was solved
  for.
- `budget` — the sixth chapter's `copy` (its ten states and the horizon note), `graph`
  (each panel's own axis name), `control` (the coverage lever), `population`,
  `horizon_years` and `assumptions`. It publishes no price-choice wording, because the
  journey has one price.
- `readiness` — the seventh chapter's `copy` (its nine states), `graph` (its own figure
  labels), `questions` (the four the chapter asks), `defaults` (the option ids that
  match the case's own values, which are also the start), `fixed` (the six held
  inputs, as label/value rows), `inputs` (the ten inputs `calculate_readiness()`
  receives at those defaults) and `module`. The statuses, rules and per-domain
  sentences are not published here: they arrive with the chapter's own result. Its last
  state names its own `advance_label` ("How events unfold over time"), because it opens
  the bridge into the chapter that follows rather than moving to another part of the
  check.
- `readiness.module` — what the dashboard module publishes so its own panel can open
  this chapter as a standalone explainer: `label` (the module's name), `orientation`
  (the one sentence a reader who arrived from the module needs: which case the lesson
  uses and that it reads none of their settings), and `enter_label` / `return_label`.
  A chapter that publishes no `module` block cannot be opened on its own, so the
  interface cannot invent a standalone lesson R has not written. The chapter's copy is
  not duplicated here: the explainer shows the same states, captions and request.
- `survival` — the eighth and last chapter's `copy` (three states, each naming its
  `beat` — `time`, `step` or `compare` — and all three carrying `interactive` because
  the time choice is the chapter's own control), `graph` (`title`, `qualifier` — the
  short visible line saying the curves are simulated and other-cause deaths are
  censored — and `times_title`, the legend of the time choice), `inputs_key` and
  `module`. The `inputs_key` is composed in R from every input the simulation reads —
  the sample size, the follow-up, the seed, the effect assumption and the three annual
  risks — so the client caches against all of them rather than against the session; the
  price and the score are deliberately absent. The curves, the readings and the
  comparison arrive with the chapter's own result, not here.
- `survival.module` — the same shape as `readiness.module`, with no price field: the
  lesson is the case's own simulation and reads nothing the learner has chosen.
- `notice` — the one illustrative-data notice the journey shell prints.

The threshold is not part of this slice at all: no response contains it and no
function compares a result with it.

### `POST /api/tutorial/journey/base-case`

`eqalb_journey_base_case()`, the base case for one price and one score. Body: `price`
and `utility_no_event`, both optional, each defaulting to the case's own value and each
validated against its own control's range (`'price' must be between 40 and 440.`,
`'utility_no_event' must be between 0.8 and 1.`). An out-of-range value is **refused,
never clamped**. Every other assumption is the case's own fixed value, so a journey
request cannot read or move a dashboard or Part 1 setting.

The score reaches the model exactly as submitted: it is passed to
`eqalb_tutorial_ce()` as `tutorial_utility_no_event` and on to
`scenario_utility_no_event`, with no rounding or rescaling.

- `inputs.price` and `inputs.price_display` — the price the response was evaluated
  with, and R's own rendering of it, so the interface never formats a currency.
- `inputs.utility_no_event`, `inputs.utility_display` and
  `inputs.utility_at_ceiling` — the score, R's rendering of it, and whether it is the
  one score the uncertainty analysis cannot draw exactly.
- `base_case.incremental_cost`, `incremental_qalys`, `icer` (JSON null when R
  cannot interpret it), `icer_display`, `table`, `chart` — the same values
  `POST /api/tutorial/part1` returns for the same price, score and fixed assumptions,
  because both call `eqalb_tutorial_ce()` and therefore `run_eqalb_model()`.
- `base_case.status` — `domain`, R's `code` (`Green`/`Amber`/`Red`/`Not
  assessed`) and R's `interpretation`, which is the same string Part 1's cost
  effectiveness summary row carries. The chapter shows no traffic light; the
  fields stay published because they are R's interpretation of the result.
- `base_case.reading` — `code` and one plain-language `sentence` covering the
  whole result. The client renders the sentence; it never selects copy from the
  code.
- `base_case.notes` — `cost`, `health` and `ratio`: one sentence each, written and
  formatted in R, so a stage can reveal one idea at a time and the interface can
  keep each one on screen as the learner builds the picture. `ratio` is the ICER
  sentence and the only place the learner is told what the ratio is called, how it
  is formed and what this result's value is: it names the incremental
  cost-effectiveness ratio (ICER), states that it divides the extra cost by the
  extra QALYs, and quotes the same `incremental_cost`, `incremental_qalys` and
  `icer` the response publishes, in **euros per additional QALY gained** — never
  per person, because the money is per QALY rather than per patient. It never
  prints a negative ratio as a price of health gained: with a loss of health it says
  the ratio is not a price per additional QALY, with no extra health it says no
  ratio can be read, when eQalb costs less and adds health it says so, at zero extra
  cost it reports a zero ICER per QALY gained, and an uninterpretable ratio is
  described as such without quoting an amount. The note is recomputed with the
  result, so it follows the price and the score rather than describing an earlier
  one.
- `base_case.utility_note` — one sentence tying the incremental QALYs to the score on
  screen, so the live result is reported in R's own words rather than recomposed by
  the client.
- `base_case.ceiling_note` — R's sentence for the one score the uncertainty analysis
  cannot draw exactly, or JSON null at every other score.
- `notice`.

Both tutorial families register flat handler paths in `api/plumber.R`
(`/api/tutorial-journey`, `/api/tutorial-journey-base-case`,
`/api/tutorial-journey-uncertainty`, `/api/tutorial-journey-sensitivity`,
`/api/tutorial-journey-voi`, `/api/tutorial-journey-price`,
`/api/tutorial-journey-budget`, `/api/tutorial-journey-readiness` and
`/api/tutorial-journey-survival`) for the prefix
reason described above; the published paths are the ones documented here, and the
FastAPI service maps one onto the other.

## Tests and checks

- `frontend` — `npm run build` runs `vue-tsc -b` (type check) and `vite build`;
  `npm run lint` runs oxlint over the TypeScript sources.
- The model itself is checked by the R code paths; this service only transports
  results.
- A browser session against a running API is the quickest end-to-end check: run
  each tab and confirm the numbers are plausible and the notices are present.
- `/api/readiness` can be checked against the Shiny DHT Readiness tab: the same
  inputs must give the same figures, domain statuses and interpretation. Calling
  `calculate_readiness()` directly in R is the reference for those values.
- `/api/hta-summary` can be checked against direct calls to
  `assess_hta_decision_summary()` and `build_hta_evidence_priorities()` in R with
  the same arguments: the `domains` rows, `overall_status`, `position`,
  `interpretation`, the priority `table` and its `summary` must be identical
  string for string.
- `/api/value-based-price` can be checked two ways, both of which were used when
  it was added: against a brute-force €1 price grid in R (the highest grid price
  whose incremental net monetary benefit is non-negative must be within €1 of
  `headline.max_acceptable_price`), and against a direct
  `calculate_value_based_price()` call with the same argument list. With the
  default inputs the endpoint returns a maximum acceptable price of
  €155.029800318324 at €100,000/QALY, a headroom of −€204.970199681676 against
  €360, and a required risk reduction of 24.61%; the solved price is confirmed by
  a model run whose incremental net monetary benefit is −3e-12.
- The Guided Tutorial Part 1 endpoints are checked against a direct
  `eqalb_tutorial_part1()` / `eqalb_tutorial_contract()` call in R with the same
  body: the contract, and every value, status, string, table row, chart series and
  decision-summary output for the tutorial defaults, one changed value per Step-1
  control, a changed eligible population, the readiness workflow boundaries, the
  two Step-3 answers and each reachable tutorial status, must be identical. No
  PSA is run for that check: the tutorial excludes the PSA, and it has no PSA
  input.
- The Guided Tutorial journey endpoints are checked against a direct
  `eqalb_journey_base_case()` call in R. For the same price and fixed
  assumptions, the journey response's incremental cost, incremental QALYs, ICER,
  formatted ICER, table values, chart points, status code and status
  interpretation are identical to the corresponding fields of
  `POST /api/tutorial/part1`. A request carrying dashboard-style keys changes
  nothing, and an out-of-range price returns R's message.
- The journey's price chapter is checked against the same functions it calls: its
  solved price and `method` equal a direct `eqalb_price_solve()` call at the same
  price, threshold and argument list; its balance equals
  `eqalb_tutorial_ce()` for the same price, so the chapter and the base case
  cannot disagree; a lower reference yields a lower solved price; and a
  model-run counter proves a moved price costs one `run_eqalb_model()` call when
  the solve is posted back, against three for a fresh solve. A posted solve
  carrying another scenario key, another threshold, a missing field, an
  unavailable solve with no reason, or a non-finite `max_acceptable_price` is
  asserted to raise R's own error, and a price outside the lever's range is
  rejected with R's message.
- The Guided Tutorial journey's budget chapter is checked against the same function
  it calls: every year's `net`, `cumulative`, `active_users` and `new_users` equals
  a direct `calculate_budget_impact()` call with the journey's own population and
  constants, the running total equals the last cumulative value, and a **model-run
  counter proves zero `run_eqalb_model()` calls**. The population is asserted to be
  the journey's 100,000 rather than the budget-impact route's 70,000, the sweep's
  19 steps are asserted, identical candidate prices are asserted to deduplicate, and
  a price outside the lever is asserted to raise R's message.
- The Guided Tutorial journey's readiness chapter is checked against
  `calculate_readiness()` itself: the four questions are asserted to offer three
  options each, their `input` values to be the strings and numbers that function
  accepts, and the defaults to equal the case's own interoperability level, governance
  approach, review minutes and language count. Every option of every question is then
  answered on its own and the resulting `status` is asserted to equal a **direct
  `calculate_readiness()` call** for that option's input, with `counts`, `domains` and
  the two `notes` matching the same call. `changed` is asserted to name the edited
  question and to be JSON null at the defaults, an engagement answer is asserted to
  change nothing, `readiness_key` is asserted to differ per answer, to be stable for
  the same answer and to name all ten inputs, and a **model-run counter proves zero
  `run_eqalb_model()` calls**. An option the chapter does not offer is asserted to
  raise R's own message, and an `answers` key that is not one of the four questions is
  asserted to be ignored.
- The Guided Tutorial Part 2 endpoints are checked the same way: against a direct
  `eqalb_tutorial_part2_case()` / `eqalb_tutorial_part2_evaluate()` call in R. The
  contract, all three cases (resumed by their handles and drawn by seed), each
  case's fourteen facts and later-section inputs, each case's full 43-point curve,
  and the value-for-money result at every captured price — the lever minimum, the
  default, the threshold crossing, the highest acceptable price and one lever step
  above it — must be identical, on both the computed and the posted-curve paths.
  The posted path is also checked against the computed path response for response,
  the seeded draw must be reproducible, a retry must never return the excluded
  case, a curve bound to another case must be rejected, and a body carrying
  dashboard-style fields must change nothing.
- The Slice 2 budget-impact outputs are checked per case at the default price and
  cap, the cap minimum and maximum, the maximum affordable coverage, one permitted
  step above it, and at a price that fails value for money. Each fixture pins the
  covered population, the budget ceiling, every annual row, the five-year total,
  the affordability state with its message, the maximum affordable coverage and
  the current-settings wording. Two further checks bind the section's boundaries:
  changing the cap must leave the value-for-money fields — the current-price
  result, the curve, the highest acceptable price and the marker — byte-identical,
  and each of the three affordability states must be reachable. Out-of-range
  coverage and an unknown case handle are asserted to produce R's own errors, and
  a request that omits `coverage` must evaluate at the cap's default. All three
  cases' Slice 1 numbers are pinned to the values measured before the budget
  section existed (case A 2 passing points and €155.00, case B 30 and €295.00,
  case C 5 and €170.00). No PSA is involved.
- The readiness and recommendation outputs are checked the same way: the readiness
  block for the four defaults, one answer changed per question and the four answers
  omitted, with the delivered levels and the domain statuses asserted against R;
  and each of the five recommendation outcomes at one request per case, including
  the outcome's headline and message verbatim, its `complete` flag, R's own
  validation error for an invalid answer, and the four criteria the outcome was
  chosen from. Both checks also assert that the sections beside them do not move.

## Known limitations

- The service is unauthenticated and bound to the loopback interface. It is a
  development and teaching service, not a deployed product.
- One worker serialises concurrent requests; two are started by default, so a
  third simultaneous analysis waits.
- The Guided Tutorial endpoints cover Part 1 in full and all five Part 2 sections.
  Part 2's user-visible retry flow is not implemented: the completion card offers
  "Open full analysis" only, and the Back control stays in the section nav. The
  retry rule exists in R (`exclude_case_id`, which never returns the excluded case)
  and is covered by the parity check, but no interface action calls it yet.
- The tutorial's budget-impact exercise reuses `calculate_budget_impact()` but
  supplies its own fixed values, published in the case response and the contract:
  year-1 uptake 10%, rising 5 percentage points a year over a five-year horizon,
  with no avoided-event savings passed through, the case's own follow-up engagement,
  and the tutorial's €3,000,000 ceiling. It therefore reads none of the dashboard's
  editable Budget impact inputs, and its figures are not expected to match that
  tab's.
- A Part 2 case costs about forty-four model runs, because its price curve is one
  model run per lever value. Creating or resuming a case is therefore an explicit
  action with progress; a price change costs one further model run, because the
  case's curve is posted back for R to re-classify. Posting a curve never lets a
  caller decide a status — R re-derives every classification and the highest
  acceptable price from the model outputs — and a curve is bound to its case, so a
  curve computed for one case is rejected under another.
- Part 2 depends on no PSA, no value-of-information result and no dashboard
  setting. Unlike the reference tutorial, whose case borrowed the implementation
  cost, the healthcare savings, the budget-impact settings, the digital-access
  settings and the two post-event utility fields from the analysis dashboard, a
  Part 2 case here carries its own values: a case's facts and its per-person
  result cannot move when the application's assumptions are edited, and a case's
  price lever cannot move a dashboard input.
- The tutorial routes are the one place where the two services expose different
  paths. plumber cannot hold a flat route and a nested route that share a prefix:
  defining `/api/tutorial/part1` in `api/plumber.R` alongside `/api/tutorial`
  makes plumber rebuild its route table and drop the sibling routes. The handlers
  are therefore registered there as `POST /api/tutorial-part1`,
  `GET /api/tutorial-part2`, `POST /api/tutorial-part2-case`,
  `POST /api/tutorial-part2-evaluate`, `GET /api/tutorial-journey` and
  `POST /api/tutorial-journey-base-case`. The published paths are
  `POST /api/tutorial/part1`, `GET /api/tutorial/part2`,
  `POST /api/tutorial/part2/case`, `POST /api/tutorial/part2/evaluate`,
  `GET /api/tutorial/journey` and `POST /api/tutorial/journey/base-case`, which
  the FastAPI service serves and maps to those handlers; both services run the
  identical `eqalb_tutorial_*()` and `eqalb_journey_*()` code.
- `/api/value-of-information` needs the client to hold the PSA draws, so it only
  works after a PSA has run in the same browser session.
- Charts in the Vue client are re-implementations of the Shiny plots from the
  same numbers, so cosmetic differences are expected.
- A number a client posts is preserved at the precision the service transmits —
  15 significant digits, since both the worker's reply writer and the plumber
  serializer use `jsonlite`'s `digits = NA`. A client that posts a value with more
  digits than that still gets it rounded to 15. A posted
  `incremental_cost` of 1234.5678901234 used to arrive as 1234.5679; it now arrives
  unchanged, and a 1,000-draw PSA at seed 12345 gives the same EVPI through FastAPI
  as through plumber and as a direct R call (4.70724749145015, previously
  4.6942935). Draws a client received from `/api/psa` therefore survive the round
  trip bit-exactly, which is the case `/api/value-of-information` depends on.
- A PSA above roughly 5,000 draws exceeds the FastAPI worker's 15-minute request
  timeout (`EQALB_R_TIMEOUT`, default 900 s) at the measured 0.18 s per
  iteration, so the 10,000-draw ceiling is accepted by validation but needs a
  raised timeout to complete. The plumber service has no such limit.
- `/api/readiness` and `/api/hta-summary` have typed client functions
  (`postReadiness()`, `postHtaSummary()`), and the Vue client has tabs for both.
- `/api/hta-summary` transports values the caller already holds, so a client must
  supply the base-case, PSA, value-of-information and budget-impact outputs (and
  the readiness inputs) to get a fully assessed dashboard. The endpoint never
  runs those analyses itself, exactly as the Shiny tab never reruns a model, and
  it derives every status through the two eqalb_markov.R functions rather than
  accepting a status from the client.
- A malformed field type (for example a string where a number is expected) is
  rejected by the API's own request model with HTTP 422 before R sees it, exactly
  as for every other endpoint. Ranges, level sets, defaults and the wording of
  all readiness errors come from R; no readiness rule is duplicated in Python or
  TypeScript.
- The optional plumber HTTP service (`api/run_api.R`) serialises `NA` with
  plumber's jsonlite defaults, so a not-interpretable value arrives as the string
  `"NA"` rather than as `null` (verified for `engagement_retention_pct` when
  year-1 engagement is 0, and measured again for a failed OWSA scenario, where the
  failed bound's numeric cells come back as `"NA"` instead of `null`). This is
  pre-existing plumber behaviour that affects the
  other endpoints in the same way, not something the FastAPI service does: the
  FastAPI/worker path sets `na = "null"` explicitly and returns `null`, which is
  the convention the Vue client relies on. R's own text — an OWSA `summary`, a
  readiness interpretation — is identical on both services.
- The plumber service answers an input the R layer rejects with HTTP 500
  (`{"error":"500 - Internal server error"}`), because plumber's default error
  handler maps the R error to a server error. The FastAPI service maps the same
  error to 400 with R's message in `detail`. This is pre-existing and identical
  for every endpoint, measured on `/api/base-case`, `/api/psa`, `/api/readiness`
  and `/api/value-based-price`; the 400 row in the status table above describes
  the FastAPI service, which is the one the browser interface uses.
- `/api/value-based-price` has a typed client function (`postValueBasedPrice()`)
  but no Vue tab yet: the R module and the endpoint are phase 1 of the module,
  and the interface is phase 2. Nothing in the client derives a price, a
  threshold or a status, and the function is not referenced by any component yet,
  so it is tree-shaken out of the production bundle.
- The value-based price status is read from the model run at `current_price`, so a
  `Green` status can coexist with `headline.max_acceptable_price` being `null`
  when the solved price lies above the model's own price bound (a threshold above
  roughly €970 million per QALY): the current price is supported, but no
  maximum price inside the model's price domain can be reported.
