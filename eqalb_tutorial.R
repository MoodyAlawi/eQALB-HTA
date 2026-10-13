# eQalb Guided Tutorial Part 1: R-owned defaults, statuses, wording and decision
# summary.
#
# The browser tutorial is a presentation layer over this module. Every default,
# range, label, status, threshold, interpretation, table row, chart series and
# decision-summary sentence the tutorial shows comes from here, so the tutorial
# logic and its wording exist in exactly one place and the Vue client derives
# nothing of its own.
#
# Scope: Guided Tutorial Part 1 only: four steps (base cost-effectiveness, budget
# impact, DHT readiness, tutorial decision summary) and the completion state.
# Guided Tutorial Part 2 (the commissioning case challenge) is deliberately not
# part of this module.
#
# The tutorial is self-contained. Every value it needs is either one of its own
# controls or one of the fixed R-owned values below, so it never reads a
# full-analysis control and cannot change when the dashboard is edited. In
# particular the post-event utilities are explicit tutorial constants here; the
# legacy Shiny tutorial read the dashboard's own utility fields for those two
# values.
#
# The simplified tutorial traffic-light rules in this module are deliberately
# different from the full-analysis rules, which stay in eqalb_markov.R and are
# unchanged. No model, budget-impact, readiness, PSA, OWSA, value-based-price or
# HTA-summary calculation is modified or re-implemented here: the tutorial calls
# run_eqalb_model(), calculate_budget_impact(), calculate_readiness() and
# assess_hta_decision_summary() exactly as the reference application does.
#
# Sourced by api/plumber.R, which is what the browser interface talks to.

# --- Tutorial constants and simplified rules --------------------------------

# The four steps, in teaching order, followed by the completion state.
EQALB_TUTORIAL_STEP_IDS <- c("1", "2", "3", "4")

# Simplified tutorial budget bands. The full-analysis bands are
# HTA_SUMMARY_THRESHOLDS$budget_impact_green / _amber in eqalb_markov.R.
EQALB_TUTORIAL_BUDGET_GREEN_MAX <- 5e6
EQALB_TUTORIAL_BUDGET_AMBER_MAX <- 10e6

# A tutorial readiness domain is Green when this many of the assessed domains are
# Green, unless the shared readiness assessment is itself Red.
EQALB_TUTORIAL_READINESS_GREEN_DOMAINS <- 4L

# Engagement wording thresholds for the tutorial's own Engagement explanation.
EQALB_TUTORIAL_ENGAGEMENT_FAVOURABLE_PCT <- 60
EQALB_TUTORIAL_ENGAGEMENT_LOW_PCT <- 30

# Status wording used when a domain has no status, and the wording used when the
# model cannot produce an ICER. Both are shown to the learner, so both are R's.
EQALB_TUTORIAL_STATUS_NOT_ASSESSED <- "Not assessed"
EQALB_TUTORIAL_STATUS_NOT_AVAILABLE <- "Not available"
EQALB_TUTORIAL_ICER_UNAVAILABLE <- "Not interpretable"

# --- Small formatting and validation helpers --------------------------------

# Money, formatted exactly as the reference tutorial formats it: two decimals,
# thousands separators, an explicit minus sign for negatives. `scientific = FALSE`
# is required rather than cosmetic: without it R renders a round value such as the
# €100,000 threshold or the €3,000,000 ceiling in scientific notation ("€1e+05").
# Defined here rather than read from app.R so this module is self-contained and
# cannot depend on the Shiny application being loaded.
eqalb_tutorial_money <- function(value) {
  paste0(
    "€",
    format(round(value, 2), big.mark = ",", nsmall = 2, scientific = FALSE)
  )
}

eqalb_tutorial_money_signed <- function(value) {
  formatted <- paste0(
    "€",
    format(
      round(abs(value), 2),
      big.mark = ",",
      nsmall = 2,
      scientific = FALSE,
      trim = TRUE
    )
  )
  ifelse(value < 0, paste0("-", formatted), formatted)
}

# QALYs, to five decimals, as the tutorial table and decision summary show them.
eqalb_tutorial_qalys <- function(value) {
  format(round(value, 5), nsmall = 5)
}

# One model constant, read from the model module that is already sourced. The
# fallback keeps the module usable on its own; it is the value the model file
# itself declares.
eqalb_tutorial_model_constant <- function(name, fallback) {
  value <- get0(name, envir = globalenv(), ifnotfound = NULL)
  if (is.null(value) || length(value) != 1L) {
    return(fallback)
  }
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || is.na(value) || !is.finite(value)) fallback else value
}

# The simulated-data disclaimer every response carries.
eqalb_tutorial_notice <- function() {
  get0(
    "SIMULATED_DATA_NOTICE",
    envir = globalenv(),
    ifnotfound = "Simulated illustrative data - not clinical evidence"
  )
}

# Numeric tutorial control. An absent value takes the tutorial default; a value
# outside the control's own range is rejected with R's message.
eqalb_tutorial_number <- function(body, name, default, min = -Inf, max = Inf) {
  value <- body[[name]]
  if (is.null(value) || length(value) != 1L || is.na(value)) {
    return(default)
  }
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || is.na(value) || !is.finite(value)) {
    stop(sprintf("'%s' must be a single finite number.", name), call. = FALSE)
  }
  if (value < min || value > max) {
    stop(
      sprintf("'%s' must be between %s and %s.", name, format(min), format(max)),
      call. = FALSE
    )
  }
  value
}

# Boolean tutorial control. Accepts a JSON boolean, 0/1 or "true"/"false",
# because a request body may carry any of those forms.
eqalb_tutorial_flag <- function(body, name, default) {
  value <- body[[name]]
  if (is.null(value) || length(value) != 1L || is.na(value)) {
    return(default)
  }
  if (is.logical(value)) {
    return(value)
  }
  if (is.numeric(value) && value %in% c(0, 1)) {
    return(value == 1)
  }
  text <- tolower(trimws(as.character(value)))
  if (text %in% c("true", "yes", "1")) {
    return(TRUE)
  }
  if (text %in% c("false", "no", "0")) {
    return(FALSE)
  }
  stop(sprintf("'%s' must be true or false.", name), call. = FALSE)
}

# One explanation from the interface-copy dictionary, so the tutorial shows the
# same sentence the dictionary holds. A missing key fails loudly rather than
# shipping an empty explanation.
eqalb_tutorial_copy <- function(key) {
  dictionary <- get0("CC_INFO_TEXT", envir = globalenv(), ifnotfound = NULL)
  text <- if (is.list(dictionary)) dictionary[[key]] else NULL
  if (is.null(text) || !nzchar(text)) {
    stop("No CC_INFO_TEXT entry for '", key, "'.", call. = FALSE)
  }
  text
}

# --- R-owned tutorial values and controls -----------------------------------

# The tutorial's own fixed values. Every one of them is a tutorial constant: the
# two post-event utilities in particular are declared here, so editing a
# full-analysis utility can never move a tutorial result.
eqalb_tutorial_fixed <- function() {
  list(
    utility_post_mi = 0.80,
    utility_post_stroke = 0.60,
    implementation_cost = eqalb_tutorial_model_constant(
      "implementation_cost", 40
    ),
    healthcare_savings = eqalb_tutorial_model_constant(
      "healthcare_use_savings_annual", 20
    ),
    bia_year1_uptake_pct = 10,
    bia_annual_uptake_increase_pp = 5,
    bia_horizon_years = 5,
    bia_avoided_event_savings_per_active_user = 0,
    digital_access_pct = 85,
    digital_suitability_pct = 75,
    accessibility_features = TRUE,
    algorithm_governance = "Periodic controlled updates",
    supported_languages_available = 3L,
    supported_languages_unavailable = 1L,
    interoperability_available = "FHIR-based exchange",
    interoperability_unavailable = "No data exchange"
  )
}

# The nine Part 1 controls, with the label, unit, type, valid range, step,
# default and explanation the browser renders. `step_index` is the tutorial step
# the control belongs to.
eqalb_tutorial_control_specs <- function() {
  data.frame(
    id = c(
      "tutorial_price", "tutorial_rrr", "tutorial_engagement_year1",
      "tutorial_engagement_followup", "tutorial_utility_no_event",
      "tutorial_population", "tutorial_review_minutes",
      "tutorial_interop_available", "tutorial_language_available"
    ),
    step_index = c(1L, 1L, 1L, 1L, 1L, 2L, 3L, 3L, 3L),
    type = c(
      "slider", "slider", "slider", "slider", "slider", "slider", "slider",
      "checkbox", "checkbox"
    ),
    label = c(
      "Annual price of the technology (EUR per person per year)",
      "Risk reduction for engaged users (%)",
      "Share of users engaged in year 1 (%)",
      "Share of users still engaged after the first year (%)",
      "Utility: quality of life with no event (0 to 1)",
      "Eligible population (people)",
      "Clinician review minutes per patient per month",
      "Is the intervention interoperable?",
      "Is the intervention available in the required language?"
    ),
    unit = c(
      "EUR per person per year", "%", "%", "%", "0 to 1", "people",
      "minutes per patient per month", "", ""
    ),
    info_topic = c(
      "the annual price of the technology",
      "the risk reduction for engaged users",
      "the share of users engaged in year 1",
      "the share of users still engaged after the first year",
      "the no-event utility",
      "the eligible population",
      "the clinician review time",
      "interoperability",
      "language availability"
    ),
    info_key = c(
      "tutorial_price", "tutorial_rrr", "tutorial_engagement_year1",
      "tutorial_engagement_followup", "tutorial_utility_no_event",
      "tutorial_population", "tutorial_review_minutes",
      "tutorial_interop_definition", "tutorial_language_definition"
    ),
    default = c(360, 10, 70, 42, 0.86, 100000, 10, TRUE, TRUE),
    min = c(0, 0, 0, 0, 0.50, 10000, 0, NA, NA),
    max = c(900, 30, 100, 100, 1.00, 500000, 30, NA, NA),
    step_size = c(10, 1, 1, 1, 0.01, 10000, 1, NA, NA),
    stringsAsFactors = FALSE
  )
}

# The control specs as the browser needs them: one row per control with its
# explanation resolved from the copy dictionary, its default carrying its own
# type (a checkbox default is a JSON boolean, not the 1 a mixed data.frame column
# would hold), and the bounds and step omitted for a control that has none.
eqalb_tutorial_controls <- function() {
  specs <- eqalb_tutorial_control_specs()
  specs$info <- vapply(
    specs$info_key,
    eqalb_tutorial_copy,
    character(1),
    USE.NAMES = FALSE
  )
  defaults <- eqalb_tutorial_defaults()

  lapply(seq_len(nrow(specs)), function(index) {
    row <- as.list(specs[index, , drop = FALSE])
    control <- list(
      id = row$id,
      step_index = as.integer(row$step_index),
      type = row$type,
      label = row$label,
      unit = row$unit,
      info_topic = row$info_topic,
      info = row$info,
      default = defaults[[row$id]]
    )
    # A control without a bound or a step omits the key entirely, so a checkbox
    # never carries a meaningless numeric range.
    if (!is.na(row$min)) control$min <- as.numeric(row$min)
    if (!is.na(row$max)) control$max <- as.numeric(row$max)
    if (!is.na(row$step_size)) control$step <- as.numeric(row$step_size)
    control
  })
}

# The tutorial's own default for every control, as a named list with each value
# in its own type. This is what "Restart tutorial" restores and what a request
# with no body evaluates.
eqalb_tutorial_defaults <- function() {
  specs <- eqalb_tutorial_control_specs()
  values <- lapply(seq_len(nrow(specs)), function(index) {
    type <- specs$type[index]
    default <- specs$default[index]
    if (identical(type, "checkbox")) {
      isTRUE(as.logical(default))
    } else {
      as.numeric(default)
    }
  })
  stats::setNames(values, specs$id)
}

# --- Tutorial-only status rules ---------------------------------------------

# The least favourable assessed domain. The simulated clinical-evidence domain is
# excluded by the caller, so it never sets the tutorial overall status.
eqalb_tutorial_overall_status <- function(statuses) {
  assessed <- statuses[statuses %in% c("Green", "Amber", "Red")]
  if (length(assessed) == 0L) {
    return(EQALB_TUTORIAL_STATUS_NOT_ASSESSED)
  }
  if (any(assessed == "Red")) {
    return("Red")
  }
  if (any(assessed == "Amber")) {
    return("Amber")
  }
  "Green"
}

# Cost effectiveness, from the sign of the incremental values only: Green when
# eQalb costs less and adds QALYs, Amber when it costs more but adds QALYs, Red
# when it adds none.
eqalb_tutorial_ce_status <- function(incremental_cost, incremental_qalys) {
  if (length(incremental_cost) == 0L || length(incremental_qalys) == 0L ||
        is.na(incremental_cost) || is.na(incremental_qalys)) {
    return(EQALB_TUTORIAL_STATUS_NOT_ASSESSED)
  }
  if (incremental_cost <= 0 && incremental_qalys > 0) {
    "Green"
  } else if (incremental_qalys > 0) {
    "Amber"
  } else {
    "Red"
  }
}

# Budget impact, on the simplified tutorial bands.
eqalb_tutorial_budget_status <- function(cumulative_budget_impact) {
  if (length(cumulative_budget_impact) == 0L ||
        is.na(cumulative_budget_impact)) {
    return(EQALB_TUTORIAL_STATUS_NOT_ASSESSED)
  }
  if (cumulative_budget_impact < EQALB_TUTORIAL_BUDGET_GREEN_MAX) {
    "Green"
  } else if (cumulative_budget_impact <= EQALB_TUTORIAL_BUDGET_AMBER_MAX) {
    "Amber"
  } else {
    "Red"
  }
}

# Implementation readiness. It reuses the status the shared readiness
# assessment already produced (passed in by the caller) and never re-implements
# the readiness rule.
eqalb_tutorial_readiness_status <- function(readiness_domains, existing_status) {
  if (identical(existing_status, "Red")) {
    return("Red")
  }
  if (sum(readiness_domains$Status == "Green") >=
        EQALB_TUTORIAL_READINESS_GREEN_DOMAINS) {
    "Green"
  } else {
    "Amber"
  }
}

# Tutorial-only wording for the Engagement readiness domain. The shared
# explanation is written from the follow-up value alone, which reads as "follow-up
# engagement is low" even when follow-up engagement is high and only year-1
# engagement is low. The tutorial keeps the same traffic light but names the
# engagement input that is actually the concern.
eqalb_tutorial_engagement_explanation <- function(year1_pct, followup_pct) {
  if (length(year1_pct) == 0L || length(followup_pct) == 0L ||
        is.na(year1_pct) || is.na(followup_pct)) {
    return("Engagement is not available under the selected assumptions.")
  }
  year1_low <- year1_pct < EQALB_TUTORIAL_ENGAGEMENT_LOW_PCT
  followup_low <- followup_pct < EQALB_TUTORIAL_ENGAGEMENT_LOW_PCT
  if (year1_low && followup_low) {
    paste(
      "Year-1 and follow-up engagement are low, so fewer users may begin and",
      "remain engaged over time."
    )
  } else if (year1_low) {
    paste(
      "Year-1 engagement is low, so fewer eligible users may begin or remain",
      "engaged during the first year."
    )
  } else if (followup_low) {
    paste(
      "Follow-up engagement is low, so users may not remain engaged after the",
      "first year."
    )
  } else if (year1_pct >= EQALB_TUTORIAL_ENGAGEMENT_FAVOURABLE_PCT &&
               followup_pct >= EQALB_TUTORIAL_ENGAGEMENT_FAVOURABLE_PCT) {
    paste(
      "Year-1 and follow-up engagement are favourable under the selected",
      "assumptions."
    )
  } else {
    paste0(
      "Year-1 engagement is ", year1_pct, "% and follow-up engagement is ",
      followup_pct, "%, so some users may not remain engaged over time."
    )
  }
}

# Plain-language wording for each tutorial domain status.
eqalb_tutorial_status_text <- function(domain, status) {
  switch(paste0(domain, "|", status),
    "Cost-effectiveness|Green" = paste(
      "eQalb costs less than usual care and adds QALYs, so it dominates the",
      "comparator under these assumptions."
    ),
    "Cost-effectiveness|Amber" = paste(
      "eQalb costs more than usual care but adds QALYs, so the ICER has to be",
      "compared with a willingness-to-pay threshold before any judgement."
    ),
    "Cost-effectiveness|Red" = paste(
      "eQalb does not add QALYs under these assumptions, so it is",
      "unfavourable or dominated whatever the ICER."
    ),
    "Budget impact|Green" = paste(
      "Low five-year cumulative net budget impact, so affordability is",
      "unlikely to be a barrier at this scale."
    ),
    "Budget impact|Amber" = paste(
      "Moderate five-year cumulative net budget impact, so affordability",
      "depends on uptake and price."
    ),
    "Budget impact|Red" = paste(
      "High five-year cumulative net budget impact, so affordability is a",
      "material barrier under the selected uptake assumptions."
    ),
    "Clinical evidence maturity|Red" = paste(
      "The clinical outcome evidence in this app is simulated illustrative",
      "data, not observed clinical evidence, so this domain is always Red. It",
      "is shown for transparency and does not set the tutorial overall status."
    ),
    "Implementation readiness|Green" = paste(
      "At least four readiness domains are Green, so there is no obvious",
      "implementation barrier under the selected assumptions."
    ),
    "Implementation readiness|Amber" = paste(
      "Some readiness domains need mitigation before broad deployment; see",
      "the readiness results above for the domain detail."
    ),
    "Implementation readiness|Red" = paste(
      "The readiness assessment is Red, so major barriers need resolution",
      "before broad deployment."
    ),
    EQALB_TUTORIAL_STATUS_NOT_ASSESSED
  )
}

# --- Static tutorial wording (the contract) ---------------------------------

# The simplified teaching rules, in the tutorial's own words.
eqalb_tutorial_rule_items <- function() {
  c(
    paste(
      "Cost effectiveness is Green when eQalb costs less than usual care and",
      "adds QALYs, Amber when it costs more but still adds QALYs so the ICER",
      "has to be considered, and Red when it does not add QALYs."
    ),
    paste(
      "Budget impact is Green below €5 million, Amber from €5 million up to",
      "€10 million, and Red above €10 million."
    ),
    paste(
      "Implementation readiness is Green when at least four readiness domains",
      "are Green, Amber otherwise, and Red when the existing readiness",
      "assessment is itself Red."
    ),
    paste(
      "Clinical evidence maturity is always Red because the evidence in this",
      "application is simulated. It is shown for transparency and does not set",
      "the tutorial overall status."
    ),
    "The tutorial overall status is the least favourable assessed domain.",
    paste(
      "These are simplified teaching rules for this tutorial, not official",
      "payer or NICE criteria."
    )
  )
}

# The simplified evidence-generation priorities the tutorial shows. The full
# evidence-priority table is a full-analysis output and is not shown here.
eqalb_tutorial_evidence_items <- function() {
  c(
    "Collect stronger evidence on clinical outcomes.",
    "Confirm sustained user engagement.",
    "Assess implementation and interoperability in practice.",
    "Validate costs and resource use in the target health system."
  )
}

# The four steps: the heading, the progress name, the teaching paragraph, the
# explanation bullets, the hint lines and the headings of the blocks the step
# renders. Every sentence the learner reads is held here.
eqalb_tutorial_step_copy <- function() {
  list(
    list(
      id = "1",
      title = "Step 1. Base cost-effectiveness",
      progress = "Base cost-effectiveness",
      intro = paste(
        "An economic evaluation compares two options: the new technology and",
        "what is already done. The usual-care option is the comparator, and",
        "eQalb is added on top of it."
      ),
      explain = c(
        paste(
          "Incremental cost is how much more the eQalb strategy costs than",
          "usual care."
        ),
        paste(
          "Incremental QALYs are the extra quality-adjusted life years gained.",
          "One QALY is one year in full health."
        ),
        paste(
          "The ICER divides the extra cost by the extra QALYs. It is the price",
          "of one additional QALY."
        )
      ),
      controls_heading = "Try changing these assumptions",
      result_heading = "Result from the base model"
    ),
    list(
      id = "2",
      title = "Step 2. Budget impact",
      progress = "Budget impact",
      intro = paste(
        "Cost effectiveness asks whether the technology is worth its price.",
        "Budget impact asks a different question: how much money the payer",
        "would spend over the next few years."
      ),
      explain = character(0),
      heading_info_key = "tutorial_bia_explain",
      heading_info_topic = "how budget impact is calculated",
      linked_price_label = "Adjust linked price in Step 1",
      result_heading = "Result from the budget-impact analysis",
      disclosure_label = "View annual breakdown"
    ),
    list(
      id = "3",
      title = "Step 3. DHT readiness",
      progress = "DHT readiness",
      intro = paste(
        "A model can look favourable and still fail in practice. The readiness",
        "assessment checks whether the technology can actually reach and",
        "support patients."
      ),
      explain = character(0),
      heading_info_key = "tutorial_readiness_explain",
      heading_info_topic = "how readiness is assessed",
      domains_heading = "Readiness domain statuses",
      engagement_note = paste(
        "Engagement is shared with Step 1, so changing the year-1 or follow-up",
        "engagement there also changes these domains."
      ),
      conditions_heading = "Implementation conditions",
      conditions_note = paste(
        "Both answers set the interoperability and language-access domains.",
        "Algorithm governance is not assessed in this simplified tutorial."
      ),
      disclosure_label = "View readiness calculations"
    ),
    list(
      id = "4",
      title = "Step 4. Tutorial decision summary",
      progress = "HTA decision summary",
      intro = paste(
        "The last step brings the earlier results together into one picture. It",
        "reuses the base-model output and the readiness assessment you have",
        "already seen, and does not recalculate anything."
      ),
      explain = c(
        paste(
          "Cost effectiveness compares the incremental cost with the",
          "incremental QALYs."
        ),
        paste(
          "Budget impact asks whether the five-year net cost is affordable,",
          "using simplified tutorial bands."
        ),
        paste(
          "Clinical evidence maturity is always red here, because the evidence",
          "in this application is simulated. It is shown for transparency but",
          "does not set the tutorial overall status."
        ),
        paste(
          "Implementation readiness summarises the readiness domains from the",
          "previous step."
        )
      ),
      rules_trigger_label = paste(
        "Traffic-light rules: show the simplified teaching rules used in this",
        "tutorial"
      ),
      rules_title = "Tutorial traffic-light rules",
      summary_heading = "Tutorial decision summary",
      interpretation_heading = "Plain-language interpretation",
      evidence_heading = "Tutorial evidence-generation priorities",
      finish_label = "Finish tutorial"
    )
  )
}

# The static Part 1 contract: everything the browser needs before (and alongside)
# a calculation. No model run happens to build it.
eqalb_tutorial_contract <- function() {
  fixed <- eqalb_tutorial_fixed()
  list(
    part1 = list(
      title = "Guided tutorial",
      kicker = "Simplified learning tutorial",
      disclaimer = paste(
        "This tutorial uses the same illustrative base model as the full",
        "analysis but presents a simplified sequence for learning. It is not a",
        "complete HTA and does not represent clinical or reimbursement",
        "evidence."
      ),
      progress = list(
        total = length(EQALB_TUTORIAL_STEP_IDS),
        step_template = "Step {step} of {total}. {title}",
        completed_template = "All {total} steps completed. Tutorial complete."
      ),
      navigation = list(
        back = "Back",
        forward = "Next",
        exit = "Exit tutorial"
      ),
      completion = list(
        title = "Tutorial complete",
        body = paste(
          "You have completed the simplified tutorial. The full analysis",
          "includes additional uncertainty and value-of-information methods.",
          "Consider running a PSA next to explore how uncertainty affects the",
          "decision."
        ),
        open_full_label = "Open full analysis",
        restart_label = "Restart tutorial"
      ),
      controls = eqalb_tutorial_controls(),
      defaults = eqalb_tutorial_defaults(),
      # The two explanations that belong to a step heading rather than to a
      # control, so a step can explain what it is about to ask for.
      headings = list(
        tutorial_bia_explain = eqalb_tutorial_copy("tutorial_bia_explain"),
        tutorial_readiness_explain = eqalb_tutorial_copy(
          "tutorial_readiness_explain"
        )
      ),
      # The headings of the tutorial's own tables, so a table this interface
      # renders carries R's column names rather than a second copy of them.
      table_headings = list(
        measure = "Measure",
        value = "Value",
        basis = "Illustrative basis",
        year = "Year",
        active_users = "Active users",
        net_budget_impact = "Net budget impact",
        current_values = "Current values: "
      ),
      fixed = list(
        values = fixed,
        post_event_utilities = list(
          title = "Fixed post-event utilities used in this tutorial",
          items = c(
            sprintf("Post-MI utility: %.2f", fixed$utility_post_mi),
            sprintf("Post-stroke utility: %.2f", fixed$utility_post_stroke)
          ),
          hint = paste(
            "These fixed values are applied to time spent after MI or stroke",
            "when calculating QALYs. The slider above controls the no-event",
            "utility."
          )
        )
      ),
      steps = eqalb_tutorial_step_copy(),
      rules = list(
        title = "Tutorial traffic-light rules",
        trigger_label = paste(
          "Traffic-light rules: show the simplified teaching rules used in this",
          "tutorial"
        ),
        items = eqalb_tutorial_rule_items()
      ),
      evidence = list(
        heading = "Tutorial evidence-generation priorities",
        items = eqalb_tutorial_evidence_items()
      ),
      labels = list(
        current_values = "Current values: ",
        readiness_checks = "Readiness domains set by these two answers: ",        overall_status_prefix = "Tutorial overall status - ",
        overall_note = paste(
          "Simplified tutorial status over cost effectiveness, budget impact",
          "and implementation readiness. Simulated clinical evidence is shown",
          "below but does not set this status."
        ),
        overall_fallback_status = "Not assessed"
      )
    ),
    notice = eqalb_tutorial_notice()
  )
}

# --- Resolving the tutorial inputs ------------------------------------------

# The tutorial's control values, validated against their own ranges and
# completed with R's defaults. Nothing outside this list is read, so a request
# cannot reach a full-analysis setting.
eqalb_tutorial_inputs <- function(body = list()) {
  specs <- eqalb_tutorial_control_specs()
  specs <- specs[order(specs$step_index), , drop = FALSE]
  values <- list()
  for (index in seq_len(nrow(specs))) {
    row <- specs[index, , drop = FALSE]
    if (identical(row$type, "checkbox")) {
      values[[row$id]] <- eqalb_tutorial_flag(
        body, row$id, isTRUE(as.logical(row$default))
      )
    } else {
      values[[row$id]] <- eqalb_tutorial_number(
        body, row$id, as.numeric(row$default),
        min = as.numeric(row$min), max = as.numeric(row$max)
      )
    }
  }
  values
}

# --- Part 1 calculations -----------------------------------------------------

# Step 1: the base-case model result and its presentation data. The model
# function is unchanged; only the tutorial's own values are passed to it.
eqalb_tutorial_ce <- function(inputs, fixed) {
  result <- run_eqalb_model(
    scenario_intervention_price = inputs$tutorial_price,
    scenario_implementation_cost = fixed$implementation_cost,
    scenario_healthcare_savings = fixed$healthcare_savings,
    scenario_rrr = inputs$tutorial_rrr / 100,
    scenario_engagement_year1 = inputs$tutorial_engagement_year1 / 100,
    scenario_engagement_followup = inputs$tutorial_engagement_followup / 100,
    scenario_utility_no_event = inputs$tutorial_utility_no_event,
    scenario_utility_post_mi = fixed$utility_post_mi,
    scenario_utility_post_stroke = fixed$utility_post_stroke
  )

  # R owns both renderings of a ratio the model could not produce, so the client
  # never decides how an uninterpretable ICER reads.
  icer_finite <- is.finite(result$icer)
  icer_display <- if (icer_finite) {
    paste0(eqalb_tutorial_money(result$icer), "/QALY")
  } else {
    EQALB_TUTORIAL_ICER_UNAVAILABLE
  }
  chart_subtitle <- if (icer_finite) {
    paste0("ICER: ", eqalb_tutorial_money(result$icer), " per QALY")
  } else {
    paste0("ICER: ", tolower(EQALB_TUTORIAL_ICER_UNAVAILABLE))
  }

  list(
    incremental_cost = result$incremental_cost,
    incremental_qalys = result$incremental_qalys,
    # R's own "not interpretable" convention: NA, which the service writes as
    # JSON null rather than as a number.
    icer = if (icer_finite) result$icer else NA_real_,
    icer_display = icer_display,
    table = list(
      list(
        measure = "Incremental cost (EUR per person)",
        value = eqalb_tutorial_money(result$incremental_cost)
      ),
      list(
        measure = "Incremental QALYs (per person)",
        value = eqalb_tutorial_qalys(result$incremental_qalys)
      ),
      list(
        measure = "ICER (EUR per QALY)",
        value = icer_display
      )
    ),
    chart = list(
      title = "Cost-effectiveness plane",
      subtitle = chart_subtitle,
      x_label = "Incremental QALYs",
      y_label = "Incremental cost (€)",
      points = list(
        list(
          label = "Usual care",
          incremental_cost = 0,
          incremental_qalys = 0
        ),
        list(
          label = "eQalb + usual care",
          incremental_cost = result$incremental_cost,
          incremental_qalys = result$incremental_qalys
        )
      )
    )
  )
}

# Step 2: the budget-impact result, its formatted table and its chart series. The
# intervention price is the tutorial's own Step-1 price and the follow-up
# engagement is the tutorial's own Step-1 value, so the two steps cannot
# disagree.
eqalb_tutorial_bia <- function(inputs, fixed) {
  result <- calculate_budget_impact(
    population = inputs$tutorial_population,
    year1_uptake_pct = fixed$bia_year1_uptake_pct,
    annual_uptake_increase_pp = fixed$bia_annual_uptake_increase_pp,
    horizon_years = fixed$bia_horizon_years,
    intervention_price = inputs$tutorial_price,
    implementation_cost_per_new_user = fixed$implementation_cost,
    healthcare_savings_per_active_user = fixed$healthcare_savings,
    avoided_event_savings_per_active_user =
      fixed$bia_avoided_event_savings_per_active_user,
    followup_engagement_pct = inputs$tutorial_engagement_followup
  )
  total <- sum(result$net_budget_impact)

  years <- seq_len(nrow(result))
  rows <- lapply(years, function(index) {
    list(
      year = result$year[index],
      eligible_population = result$eligible_population[index],
      uptake_pct = result$uptake_pct[index],
      cumulative_users = result$cumulative_users[index],
      new_users = result$new_users[index],
      active_users = result$active_users[index],
      gross_intervention_cost = result$gross_intervention_cost[index],
      implementation_cost = result$implementation_cost[index],
      healthcare_savings = result$healthcare_savings[index],
      avoided_event_savings = result$avoided_event_savings[index],
      net_budget_impact = result$net_budget_impact[index],
      cumulative_budget_impact = result$cumulative_budget_impact[index]
    )
  })
  table <- lapply(years, function(index) {
    list(
      year = result$year[index],
      active_users = format(round(result$active_users[index]), big.mark = ","),
      net_budget_impact = eqalb_tutorial_money_signed(
        result$net_budget_impact[index]
      )
    )
  })

  list(
    horizon_years = nrow(result),
    total = total,
    total_display = eqalb_tutorial_money_signed(total),
    total_sentence = paste0(
      "Net budget impact over ", nrow(result), " years: ",
      eqalb_tutorial_money_signed(total), "."
    ),
    linked_price_sentence = paste0(
      "Intervention price from Step 1: ",
      eqalb_tutorial_money_signed(inputs$tutorial_price),
      " per active user per year."
    ),
    rows = rows,
    table = table,
    chart = list(
      title = "Budget impact analysis: annual net budget impact",
      subtitle = paste(
        "Educational budget-impact analysis using illustrative assumptions"
      ),
      x_label = "Year",
      y_label = "Annual net budget impact (€)"
    )
  )
}

# Step 3: the readiness assessment through the shared function, restricted to the
# domains the tutorial shows. Algorithm governance is dropped from the tutorial
# presentation only; the full readiness tab still reports all seven domains.
eqalb_tutorial_readiness <- function(inputs, fixed) {
  readiness <- calculate_readiness(
    target_population = inputs$tutorial_population,
    digital_access = fixed$digital_access_pct,
    digital_suitability = fixed$digital_suitability_pct,
    readiness_year1_engagement = inputs$tutorial_engagement_year1,
    readiness_followup_engagement = inputs$tutorial_engagement_followup,
    review_minutes = inputs$tutorial_review_minutes,
    supported_languages = if (isTRUE(inputs$tutorial_language_available)) {
      fixed$supported_languages_available
    } else {
      fixed$supported_languages_unavailable
    },
    accessibility_features = fixed$accessibility_features,
    interoperability = if (isTRUE(inputs$tutorial_interop_available)) {
      fixed$interoperability_available
    } else {
      fixed$interoperability_unavailable
    },
    algorithm_governance = fixed$algorithm_governance
  )

  domains <- readiness$domains[
    readiness$domains$Domain != "Algorithm governance", , drop = FALSE
  ]
  cards <- readiness$cards[
    readiness$cards$Domain != "Algorithm governance", , drop = FALSE
  ]
  engagement <- cards$Domain == "Engagement"
  if (any(engagement)) {
    cards$Explanation[engagement] <- eqalb_tutorial_engagement_explanation(
      inputs$tutorial_engagement_year1,
      inputs$tutorial_engagement_followup
    )
  }

  # The two yes/no answers are reported through the domains the shared
  # calculation already produced, so neither answer looks decorative.
  status_of <- function(name) {
    row <- domains[domains$Domain == name, , drop = FALSE]
    if (nrow(row) == 0L) {
      return(NULL)
    }
    sprintf("%s: %s", name, row$Status[1])
  }
  checks <- c(status_of("Interoperability"), status_of("Language access"))

  list(
    cards = lapply(seq_len(nrow(cards)), function(index) {
      list(
        domain = cards$Domain[index],
        status = cards$Status[index],
        explanation = cards$Explanation[index]
      )
    }),
    domains = domains,
    numbers = lapply(seq_len(nrow(readiness$numbers)), function(index) {
      list(
        measure = readiness$numbers$Measure[index],
        value = readiness$numbers$Value[index],
        basis = readiness$numbers$`Illustrative basis`[index]
      )
    }),
    checks_sentence = if (length(checks) == 0L) {
      ""
    } else {
      paste(checks, collapse = " | ")
    },
    green_domain_count = sum(domains$Status == "Green"),
    domain_count = nrow(domains)
  )
}

# Step 4: the tutorial decision summary. It reuses the shared readiness
# assessment for the readiness status and the model result and budget total it is
# given, and applies only the simplified tutorial rules above.
#
# The shared summary is called with no PSA metrics, exactly as it is before a PSA
# has been run: the tutorial excludes the PSA, so nothing else is available and
# nothing is invented. Only its Implementation-readiness row is read, which is
# derived from the tutorial's own readiness domains.
eqalb_tutorial_summary <- function(ce, bia, readiness) {
  existing <- assess_hta_decision_summary(
    icer = ce$icer,
    reference_wtp = NA_real_,
    probability_cost_effective = NA_real_,
    mean_incremental_nmb = NA_real_,
    evpi = NA_real_,
    highest_evppi = NA_real_,
    cumulative_budget_impact = bia$total,
    readiness_domains = readiness$domains
  )
  existing_readiness_status <- existing$domains$Status[
    existing$domains$Domain == "Implementation readiness"
  ]

  ce_status <- eqalb_tutorial_ce_status(
    ce$incremental_cost, ce$incremental_qalys
  )
  budget_status <- eqalb_tutorial_budget_status(bia$total)
  readiness_status <- eqalb_tutorial_readiness_status(
    readiness$domains, existing_readiness_status
  )

  rows <- list(
    list(
      domain = "Cost-effectiveness",
      status = ce_status,
      measure = paste0(
        "Incremental cost ",
        eqalb_tutorial_money_signed(ce$incremental_cost),
        " per person; incremental QALYs ",
        eqalb_tutorial_qalys(ce$incremental_qalys)
      ),
      interpretation = eqalb_tutorial_status_text("Cost-effectiveness", ce_status)
    ),
    list(
      domain = "Budget impact",
      status = budget_status,
      measure = paste0(
        "Five-year cumulative net budget impact ",
        eqalb_tutorial_money_signed(bia$total)
      ),
      interpretation = eqalb_tutorial_status_text("Budget impact", budget_status)
    ),
    list(
      domain = "Clinical evidence maturity",
      status = "Red",
      measure = "Simulated illustrative data",
      interpretation = eqalb_tutorial_status_text(
        "Clinical evidence maturity", "Red"
      )
    ),
    list(
      domain = "Implementation readiness",
      status = readiness_status,
      measure = paste0(
        readiness$green_domain_count, " of ", readiness$domain_count,
        " domains Green"
      ),
      interpretation = eqalb_tutorial_status_text(
        "Implementation readiness", readiness_status
      )
    )
  )

  # Simulated clinical evidence stays Red for transparency but is excluded from
  # the tutorial overall status.
  scored <- vapply(rows, function(row) row$status, character(1))
  scored <- scored[
    vapply(rows, function(row) row$domain, character(1)) !=
      "Clinical evidence maturity"
  ]
  overall <- eqalb_tutorial_overall_status(scored)

  list(
    overall_status = overall,
    overall_title = paste0("Tutorial overall status - ", overall),
    rows = rows,
    interpretation = paste0(
      "This tutorial summary is not a complete HTA and is not a reimbursement ",
      "recommendation. Under the assumptions you selected the least favourable ",
      "assessed domain is ", overall, ", based on cost effectiveness, budget ",
      "impact and implementation readiness. The full analysis adds uncertainty ",
      "and value-of-information methods, so consider running the PSA there to ",
      "see how uncertainty would affect the decision."
    )
  )
}

# The complete Part 1 response: everything all four steps render, from one
# deterministic calculation.
eqalb_tutorial_part1 <- function(body = list()) {
  inputs <- eqalb_tutorial_inputs(body)
  fixed <- eqalb_tutorial_fixed()

  ce <- eqalb_tutorial_ce(inputs, fixed)
  bia <- eqalb_tutorial_bia(inputs, fixed)
  readiness <- eqalb_tutorial_readiness(inputs, fixed)
  summary <- eqalb_tutorial_summary(ce, bia, readiness)

  list(
    inputs = inputs,
    # The values behind the tutorial that are not its own controls, echoed so a
    # caller can see that they are tutorial constants rather than dashboard
    # settings.
    fixed_inputs = fixed,
    ce = ce,
    bia = bia,
    readiness = list(
      cards = readiness$cards,
      domains = readiness$domains,
      numbers = readiness$numbers,
      checks_sentence = readiness$checks_sentence,
      green_domain_count = readiness$green_domain_count,
      domain_count = readiness$domain_count
    ),
    summary = summary,
    notice = eqalb_tutorial_notice()
  )
}

# ===========================================================================
# Guided Tutorial Part 2: the commissioning case challenge.
#
# A tutorial-only, case-based continuation of Part 1. It reuses
# run_eqalb_model(), calculate_budget_impact() and calculate_readiness() with
# one negotiated-price lever, so no model arithmetic is defined here.
#
# Every value a case supplies is a fixed Part 2 constant in this module: a case
# never reads a Part 1 control or a full-analysis setting, so editing the
# dashboard cannot move a case's facts and a case's price lever cannot move the
# dashboard. The three post-event utilities are the case's own values, which is
# the correction to the reference tutorial, where a Part 2 case took its
# utilities from the dashboard's editable utility fields.
#
# Slice 1 scope: the static contract, case creation/resume and the
# value-for-money section (the negotiated price lever, its price curve and the
# current-price result). The budget-impact, DHT-readiness and recommendation
# sections are declared in the contract as not yet available, and their fixed
# inputs are published so the contract already carries the values they will need.
# ===========================================================================

# --- Part 2 constants -------------------------------------------------------

# Identical in every case, so no rule, label or checklist wording depends on
# which case was drawn.
EQALB_PART2_WTP <- 100000
EQALB_PART2_BUDGET_CEILING <- 3e6

# The negotiated-price lever. The step is five euros so the highest passing
# slider value can be located precisely: the value-for-money window is narrow for
# some cases, and a coarser step would skip over the highest acceptable price.
EQALB_PART2_PRICE_MIN <- 150
EQALB_PART2_PRICE_MAX <- 360
EQALB_PART2_PRICE_STEP <- 5
EQALB_PART2_PRICE_DEFAULT <- 360

# The rollout coverage cap. Only the case's budget impact scales with it.
EQALB_PART2_COVERAGE_MIN <- 10
EQALB_PART2_COVERAGE_MAX <- 100
EQALB_PART2_COVERAGE_STEP <- 5
EQALB_PART2_COVERAGE_DEFAULT <- 100

# The budget-impact settings the case's five-year calculation uses. They are
# tutorial constants, not dashboard settings, so a case's budget impact cannot
# move when the application's assumptions are edited.
EQALB_PART2_BIA_YEAR1_UPTAKE_PCT <- 10
EQALB_PART2_BIA_ANNUAL_UPTAKE_INCREASE_PP <- 5
EQALB_PART2_BIA_HORIZON_YEARS <- 5
EQALB_PART2_BIA_AVOIDED_EVENT_SAVINGS_PER_ACTIVE_USER <- 0

# The five sections in teaching order, and the three this slice implements.
EQALB_PART2_STEP_KEYS <- c("brief", "value", "budget", "readiness", "recommend")
EQALB_PART2_STEP_NAMES <- c(
  "Case brief", "Value for money", "Budget impact", "DHT readiness",
  "Recommendation"
)
EQALB_PART2_AVAILABLE_STEPS <- c("brief", "value", "budget", "readiness", "recommend")

# Readiness levels: the short answers the readiness exercise accepts, each mapped
# onto the input calculate_readiness() already takes, so the exercise reuses the
# existing thresholds instead of introducing new rules. The names are what the
# client sends; the mapping stays R's.
EQALB_PART2_INTEROP_LEVELS <- c(
  no = "No data exchange",
  basic = "PDF/manual export",
  strong = "FHIR-based exchange"
)
EQALB_PART2_GOVERNANCE_LEVELS <- c(
  weak = "Continuously learning algorithm",
  partial = "Periodic controlled updates",
  strong = "Locked algorithm"
)

# The workflow-fit answers and the review minutes each one means. `moderate` is
# the case's own review time rather than a fixed number, so the same answer reads
# differently in a case with a different workload; the other two are constants.
EQALB_PART2_WORKFLOW_MINUTES <- c(low = 4, moderate = NA_real_, high = 20)
EQALB_PART2_ENGAGEMENT_PCT <- c(low = 30, moderate = 60, high = 90)

# --- Part 2 cases -----------------------------------------------------------

# Three complete, internally consistent commissioning cases. Each case is one
# set of facts: the values are chosen together so a price inside the lever's
# range can still meet the payer's threshold, and each case presents a different
# amount of headroom. Values are never mixed between cases.
#
# `case_id` is the opaque handle a client stores and echoes back. It carries no
# meaning of its own: only this module knows which case it belongs to, so a
# client cannot select a case, and the draw stays R's.
#
# The utilities are the case's own values (not the model defaults and not a
# dashboard setting), so a case's per-person result cannot change when the
# application's assumptions are edited.
eqalb_part2_cases <- function() {
  list(
    list(
      case_id = "p2c-4d81a0",
      label = "Case A",
      title = "Regional roll-out",
      summary = paste(
        "A regional roll-out of 100,000 potentially eligible people with",
        "moderate evidence and FHIR-based interoperability."
      ),
      rrr = 0.10,
      year1_engagement = 70,
      followup_engagement = 42,
      utility_no_event = 0.86,
      utility_post_mi = 0.80,
      utility_post_stroke = 0.60,
      population = 100000,
      review_minutes = 10,
      languages = 3
    ),
    list(
      case_id = "p2c-9be2f5",
      label = "Case B",
      title = "Integrated pilot",
      summary = paste(
        "A smaller integrated pilot of 80,000 people with stronger evidence and",
        "better follow-up engagement, so a wider range of prices still meets the",
        "value-for-money test."
      ),
      rrr = 0.15,
      year1_engagement = 80,
      followup_engagement = 60,
      utility_no_event = 0.88,
      utility_post_mi = 0.82,
      utility_post_stroke = 0.62,
      population = 80000,
      review_minutes = 8,
      languages = 4
    ),
    list(
      case_id = "p2c-13c7d2",
      label = "Case C",
      title = "Fragmented deployment",
      summary = paste(
        "A wider deployment of 140,000 people with weaker evidence and fewer",
        "supported languages, so fewer prices meet the value-for-money test and",
        "less coverage fits the budget."
      ),
      rrr = 0.12,
      year1_engagement = 65,
      followup_engagement = 40,
      utility_no_event = 0.85,
      utility_post_mi = 0.79,
      utility_post_stroke = 0.59,
      population = 140000,
      review_minutes = 14,
      languages = 2
    )
  )
}

# One case by its opaque handle. An unknown or expired handle is an R error, so a
# client can never be given a silently substituted case.
eqalb_part2_case <- function(case_id) {
  if (is.null(case_id) || length(case_id) != 1L || is.na(case_id)) {
    stop("A Part 2 request must carry a case id.", call. = FALSE)
  }
  handle <- as.character(case_id)
  cases <- eqalb_part2_cases()
  for (case in cases) {
    if (identical(case$case_id, handle)) {
      return(case)
    }
  }
  stop(
    "Unknown or expired Part 2 case id '", handle, "'.", call. = FALSE
  )
}

# Draws a case for a new session. `exclude_case_id` is the legacy retry rule -
# a retry must present a different commissioning position - and `seed` exists so
# a fixture can pin the draw; the interface never sends one. The draw itself is
# R's, and only the opaque handle leaves this module.
eqalb_part2_select_case <- function(exclude_case_id = NULL, seed = NULL) {
  cases <- eqalb_part2_cases()
  handles <- vapply(cases, function(case) case$case_id, character(1))
  candidates <- handles
  if (!is.null(exclude_case_id) && length(exclude_case_id) == 1L &&
        !is.na(exclude_case_id)) {
    candidates <- setdiff(handles, as.character(exclude_case_id))
    if (length(candidates) == 0L) {
      candidates <- handles
    }
  }
  if (!is.null(seed) && length(seed) == 1L && !is.na(seed)) {
    # A local seed keeps the global random stream untouched, so a fixture draw
    # cannot change any other random result in the session.
    drawn <- local({
      set.seed(as.integer(seed))
      sample(candidates, 1L)
    })
  } else {
    drawn <- sample(candidates, 1L)
  }
  list(
    case_id = drawn,
    candidates = length(candidates),
    excluded = if (length(candidates) < length(handles)) {
      as.character(exclude_case_id)
    } else {
      ""
    }
  )
}

# --- Part 2 case facts ------------------------------------------------------

# The read-only case facts. Every value comes from the case that also supplies
# the model inputs, so the table cannot drift from the numbers the case produces.
eqalb_part2_case_facts <- function(case) {
  data.frame(
    group = c(
      rep("Clinical evidence", 6L),
      rep("Implementation setting", 4L),
      rep("Decision criteria", 4L)
    ),
    fact = c(
      "Relative risk reduction", "Year-1 engagement",
      "Follow-up engagement", "No-event utility", "Post-MI utility",
      "Post-stroke utility", "Potentially eligible population",
      "Clinician review time", "Interoperability",
      "Required-language availability",
      "Manufacturer's reference price", "WTP threshold",
      "Five-year budget ceiling", "Red readiness domains allowed"
    ),
    value = c(
      paste0(format(case$rrr * 100, trim = TRUE), "%"),
      paste0(format(case$year1_engagement, trim = TRUE), "%"),
      paste0(format(case$followup_engagement, trim = TRUE), "%"),
      format(round(case$utility_no_event, 2), nsmall = 2),
      format(round(case$utility_post_mi, 2), nsmall = 2),
      format(round(case$utility_post_stroke, 2), nsmall = 2),
      format(case$population, big.mark = ",", scientific = FALSE),
      paste0(case$review_minutes, " minutes per patient per month"),
      "Yes",
      if (case$languages >= 3) "Yes" else "No",
      paste0(
        eqalb_tutorial_money(EQALB_PART2_PRICE_MIN),
        " per active user per year"
      ),
      paste0(eqalb_tutorial_money(EQALB_PART2_WTP), " per QALY"),
      eqalb_tutorial_money(EQALB_PART2_BUDGET_CEILING),
      "None"
    ),
    stringsAsFactors = FALSE
  )
}

# The case facts as the interface renders them: one row per fact, in order.
eqalb_part2_facts_payload <- function(case) {
  facts <- eqalb_part2_case_facts(case)
  lapply(seq_len(nrow(facts)), function(index) {
    list(
      group = facts$group[index],
      fact = facts$fact[index],
      value = facts$value[index]
    )
  })
}

# --- Part 2 scenario arguments ---------------------------------------------

# The model arguments for one case at one price. The tutorial's own fixed values
# supply the implementation cost and the healthcare savings, exactly as Part 1
# does, so both parts of the tutorial describe the same programme; everything
# else is the case's own.
eqalb_part2_model_args <- function(case, price) {
  fixed <- eqalb_tutorial_fixed()
  list(
    scenario_intervention_price = price,
    scenario_implementation_cost = fixed$implementation_cost,
    scenario_healthcare_savings = fixed$healthcare_savings,
    scenario_rrr = case$rrr,
    scenario_engagement_year1 = case$year1_engagement / 100,
    scenario_engagement_followup = case$followup_engagement / 100,
    scenario_utility_no_event = case$utility_no_event,
    scenario_utility_post_mi = case$utility_post_mi,
    scenario_utility_post_stroke = case$utility_post_stroke
  )
}

# --- Part 2 value-for-money rules ------------------------------------------

# The payer's test: the additional health gained must be worth the additional
# cost at the stated threshold. It is the ICER against the threshold with
# positive incremental QALYs - never a test of the price against the
# manufacturer's minimum - so any negotiated price that meets the threshold
# passes.
eqalb_part2_value_for_money <- function(incremental_cost, incremental_qalys) {
  if (length(incremental_cost) == 0L || length(incremental_qalys) == 0L ||
        is.na(incremental_cost) || is.na(incremental_qalys)) {
    return(FALSE)
  }
  incremental_qalys > 0 && (incremental_cost / incremental_qalys) <=
    EQALB_PART2_WTP
}

# The price range the curve is drawn over, as whole lever values.
eqalb_part2_price_values <- function() {
  seq(EQALB_PART2_PRICE_MIN, EQALB_PART2_PRICE_MAX, by = EQALB_PART2_PRICE_STEP)
}

# The deterministic ICER across the whole lever range. Every point comes from
# run_eqalb_model() with the case's fixed facts, so no equation is repeated here.
# The curve does not depend on the learner's price: moving the lever moves the
# marker, not the curve.
eqalb_part2_price_curve <- function(case) {
  prices <- eqalb_part2_price_values()
  points <- lapply(prices, function(price) {
    result <- do.call(run_eqalb_model, eqalb_part2_model_args(case, price))
    icer_finite <- is.finite(result$icer)
    meets <- eqalb_part2_value_for_money(
      result$incremental_cost, result$incremental_qalys
    )
    list(
      price = price,
      key = paste0("price-", format(price, trim = TRUE)),
      incremental_cost = result$incremental_cost,
      incremental_qalys = result$incremental_qalys,
      icer = if (icer_finite) result$icer else NA_real_,
      icer_display = if (icer_finite) {
        eqalb_tutorial_money(result$icer)
      } else {
        EQALB_TUTORIAL_ICER_UNAVAILABLE
      },
      # The two series R decides: a point either meets the payer's threshold or
      # it does not. The client never classifies a point itself.
      series_key = if (meets) "meets" else "above",
      meets = meets
    )
  })

  meeting <- vapply(
    points,
    function(point) isTRUE(point$meets) && is.finite(point$icer),
    logical(1)
  )
  maximum <- if (any(meeting)) {
    max(vapply(
      points[meeting], function(point) point$price, numeric(1)
    ))
  } else {
    NA_real_
  }

  list(
    # The case the curve belongs to. It is returned with the curve and required
    # when a curve is posted back, so a curve can never be re-classified against a
    # different case: the 43 lever prices are the same for every case, so without
    # this binding a mismatched pair would silently produce another case's numbers.
    case_id = case$case_id,
    points = points,
    point_count = length(points),
    max_acceptable_price = maximum,
    max_acceptable_price_display = if (is.na(maximum)) {
      EQALB_TUTORIAL_STATUS_NOT_AVAILABLE
    } else {
      eqalb_tutorial_money(maximum)
    },
    threshold = EQALB_PART2_WTP
  )
}

# Canonicalises a price curve the client posted back, so a price change costs one
# model run instead of forty-four. The client can only send the model outputs R
# itself produced a moment earlier (the `case` response carries them), and R
# re-derives the two decision values from those outputs with its own rule: which
# points meet the payer's threshold and the highest acceptable price are R's
# classification, never the caller's. A payload that is not the lever's own price
# list, or whose model outputs are not usable numbers, is an R error.
eqalb_part2_curve_from_payload <- function(payload, case) {
  if (is.null(payload) || !is.list(payload)) {
    stop(
      "A supplied 'curve' must be the curve object returned for this case.",
      call. = FALSE
    )
  }
  # The curve is bound to the case it was computed for. The lever's 43 prices are
  # identical for every case, so without this check a curve computed for one case
  # could be re-classified under another and return that other case's numbers
  # under this case's name.
  supplied_case <- payload[["case_id"]]
  if (is.null(supplied_case) || length(supplied_case) != 1L ||
        is.na(supplied_case) ||
        !identical(as.character(supplied_case), case$case_id)) {
    stop(
      paste(
        "A supplied 'curve' must be the curve returned for this case: its",
        "'case_id' must match the requested case."
      ),
      call. = FALSE
    )
  }
  points <- payload[["points"]]
  # An array of same-shaped objects is simplified into a data frame by the JSON
  # reader the route handlers use, so the rows are taken back out of it here. Both
  # shapes are the same request: a client does not control which one arrives.
  if (is.data.frame(points)) {
    points <- lapply(
      seq_len(nrow(points)),
      function(index) as.list(points[index, , drop = FALSE])
    )
  } else if (is.matrix(points)) {
    points <- lapply(
      seq_len(nrow(points)),
      function(index) as.list(points[index, , drop = FALSE])
    )
  }
  if (is.null(points) || !is.list(points)) {
    stop("A supplied 'curve' must carry its 'points' array.", call. = FALSE)
  }
  prices <- eqalb_part2_price_values()
  if (length(points) != length(prices)) {
    stop(
      sprintf(
        "A supplied 'curve' must carry exactly %d points, one per lever value.",
        length(prices)
      ),
      call. = FALSE
    )
  }

  canonical <- lapply(seq_along(prices), function(index) {
    price <- prices[[index]]
    point <- points[[index]]
    supplied_price <- suppressWarnings(as.numeric(point[["price"]]))
    if (length(supplied_price) != 1L || is.na(supplied_price) ||
          abs(supplied_price - price) > 1e-9) {
      stop(
        sprintf(
          "Supplied curve point %d must be the lever value %s.",
          index, format(price, trim = TRUE)
        ),
        call. = FALSE
      )
    }
    cost <- suppressWarnings(as.numeric(point[["incremental_cost"]]))
    qalys <- suppressWarnings(as.numeric(point[["incremental_qalys"]]))
    if (length(cost) != 1L || is.na(cost) || !is.finite(cost) ||
          length(qalys) != 1L || is.na(qalys) || !is.finite(qalys)) {
      stop(
        sprintf(
          paste(
            "Supplied curve point %d must carry finite 'incremental_cost' and",
            "'incremental_qalys' values."
          ),
          index
        ),
        call. = FALSE
      )
    }
    icer <- if (qalys == 0) NA_real_ else cost / qalys
    icer_finite <- is.finite(icer)
    meets <- eqalb_part2_value_for_money(cost, qalys)
    list(
      price = price,
      key = paste0("price-", format(price, trim = TRUE)),
      incremental_cost = cost,
      incremental_qalys = qalys,
      icer = if (icer_finite) icer else NA_real_,
      icer_display = if (icer_finite) {
        eqalb_tutorial_money(icer)
      } else {
        EQALB_TUTORIAL_ICER_UNAVAILABLE
      },
      series_key = if (meets) "meets" else "above",
      meets = meets
    )
  })

  meeting <- vapply(
    canonical,
    function(point) isTRUE(point$meets) && is.finite(point$icer),
    logical(1)
  )
  maximum <- if (any(meeting)) {
    max(vapply(canonical[meeting], function(point) point$price, numeric(1)))
  } else {
    NA_real_
  }

  list(
    case_id = case$case_id,
    points = canonical,
    point_count = length(canonical),
    max_acceptable_price = maximum,
    max_acceptable_price_display = if (is.na(maximum)) {
      EQALB_TUTORIAL_STATUS_NOT_AVAILABLE
    } else {
      eqalb_tutorial_money(maximum)
    },
    threshold = EQALB_PART2_WTP,
    source = "client-supplied model outputs, re-classified in R"
  )
}

# --- Part 2 current-price result -------------------------------------------
# The current-price card: the three states the learner's lever can be in, the
# model detail behind them and the nudge that points at the one lever that can
# change the case.
eqalb_part2_price_result <- function(case, price, curve) {
  result <- do.call(run_eqalb_model, eqalb_part2_model_args(case, price))
  icer_finite <- is.finite(result$icer)
  passed <- eqalb_part2_value_for_money(
    result$incremental_cost, result$incremental_qalys
  )
  best <- curve$max_acceptable_price
  # "At the answer" means passing at the highest lever value that still passes:
  # it is read from the curve, so the learner's own lever never defines it.
  at_max <- passed && !is.na(best) && abs(price - best) < 1e-9

  state <- if (at_max) {
    "at_max"
  } else if (passed) {
    "below_max"
  } else {
    "over"
  }
  strings <- eqalb_part2_price_strings()

  list(
    price = price,
    price_display = eqalb_tutorial_money(price),
    passed = passed,
    at_max = at_max,
    state = state,
    state_label = strings$states[[state]]$label,
    state_message = strings$states[[state]]$message,
    state_hint = if (identical(state, "below_max")) strings$below_max_hint else "",
    incremental_cost = result$incremental_cost,
    incremental_qalys = result$incremental_qalys,
    icer = if (icer_finite) result$icer else NA_real_,
    icer_display = if (icer_finite) {
      eqalb_tutorial_money(result$icer)
    } else {
      EQALB_TUTORIAL_ICER_UNAVAILABLE
    },
    detail = paste0(
      "Incremental cost ", eqalb_tutorial_money_signed(result$incremental_cost),
      " per person; incremental QALYs ",
      eqalb_tutorial_qalys(result$incremental_qalys), "; ",
      if (icer_finite) {
        paste0(eqalb_tutorial_money(result$icer), " per QALY")
      } else {
        paste0(
          "ICER not interpretable because incremental QALYs are not positive"
        )
      },
      " against a threshold of ", eqalb_tutorial_money(EQALB_PART2_WTP),
      " per QALY."
    ),
    threshold = EQALB_PART2_WTP
  )
}

# --- Part 2 budget-impact rules --------------------------------------------

# The coverage cap is a percentage of the potentially eligible population, held
# inside its own permitted range. An absent value takes the tutorial default, so a
# request that has not chosen a cap still evaluates.
eqalb_part2_coverage_pct <- function(coverage) {
  cap <- suppressWarnings(as.numeric(coverage))
  if (length(cap) != 1L || is.na(cap) || !is.finite(cap)) {
    cap <- EQALB_PART2_COVERAGE_DEFAULT
  }
  min(max(cap, EQALB_PART2_COVERAGE_MIN), EQALB_PART2_COVERAGE_MAX)
}

# The population the case's budget impact is calculated over at a coverage cap.
# Only the budget calculation scales with the cap: the per-person model result and
# the price curve are unaffected.
eqalb_part2_covered_population <- function(coverage, population) {
  population * eqalb_part2_coverage_pct(coverage) / 100
}

# The permitted coverage steps, highest first. The scan walks these in order, so
# "the highest affordable cap" is found by the rule itself rather than by
# inverting the budget formula.
eqalb_part2_coverage_steps <- function() {
  seq(
    EQALB_PART2_COVERAGE_MAX, EQALB_PART2_COVERAGE_MIN,
    by = -EQALB_PART2_COVERAGE_STEP
  )
}

# The annual budget-impact rows for one case at one price and one coverage cap.
# calculate_budget_impact() is unchanged: the fixed values the tutorial supplies
# are the ones the contract publishes, and the cap scales the population only.
eqalb_part2_bia_for <- function(case, price, coverage) {
  fixed <- eqalb_tutorial_fixed()
  calculate_budget_impact(
    population = eqalb_part2_covered_population(coverage, case$population),
    year1_uptake_pct = EQALB_PART2_BIA_YEAR1_UPTAKE_PCT,
    annual_uptake_increase_pp = EQALB_PART2_BIA_ANNUAL_UPTAKE_INCREASE_PP,
    horizon_years = EQALB_PART2_BIA_HORIZON_YEARS,
    intervention_price = price,
    implementation_cost_per_new_user = fixed$implementation_cost,
    healthcare_savings_per_active_user = fixed$healthcare_savings,
    avoided_event_savings_per_active_user =
      EQALB_PART2_BIA_AVOIDED_EVENT_SAVINGS_PER_ACTIVE_USER,
    followup_engagement_pct = case$followup_engagement
  )
}

# The five-year net budget impact at a coverage cap and price.
eqalb_part2_bia_total <- function(case, price, coverage) {
  sum(eqalb_part2_bia_for(case, price, coverage)$net_budget_impact)
}

# The affordability test: the five-year net budget impact must fit the payer's
# ceiling. It is the only rule the budget section applies.
eqalb_part2_affordability_pass <- function(cumulative_budget_impact) {
  if (length(cumulative_budget_impact) == 0L ||
        is.na(cumulative_budget_impact)) {
    return(FALSE)
  }
  cumulative_budget_impact <= EQALB_PART2_BUDGET_CEILING
}

# The highest permitted coverage step that still fits the ceiling at this price.
# It is found by evaluating the permitted steps from the highest down, which is
# the rule itself rather than an inverted formula; NA means even the lowest step
# does not fit, which is a reachable state for a high price and a large case.
eqalb_part2_max_affordable_coverage <- function(case, price) {
  for (coverage in eqalb_part2_coverage_steps()) {
    if (eqalb_part2_affordability_pass(
      eqalb_part2_bia_total(case, price, coverage)
    )) {
      return(coverage)
    }
  }
  NA_real_
}

# The annual rows and the chart series for one case, price and coverage cap. Every
# value is R's; the client plots what it is given.
eqalb_part2_bia_rows <- function(case, price, coverage) {
  result <- eqalb_part2_bia_for(case, price, coverage)
  lapply(seq_len(nrow(result)), function(index) {
    list(
      year = result$year[index],
      # The key the chart and the table map on, so no row is matched by position.
      key = paste0("year-", result$year[index]),
      eligible_population = result$eligible_population[index],
      uptake_pct = result$uptake_pct[index],
      cumulative_users = result$cumulative_users[index],
      new_users = result$new_users[index],
      active_users = result$active_users[index],
      active_users_display =
        format(round(result$active_users[index]), big.mark = ","),
      gross_intervention_cost = result$gross_intervention_cost[index],
      implementation_cost = result$implementation_cost[index],
      healthcare_savings = result$healthcare_savings[index],
      avoided_event_savings = result$avoided_event_savings[index],
      net_budget_impact = result$net_budget_impact[index],
      net_budget_impact_display = eqalb_tutorial_money_signed(
        result$net_budget_impact[index]
      ),
      cumulative_budget_impact = result$cumulative_budget_impact[index],
      cumulative_display = eqalb_tutorial_money_signed(
        result$cumulative_budget_impact[index]
      )
    )
  })
}

# --- Part 2 budget-impact wording -------------------------------------------

# The wording of the budget-impact section: its task, its three affordability
# states, the summary and the annual table. All of it is R's, including the
# status words the interface shows, so the client never phrases an
# affordability judgement itself.
eqalb_part2_budget_strings <- function() {
  list(
    task = paste(
      "Your task: after agreeing a value-for-money price, find the highest",
      "programme coverage that stays within the €3 million five-year budget."
    ),
    note = paste(
      "A technology can be cost-effective per person but still exceed the",
      "payer's near-term budget when adopted across a large population."
    ),
    scope_note = paste(
      "The coverage cap scales this case's budget-impact population only. It",
      "does not change the per-person result or the value-for-money answer."
    ),
    lever_label = "Negotiated annual price used in this case",
    coverage_label = "Programme coverage cap",
    coverage_sentence_template = paste0(
      "Coverage cap: {coverage}% of the potentially eligible population."
    ),
    population_template = paste0(
      "Potentially eligible population: {population} people."
    ),
    covered_template = paste0(
      "Covered population: {covered} people at this coverage cap."
    ),
    full_rollout_template = paste0(
      "Full rollout means coverage of all {population} potentially eligible",
      " people. A lower cap represents phased adoption, not a change in the",
      " clinical evidence or in the per-person result."
    ),
    states = list(
      over = list(
        label = "Above the available five-year budget.",
        message = "Above the available five-year budget."
      ),
      below_max = list(
        label = "Within budget.",
        message = "Within budget."
      ),
      at_max = list(
        label = "Maximum affordable coverage achieved.",
        message = "Maximum affordable coverage achieved."
      )
    ),
    maximum_label = "Maximum affordable coverage at this price",
    maximum_none = paste0(
      "none — even the lowest coverage step exceeds the ",
      "€3,000,000 five-year budget at this price"
    ),
    maximum_reached_hint = paste(
      "Coverage is at the highest step that stays within the budget at this",
      "price."
    ),
    increase_hint = paste(
      "Increase the coverage cap to find the highest affordable coverage at",
      "this price."
    ),
    summary_template = "Net budget impact over {years} years: {total}.",
    chart = list(
      title = "Budget impact analysis: annual net budget impact",
      caption = paste(
        "Annual net budget impact for this case at the selected coverage cap,",
        "with the cumulative position over the horizon."
      ),
      x_label = "Year",
      y_label = "Annual net budget impact (€)",
      cumulative_label = "Cumulative net budget impact",
      annual_label = "Net budget impact (per year)",
      cost_label = "Net cost",
      saving_label = "Net saving"
    ),
    table = list(
      disclosure_label = "View annual breakdown",
      caption = "Annual budget impact for this case",
      headings = list(
        year = "Year",
        activated_users = "Active users",
        net_budget_impact = "Net budget impact",
        cumulative = "Cumulative net budget impact"
      )
    ),
    price_shortcut_label = "Change negotiated price",
    price_shortcut_note = paste(
      "Value for money has not been achieved at the current price, so a lower",
      "price is what would change this case."
    )
  )
}

# The budget-impact status the current coverage cap produces, and the two
# sentences that describe the case's population.
eqalb_part2_budget_result <- function(case, price, coverage, strings) {
  coverage <- eqalb_part2_coverage_pct(coverage)
  covered <- eqalb_part2_covered_population(coverage, case$population)
  rows <- eqalb_part2_bia_rows(case, price, coverage)
  total <- eqalb_part2_bia_total(case, price, coverage)
  best <- eqalb_part2_max_affordable_coverage(case, price)

  affordable <- eqalb_part2_affordability_pass(total)
  at_max <- affordable && !is.na(best) &&
    identical(as.numeric(coverage), as.numeric(best))
  state <- if (at_max) {
    "at_max"
  } else if (affordable) {
    "below_max"
  } else {
    "over"
  }

  list(
    coverage = coverage,
    covered_population = covered,
    population = case$population,
    horizon_years = length(rows),
    total = total,
    total_display = eqalb_tutorial_money_signed(total),
    affordable = affordable,
    at_max = at_max,
    state = state,
    state_label = strings$states[[state]]$label,
    state_message = strings$states[[state]]$message,
    state_hint = if (identical(state, "over")) {
      strings$increase_hint
    } else if (identical(state, "below_max")) {
      strings$increase_hint
    } else {
      strings$maximum_reached_hint
    },
    max_affordable_coverage = best,
    max_affordable_coverage_display = if (is.na(best)) {
      EQALB_TUTORIAL_STATUS_NOT_AVAILABLE
    } else {
      paste0(format(best, trim = TRUE), "%")
    },
    budget_ceiling = EQALB_PART2_BUDGET_CEILING,
    budget_ceiling_display = eqalb_tutorial_money(EQALB_PART2_BUDGET_CEILING)
  )
}

# --- Part 2 readiness exercise ---------------------------------------------

# One readiness answer from the request. An absent answer takes the exercise's
# default; a value that is not one of the accepted short names is R's error, so an
# invalid answer cannot be read as a level.
eqalb_part2_readiness_choice <- function(body, name, levels, default) {
  value <- body[[name]]
  if (is.null(value) || (length(value) == 1L && is.na(value))) {
    return(default)
  }
  if (!is.character(value) || length(value) != 1L || !value %in% names(levels)) {
    stop(sprintf(
      "'%s' must be one of: %s.", name, paste(names(levels), collapse = ", ")
    ), call. = FALSE)
  }
  value
}

# The follow-up engagement answer restated as the level it represents. It is read
# from the same percentage that drives the Engagement domain, so the wording can
# never disagree with the traffic light beside it.
eqalb_part2_engagement_note <- function(pct) {
  level <- if (pct >= EQALB_PART2_ENGAGEMENT_PCT[["high"]]) {
    "high"
  } else if (pct >= EQALB_PART2_ENGAGEMENT_PCT[["moderate"]]) {
    "moderate"
  } else {
    "low"
  }
  paste0("Follow-up engagement is ", level, ".")
}

# The DHT readiness exercise's own result. The four answers are mapped onto the
# inputs calculate_readiness() takes and the shared function decides every status,
# so the traffic lights here are the same rule the full readiness assessment uses.
# The answers reach the readiness assessment only: the price, the curve, the
# budget impact and the model result are untouched. Part 2 is isolated from the
# dashboard, so the three inputs the reference exercise read from the full
# analysis are the tutorial's own fixed values, and the workflow and engagement
# answers are mapped by R rather than sent as inputs.
eqalb_part2_readiness <- function(case, body) {
  fixed <- eqalb_tutorial_fixed()
  interoperability <- eqalb_part2_readiness_choice(
    body, "interoperability", EQALB_PART2_INTEROP_LEVELS, "strong"
  )
  governance <- eqalb_part2_readiness_choice(
    body, "governance", EQALB_PART2_GOVERNANCE_LEVELS, "partial"
  )
  workflow <- eqalb_part2_readiness_choice(
    body, "clinical_workflow", EQALB_PART2_WORKFLOW_MINUTES, "moderate"
  )
  engagement <- eqalb_part2_readiness_choice(
    body, "patient_engagement", EQALB_PART2_ENGAGEMENT_PCT, "low"
  )

  review_minutes <- EQALB_PART2_WORKFLOW_MINUTES[[workflow]]
  if (is.na(review_minutes)) {
    review_minutes <- case$review_minutes
  }
  followup_pct <- EQALB_PART2_ENGAGEMENT_PCT[[engagement]]

  readiness <- calculate_readiness(
    target_population = case$population,
    digital_access = fixed$digital_access_pct,
    digital_suitability = fixed$digital_suitability_pct,
    readiness_year1_engagement = case$year1_engagement,
    readiness_followup_engagement = followup_pct,
    review_minutes = review_minutes,
    supported_languages = case$languages,
    accessibility_features = fixed$accessibility_features,
    interoperability = EQALB_PART2_INTEROP_LEVELS[[interoperability]],
    algorithm_governance = EQALB_PART2_GOVERNANCE_LEVELS[[governance]]
  )

  measure_value <- function(measure) {
    hit <- readiness$numbers$Value[readiness$numbers$Measure == measure]
    if (length(hit) == 0L) "" else hit[[1]]
  }
  deliverable <- !any(readiness$domains$Status == "Red")

  list(
    choices = list(
      interoperability = interoperability,
      governance = governance,
      clinical_workflow = workflow,
      patient_engagement = engagement
    ),
    inputs = list(
      interoperability = EQALB_PART2_INTEROP_LEVELS[[interoperability]],
      algorithm_governance = EQALB_PART2_GOVERNANCE_LEVELS[[governance]],
      review_minutes = review_minutes,
      followup_engagement_pct = followup_pct
    ),
    domains = lapply(seq_len(nrow(readiness$domains)), function(index) {
      list(
        domain = readiness$domains$Domain[index],
        status = readiness$domains$Status[index]
      )
    }),
    numbers = lapply(seq_len(nrow(readiness$numbers)), function(index) {
      list(
        measure = readiness$numbers$Measure[index],
        value = readiness$numbers$Value[index]
      )
    }),
    deliverability = list(
      passed = deliverable,
      label = if (deliverable) "Pass" else "Not yet achieved"
    ),
    note = paste0(
      "At these choices: ", measure_value("Active users at year 1"),
      " active users in year 1 and ", measure_value("Active users at follow-up"),
      " at follow-up, needing ", measure_value("Annual clinician-review hours"),
      " clinician-review hours a year."
    ),
    engagement_note = eqalb_part2_engagement_note(followup_pct)
  )
}

# --- Part 2 recommendation --------------------------------------------------

# The commissioning outcomes, chosen from the three criteria and the selected
# coverage cap in the reference tutorial's own order and wording. The three
# economic tests are separate questions, so the message names the first one that
# fails rather than blending them; when all three hold but the cap is below the
# highest affordable cap the wording must not claim the rollout is maximised, so
# that case gets its own message and no completion. Only the last outcome
# completes the case, and `complete` says so rather than the client inferring it
# from the status.
eqalb_part2_recommendation <- function(
  value_for_money, affordability, deliverability,
  coverage_maximised = TRUE, max_coverage = NA_real_
) {
  outcome <- if (!isTRUE(value_for_money)) {
    list(
      status = "do_not_recommend",
      headline = "Do not recommend adoption at the current price",
      message = paste(
        "Do not recommend adoption at the current price. The expected health",
        "gain does not yet justify the additional cost at the payer's",
        "threshold."
      )
    )
  } else if (!isTRUE(affordability)) {
    list(
      status = "negotiate_price",
      headline = "Value for money is acceptable, but affordability is not",
      message = paste(
        "Value for money is acceptable, but full or current rollout exceeds the",
        "available five-year budget. Consider a lower negotiated price or a",
        "phased rollout."
      )
    )
  } else if (!isTRUE(deliverability)) {
    list(
      status = "resolve_barriers",
      headline = "Economic criteria are met, but implementation barriers remain",
      message = paste(
        "Economic criteria are met, but implementation barriers must be",
        "resolved before adoption."
      )
    )
  } else if (!isTRUE(coverage_maximised)) {
    list(
      status = "increase_coverage",
      headline = paste(
        "Recommended outcome: Conditional adoption, coverage not maximised"
      ),
      message = paste0(
        "The negotiated price provides acceptable value for money and the ",
        "programme stays within the available five-year budget. Coverage can ",
        "be increased",
        if (is.na(max_coverage)) {
          "."
        } else {
          paste0(" to ", format(max_coverage, trim = TRUE), "%")
        },
        " to maximise patient access without exceeding the budget."
      )
    )
  } else {
    list(
      status = "conditional_adoption",
      headline = "Recommended outcome: Conditional adoption",
      message = paste(
        "The negotiated price provides acceptable value for money. The phased",
        "rollout maximises patient access while keeping expected five-year",
        "spending within the available budget, and there are no Red readiness",
        "barriers."
      )
    )
  }

  outcome$complete <- identical(outcome$status, "conditional_adoption")
  outcome
}

# The wording of the value-for-money section: its task, its three states and the
# chart's labels. All of it is R's, and the chart's series colours are R's too,
# so the interface never decides what passes or how a passing point looks.
eqalb_part2_price_strings <- function() {
  list(
    task = paste(
      "Find the highest annual price that remains cost-effective at the payer's",
      "€100,000/QALY threshold."
    ),
    note = paste(
      "This test asks whether the additional health gained is worth the",
      "additional cost at the payer's stated threshold. It is a per-person test,",
      "so it does not change with the rollout coverage cap."
    ),
    lever_hint = paste(
      "This is the case's price lever. It applies to this case only: Part 1 and",
      "the full analysis keep their own price values. The test is the ICER",
      "against €100,000 per QALY, so the answer is the highest price on the",
      "slider that still passes for this case."
    ),
    method_note = paste(
      "Every point on the curve is a separate model run at that price with this",
      "case's fixed facts, so the curve describes this case only."
    ),
    states = list(
      at_max = list(
        label = "Maximum acceptable negotiated price reached.",
        message = "Maximum acceptable negotiated price reached."
      ),
      below_max = list(
        label = "Value for money achieved, but not at the highest passing price",
        message = "Value for money achieved, but not at the highest passing price"
      ),
      over = list(
        label = "This price is above the value-for-money threshold.",
        message = "This price is above the value-for-money threshold."
      )
    ),
    below_max_hint = paste(
      "Increase the price to find the highest acceptable negotiated price."
    ),
    maximum_label = "Highest acceptable negotiated price",
    threshold_label = "€100,000/QALY",
    chart = list(
      title = "Deterministic ICER across the negotiated price range",
      caption = paste(
        "Each point is the model's ICER at that annual price with this case's",
        "fixed facts. The dashed line is the payer's threshold."
      ),
      x_label = "Negotiated annual price (EUR per active user per year)",
      y_label = "ICER (EUR per QALY)",
      # An unnamed list, so it reaches the client as an array it can iterate. Each
      # entry carries R's own key, legend label and colour.
      series = list(
        list(key = "meets", label = "Meets the threshold", colour = "#1e7d45"),
        list(key = "above", label = "Above the threshold", colour = "#7a8b93")
      ),
      threshold_line = list(
        value = EQALB_PART2_WTP,
        colour = "#b02a37",
        dash = "dashed",
        label = "€100,000/QALY"
      ),
      marker = list(
        colour = "#d9480f",
        label = "Selected price"
      )
    )
  )
}

# --- Part 2 contract --------------------------------------------------------

# The static Part 2 contract: everything the interface needs before (and
# alongside) a case. No model run and no case draw happens to build it.
eqalb_tutorial_part2_contract <- function() {
  sections <- lapply(seq_along(EQALB_PART2_STEP_KEYS), function(index) {
    key <- EQALB_PART2_STEP_KEYS[[index]]
    list(
      key = key,
      name = EQALB_PART2_STEP_NAMES[[index]],
      available = key %in% EQALB_PART2_AVAILABLE_STEPS
    )
  })

  list(
    part2 = list(
      title = "Commissioning case challenge",
      kicker = "Guided tutorial Part 2",
      sections = sections,
      available_sections = as.list(EQALB_PART2_AVAILABLE_STEPS),
      coming_next_label = "Coming next",
      coming_next_note = paste(
        "This slice of the tutorial covers all five sections: the case brief,",
        "the value-for-money exercise, the budget-impact exercise, the DHT",
        "readiness exercise and the recommendation."
      ),
      # The minimal Part 1 integration point: the label and the sentence the
      # Part 1 completion card shows for its Part 2 entry action. They live in
      # this contract so Part 1's own response is unchanged.
      entry_label = "Start Part 2: Commissioning case",
      entry_note = paste(
        "Optional next step: a short commissioning case that shows why value for",
        "money, affordability and readiness are separate tests. This slice covers",
        "the case brief, the value-for-money exercise, the budget-impact exercise,",
        "the DHT readiness exercise and the recommendation."
      ),
      entry_busy_label = "Preparing the case…",
      progress = list(
        total = length(EQALB_PART2_STEP_KEYS),
        step_template = "Section {step} of {total}. {name}",
        available_template = paste(
          "Section {step} of {total}. {name} — this slice covers the first",
          "{available} sections."
        )
      ),
      navigation = list(
        back = "Back",
        forward = "Next",
        exit = "Exit tutorial"
      ),
      case_banner_template = "Active case: {label} — {title}",
      case_facts = list(
        button_label = "Case facts",
        title_template = "Case facts — {label} — {title}",
        close_label = "Close",
        table_headings = list(group = "Group", fact = "Fact", value = "Value"),
        hint = paste(
          "These case facts are fixed. The negotiated annual price and the",
          "programme coverage cap are the case's adjustable levers. The",
          "manufacturer's reference price is a starting point for negotiation.",
          "Your task is to recommend a price and initial coverage level that",
          "offer value for money, fit the available budget, and can be",
          "delivered in practice."
        )
      ),
      brief = list(
        heading = "Case brief",
        controls_heading = "Fixed case facts (not editable)",
        intro_template = paste0(
          "eQalb is being considered for regional adoption to reduce ",
          "cardiovascular events among eligible adults. {summary} Evidence ",
          "suggests a {rrr}% relative reduction in event risk among engaged ",
          "users. Engagement, clinical evidence, local workflow, and digital ",
          "access are fixed for this case."
        ),
        policy = paste(
          "The manufacturer has proposed a starting price of €360 per active",
          "user per year. Your task is to negotiate a price that the health",
          "service could responsibly fund."
        ),
        levers = paste(
          "You may negotiate the annual price, and you may phase the rollout so",
          "that only a capped share of the eligible population is funded. You",
          "may not alter the clinical evidence or local implementation facts",
          "merely to make the result favourable."
        ),
        facts_hint = paste(
          "These facts are fixed so the case reflects a realistic commissioning",
          "position rather than one chosen to give a favourable result. The",
          "negotiated price and the rollout coverage cap are the only levers."
        ),
        start_label = "Start the value-for-money exercise"
      ),
      value = list(
        heading = "Value for money",
        result_heading = "Value-for-money result"
      ),
      budget = list(
        heading = "Budget impact",
        result_heading = "Budget-impact result",
        coverage_control = list(
          id = "part2_coverage",
          type = "slider",
          label = "Programme coverage cap (% of eligible population)",
          unit = "% of eligible population",
          info_topic = "the programme coverage cap",
          info = eqalb_tutorial_copy("part2_coverage"),
          min = EQALB_PART2_COVERAGE_MIN,
          max = EQALB_PART2_COVERAGE_MAX,
          step = EQALB_PART2_COVERAGE_STEP
        )
      ),
      fixed = list(
        threshold = EQALB_PART2_WTP,
        threshold_display = eqalb_tutorial_money(EQALB_PART2_WTP),
        budget_ceiling = EQALB_PART2_BUDGET_CEILING,
        budget_ceiling_display = eqalb_tutorial_money(EQALB_PART2_BUDGET_CEILING),
        manufacturer_minimum_price = EQALB_PART2_PRICE_MIN,
        manufacturer_minimum_price_display =
          eqalb_tutorial_money(EQALB_PART2_PRICE_MIN)
      ),
      price_control = list(
        id = "part2_price",
        type = "slider",
        label = "Negotiated annual price (€ per active user per year)",
        unit = "EUR per active user per year",
        info_topic = "the negotiated annual price",
        info = eqalb_tutorial_copy("part2_price"),
        default = EQALB_PART2_PRICE_DEFAULT,
        min = EQALB_PART2_PRICE_MIN,
        max = EQALB_PART2_PRICE_MAX,
        step = EQALB_PART2_PRICE_STEP
      ),
      price = eqalb_part2_price_strings(),
      budget_impact = eqalb_part2_budget_strings(),
      status_available = EQALB_TUTORIAL_STATUS_NOT_AVAILABLE,
      icer_unavailable = EQALB_TUTORIAL_ICER_UNAVAILABLE,
      limitation = paste(
        "Educational commissioning exercise using illustrative assumptions.",
        "The case facts, the price curve and the thresholds are simplified",
        "teaching material, not official payer or NICE criteria."
      )
    ),
    notice = eqalb_tutorial_notice()
  )
}

# --- Part 2 case creation and resume ---------------------------------------

# Creates a case for a new session, or resumes the case a client already holds.
# The interface sends only the opaque handle it was given, so the draw stays R's
# and a client cannot choose a case. A reload starts a new case: the client has
# no handle to send, so it omits it and R draws again.
eqalb_tutorial_part2_case <- function(body = list()) {
  case_id <- body[["case_id"]]
  seed <- body[["seed"]]

  resumed <- !is.null(case_id) && length(case_id) == 1L && !is.na(case_id) &&
    nzchar(as.character(case_id))
  if (resumed) {
    # An unknown handle is an error rather than a silent re-draw, so a client can
    # never present one case's facts beside another case's numbers.
    case <- eqalb_part2_case(case_id)
    selection <- list(
      rule = "resumed",
      candidates = length(eqalb_part2_cases()),
      excluded = ""
    )
  } else {
    exclude <- body[["exclude_case_id"]]
    drawn <- eqalb_part2_select_case(
      exclude_case_id = exclude,
      seed = if (is.null(seed) || length(seed) != 1L || is.na(seed)) {
        NULL
      } else {
        suppressWarnings(as.numeric(seed))
      }
    )
    case <- eqalb_part2_case(drawn$case_id)
    selection <- list(
      rule = if (nzchar(drawn$excluded)) "redrawn" else "created",
      candidates = drawn$candidates,
      excluded = drawn$excluded
    )
  }

  strings <- eqalb_part2_price_strings()
  banner <- eqalb_part2_banner_text(case)

  list(
    case = list(
      case_id = case$case_id,
      label = case$label,
      title = case$title,
      heading = paste0(case$label, " — ", case$title),
      summary = case$summary,
      banner = banner,
      facts = eqalb_part2_facts_payload(case)
    ),
    brief = list(
      intro = eqalb_part2_brief_intro(case)
    ),
    price = list(
      control = list(
        id = "part2_price",
        label = "Negotiated annual price (€ per active user per year)",
        unit = "EUR per active user per year",
        min = EQALB_PART2_PRICE_MIN,
        max = EQALB_PART2_PRICE_MAX,
        step = EQALB_PART2_PRICE_STEP,
        value = EQALB_PART2_PRICE_DEFAULT
      ),
      curve = eqalb_part2_price_curve(case)
    ),
    # Fixed per-case inputs the later sections will need. Published now so the
    # contract carries them, and derived from the case rather than from a
    # dashboard setting.
    later_inputs = list(
      population = case$population,
      review_minutes = case$review_minutes,
      followup_engagement_pct = case$followup_engagement,
      year1_engagement_pct = case$year1_engagement,
      languages = case$languages,
      language_available = case$languages >= 3
    ),
    # The coverage lever with its starting value and the case's budget-impact
    # result at that value, so the budget section has a result the first time it is
    # opened, exactly as the price section does.
    budget = {
      coverage_strings <- eqalb_part2_budget_strings()
      initial <- eqalb_part2_budget_result(
        case, EQALB_PART2_PRICE_DEFAULT, EQALB_PART2_COVERAGE_DEFAULT,
        coverage_strings
      )
      initial$rows <- eqalb_part2_bia_rows(
        case, EQALB_PART2_PRICE_DEFAULT, EQALB_PART2_COVERAGE_DEFAULT
      )
      initial$control <- list(
        id = "part2_coverage",
        label = "Programme coverage cap (% of eligible population)",
        unit = "% of eligible population",
        min = EQALB_PART2_COVERAGE_MIN,
        max = EQALB_PART2_COVERAGE_MAX,
        step = EQALB_PART2_COVERAGE_STEP,
        value = EQALB_PART2_COVERAGE_DEFAULT
      )
      initial
    },
    strings = list(
      price = strings[c(
        "task", "note", "lever_hint", "method_note", "below_max_hint",
        "maximum_label"
      )],
      chart = strings$chart
    ),
    selection = selection,
    notice = eqalb_tutorial_notice()
  )
}

# The case's own banner sentence, from R's template.
eqalb_part2_banner_text <- function(case) {
  template <- eqalb_tutorial_part2_contract()$part2$case_banner_template
  gsub(
    "{label}", case$label, fixed = TRUE,
    gsub("{title}", case$title, template, fixed = TRUE)
  )
}

# The case's own brief introduction, from R's template.
eqalb_part2_brief_intro <- function(case) {
  template <- eqalb_tutorial_part2_contract()$part2$brief$intro_template
  text <- gsub("{summary}", case$summary, template, fixed = TRUE)
  gsub(
    "{rrr}", format(case$rrr * 100, trim = TRUE), text, fixed = TRUE
  )
}

# --- Part 2 evaluation ------------------------------------------------------

# The current-price evaluation. It takes the case and the negotiated price, and
# returns everything the value-for-money section renders: the case identity, the
# price curve, the current-price card and the chart's labels and colours.
#
# The curve is the most expensive part of Part 2: it is one model run per lever
# value, forty-three in all, while the current price itself costs a single run.
# A caller that already holds the curve for this case — it comes back with the
# case — may post it as `curve`, and R then re-classifies it instead of
# re-running it, so moving the price lever costs one model run. R still decides
# every classification and the highest acceptable price in both paths, and both
# paths return the same response.
eqalb_tutorial_part2_evaluate <- function(body = list()) {
  case <- eqalb_part2_case(body[["case_id"]])
  price <- eqalb_tutorial_number(
    body, "price", EQALB_PART2_PRICE_DEFAULT,
    min = EQALB_PART2_PRICE_MIN, max = EQALB_PART2_PRICE_MAX
  )

  supplied_curve <- body[["curve"]]
  curve <- if (is.null(supplied_curve)) {
    eqalb_part2_price_curve(case)
  } else {
    eqalb_part2_curve_from_payload(supplied_curve, case)
  }
  result <- eqalb_part2_price_result(case, price, curve)

  # The budget impact reads the coverage cap and the same negotiated price. It is
  # a separate result: the price lever moves both, the coverage cap moves only
  # this one. The cap is validated against the lever's own range, so a value
  # outside it is R's error rather than a silently clamped number.
  budget_strings <- eqalb_part2_budget_strings()
  coverage <- eqalb_tutorial_number(
    body, "coverage", EQALB_PART2_COVERAGE_DEFAULT,
    min = EQALB_PART2_COVERAGE_MIN, max = EQALB_PART2_COVERAGE_MAX
  )
  budget <- eqalb_part2_budget_result(
    case, price, coverage, budget_strings
  )
  budget$rows <- eqalb_part2_bia_rows(case, price, coverage)
  budget$summary <- gsub(
    "{years}", format(budget$horizon_years, trim = TRUE),
    budget_strings$summary_template,
    fixed = TRUE
  )
  budget$summary <- gsub(
    "{total}", budget$total_display, budget$summary, fixed = TRUE
  )
  budget$population_sentence <- gsub(
    "{population}", format(case$population, big.mark = ",", scientific = FALSE),
    budget_strings$population_template,
    fixed = TRUE
  )
  budget$covered_sentence <- gsub(
    "{covered}", format(round(budget$covered_population), big.mark = ","),
    budget_strings$covered_template,
    fixed = TRUE
  )
  budget$full_rollout_sentence <- gsub(
    "{population}", format(case$population, big.mark = ",", scientific = FALSE),
    budget_strings$full_rollout_template,
    fixed = TRUE
  )
  budget$coverage_sentence <- gsub(
    "{coverage}", format(coverage, trim = TRUE),
    budget_strings$coverage_sentence_template,
    fixed = TRUE
  )
  budget$lever_sentence <- paste0(
    budget_strings$lever_label, ": ", eqalb_tutorial_money(price),
    " per active user per year. ", budget$coverage_sentence
  )
  # The shortcut back to the price lever is shown only while the price has not
  # achieved value for money: R decides that, from the value-for-money result.
  budget$price_shortcut <- list(
    show = !isTRUE(result$passed),
    label = budget_strings$price_shortcut_label,
    note = budget_strings$price_shortcut_note
  )
  budget$strings <- budget_strings
  strings <- eqalb_part2_price_strings()

  # The readiness exercise reads its four answers from the same request. It is a
  # separate result: the answers move the readiness statuses only, so the price,
  # the curve, the maximum and the budget impact above are unaffected.
  readiness <- eqalb_part2_readiness(case, body)

  # The recommendation reads the three criteria and the coverage cap from the
  # results above. The three economic tests are separate, so the outcome names the
  # first one that fails; the coverage test needs all three and the cap at the
  # highest affordable step, which is what the budget result already decided.
  recommendation <- eqalb_part2_recommendation(
    value_for_money = result$passed,
    affordability = budget$affordable,
    deliverability = readiness$deliverability$passed,
    coverage_maximised = isTRUE(result$passed) && isTRUE(budget$at_max) &&
      isTRUE(readiness$deliverability$passed),
    max_coverage = budget$max_affordable_coverage
  )

  answer <- if (is.na(curve$max_acceptable_price)) {
    paste0(
      "No price on the lever meets the payer's threshold for this case: the",
      "model's incremental net monetary benefit is below zero across the whole",
      "range."
    )
  } else {
    paste0(
      "The highest price on the lever that still meets the payer's threshold",
      "for this case is ", curve$max_acceptable_price_display,
      " per active user per year."
    )
  }

  list(
    case = list(
      case_id = case$case_id,
      label = case$label,
      title = case$title,
      heading = paste0(case$label, " — ", case$title),
      banner = eqalb_part2_banner_text(case),
      facts = eqalb_part2_facts_payload(case)
    ),
    price = result,
    maximum = list(
      value = curve$max_acceptable_price,
      display = curve$max_acceptable_price_display,
      label = strings$maximum_label,
      reached = isTRUE(result$at_max)
    ),
    curve = curve,
    curve_source = if (is.null(supplied_curve)) "computed" else "posted",
    marker = list(
      price = price,
      key = paste0("price-", format(price, trim = TRUE)),
      colour = strings$chart$marker$colour,
      label = strings$chart$marker$label
    ),
    chart = strings$chart,
    answer = answer,
    # The budget-impact section's own result. It is additive: the value-for-money
    # fields above are byte-identical whether or not a coverage cap is supplied,
    # because the cap scales the budget-impact population only.
    budget = budget,
    # The DHT readiness exercise's own result, likewise additive.
    readiness = readiness,
    # The commissioning outcome, chosen in R from the results above. It is
    # additive too: every field beside it is unchanged.
    recommendation = recommendation,
    strings = list(
      task = strings$task,
      note = strings$note,
      lever_hint = strings$lever_hint,
      method_note = strings$method_note
    ),
    section = list(
      key = "value",
      name = EQALB_PART2_STEP_NAMES[[2]],
      step_index = 2L,
      available = TRUE
    ),
    limitation = eqalb_tutorial_part2_contract()$part2$limitation,
    notice = eqalb_tutorial_notice()
  )
}
