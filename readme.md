# eQalb HTA Learning Model

An interactive Shiny application for exploring health technology assessment methods, built around a simplified assessment of a fictional digital health technology called eQalb.

## Overview

This repository contains an interactive Shiny application that works through a simplified health technology assessment (HTA) of eQalb.

eQalb is a fictional prescription digital health technology for adults with uncontrolled hypertension. It is the technology being assessed, and it also names this application, which was originally called CardioConnect and was renamed to eQalb. The interactive Shiny application is the learning tool that assesses it, showing how an HTA model is structured, calculated, visualised, and interpreted.

At its core the application runs a two-strategy Markov model that compares eQalb plus usual care with usual care alone. Around that core model it adds views for uncertainty, affordability, clinical outcomes, implementation readiness, and evidence priorities, so the whole assessment can be explored in one place.

The reference willingness-to-pay threshold is EUR 100,000 per QALY, and every threshold control in the application defaults to it: the PSA reference threshold, the one-way sensitivity-analysis willingness-to-pay value, the VOI thresholds, the HTA decision-summary rules, and the Part 2 value-for-money test.

Every clinical effect, cost, utility, event risk, survival curve, and economic result comes from simulated data and illustrative assumptions produced by the code in this repository. The project is an educational model, not clinical evidence, a validated HTA, or an official NICE, payer, regulatory, reimbursement, or policy recommendation.

What you can do with it:

- Explore six analysis tabs covering cost effectiveness, uncertainty, affordability, survival, implementation readiness, and decision support.
- Work through the guided tutorial if you are new to health economics.
- Adjust the assumptions and see how each result responds.
- Download every result available in the session as a single ZIP package.
- Switch between a light and a dark colour mode.

## Live demo

Try the hosted version:

https://01a11174-15b8-e5c7-dbb8-5ca8cb298ab0.share.connect.posit.cloud/

## Analyses included

| Tab | What it shows |
|---|---|
| Cost-effectiveness | The shared global assumptions, the base case with incremental cost, incremental QALYs and the ICER, the cost-effectiveness plane, the probabilistic sensitivity analysis with its incremental cost and QALY cloud and the cost-effectiveness acceptability curve (CEAC), and a five-year budget impact analysis with a yearly table and chart. |
| Sensitivity Analysis | A one-way deterministic sensitivity analysis across ten parameters, with a tornado diagram ranked by ICER impact and an incremental net monetary benefit table. |
| Kaplan-Meier Curve | A simulated illustrative patient-level survival simulation with a risk table, optional exploratory engagement curves, event and censoring diagnostics, a log-rank comparison, an arm check, and a traffic-light interpretation panel. |
| DHT Readiness & Implementation | An implementation, equity, and digital readiness assessment: quantitative reach and clinician workload outputs, and a seven-domain traffic-light readiness summary covering equity and access, engagement, workflow burden, language access, accessibility, interoperability, and algorithm governance. |
| Value of information | Expected value of perfect information (EVPI) per patient, a decision-uncertainty traffic light, and regression-based expected value of partial perfect information (EVPPI) per patient for the sampled PSA parameters. |
| HTA decision summary | A five-domain traffic-light dashboard for economic value, decision uncertainty, budget impact, clinical evidence maturity, and implementation readiness, with an overall status, a provisional position, a plain-language interpretation, and an evidence-generation plan in a collapsible panel. |

Supporting functionality:

- A landing page offering Start analysis, Guided tutorial, Project description, and Download results.
- A Guided tutorial: a four step beginner walkthrough of the base cost effectiveness, budget impact, DHT readiness, and the tutorial decision summary, using the same base model as the full analysis.
- An optional Guided tutorial Part 2 commissioning case challenge: three randomly drawn complete cases with a negotiated-price lever, a coverage cap, a DHT readiness exercise, and a recommendation checklist.
- A welcome prompt the first time you open the full analysis from the home page, suggesting the tutorial to newcomers.
- A light and dark mode switch.
- A Download results package button that exports the results already produced in the session, plus per-analysis download buttons inside the tabs.

## How to use the application

1. Open the application. It starts on a title screen with four entry points.
2. New to the topic? Select Guided tutorial. It walks through four steps, lets you change a few assumptions, and explains what each one means.
3. Select Start analysis to read the analysis areas, then select Open analysis dashboard.
4. Work through the tabs from left to right. Results are produced when you press the action button for that analysis, so the numbers update on demand instead of on every keystroke.

| Action button | Produces |
|---|---|
| Run model | The base case and the cost-effectiveness plane. |
| Run probabilistic analysis | The probabilistic sensitivity analysis, the PSA plane, and the CEAC. |
| Run budget impact analysis | The five-year budget impact table, summary, and chart. |
| Run sensitivity analysis | The one-way sensitivity analysis and the tornado diagram. |
| Simulate and update curve | The simulated Kaplan-Meier curve and its diagnostics. |
| Assess readiness | The digital health technology readiness assessment. |

4. Read the Value of information and HTA decision summary tabs last. Both reuse the results of the analyses above rather than recalculating, so they show what is available in the current session and tell you when something has not been run yet.
5. Open the Evidence-generation plan panel in the HTA decision summary when you want the detail behind the priorities.
6. Use the Download results view, or the download buttons inside each tab, to export outcomes. The ZIP package contains a README that lists what was included and what had not been run.
7. Use the switch in the top right corner to change colour mode, and Home to return to the title screen.

The first time you open the full analysis from the home page, a short welcome prompt suggests the tutorial. It appears once per browser session, and you can carry straight on to the full analysis instead.

The guided tutorial uses the same illustrative base model as the full analysis and presents a simplified sequence for learning. It is not a complete HTA and does not represent clinical or reimbursement evidence. It covers four steps in order:

| Step | Topic |
|---|---|
| 1 | Base cost effectiveness, with sliders for the price, the risk reduction among engaged users, year 1 engagement, follow-up engagement, and the utility used for QALYs. |
| 2 | Budget impact, with a slider for the eligible population. The price set in step 1 carries into this analysis. |
| 3 | DHT readiness, with a slider for clinician review minutes plus two yes or no questions on interoperability and language availability. The engagement assumptions come from step 1. |
| 4 | Tutorial decision summary, covering cost effectiveness, budget impact, clinical evidence maturity, and implementation readiness, with a short traffic light rules popover, a compact list of evidence generation priorities, and a Finish tutorial button. |

Finishing the tutorial shows a centred completion note that points to the full analysis and its uncertainty and value of information methods, without running any analysis automatically. From there you can open the full analysis, restart the tutorial, or continue to Guided Tutorial Part 2.

### Guided Tutorial Part 2: commissioning case challenge

Part 2 is an optional continuation, reachable only from the Part 1 completion note. It is a five-section tutorial-only commissioning case and it changes nothing in Part 1 or in the analysis tabs.

Three complete cases are predefined, and the application draws one at random when the session opens. The chosen case stays fixed for the whole run, so changing a control or moving between sections never switches it, and a short banner always names the active case. A Case facts button in the top row opens a read-only overlay of the same facts.

The case has two levers:

- The negotiated annual price (EUR 150 to EUR 360), which changes only this case's per-person result.
- The programme coverage cap (10% to 100% of the potentially eligible population), which changes only the five-year budget impact.

| Section | What the learner does |
|---|---|
| Case brief | Reads the fixed case facts, including the manufacturer's minimum acceptable price of EUR 150 per active user per year. |
| Value for money | Finds the highest annual price that still passes the payer's EUR 100,000/QALY threshold, using the price slider, with an ICER curve across the whole slider range and feedback stating whether the price is below the maximum, at the maximum, or above the threshold. |
| Budget impact | Finds the highest coverage cap that stays within the five-year EUR 3 million budget, with a live status line and a collapsible annual breakdown. |
| DHT readiness | Answers four case-based questions on interoperability, algorithm governance, workflow burden, and follow-up engagement. This is a learning exercise and shows no traffic-light verdicts of its own. |
| Recommendation | Shows the readiness traffic lights for the selected answers, the checklist for value for money, budget impact, readiness and coverage, and the resulting recommendation. |

The "Retry Part 2 with different assumptions" button on the completion card draws a different case, returns the price, the coverage cap, the section, and the four readiness answers to their defaults, and reopens the case brief.

The default assumptions are illustrative starting values, for example an annual intervention price of EUR 360, an implementation cost of EUR 40 per new user, annual healthcare savings of EUR 20 per active user, a 10% relative risk reduction among engaged users, and 70% engagement in year 1 with 42% at follow-up. These are the full-analysis and Part 1 tutorial defaults; Part 2 uses the values of whichever case it drew.

## Technical stack

| Layer | Used here |
|---|---|
| Language | R 4.5.1 |
| Application | shiny, with bslib providing the Bootstrap 5 theme, the light and dark colour modes, and the collapsible and popover components |
| Charts | ggplot2, with scales for axis and number formatting |
| Data handling | dplyr |
| Economic model | heemod for the Markov model, with base R splines for the EVPPI regression |
| Survival module | survival and survminer |
| Interactive charts | plotly, used by the reusable one-way sensitivity helper in eqalb_owsa.R |
| Reproducibility | renv, with a committed renv.lock recording the exact package versions |
| Editor tooling | A VS Code task that launches the application on 127.0.0.1:7788 |

Repository layout:

| File | Purpose |
|---|---|
| app.R | The Shiny user interface and server logic. |
| eqalb_markov.R | The Markov model, the probabilistic sensitivity analysis, the budget impact analysis, and the value of information and HTA decision summary helpers. |
| eqalb_survival.R | The simulated Kaplan-Meier survival module. |
| eqalb_owsa.R | Reusable one-way sensitivity analysis helpers. |
| run_app.R | A small launcher pinned to 127.0.0.1:7788. |
| .vscode/tasks.json | The VS Code task that runs run_app.R. |
| renv.lock, .Rprofile, renv/ | The reproducible package environment. |
| manifest.json | The deployment manifest used by the hosted demo. |
| agents.md | The project rules and conventions followed while developing the application. |
| project_state.md | A short log of verified status, known limitations, and next steps. |

## Running locally

You need R installed. The project was developed and tested with R 4.5.1.

```r
# Restore the exact package versions recorded in renv.lock
renv::restore()

# Start the application
shiny::runApp()
```

Or use the launcher, which pins the address so it is stable:

```sh
Rscript run_app.R
```

In VS Code you can also run the task "eQalb: run app (127.0.0.1:7788)".

Two things worth knowing:

- Keep `shiny::runApp()` out of app.R, so the file stays importable.
- Start the application from the project folder, so `.Rprofile` can activate renv.

## Limitations

- Simulated data throughout. Clinical effects, event risks, survival curves, costs, utilities, engagement rates, and all economic results are simulated or illustrative.
- Illustrative uncertainty. The PSA distributions and their standard deviations are educational assumptions rather than estimates derived from evidence.
- Simplified model structure. Two strategies and four health states (no event, post myocardial infarction, post stroke, and death), with annual cycles over a fixed time horizon.
- Comparator assumptions. Usual care is the comparator and the model works on incremental costs, so routine care costs assumed identical in both arms are omitted. Event-related post-event state costs appear in both arms and differ only through the health state occupancy each arm produces.
- Placeholder cost inputs. The follow-up post-event cost constants are marked in the code as still needing a source.
- Sensitivity analysis scope. The one-way analysis varies one parameter at a time across the ranges you set, so it does not capture interactions between parameters.
- Value of information scope. Population EVPI is not calculated because the application has no research population, decision timeline, or incidence structure. EVPPI is a single-loop regression approximation and can be imprecise when the number of PSA simulations is small.
- Presentation thresholds. The traffic-light bands for decision uncertainty, budget impact, readiness, and the HTA decision summary are teaching rules written for this application, not official HTA or payer criteria.
- Direction of the base case. Under the default assumptions the base case is not cost effective at conventional willingness-to-pay thresholds, and the decision summary reports that cautiously rather than presenting a favourable conclusion.
- Not a formal assessment. The application demonstrates HTA methods for learning. It is not clinical evidence, a validated HTA, or a recommendation of any kind.

## Author

Created by Mahmood Alawi

- LinkedIn: https://www.linkedin.com/in/mahmoodalawi
- GitHub: https://github.com/MoodyAlawi/eQALB-HTA

## Screenshots

Screenshots are not committed to the repository yet. The hosted demo above is the quickest way to see the current interface. Planned captures:

| Screenshot | What it will show |
|---|---|
| Title screen | The landing page and the light and dark mode switch. |
| Cost-effectiveness | The base case, the cost-effectiveness plane, and the CEAC. |
| Sensitivity Analysis | The tornado diagram. |
| Kaplan-Meier Curve | The simulated survival curve with its risk table. |
| DHT Readiness & Implementation | The readiness traffic-light summary. |
| Value of information | The EVPI and EVPPI outputs. |
| HTA decision summary | The decision dashboard and the evidence-generation panel. |
| Exported package | The contents of the downloaded ZIP file. |


## License

This project is licensed under the MIT License. See `License` for details.

## Educational disclaimer

eQalb is an educational simulation using illustrative model inputs and
assumptions. It is not intended for clinical, reimbursement, procurement, or
patient-care decision-making.