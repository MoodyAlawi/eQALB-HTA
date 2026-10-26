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
interface, and what remains sits in exactly two closed disclosures. Details are kept in the private project record.
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

The redesigned Guided Tutorial is being built as a separate teaching sequence,
additively and behind `/app?journey=1`, so the tutorial above stays the default
entry and is unchanged. Its first slice — the case brief and Chapter 1 (base
case) — is implemented in `eqalb_tutorial_journey.R`, its endpoints
(`GET /api/tutorial/journey`, `POST /api/tutorial/journey/base-case` and one per
later chapter), an isolated session (`useTutorialJourney`) and
`views/JourneyView.vue` with `components/journey/`. Chapter 1 is one continuous
guided sequence: a guide ring
and caret point at the one control to act on, and a completed action *is* the
advance, so there is no forward button between the four exploration stages and no
timer anywhere. The learner selects eQalb (the only model run), reveals the extra
cost, the extra health and the ratio, then moves the price as often as they like;
the one quiet Continue appears after the first move and carries the
unchanged-health observation and the reflective question. A quiet Back revisits an
earlier stage without erasing anything, and Resume returns. There is no
multiple-choice question beyond the three provisional views, and no table,
traffic light or threshold line. The base case goes through `eqalb_tutorial_ce()`
and therefore `run_eqalb_model()`, so its values are the same values Part 1
returns for the same price, score and fixed assumptions; the journey adds the
scenario's own levers, R-owned reveal sentences and R-owned interpretation only. The
illustrative-data notice is printed once, in the journey's header.

The journey now has eight chapters, in teaching order: the base case, one-way
sensitivity analysis, the probabilistic uncertainty view, the value of
information, the price, the budget, the readiness check and the time to a first
heart attack or stroke. All eight share the same
shell, the same persistent panel, the same spotlight guidance and the same
bridge-between-chapters pattern, and each chapter is one continuous guided sequence of
states rather than a set of screens. The endpoints are `GET /api/tutorial/journey` (the
contract: the chapter list, the copy and the chart labels),
`POST /api/tutorial/journey/base-case`,
`POST /api/tutorial/journey/sensitivity`, `POST /api/tutorial/journey/uncertainty`,
`POST /api/tutorial/journey/voi`, `POST /api/tutorial/journey/price`,
`POST /api/tutorial/journey/budget`, `POST /api/tutorial/journey/readiness` and
`POST /api/tutorial/journey/survival`. Each
chapter's calculation reuses the analysis function the corresponding dashboard tab
uses and runs no simulation of its own; the value-of-information chapter is the
clearest case, because it is handed the draw rows the uncertainty chapter returned
and puts a value on exactly those comparisons.

**One scenario, chosen in the base case, used by every chapter.** The base case sets
the journey's two levers: the annual price and the quality-of-life score of a year
without a prior cardiovascular event (0.80–1.00, step 0.01, defaulting to the model's
own 0.86). Both travel in the body of every request whose calculation reads them, and
both are model inputs rather than teaching props — the score reaches
`scenario_utility_no_event` exactly as submitted, with no rounding or rescaling, and
in the uncertainty chapter it becomes the mean of `psa_parameter_table()`'s existing
beta for that parameter, whose spread is the analysis's own and is not chosen here.
At exactly 1.00 that beta's own validity guard applies, so the deterministic model
uses 1.00 while the simulation's draws centre marginally below it and are narrower;
R publishes one sentence for that single score and is silent at every other, and the
guard is not replaced or bypassed. Changing either lever drops everything derived
from the previous scenario — the repeats, the rankings, the value of information, the
balance and its solve, and the budget sweep — rather than relabelling it, and each
in-flight request is cancelled by its token so a late answer for the old scenario is
discarded. The value-of-information chapter is the one exception by design: it values
the retained draw rows rather than rebuilding them, so it takes no score of its own.

The base-case QALY lesson is therefore interactive rather than illustrative. Its
one-year line ("1 year × [score] = [result] QALYs") is labelled as arithmetic on the
score, while the model's own answer is re-run for the score on screen and reported in
R's words, so the illustration and the result cannot be confused. The post-MI (0.80)
and post-stroke (0.60) utilities stay fixed during that interaction. The panel itself
keeps only the state's caption, the sentence that defines a QALY, the slider and its
value, and those two held values; the scale, the role of the score, the one-year line,
R's answer at the score on screen, the note for the one score the uncertainty analysis
cannot draw exactly and the way back to the model's own assumption all sit inside the
panel's single information button, which is the only disclosure the QALY step has.

**One price for the whole journey.** The price chapter and the budget chapter have no
lever of their own. The price chapter places the learner's price on a track beside the
manufacturer's proposal and beside the price at which the balance reaches zero, and
draws the balance on a separate axis with its own zero, so the two quantities are
never put on one scale. The budget chapter charges the same price under its own
payment assumption, and its only interaction is the coverage lever, which selects from
the sweep R returns in one response. A stored price solve is dropped whenever either
lever changes, and R validates the posted solve's scenario key — which folds in the
score too — before using it, so a solve can never supply a marker for a scenario it
was not solved for.

The budget chapter draws one bar per year and the running total on its own axis, runs
no model at all (its figures are `calculate_budget_impact()`'s), and its coverage
lever selects from a sweep R returns in one response. Its spending and savings are
shown as a four-figure breakdown — programme costs, setup costs, healthcare savings
subtracted, and the net impact — built up one card at a time with R's own amounts,
rather than explained in a paragraph; the amounts are labelled by R as five-year,
undiscounted totals. The breakdown and the chart are the base application's own budget
chart and metric cards, so the journey's figure reads the same way as the analysis
tab's. The budget chapter accepts no utility: `calculate_budget_impact()` prices
active users and has no quality-of-life term, so the score cannot move a budget figure
and the chapter does not claim it does.

**One place for the way forward.** Every chapter and state renders the same accent
disc in the panel's footer: an arrow with no visible text, whose accessible name is
R's own transition wording ("The balance at your price", "Go on to the budget") or the
journey's own "Next part of the journey". It is a 44 px target, full-width on a phone,
carries a visible focus ring, keeps its box and its position while R works, holds a
slow breathing halo only while it is ready to advance, and pauses that halo on hover,
on focus and while busy. The arrow itself never moves, and `prefers-reduced-motion`
leaves a static accent with no pulse at all. Where nothing follows — the last state of
a chapter that opens the next chapter's bridge, and the end of the journey — no control
is rendered, so an integration boundary stays control-free.

The budget chapter keeps two costing conventions apart rather than merging them:
`calculate_budget_impact()` charges the annual price for **active users only**, while
the Markov model charges **everyone receiving eQalb**, so the same price is applied
under a different payment assumption and a budget total is not the Chapter 5
per-person result scaled to a population. The difference is stated in the chapter's
first state and recorded in its disclosure as a model limitation; this slice does not
harmonise the two and does not apply a budget ceiling.

The readiness chapter is the seventh chapter, and the first that runs **no model and no
economic function at all**: it is `calculate_readiness()`, the
assessment the DHT readiness tab and Part 2 already use, called once per request. It
asks about the four things that describe a deployment — how the app exchanges data
with the clinical record system, how the algorithm changes after it is deployed, how
much clinician review each patient takes a month, and how many languages are offered —
with three scenario-worded options each, so a learner who does not know an acronym can
still choose. The other six inputs the assessment needs are the case's own values and
are shown on demand rather than asked about; the two engagement values in particular
are the journey scenario's, so this chapter cannot contradict the economics the earlier
ones computed. Each answer is a state: the changed area is marked and the panel prints
that domain's own sentence from `calculate_readiness()`, with the traffic-light rules
presented as illustrative teaching rules rather than official standards. Nothing
requires a Green, no status is treated as a verdict on a technology, and the seven
labelled domain chips are the figure while the counts are a secondary summary rather
than a readiness score. The chapter adds only what the check is and is not: that the
economic results assume the intervention can be delivered as modelled, that these are
scenario answers judged by an illustrative checklist, that the check does not verify the
modelled outcomes or validate the economic assumptions, and that it is not a
regulatory, cybersecurity or funding decision. Answers survive Back, and an assessment
is cached against R's own ten-input set for the case together with the four answers, so
a different case or a changed answer cannot reuse it; readiness sits deliberately
outside the price and utility invalidation, because the assessment reads neither. The
chapter's last state names its own way forward, because it opens the bridge into the
chapter that follows; the journey's end card (R's `journey.end`) follows the last chapter
only, and a standalone explainer of this lesson ends with its own return to the
readiness module.

The time-to-event chapter is the eighth and last, and it is a different view of the same
comparison rather than a further calculation of value: `simulate_eqalb_survival()`, the
function the Simulated survival tab runs, at the case's own effect assumption and the
model's own annual risks, with 1,000 people per arm, 10 years and one fixed seed. It
reads no price and no score, so nothing earlier can change it and it changes nothing
earlier. Three states read the same two Kaplan-Meier curves at a time the learner
chooses — 1, 5 or 10 years — and one response carries all three, so changing the time
selects a reading R has already computed. The first state reads the two estimates, the
second shows what a downward movement is (the fall between two times and the first
events behind it, then the mechanic that the line holds its level between events and
steps down when one occurs), and the third compares the two estimates at that one time
in percentage points. **No p-value, hazard ratio or median is published**, because the
chapter compares two readings rather than testing them. The downward-movement state
shades the interval it describes on the arm R's sentence names, using the two years and
the level R publishes for it; the chart's new `highlight` prop is optional, so the tab's
own drawing is unchanged. In a standalone lesson the first advance fetches the curves and
stays on the first state, so the learner reads the two estimates before moving on, and
the next two advances walk the remaining states; a reopened lesson reuses the stored
response while its inputs key still matches instead of simulating again. The visible
title names what is
timed and what the event is, a short qualifier says the estimates are simulated and that
other-cause deaths are censored, and the information disclosure carries the hypothetical
reading of a censored estimate, what the 95% band describes, how the two groups were
simulated, and that the curves say nothing about costs, QALYs or the ICER. The chapter
reuses the tab's chart component, and its answer is cached against the key R
composes from every input the simulation reads, so a stored set of curves is reused only
while it describes the same simulation; the price and the score are not in that key
because the curves do not read them.

**Chapter numbering follows the list.** A chapter's heading numeral is its own position in
the contract's chapter list, which is the number the stepper and the "Chapter {step} of
{total}" line already show, so the ninth entry is "Chapter 9" rather than "Chapter 8". The
brief is entry 1 and names itself, and its start control names the chapter it opens
("Start Chapter 2").

**Presentation refinements (implemented).** Three pieces of the interface are now shared
rather than per-screen. The changing lesson text is one callout (`JourneyBeatCallout`): a
compact blue-tinted card with an accent edge and a step indicator, which briefly tints when
the sentence changes and is still under reduced motion; the survival chapter also drives the
chart's optional emphasis from the beat, so the figure and the sentence agree. Each module
heading carries R's method note behind a "How this is calculated" control (`MethodInfo`),
opened in place and drawn from `MODULE_METHOD_NOTES` — the same dictionary the journey
contract republishes — with "How this works" for the non-economic modules and no note on the
HTA summary, whose rules are already a disclosure. Each note is written for a reader who
knows mathematics and nothing about the code, and carries only the blocks that add
something: the question, the relation, the computation in order, the symbols with their
units and scope, how to read the result, the assumptions that matter and — where it adds
something — a breakdown. The general decision rule is the incremental net monetary benefit,
with the ICER-threshold equivalence marked as holding only when extra health is positive.
No function names, files or endpoints, and no model default presented as the reader's own
setting. The mathematics is typeset rather than transcribed: R authors each expression as TeX
in the same string as the prose, one renderer (`MathText`) typesets only the designated pieces
and emits MathML alongside the visual HTML, and `node scripts/check-math.mjs` typesets an
exported note dictionary to catch a malformed equation before it ships. The end of the journey is an overlay
(`JourneyOverlay`): the app's own dialog behaviour, R's two lines and two actions, and a close
control back to the final chart — and it is now the *same box* as every other overlay in the app
(`EcgOverlay`): one ECG perimeter instead of a card border, one interior surface, one opening
sequence (origins, perimeter, then interior and words together, then the looping signal) and one
set of padding, type and spacing rules. The chapter-transition bridge, the menu and welcome
prompts, the PSA confirmation, the Part 2 dialogs, presentation mode and the floating information
popovers all wear it too; short announcements are centred and sized to their content, longer
informational content stays left-aligned, and the loading card keeps its own treatment untouched.
Home now offers the narrative tutorial as "The Journey" and
no longer lists the legacy guided tutorial, whose screen is unchanged and still reachable by
its own address.

**How the tutorial was extended (delivered).** The journey's purpose is now
dual: every chapter must work as a beat in the whole case *and* as a standalone
explainer for its matching dashboard module, so a learner can open one chapter from the
module it explains, read it, and come back. The end of the journey therefore exists to
hand the learner to the analysis app, not to conclude an argument. What follows records
the decisions that produced the delivered pattern; the acceptance record further down
separates what was observed in the running app from what was established by reading the
code.

*Coverage and entry.* Eight of the nine dashboard modules have a chapter in the journey:
base case (`base_case`), sensitivity (`sensitivity`), cost-effectiveness and PSA
(`uncertainty`, one chapter for both panels), value of information (`voi`), budget
impact (`budget`), DHT readiness (`readiness`), value-based price (`price`) and
simulated survival (`survival`). **The HTA Decision Summary has none.**
The `case` brief has no module counterpart and stays journey-only. Three of the eight can
also be opened as standalone lessons — the readiness, budget and survival chapters — because
they are the only ones R publishes a `module` block for; a chapter without one has no
orientation sentence and no return label, so it is never opened on its own and its panel
carries no control. Every chapter is a beat in the whole case.

*The HTA summary is its own module, not a capstone.* The earlier idea of a final
synthesis/recommendation chapter is **retired**: no chapter is required merely to close
the journey, and the HTA summary — if it gets an explainer — is one more module
explainer that the journey may or may not list later.

*Slice 8a — the readiness explainer and the end screen (implemented).* The readiness
panel carries an "Explain this" control that opens the same readiness chapter on its
own, at `/app?journey=1&explain=readiness`, and a "Back to analysis" control that
returns to the readiness tab. In explainer mode the chapter list, the progress line,
the Back into earlier chapters, the restart control and the chapter bridges are all
absent; R's `orientation` sentence and the module's own label take their place. Opening
the lesson requests nothing: the chapter's first advance is what calls the readiness
endpoint, and only a failed request holds the arrow (the error's retry is then the way
forward). The explainer keeps its own answers and cached assessments — the journey's
chapter, stage, answers and cached results are put aside on entry and restored on exit,
so a refresher cannot move the journey's position — and it writes neither the price nor
the score, so the scenario is untouched. The selected dashboard tab moved into the
navigation store for the return, because only that store is read outside the shell; a
direct link with no dashboard behind it therefore returns to the readiness tab rather
than claiming to restore a session. Both dashboard and journey state are singletons
that the explainer never rewrites, so returning finds them as they were left. The
journey's end card renders after the last state of the last chapter the contract
publishes (R's `journey.end`), and only in full-journey mode.

*The other module lessons (implemented for budget and survival).* The same pattern applies
to the remaining covered modules — the entry control on each panel, and the run each lesson
needs started by its own first advance rather than on entry (base case one
`run_eqalb_model()`; sensitivity, uncertainty and price their own analysis; better evidence
the PSA, because it values that simulation's draws). An "Explain this" control is published
only where R also publishes that chapter's `module` block, which today is the budget,
readiness and survival panels: opening any other chapter on its own is supported by the
address and the pattern, but its panel offers no control until that block exists. The eight R
strings that assume a preceding chapter —
"the comparison you explored earlier", "assumptions tested in the previous chapter",
"the price you chose in the first chapter", and the readiness chapter's "the results so
far assume …" — are left as they are: they read correctly in the journey, and each screen
that uses one also carries an orientation sentence before it is opened standalone. Bridge
recaps stay full-journey only, because they are never rendered standalone.

*Data policy for a standalone explainer.* The lesson uses the **journey's own fixed
case**, labelled as a tutorial example in R's orientation line and repeated in the
chapter's disclosure; it never reads or writes a dashboard input or result. An explicit
snapshot — "Use my dashboard settings" — is **deferred** and not implemented.

*Slice 9 — simulated survival (implemented).* A new chapter built from the same pattern:
R's copy, the existing Kaplan-Meier figure, the existing interpretation statuses, and no new
model. Its three beats read one time point, then one downward step, then the two estimates
compared; the chart's interval highlight exists only for the step beat and every other
caller draws exactly as before.

*Slice 10 — HTA Decision Summary (not implemented).* Entered standalone like the others,
if it is done at all. If it is later listed in the journey it is one entry in the chapter
list; the ending works with or without it.

*The end screen (implemented).* One card after the closing sentence, rendered only when
the chapter list has nothing after the chapter on screen, so adding a chapter later
moves it automatically. It carries R's `journey.end` sentence and note, then **Open the
analysis app** (the dashboard as it stands), **Start the journey again** (the journey's
existing reset, which does not touch the dashboard) and **Exit to Home**. It is not a
stepper entry, it never enumerates chapters, it states no verdict, and a standalone
explainer never shows it.

*Approved and settled for this pattern:* the capstone is retired; there is no entry gate
card (the lesson's own first advance starts what it needs); the R-owned per-chapter
`module` block is the only module mapping R publishes, with the dashboard tab id kept as
a small frontend constant; `activeTab` lives in the navigation store; and an entry
control is added only to a module whose chapter publishes a `module` block.

**Acceptance of this scope (frozen).** The tutorial overhaul — the nine chapters, the
standalone explainers, the shared overlay box and the calculation notes — is accepted as
delivered, and no further redesign is planned. The record below separates what was
observed in the running application from what was established by reading the code, so
neither is claimed for the other.

*Observed in the running application.* The stack was verified ready first (two R workers
of two, `model_ready: true`). Against the served `POST /api/hta-summary`, synthetic bodies
only: a dominated option (incremental cost +€5,000, incremental health −0.10 QALYs) at a
2 % probability of cost-effectiveness returns **Red**, the same shape at 90 % returns
**Amber and never Green**, zero incremental health with a real cost difference and no
ICER returns **Amber with the economic domain assessed**, and valid differences without an
ICER return **Green with `base_case: true`** and no `icer` in `missing_inputs`. The served
`rules[0]` and `rule_note` state the net-monetary-benefit rule and no longer contain
"ICER is at or below". The method notes render their typeset mathematics through the real
served path — KaTeX output plus a MathML reading, no raw TeX, no fallback and no page-level
overflow at 1250, 390, 340, 330 or 320 px, with the equation scrolling inside its own box
only where it must; `npm run typecheck`, `npm run lint`, the 47 rule checks, the 33 endpoint
checks, the 97 authored expressions and `npm audit` (0 advisories at `katex@0.18.10`) all
pass. In the journey: the survival chapter's marker sits at the selected
time, its interval shading covers exactly the years R's sentence names, and the comparison
beat marks both curves and prints both estimates; the completion overlay is the shared box
(no border, no radius, four measured ECG perimeter edges, interior revealed, focus on its
primary action); Escape and the close control both dismiss it without reopening it;
**Open analysis workspace** returns to the dashboard with every input it had; **Restart
The Journey** returns the journey to its first chapter and clears its cached curves while
leaving the dashboard's inputs and results untouched. None of those three actions issued an
API request. The overlay's opening sequence was sampled on the shared component (content
`inert` and transparent until the perimeter closes at about 0.8 s, then revealed, then the
primary action takes focus).

*Established by reading the code, not observed at runtime.* One chapter-transition bridge.
Every bridge leads into a chapter whose own calculation must run first, and after the
survival chapter none is available without another simulation, so the bridge was not
exercised in a browser. Its structure is the shared `EcgOverlay` in `centre` variant with
`role="group"` and `aria-labelledby="recap-heading"` — the same box and sequence measured
above — and `leaveRecap()` opens the awaiting chapter when its result is already held, or
shows the app-wide loader while it waits, never issuing a second request for the same
answer. **That bridge remains the one runtime gap in this scope.**

*Known interaction.* The completion overlay opens as soon as the final survival beat is
reached, so the last comparison sentence and its two marked estimates are read after the
overlay is dismissed — closing returns to that chart, which stays interactive. It is the
intended design (the ending does not wait for a further click), and it means the final beat
is never seen without the overlay first.

*Deliberate non-persistence.* Journey position — chapter, beat, answers and cached
results — is session state held in memory and is not restored after a page reload; the Home
control offers "The Journey (resume)" while a journey is in progress and "The Journey" after
a reload. This matches the legacy tutorial, which the reference documentation also describes
as cleared by reload. It is a decision, not an omission.

**What stays in the panel and what opens on demand.** Every chapter keeps the short
teaching caption, the feedback its own action produced, and the labels, units and
assumptions needed to read the figure (the two axes, the price unit, the threshold the
balance is measured against, annual versus running totals, the two utilities the QALY
control holds fixed, the one-line definitions of EVPI and EVPPI on the states that
introduce them, and the note that a score of 1.00 is simulated marginally below 1).
Everything secondary sits in one closed
disclosure per chapter, under its own heading: the readiness chapter's teaching-rule
and certification caveats, its held-fixed values and its limits in "How this check
works" and "Values the chapter holds fixed"; the one-way chapter's method name and both
misreading guards in "What this ranking does and does not show"; the uncertainty
chapter's method name and which assumptions the simulation varied in "Which assumptions
varied"; the value-of-information chapter's EVPI/EVPPI qualifications and scope limits
in "What these figures cover"; the price chapter's balance definition and reference in
"What this comparison covers"; the budget chapter's two payment conventions, horizon and
the affordability question it does not answer in "What this total covers"; and the base
case's "How this score is used", which holds the two sentences describing how the model
weights health states. Each sentence is R's and was moved or rewritten there rather than
composed by the client, no caveat appears both inline and inside a disclosure, and no
state prints a paragraph where a caption belongs.

Two parts of the price chapter were planned and are **deferred, not implemented**:
the required-effect state (the extra effect a given price would need to reach the
case's reference — `eqalb_price_required_rrr()` is internal to
`calculate_value_based_price()` and bisects over several model runs, which would
break the chapter's one-model-run budget), and the 3×3 effect ×
engagement scan. Neither is described as working anywhere in the interface.

A known unit-label inconsistency remains outside the journey. The BIA charges active
users; the Markov model charges everyone in the intervention arm. The price-module
"per active user" wording in `eqalb_price.R` and the `/api/value-based-price`
documentation remains unresolved and must be checked against the calculation that its
solver actually uses. It is left for a separately scoped cleanup rather than changed
here; no calculation was altered.

A later frontend-only pass added two restrained animations, both decoration and
both uncommitted for local review: an analysis result fades in under a one-shot ECG
trace when it is committed — the trace draws itself beneath the panel heading as a
soft teal highlight runs along it, then the whole strip fades away and the heading
is left clean (never on a tab switch, a theme change, an input edit or a failed
request, and again on each new run even when the numbers match) — and tutorial
steps and Part 2 sections cross-fade with a
few pixels of horizontal travel through `components/tutorial/TutorialStepStage.vue`,
which renders one step at a time and moves focus to the arriving step's heading.
`prefers-reduced-motion` removes both. See the private project record for the details and the verification.

A further frontend-only pass, also uncommitted, polished five routine interactions
and added a lighthearted second line under long waits. The analysis tab strip now
carries one sliding teal indicator (`composables/useTabUnderline.ts`) that slides
between tabs on the same row and jumps into place across a wrap, on resize or on a
font change, so it can never be drawn in the wrong place; the existing `<details>`
disclosures animate to the content's real height where the engine supports
`::details-content` with `interpolate-size`, and fall back to an instant open and
close where it does not, with the existing marker becoming a rotating chevron; the
nine run buttons use `components/ButtonLabel.vue`, whose two labels occupy one grid
cell so the button's box and accessible name are exactly one label at a time, with
the pending label stating the operation (and the PSA's iteration count) beside a
small ECG; a prepared export reports once through `components/DownloadNotice.vue`
(a corner card that is never a claim that a file was saved, with failures waiting
to be dismissed); and the four dialogs fade and move a few pixels through
`composables/useDialogTransition.ts`, which also makes the leaving dialog `inert`,
while `composables/useModalFocus.ts` keeps the keyboard inside whichever dialog is
open: focus moved in, Tab and Shift+Tab wrapped, the rest of the page `inert` and
the focus returned to the opener.
The loading line is `composables/useLoadingMessages.ts`: 24 sentences in one list,
one shown after a 1 s grace and a different one every 7 s, each change a 280 ms
opacity-only crossfade, in an area sized by the longest sentence so the card keeps
one height. `prefers-reduced-motion` removes every one of these animations and holds
the loading line still.

The last of these, also released with the same commit, is the page-entry fade: a page
fades in, opacity only over 160 ms, when an internal link or button moves the visitor
to it, on the `.page-entry` wrapper `App.vue` puts around the page content rather than
on the shell (the shell holds the fixed loading indicator, download notice and launch
overlay). `composables/usePageEntrance.ts` decides when it plays — once per entry,
where an entry is the page plus the post's slug, and never on a first paint, on Back
or Forward, during the landing page's crossing into the app, while a dialog is open,
or on a scrolled arrival — and the app's Home screen is listed to skip because it has
its own entrance and pins its theme button to the window corner.

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
| 5 | Guided Tutorial journey as the teaching layer: seven chapters implemented behind `/app?journey=1`, one case and one scenario shared by all of them, the readiness lesson also reachable as a standalone explainer from its dashboard module, and the journey's end card handing over to the analysis app. Remaining: the same standalone entry for the other six covered modules, then a simulated-survival explainer and an HTA-summary explainer. | Accepted and frozen: nine entries (the case brief, the base case, sensitivity, uncertainty, value of information, price, budget, readiness and simulated survival) behind `/app?journey=1`, the shared ECG overlay for the endings and transitions, and the method notes with typeset mathematics. Three chapters are also reachable as standalone lessons from their panel (`?journey=1&explain=budget`, `explain=readiness`, `explain=survival`) — the only three for which R publishes a `module` block, since a lesson the contract has not written is never invented. The HTA Decision Summary has no chapter. See "Acceptance of this scope (frozen)" above for what was observed and the one runtime gap (a chapter-transition bridge). |

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
  from its caption or a `label` prop). Both were frontend-only and are recorded in the private project record.
- The approved UX revamp is being delivered in batches; Batch 1 (global frontend
  foundation) is implemented and recorded in the private project record: viewport-clamped
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
  (base case and PSA) is implemented and recorded in the private project record: the
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
  information) is implemented and recorded in the private project record: OWSA's narrative
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
  and recorded in the private project record: the readiness inputs became a panel-only
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
  followed the final acceptance review, still frontend-only and recorded in the
  private project record: one shared `StaleNotice` sentence marks a stored result as
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
eqalb_tutorial_journey.R  # redesigned tutorial: the fixed case, the chapter list and every chapter's
                       # copy and sentences, the base case (through eqalb_tutorial_ce()), the price
                       # chapter's balance and solve, the budget chapter's coverage sweep (through
                       # calculate_budget_impact()), the value-of-information valuation of the draws the
                       # uncertainty chapter returned, and the readiness chapter's four questions and
                       # assessment (through calculate_readiness())
frontend/
  index.html
  vite.config.ts       # /api proxy to the model API
  src/
    main.ts, App.vue   # shell
    api/client.ts      # typed fetch client
    api/types.ts       # response contracts mirroring the R return shapes
    composables/       # useModel (state), useTutorialSession (isolated tutorial state),
                       # useTutorialJourney (the redesigned tutorial's own isolated state),
                       # useTheme (palette), useEcharts (charts), useAppView (which page is shown, and the
                       # /, /blog, /blog/<slug>, /app and /about addresses with the history entries and document
                       # title), useLandingTheme (the landing page's and the blog's own light/dark choice),
                       # useAppBusy (the app-wide loading state), useResultEntrance and useTabUnderline
                       # (which element a one-shot entrance and the tab strip's indicator are placed on),
                       # useDownloadNotice (the prepared-download notice), useDialogTransition (the dialog
                       # fade and the leaving dialog's inert state), useModalFocus (the dialog's keyboard
                       # containment: focus in, a Tab loop, the page behind it inert, focus returned),
                       # useLoadingMessages (the lighthearted
                       # line under a long wait: the sentence list, the 7 s interval, the crossfade),
                       # usePageEntrance (the page-entry fade: which entries fade and which are shown
                       # immediately)
    components/        # presentation only; charts/ holds the chart options; tutorial/ the four Part 1 steps, Part 2's five sections and the step stage that transitions between them; journey/ the redesigned tutorial's case brief, its seven chapters' figures and the shared spotlight guidance; blog/ the blog's shell and its date formatting; ResultTrace is the trace that passes under a panel heading; ButtonLabel is the two-label run button (idle / pending); DownloadNotice is the prepared-download card; InfoTip is the help control; AppLoadingIndicator is the loading indicator
    views/             # OpenHealth landing (/), the blog (/blog and /blog/<slug>), the eQalb Home screen (/app,
                       # with the Guided tutorial, Project description and Download results subviews) and About
                       # OpenHealth (/about)
    content/blog/      # the blog's posts: one module per post, the registry that publishes them, the content
                       # model, and the format and workflow documentation
    export/            # results package + per-tab exports: ZIP writer, CSV builders
    format.ts          # EUR/QALY formatting; null becomes a dash
    styles.css         # teal palette + light/dark tokens
    landing.css        # the landing page's palette and layout; blog.css the blog's
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
`@types/node` — unchanged by the blog, which adds no dependency: a post is typed
data rendered block by block rather than Markdown, so there is no renderer to add
and no HTML to sanitise.

Python: `fastapi` and `uvicorn` in `api/.venv` (see `api/requirements.txt`). No
Python package computes model output.

R: `plumber` (plus its dependencies) in the project `renv` library — it is needed
for its request parsing and route handlers, which `api/r_worker.R` reuses.
`renv.lock` is intentionally left for a deliberate `renv::snapshot()` by the
project owner.

## 9. Known limitations

- The API is unauthenticated and binds to loopback only (`127.0.0.1` by default),
  so nothing reaches it from the network directly. In the self-hosted setup that
  `deploy/` documents, that is deliberate: Caddy is the only public listener and
  reverse-proxies `/api/*` to the loopback port, so the API has no public origin
  of its own. It is a development and teaching service, not an authenticated
  product API.
- The blog (`/blog` and `/blog/<slug>`) is published with one post — the release of
  eQalb and the introduction of OpenHealth (14 October 2026), the author's own text
  as written. Its posts are typed data in `frontend/src/content/blog/`, rendered
  block by block — no Markdown renderer was added, which would be one dependency
  plus its approval. The landing page's footer links to the blog instead of to
  `/about`, which remains reachable at its address until that is decided.
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
  the production build succeeds. Two R test scripts do exist, and both run with
  synthetic inputs and no model call: `tests/test_hta_summary_rule.R` pins the
  decision rule, and `tests/test_hta_availability.R` drives the real
  `/api/hta-summary` handler to pin its availability block. The method notes'
  mathematics is checked by `frontend/scripts/check-math.mjs`.
- One chapter-transition bridge has **not** been exercised in a running browser.
  A bridge is the recap at a chapter's last state and always leads into a chapter
  whose own calculation must run first; after the survival chapter none is
  reachable without another simulation. Its structure was read in the source and
  is the shared overlay box (`EcgOverlay`, `centre` variant, `role="group"` with
  `aria-labelledby="recap-heading"`), and `leaveRecap()` opens the awaiting chapter
  once its answer is held or shows the app-wide loader while it waits, without
  issuing a second request for the same answer. Everything else in the journey —
  the chapters, the survival chart's marker/shading/comparison beat, the completion
  overlay and its three actions — was verified in the running app.
- The completion overlay opens as soon as the final survival beat is reached, so
  that beat's comparison sentence and its two marked estimates are read after the
  overlay is dismissed (closing returns to the chart, which stays interactive).
  This is the intended behaviour, and it means the last beat is never seen without
  the overlay first.
- Journey position is in-memory session state and is not restored after a page
  reload, by design: the Home control reads "The Journey (resume)" while a journey
  is in progress and "The Journey" otherwise. The legacy tutorial behaves the same
  way and is documented as cleared by reload.
- Every dialog contains its own focus. The four real modals (the welcome question,
  the PSA confirmation, the case facts and the congratulation) move the focus to
  their own first action when they open, wrap Tab and Shift+Tab inside themselves,
  make everything outside them `inert` while they are up — through their relatives,
  never through an ancestor, and restoring each element's prior state — and return
  the focus to the control that opened them, with the welcome question falling back
  to the selected analysis tab (it is asked on arrival, so it has no button to
  return to) and a dialog whose opener is disabled (Continue, which disables the run
  button as it starts the run) leaving the focus where the dialog left it. That is
  `frontend/src/composables/useModalFocus.ts`, wired once per dialog.
- The disclosure expansion is conditional: it animates only where `::details-content`
  and `interpolate-size` are both supported (the engines the app is developed and
  reviewed in), and where they are not, a disclosure opens and closes instantly
  exactly as it did before. Nothing about the contents, their semantics or the tab
  order depends on the animation.
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
