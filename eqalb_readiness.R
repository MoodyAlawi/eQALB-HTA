# eQalb DHT readiness and implementation assessment.
#
# The reusable full-analysis readiness logic, sourced by app.R (the Shiny UI)
# and by api/plumber.R (the model API), so the readiness rules exist exactly
# once and the API never has to source app.R.
#
# Contents: the interoperability and algorithm-approach levels, the two
# formatting helpers, the decision-support disclaimer used in the readiness
# interpretation, and calculate_readiness(), which scores the seven
# illustrative readiness domains.
#
# The thresholds, wording and basis notes are illustrative teaching rules for
# the fictional eQalb digital therapeutic. They are not a validated
# assessment instrument or a regulatory standard.

# DHT readiness and implementation dashboard.
# These are transparent illustrative rules for the fictional eQalb
# digital therapeutic, not a validated assessment instrument or regulatory
# standard.
DHT_INTEROPERABILITY_LEVELS <- c(
  "No data exchange",
  "PDF/manual export",
  "Structured API",
  "FHIR-based exchange"
)

DHT_ALGORITHM_APPROACHES <- c(
  "No algorithmic component",
  "Locked algorithm",
  "Periodic controlled updates",
  "Continuously learning algorithm"
)

DHT_DISCLAIMER <- paste(
  "Educational DHT implementation assessment using illustrative assumptions.",
  "This is not a validated HTA, DiGA, regulatory, cybersecurity, or",
  "reimbursement assessment."
)

dht_format_count <- function(value) {
  format(round(value), big.mark = ",", scientific = FALSE, trim = TRUE)
}

dht_format_rate <- function(value) {
  format(
    round(value, 1),
    big.mark = ",",
    nsmall = 1,
    scientific = FALSE,
    trim = TRUE
  )
}

# Illustrative DHT readiness dashboard.
# Accepts the dashboard inputs and returns a named list containing the
# calculated outputs and the Green/Amber/Red status of each assessment domain.
calculate_readiness <- function(
  target_population,
  digital_access,
  digital_suitability,
  readiness_year1_engagement,
  readiness_followup_engagement,
  review_minutes,
  supported_languages,
  accessibility_features,
  interoperability,
  algorithm_governance
) {
  eligible_population <-
    target_population * (digital_access / 100) * (digital_suitability / 100)
  active_users_year1 <-
    eligible_population * (readiness_year1_engagement / 100)
  active_users_followup <-
    eligible_population * (readiness_followup_engagement / 100)
  annual_clinician_hours <-
    active_users_year1 * review_minutes * 12 / 60

  retention_pct <- if (readiness_year1_engagement == 0) {
    NA_real_
  } else {
    (readiness_followup_engagement / readiness_year1_engagement) * 100
  }

  eligible_share_pct <-
    (digital_access / 100) * (digital_suitability / 100) * 100

  equity_status <- if (digital_access >= 80 && digital_suitability >= 75) {
    "Green"
  } else if (digital_access >= 50 && digital_suitability >= 50) {
    "Amber"
  } else {
    "Red"
  }

  engagement_status <- if (readiness_followup_engagement >= 60) {
    "Green"
  } else if (readiness_followup_engagement >= 30) {
    "Amber"
  } else {
    "Red"
  }

  workflow_status <- if (review_minutes < 5) {
    "Green"
  } else if (review_minutes <= 15) {
    "Amber"
  } else {
    "Red"
  }

  language_status <- if (supported_languages >= 3) {
    "Green"
  } else if (supported_languages == 2) {
    "Amber"
  } else {
    "Red"
  }

  accessibility_status <- if (isTRUE(accessibility_features)) "Green" else "Red"

  interoperability_status <- if (identical(
    interoperability, "FHIR-based exchange"
  )) {
    "Green"
  } else if (identical(interoperability, "No data exchange")) {
    "Red"
  } else {
    "Amber"
  }

  governance_status <- if (algorithm_governance %in%
    c("No algorithmic component", "Locked algorithm")) {
    "Green"
  } else if (identical(
    algorithm_governance, "Periodic controlled updates"
  )) {
    "Amber"
  } else {
    "Red"
  }

  equity_input <- sprintf(
    "Access %s%%, suitability %s%%",
    dht_format_rate(digital_access),
    dht_format_rate(digital_suitability)
  )
  equity_text <- switch(
    equity_status,
    Green = sprintf(
      paste(
        "Digitally eligible share is %s%% of the target population.",
        "No obvious access barrier under the selected assumptions."
      ),
      dht_format_rate(eligible_share_pct)
    ),
    Amber = sprintf(
      paste(
        "Digitally eligible share is %s%% of the target population.",
        "Reach may need mitigation so deployment does not widen the digital",
        "divide."
      ),
      dht_format_rate(eligible_share_pct)
    ),
    Red = sprintf(
      paste(
        "Digitally eligible share is %s%% of the target population.",
        "A major access barrier should be resolved before broad deployment."
      ),
      dht_format_rate(eligible_share_pct)
    )
  )

  engagement_input <- sprintf(
    "Follow-up %s%% (year-1 %s%%)",
    dht_format_rate(readiness_followup_engagement),
    dht_format_rate(readiness_year1_engagement)
  )
  engagement_text <- switch(
    engagement_status,
    Green = paste(
      "Follow-up engagement is sustained, so the modelled clinical and",
      "economic value is less likely to be eroded by disengagement."
    ),
    Amber = paste(
      "Follow-up engagement is moderate, so some erosion of the modelled",
      "clinical and economic value is plausible."
    ),
    Red = paste(
      "Follow-up engagement is low, so the modelled clinical and economic",
      "value may not be realised in practice."
    )
  )

  workflow_input <- sprintf(
    "%s clinician-review minutes per patient per month",
    dht_format_rate(review_minutes)
  )
  workflow_text <- switch(
    workflow_status,
    Green = "Low clinical workload; routine workflow is unlikely to be strained.",
    Amber = paste(
      "Moderate clinical workload; extra clinician capacity or workflow",
      "mitigation may be required."
    ),
    Red = paste(
      "High clinical workload; this is a major workflow barrier before broad",
      "deployment."
    )
  )

  language_input <- sprintf(
    "%d supported language(s)",
    as.integer(supported_languages)
  )
  language_text <- switch(
    language_status,
    Green = paste(
      "Three or more languages are supported, giving broad language access",
      "under the selected assumptions."
    ),
    Amber = paste(
      "Two languages are supported; more language coverage may be required",
      "for equitable access."
    ),
    Red = paste(
      "Only one language is supported, which is a major language-access",
      "barrier for a diverse population."
    )
  )

  accessibility_input <- if (isTRUE(accessibility_features)) {
    "Accessibility features available"
  } else {
    "Accessibility features not available"
  }
  accessibility_text <- if (accessibility_status == "Green") {
    "Accessibility features are available; no obvious accessibility barrier."
  } else {
    paste(
      "Accessibility features are not available; this is a major",
      "accessibility barrier before broad deployment."
    )
  }

  interoperability_input <- interoperability
  interoperability_text <- switch(
    interoperability_status,
    Green = "FHIR-based exchange supports structured, interoperable data flows.",
    Amber = paste(
      "Only partial interoperability; integration effort or manual rework is",
      "likely."
    ),
    Red = "No data exchange is available; a major interoperability barrier."
  )

  governance_input <- algorithm_governance
  governance_text <- switch(
    governance_status,
    Green = paste(
      "Governance risk is low because no algorithm is used or the algorithm",
      "is locked."
    ),
    Amber = paste(
      "Periodic controlled updates require documented change control and",
      "re-validation."
    ),
    Red = paste(
      "A continuously learning algorithm requires major governance and",
      "validation work before broad deployment."
    )
  )

  domains <- data.frame(
    Domain = c(
      "Equity and access",
      "Engagement",
      "Workflow burden",
      "Language access",
      "Accessibility",
      "Interoperability",
      "Algorithm governance"
    ),
    Status = c(
      equity_status,
      engagement_status,
      workflow_status,
      language_status,
      accessibility_status,
      interoperability_status,
      governance_status
    ),
    `Current input` = c(
      equity_input,
      engagement_input,
      workflow_input,
      language_input,
      accessibility_input,
      interoperability_input,
      governance_input
    ),
    Interpretation = c(
      equity_text,
      engagement_text,
      workflow_text,
      language_text,
      accessibility_text,
      interoperability_text,
      governance_text
    ),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  cards <- data.frame(
    Domain = c(
      "Equity and access",
      "Engagement",
      "Workflow burden",
      "Interoperability",
      "Algorithm governance"
    ),
    Status = c(
      equity_status,
      engagement_status,
      workflow_status,
      interoperability_status,
      governance_status
    ),
    Explanation = c(
      equity_text,
      engagement_text,
      workflow_text,
      interoperability_text,
      governance_text
    ),
    stringsAsFactors = FALSE
  )

  counts <- table(factor(
    domains$Status,
    levels = c("Green", "Amber", "Red")
  ))
  n_green <- as.integer(counts[["Green"]])
  n_amber <- as.integer(counts[["Amber"]])
  n_red <- as.integer(counts[["Red"]])

  retention_text <- if (is.na(retention_pct)) {
    "NA (year-1 engagement is 0)"
  } else {
    paste0(dht_format_rate(retention_pct), "%")
  }

  numbers <- data.frame(
    Measure = c(
      "Digitally eligible population",
      "Active users at year 1",
      "Active users at follow-up",
      "Engagement retention",
      "Annual clinician-review hours"
    ),
    Value = c(
      dht_format_count(eligible_population),
      dht_format_count(active_users_year1),
      dht_format_count(active_users_followup),
      retention_text,
      dht_format_rate(annual_clinician_hours)
    ),
    `Illustrative basis` = c(
      "Target population x access % x suitability %",
      "Digitally eligible population x year-1 engagement %",
      "Digitally eligible population x follow-up engagement %",
      "Follow-up engagement / year-1 engagement",
      "Active users at year 1 x review minutes x 12 / 60"
    ),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  red_domains <- domains$Domain[domains$Status == "Red"]
  amber_domains <- domains$Domain[domains$Status == "Amber"]

  barrier_text <- if (length(red_domains) > 0L) {
    paste0(
      "Highest-priority barriers (Red): ",
      paste(red_domains, collapse = ", "), "."
    )
  } else if (length(amber_domains) > 0L) {
    paste0(
      "No Red domains. Domains needing mitigation (Amber): ",
      paste(amber_domains, collapse = ", "), "."
    )
  } else {
    "No Red or Amber domains under the selected assumptions."
  }

  interpretation <- paste(
    sprintf(
      paste(
        "Assessment summary: %d Green, %d Amber and %d Red across %d",
        "illustrative domains."
      ),
      n_green, n_amber, n_red, nrow(domains)
    ),
    barrier_text,
    paste(
      "Lower engagement may reduce the economic and clinical value estimated",
      "in the eQalb model."
    ),
    paste(
      "Interoperability and workflow burden may affect implementation costs",
      "and clinical feasibility."
    ),
    paste(
      "This dashboard is an educational, illustrative assessment and does not",
      "replace clinical, regulatory, cybersecurity, security, or formal HTA",
      "assessment."
    ),
    DHT_DISCLAIMER
  )

  list(
    eligible_population = eligible_population,
    active_users_year1 = active_users_year1,
    active_users_followup = active_users_followup,
    engagement_retention_pct = retention_pct,
    annual_clinician_hours = annual_clinician_hours,
    numbers = numbers,
    domains = domains,
    cards = cards,
    counts = c(Green = n_green, Amber = n_amber, Red = n_red),
    interpretation = interpretation
  )
}
