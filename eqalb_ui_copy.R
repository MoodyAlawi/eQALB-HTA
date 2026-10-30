# eQalb interface copy shared by the Shiny app and the model API.
#
# Everything in this module is text the interface displays or reads as an
# accessible label: the HTA decision-summary rules and notes, the module method
# notes, and the CC_INFO_TEXT explanations for the analysis inputs. It was moved
# out of app.R because the model API has to publish exactly what Shiny shows,
# and the alternatives were a second copy of the wording or a paraphrase written
# in TypeScript. The HTA rule note and the method notes have since been rewritten
# here, in the one place both interfaces read, so the wording and the rule it
# describes cannot part company; the CC_INFO_TEXT explanations remain verbatim.
#
# No calculation reads any of the explanatory strings: they are presentation and
# documentation only.
#
# Sourced by app.R (Shiny) and by api/plumber.R (the model API).
# Presentation constants for the HTA decision-summary tab.
HTA_SUMMARY_RULE_NOTE <- paste(
  "Educational traffic-light rules: economic value is Green when the",
  "probability of cost-effectiveness is at least 50% and eQalb's incremental",
  "net monetary benefit at the reference threshold is positive (threshold times",
  "extra QALYs, minus extra cost), Red when the probability is below 5% and that",
  "net benefit is negative, and Amber otherwise, including when it is exactly",
  "zero. A negative ICER never decides on its own: it arises both when eQalb",
  "costs less and adds health and when it costs more and adds none, and the",
  "net benefit separates those cases. Decision uncertainty reuses",
  "the value-of-information rule (Red only when the option that wins less",
  "often still wins in at least 40% of simulations or EVPI exceeds \u20ac1,000",
  "per patient).",
  "Budget impact is Green at or below \u20ac1m, Amber up to \u20ac10m and Red above.",
  "Clinical evidence maturity is always Red because the evidence is simulated.",
  "Implementation readiness is Green only when every readiness domain is",
  "Green, Red when more than a quarter of domains are Red, and Amber",
  "otherwise. The overall status is the",
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
    "least 50% and eQalb's incremental net monetary benefit at the reference",
    "threshold is positive, Red when the probability is below 5% and that net",
    "benefit is negative, and Amber otherwise, including when it is exactly",
    "zero. The net monetary benefit is the threshold multiplied by the extra",
    "QALYs, minus the extra cost, so its sign is right whether eQalb costs more",
    "or less and whether it adds health or not. A negative ICER never decides on",
    "its own: it appears both when eQalb costs less and adds health and when it",
    "costs more and adds none."
  ),
  paste(
    "Decision uncertainty reuses the value-of-information rule: Red only when",
    "the option that wins less often still wins in at least 40% of simulations",
    "or EVPI exceeds \u20ac1,000 per patient."
  ),
  "Budget impact is Green at or below \u20ac1m, Amber up to \u20ac10m, and Red above.",
  "Clinical evidence maturity is always Red because the evidence is simulated.",
  paste(
    "Implementation readiness is Green only when every readiness domain is",
    "Green, Red when more than a quarter of domains are Red, and Amber",
    "otherwise."
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
    "The annual price per person. In the cost-effectiveness model, it is",
    "charged for every treated person alive; in budget impact, it is charged",
    "only for active users."
  ),
  relative_risk_reduction = paste(
    "The proportional reduction in heart-attack and stroke risk for engaged",
    "users, compared with usual care."
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
  uptake = paste(
    "The share of the covered population (eligible people × coverage)",
    "enrolled by each year."
  ),
  intervention_cost = paste(
    "A one-off cost for each new user, charged in their first year only."
  ),
  review_minutes = paste(
    "The clinician time required to review or support each active user."
  ),
  willingness_to_pay = paste(
    "The maximum amount considered acceptable to pay for one additional QALY."
  ),
  reference_wtp = paste(
    "The amount the payer is assumed to be willing to pay for one extra QALY,",
    "in euros."
  ),
  psa_simulations = paste(
    "The number of simulations used to explore uncertainty in the model",
    "inputs."
  ),
  random_seed = "A fixed number that makes simulation results reproducible.",
  evpi = paste(
    "The most it could be worth, per patient, to remove all uncertainty about",
    "the decision at this threshold."
  ),
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
    "An assumed annual saving in other healthcare use, separate from the",
    "savings from fewer heart attacks and strokes, which the model calculates",
    "itself. This is illustrative and does not represent observed savings."
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

# --- How a module is calculated --------------------------------------------
#
# One on-demand method note per analysis module, for the "How this is calculated"
# control beside a module's own section title. Presentation and documentation
# only: no calculation reads any of it.
#
# The audience is a reader who is comfortable with mathematics but knows nothing
# about R, this repository or the way the app is wired. So a note states the
# question the module answers, the formula or the steps that answer it, what each
# symbol means (with its unit and its scope), and how to read the result. It
# names no function, file, endpoint or internal check, and it never presents a
# model default as though it were the reader's current input: a default is only
# ever described as a value the model falls back to.
#
# The mathematics is the model's own — the ten annual cycles, the four states and
# their transitions, the 3% discounting, the price-only slope the break-even
# price is solved from, the budget's two savings terms and undiscounted horizon,
# the seven readiness rules, and the Kaplan-Meier product — so a note cannot
# drift into a second, textbook calculation the app does not perform.
#
# Shape of one note. Every field but `label`, `summary` and `steps` is optional,
# and a note carries only the blocks that add something the others do not: the
# lead sentence already says what question the module answers, so there is no
# separate question field to repeat it, and a breakdown table appears only where
# the result is genuinely assembled from parts that the steps do not already name.
#   label             the control's own words
#   summary           the lead: the question the module answers, in one or two sentences
#   formula           the one relation worth seeing, where there is one
#   steps             the computation, in order
#   definitions       symbol -> meaning, with units and scope; only symbols not
#                     already defined where they are introduced
#   interpretation    how to read the number, including the decision rule
#   assumptions       only those that change how the result reads
#   table             a compact breakdown, where it adds distinct information
#
# `label` is "How this is calculated" where the module computes an economic
# result and "How this works" where it does not (a checklist, a simulation).
MODULE_METHOD_NOTES <- list(
  base_case = list(
    label = "How this is calculated",
    summary = paste(
      "Does eQalb buy enough extra health to justify its extra cost — and at what",
      "price per extra QALY? Both options are followed year by year for one person,",
      "and the difference in cost is set against the difference in health."
    ),
    formula = paste0(
      "\\begin{aligned}\n",
      "\\mathrm{ICER} &= \\frac{\\Delta C}{\\Delta E} \\\\[2pt]\n",
      "&= \\frac{C_{\\mathrm{eQalb}} - C_{\\mathrm{usual}}}",
      "{E_{\\mathrm{eQalb}} - E_{\\mathrm{usual}}}\n",
      "\\end{aligned}"
    ),
    steps = c(
      paste(
        "A cohort starts with no prior cardiovascular event and moves between four",
        "states — no event, after a heart attack, after a stroke, death — one year at",
        "a time, for the horizon in force."
      ),
      paste(
        "Each year, everyone in the no-event state faces an annual heart-attack risk,",
        "a stroke risk and an other-cause death risk; after a heart attack 5% die each",
        "year, and after a stroke 6%."
      ),
      paste0(
        "In the eQalb arm only the engaged share gets the lower risk: ",
        "$p_{\\mathrm{eff}} = (1-\\varepsilon)\\,p + \\varepsilon\\,p\\,(1-\\rho)$, ",
        "where $\\varepsilon$ is the engaged share, $\\rho$ the relative risk ",
        "reduction and $p$ the usual-care risk of that event."
      ),
      paste(
        "A treated person's year costs the cost of their state (higher in the first",
        "year after an event, lower afterwards) plus the annual price, plus the one-off",
        "implementation cost in the first year only, minus the annual healthcare-use",
        "saving."
      ),
      paste(
        "A year of health is one year in that state times its utility."
      ),
      paste0(
        "Costs and QALYs are each discounted at the rate in force and summed over ",
        "the horizon, per person. The first year is not discounted; the amount in ",
        "year $t$ is divided by $(1+r)^{t-1}$, so at 3% year 2 counts about 0.971 ",
        "of its value and year 3 about 0.943."
      )
    ),
    definitions = list(
      list(symbol = "$\\Delta C$", meaning = "Extra cost of eQalb over usual care, euros per person over the horizon."),
      list(symbol = "$\\Delta E$", meaning = "Extra health, QALYs per person over the horizon."),
      list(symbol = "$r$", meaning = "Discount rate per year; costs and health may use different rates."),
      list(symbol = "$\\lambda$", meaning = "Willingness-to-pay threshold, euros per QALY.")
    ),
    interpretation = paste0(
      "$\\Delta C$ is what eQalb costs on top of usual care and $\\Delta E$ the ",
      "health it adds, both per person. The decision rule is the incremental net ",
      "monetary benefit, $\\mathrm{INMB} = \\lambda\\,\\Delta E - \\Delta C$: ",
      "positive favours eQalb, negative favours usual care, and zero means the two ",
      "give the same net benefit. How to read the ICER depends on the sign of ",
      "$\\Delta E$. If eQalb adds health at extra cost, the ICER is the price of each ",
      "extra QALY, and an ICER at or below $\\lambda$ means $\\mathrm{INMB} \\ge 0$. ",
      "If it adds health and also saves money, it dominates usual care: the ICER is ",
      "negative for a good reason. A negative ICER also arises when eQalb costs more ",
      "and adds less health, so a negative ICER alone says nothing. If eQalb gives ",
      "less health at a lower cost, the 'below the threshold' reading is reversed: ",
      "it is favoured only if the saving per QALY lost is above $\\lambda$. If ",
      "$\\Delta E$ is zero there is no ICER, and the cost difference alone decides."
    ),
    assumptions = c(
      "Per person over the horizon, health-payer perspective, in 2025 euros.",
      paste(
        "The horizon, the two discount rates, the utilities and every price and cost",
        "are assumptions rather than fixed facts: the model starts from ten years, 3%",
        "and utilities of 0.86 / 0.80 / 0.60, and the method holds whichever values are",
        "in force."
      ),
      paste(
        "The annual price is charged in every year a treated person is alive in a",
        "living state, not only until a first event. The risk reduction applies to",
        "heart attacks and strokes; the other-cause death risk is unchanged."
      )
    )
  ),
  sensitivity = list(
    label = "How this is calculated",
    summary = paste(
      "Which single assumption could change the answer most? Each one is moved on",
      "its own, and the whole comparison is re-run at both ends of its range."
    ),
    formula = paste0(
      "\\begin{aligned}\n",
      "\\mathrm{swing} &= \\max\\{\\Delta(\\theta_{\\mathrm{low}}),\\,",
      "\\Delta(\\theta_{\\mathrm{high}})\\} \\\\\n",
      "&\\quad - \\min\\{\\Delta(\\theta_{\\mathrm{low}}),\\,",
      "\\Delta(\\theta_{\\mathrm{high}})\\}\n",
      "\\end{aligned}"
    ),
    steps = c(
      "Fourteen assumptions are tested, one at a time, with every other assumption held at the scenario in force.",
      "Each is run twice, at its low and at its high value, and the results at the two ends are recorded.",
      "An assumption's swing is the gap between those two results: the larger minus the smaller.",
      "Assumptions are ranked by their swing in extra cost and, separately, by their swing in extra QALYs. The two rankings are never merged into one score.",
      "Each range is built around the value in force, not taken from a textbook.",
      "Each discount rate is tested at two policy values: no discounting, and twice the current rate.",
      "The horizon is tested at the nearest distinct whole-year horizons.",
      "Every other assumption moves by a fixed offset from its current value: for example, the annual price moves by ±€180 and stays inside €0–€2,000, and the risk reduction moves by ±0.05."
    ),
    definitions = list(
      list(symbol = "$\\Delta(\\theta)$", meaning = "The result at one tested value $\\theta$: extra cost in euros per person, or extra QALYs per person."),
      list(symbol = "$\\mathrm{swing}$", meaning = "How far the result travels across one assumption's range, in the result's own units.")
    ),
    interpretation = paste(
      "A long bar marks an assumption that can move the result a lot within its",
      "range; a short bar marks one the result barely notices. Bar length says how far",
      "the answer moves, never how likely either end is: an illustrative scenario, not",
      "a confidence interval."
    ),
    assumptions = c(
      "One assumption moves at a time, so combinations of assumptions are not tested."
    )
  ),
  uncertainty = list(
    label = "How this is calculated",
    summary = paste(
      "With all the uncertain assumptions varying together, how often is eQalb the",
      "better buy? Each iteration draws all nine at once and re-runs the whole",
      "comparison, so the answer is a distribution rather than a single number."
    ),
    formula = paste0(
      "\\begin{aligned}\n",
      "\\mathrm{INMB}_i &= \\lambda\\,\\Delta E_i - \\Delta C_i \\\\[2pt]\n",
      "P(\\text{cost-effective}) &= ",
      "\\frac{\\#\\{\\,i : \\mathrm{INMB}_i > 0\\,\\}}{N}\n",
      "\\end{aligned}"
    ),
    steps = c(
      paste(
        "Nine inputs are uncertain: six bounded fractions (the risk reduction, the two",
        "engagement shares and the three utilities), drawn from beta distributions,",
        "and three non-negative money values (price, implementation cost and savings),",
        "drawn from gamma distributions."
      ),
      paste(
        "Each distribution is centred on the scenario in force and given a spread;",
        "drawing all nine values together is one iteration."
      ),
      paste(
        "Each iteration is a complete run of both options over the horizon in force,",
        "and keeps its own extra cost and extra QALYs — those points are the cloud on",
        "the plane."
      ),
      paste(
        "The summary is the average of the draws, and the ICER is summarised as the",
        "median of the draws that add health, since a mean of ratios is unstable."
      ),
      "Working out the probability of cost-effectiveness at every willingness-to-pay value gives the acceptability curve.",
      "A fixed random seed makes the whole run reproducible: the same seed and the same number of draws give the same figures."
    ),
    definitions = list(
      list(symbol = "$N$", meaning = "Number of iterations (the simulation count)."),
      list(symbol = "$\\Delta C_i,\\ \\Delta E_i$", meaning = "Extra cost (euros per person) and extra QALYs (per person) in iteration $i$."),
      list(symbol = "$\\mathrm{INMB}_i$", meaning = "Net monetary benefit in iteration $i$, in euros per person; positive means eQalb is the better buy in that draw."),
      list(symbol = "$\\lambda$", meaning = "Willingness-to-pay threshold, euros per QALY.")
    ),
    interpretation = paste(
      "For example, a probability of 0.39 would mean that 39% of the draws came out",
      "cost-effective. It reflects the uncertainty put into the model, not the",
      "probability that the decision is correct. A wide cloud means the answer depends heavily on which values are",
      "true; a cloud sitting mostly on one side of the threshold line means the",
      "decision is fairly robust to the uncertainty described."
    ),
    assumptions = c(
      "The nine inputs are drawn independently, so correlations between them are not represented.",
      "The spread describes uncertainty about the assumptions, not sampling error from a trial.",
      "The distributions, their means and their spreads are illustrative teaching assumptions."
    )
  ),
  voi = list(
    label = "How this is calculated",
    summary = paste(
      "What would it be worth to know the uncertain assumptions exactly — and which",
      "assumptions carry that value? Both are read from the draws the uncertainty",
      "analysis already made; nothing new is simulated."
    ),
    formula = paste0(
      "\\begin{aligned}\n",
      "\\mathrm{EVPI} &= \\mathbb{E}\\big[\\max(\\mathrm{NMB}, 0)\\big] \\\\\n",
      "&\\quad - \\max\\big(\\mathbb{E}[\\mathrm{NMB}], 0\\big)\n",
      "\\end{aligned}"
    ),
    steps = c(
      paste0(
        "Each iteration has a net monetary benefit ",
        "$\\mathrm{NMB} = \\lambda\\,\\Delta E - \\Delta C$; usual care has ",
        "$\\mathrm{NMB} = 0$ by construction."
      ),
      paste(
        "With today's information the choice is fixed in advance, so its value is the",
        "larger of the average NMB and zero: a technology that is worse on average is",
        "simply not adopted."
      ),
      paste0(
        "With perfect information the better option would be chosen in each iteration, ",
        "so the value then is the average of $\\max(\\mathrm{NMB}, 0)$ across iterations."
      ),
      "The difference between those two values is the expected value of perfect information, per person.",
      paste(
        "EVPI is about removing all uncertainty at once. The expected value of",
        "partial perfect information (EVPPI) asks a narrower question: what would",
        "it be worth to learn one assumption (or one group of assumptions)",
        "exactly, while everything else stays uncertain?"
      ),
      paste(
        "To estimate it, a smooth curve is fitted through the existing draws that",
        "predicts net monetary benefit from that assumption's value (or the",
        "group's values) alone. The curve stands in for what we would expect once",
        "those values are known, and",
        "the same calculation as for EVPI is applied to it."
      )
    ),
    definitions = list(
      list(symbol = "$\\mathrm{NMB}$", meaning = "$\\lambda\\,\\Delta E - \\Delta C$, in euros per person."),
      list(symbol = "$\\max(\\mathrm{NMB}, 0)$", meaning = "Keeping the better of eQalb and usual care in each iteration."),
      list(symbol = "$\\mathrm{EVPI}$", meaning = "Expected value of perfect information: the most that resolving every uncertain assumption could be worth, euros per person."),
      list(symbol = "$\\mathrm{EVPPI}$", meaning = "Expected value of partial perfect information: the value of learning one assumption or group of assumptions exactly while the others stay uncertain, euros per person."),
      list(symbol = "$\\lambda$", meaning = "Willingness-to-pay threshold, euros per QALY.")
    ),
    interpretation = paste(
      "EVPI is an upper bound on what further research could be worth, per person:",
      "it is what perfect knowledge would buy, not what a study would cost. An",
      "assumption with a large EVPPI is where better evidence would change decisions",
      "most. Group values can overlap, so they need not add up to the total."
    ),
    assumptions = c(
      "All values are per person, before any population size is applied.",
      "EVPPI is estimated from the existing draws with a statistical shortcut (a regression) rather than a second, nested simulation, so it is an approximation."
    )
  ),
  price = list(
    label = "How this is calculated",
    summary = paste(
      "What is the highest annual price at which eQalb still pays for itself at the",
      "willingness-to-pay threshold? The price is solved for the value at which net",
      "monetary benefit is exactly zero."
    ),
    formula = paste0(
      "\\begin{aligned}\n",
      "\\lambda\\,\\Delta E(p) - \\Delta C(p) &= 0 \\\\[2pt]\n",
      "p^{*} &= \\frac{\\lambda\\,\\Delta E - c_0}{s}\n",
      "\\end{aligned}"
    ),
    steps = c(
      "The comparison is run once at the price in force, giving extra cost, extra QALYs and net monetary benefit.",
      paste(
        "It is run a second time at a slightly higher price. Health does not depend on",
        "the price, so extra cost rises in a straight line, and the two runs give that",
        "line's slope and its value at a price of zero."
      ),
      "Setting net monetary benefit to zero and solving that line gives the break-even price $p^{*}$.",
      paste0(
        "The solved price is then checked against a fresh run at $p^{*}$. If net ",
        "monetary benefit there is not zero, a search that makes no shape assumption ",
        "replaces the solved value."
      ),
      paste(
        "If the line never reaches zero at a positive price, no price is supported and",
        "the module says so. Solving the same equation for the risk reduction instead",
        "gives the effect the current price would need."
      )
    ),
    definitions = list(
      list(symbol = "$p$", meaning = "Annual price per treated person, euros per person-year."),
      list(symbol = "$p^{*}$", meaning = "Break-even annual price: the price at which net monetary benefit is exactly zero, euros per person-year. In this model extra cost rises with price while health does not change, so any higher price gives negative net monetary benefit."),
      list(symbol = "$\\lambda$", meaning = "Willingness-to-pay threshold, euros per QALY."),
      list(symbol = "$s$", meaning = "Slope of extra cost against price, in euros of extra cost per €1 of price — the treated years per person."),
      list(symbol = "$c_0$", meaning = "Extra cost with the price set to zero, euros per person."),
      list(symbol = "$\\Delta E$", meaning = "Extra QALYs per person; unchanged by the price.")
    ),
    interpretation = paste0(
      "$p^{*}$ is the price at which value exactly breaks even: above it the net ",
      "monetary benefit is negative, below it positive. It is not a negotiated or ",
      "recommended price, and it moves with every other assumption — a different ",
      "scenario solves to a different price. The headroom is $p^{*}$ minus the price ",
      "in force."
    ),
    assumptions = c(
      "The price changes costs only and leaves health untouched.",
      "Extra cost is linear in the price in this model, which is what makes the solve exact; if that ever fails, a direct search replaces the equation."
    )
  ),
  budget = list(
    label = "How this is calculated",
    summary = paste(
      "What would treating the covered population cost the payer each year, and in",
      "total? Spending is totalled across the people treated, year by year, and added",
      "up over the horizon."
    ),
    formula = paste0(
      "\\begin{aligned}\n",
      "\\mathrm{net}_t &= p\\,A_t + k\\,(E_t - E_{t-1}) \\\\\n",
      "&\\quad - (s_h + s_e)\\,A_t\n",
      "\\end{aligned}"
    ),
    steps = c(
      "Covered population = eligible population × coverage share: the number of people the programme is offered to.",
      paste0(
        "Uptake is a percentage of that covered population. It starts at the first-year ",
        "value and rises by a fixed number of points each year, capped at 100%: ",
        "$u_t = \\min\\big(100,\\; u_1 + (t-1)\\,\\Delta u\\big)$."
      ),
      paste0(
        "Enrolled people by the end of year $t$ are ",
        "$E_t = \\text{covered population} \\times u_t/100$. New users in year $t$ are ",
        "$E_t - E_{t-1}$, and active users are the enrolled people who stay engaged: ",
        "$A_t = E_t \\times \\text{follow-up engagement share}$."
      ),
      paste0(
        "A year's spending $= p\\,A_t + k\\,(E_t - E_{t-1})$: the annual price for each ",
        "active user plus the one-off implementation cost for each new user."
      ),
      paste0(
        "A year's offsets $= (s_h + s_e)\\,A_t$: the healthcare-use and avoided-event ",
        "savings for each active user."
      ),
      paste(
        "Annual net impact is spending minus offsets; the running total is the sum of",
        "those annual amounts across the horizon."
      )
    ),
    definitions = list(
      list(symbol = "$A_t$", meaning = "Active users in year $t$, in people: enrolled and still engaged."),
      list(symbol = "$E_t$", meaning = "Enrolled people by the end of year $t$, in people."),
      list(symbol = "$u_t$", meaning = "Uptake in year $t$, as a percentage of the covered population."),
      list(symbol = "$\\Delta u$", meaning = "The annual increase in uptake, in percentage points per year."),
      list(symbol = "$p$", meaning = "Annual price, euros per active person-year."),
      list(symbol = "$k$", meaning = "One-off implementation cost, euros per new user."),
      list(symbol = "$s_h,\\ s_e$", meaning = "Healthcare-use and avoided-event savings, euros per active person-year."),
      list(symbol = "$\\mathrm{net}_t$", meaning = "Net budget impact in year $t$, euros for the whole covered population.")
    ),
    interpretation = paste(
      "The annual figure is money per year, at the scale of the covered population;",
      "the cumulative figure is the plain sum of those years across the horizon. They",
      "are different quantities — a multi-year total is not the annual figure",
      "multiplied by the number of years, because uptake and the number of new users",
      "change each year. No budget ceiling is applied, so no affordability verdict is",
      "produced."
    ),
    assumptions = c(
      "Nothing is discounted or inflated, so the figures are cash amounts rather than present values; the horizon, the uptake path and the savings are the values in force (the panel starts at five years, 10% year-1 uptake and a 5-point annual rise).",
      "The annual price is charged for active users only, not for everyone enrolled."
    )
  ),
  readiness = list(
    label = "How this works",
    summary = paste(
      "Could this be delivered as planned, to the people it is meant for? Seven",
      "delivery areas are each judged against their own fixed rule, and the judgements",
      "are counted rather than scored."
    ),
    steps = c(
      paste0(
        "Reach $=$ target population $\\times$ access $\\times$ suitability: the ",
        "people who could be offered the programme at all."
      ),
      paste0(
        "Active users $=$ reach $\\times$ engagement. Clinician hours per year ",
        "$=$ year-1 active users $\\times$ review minutes per patient per month ",
        "$\\times$ 12 $\\div$ 60."
      ),
      paste0(
        "Retention $=$ follow-up engagement $\\div$ year-1 engagement, as a percentage."
      ),
      "Each of the seven areas below is tested against its own thresholds.",
      "The counts of green, amber and red summarise those seven judgements. They are never weighted or added into a single score."
    ),
    interpretation = paste(
      "A status marks an area that needs attention; it is not a verdict on the",
      "technology, and green everywhere would not be a certification. Because each",
      "area is judged on its own, one red area is not offset by two green ones."
    ),
    assumptions = c(
      "The thresholds are illustrative teaching rules for this fictional case, not an official standard.",
      "The target population and the two engagement values are shared with the economic assumptions; the other inputs belong to this check."
    ),
    table_title = "The seven rules",
    table = list(
      list(label = "Reach and equity", value = "Green: access $\\ge 80\\%$ and suitability $\\ge 75\\%$. Amber: both $\\ge 50\\%$. Red: otherwise."),
      list(label = "Engagement", value = "Green: follow-up engagement $\\ge 60\\%$. Amber: $\\ge 30\\%$. Red: below $30\\%$."),
      list(label = "Workflow", value = "Green: under 5 review minutes. Amber: 5 to 15. Red: over 15."),
      list(label = "Language", value = "Green: 3 or more languages. Amber: exactly 2. Red: 1."),
      list(label = "Accessibility", value = "Green: accessibility features present. Red: absent."),
      list(label = "Interoperability", value = "Green: FHIR-based exchange. Amber: partial exchange. Red: no exchange."),
      list(label = "Algorithm governance", value = "Green: locked algorithm or no algorithmic component. Amber: controlled periodic updates. Red: otherwise.")
    )
  ),
  survival = list(
    label = "How this works",
    summary = paste(
      "By a given time, what share of each group is estimated to be free of a first",
      "heart attack or stroke? Two simulated groups are followed year by year, and the",
      "Kaplan–Meier estimate turns each group's experience into a curve."
    ),
    formula = paste0(
      "\\hat{S}(t) = \\prod_{t_i \\le t} ",
      "\\left(1 - \\frac{d_i}{n_i}\\right)"
    ),
    steps = c(
      paste(
        "Each arm simulates a group of people who are followed for the chosen number",
        "of years. In each year a person can have a first heart attack or stroke, die",
        "of another cause, or remain event-free."
      ),
      paste(
        "The annual event risk is the heart-attack risk plus the stroke risk; for",
        "engaged users in the eQalb arm it is reduced by the relative risk reduction.",
        "An event time is drawn within the year in which the event happens."
      ),
      paste(
        "Other-cause deaths and the end of follow-up are censored: that person",
        "contributes the time they were followed, but no event."
      ),
      paste0(
        "The estimate starts at 1. At each event time it is multiplied by ",
        "$1 - d_i/n_i$. Censored people drop out of the risk set without being ",
        "counted as events."
      ),
      "The two arms' estimates are read at the same time to compare them."
    ),
    definitions = list(
      list(symbol = "$\\hat{S}(t)$", meaning = "Estimated probability of remaining free of a first heart attack or stroke up to time $t$, from 0 to 1, shown as a percentage."),
      list(symbol = "$d_i$", meaning = "Number of first events at event time $t_i$."),
      list(symbol = "$n_i$", meaning = "Number of people still followed just before $t_i$."),
      list(symbol = "censored", meaning = "Followed for some time without an observed event; other-cause deaths and the end of follow-up are both censored.")
    ),
    interpretation = paste(
      "The curve estimates the share still event-free in a hypothetical world where",
      "other-cause death does not remove people from the group, because that death is",
      "handled as censoring. It is therefore not the real-world chance of avoiding a",
      "heart attack or stroke, and one minus the curve is not a real-world event risk.",
      "Both curves come from a simulation with a fixed random seed: repeating it",
      "reproduces them exactly, and a different seed moves them slightly."
    ),
    assumptions = c(
      "The data are simulated and illustrative, not clinical evidence.",
      "The event is a first heart attack or stroke. Before a first event, the only way to die in this simulation is from another cause; those deaths are censored, as is everyone still event-free at the end of follow-up. This simulation is separate from the cost-effectiveness model, which also includes deaths after a heart attack or stroke.",
      "The band around each curve is the estimator's uncertainty for this simulation, not a claim about a real trial."
    )
  )
)

# `jsonlite` writes a one-element character vector as a bare string rather than an
# array, which would make a reader iterate its characters instead of its sentences.
# The two character lists are therefore marked AsIs, so they stay arrays at every
# length; the row lists (`definitions`, `table`) are lists of objects and already do.
MODULE_METHOD_NOTES <- lapply(MODULE_METHOD_NOTES, function(note) {
  note$steps <- I(as.character(note$steps))
  if (!is.null(note$assumptions)) {
    note$assumptions <- I(as.character(note$assumptions))
  }
  note
})

# One module's method note, or NULL where the module publishes none. A caller that
# asks for a module this dictionary does not carry gets nothing rather than a
# guessed note, so a new module cannot silently inherit another's method.
module_method_note <- function(id) {
  if (!id %in% names(MODULE_METHOD_NOTES)) return(NULL)
  MODULE_METHOD_NOTES[[id]]
}
