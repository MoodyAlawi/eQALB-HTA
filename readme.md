# eQalb HTA Learning Model

An interactive Shiny application for exploring health technology assessment methods, built around a simplified assessment of a fictional digital health technology called eQalb.

## Overview

This repository contains an interactive Shiny application that works through a simplified health technology assessment (HTA) of eQalb.

eQalb is a fictional prescription digital health technology for adults with uncontrolled hypertension. It is the technology being assessed, not the name of the application. The interactive Shiny application is the learning tool that assesses it, showing how an HTA model is structured, calculated, visualised, and interpreted.

At its core the application runs a two-strategy Markov model that compares eQalb plus usual care with usual care alone. Around that core model it adds views for uncertainty, affordability, clinical outcomes, implementation readiness, and evidence priorities, so the whole assessment can be explored in one place.

Every clinical effect, cost, utility, event risk, survival curve, and economic result comes from simulated data and illustrative assumptions produced by the code in this repository. The project is an educational model, not clinical evidence, a validated HTA, or an official NICE, payer, regulatory, reimbursement, or policy recommendation.

What you can do with it:

- Explore six analysis tabs covering cost effectiveness, uncertainty, affordability, survival, implementation readiness, and decision support.
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

- A landing page offering Start analysis, Project description, and Download results.
- A light and dark mode switch.
- A Download results package button that exports the results already produced in the session, plus per-analysis download buttons inside the tabs.

## How to use the application

1. Open the application. It starts on a title screen with three entry points.
2. Select Start analysis to read the analysis areas, then select Open analysis dashboard.
3. Work through the tabs from left to right. Results are produced when you press the action button for that analysis, so the numbers update on demand instead of on every keystroke.

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

The default assumptions are illustrative starting values, for example an annual intervention price of EUR 360, an implementation cost of EUR 40 per new user, annual healthcare savings of EUR 20 per active user, a 10% relative risk reduction among engaged users, and 70% engagement in year 1 with 42% at follow-up.

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
