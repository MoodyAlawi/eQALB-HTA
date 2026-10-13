# eQalb interface copy shared by the Shiny app and the model API.
#
# Everything in this module is text the interface displays or reads as an
# accessible label: the HTA decision-summary rules and notes, and the
# CC_INFO_TEXT explanations for the analysis inputs. It was moved out of app.R
# verbatim - not one character was rewritten, summarised or reworded - because
# the model API has to publish exactly what Shiny shows, and the alternatives
# were a second copy of the wording or a paraphrase written in TypeScript.
#
# No calculation reads any of it: the strings are presentation and
# documentation only.
#
# Sourced by app.R (Shiny) and by api/plumber.R (the model API).
# Presentation constants for the HTA decision-summary tab.
HTA_SUMMARY_RULE_NOTE <- paste(
  "Educational traffic-light rules: economic value is Green when the",
  "probability of cost-effectiveness is at least 50% and the base-case ICER is",
  "at or below the reference threshold, Red when the probability is below 5%",
  "and the ICER is above it, and Amber otherwise. Decision uncertainty reuses",
  "the value-of-information rule (Red only when the less-preferred option wins",
  "in at least 40% of simulations or EVPI exceeds \u20ac1,000 per patient).",
  "Budget impact is Green at or below \u20ac1m, Amber up to \u20ac10m and Red above.",
  "Clinical evidence maturity is always Red because the evidence is simulated.",
  "Implementation readiness is Amber when any readiness domain is Amber, and",
  "Red when more than a quarter of domains are Red. The overall status is the",
  "least favourable assessed domain. These are presentation rules for this",
  "teaching app, not official NICE or payer criteria."
)

# Note shown below the dynamic evidence-priority table.
HTA_EVIDENCE_NOTE <- paste(
  "Evidence priorities combine current model outputs with clinical,",
  "implementation, equity, and evidence-maturity considerations. They are not",
  "determined by EVPPI alone."
)

# The same traffic-light rules, split into readable paragraphs for the on-demand
# popover on the HTA decision-summary tab. HTA_SUMMARY_RULE_NOTE stays in its
# single-line form because it is written into the exported results package, so
# exports are unchanged.
HTA_RULE_ITEMS <- c(
  paste(
    "Economic value is Green when the probability of cost-effectiveness is at",
    "least 50% and the base-case ICER is at or below the reference threshold,",
    "Red when the probability is below 5% and the ICER is above it, and Amber",
    "otherwise."
  ),
  paste(
    "Decision uncertainty reuses the value-of-information rule: Red only when",
    "the less-preferred option wins in at least 40% of simulations or EVPI",
    "exceeds \u20ac1,000 per patient."
  ),
  "Budget impact is Green at or below \u20ac1m, Amber up to \u20ac10m, and Red above.",
  "Clinical evidence maturity is always Red because the evidence is simulated.",
  paste(
    "Implementation readiness is Amber when any readiness domain is Amber, and",
    "Red when more than a quarter of domains are Red."
  ),
  "The overall status is the least favourable assessed domain.",
  paste(
    "These are presentation rules for this teaching app, not official NICE or",
    "payer criteria."
  )
)

# Accessible label for the traffic-light-rules information control.
HTA_RULES_TRIGGER_LABEL <- paste(
  "Traffic-light rules: show the educational rules used to set each domain",
  "status"
)

# One-way sensitivity-analysis tab. Both lines were moved verbatim out of app.R
# (the paragraph above the summary, and the text the summary shows before the
# analysis has been run) so the browser interface shows the same sentences. The
# narrative that follows them is built by summarize_eqalb_owsa() in eqalb_owsa.R.
OWSA_SUMMARY_NOTE <- "Educational analysis using illustrative parameter ranges."
OWSA_PRERUN_NOTE <- "Set the assumptions and click Run sensitivity analysis."

# Explanations for the small information controls next to the main
# full-analysis inputs. Presentation only: the text is shown in an on-demand
# bslib popover and no calculation reads it.
CC_INFO_TEXT <- list(
  intervention_price = paste(
    "The cost of the digital intervention per user over the modelled period."
  ),
  relative_risk_reduction = paste(
    "The proportional reduction in event risk compared with usual care."
  ),
  year1_engagement = paste(
    "The proportion of eligible users who engage with the intervention during",
    "the first year."
  ),
  followup_engagement = paste(
    "The proportion of users who remain engaged after the first year."
  ),
  utility = paste(
    "A value representing health-related quality of life, used to calculate",
    "QALYs."
  ),
  population_size = paste(
    "The number of people in the eligible population used in the analysis."
  ),
  uptake = "The proportion of eligible people who adopt the intervention.",
  intervention_cost = paste(
    "The cost applied to each person receiving the intervention."
  ),
  review_minutes = paste(
    "The clinician time required to review or support each active user."
  ),
  willingness_to_pay = paste(
    "The maximum amount considered acceptable to pay for one additional QALY."
  ),
  reference_wtp = paste(
    "The amount used to judge whether the intervention is cost-effective for",
    "the main PSA result, expressed as euros per QALY."
  ),
  psa_simulations = paste(
    "The number of simulations used to explore uncertainty in the model",
    "inputs."
  ),
  random_seed = "A fixed number that makes simulation results reproducible.",
  evpi = "The value of completely eliminating uncertainty about the decision.",
  evppi = paste(
    "The value of eliminating uncertainty about selected groups of inputs."
  ),
  psa_mean_cost = paste(
    "The mean incremental cost is the average of total eQalb cost minus total",
    "usual-care cost across the successful PSA simulations. The table splits",
    "that average into its components."
  ),
  psa_mean_qalys = paste(
    "The mean incremental QALYs are the average of total eQalb QALYs minus",
    "total usual-care QALYs across the successful PSA simulations. The table",
    "splits that average into time in each health state."
  ),
  healthcare_savings = paste(
    "Estimated healthcare costs avoided because the intervention reduces",
    "modelled clinical events. This is illustrative and does not represent",
    "observed savings."
  ),
  # Guided-tutorial explanations. These are the texts that used to sit
  # permanently under the step-1 sliders; they are now shown on demand so the
  # tutorial reads as a compact set of controls.
  tutorial_price = paste(
    "This is the extra technology cost. Increasing the annual price usually",
    "increases incremental cost and makes the ICER worse, unless other savings",
    "or health gains offset it. Example: an extra \u20ac100 adds about \u20ac100",
    "per active person-year before avoided event costs."
  ),
  tutorial_rrr = paste(
    "This reduces MI and stroke risk for engaged users. Example: a 10%",
    "reduction changes a 1.5% event risk to about 1.35% for the users receiving",
    "the effect. Fewer events can reduce costs and increase QALYs."
  ),
  tutorial_engagement_year1 = paste(
    "This is the share of users who receive the treatment effect in the first",
    "year. At 70% engagement, about 70 of 100 users receive the risk-reduction",
    "benefit. Higher engagement usually increases QALYs and avoided event",
    "costs."
  ),
  tutorial_engagement_followup = paste(
    "This determines how much of the treatment effect continues in later",
    "years. Higher follow-up engagement usually increases long-term benefits",
    "and avoided event costs."
  ),
  tutorial_utility_no_event = paste(
    "This is the quality-of-life weight for a year without MI or stroke. A",
    "utility of 0.86 means one year in this state contributes 0.86 QALYs.",
    "Changing it can change the incremental QALY difference and therefore the",
    "ICER."
  ),
  tutorial_bia_explain = paste(
    "A technology can be cost effective and still be unaffordable. Costs come",
    "from the price per active user plus a one-off implementation cost for each",
    "new user. Savings come from assumed reductions in healthcare use for",
    "active users. The net budget impact is costs minus savings, added up over",
    "the horizon."
  ),
  tutorial_population = paste(
    "A larger eligible population increases the number of users, so both the",
    "cost and the net budget impact grow."
  ),
  tutorial_readiness_explain = paste(
    "Reach combines the target population with access and digital suitability,",
    "then with engagement. Workflow burden estimates the clinician time the",
    "pathway needs; more review time means more strain on services. The traffic",
    "lights summarise the domains: Red means a barrier to resolve before wide",
    "deployment, Amber means mitigation may be needed, and Green means no",
    "obvious barrier under these assumptions."
  ),
  tutorial_review_minutes = paste(
    "More review minutes per patient means more total clinician hours, which",
    "pushes the workflow domain towards amber or red."
  ),
  tutorial_interop_definition = paste(
    "Interoperability means the intervention can exchange and use information",
    "with other relevant health or digital systems."
  ),
  tutorial_language_definition = paste(
    "Language availability means that users can understand and use the",
    "intervention in the language needed for the target population."
  ),
  part2_price = paste(
    "The negotiated annual price is the case's value-for-money lever. Lowering",
    "it reduces the incremental cost and improves the ICER, and it also reduces",
    "the five-year budget impact, because the same price is charged for every",
    "active user. The manufacturer has proposed a starting price. Your task is",
    "to negotiate a price that offers value for money at the payer's threshold.",
    "The manufacturer's reference price is provided as context, not as the",
    "target answer."
  ),
  part2_coverage = paste(
    "A phased rollout funds eQalb for a capped share of the eligible",
    "population. This lowers the number of users and the total five-year",
    "budget impact, even when the price per user stays the same."
  )
)
