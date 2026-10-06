# eQalb Interactive HTA Learning Model

## Live Demo

https://01a11174-15b8-e5c7-dbb8-5ca8cb298ab0.share.connect.posit.cloud/

## Project overview

eQalb is a fictional prescription digital health technology for adults
with uncontrolled hypertension.

This project is an educational R Shiny application designed to demonstrate how
digital health technologies can be evaluated using health technology assessment
(HTA) and health economic methods.

The application explores:

- Clinical and implementation assumptions.
- Costs and quality-adjusted life years (QALYs).
- Incremental cost-effectiveness ratios (ICERs).
- Cost-effectiveness planes.
- Simulated Kaplan–Meier curves.
- Deterministic sensitivity analysis.
- Tornado diagrams.
- Probabilistic sensitivity analysis (PSA).
- Cost-effectiveness acceptability curves (CEACs).
- Budget-impact analysis.
- Digital health technology readiness and implementation factors.

## Important disclaimer

This is a fictional educational model.

The clinical effects, costs, utilities, engagement rates, event risks,
Kaplan–Meier data, PSA distributions, and economic results are illustrative or
simulated unless explicitly stated otherwise.

The outputs must not be interpreted as:

- Real clinical evidence.
- A validated clinical prediction model.
- A real reimbursement submission.
- A regulatory assessment.
- A cybersecurity or data-protection assessment.
- Evidence that eQalb is clinically effective or cost-effective.

The purpose of the project is to learn how HTA models are structured,
calculated, visualised, and interpreted.

## How to run the app

Open R or the R terminal in VS Code and set the working directory to the project
folder.

Then run:

```r
shiny::runApp()
```

Do not place `shiny::runApp()` inside `app.R`.

The application should open in a browser or the configured Shiny viewer.

## Reproducible environment (renv)

The project uses [`renv`](https://rstudio.github.io/renv/) so that the package
versions the model was verified against can be restored exactly on another
machine.

| File or folder | Purpose |
|---|---|
| `.Rprofile` | activates `renv` for this project; contains `source("renv/activate.R")` |
| `renv.lock` | the lockfile: R version 4.5.1 and the exact version of every package used |
| `renv/activate.R` | the activation script written by `renv` |
| `renv/settings.json` | project settings (`snapshot.type` `implicit`, `use.cache` `true`) |
| `renv/library/` | the project library; ignore it, it is rebuilt locally |
| `renv/.gitignore` | keeps `renv/library/` and other local state out of version control |

It was set up with:

```r
install.packages("renv")
renv::init()
renv::snapshot()
```

`renv::init()` discovered the packages the project references from the
`library()` and `pkg::` calls in the R files and linked them into the project
library, so nothing had to be downloaded. `renv::snapshot()` records the current
versions in `renv.lock`. The lockfile is synchronized: `renv::status()` reports
"No issues found -- the project is in a consistent state."

The packages the app needs are `bslib`, `dplyr`, `ggplot2`, `heemod`, `plotly`,
`scales`, `shiny`, `survminer` and `survival`, plus their dependencies and the
base packages that ship with R.

To restore this environment elsewhere, clone the project and run:

```r
renv::restore()
```

`renv` is a development-time tool only. It does not change any model
calculation, and the app behaves identically with or without it.

## Navigation

The app opens on a centred title screen: the large title "eQalb", the
subtitle "Interactive health-technology-assessment model", and three vertically
stacked buttons.

| Button | Shows |
|---|---|
| Start analysis | the list of analysis areas, the "Open analysis dashboard" button and a "Back" button |
| Project description | a short description of the model with a "Back" button |
| Download results | the results-package export panel with a "Back" button |

All three subviews are centred horizontally and vertically using the same
visual language as the title screen, with the content capped at a readable
`46rem` maximum width. Inside each panel the headings, paragraphs and buttons
are centre-aligned; the Start analysis bullet list is centred as a block with
its bullet text kept left-aligned so the bullet lengths stay readable.

"Open analysis dashboard" reveals the existing tabbed interface, which keeps its
six tabs in their existing order. A "Home" button at the top right of the
dashboard returns to the title screen, and the "Back" buttons return from the
three subviews.

The title screen is centred both horizontally and vertically, with a subtle teal
gradient that shifts very slowly and a short fade-in. Both animations are
disabled under the `prefers-reduced-motion: reduce` media query. No external
asset, font or audio is used.

The light/dark mode switch is the only control in the top-right corner; there is
no separate appearance card. It stays available on the title screen, in the
description and export views, and in the dashboard.

All landing views are show/hide toggles over the same containers, not second
copies of the UI: the dashboard and the export button stay in the DOM, so every
input value and output binding is preserved when navigating away and back.
Nothing is recalculated by navigating. A hidden `nav_page` `selectInput` holds the
current view and drives one `conditionalPanel` per view.

## Appearance

The app uses a `bslib` Bootstrap 5 theme (`EQALB_THEME` at the top of
`app.R`) for its visual styling: a light blue-grey page background, a teal
primary accent, a system sans-serif font stack, white rounded cards with subtle
shadows, styled buttons, tables and tabs, and a styled tab bar.

The theme is presentation-only. It does not change the layout structure, any
input or output ID, or any calculation. The green/amber/red traffic-light
colours used by the status cards are inline styles and are therefore unaffected
by the theme.

`bslib` is required for the theme. If it is not installed, the app will not
start; install it with `install.packages("bslib")`.

### Light and dark mode

The app supports a light and a dark colour mode using `bslib`:

- `bslib::input_dark_mode(id = "color_mode", mode = "light")` adds the switch.
  Light mode is the initial default.
- `bslib` sets a `data-bs-theme` attribute on the page, which switches the
  Bootstrap 5 colour variables.
- `EQALB_THEME` adds `[data-bs-theme='dark']` overrides for the pieces
  the existing app styles explicitly: the page background, `wellPanel()` cards,
  tables and their header rows, buttons, the tab bar, muted text and rules.

There is a single switch, placed at the top right of the page above every
landing view and the analysis dashboard, so it is visible in all of them without
duplicating the widget (and therefore without duplicating the input ID). The
`color_mode` input is not read by any server logic; it only drives styling.

Because the traffic-light status cards use inline background and text colours,
they keep the same green/amber/red appearance in both modes so that their
meanings stay identical. Static `ggplot` figures are rendered as images with
light backgrounds and remain readable in dark mode.

## Exports

The "Download results package" button in the landing page's "Download results"
view downloads one ZIP file containing every result that is currently available
in the session. The button is the same `download_results_package` control as
before; only its label and its position on the landing page changed.

The package reuses the results already computed by the other tabs. It never
reruns the model, the PSA, the survival simulation, the budget-impact analysis or
the readiness assessment, and it never changes any analysis. Redrawing a plot
object that is already cached is not a re-analysis.

Files are only included when the corresponding analysis has been run:

| File | Included when |
|---|---|
| `README.txt` | always |
| `model_assumptions.csv` | base case has been run |
| `cost_effectiveness_summary.csv` | base case has been run |
| `cost_effectiveness_plane.png` | base case has been run |
| `psa_summary.csv` | PSA has been run |
| `ceac.png` | PSA has been run |
| `tornado_diagram.png` | sensitivity analysis has been run |
| `budget_impact_results.csv` | budget-impact analysis has been run |
| `budget_impact_plot.png` | budget-impact analysis has been run |
| `km_results.csv` | survival curve has been simulated |
| `km_curve.png` | survival curve has been simulated |
| `dht_readiness_results.csv` | readiness has been assessed |
| `hta_decision_summary.txt` | always |
| `evidence_priorities.csv` | always |

`README.txt` records the app name, the date and time of the export, which
analyses were included, which analyses had not been run yet, the illustrative
nature of every output, the comparator and usual-care cost assumption (see
"Comparator and usual-care cost assumptions") and, when the PSA has been run, the
random seed and simulation counts that produced the exported PSA results. A
missing analysis is documented there rather than causing an error.

The archive is written with base R, using the ZIP store method, because
`utils::zip()` needs an external `zip` program that R does not bundle (it comes
from Rtools or a system package) and the project does not add packages. The
CRC-32 of each entry is read from the trailer of a gzip stream written by
`gzfile()`, which uses the same CRC-32 that ZIP requires. The resulting archive
opens with Windows Explorer, PowerShell `Expand-Archive` and other ZIP tools.

Temporary staging files are removed after the archive is created, so nothing is
left behind on disk. Only result files are included; no code or hidden technical
file is added to the package.

Each analysis also keeps its own download button inside its tab; the ZIP is an
additional consolidated export, not a replacement.

## Project files

```text
app.R
```

Contains the Shiny user interface, input controls, outputs, charts, and server
logic.

```text
eqalb_markov.R
```

Contains the economic model and reusable model functions used by the Shiny app.

```text
AGENTS.md
```

Contains instructions for the coding agent, including project rules,
architecture rules, and development constraints.

```text
PROJECT_STATE.md
```

Contains a short record of the verified project status, completed modules,
known limitations, and next planned task.

Two further source files are loaded by `app.R` rather than listed above:
`eqalb_survival.R` (the simulated Kaplan-Meier module) and `eqalb_owsa.R`
(reusable one-way sensitivity-analysis helpers). `run_app.R` and
`.vscode/tasks.json` launch the app on `127.0.0.1:7788`. The `renv` environment
files (`.Rprofile`, `renv.lock` and the `renv/` folder) are described in
"Reproducible environment (renv)" above.

## eQalb decision problem

The model compares:

```text
eQalb plus usual care
versus
Usual care alone
```

The fictional target population is adults with uncontrolled hypertension.

eQalb includes:

- Bluetooth blood-pressure monitoring.
- Medication reminders.
- Lifestyle coaching.
- Clinician alerts for persistently high readings.
- An algorithm that adapts coaching or reminders according to patient data and
  engagement (not simulated in the economic model; classified only in the DHT
  readiness tab).

## Shared model parameters

The following parameters describe eQalb and may be used across several
analyses.

### Annual intervention price

This is the annual amount paid for each active eQalb user.

Increasing the price usually:

- Increases incremental cost.
- Moves the cost-effectiveness-plane point upward.
- Increases the ICER.
- Increases the payer's budget impact.
- Usually reduces net monetary benefit.

### Implementation cost

This represents one-off costs associated with onboarding, staff training,
workflow integration, or initial deployment.

Increasing implementation cost usually:

- Increases incremental cost.
- Increases the ICER.
- Increases the first-year budget impact.
- Has the greatest budget effect during periods of rapid uptake.

### Healthcare-use savings

This represents estimated savings from reduced or changed healthcare use, such
as fewer GP visits or altered nurse contacts.

Increasing healthcare-use savings usually:

- Reduces incremental cost.
- Improves the ICER.
- Reduces the net budget impact.

These savings should not be treated as real unless supported by appropriate
resource-use evidence.

### Relative risk reduction

Relative risk reduction represents the assumed reduction in cardiovascular
event risk among patients who receive the intervention effect.

If usual-care event risk is `p` and relative risk reduction is `RRR`, then the
risk among patients receiving the intervention effect is:

```text
Intervention risk = p × (1 − RRR)
```

For the intervention cohort as a whole, the model applies an engagement-weighted
effective risk, where `engagement` is year-1 engagement in the first cycle and
follow-up engagement thereafter:

```text
Effective risk = (1 − engagement) × p + engagement × p × (1 − RRR)
```

Increasing relative risk reduction usually:

- Reduces simulated cardiovascular events.
- Increases event-free survival.
- Increases incremental QALYs.
- Improves the ICER.
- Improves net monetary benefit.

### Engagement

Engagement represents the proportion of patients assumed to use the technology
sufficiently to receive its benefit.

The model distinguishes between:

- Year-1 engagement.
- Follow-up engagement.

The economic model applies year-1 engagement in the first cycle only and
follow-up engagement in all later cycles. Budget-impact analysis uses follow-up
engagement only when deriving active users.

Increasing engagement usually:

- Increases the number of patients receiving the intervention benefit.
- Increases QALYs.
- Improves the ICER.
- Increases the number of active users generating programme costs in budget-impact
  analysis, which uses follow-up engagement only.

Engagement is particularly important for digital health technologies because
real-world effectiveness may be lower than efficacy observed among highly
engaged trial participants.

## Cost-effectiveness analysis

The base-case economic model compares costs and QALYs for eQalb plus
usual care against usual care alone.

### Incremental cost

```text
Incremental cost =
Cost of eQalb strategy
− Cost of usual-care strategy
```

A positive incremental cost means eQalb costs more than usual care.

### Incremental QALYs

```text
Incremental QALYs =
QALYs with eQalb
− QALYs with usual care
```

A positive value means eQalb produces more QALYs.

A QALY combines:

- Length of life.
- Quality of life during that time.

### ICER

```text
ICER =
Incremental cost ÷ Incremental QALYs
```

The ICER answers:

> How much additional money is required to gain one additional QALY with
> eQalb compared with usual care?

A lower ICER generally indicates better value, but the ICER must be interpreted
against a relevant willingness-to-pay threshold.

If incremental QALYs are very small, the ICER can become extremely large or
unstable. If the intervention is less effective and more costly, an ordinary
ICER may not be meaningful.

### Comparator and usual-care cost assumptions

Usual care is the comparator, and the model is an incremental comparison:
incremental cost is the total cost of the eQalb strategy minus the total
cost of the usual-care strategy.

Only costs that distinguish the two arms are modelled:

- **Event-related state costs.** The post-MI and post-stroke costs
  (`cost_post_mi_year1`, `cost_post_mi_followup`, `cost_post_stroke_year1`,
  `cost_post_stroke_followup`) are defined for both arms. They reach incremental
  cost only through the different number of events, and therefore the different
  state occupancy, in each arm.
- **eQalb-specific costs.** The annual intervention price in every
  cycle, a one-off implementation cost in the first cycle, and an annual
  healthcare-use saving subtracted in every cycle.

Routine-care costs that would be common to both arms, such as GP visits,
antihypertensive medication, and monitoring, are not modelled. The `NoEvent`
state carries a cost of zero (`cost_no_event <- 0`) in both arms, because a cost
that is identical in both arms cancels in the incremental comparison and cannot
change the ICER. The `Death` state is likewise zero-cost in both arms.

Usual care is therefore not cost-free in this model, but its cost arises only
after an event: while a person remains event-free, both arms accrue zero cost in
the `NoEvent` state. The budget-impact analysis follows the same convention — it
estimates the additional payer spend on the eQalb programme and does not
model a usual-care cost baseline.

This is an educational illustrative assumption. A real HTA should replace it
with empirically sourced comparator costs, including any routine-care costs that
genuinely differ between the two arms.

## Cost-effectiveness plane

The cost-effectiveness plane displays:

- Incremental QALYs on the horizontal axis.
- Incremental costs on the vertical axis.

Usual care is represented at the origin:

```text
(0, 0)
```

eQalb is plotted according to its incremental cost and incremental
QALY result.

### Quadrants

| Quadrant | Interpretation |
|---|---|
| Northeast | More effective and more costly |
| Southeast | More effective and less costly; potentially dominant |
| Northwest | Less effective and more costly; dominated |
| Southwest | Less effective and less costly; requires a value judgement |

The app draws only the zero axes and does not label the quadrants.

In the default base case, eQalb appears in the northeast quadrant: it
costs more and is assumed to produce more health benefit.

The ICER is represented by the slope between the usual-care origin and the
eQalb point.

The deterministic plane displays one selected scenario. It does not display
the full uncertainty around the model result.

## Kaplan–Meier curve

The Kaplan–Meier module displays simulated time to a first major cardiovascular
event.

The simulated primary event is a composite of a first:

- Myocardial infarction.
- Stroke.

The Kaplan–Meier simulation and the economic model treat death differently:

- **Simulated primary event (Kaplan–Meier):** a first myocardial infarction or
  stroke.
- **Competing death and censoring (Kaplan–Meier):** death is not a modelled
  event. A cardiovascular-death incidence input is not available, so other-cause
  death is treated as a competing censoring event that removes people from the
  risk set.
- **Explicit death transitions (economic model):** the Markov model in
  `eqalb_markov.R` includes an explicit `Death` state with separate
  transitions for other-cause death, death after MI, and death after stroke.

The curve shows the probability of remaining free from the event over time.

### How to read the curve

- A higher curve means more people remain event-free.
- A downward step means one or more events occurred.
- A wider separation between curves suggests a larger simulated difference in
  event-free survival.
- Convergence suggests that the treatment effect may be small or may diminish
  over time.

### Risk table

The risk table below the curve shows the number of patients who are:

- Still event-free.
- Still being observed.
- Not yet censored.

It does not show how many patients are still actively using the app.

People leave the risk set because they either:

- Experience the defined event.
- Become censored or leave follow-up.

The number at risk therefore cannot by itself distinguish treatment discontinuation
from cardiovascular events.

### Simulation warning

The current Kaplan–Meier data are simulated. They do not represent observed
patient-level clinical data.

In a real study, a Kaplan–Meier curve would normally be calculated from
individual patient data containing time-to-event and censoring information.

## Deterministic sensitivity analysis

Deterministic sensitivity analysis changes model inputs to explore how the
results respond.

### One-way sensitivity analysis

One parameter is changed at a time while all other inputs remain at their
base-case values.

Examples:

- Lower and higher intervention price.
- Lower and higher relative risk reduction.
- Lower and higher engagement.
- Lower and higher healthcare savings.

The purpose is to identify which assumptions have the greatest effect on the
model result.

### Tornado diagram

The tornado diagram ranks parameters according to how much they change the
selected outcome.

A wide bar means that the parameter has a large influence on the result.

A narrow bar means that the parameter has a smaller influence within the
selected range.

The tornado diagram does not prove that one parameter is clinically more
important. It only shows that the model output is more sensitive to that
parameter under the selected low and high assumptions.

The ranking depends on the ranges chosen.

### Incremental net monetary benefit

The model may use incremental net monetary benefit (INMB) as the tornado
outcome:

```text
INMB =
(Willingness-to-pay threshold × Incremental QALYs)
− Incremental cost
```

Positive INMB means that the intervention is cost-effective at the selected
threshold under that scenario.

INMB is often easier to interpret than an ICER when incremental QALY gains are
very small or when the ICER is unstable.

## Probabilistic sensitivity analysis

Probabilistic sensitivity analysis (PSA) varies several uncertain inputs at the
same time.

For each simulation, the model randomly samples values for parameters such as:

- Relative risk reduction.
- Year-1 engagement.
- Follow-up engagement.
- Utilities.
- Intervention price.
- Implementation cost.
- Healthcare-use savings.

The model then runs repeatedly, producing many possible combinations of:

- Incremental costs.
- Incremental QALYs.
- ICERs.
- Net monetary benefits.

The PSA is reproducible when the same random seed is used.

The seed is set once before the simulation loop. Setting the same seed inside
each simulation would repeatedly generate identical draws and would not be
appropriate for a PSA.

### Current PSA limitation

The current PSA distributions and standard deviations are illustrative unless
they have been linked to empirical evidence.

The results therefore demonstrate PSA mechanics and interpretation rather than
providing a real estimate of decision uncertainty.

### Where the PSA parameter means come from

All nine PSA distributions are centred on their live global inputs in the
Cost-effectiveness tab — intervention price, implementation cost,
healthcare-use savings, relative risk reduction, year-1 and follow-up
engagement, and the three health-state utilities — so changing those controls
and re-running the PSA does change the PSA results. Their uncertainty widths
(standard deviations of €72, €8, €4, 0.03, 0.10, 0.10, 0.03, 0.05 and 0.07) are
fixed and do not scale with the means.

The utilities are entered as three editable base-case inputs in the
"Health-state utilities" section of the Cost-effectiveness tab. That section
also contains a separate "Deterministic sensitivity-analysis ranges" block whose
low and high values are used only by the one-way sensitivity analysis and never
as base-case values.

## PSA cost-effectiveness plane

The PSA cost-effectiveness plane displays one point for each successful PSA
simulation.

It shows how the incremental cost and incremental QALY results vary when
multiple uncertain inputs change together.

Compared with the deterministic plane:

| Deterministic plane | PSA plane |
|---|---|
| One selected scenario | Many simulations |
| One point | Cloud of points |
| No joint uncertainty | Joint parameter uncertainty |
| Shows a central result | Shows the spread of possible results |

The PSA cloud may fall in any quadrant, depending on the sampled values: across
simulations the intervention can appear more or less effective and more or less
costly, with substantial variation in the size of the benefit and cost.

## Cost-effectiveness acceptability curve

The CEAC shows the probability that eQalb is cost-effective at different
willingness-to-pay thresholds.

For every PSA simulation, the model calculates:

```text
INMB =
(WTP threshold × Incremental QALYs)
− Incremental cost
```

A simulation is considered cost-effective when:

```text
INMB > 0
```

The CEAC then shows the proportion of simulations meeting that condition at each
threshold.

A CEAC value of 60% at €100,000 per QALY means:

> Under the model assumptions and illustrative PSA distributions, eQalb
> has positive net monetary benefit in 60% of simulations at that threshold.

It does not mean that:

- The app has a 60% chance of clinically working.
- 60% of patients benefit.
- The treatment effect is 60%.
- Reimbursement should automatically be approved.

## Budget-impact analysis

Budget impact addresses affordability rather than value for money.

It asks:

> How much would the payer spend if eQalb were adopted at a particular
> uptake rate over a defined period?

### Main budget-impact parameters

#### Eligible clinical target population

The maximum number of people who could receive the intervention.

A larger population usually increases total programme costs and savings.

#### Year-1 uptake

The percentage of the eligible population entering the programme during year 1.

A higher value increases early costs and may also increase early savings.

#### Annual uptake increase

The additional percentage-point increase in uptake each year.

A higher value increases later-year adoption and usually increases cumulative
budget impact.

#### Budget-impact horizon

The number of years included in the analysis.

A longer horizon captures more years of costs and savings.

#### Annual intervention price

Budget impact reuses the shared global annual intervention price; the
budget-impact section has no separate price control.

#### Implementation cost per new user

The one-off implementation cost incurred for each new user entering the programme
in a given year. It is taken from the shared global implementation cost.

#### Annual healthcare-use savings per active user

The estimated annual healthcare-use savings accrued for each active user. It is
taken from the shared global healthcare-use savings.

#### Annual avoided-event savings per active user

An illustrative annual saving applied to each active user to represent avoided
event costs. It defaults to €0 and is not linked to the event costs used in the
economic model.

### Budget-impact user counts

For each year, the model derives:

```text
Uptake percentage = min(100, year-1 uptake + (year − 1) × annual uptake increase)
Cumulative users  = eligible target population × uptake percentage ÷ 100
New users         = cumulative users − cumulative users in the previous year
                    (zero in year 1)
Active users      = cumulative users × follow-up engagement ÷ 100
```

Uptake is capped at 100%, so cumulative users cannot exceed the eligible target
population.

### Budget-impact formulas

```text
Gross intervention cost = active users × annual intervention price

Implementation cost     = new users × implementation cost per new user

Healthcare-use savings  = active users × annual healthcare-use savings per active user

Avoided-event savings   = active users × annual avoided-event savings per active user

Net budget impact       = gross intervention cost
                        + implementation cost
                        − healthcare-use savings
                        − avoided-event savings
```

Annual budget impact is the net budget impact for a single year. Cumulative
budget impact is the running total from year 1 through the selected horizon:

```text
Cumulative budget impact (year n) =
sum of net budget impact from year 1 to year n
```

## HTA decision summary

The HTA decision summary is the last tab in the app. It collects the outputs of
the other tabs into an educational traffic-light dashboard and an
evidence-generation plan. It does not recalculate anything: every value is read
from the base-case, PSA, value-of-information, budget-impact and DHT readiness
results already computed in the other tabs, and no analysis is rerun.

### Dashboard domains

| Domain | Rule |
|---|---|
| Economic value | Green when the probability of cost-effectiveness is at least 50% *and* the base-case ICER is at or below the reference threshold; Red when the probability is below 5% *and* the ICER is above it; Amber otherwise |
| Decision uncertainty | Reuses the value-of-information rule (Red only when the less-preferred option wins in at least 40% of simulations, or EVPI exceeds €1,000 per patient) |
| Budget impact | Green at or below €1m cumulative net budget impact over the horizon; Amber up to €10m; Red above |
| Clinical evidence maturity | Always Red, because the clinical outcome evidence is simulated illustrative data |
| Implementation readiness | Green when every readiness domain is Green; Amber when any domain is Amber; Red when more than a quarter of the domains are Red |

The overall status is the least favourable assessed domain.

### Provisional HTA position

| Position | Rule |
|---|---|
| Potentially favourable | Economic value Green and decision uncertainty not Red |
| Not favourable under current assumptions | Economic value Red and decision uncertainty Green |
| Further evidence required | Decision uncertainty Red |
| Conditional adoption with evidence generation | Any other assessed combination |
| Not yet assessable | The economic value or decision-uncertainty domain has not been computed yet |

These categories are educational and illustrative. They are not official NICE or
payer criteria, and they are not a reimbursement recommendation.

### Evidence-generation plan

The tab also shows a dynamic evidence-priority table with eight columns:
evidence gap, current model signal, current status, why it matters, evidence
needed, suggested study or data source, priority, and dashboard domain affected.

Nine gaps are listed: relative risk reduction, year-1 and follow-up engagement,
long-term durability of benefit, MI and stroke outcomes, healthcare-use savings,
intervention and implementation costs, workflow burden and staff time, digital
access and equity, and interoperability and implementation feasibility.

The **current model signal** and **current status** columns are filled from the
outputs already computed in the session (ICER, probability cost-effective, EVPI,
EVPPI, the five-year cumulative net budget impact and its components, the live
global assumptions, and the DHT readiness domains). Where the relevant analysis
has not been run, the row shows "Not yet available" rather than an invented
value.

Two rows are exceptions before the PSA has been run. Relative risk reduction and
engagement are the two gaps on which every other result depends, so they keep a
High priority with the status "Not yet quantified" and the dashboard domain
"Clinical evidence maturity / decision uncertainty": the relative-risk-reduction
signal reads "PSA not yet run", and the engagement signal shows the live
engagement assumptions. Once the PSA has been run both rows revert to their
computed signal, status, priority and domain.

**Priority** is not determined by EVPPI. Each gap is mapped to the dashboard
domains it drives, and the priority is taken from the least favourable of those
domains:

```text
High   = the gap drives a Red dashboard domain
Medium = the gap drives an Amber dashboard domain
Low    = the gap drives only Green domains
Not yet available = the driving output has not been computed in this session
```

A short sentence above the table names the gaps currently rated High. Because
clinical evidence maturity is always Red, the clinical outcome and durability
gaps are always rated High regardless of the economic results, and the equity,
workflow and interoperability gaps are rated from the DHT readiness domains
rather than from the PSA.

## Value of information

The Value of information tab is the last tab in the app. It reuses the PSA
simulations already computed in the Cost-effectiveness tab and does not rerun
the PSA. All results are per patient and are reported at the reference
willingness-to-pay threshold entered in the PSA controls.

### Parameters used

There are no new inputs. The tab uses:

- the reference willingness-to-pay threshold (`psa_reference_wtp`);
- the PSA simulations stored by the Cost-effectiveness tab;
- the sampled parameter draws returned with each PSA simulation.

The parameter means and distributions are the ones defined by the PSA model
(`psa_parameter_table()`). The intervention price is centred on the live global
price; the other parameters are built from model constants and may differ from
the live base-case sliders used in the Cost-effectiveness tab.

### Expected value of perfect information

Expected value of perfect information (EVPI) is the expected gain from removing
uncertainty in every parameter at once. Usual care has an incremental net
monetary benefit of zero, so:

```text
NMB_i                = reference WTP x incremental QALYs_i - incremental cost_i
Expected NMB (perfect information) = mean(max(NMB_i, 0))
Expected NMB (current decision)    = max(mean(NMB_i), 0)
EVPI per patient     = mean(max(NMB_i, 0)) - max(mean(NMB_i), 0)
```

The tab also reports the reference threshold, the number of PSA simulations
used, the mean incremental cost, the mean incremental QALYs, the mean
incremental net monetary benefit, the current preferred decision, and the
probability that eQalb is cost-effective.

### Decision-uncertainty traffic light

A compact traffic-light card summarises how uncertain the current decision is.
The status is derived dynamically from the EVPI per patient and the probability
that eQalb is cost-effective, using these educational rules:

```text
p_loser      = min(probability cost-effective, 1 - probability cost-effective)
EVPI bands   = negligible <= EUR 1 < modest <= EUR 100 < moderate <= EUR 1,000 < material

Red   = high decision uncertainty
        p_loser >= 40%, or EVPI per patient is material
Amber = low-to-moderate decision uncertainty
        p_loser >= 1%, or EVPI per patient is above negligible
Green = low decision uncertainty
        p_loser < 1% and EVPI per patient is negligible
```

`p_loser` is the share of simulations in which the less-preferred option wins,
so it is largest when the decision is close to a coin flip. The card also shows
a short plain-language explanation, a "What this means" box, the PSA-assumptions
note, and the illustrative-analysis warning. The EVPI bands and the
traffic-light thresholds are presentation rules for this teaching app, not
official HTA or research-priority thresholds.

### Expected value of partial perfect information

Expected value of partial perfect information (EVPPI) is the expected gain from
removing uncertainty in one parameter while all other parameters stay uncertain.
It is approximated with a single loop over the stored PSA simulations:

```text
EVPPI (parameter k) =
mean(max(E[NMB | parameter k], 0)) - max(mean(NMB), 0)
```

`E[NMB | parameter k]` is estimated by a natural cubic spline regression of the
simulated net monetary benefit on the sampled values of that parameter. This is
a regression-based approximation, not a nested Monte Carlo estimate.

EVPPI is reported for each of the nine sampled parameters: relative risk
reduction, year-1 engagement, follow-up engagement, the three utilities, the
annual intervention price, the implementation cost, and the annual
healthcare-use savings. Only parameters that are actually present in the
returned PSA draws are included, and EVPPI is shown only when at least 100
successful simulations are available. A bar chart shows EVPPI by parameter with
the EVPI as a dashed reference line.

### Value-of-information limitations

- EVPI and EVPPI are per patient. Population EVPI is not calculated because the
  app has no defined research population, decision timeline, or
  population-incidence structure.
- EVPI and EVPPI are not research budgets. They do not account for the cost,
  feasibility, or timeliness of collecting further evidence.
- The EVPPI spline approximation can be imprecise when the number of PSA
  simulations is small.
- At low willingness-to-pay thresholds every EVPPI can be approximately zero
  because no single parameter is expected to change the preferred decision on
  its own.
- Values are not silently clipped. A negative value is set to zero only when it
  is within a documented numerical tolerance of `1e-6`; anything larger is shown
  unchanged so that an implementation error stays visible.
- Simulated illustrative analysis — not clinical evidence.