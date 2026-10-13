# eQalb Kaplan-Meier traffic-light interpretation.
#
# assess_km_interpretation() and its two formatting helpers are the exact
# functions the Shiny Kaplan-Meier tab calls in app.R. They are moved here
# verbatim - unchanged - because the model API has to answer with the same
# interpretation the Shiny tab renders, and the alternatives were a second
# copy of the rules or a status derived outside R. The interpretation logic
# therefore still exists exactly once, and app.R sources it.
#
# Sourced by app.R (Shiny) and by api/plumber.R (the model API). The
# presentation-only card colours (KM_STATUS_STYLES) stay in app.R.
km_number <- function(value, digits = 3) {
  if (length(value) == 0L || is.na(value)) {
    return("not estimable")
  }
  format(round(value, digits), nsmall = digits, scientific = FALSE, trim = TRUE)
}

km_p_value <- function(value) {
  if (length(value) == 0L || is.na(value)) {
    return("not estimable")
  }
  format.pval(value, digits = 3, eps = 0.001)
}

# Derives the five traffic-light domains and the overall status from the
# existing Kaplan-Meier summary and arm-contrast statistics.
assess_km_interpretation <- function(
  arm_summary,
  logrank_p,
  hazard_ratio,
  competing_death_p = NA_real_
) {
  cc <- arm_summary[
    arm_summary$treatment == "eQalb plus usual care", , drop = FALSE
  ]
  uc <- arm_summary[arm_summary$treatment == "Usual care", , drop = FALSE]

  cc_events <- cc$events[[1]]
  uc_events <- uc$events[[1]]
  cc_censored <- cc$censored[[1]]
  uc_censored <- uc$censored[[1]]
  cc_deaths <- cc$competing_deaths[[1]]
  uc_deaths <- uc$competing_deaths[[1]]
  cc_admin <- cc$admin_censored[[1]]
  uc_admin <- uc$admin_censored[[1]]

  event_status <- if (cc_events < uc_events) {
    "Green"
  } else if (cc_events == uc_events) {
    "Amber"
  } else {
    "Red"
  }
  event_text <- if (event_status == "Green") {
    sprintf(
      "eQalb had fewer simulated events in this run (%d vs %d composite events).",
      cc_events, uc_events
    )
  } else if (event_status == "Amber") {
    sprintf(
      "Composite event counts were equal in this run (%d vs %d).",
      cc_events, uc_events
    )
  } else {
    sprintf(
      "eQalb had more simulated events in this run (%d vs %d composite events).",
      cc_events, uc_events
    )
  }

  size_status <- if (is.na(hazard_ratio)) {
    "Amber"
  } else if (hazard_ratio < 0.80) {
    "Green"
  } else if (hazard_ratio <= 1.00) {
    "Amber"
  } else {
    "Red"
  }
  size_text <- if (is.na(hazard_ratio)) {
    "Hazard ratio is not estimable for this run."
  } else {
    sprintf(
      "Hazard ratio %s for eQalb versus usual care.",
      km_number(hazard_ratio)
    )
  }

  evidence_status <- if (is.na(logrank_p)) {
    "Amber"
  } else if (logrank_p < 0.05) {
    "Green"
  } else if (logrank_p <= 0.10) {
    "Amber"
  } else {
    "Red"
  }
  evidence_text <- if (is.na(logrank_p)) {
    "Descriptive log-rank p-value is not estimable for this run."
  } else {
    sprintf("Descriptive log-rank p = %s.", km_p_value(logrank_p))
  }

  censoring_relative <- abs(cc_censored - uc_censored) /
    max(cc_censored, uc_censored, 1)
  competing_relative <- abs(cc_deaths - uc_deaths) /
    max(cc_deaths, uc_deaths, 1)
  competing_significant <- !is.na(competing_death_p) && competing_death_p < 0.05
  censoring_status <- if (competing_significant ||
    censoring_relative > 0.25 || competing_relative > 0.25) {
    "Red"
  } else if (censoring_relative > 0.10 || competing_relative > 0.10) {
    "Amber"
  } else {
    "Green"
  }
  censoring_text <- sprintf(
    paste0(
      "Total censoring %d vs %d; competing other-cause deaths %d vs %d; ",
      "administrative end-of-follow-up censoring %d vs %d ",
      "(eQalb vs usual care). Competing-death Fisher p = %s."
    ),
    cc_censored, uc_censored, cc_deaths, uc_deaths, cc_admin, uc_admin,
    km_p_value(competing_death_p)
  )

  credibility_status <- "Red"
  credibility_text <- paste(
    "Simulated illustrative data — not clinical evidence; the curves are not",
    "based on patient-level clinical data."
  )

  clinical_status <- c(
    event_status, size_status, evidence_status, censoring_status
  )
  uses_real_patient_data <- FALSE
  overall_status <- if (credibility_status == "Red" && !uses_real_patient_data) {
    "Red"
  } else if (all(clinical_status == "Green")) {
    "Green"
  } else {
    "Amber"
  }

  event_phrase <- if (cc_events < uc_events) {
    "had fewer simulated composite events than usual care in this simulation"
  } else if (cc_events == uc_events) {
    "had the same number of simulated composite events as usual care in this simulation"
  } else {
    "had more simulated composite events than usual care in this simulation"
  }
  significance_phrase <- if (!is.na(logrank_p) && logrank_p < 0.05) {
    "and the difference was statistically significant"
  } else {
    "but the difference was not statistically significant"
  }

  interpretation <- paste(
    sprintf("eQalb %s, %s.", event_phrase, significance_phrase),
    paste(
      "The result is compatible with random simulation variation and is not",
      "clinical evidence."
    ),
    paste(
      "The Kaplan–Meier risk table shows people who are event-free and still",
      "observed. It does not show how many people are still actively using",
      "the app."
    )
  )

  rules <- c(
    paste(
      "Event direction: Green if eQalb has fewer composite events;",
      "Amber if event counts are equal; Red if eQalb has more events."
    ),
    paste(
      "Size of apparent benefit: Green if hazard ratio < 0.80; Amber if 0.80",
      "to 1.00; Red if > 1.00."
    ),
    paste(
      "Statistical evidence: Green if log-rank p < 0.05; Amber if p is 0.05",
      "to 0.10; Red if p > 0.10."
    ),
    paste(
      "Censoring and competing events: Red if competing-death Fisher p < 0.05",
      "or total censoring or competing-death counts differ by more than 25%;",
      "Amber if they differ by more than 10%; Green otherwise."
    ),
    paste(
      "Evidence credibility: always Red because the current Kaplan–Meier data",
      "are simulated illustrative data, not clinical evidence."
    )
  )

  list(
    overall_status = overall_status,
    domains = data.frame(
      Domain = c(
        "Event direction",
        "Size of apparent benefit",
        "Statistical evidence",
        "Censoring and competing events",
        "Evidence credibility"
      ),
      Status = c(
        event_status, size_status, evidence_status, censoring_status,
        credibility_status
      ),
      Explanation = c(
        event_text, size_text, evidence_text, censoring_text, credibility_text
      ),
      stringsAsFactors = FALSE
    ),
    counts = list(
      cc_events = cc_events, uc_events = uc_events,
      cc_censored = cc_censored, uc_censored = uc_censored,
      cc_deaths = cc_deaths, uc_deaths = uc_deaths,
      cc_admin = cc_admin, uc_admin = uc_admin,
      hazard_ratio = hazard_ratio, logrank_p = logrank_p,
      competing_death_p = competing_death_p
    ),
    interpretation = paste(interpretation, collapse = " "),
    rules = rules
  )
}
