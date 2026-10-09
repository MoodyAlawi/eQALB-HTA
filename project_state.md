# eQalb project state

Last verified: 2026-10-09

## Project purpose

Educational R Shiny HTA model for a fictional hypertension digital therapeutic
called eQalb.

All clinical data, costs, utilities, treatment effects, survival data, PSA
distributions, and economic outputs are illustrative or simulated unless
explicitly documented otherwise.

## File map

- `app.R`: Shiny UI and server logic.
- `eqalb_markov.R`: economic model and reusable model functions.
- `eqalb_owsa.R`: reusable one-way sensitivity-analysis helper.
- `eqalb_survival.R`: reusable simulated survival (Kaplan-Meier) helper.
- `readme.md`: project overview and user-facing documentation.
- `run_app.R`: launcher that pins the address to 127.0.0.1:7788.
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
  explains how to read the curve.
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
  €3,000,000, no Red domain allowed and the manufacturer's minimum acceptable
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

## Current methodological interpretation

- ICER shows incremental cost per additional QALY.
- The cost-effectiveness plane shows incremental costs and QALYs for one
  scenario.
- Deterministic sensitivity analysis changes one input at a time.
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
- The tutorial step-1 "Fixed post-event utilities used in this tutorial" block is
  static UI text rendered from the model constants (`utility_post_mi`,
  `utility_post_stroke`), so it does not track the editable base-case utility
  inputs in the full analysis; the tutorial calculation itself keeps using those
  live inputs.
- Formal model validation is deferred until the current modules are stable.
- PSA runtime is relatively long for large simulation counts.
- The CEAC x-axis upper limit is no longer user-selectable: it is derived from
  the Reference WTP control as `max(2 x reference, €100,000)`, so the plotted
  range changes with the reference threshold. The CEAC probability values
  themselves do not depend on the axis limit.
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
- Tutorial Part 2 fixes its case facts, but it still draws some parameters the
  case does not restate as facts from the existing live controls: the
  budget-impact uptake schedule and horizon, the implementation cost, the
  healthcare-use savings, digital access and digital suitability, accessibility
  features and avoided-event savings. Changing those full-analysis inputs
  therefore changes Part 2 as well, exactly as they change the Part 1 tutorial.
  The case's own inputs are the negotiated price, the programme coverage cap and
  the four readiness-exercise choices.
- Part 2 fixes the three utilities at the active case's own values (Case A
  0.86 / 0.80 / 0.60, with Cases B and C differing) rather than at the model
  constants, so unlike the Part 1 tutorial it does not follow the editable
  no-event utility slider. This is intentional: the case facts are declared
  evidence facts, not learner levers.
- Part 2's readiness summary shows all seven readiness domains, including
  Algorithm governance, which the Part 1 tutorial deliberately drops from its
  simplified view. It is rendered in the Recommendation section, while the five
  summary cards cover Equity and access, Engagement, Workflow burden,
  Interoperability and Algorithm governance; Language access and Accessibility
  are graded in the seven-domain test but have no card, and in Part 2 those two
  are fixed at Green unless the full-analysis accessibility box is unchecked.
- Part 2 readiness still uses the live digital-access, digital-suitability and
  accessibility inputs, so a learner who unchecks "Accessibility features
  available" in the full analysis would make the Part 2 case fail its
  deliverability test with a Red that has no card in the Recommendation summary.
  Algorithm governance, interoperability, workflow burden and follow-up
  engagement are now the exercise's own choices rather than live global inputs.
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
  limiting instead of describing a high follow-up value as low. Part 2 restates
  the same description from its own 30/60/90 answer via `part2_engagement_level()`,
  so the Engagement domain can carry different wording in the Part 1 tutorial,
  Part 2 and the DHT Readiness tab even though all three share one status rule.
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

## Current task

Completed: a focused cleanup of the full-analysis "DHT Readiness &
Implementation" tab. The tab's own Year-1 and Follow-up engagement sliders were
removed, so Global Settings is now the only place in the app where engagement is
adjusted; the assessment reads `input$engagement_year1` and
`input$engagement_followup`, so a change there is picked up by the next "Assess
readiness" click, and the readiness inputs table in the read-only Assumptions
overlay reads the same two values. The duplicated "Readiness overview" section
and its large per-domain cards were removed, leaving the compact seven-row
Domain assessment table, the quantitative outputs table, the traffic-light rules
control and all other readiness controls. Because that four-column table was the
only element in the app that overflowed at 390px, it is now rendered inside a
`.cc-readiness-domain` wrapper with the same fixed-layout treatment the Part 2
case-fact table already uses, so the tab no longer forces a horizontal scroll.
`calculate_readiness()` and its thresholds, the traffic-light rules, Part 1,
Part 2, the VOI and HTA-summary tabs, the economic outputs and exports were not
changed.

## Next planned task

Review the DHT Readiness tab end to end now that it has a single engagement
control and a single readiness display, and confirm the Assumptions overlay and
the HTA decision summary still describe the tab accurately.

### Superseded note

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
