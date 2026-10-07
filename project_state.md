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
  analysis or Restart tutorial. It reuses the existing model, budget-impact and
  readiness functions and the existing `assess_hta_decision_summary()` readiness
  result, and shares the Cost-effectiveness plane and budget-impact chart
  builders with the full analysis.
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
- The tutorial's readiness step takes its engagement assumptions from the
  tutorial's own step-1 sliders rather than the full-analysis readiness sliders,
  so the follow-up engagement value carries across steps without a second input.
  It also maps its two yes/no questions onto existing readiness inputs
  (interoperability maturity and the supported-language count) and drops the
  algorithm-governance domain from the tutorial presentation only.
  `calculate_readiness()` is called unchanged, so the full DHT Readiness tab still
  reports all seven domains. Because the shared explanation is written from the
  follow-up value alone, the tutorial rewrites the Engagement description via
  `tutorial_engagement_explanation()` so it names whichever engagement input is
  limiting instead of describing a high follow-up value as low.
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
  main inputs and the EVPI and EVPPI headings; the tutorial has none, and no
  discount-rate control exists in the model, so no control was added for it.
  The icon sits inside the input label, so the label's accessible name includes
  its own explanation. The icon is drawn in CSS (a borderless button holding a
  small circled `i`), so no icon font or extra package is needed, and both the
  information popovers and the traffic-light-rules popovers carry a custom
  class through the popover options (`cc-info-popover` and `cc-rules-popover`),
  which is the hook the scoped CSS uses to remove the heading margin that used
  to leave a light strip above the header.
- Traffic-light rules are now on demand everywhere in the analysis area:
  `cc_rules_popover()` wraps the same bslib popover pattern for the Kaplan-Meier
  tab, the DHT readiness tab, the VOI tab, the tutorial summary and the HTA
  decision summary, so no rules paragraph is permanently visible.
- The three removed analysis-tab notice boxes are gone, but the same wording
  still appears where it is result-level output rather than a repeated banner:
  `BIA_DISCLAIMER` is part of `bia_interpretation` and `DHT_DISCLAIMER` is part
  of the readiness `interpretation` string. Both were left unchanged because
  they are generated output text, not standalone notices.

## Current task

Completed: rewrote the Project Description content only. It now explains that
eQalb is the fictional digital health intervention being assessed and that the
interactive R Shiny application is the educational simulation around it, lists
the analyses the app brings together, states the illustrative nature of all
outputs and decision rules, and ends with a "Feedback and contact" section
containing a `mailto:` link and the LinkedIn link. The copy is centred with the
rest of the view, and the heading, card layout, Back button and all other views
are unchanged.

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