library(shiny)
library(ggplot2)
library(dplyr)
library(survival)
library(survminer)

app_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
app_dir <- if (is.null(app_file)) getwd() else dirname(normalizePath(app_file))
source(file.path(app_dir, "eqalb_markov.R"))
source(file.path(app_dir, "eqalb_survival.R"))
source(file.path(app_dir, "eqalb_owsa.R"))

format_euros <- function(value) {
  paste0("€", format(round(value, 2), big.mark = ",", nsmall = 2))
}

format_euros_signed <- function(value) {
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

# ---------------------------------------------------------------------------
# Consolidated results export: helpers for the "Download complete results
# package" ZIP.
#
# R on Windows does not ship a zip binary and this project must not add
# packages, so the archive is written directly with base R using the ZIP store
# method (no compression). The CRC-32 of each entry is read from the trailer of
# a gzip stream written by R: RFC 1952 ends every gzip member with the CRC-32
# of the uncompressed data, which is the CRC-32 that ZIP requires.
# ---------------------------------------------------------------------------
zip_uint16 <- function(value) {
  as.raw(c(value %% 256, (value %/% 256) %% 256))
}

zip_uint32 <- function(value) {
  as.raw(c(
    value %% 256,
    (value %/% 256) %% 256,
    (value %/% 65536) %% 256,
    (value %/% 16777216) %% 256
  ))
}

zip_dos_timestamp <- function(when = Sys.time()) {
  parts <- as.POSIXlt(when)
  list(
    time = bitwOr(
      bitwOr(bitwShiftL(parts$hour, 11L), bitwShiftL(parts$min, 5L)),
      parts$sec %/% 2
    ),
    date = bitwOr(
      bitwOr(bitwShiftL(parts$year - 80L, 9L), bitwShiftL(parts$mon + 1L, 5L)),
      parts$mday
    )
  )
}

zip_crc32 <- function(bytes, scratch) {
  if (length(bytes) == 0L) {
    return(zip_uint32(0))
  }
  con <- gzfile(scratch, "wb")
  writeBin(bytes, con)
  close(con)
  size <- file.info(scratch)$size
  con <- file(scratch, "rb")
  on.exit(close(con), add = TRUE)
  seek(con, where = size - 8, origin = "start")
  trailer <- readBin(con, "raw", n = 8L)
  trailer[1:4]
}

write_zip_archive <- function(files, dest) {
  files <- files[file.exists(files)]
  scratch <- tempfile("eqalb_crc_")
  on.exit(unlink(scratch), add = TRUE)
  stamp <- zip_dos_timestamp()
  con <- file(dest, "wb")
  on.exit(close(con), add = TRUE)
  entries <- vector("list", length(files))
  offset <- 0
  for (i in seq_along(files)) {
    bytes <- readBin(files[[i]], "raw", n = file.info(files[[i]])$size)
    name <- charToRaw(basename(files[[i]]))
    crc <- zip_crc32(bytes, scratch)
    header <- c(
      zip_uint32(0x04034b50), zip_uint16(20), zip_uint16(0), zip_uint16(0),
      zip_uint16(stamp$time), zip_uint16(stamp$date), crc,
      zip_uint32(length(bytes)), zip_uint32(length(bytes)),
      zip_uint16(length(name)), zip_uint16(0), name
    )
    writeBin(header, con)
    writeBin(bytes, con)
    entries[[i]] <- list(
      name = name, crc = crc, size = length(bytes), offset = offset
    )
    offset <- offset + length(header) + length(bytes)
  }
  central_offset <- offset
  for (entry in entries) {
    central <- c(
      zip_uint32(0x02014b50), zip_uint16(20), zip_uint16(20), zip_uint16(0),
      zip_uint16(0), zip_uint16(stamp$time), zip_uint16(stamp$date), entry$crc,
      zip_uint32(entry$size), zip_uint32(entry$size),
      zip_uint16(length(entry$name)), zip_uint16(0), zip_uint16(0),
      zip_uint16(0), zip_uint16(0), zip_uint32(0), zip_uint32(entry$offset),
      entry$name
    )
    writeBin(central, con)
    offset <- offset + length(central)
  }
  writeBin(
    c(
      zip_uint32(0x06054b50), zip_uint16(0), zip_uint16(0),
      zip_uint16(length(entries)), zip_uint16(length(entries)),
      zip_uint32(offset - central_offset), zip_uint32(central_offset),
      zip_uint16(0)
    ),
    con
  )
  invisible(dest)
}

# Draws an already-computed plot object (a ggplot or a ggsurvplot) into a PNG.
# The plot objects come from cached reactives, so nothing is recalculated here.
write_plot_png <- function(plot, path, width, height) {
  if (is.null(plot)) {
    stop("The exported plot object is missing.")
  }
  grDevices::png(
    path, width = width, height = height, units = "in", res = 300, bg = "white"
  )
  on.exit(grDevices::dev.off(), add = TRUE)
  print(plot)
  invisible(path)
}

# Writes the collected export items and their README into one ZIP archive, using
# a temporary staging directory that is removed again afterwards.
write_results_package <- function(dest, items, readme_lines) {
  staging <- tempfile("eqalb_export_")
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE, force = TRUE), add = TRUE)
  paths <- character(0)
  for (item in items) {
    path <- file.path(staging, item$name)
    if (identical(item$type, "csv")) {
      utils::write.csv(
        item$payload, path, row.names = FALSE, na = "", fileEncoding = "UTF-8"
      )
    } else if (identical(item$type, "text")) {
      writeLines(item$payload, path, useBytes = TRUE)
    } else {
      write_plot_png(item$payload, path, item$width, item$height)
    }
    paths <- c(paths, path)
  }
  readme_path <- file.path(staging, "README.txt")
  writeLines(readme_lines, readme_path, useBytes = TRUE)
  write_zip_archive(c(readme_path, paths), dest)
  invisible(dest)
}

BIA_DISCLAIMER <- paste(
  "Educational budget-impact analysis using illustrative assumptions.",
  "Budget impact measures payer affordability; it does not measure",
  "cost-effectiveness or value for money."
)

# Numerical tolerance used by the value-of-information checks. Only negative
# values inside this tolerance are treated as floating-point rounding.
VOI_TOLERANCE <- 1e-6

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

# Light card colours used by the readiness status cards and table badges.
DHT_STATUS_STYLES <- list(
  Green = c(background = "#d4edda", border = "#c3e6cb", text = "#155724"),
  Amber = c(background = "#fff3cd", border = "#ffeeba", text = "#856404"),
  Red = c(background = "#f8d7da", border = "#f5c6cb", text = "#721c24")
)

DHT_DISCLAIMER <- paste(
  "Educational DHT implementation assessment using illustrative assumptions.",
  "This is not a validated HTA, DiGA, regulatory, cybersecurity, or",
  "reimbursement assessment."
)

DHT_THRESHOLD_NOTE <- paste(
  "The traffic-light thresholds used here are educational illustrative",
  "assumptions for the fictional eQalb digital therapeutic. They are",
  "not official HTA, DiGA, regulatory, cybersecurity, or reimbursement",
  "standards."
)

DHT_TRAFFIC_LEGEND <- c(
  "Green = no obvious barrier under the selected assumptions",
  "Amber = uncertainty or mitigation required",
  "Red = major barrier needing resolution before broad deployment"
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

# Compact Kaplan-Meier traffic-light interpretation.
# Presentation-only: it summarises the already-computed simulated statistics and
# does not change the simulation or any test.
KM_STATUS_STYLES <- list(
  Green = c(background = "#d4edda", border = "#c3e6cb", text = "#155724"),
  Amber = c(background = "#fff3cd", border = "#ffeeba", text = "#856404"),
  Red = c(background = "#f8d7da", border = "#f5c6cb", text = "#721c24")
)

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

# Modern visual theme (bslib only). This is presentation-only: it changes
# colours, typography, spacing and component styling, and does not alter the
# layout structure, any input or output ID, or any server logic.
EQALB_THEME <- bslib::bs_add_rules(
  bslib::bs_theme(
    version = 5,
    bg = "#f4f7f9",
    fg = "#1f2d3d",
    primary = "#176b73",
    secondary = "#546e7a",
    info = "#176b73",
    success = "#2e7d4f",
    warning = "#b26a00",
    danger = "#b3261e",
    base_font = paste(
      "Segoe UI", "system-ui", "-apple-system", "Helvetica Neue", "Arial",
      "sans-serif", sep = ", "
    ),
    heading_font = paste(
      "Segoe UI", "system-ui", "-apple-system", "Helvetica Neue", "Arial",
      "sans-serif", sep = ", "
    ),
    "border-radius" = "0.5rem",
    "card-border-radius" = "0.5rem",
    "font-size-base" = "0.95rem"
  ),
  "
  body { background-color: #f4f7f9; }
  .container-fluid { padding: 1.25rem 1.5rem 2rem 1.5rem; }
  h2, h3 { font-weight: 600; letter-spacing: -0.01em; }
  h3 { margin-top: 1.25rem; margin-bottom: 0.75rem; color: #14555c; }
  h4 { margin-top: 1.25rem; margin-bottom: 0.5rem; font-weight: 600; }
  h5 { margin-top: 1rem; margin-bottom: 0.5rem; font-weight: 600; }
  .well, .card {
    background-color: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 0.5rem;
    box-shadow: 0 1px 2px rgba(15, 23, 42, 0.06);
    padding: 1rem 1.25rem;
    margin-bottom: 1rem;
  }
  .well > strong:first-child, .card > strong:first-child { display: block; margin-bottom: 0.35rem; }
  .btn { border-radius: 0.4rem; font-weight: 500; padding: 0.45rem 0.95rem; }
  .btn-default, .btn-secondary {
    background-color: #ffffff; border-color: #cbd5e1; color: #1f2d3d;
  }
  .btn-default:hover, .btn-secondary:hover {
    background-color: #eef2f6; border-color: #94a3b8; color: #14555c;
  }
  .nav-tabs { border-bottom: 2px solid #e2e8f0; margin-bottom: 1rem; }
  .nav-tabs > li > a, .nav-tabs .nav-link {
    border: none; border-radius: 0.45rem 0.45rem 0 0;
    color: #546e7a; font-weight: 500; padding: 0.5rem 0.95rem;
  }
  .nav-tabs > li > a:hover, .nav-tabs .nav-link:hover { color: #176b73; }
  .nav-tabs > li.active > a, .nav-tabs .nav-link.active {
    color: #14555c; background-color: #ffffff;
    border-bottom: 3px solid #176b73; font-weight: 600;
  }
  table.table { background-color: #ffffff; border-radius: 0.4rem; }
  table.table > thead > tr > th, table.table thead th {
    background-color: #eaf1f3; color: #1f2d3d; font-weight: 600;
    border-color: #e2e8f0;
  }
  table.table td, table.table th { border-color: #e2e8f0; vertical-align: top; }
  .alert { border-radius: 0.5rem; border-width: 1px; }
  .text-muted { color: #64748b !important; }
  .form-group { margin-bottom: 0.85rem; }
  hr { border-top: 1px solid #e2e8f0; margin: 1.25rem 0; }
  [data-bs-theme='dark'] body, body[data-bs-theme='dark'] {
    background-color: #101a1f;
  }
  [data-bs-theme='dark'] .well, [data-bs-theme='dark'] .card,
  body[data-bs-theme='dark'] .well, body[data-bs-theme='dark'] .card {
    background-color: #16242c;
    border-color: #2b3d47;
    box-shadow: none;
  }
  [data-bs-theme='dark'] h3, body[data-bs-theme='dark'] h3 { color: #7fd1d8; }
  [data-bs-theme='dark'] table.table,
  body[data-bs-theme='dark'] table.table { background-color: #16242c; }
  [data-bs-theme='dark'] table.table > thead > tr > th,
  [data-bs-theme='dark'] table.table thead th,
  body[data-bs-theme='dark'] table.table thead th {
    background-color: #1e3039; color: #e6edf1; border-color: #2b3d47;
  }
  [data-bs-theme='dark'] table.table td, [data-bs-theme='dark'] table.table th,
  body[data-bs-theme='dark'] table.table td,
  body[data-bs-theme='dark'] table.table th { border-color: #2b3d47; }
  [data-bs-theme='dark'] .btn-default, [data-bs-theme='dark'] .btn-secondary,
  body[data-bs-theme='dark'] .btn-default,
  body[data-bs-theme='dark'] .btn-secondary {
    background-color: #1e3039; border-color: #37505c; color: #e6edf1;
  }
  [data-bs-theme='dark'] .nav-tabs,
  body[data-bs-theme='dark'] .nav-tabs { border-bottom-color: #2b3d47; }
  [data-bs-theme='dark'] .nav-tabs > li > a,
  [data-bs-theme='dark'] .nav-tabs .nav-link,
  body[data-bs-theme='dark'] .nav-tabs > li > a,
  body[data-bs-theme='dark'] .nav-tabs .nav-link { color: #a9bcc6; }
  [data-bs-theme='dark'] .nav-tabs > li.active > a,
  [data-bs-theme='dark'] .nav-tabs .nav-link.active,
  body[data-bs-theme='dark'] .nav-tabs > li.active > a,
  body[data-bs-theme='dark'] .nav-tabs .nav-link.active {
    background-color: #16242c; color: #7fd1d8;
    border-bottom: 3px solid #2fa3ad;
  }
  [data-bs-theme='dark'] .text-muted,
  body[data-bs-theme='dark'] .text-muted { color: #9fb2bd !important; }
  [data-bs-theme='dark'] hr,
  body[data-bs-theme='dark'] hr { border-top-color: #2b3d47; }

  /* Landing-page title screen. Presentation only: no effect on any analysis. */
  .cc-title-screen {
    min-height: calc(100vh - 8rem);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    padding: 2rem 1rem;
    border-radius: 18px;
    background-image: linear-gradient(
      135deg,
      rgba(23, 107, 115, 0.10),
      rgba(94, 178, 183, 0.05) 45%,
      rgba(23, 107, 115, 0.10)
    );
    background-size: 220% 220%;
    background-position: 0% 50%;
    animation: cc-title-gradient 38s ease-in-out infinite;
  }
  .cc-title-block { animation: cc-title-fade-up 700ms ease-out both; }
  .cc-title {
    font-size: clamp(2.75rem, 9vw, 4.75rem);
    font-weight: 700;
    letter-spacing: -0.02em;
    line-height: 1.05;
    margin: 0 0 0.6rem 0;
  }
  .cc-subtitle {
    font-size: clamp(1rem, 2.4vw, 1.3rem);
    font-weight: 400;
    margin: 0 0 2.25rem 0;
    opacity: 0.72;
  }
  .cc-title-actions {
    display: flex;
    flex-direction: column;
    gap: 0.7rem;
    width: 100%;
    max-width: 20rem;
    margin: 0 auto;
  }
  .cc-title-actions .btn {
    width: 100%;
    padding: 0.6rem 1.25rem;
    border-radius: 10px;
  }
  .cc-panel-page {
    min-height: calc(100vh - 8rem);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 1.5rem 1rem;
  }
  .cc-panel-inner {
    width: 100%;
    max-width: 46rem;
    text-align: center;
  }
  /* Centre the bullet block itself while keeping the bullet text left-aligned
     and readable. Scoped to the three landing-page subviews only. */
  .cc-panel-inner .well > ul {
    display: inline-block;
    text-align: left;
    max-width: 34rem;
  }
  @keyframes cc-title-fade-up {
    from { opacity: 0; transform: translateY(12px); }
    to { opacity: 1; transform: translateY(0); }
  }
  @keyframes cc-title-gradient {
    0% { background-position: 0% 50%; }
    50% { background-position: 100% 50%; }
    100% { background-position: 0% 50%; }
  }
  @media (prefers-reduced-motion: reduce) {
    .cc-title-screen, .cc-title-block { animation: none; }
  }
  "
)

ui <- fluidPage(
  theme = EQALB_THEME,
  # Shared light/dark switch. A single control is placed above both containers so
  # it stays available on the landing page and in the analysis dashboard header
  # without duplicating the widget (and therefore its ID).
  tags$div(
    style = "display:flex; justify-content:flex-end; margin-bottom:0.5rem;",
    bslib::input_dark_mode(id = "color_mode", mode = "light")
  ),
  # Landing-page navigation. Presentation only: a hidden control decides which
  # container is visible. The analysis UI stays in the DOM, so every input value
  # and output binding is preserved when navigating away and back.
  tags$div(
    style = "display:none;",
    selectInput(
      "nav_page", NULL,
      choices = c("home", "start", "description", "export", "dashboard"),
      selected = "home", selectize = FALSE
    )
  ),
  # Title screen (default view). The condition is written as a negation so that
  # it is already true before the first input payload arrives, which avoids a
  # blank flash at start-up.
  conditionalPanel(
    condition = paste(
      "input.nav_page !== 'start'",
      "input.nav_page !== 'description'",
      "input.nav_page !== 'export'",
      "input.nav_page !== 'dashboard'",
      sep = " && "
    ),
    tags$div(
      class = "cc-title-screen",
      tags$div(
        class = "cc-title-block",
        tags$h1(class = "cc-title", "eQalb"),
        tags$p(
          class = "cc-subtitle",
          "Interactive health-technology-assessment model"
        ),
        tags$div(
          class = "cc-title-actions",
          actionButton(
            "home_start_analysis", "Start analysis", class = "btn-primary"
          ),
          actionButton("home_project_description", "Project description"),
          actionButton("home_download_results", "Download results")
        )
      )
    )
  ),
  # "Start analysis" view: the existing analysis-area description and the
  # existing Open analysis dashboard button, unchanged, plus a Back button.
  conditionalPanel(
    condition = "input.nav_page === 'start'",
    tags$div(
      class = "cc-panel-page",
      tags$div(
        class = "cc-panel-inner",
        wellPanel(
          tags$h4("Analysis areas"),
          tags$ul(
            tags$li(paste(
              "Cost-effectiveness - base case, ICER and the cost-effectiveness",
              "plane."
            )),
            tags$li(paste(
              "Sensitivity Analysis - one-way sensitivity analysis and the",
              "tornado diagram."
            )),
            tags$li(paste(
              "Kaplan-Meier Curve - the simulated illustrative survival curve and",
              "risk table."
            )),
            tags$li(paste(
              "DHT Readiness & Implementation - implementation, equity and",
              "digital-readiness assessment."
            )),
            tags$li("Value of information - EVPI and EVPPI."),
            tags$li(paste(
              "HTA decision summary - traffic-light dashboard and the",
              "evidence-generation plan."
            ))
          ),
          actionButton("open_dashboard", "Open analysis dashboard"),
          tags$div(style = "margin-top:0.75rem;",
                   actionButton("home_back_from_start", "Back"))
        ),
        tags$div(
          class = "alert alert-warning",
          tags$strong(paste(
            "Simulated illustrative analysis - not clinical evidence and not an",
            "official HTA recommendation."
          ))
        )
      )
    )
  ),
  # "Project description" view.
  conditionalPanel(
    condition = "input.nav_page === 'description'",
    tags$div(
      class = "cc-panel-page",
      tags$div(
        class = "cc-panel-inner",
        wellPanel(
          tags$h4("Project description"),
          tags$p(paste(
            "eQalb is an educational digital-health technology assessment",
            "model for hypertension management. It explores cost effectiveness,",
            "uncertainty, budget impact, clinical outcomes, implementation",
            "readiness, and evidence priorities for a supplementary digital",
            "intervention. All clinical and economic results are illustrative",
            "simulations designed for learning and model exploration."
          )),
          actionButton("home_back_from_description", "Back")
        )
      )
    )
  ),
  # "Download results" view. It reuses the existing export button and its ZIP
  # generation logic unchanged; the ID is not duplicated anywhere else.
  conditionalPanel(
    condition = "input.nav_page === 'export'",
    tags$div(
      class = "cc-panel-page",
      tags$div(
        class = "cc-panel-inner",
        wellPanel(
          tags$h4("Download results"),
          tags$p(class = "text-muted", paste(
            "Downloads a ZIP package containing the results currently available",
            "in this session. Analyses that have not been run are listed in the",
            "package README."
          )),
          downloadButton(
            "download_results_package", "Download results package"
          ),
          tags$div(style = "margin-top:0.75rem;",
                   actionButton("home_back_from_export", "Back"))
        )
      )
    )
  ),
  conditionalPanel(
    condition = "input.nav_page === 'dashboard'",
    tags$div(
      style = "text-align:right; margin-bottom:-0.5rem;",
      actionButton("go_home", "Home")
    ),
    titlePanel("eQalb interactive model"),
    tabsetPanel(
    tabPanel(
      "Cost-effectiveness",
      tags$h3("Global eQalb assumptions"),
      wellPanel(
        tags$p(class = "text-muted", paste(
          "These assumptions describe the eQalb intervention and are",
          "shared across analyses unless an analysis-specific control is",
          "explicitly labelled."
        )),
        fluidRow(
          column(
            4,
            numericInput("price", "Annual intervention price (€)", 360)
          ),
          column(
            4,
            numericInput("implementation", "Implementation cost (€)", 40)
          ),
          column(
            4,
            numericInput("savings", "Annual healthcare savings (€)", 20)
          ),
          column(
            4,
            sliderInput("rrr", "Relative risk reduction (%)",
                        min = 0, max = 30, value = 10)
          ),
          column(
            4,
            sliderInput("engagement_year1", "Year-1 engagement (%)",
                        min = 0, max = 100, value = 70)
          ),
          column(
            4,
            sliderInput("engagement_followup", "Follow-up engagement (%)",
                        min = 0, max = 100, value = 42)
          )
        ),
        tags$h4("Health-state utilities"),
        tags$p(class = "text-muted", paste(
          "Utilities represent health-related quality of life in each modelled",
          "health state. They affect QALYs and cost effectiveness but do not",
          "change the number of MI or stroke events."
        )),
        fluidRow(
          column(
            4,
            numericInput("utility_no_event", "Base-case utility: no event",
                         0.86, min = 0, max = 1, step = 0.01)
          ),
          column(
            4,
            numericInput("utility_post_mi", "Base-case utility: post-MI",
                         0.80, min = 0, max = 1, step = 0.01)
          ),
          column(
            4,
            numericInput("utility_post_stroke", "Base-case utility: post-stroke",
                         0.60, min = 0, max = 1, step = 0.01)
          )
        ),
        tags$h5("Deterministic sensitivity-analysis ranges"),
        tags$p(class = "text-muted", paste(
          "These low and high values are used only for deterministic sensitivity",
          "analysis. They do not define the base-case values."
        )),
        fluidRow(
          column(
            6,
            tags$strong("Post-MI utility"),
            numericInput("ow_sa_low_utility_post_mi", "Low", 0.70, min = 0, max = 1, step = 0.01),
            numericInput("ow_sa_high_utility_post_mi", "High", 0.90, min = 0, max = 1, step = 0.01)
          ),
          column(
            6,
            tags$strong("Post-stroke utility"),
            numericInput("ow_sa_low_utility_post_stroke", "Low", 0.45, min = 0, max = 1, step = 0.01),
            numericInput("ow_sa_high_utility_post_stroke", "High", 0.75, min = 0, max = 1, step = 0.01)
          )
        ),
        tags$details(
          tags$summary("Fixed model defaults (not editable here)"),
          tags$p(paste(
            "Event costs are defined in the model file and are shared by every",
            "analysis in this tab:"
          )),
          tags$ul(
            tags$li(sprintf(
              "Post-MI cost, year 1 and follow-up: %s and %s",
              format_euros(cost_post_mi_year1),
              format_euros(cost_post_mi_followup)
            )),
            tags$li(sprintf(
              "Post-stroke cost, year 1 and follow-up: %s and %s",
              format_euros(cost_post_stroke_year1),
              format_euros(cost_post_stroke_followup)
            ))
          )
        )
      ),
      tags$hr(),
      tags$h3("Base-case cost-effectiveness"),
      fluidRow(
        column(
          4,
          wellPanel(
            tags$strong("Base-case run"),
            tags$p(class = "text-muted", paste(
              "Runs the deterministic model using the global assumptions above."
            )),
            actionButton("run", "Run model")
          )
        ),
        column(
          8,
          tableOutput("results"),
          plotOutput("icer_plot", height = "480px"),
          uiOutput("ce_downloads")
        )
      ),
      tags$hr(),
      tags$h3("Probabilistic sensitivity analysis"),
      fluidRow(
        column(
          4,
          wellPanel(
            tags$strong("PSA controls"),
            numericInput("psa_n_sim", "Number of PSA simulations",
                         value = 1000, min = 100, max = 10000, step = 100),
            numericInput("psa_seed", "PSA random seed", value = 12345, min = 1),
            numericInput(
              "psa_reference_wtp",
              "Reference WTP threshold — PSA plane line and probability summary (€ per QALY)",
              value = 100000, min = 0, step = 10000
            ),
            numericInput(
              "psa_max_wtp",
              "Maximum WTP threshold — CEAC x-axis upper limit (€ per QALY)",
              value = 200000, min = 0, step = 10000
            ),
            actionButton("run_psa", "Run probabilistic analysis")
          )
        ),
        column(
          8,
          tags$p(class = "text-muted", paste(
            "PSA varies multiple uncertain parameters together. It does not",
            "change the global product assumptions shown above unless the PSA",
            "samples those parameters from their specified distributions."
          )),
          tags$div(
            class = "alert alert-warning",
            tags$strong(paste(
              "PSA distributions are illustrative unless linked to empirical",
              "evidence."
            ))
          ),
          tags$p(paste(
            "Probabilities of cost-effectiveness are conditional on this model",
            "and its illustrative uncertainty distributions."
          )),
          uiOutput("psa_status"),
          tableOutput("psa_summary"),
          plotOutput("psa_plane", height = "480px"),
          plotOutput("psa_ceac", height = "480px")
        )
      ),
      tags$hr(),
      tags$h3("Budget impact analysis"),
      fluidRow(
        column(
          4,
          wellPanel(
            tags$strong("Budget-impact controls"),
            tags$p(class = "text-muted", paste(
              "Uses the global intervention price, implementation cost, and",
              "healthcare-use savings from the assumptions above."
            )),
            numericInput("bia_population", "Eligible clinical target population",
                         value = 100000, min = 0, step = 1000),
            numericInput("bia_year1_uptake", "Year-1 eQalb uptake (%)",
                         value = 10, min = 0, max = 100, step = 1),
            numericInput("bia_annual_uptake_increase",
                         "Annual uptake increase (percentage points)",
                         value = 5, min = 0, max = 100, step = 1),
            numericInput("bia_horizon", "Budget-impact horizon (years)",
                         value = 5, min = 1, max = 10, step = 1),
            numericInput("bia_avoided_event_savings",
                         "Annual avoided-event savings per active user (€)",
                         value = 0, min = 0),
            actionButton("run_bia", "Run budget impact analysis")
          )
        ),
        column(
          8,
          tags$p(class = "text-muted", paste(
            "Budget impact estimates payer affordability over time. It is",
            "separate from cost-effectiveness and does not replace the ICER."
          )),
          tags$div(
            class = "alert alert-warning",
            tags$strong(BIA_DISCLAIMER)
          ),
          uiOutput("bia_status"),
          tableOutput("bia_table"),
          tableOutput("bia_summary"),
          plotOutput("bia_plot", height = "420px"),
          textOutput("bia_interpretation")
        )
      )
    ),
    tabPanel(
      "Sensitivity Analysis",
      sidebarLayout(
        sidebarPanel(
          numericInput("ow_sa_wtp", "Willingness to pay (€ per QALY)",
                       value = 100000, min = 0, step = 5000),
          tags$strong("Annual intervention price"),
          numericInput("ow_sa_low_price", "Low", 180, min = 0),
          numericInput("ow_sa_high_price", "High", 540, min = 0),
          tags$strong("Relative risk reduction"),
          numericInput("ow_sa_low_rrr", "Low", 0.05, min = 0, max = 1, step = 0.01),
          numericInput("ow_sa_high_rrr", "High", 0.15, min = 0, max = 1, step = 0.01),
          tags$strong("Year-1 engagement"),
          numericInput("ow_sa_low_engagement_year1", "Low", 0.50, min = 0, max = 1, step = 0.01),
          numericInput("ow_sa_high_engagement_year1", "High", 0.85, min = 0, max = 1, step = 0.01),
          tags$strong("Follow-up engagement"),
          numericInput("ow_sa_low_engagement_followup", "Low", 0.20, min = 0, max = 1, step = 0.01),
          numericInput("ow_sa_high_engagement_followup", "High", 0.60, min = 0, max = 1, step = 0.01),
          tags$strong("Annual healthcare-use savings"),
          numericInput("ow_sa_low_savings", "Low", 0, min = 0),
          numericInput("ow_sa_high_savings", "High", 60, min = 0),
          tags$strong("Implementation cost"),
          numericInput("ow_sa_low_implementation", "Low", 0, min = 0),
          numericInput("ow_sa_high_implementation", "High", 100, min = 0),
          tags$strong("Post-MI cost (year-1 anchor)"),
          numericInput("ow_sa_low_post_mi_cost", "Low", 10000, min = 0),
          numericInput("ow_sa_high_post_mi_cost", "High", 20000, min = 0),
          tags$strong("Post-stroke cost (year-1 anchor)"),
          numericInput("ow_sa_low_post_stroke_cost", "Low", 15000, min = 0),
          numericInput("ow_sa_high_post_stroke_cost", "High", 25000, min = 0),
          actionButton("run_owsa", "Run sensitivity analysis")
        ),
        mainPanel(
          tags$p("Educational analysis using illustrative parameter ranges."),
          textOutput("owsa_summary"),
          tableOutput("owsa_table"),
          plotOutput("tornado_plot", height = "520px"),
          uiOutput("owsa_downloads")
        )
      )
    ),
    tabPanel(
      "Kaplan–Meier Curve",
      sidebarLayout(
        sidebarPanel(
          sliderInput("km_n_per_arm", "Number of patients per treatment arm",
                      min = 250, max = 5000, value = 1000, step = 250),
          sliderInput("km_followup_years", "Follow-up duration (years)",
                      min = 1, max = 10, value = 10, step = 1),
          numericInput("km_seed", "Random seed", value = 20261004,
                       min = 0, max = .Machine$integer.max, step = 1),
          checkboxInput("km_show_ci", "Show 95% confidence intervals", value = TRUE),
          checkboxInput("km_show_risk_table", "Show risk table", value = FALSE),
          checkboxInput("km_show_engaged_curves",
                        "Show engaged versus non-engaged eQalb exploratory curves",
                        value = FALSE),
          actionButton("simulate_km", "Simulate and update curve")
        ),
        mainPanel(
          tags$div(
            class = "alert alert-warning",
            tags$strong(SIMULATED_DATA_NOTICE),
            tags$p("Educational simulation only; not based on a clinical trial."),
            tags$p(SIMULATED_EVENT_NOTE),
            tags$p(paste(
              "The existing model has no cardiovascular-death incidence input.",
              "Other-cause death is treated as a competing censoring event."
            ))
          ),
          tags$h4("KM simulation assumptions"),
          tableOutput("km_assumptions"),
          tags$p(class = "text-muted", paste(
            "Relative risk reduction and both engagement values are live global",
            "inputs from the Cost-effectiveness tab, not hard-coded values, and",
            "they do affect the curve. They are the same values used by the",
            "economic model base case, so there is no Kaplan-Meier versus",
            "economic-model difference in these inputs."
          )),
          tags$h4(SIMULATED_DATA_NOTICE),
          plotOutput("km_plot", height = "780px"),
          conditionalPanel(
            condition = "input.km_show_engaged_curves === true",
            tags$h4("Exploratory engagement curves: ", SIMULATED_DATA_NOTICE),
            plotOutput("km_engagement_plot", height = "520px")
          ),
          tags$h4("Results table: ", SIMULATED_DATA_NOTICE),
          tableOutput("km_results"),
          tags$h4("Log-rank comparison"),
          textOutput("km_logrank"),
          tags$div(
            class = "alert alert-info",
            tags$strong("How to read the at-risk table"),
            tags$p(paste(
              "The number at risk includes participants who have not yet",
              "experienced the event and have not been censored. It is not",
              "a measure of treatment adherence."
            ))
          ),
          tags$h4("Diagnostic table: ", SIMULATED_DATA_NOTICE),
          tags$p(paste(
            "Derived from the same simulated patient-level dataset that",
            "produced the curve above; no additional simulation is run."
          )),
          tableOutput("km_diagnostics"),
          tags$h4(
            "Yearly at-risk, event and censoring table: ", SIMULATED_DATA_NOTICE
          ),
          tableOutput("km_yearly_diagnostics"),
          tags$h4("eQalb arm check: ", SIMULATED_DATA_NOTICE),
          tableOutput("km_arm_check"),
          tags$h4("Traffic-light interpretation: ", SIMULATED_DATA_NOTICE),
          uiOutput("km_interpretation_panel"),
          uiOutput("km_downloads")
        )
      )
    ),
    tabPanel(
      "DHT Readiness & Implementation",
      sidebarLayout(
        sidebarPanel(
          tags$h5("Population and access"),
          numericInput("target_population",
                       "Clinical target population",
                       value = 100000, min = 0, step = 1000),
          sliderInput("digital_access",
                      "Smartphone/internet access (%)",
                      min = 0, max = 100, value = 85, step = 1),
          sliderInput("digital_suitability",
                      "Digitally suitable population (%)",
                      min = 0, max = 100, value = 75, step = 1),
          tags$h5("Engagement"),
          sliderInput("readiness_year1_engagement",
                      "Year-1 engagement (%)",
                      min = 0, max = 100, value = 70, step = 1),
          sliderInput("readiness_followup_engagement",
                      "Follow-up engagement (%)",
                      min = 0, max = 100, value = 42, step = 1),
          tags$h5("Workflow burden"),
          numericInput("review_minutes",
                       "Clinician-review minutes per patient per month",
                       value = 10, min = 0, step = 1),
          tags$h5("Accessibility and language"),
          numericInput("supported_languages",
                       "Number of supported languages",
                       value = 1, min = 1, step = 1),
          checkboxInput("accessibility_features",
                        "Accessibility features available",
                        value = TRUE),
          tags$h5("Interoperability"),
          selectInput("interoperability",
                      "Interoperability maturity",
                      choices = DHT_INTEROPERABILITY_LEVELS,
                      selected = "PDF/manual export"),
          tags$h5("Algorithm governance"),
          selectInput("algorithm_governance",
                      "Algorithm change approach",
                      choices = DHT_ALGORITHM_APPROACHES,
                      selected = "Periodic controlled updates"),
          actionButton("assess_readiness", "Assess readiness"),
          actionButton("reset_readiness", "Reset values")
        ),
        mainPanel(
          tags$div(
            class = "alert alert-warning",
            tags$strong(DHT_DISCLAIMER)
          ),
          tags$p(DHT_THRESHOLD_NOTE),
          tags$h4("Traffic-light key"),
          tags$ul(lapply(DHT_TRAFFIC_LEGEND, tags$li)),
          uiOutput("readiness_notice"),
          tags$h4("Readiness overview"),
          uiOutput("readiness_cards"),
          tags$h4("Quantitative outputs"),
          tableOutput("readiness_numbers"),
          tags$h4("Domain assessment"),
          uiOutput("readiness_table"),
          tags$h4("Interpretation"),
          textOutput("readiness_interpretation")
        )
      )
    ),
    tabPanel(
      "Value of information",
      tags$div(
        class = "alert alert-warning",
        tags$strong("Simulated illustrative analysis — not clinical evidence.")
      ),
      tags$h3("Value of information"),
      tags$p(paste(
        "Value of information asks how much it would be worth to remove decision",
        "uncertainty. EVPI (expected value of perfect information) is the",
        "expected gain from eliminating uncertainty in every parameter at once.",
        "EVPPI (expected value of partial perfect information) is the expected",
        "gain from eliminating uncertainty in one parameter while the others stay",
        "uncertain. Both are reported per patient, at the reference",
        "willingness-to-pay threshold below, using the PSA simulations already",
        "computed in the Cost-effectiveness tab. The PSA is not rerun."
      )),
      tags$h4("Current PSA / VOI assumptions"),
      uiOutput("voi_assumptions"),
      tags$h4("Expected value of perfect information (EVPI)"),
      uiOutput("voi_status"),
      tableOutput("voi_evpi"),
      uiOutput("voi_uncertainty"),
      tags$h4("Expected value of partial perfect information (EVPPI)"),
      uiOutput("voi_evppi_status"),
      tableOutput("voi_evppi_table"),
      plotOutput("voi_evppi_plot", height = "420px"),
      tags$h4("Method and limitations"),
      tags$ul(
        tags$li(paste(
          "EVPI per patient is derived from the PSA simulations already stored in",
          "the Cost-effectiveness tab; the PSA is not rerun for this tab."
        )),
        tags$li(paste(
          "VOI uses the PSA distributions and parameter means defined by the PSA",
          "model. These may differ from the live base-case sliders used elsewhere",
          "in the app."
        )),
        tags$li(paste(
          "EVPPI is a single-loop regression-based approximation (a natural cubic",
          "spline of NMB on the sampled parameter), not a nested Monte Carlo",
          "estimate, and it can be imprecise when the number of simulations is",
          "small."
        )),
        tags$li(paste(
          "EVPI and EVPPI are per patient. Population EVPI is not calculated",
          "because the app has no defined research population, decision timeline,",
          "or population-incidence structure."
        )),
        tags$li(paste(
          "EVPI and EVPPI are not research budgets: they do not account for the",
          "cost, feasibility, or timeliness of collecting further evidence."
        )),
        tags$li(paste(
          "Only parameters that are actually present in the returned PSA draws are",
          "included, and EVPPI is shown only when at least 100 successful",
          "simulations are available."
        )),
        tags$li("Simulated illustrative analysis — not clinical evidence.")
      )
    ),
    tabPanel(
      "HTA decision summary",
      tags$div(
        class = "alert alert-warning",
        tags$strong(paste(
          "Simulated illustrative analysis — not clinical evidence and not an",
          "official HTA recommendation."
        ))
      ),
      tags$h3("HTA decision summary"),
      tags$p(paste(
        "This tab collects the existing outputs of the other tabs into an",
        "educational traffic-light dashboard and an evidence-generation plan.",
        "It does not recalculate anything: the values below come from the base",
        "case, the PSA, the value-of-information analysis, the budget-impact",
        "analysis and the DHT readiness assessment you have already run."
      )),
      uiOutput("hta_status"),
      tags$h4("Decision dashboard"),
      uiOutput("hta_dashboard"),
      tags$h4("Plain-language interpretation"),
      textOutput("hta_interpretation"),
      tags$h4("Evidence-generation plan"),
      tags$p(class = "text-muted", paste(
        "An educational mapping of the model's uncertainties onto possible",
        "evidence-generation activities. This is not a formal research",
        "protocol."
      )),
      textOutput("hta_evidence_summary"),
      tableOutput("hta_evidence_table"),
      tags$p(class = "text-muted", style = "font-size:12px;",
             HTA_EVIDENCE_NOTE),
      tags$h4("What is live and what is illustrative"),
      tags$ul(
        tags$li(paste(
          "Live inputs: the global assumptions in the Cost-effectiveness tab",
          "(price, implementation cost, savings, RRR, engagement and utilities),",
          "the PSA controls, the budget-impact controls, the DHT readiness",
          "inputs and the Kaplan-Meier inputs."
        )),
        tags$li(paste(
          "Illustrative outputs: every economic, PSA, value-of-information,",
          "budget-impact, survival and readiness figure is produced from",
          "simulated illustrative data and assumed input values."
        )),
        tags$li(paste(
          "This dashboard is an educational summary of the app's own outputs,",
          "not a validated HTA and not a reimbursement recommendation."
        ))
      )
    )
  )
  )
)
# nolint start: object_usage_linter
server <- function(input, output, session) {
  model_ready <- reactiveVal(FALSE)
  model_result <- eventReactive(input$run, {
    result <- run_eqalb_model(
      scenario_intervention_price = input$price,
      scenario_implementation_cost = input$implementation,
      scenario_healthcare_savings = input$savings,
      scenario_rrr = input$rrr / 100,
      scenario_engagement_year1 = input$engagement_year1 / 100,
      scenario_engagement_followup = input$engagement_followup / 100,
      scenario_utility_no_event = input$utility_no_event,
      scenario_utility_post_mi = input$utility_post_mi,
      scenario_utility_post_stroke = input$utility_post_stroke
    )
    result$input_values <- data.frame(
      parameter = c(
        "Annual intervention price", "Implementation cost",
        "Annual healthcare-use savings", "Relative risk reduction",
        "Year-1 engagement", "Follow-up engagement",
        "Utility: no event", "Utility: post-MI", "Utility: post-stroke"
      ),
      value = c(
        input$price, input$implementation, input$savings,
        input$rrr / 100, input$engagement_year1 / 100,
        input$engagement_followup / 100,
        input$utility_no_event, input$utility_post_mi,
        input$utility_post_stroke
      ),
      unit = c("EUR/person/year", "EUR/person", "EUR/person/year",
               "proportion", "proportion", "proportion",
               "utility", "utility", "utility"),
      stringsAsFactors = FALSE
    )
    model_ready(TRUE)
    result
  })

  # Minimal OWSA: run the current full-model base case and ten one-at-a-time scenarios.
  owsa_ready <- reactiveVal(FALSE)
  owsa_result <- eventReactive(input$run_owsa, {
    req(input$ow_sa_wtp, input$price, input$implementation, input$savings,
        input$rrr, input$engagement_year1, input$engagement_followup)
    validate(need(is.finite(input$ow_sa_wtp) && input$ow_sa_wtp >= 0,
                  "Willingness to pay must be a non-negative number."))

    base_args <- list(
      scenario_intervention_price = input$price,
      scenario_implementation_cost = input$implementation,
      scenario_healthcare_savings = input$savings,
      scenario_rrr = input$rrr / 100,
      scenario_engagement_year1 = input$engagement_year1 / 100,
      scenario_engagement_followup = input$engagement_followup / 100,
      scenario_utility_no_event = input$utility_no_event,
      scenario_utility_post_mi = input$utility_post_mi,
      scenario_utility_post_stroke = input$utility_post_stroke,
      scenario_cost_post_mi_year1 = cost_post_mi_year1,
      scenario_cost_post_mi_followup = cost_post_mi_followup,
      scenario_cost_post_stroke_year1 = cost_post_stroke_year1,
      scenario_cost_post_stroke_followup = cost_post_stroke_followup
    )
    base_model <- tryCatch(
      do.call(run_eqalb_model, base_args),
      error = function(error) {
        validate(need(FALSE, paste("Base-case model failed:", conditionMessage(error))))
      }
    )
    base_inmb <- base_model$incremental_qalys * input$ow_sa_wtp -
      base_model$incremental_cost

    parameters <- data.frame(
      parameter = c(
        "Annual intervention price",
        "Relative risk reduction",
        "Year-1 engagement",
        "Follow-up engagement",
        "Annual healthcare-use savings",
        "Implementation cost",
        "Post-MI cost",
        "Post-stroke cost",
        "Utility post-MI",
        "Utility post-stroke"
      ),
      model_argument = c(
        "scenario_intervention_price", "scenario_rrr",
        "scenario_engagement_year1", "scenario_engagement_followup",
        "scenario_healthcare_savings", "scenario_implementation_cost",
        "scenario_cost_post_mi_year1", "scenario_cost_post_stroke_year1",
        "scenario_utility_post_mi", "scenario_utility_post_stroke"
      ),
      base_value = c(
        input$price, input$rrr / 100, input$engagement_year1 / 100,
        input$engagement_followup / 100, input$savings, input$implementation,
        cost_post_mi_year1, cost_post_stroke_year1,
        input$utility_post_mi, input$utility_post_stroke
      ),
      low_value = c(
        input$ow_sa_low_price, input$ow_sa_low_rrr,
        input$ow_sa_low_engagement_year1, input$ow_sa_low_engagement_followup,
        input$ow_sa_low_savings, input$ow_sa_low_implementation,
        input$ow_sa_low_post_mi_cost, input$ow_sa_low_post_stroke_cost,
        input$ow_sa_low_utility_post_mi, input$ow_sa_low_utility_post_stroke
      ),
      high_value = c(
        input$ow_sa_high_price, input$ow_sa_high_rrr,
        input$ow_sa_high_engagement_year1, input$ow_sa_high_engagement_followup,
        input$ow_sa_high_savings, input$ow_sa_high_implementation,
        input$ow_sa_high_post_mi_cost, input$ow_sa_high_post_stroke_cost,
        input$ow_sa_high_utility_post_mi, input$ow_sa_high_utility_post_stroke
      ),
      stringsAsFactors = FALSE
    )

    run_scenario <- function(parameter, scenario, value) {
      scenario_args <- base_args
      if (parameter$model_argument == "scenario_cost_post_mi_year1") {
        followup_ratio <- base_args$scenario_cost_post_mi_followup /
          base_args$scenario_cost_post_mi_year1
        scenario_args$scenario_cost_post_mi_year1 <- value
        scenario_args$scenario_cost_post_mi_followup <- value * followup_ratio
      } else if (parameter$model_argument == "scenario_cost_post_stroke_year1") {
        followup_ratio <- base_args$scenario_cost_post_stroke_followup /
          base_args$scenario_cost_post_stroke_year1
        scenario_args$scenario_cost_post_stroke_year1 <- value
        scenario_args$scenario_cost_post_stroke_followup <- value * followup_ratio
      } else {
        scenario_args[[parameter$model_argument]] <- value
      }
      tryCatch({
        model <- do.call(run_eqalb_model, scenario_args)
        incremental_cost <- model$incremental_cost
        incremental_qalys <- model$incremental_qalys
        data.frame(
          parameter = parameter$parameter,
          scenario = scenario,
          parameter_value = value,
          incremental_cost = incremental_cost,
          incremental_qalys = incremental_qalys,
          icer = if (is.finite(incremental_qalys) && incremental_qalys != 0) {
            incremental_cost / incremental_qalys
          } else {
            NA_real_
          },
          inmb = incremental_qalys * input$ow_sa_wtp - incremental_cost,
          error_message = "",
          stringsAsFactors = FALSE
        )
      }, error = function(error) {
        data.frame(
          parameter = parameter$parameter,
          scenario = scenario,
          parameter_value = value,
          incremental_cost = NA_real_,
          incremental_qalys = NA_real_,
          icer = NA_real_,
          inmb = NA_real_,
          error_message = conditionMessage(error),
          stringsAsFactors = FALSE
        )
      })
    }

    scenarios <- do.call(rbind, lapply(seq_len(nrow(parameters)), function(i) {
      parameter <- parameters[i, , drop = FALSE]
      rbind(
        run_scenario(parameter, "Low", parameter$low_value),
        run_scenario(parameter, "High", parameter$high_value)
      )
    }))
    impact <- do.call(rbind, lapply(parameters$parameter, function(parameter_name) {
      pair <- scenarios[scenarios$parameter == parameter_name, ]
      data.frame(
        parameter = parameter_name,
        impact = abs(pair$inmb[pair$scenario == "High"] -
                       pair$inmb[pair$scenario == "Low"]),
        stringsAsFactors = FALSE
      )
    }))
    scenarios$impact <- impact$impact[match(scenarios$parameter, impact$parameter)]
    scenarios <- scenarios[order(scenarios$impact, decreasing = TRUE, na.last = TRUE), ]
    rownames(scenarios) <- NULL
    attr(scenarios, "base_inmb") <- base_inmb
    attr(scenarios, "wtp") <- input$ow_sa_wtp
    owsa_ready(TRUE)
    scenarios
  }, ignoreInit = TRUE)

  km_ready <- reactiveVal(FALSE)
  # Captured at simulation time so the panel reports the values the plotted
  # curve was actually generated with (eventReactive does not re-run when other
  # inputs change, so live inputs could otherwise disagree with the curve).
  km_assumptions_used <- reactiveVal(NULL)
  km_data <- eventReactive(input$simulate_km, {
    req(input$km_n_per_arm, input$km_followup_years, input$km_seed,
        input$rrr, input$engagement_year1, input$engagement_followup)
    validate(
      need(input$km_n_per_arm >= 250 && input$km_n_per_arm <= 5000,
           "Choose 250 to 5,000 patients per arm."),
      need(input$km_followup_years >= 1 && input$km_followup_years <= 10,
           "Choose 1 to 10 years of follow-up."),
      need(input$km_seed == floor(input$km_seed), "The random seed must be an integer.")
    )

    km_assumptions_used(list(
      rrr = input$rrr / 100,
      engagement_year1 = input$engagement_year1 / 100,
      engagement_followup = input$engagement_followup / 100,
      followup_years = input$km_followup_years,
      n_per_arm = input$km_n_per_arm,
      seed = input$km_seed
    ))

    data <- simulate_eqalb_survival(
      n_per_arm = input$km_n_per_arm,
      followup_years = input$km_followup_years,
      seed = input$km_seed,
      rrr = input$rrr / 100,
      engagement_year1 = input$engagement_year1 / 100,
      engagement_followup = input$engagement_followup / 100,
      p_mi = p_mi_usual_care,
      p_stroke = p_stroke_usual_care,
      p_other_death = p_other_death
    )
    km_ready(TRUE)
    data
  }, ignoreInit = TRUE)

  km_plot_object <- reactive({
    data <- km_data()
    req(nrow(data) > 0)
    data$treatment <- factor(
      data$treatment,
      levels = c("Usual care", "eQalb plus usual care")
    )
    fit <- survival::survfit(
      survival::Surv(time_years, event_status) ~ treatment,
      data = data
    )
    plot <- survminer::ggsurvplot(
      fit,
      data = data,
      conf.int = input$km_show_ci,
      risk.table = input$km_show_risk_table,
      risk.table.height = 0.25,
      risk.table.title = paste("Patients at risk -", SIMULATED_DATA_NOTICE),
      break.time.by = 1,
      xlim = c(0, input$km_followup_years),
      xlab = "Time since enrolment (years)",
      ylab = "Event-free survival probability",
      title = paste("Kaplan-Meier curve -", SIMULATED_DATA_NOTICE),
      legend.title = "Treatment group",
      legend.labs = levels(data$treatment),
      ggtheme = ggplot2::theme_minimal(base_size = 12)
    )
    plot$plot <- plot$plot + ggplot2::labs(
      subtitle = paste(strwrap(SIMULATED_EVENT_NOTE, width = 78), collapse = "\n")
    )
    plot
  })

  km_exploratory_plot_object <- reactive({
    req(input$km_show_engaged_curves)
    data <- km_data()
    data$exploratory_group <- dplyr::case_when(
      data$treatment == "Usual care" ~ "Usual care",
      data$engagement_status == "Engaged in year 1" ~
        "eQalb - engaged in year 1",
      TRUE ~ "eQalb - not engaged in year 1"
    )
    data$exploratory_group <- factor(
      data$exploratory_group,
      levels = c(
        "Usual care",
        "eQalb - engaged in year 1",
        "eQalb - not engaged in year 1"
      )
    )
    fit <- survival::survfit(
      survival::Surv(time_years, event_status) ~ exploratory_group,
      data = data
    )
    plot <- survminer::ggsurvplot(
      fit,
      data = data,
      conf.int = input$km_show_ci,
      risk.table = FALSE,
      break.time.by = 1,
      xlim = c(0, input$km_followup_years),
      xlab = "Time since enrolment (years)",
      ylab = "Event-free survival probability",
      title = paste("Exploratory year-1 engagement groups -", SIMULATED_DATA_NOTICE),
      legend.title = "Exploratory group",
      legend.labs = levels(data$exploratory_group),
      ggtheme = ggplot2::theme_minimal(base_size = 12)
    )
    plot$plot <- plot$plot + ggplot2::labs(
      subtitle = paste(
        strwrap(
          paste("Year-1 engagement grouping is exploratory.", SIMULATED_EVENT_NOTE),
          width = 78
        ),
        collapse = "\n"
      )
    )
    plot
  })

  output$results <- renderTable({
    res <- model_result()

    data.frame(
      Measure = c("Incremental cost", "Incremental QALYs", "ICER"),
      Value = c(
        format_euros(res$incremental_cost),
        format(round(res$incremental_qalys, 5), nsmall = 5),
        paste0(format_euros(res$icer), "/QALY")
      )
    )
  })

  icer_plot_object <- reactive({
    res <- model_result()
    plane <- data.frame(
      strategy = c("Usual care", "eQalb + usual care"),
      incremental_qalys = c(0, res$incremental_qalys),
      incremental_cost = c(0, res$incremental_cost)
    )
    qaly_limits <- range(plane$incremental_qalys)
    qaly_padding <- max(diff(qaly_limits) * 0.4, 0.001)
    cost_limits <- range(plane$incremental_cost)
    cost_padding <- max(diff(cost_limits) * 0.2, 1)
    qaly_limits <- qaly_limits + c(-qaly_padding, qaly_padding)
    cost_limits <- cost_limits + c(-cost_padding, cost_padding)

    ggplot(plane, aes(x = incremental_qalys, y = incremental_cost)) +
      geom_hline(yintercept = 0, colour = "grey75") +
      geom_vline(xintercept = 0, colour = "grey75") +
      annotate(
        "segment",
        x = 0, y = 0,
        xend = res$incremental_qalys, yend = res$incremental_cost,
        colour = "#287D78",
        linewidth = 1,
        arrow = grid::arrow(length = grid::unit(0.18, "inches"))
      ) +
      geom_point(aes(colour = strategy), size = 4) +
      geom_text(aes(label = strategy), nudge_y = diff(range(plane$incremental_cost)) * 0.08,
                hjust = 0, show.legend = FALSE) +
      coord_cartesian(xlim = qaly_limits, ylim = cost_limits, expand = FALSE) +
      scale_colour_manual(values = c("Usual care" = "#D37345", "eQalb + usual care" = "#287D78")) +
      scale_y_continuous(
        labels = scales::label_number(prefix = "€", big.mark = ",")
      ) +
      labs(
        title = "Cost-effectiveness plane",
        subtitle = paste0("ICER: ", format_euros(res$icer), " per QALY"),
        x = "Incremental QALYs",
        y = "Incremental cost (€)",
        colour = NULL
      ) +
      theme_minimal(base_size = 13) +
      theme(legend.position = "bottom")
  })

  output$icer_plot <- renderPlot({
    icer_plot_object()
  }, height = 480)

  ce_export_results <- reactive({
    res <- model_result()
    outcome_rows <- data.frame(
      section = "Model result",
      parameter = c("Incremental cost", "Incremental QALYs", "ICER"),
      value = c(res$incremental_cost, res$incremental_qalys, res$icer),
      unit = c("EUR/person", "QALYs/person", "EUR/QALY"),
      stringsAsFactors = FALSE
    )
    input_rows <- res$input_values
    input_rows$section <- "Model input"
    input_rows <- input_rows[, c("section", "parameter", "value", "unit")]
    rbind(input_rows, outcome_rows)
  })

  output$ce_downloads <- renderUI({
    if (!isTRUE(model_ready())) {
      return(tags$div(
        class = "btn-group",
        tags$button("Download results (CSV)", class = "btn btn-default", disabled = NA),
        tags$button("Download CE plane (PNG)", class = "btn btn-default", disabled = NA),
        tags$button("Download CE plane (PDF)", class = "btn btn-default", disabled = NA)
      ))
    }
    tags$div(
      class = "btn-group",
      downloadButton("download_ce_csv", "Download results (CSV)"),
      downloadButton("download_ce_png", "Download CE plane (PNG)"),
      downloadButton("download_ce_pdf", "Download CE plane (PDF)")
    )
  })

  output$download_ce_csv <- downloadHandler(
    filename = function() "eqalb_cost_effectiveness_results.csv",
    content = function(file) {
      results <- ce_export_results()
      req(nrow(results) > 0)
      utils::write.csv(results, file, row.names = FALSE)
    }
  )

  save_icer_plot <- function(file, device) {
    plot <- icer_plot_object()
    ggplot2::ggsave(
      filename = file,
      plot = plot,
      device = device,
      width = 9,
      height = 6,
      dpi = 300,
      bg = "white"
    )
  }

  output$download_ce_png <- downloadHandler(
    filename = function() "eqalb_cost_effectiveness_plane.png",
    content = function(file) save_icer_plot(file, "png")
  )

  output$download_ce_pdf <- downloadHandler(
    filename = function() "eqalb_cost_effectiveness_plane.pdf",
    content = function(file) save_icer_plot(file, "pdf")
  )

  # Phase 1 PSA: runs only when the user clicks Run probabilistic analysis.
  psa_result <- shiny::eventReactive(input$run_psa, {
    if (is.null(input$run_psa) || input$run_psa < 1) {
      return(NULL)
    }
    validate(
      need(
        is.numeric(input$psa_n_sim) && input$psa_n_sim >= 100,
        "Number of PSA simulations must be at least 100."
      ),
      need(
        is.numeric(input$psa_seed) && input$psa_seed >= 1,
        "PSA random seed must be a positive integer."
      ),
      need(
        is.numeric(input$psa_max_wtp) && input$psa_max_wtp >= 0,
        "Maximum willingness-to-pay threshold must be non-negative."
      )
    )
    progress <- shiny::Progress$new(session = session, min = 0, max = 1)
    on.exit(progress$close(), add = TRUE)
    progress$set(
      value = 0,
      message = "Running probabilistic sensitivity analysis",
      detail = "Preparing simulations"
    )
    tryCatch(
      run_psa_eqalb(
        n_sim = input$psa_n_sim,
        seed = input$psa_seed,
        max_wtp = input$psa_max_wtp,
        intervention_price = input$price,
        implementation = input$implementation,
        savings = input$savings,
        rrr = input$rrr / 100,
        engagement_year1 = input$engagement_year1 / 100,
        engagement_followup = input$engagement_followup / 100,
        no_event_utility = input$utility_no_event,
        post_mi_utility = input$utility_post_mi,
        post_stroke_utility = input$utility_post_stroke,
        progress = function(current, total) {
          progress$set(
            value = current / total,
            detail = sprintf("Simulation %d of %d", current, total)
          )
        }
      ),
      error = function(error) {
        validate(need(FALSE, paste("PSA failed:", conditionMessage(error))))
      }
    )
  })

  output$psa_status <- renderUI({
    if (!is.null(psa_result())) {
      return(NULL)
    }
    tags$p(paste(
      "Set the PSA assumptions and click Run probabilistic analysis.",
      "The PSA is not rerun when the inputs change."
    ))
  })

  output$psa_summary <- renderTable({
    result <- psa_result()
    req(result)
    probability <- result$probability_cost_effective
    probability_text <- function(threshold) {
      key <- format(threshold, big.mark = ",", scientific = FALSE, trim = TRUE)
      paste0(format(round(probability[[key]] * 100, 1), nsmall = 1), "%")
    }
    reference_wtp <- input$psa_reference_wtp
    reference_probability <- psa_probability_cost_effective(
      result$results, reference_wtp
    )
    reference_label <- paste0(
      "Probability cost-effective at reference WTP (€",
      format(reference_wtp, big.mark = ",", scientific = FALSE),
      "/QALY)"
    )
    reference_value <- paste0(
      format(round(reference_probability * 100, 1), nsmall = 1), "%"
    )
    data.frame(
      Measure = c(
        "Simulations requested",
        "Successful simulations",
        "Failed simulations",
        "Mean incremental cost",
        "Mean incremental QALYs",
        "Median ICER (where interpretable)",
        reference_label,
        "Probability cost-effective at €50,000/QALY",
        "Probability cost-effective at €100,000/QALY",
        "Probability cost-effective at €150,000/QALY"
      ),
      Value = c(
        format(result$n_requested, big.mark = ","),
        format(result$n_successful, big.mark = ","),
        format(result$n_failed, big.mark = ","),
        format_euros(result$mean_incremental_cost),
        format(round(result$mean_incremental_qalys, 5), nsmall = 5),
        if (is.na(result$median_icer)) {
          "Not interpretable"
        } else {
          paste0(format_euros(result$median_icer), "/QALY")
        },
        reference_value,
        probability_text(50000),
        probability_text(100000),
        probability_text(150000)
      ),
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  psa_plane_object <- reactive({
    result <- psa_result()
    req(result)
    ggplot2::ggplot(
      result$results,
      ggplot2::aes(x = incremental_qalys, y = incremental_cost)
    ) +
      ggplot2::geom_hline(yintercept = 0, colour = "grey80") +
      ggplot2::geom_vline(xintercept = 0, colour = "grey80") +
      ggplot2::geom_abline(
        slope = input$psa_reference_wtp,
        intercept = 0,
        linetype = "dashed",
        colour = "#D37345"
      ) +
      ggplot2::geom_point(colour = "#287D78", alpha = 0.4, size = 1.6) +
      ggplot2::scale_y_continuous(
        labels = scales::label_number(prefix = "€", big.mark = ",")
      ) +
      ggplot2::labs(
        title = "PSA cost-effectiveness plane",
        subtitle = "Simulated illustrative data — not clinical evidence",
        caption = paste0(
          "Dashed line: reference willingness-to-pay threshold of €",
          format(input$psa_reference_wtp, big.mark = ",", scientific = FALSE),
          " per QALY."
        ),
        x = "Incremental QALYs",
        y = "Incremental cost (€)"
      ) +
      ggplot2::theme_minimal(base_size = 13)
  })

  output$psa_plane <- renderPlot({
    psa_plane_object()
  }, height = 480)

  psa_ceac_object <- reactive({
    result <- psa_result()
    req(result)
    ggplot2::ggplot(
      result$ceac,
      ggplot2::aes(x = wtp, y = probability)
    ) +
      ggplot2::geom_hline(
        yintercept = 0.5, linetype = "dashed", colour = "grey40"
      ) +
      ggplot2::geom_vline(
        xintercept = c(50000, 100000, 150000),
        linetype = "dotted",
        colour = "grey55"
      ) +
      ggplot2::geom_line(colour = "#287D78", linewidth = 1) +
      ggplot2::scale_x_continuous(
        labels = scales::label_number(prefix = "€", big.mark = ",")
      ) +
      ggplot2::scale_y_continuous(limits = c(0, 1)) +
      ggplot2::labs(
        title = "Cost-effectiveness acceptability curve",
        subtitle = paste(
          "Probability is conditional on this model and its illustrative",
          "uncertainty distributions."
        ),
        x = "Willingness-to-pay threshold (€ per QALY)",
        y = "Probability cost-effective"
      ) +
      ggplot2::theme_minimal(base_size = 13)
  })

  output$psa_ceac <- renderPlot({
    psa_ceac_object()
  }, height = 480)

  # Value of information (VOI). EVPI and EVPPI are derived from the PSA results
  # already stored in psa_result(); the PSA is not rerun.
  voi_evpi_result <- reactive({
    result <- psa_result()
    req(result)
    voi_evpi(result$results, wtp = input$psa_reference_wtp,
             tolerance = VOI_TOLERANCE)
  })

  voi_evppi_result <- reactive({
    result <- psa_result()
    req(result)
    voi_evppi(
      result$results,
      wtp = input$psa_reference_wtp,
      tolerance = VOI_TOLERANCE
    )
  })

  output$voi_status <- renderUI({
    # Read input$run_psa before psa_result(): reading an eventReactive that has
    # not been triggered yet blocks, so the "run the PSA first" message must not
    # depend on psa_result().
    if (is.null(input$run_psa) || input$run_psa < 1) {
      return(tags$div(
        class = "alert alert-info",
        paste(
          "Run the PSA first (Cost-effectiveness tab, then Run probabilistic",
          "analysis). Value of information is calculated from those PSA",
          "simulations and does not rerun the PSA."
        )
      ))
    }
    if (isTRUE(voi_evpi_result()$clamped)) {
      return(tags$p(paste(
        "Note: a negative EVPI within the numerical tolerance of",
        format(VOI_TOLERANCE, scientific = TRUE), "euros was set to zero."
      )))
    }
    NULL
  })

  output$voi_assumptions <- renderTable({
    result <- psa_result()
    req(result)
    data.frame(
      Item = c(
        "Reference willingness-to-pay threshold",
        "PSA simulations requested",
        "PSA simulations used",
        "PSA random seed",
        "PSA parameter means and distributions"
      ),
      Value = c(
        paste0(format_euros_signed(input$psa_reference_wtp), " per QALY"),
        format(result$n_requested, big.mark = ","),
        format(result$n_successful, big.mark = ","),
        format(as.integer(input$psa_seed), scientific = FALSE, trim = TRUE),
        "Defined by the PSA model, not by the live global sliders"
      ),
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$voi_evpi <- renderTable({
    result <- psa_result()
    req(result)
    evpi <- voi_evpi_result()
    probability <- psa_probability_cost_effective(
      result$results, input$psa_reference_wtp
    )
    decision <- if (evpi$mean_nmb > VOI_TOLERANCE) {
      "eQalb (positive mean net monetary benefit)"
    } else if (evpi$mean_nmb < -VOI_TOLERANCE) {
      "Usual care (net monetary benefit of zero)"
    } else {
      "Indifferent (mean net monetary benefit is approximately zero)"
    }
    data.frame(
      Measure = c(
        "Reference willingness-to-pay threshold",
        "Number of PSA simulations used",
        "Mean incremental cost",
        "Mean incremental QALYs",
        "Mean incremental net monetary benefit",
        "Current preferred decision",
        "Probability eQalb is cost-effective",
        "Expected NMB with perfect information",
        "Expected NMB under the current decision",
        "EVPI per patient"
      ),
      Value = c(
        paste0(format_euros_signed(input$psa_reference_wtp), " per QALY"),
        format(evpi$n, big.mark = ","),
        format_euros_signed(evpi$mean_incremental_cost),
        format(round(evpi$mean_incremental_qalys, 6), nsmall = 6),
        format_euros_signed(evpi$mean_nmb),
        decision,
        paste0(format(round(100 * probability, 1), nsmall = 1), "%"),
        format_euros_signed(evpi$expected_nmb_perfect),
        format_euros_signed(evpi$expected_nmb_current),
        format_euros_signed(evpi$evpi)
      ),
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  # Compact traffic-light interpretation of decision uncertainty. Presentation
  # only: the status is derived from the EVPI and the probability of
  # cost-effectiveness already computed above.
  output$voi_uncertainty <- renderUI({
    result <- psa_result()
    req(result)
    evpi <- voi_evpi_result()
    probability <- psa_probability_cost_effective(
      result$results, input$psa_reference_wtp
    )
    assessment <- voi_uncertainty_status(
      probability_cost_effective = probability,
      evpi = evpi$evpi,
      mean_nmb = evpi$mean_nmb,
      tolerance = VOI_TOLERANCE
    )
    style <- KM_STATUS_STYLES[[assessment$status]]

    tags$div(
      tags$div(
        style = paste0(
          "background-color:", style[["background"]], ";",
          "border:1px solid ", style[["border"]], ";",
          "color:", style[["text"]], ";",
          "border-radius:4px;padding:12px;margin-bottom:10px;"
        ),
        tags$h4(
          style = "margin-top:0;",
          paste0(
            toupper(assessment$status), " \u2014 ", assessment$label
          )
        ),
        assessment$interpretation
      ),
      wellPanel(
        tags$strong("What this means"), tags$br(),
        assessment$what_this_means
      ),
      tags$p(
        class = "text-muted",
        style = "font-size:12px;",
        paste(
          "VOI uses the PSA distributions and parameter means defined by the",
          "PSA model. These may differ from the live base-case sliders",
          "elsewhere in the app."
        )
      ),
      tags$p(
        class = "text-muted",
        style = "font-size:12px;",
        assessment$thresholds
      ),
      tags$p(tags$strong(
        "Simulated illustrative analysis \u2014 not clinical evidence."
      ))
    )
  })

  output$voi_evppi_status <- renderUI({
    result <- psa_result()
    if (is.null(result)) {
      return(NULL)
    }
    evppi <- voi_evppi_result()
    if (!isTRUE(evppi$available)) {
      return(tags$div(class = "alert alert-info", evppi$reason))
    }
    notes <- list()
    if (all(evppi$table$evppi <= VOI_TOLERANCE)) {
      notes <- c(notes, list(tags$p(paste(
        "At this willingness-to-pay threshold, no single parameter is expected",
        "to change the preferred decision on its own, so every EVPPI is",
        "approximately zero. Resolving uncertainty in one parameter at a time",
        "would add no expected value here."
      ))))
    }
    if (isTRUE(evppi$any_clamped)) {
      notes <- c(notes, list(tags$p(paste(
        "Note: small negative EVPPI values within the numerical tolerance of",
        format(VOI_TOLERANCE, scientific = TRUE), "euros were set to zero."
      ))))
    }
    if (isTRUE(evppi$exceeds)) {
      notes <- c(notes, list(tags$div(
        class = "alert alert-warning",
        paste(
          "The regression approximation produced an EVPPI above the EVPI for at",
          "least one parameter, which is a numerical artefact of the single-loop",
          "method. Values are shown unaltered rather than clipped; treat these",
          "estimates with caution and prefer a larger PSA."
        )
      )))
    }
    if (length(notes) == 0L) {
      return(NULL)
    }
    tags$div(notes)
  })

  output$voi_evppi_table <- renderTable({
    result <- psa_result()
    req(result)
    evppi <- voi_evppi_result()
    req(isTRUE(evppi$available))
    share <- if (isTRUE(all.equal(evppi$evpi, 0))) {
      rep("not applicable", nrow(evppi$table))
    } else {
      paste0(
        format(round(100 * evppi$table$evppi / evppi$evpi, 1), nsmall = 1), "%"
      )
    }
    data.frame(
      Parameter = evppi$table$parameter,
      `EVPPI per patient` = format_euros_signed(evppi$table$evppi),
      `Share of EVPI` = share,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$voi_evppi_plot <- renderPlot({
    result <- psa_result()
    req(result)
    evppi <- voi_evppi_result()
    req(isTRUE(evppi$available))
    table <- evppi$table
    table$parameter <- factor(
      table$parameter, levels = rev(table$parameter)
    )
    ggplot2::ggplot(table, ggplot2::aes(x = parameter, y = evppi)) +
      ggplot2::geom_col(fill = "#287D78") +
      ggplot2::geom_hline(
        yintercept = evppi$evpi, linetype = "dashed", colour = "#D37345"
      ) +
      ggplot2::coord_flip() +
      ggplot2::scale_y_continuous(
        labels = scales::label_number(prefix = "€", big.mark = ",")
      ) +
      ggplot2::labs(
        title = "EVPPI per patient by parameter",
        subtitle = paste(
          "Dashed line: EVPI per patient. Simulated illustrative analysis —",
          "not clinical evidence."
        ),
        x = NULL,
        y = "EVPPI per patient (€)"
      ) +
      ggplot2::theme_minimal(base_size = 12)
  }, height = 420)

  # Budget impact analysis (BIA): runs only when the user clicks the button.
  # Inputs are read inside isolate() so the analysis never re-runs on its own.
  bia_result <- eventReactive(input$run_bia, {
    if (is.null(input$run_bia) || input$run_bia < 1) {
      return(NULL)
    }
    params <- isolate(list(
      population = input$bia_population,
      year1_uptake_pct = input$bia_year1_uptake,
      annual_uptake_increase_pp = input$bia_annual_uptake_increase,
      horizon_years = input$bia_horizon,
      # Shared product assumptions, defined once in the global section.
      intervention_price = input$price,
      implementation_cost_per_new_user = input$implementation,
      healthcare_savings_per_active_user = input$savings,
      avoided_event_savings_per_active_user = input$bia_avoided_event_savings,
      followup_engagement_pct = input$engagement_followup
    ))
    validate(
      need(
        is.numeric(params$population) && params$population >= 0,
        "Eligible clinical target population must be zero or greater."
      ),
      need(
        is.numeric(params$year1_uptake_pct) &&
          params$year1_uptake_pct >= 0 && params$year1_uptake_pct <= 100,
        "Year-1 uptake must be between 0 and 100 percent."
      ),
      need(
        is.numeric(params$annual_uptake_increase_pp) &&
          params$annual_uptake_increase_pp >= 0,
        "Annual uptake increase cannot be negative."
      ),
      need(
        is.numeric(params$horizon_years) && params$horizon_years >= 1 &&
          params$horizon_years <= 10,
        "Budget-impact horizon must be between 1 and 10 years."
      ),
      need(
        is.numeric(params$intervention_price) &&
          params$intervention_price >= 0,
        "Annual intervention price cannot be negative."
      ),
      need(
        is.numeric(params$implementation_cost_per_new_user) &&
          params$implementation_cost_per_new_user >= 0,
        "Implementation cost per new user cannot be negative."
      ),
      need(
        is.numeric(params$healthcare_savings_per_active_user) &&
          params$healthcare_savings_per_active_user >= 0,
        "Annual healthcare-use savings cannot be negative."
      ),
      need(
        is.numeric(params$avoided_event_savings_per_active_user) &&
          params$avoided_event_savings_per_active_user >= 0,
        "Annual avoided-event savings cannot be negative."
      )
    )
    tryCatch(
      do.call(calculate_budget_impact, params),
      error = function(error) {
        validate(need(FALSE, paste(
          "Budget impact analysis failed:", conditionMessage(error)
        )))
      }
    )
  })

  output$bia_status <- renderUI({
    if (!is.null(bia_result())) {
      return(NULL)
    }
    tags$p(paste(
      "Set the budget-impact assumptions and click Run budget impact analysis.",
      "The analysis is not rerun when the inputs change."
    ))
  })

  output$bia_table <- renderTable({
    result <- bia_result()
    req(result)
    data.frame(
      Year = result$year,
      `Uptake (%)` = format(round(result$uptake_pct, 1), nsmall = 1),
      `New users` = format(round(result$new_users), big.mark = ","),
      `Cumulative users` = format(round(result$cumulative_users), big.mark = ","),
      `Gross intervention cost` = format_euros_signed(
        result$gross_intervention_cost
      ),
      `Implementation cost` = format_euros_signed(result$implementation_cost),
      `Healthcare-use savings` = format_euros_signed(result$healthcare_savings),
      `Avoided-event savings` = format_euros_signed(
        result$avoided_event_savings
      ),
      `Net budget impact` = format_euros_signed(result$net_budget_impact),
      `Cumulative budget impact` = format_euros_signed(
        result$cumulative_budget_impact
      ),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$bia_summary <- renderTable({
    result <- bia_result()
    req(result)
    horizon <- nrow(result)
    data.frame(
      Measure = c(
        sprintf("Total budget impact over the horizon (%d years)", horizon),
        "Total intervention cost",
        "Total implementation cost",
        "Total healthcare-use savings",
        "Total avoided-event savings"
      ),
      Value = c(
        format_euros_signed(sum(result$net_budget_impact)),
        format_euros_signed(sum(result$gross_intervention_cost)),
        format_euros_signed(sum(result$implementation_cost)),
        format_euros_signed(sum(result$healthcare_savings)),
        format_euros_signed(sum(result$avoided_event_savings))
      ),
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  bia_plot_object <- reactive({
    result <- bia_result()
    req(result)
    result$direction <- ifelse(
      result$net_budget_impact >= 0, "Net cost", "Net saving"
    )
    ggplot2::ggplot(
      result,
      ggplot2::aes(x = factor(year), y = net_budget_impact, fill = direction)
    ) +
      ggplot2::geom_hline(yintercept = 0, colour = "grey40") +
      ggplot2::geom_col() +
      ggplot2::scale_fill_manual(
        values = c("Net cost" = "#D37345", "Net saving" = "#287D78"),
        name = NULL
      ) +
      ggplot2::scale_y_continuous(
        labels = scales::label_number(prefix = "€", big.mark = ",")
      ) +
      ggplot2::labs(
        title = "Budget impact analysis: annual net budget impact",
        subtitle = paste(
          "Educational budget-impact analysis using illustrative assumptions"
        ),
        x = "Year",
        y = "Annual net budget impact (€)"
      ) +
      ggplot2::theme_minimal(base_size = 13) +
      ggplot2::theme(legend.position = "bottom")
  })

  output$bia_plot <- renderPlot({
    bia_plot_object()
  }, height = 420)

  output$bia_interpretation <- renderText({
    result <- bia_result()
    req(result)
    horizon <- nrow(result)
    total_net <- sum(result$net_budget_impact)
    cost_components <- c(
      "gross intervention cost" = sum(result$gross_intervention_cost),
      "implementation cost" = sum(result$implementation_cost)
    )
    largest_component <- names(cost_components)[which.max(cost_components)]
    direction <- if (total_net > 0) {
      paste0("a net cost of ", format_euros_signed(total_net))
    } else if (total_net < 0) {
      paste0("a net saving of ", format_euros_signed(abs(total_net)))
    } else {
      "broadly budget neutral"
    }
    paste(
      sprintf(
        paste(
          "Over the selected %d-year horizon the programme produces %s",
          "(net budget impact %s)."
        ),
        horizon, direction, format_euros_signed(total_net)
      ),
      sprintf(
        "The largest cost component is the %s (%s over the horizon).",
        largest_component, format_euros_signed(max(cost_components))
      ),
      paste(
        "Uptake assumptions strongly affect the total: higher or faster uptake",
        "increases the number of active users and therefore both costs and",
        "savings."
      ),
      paste(
        "Budget impact measures payer affordability over time; it does not",
        "measure cost-effectiveness or value for money, so read it alongside",
        "the ICER and the cost-effectiveness plane rather than instead of them."
      ),
      BIA_DISCLAIMER
    )
  })

  output$owsa_summary <- renderText({
    if (input$run_owsa == 0) {
      return("Set the assumptions and click Run sensitivity analysis.")
    }
    result <- owsa_result()
    impact_by_parameter <- tapply(result$impact, result$parameter, function(x) x[[1]])
    top_parameters <- names(sort(impact_by_parameter, decreasing = TRUE))[1:3]
    top_parameters <- top_parameters[!is.na(top_parameters)]
    details <- vapply(top_parameters, function(parameter) {
      scenarios <- result[result$parameter == parameter, ]
      if (any(nzchar(scenarios$error_message))) {
        return(paste0(parameter, ": at least one scenario failed"))
      }
      low_inmb <- scenarios$inmb[scenarios$scenario == "Low"]
      high_inmb <- scenarios$inmb[scenarios$scenario == "High"]
      threshold_status <- if (xor(low_inmb >= 0, high_inmb >= 0)) {
        "crosses the WTP decision threshold"
      } else {
        "does not cross the WTP decision threshold"
      }
      paste0(parameter, ": ", threshold_status)
    }, character(1))
    paste(c(
      paste("Top parameters by absolute low-to-high INMB range:",
            paste(details, collapse = " | ")),
      paste("Base-case INMB: €", format(round(attr(result, "base_inmb")), big.mark = ",",
                     scientific = FALSE),
        " at WTP €", format(round(attr(result, "wtp")), big.mark = ",",
                scientific = FALSE), "/QALY.", sep = ""),
      "One-way analysis varies one parameter at a time; it does not represent joint parameter uncertainty."
    ), collapse = "\n")
  })

  output$owsa_table <- renderTable({
    result <- owsa_result()
    result[, c(
      "parameter", "scenario", "parameter_value", "incremental_cost",
      "incremental_qalys", "icer", "inmb", "error_message"
    )]
  }, rownames = FALSE, striped = TRUE, bordered = TRUE, hover = TRUE)

  owsa_plot_object <- reactive({
    result <- owsa_result()
    successful <- result[nzchar(result$error_message) == FALSE & is.finite(result$inmb), ]
    validate(need(nrow(successful) > 0, "No successful low/high scenarios to plot."))
    order_data <- successful[successful$scenario == "Low", c("parameter", "impact")]
    order_data <- order_data[order(order_data$impact, decreasing = TRUE), ]
    parameter_order <- rev(order_data$parameter)
    successful$parameter <- factor(successful$parameter, levels = parameter_order)
    successful$scenario <- factor(successful$scenario, levels = c("Low", "High"))

    ggplot(successful, aes(x = inmb, y = parameter, fill = scenario)) +
      geom_col(position = position_dodge(width = 0.8), width = 0.7) +
      geom_vline(xintercept = attr(result, "base_inmb"),
                 colour = "black", linetype = "dashed") +
      scale_fill_manual(values = c(Low = "#2F6DB0", High = "#E68613")) +
      scale_x_continuous(labels = scales::label_number(prefix = "€", big.mark = ",")) +
      labs(
        title = "One-way sensitivity analysis: incremental net monetary benefit",
        subtitle = paste(
          "WTP threshold: €",
          format(round(attr(result, "wtp")), big.mark = ",", scientific = FALSE),
          "per QALY"
        ),
        x = "Incremental net monetary benefit (€)",
        y = NULL,
        fill = "Scenario"
      ) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom")
  })

  output$tornado_plot <- renderPlot({
    owsa_plot_object()
  }, height = 520)

  output$owsa_downloads <- renderUI({
    if (!isTRUE(owsa_ready())) {
      return(tags$div(
        class = "btn-group",
        tags$button("Download OWSA table (CSV)", class = "btn btn-default", disabled = NA),
        tags$button("Download tornado (PNG)", class = "btn btn-default", disabled = NA)
      ))
    }
    tags$div(
      class = "btn-group",
      downloadButton("download_owsa_csv", "Download OWSA table (CSV)"),
      downloadButton("download_owsa_png", "Download tornado (PNG)")
    )
  })

  output$download_owsa_csv <- downloadHandler(
    filename = function() "eqalb_owsa_results.csv",
    content = function(file) {
      utils::write.csv(owsa_result(), file, row.names = FALSE, na = "")
    }
  )

  output$download_owsa_png <- downloadHandler(
    filename = function() "eqalb_tornado_inmb.png",
    content = function(file) {
      ggplot2::ggsave(
        filename = file,
        plot = owsa_plot_object(),
        device = "png",
        width = 9,
        height = 6,
        dpi = 300,
        bg = "white"
      )
    }
  )

  # Transparent record of the exact values the Kaplan-Meier simulation uses.
  output$km_assumptions <- renderTable({
    used <- km_assumptions_used()
    if (is.null(used)) {
      # Before the first simulation: show the values a run would use.
      used <- list(
        rrr = input$rrr / 100,
        engagement_year1 = input$engagement_year1 / 100,
        engagement_followup = input$engagement_followup / 100,
        followup_years = input$km_followup_years,
        n_per_arm = input$km_n_per_arm,
        seed = input$km_seed
      )
    }
    percent <- function(value) sprintf("%.1f%%", 100 * value)
    data.frame(
      Assumption = c(
        "Usual-care MI risk (annual)",
        "Usual-care stroke risk (annual)",
        "Relative risk reduction (RRR)",
        "Year-1 engagement",
        "Follow-up engagement",
        "Follow-up duration",
        "Patients per treatment arm",
        "Random seed",
        "Event definition",
        "Censoring / competing-event rule"
      ),
      Value = c(
        percent(p_mi_usual_care),
        percent(p_stroke_usual_care),
        paste0(percent(used$rrr),
               " - live global input; applied only to engaged eQalb",
               " patient-years"),
        percent(used$engagement_year1),
        percent(used$engagement_followup),
        sprintf("%d years", as.integer(used$followup_years)),
        format(as.integer(used$n_per_arm), big.mark = ","),
        format(as.integer(used$seed), scientific = FALSE, trim = TRUE),
        SIMULATED_EVENT_NOTE,
        sprintf(
          paste(
            "Other-cause death is treated as competing censoring at the same",
            "annual probability in both arms (%.1f%%); administrative",
            "end-of-follow-up censoring occurs at the selected follow-up",
            "duration."
          ),
          100 * p_other_death
        )
      ),
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$km_plot <- renderPlot({
    print(km_plot_object())
  }, height = 780)

  output$km_engagement_plot <- renderPlot({
    print(km_exploratory_plot_object())
  }, height = 520)

  output$km_results <- renderTable({
    data <- km_data()
    summary <- summarize_eqalb_survival(data, input$km_followup_years)
    display_survival <- function(value, year) {
      if (year > input$km_followup_years || is.na(value)) {
        "Not observed during selected follow-up"
      } else {
        sprintf("%.3f", value)
      }
    }

    data.frame(
      `Treatment arm` = summary$treatment,
      `Patients enrolled` = summary$patients_enrolled,
      `Events` = summary$events,
      `Censored` = summary$censored,
      `Median event-free survival (years)` = ifelse(
        is.na(summary$median_event_free_survival_years),
        "Not estimable",
        sprintf("%.2f", summary$median_event_free_survival_years)
      ),
      `Event-free at 1 year` = vapply(summary$event_free_at_1_year, display_survival,
                                      character(1), year = 1),
      `Event-free at 5 years` = vapply(summary$event_free_at_5_years, display_survival,
                                      character(1), year = 5),
      `Event-free at 10 years` = vapply(summary$event_free_at_10_years, display_survival,
                                       character(1), year = 10),
      check.names = FALSE
    )
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$km_logrank <- renderText({
    data <- km_data()
    req(nrow(data) > 0)
    if (sum(data$event_status) == 0L) {
      return(paste("Descriptive log-rank p-value: not estimable.", SIMULATED_DATA_NOTICE))
    }
    test <- survival::survdiff(
      survival::Surv(time_years, event_status) ~ treatment,
      data = data
    )
    p_value <- stats::pchisq(test$chisq, df = length(test$n) - 1, lower.tail = FALSE)
    paste0(
      "Descriptive log-rank p-value (simulated data only): ",
      format.pval(p_value, digits = 3, eps = 0.001),
      ". ", SIMULATED_DATA_NOTICE
    )
  })

  km_diagnostics <- reactive({
    diagnose_eqalb_survival(km_data(), input$km_followup_years)
  })

  km_arm_check_result <- reactive({
    expected_events <- expected_eqalb_events(
      n_per_arm = input$km_n_per_arm,
      followup_years = input$km_followup_years,
      rrr = input$rrr / 100,
      engagement_year1 = input$engagement_year1 / 100,
      engagement_followup = input$engagement_followup / 100,
      p_mi = p_mi_usual_care,
      p_stroke = p_stroke_usual_care,
      p_other_death = p_other_death
    )
    assess_eqalb_arm_contrast(
      km_data(),
      expected_events = expected_events
    )
  })

  output$km_diagnostics <- renderTable({
    summary <- km_diagnostics()$summary
    display_time <- function(value) {
      if (is.na(value)) "Not estimable" else sprintf("%.2f", value)
    }

    data.frame(
      `Treatment arm` = summary$treatment,
      `Patients initially enrolled` = summary$patients_enrolled,
      `Composite cardiovascular events` = summary$events,
      `Censored (total)` = summary$censored,
      `- competing other-cause death` = summary$competing_deaths,
      `- administrative end of follow-up` = summary$admin_censored,
      `Still event-free and observed at end of follow-up` =
        summary$event_free_observed_at_end,
      `Mean event time among events (years)` =
        vapply(summary$mean_event_time_years, display_time, character(1)),
      `Median event time among events (years)` =
        vapply(summary$median_event_time_years, display_time, character(1)),
      `Event rate per 100 patients` =
        sprintf("%.1f", summary$event_rate_per_100),
      `Censoring rate per 100 patients` =
        sprintf("%.1f", summary$censoring_rate_per_100),
      check.names = FALSE
    )
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$km_yearly_diagnostics <- renderTable({
    yearly <- km_diagnostics()$yearly
    data.frame(
      `Treatment arm` = yearly$treatment,
      `Year` = yearly$year,
      `Number at risk` = yearly$at_risk,
      `Cumulative events` = yearly$cumulative_events,
      `Cumulative censored` = yearly$cumulative_censored,
      `Remaining event-free and observed` =
        yearly$remaining_event_free_observed,
      check.names = FALSE
    )
  }, striped = TRUE, bordered = TRUE, hover = TRUE, digits = 0)

  output$km_arm_check <- renderTable({
    km_arm_check_result()$checks
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$km_interpretation_panel <- renderUI({
    if (!isTRUE(km_ready())) {
      return(tags$p(paste(
        "Simulate a curve to show the illustrative traffic-light",
        "interpretation."
      )))
    }
    if (sum(km_data()$event_status) == 0L) {
      return(tags$p(paste(
        "Not estimable: no simulated composite events in this run.",
        SIMULATED_DATA_NOTICE
      )))
    }
    result <- km_arm_check_result()
    assessment <- assess_km_interpretation(
      km_diagnostics()$summary,
      logrank_p = result$logrank_p,
      hazard_ratio = result$hazard_ratio_cc_vs_uc,
      competing_death_p = result$competing_death_p
    )
    counts <- assessment$counts

    status_card <- function(domain, status, explanation) {
      style <- KM_STATUS_STYLES[[status]]
      tags$div(
        style = paste0(
          "background-color:", style[["background"]], ";",
          "border:1px solid ", style[["border"]], ";",
          "color:", style[["text"]], ";",
          "border-radius:4px;padding:10px;margin-bottom:10px;"
        ),
        tags$h4(
          style = "margin-top:0;",
          paste0(domain, " - ", status)
        ),
        tags$strong("Status: "), status, tags$br(),
        explanation
      )
    }

    overall_style <- KM_STATUS_STYLES[[assessment$overall_status]]
    domains <- assessment$domains

    tags$div(
      tags$div(
        style = paste0(
          "background-color:", overall_style[["background"]], ";",
          "border:1px solid ", overall_style[["border"]], ";",
          "color:", overall_style[["text"]], ";",
          "border-radius:4px;padding:12px;margin-bottom:10px;"
        ),
        tags$h4(
          style = "margin-top:0;",
          paste0("Overall status - ", assessment$overall_status)
        ),
        tags$strong("Interpretation: "), assessment$interpretation
      ),
      tags$table(
        class = "table table-striped table-bordered",
        tags$thead(tags$tr(
          tags$th("Simulated statistic"),
          tags$th("eQalb"),
          tags$th("Usual care")
        )),
        tags$tbody(
          tags$tr(
            tags$td("Composite cardiovascular events"),
            tags$td(counts$cc_events), tags$td(counts$uc_events)
          ),
          tags$tr(
            tags$td("Total censoring"),
            tags$td(counts$cc_censored), tags$td(counts$uc_censored)
          ),
          tags$tr(
            tags$td("Competing other-cause deaths"),
            tags$td(counts$cc_deaths), tags$td(counts$uc_deaths)
          ),
          tags$tr(
            tags$td("Administrative end-of-follow-up censoring"),
            tags$td(counts$cc_admin), tags$td(counts$uc_admin)
          )
        )
      ),
      tags$ul(
        tags$li(paste0(
          "Hazard ratio (eQalb vs usual care): ",
          km_number(counts$hazard_ratio)
        )),
        tags$li(paste0(
          "Log-rank p-value: ", km_p_value(counts$logrank_p)
        ))
      ),
      lapply(seq_len(nrow(domains)), function(i) {
        status_card(domains$Domain[i], domains$Status[i], domains$Explanation[i])
      }),
      tags$details(
        tags$summary("Traffic-light rules used"),
        tags$ul(lapply(assessment$rules, tags$li))
      )
    )
  })

  output$km_downloads <- renderUI({
    if (!isTRUE(km_ready())) {
      return(tags$div(
        class = "btn-group",
        tags$button("Download simulated data (CSV)", class = "btn btn-default", disabled = NA),
        tags$button("Download KM chart (PNG)", class = "btn btn-default", disabled = NA),
        tags$button("Download KM chart (PDF)", class = "btn btn-default", disabled = NA)
      ))
    }
    tags$div(
      class = "btn-group",
      downloadButton("download_km_csv", "Download simulated data (CSV)"),
      downloadButton("download_km_png", "Download KM chart (PNG)"),
      downloadButton("download_km_pdf", "Download KM chart (PDF)")
    )
  })

  output$download_km_csv <- downloadHandler(
    filename = function() "simulated_illustrative_data_not_clinical_evidence.csv",
    content = function(file) {
      data <- km_data()
      req(nrow(data) > 0)
      utils::write.csv(data, file, row.names = FALSE, na = "")
    }
  )

  save_km_plot <- function(file, device) {
    plot <- km_plot_object()
    if (identical(device, "png")) {
      grDevices::png(file, width = 10, height = 8, units = "in", res = 300, bg = "white")
    } else {
      grDevices::pdf(file, width = 10, height = 8, bg = "white")
    }
    print(plot)
    grDevices::dev.off()
  }

  output$download_km_png <- downloadHandler(
    filename = function() "simulated_illustrative_data_not_clinical_evidence_km.png",
    content = function(file) save_km_plot(file, "png")
  )

  output$download_km_pdf <- downloadHandler(
    filename = function() "simulated_illustrative_data_not_clinical_evidence_km.pdf",
    content = function(file) save_km_plot(file, "pdf")
  )

  readiness_state <- reactiveVal(NULL)

  observeEvent(input$assess_readiness, {
    validate(
      need(
        is.numeric(input$target_population) && input$target_population >= 0,
        "Clinical target population must be zero or greater."
      ),
      need(
        is.numeric(input$review_minutes) && input$review_minutes >= 0,
        "Clinician-review minutes per patient per month cannot be negative."
      ),
      need(
        is.numeric(input$supported_languages) && input$supported_languages >= 1,
        "The number of supported languages must be at least 1."
      )
    )
    result <- tryCatch(
      calculate_readiness(
        target_population = input$target_population,
        digital_access = input$digital_access,
        digital_suitability = input$digital_suitability,
        readiness_year1_engagement = input$readiness_year1_engagement,
        readiness_followup_engagement = input$readiness_followup_engagement,
        review_minutes = input$review_minutes,
        supported_languages = input$supported_languages,
        accessibility_features = isTRUE(input$accessibility_features),
        interoperability = input$interoperability,
        algorithm_governance = input$algorithm_governance
      ),
      error = function(error) {
        validate(need(FALSE, paste(
          "Readiness assessment failed:", conditionMessage(error)
        )))
      }
    )
    readiness_state(result)
  })

  observeEvent(input$reset_readiness, {
    updateNumericInput(session, "target_population", value = 100000)
    updateSliderInput(session, "digital_access", value = 85)
    updateSliderInput(session, "digital_suitability", value = 75)
    updateSliderInput(session, "readiness_year1_engagement", value = 70)
    updateSliderInput(session, "readiness_followup_engagement", value = 42)
    updateNumericInput(session, "review_minutes", value = 10)
    updateNumericInput(session, "supported_languages", value = 1)
    updateCheckboxInput(session, "accessibility_features", value = TRUE)
    updateSelectInput(session, "interoperability",
                      selected = "PDF/manual export")
    updateSelectInput(session, "algorithm_governance",
                      selected = "Periodic controlled updates")
    readiness_state(NULL)
  })

  output$readiness_notice <- renderUI({
    if (!is.null(readiness_state())) {
      return(NULL)
    }
    tags$div(
      class = "alert alert-info",
      "Enter or review the assumptions and click Assess readiness."
    )
  })

  output$readiness_cards <- renderUI({
    result <- readiness_state()
    req(result)
    cards <- result$cards
    lapply(seq_len(nrow(cards)), function(i) {
      style <- DHT_STATUS_STYLES[[cards$Status[i]]]
      tags$div(
        style = paste0(
          "background-color:", style[["background"]], ";",
          "border:1px solid ", style[["border"]], ";",
          "color:", style[["text"]], ";",
          "border-radius:4px;padding:10px;margin-bottom:10px;"
        ),
        tags$h4(
          style = "margin-top:0;",
          paste0(cards$Domain[i], " - ", cards$Status[i])
        ),
        tags$strong("Status: "), cards$Status[i], tags$br(),
        cards$Explanation[i]
      )
    })
  })

  output$readiness_numbers <- renderTable({
    result <- readiness_state()
    req(result)
    result$numbers
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  output$readiness_table <- renderUI({
    result <- readiness_state()
    req(result)
    domains <- result$domains
    header <- tags$tr(lapply(
      c("Domain", "Status", "Current input", "Plain-language interpretation"),
      tags$th
    ))
    body <- lapply(seq_len(nrow(domains)), function(i) {
      style <- DHT_STATUS_STYLES[[domains$Status[i]]]
      tags$tr(
        tags$td(tags$strong(domains$Domain[i])),
        tags$td(tags$span(
          style = paste0(
            "background-color:", style[["background"]], ";",
            "border:1px solid ", style[["border"]], ";",
            "color:", style[["text"]], ";",
            "padding:2px 8px;border-radius:3px;font-weight:bold;"
          ),
          domains$Status[i]
        )),
        tags$td(domains[["Current input"]][i]),
        tags$td(domains$Interpretation[i])
      )
    })
    tags$table(
      class = "table table-striped table-bordered",
      tags$thead(header),
      tags$tbody(body)
    )
  })

  output$readiness_interpretation <- renderText({
    result <- readiness_state()
    req(result)
    result$interpretation
  })

  # HTA decision summary. Presentation only: it reuses the reactives already
  # computed by the other tabs and never reruns a model, PSA or simulation.
  # Each button count is tested before its eventReactive is read, because
  # reading an untriggered eventReactive would block the renderer.
  hta_base <- reactive({
    if (is.null(input$run) || input$run < 1) {
      return(NULL)
    }
    model_result()
  })

  hta_psa <- reactive({
    if (is.null(input$run_psa) || input$run_psa < 1) {
      return(NULL)
    }
    psa_result()
  })

  hta_bia <- reactive({
    if (is.null(input$run_bia) || input$run_bia < 1) {
      return(NULL)
    }
    bia_result()
  })

  hta_summary <- reactive({
    base <- hta_base()
    psa <- hta_psa()
    bia <- hta_bia()
    reference_wtp <- input$psa_reference_wtp

    probability <- if (is.null(psa)) {
      NA_real_
    } else {
      psa_probability_cost_effective(psa$results, reference_wtp)
    }
    mean_nmb <- if (is.null(psa)) {
      NA_real_
    } else {
      mean(reference_wtp * psa$results$incremental_qalys -
             psa$results$incremental_cost)
    }
    evpi <- if (is.null(psa)) {
      NA_real_
    } else {
      voi_evpi(psa$results, wtp = reference_wtp,
               tolerance = VOI_TOLERANCE)$evpi
    }
    evppi <- if (is.null(psa)) {
      NULL
    } else {
      voi_evppi(psa$results, wtp = reference_wtp, tolerance = VOI_TOLERANCE)
    }
    highest_evppi <- if (!is.null(evppi) && isTRUE(evppi$available)) {
      evppi$table$evppi[1]
    } else {
      NA_real_
    }
    readiness <- readiness_state()

    assess_hta_decision_summary(
      icer = if (is.null(base)) NA_real_ else base$icer,
      reference_wtp = reference_wtp,
      probability_cost_effective = probability,
      mean_incremental_nmb = mean_nmb,
      evpi = evpi,
      highest_evppi = highest_evppi,
      cumulative_budget_impact = if (is.null(bia)) {
        NA_real_
      } else {
        sum(bia$net_budget_impact)
      },
      readiness_domains = if (is.null(readiness)) NULL else readiness$domains
    )
  })

  output$hta_status <- renderUI({
    notes <- list()
    if (is.null(hta_psa())) {
      notes <- c(notes, list(tags$div(
        class = "alert alert-info",
        paste(
          "The PSA has not been run in this session, so the economic-value and",
          "decision-uncertainty domains are not yet assessable. Run the",
          "probabilistic analysis in the Cost-effectiveness tab to populate",
          "them."
        )
      )))
    }
    if (is.null(hta_bia())) {
      notes <- c(notes, list(tags$div(
        class = "alert alert-info",
        paste(
          "The budget-impact analysis has not been run, so that domain is not",
          "yet assessable."
        )
      )))
    }
    if (is.null(readiness_state())) {
      notes <- c(notes, list(tags$div(
        class = "alert alert-info",
        paste(
          "Readiness has not been assessed, so the implementation-readiness",
          "domain is not yet assessable."
        )
      )))
    }
    if (length(notes) == 0L) {
      return(NULL)
    }
    tags$div(notes)
  })

  output$hta_dashboard <- renderUI({
    result <- hta_summary()
    domains <- result$domains
    overall_style <- KM_STATUS_STYLES[[result$overall_status]]

    status_card <- function(domain, status, measure, basis, interpretation) {
      if (!(status %in% c("Green", "Amber", "Red"))) {
        return(tags$div(
          style = paste0(
            "border:1px solid #dee2e6;border-radius:4px;",
            "padding:10px;margin-bottom:10px;"
          ),
          tags$h4(
            style = "margin-top:0;",
            paste0(domain, " - not yet available")
          ),
          tags$em(measure)
        ))
      }
      style <- KM_STATUS_STYLES[[status]]
      tags$div(
        style = paste0(
          "background-color:", style[["background"]], ";",
          "border:1px solid ", style[["border"]], ";",
          "color:", style[["text"]], ";",
          "border-radius:4px;padding:10px;margin-bottom:10px;"
        ),
        tags$h4(style = "margin-top:0;", paste0(domain, " - ", status)),
        tags$strong("Current values: "), measure, tags$br(),
        tags$strong("Basis: "), basis, tags$br(),
        interpretation
      )
    }

    tags$div(
      tags$div(
        style = paste0(
          "background-color:", overall_style[["background"]], ";",
          "border:1px solid ", overall_style[["border"]], ";",
          "color:", overall_style[["text"]], ";",
          "border-radius:4px;padding:12px;margin-bottom:12px;"
        ),
        tags$h4(
          style = "margin-top:0;",
          paste0("Overall status - ", result$overall_status)
        ),
        tags$strong("Provisional HTA position: "), result$position
      ),
      lapply(seq_len(nrow(domains)), function(i) {
        status_card(
          domains$Domain[i], domains$Status[i], domains$Measure[i],
          domains$Basis[i], domains$Interpretation[i]
        )
      }),
      tags$p(
        class = "text-muted",
        style = "font-size:12px;",
        HTA_SUMMARY_RULE_NOTE
      )
    )
  })

  output$hta_interpretation <- renderText({
    hta_summary()$interpretation
  })

  # Dynamic evidence priorities. Reuses hta_summary() (cached) for the dashboard
  # statuses and the same button-gated reactives for the current signals; it
  # never reruns an analysis.
  hta_evidence <- reactive({
    summary <- hta_summary()
    domains <- summary$domains
    status_of <- function(domain) {
      hit <- domains$Domain == domain
      if (!any(hit)) NA_character_ else domains$Status[which(hit)[1]]
    }
    base <- hta_base()
    psa <- hta_psa()
    bia <- hta_bia()
    reference_wtp <- input$psa_reference_wtp
    evppi <- if (is.null(psa)) {
      NULL
    } else {
      voi_evppi(psa$results, wtp = reference_wtp, tolerance = VOI_TOLERANCE)
    }
    evppi_table <- if (!is.null(evppi) && isTRUE(evppi$available)) {
      evppi$table
    } else {
      NULL
    }
    readiness <- readiness_state()

    build_hta_evidence_priorities(
      icer = if (is.null(base)) NA_real_ else base$icer,
      probability_cost_effective = if (is.null(psa)) {
        NA_real_
      } else {
        psa_probability_cost_effective(psa$results, reference_wtp)
      },
      evpi = if (is.null(psa)) {
        NA_real_
      } else {
        voi_evpi(psa$results, wtp = reference_wtp,
                 tolerance = VOI_TOLERANCE)$evpi
      },
      evppi_table = evppi_table,
      cumulative_budget_impact = if (is.null(bia)) {
        NA_real_
      } else {
        sum(bia$net_budget_impact)
      },
      bia_intervention_cost = if (is.null(bia)) {
        NA_real_
      } else {
        sum(bia$gross_intervention_cost)
      },
      bia_implementation_cost = if (is.null(bia)) {
        NA_real_
      } else {
        sum(bia$implementation_cost)
      },
      bia_healthcare_savings = if (is.null(bia)) {
        NA_real_
      } else {
        sum(bia$healthcare_savings)
      },
      annual_price = input$price,
      implementation_cost_per_new_user = input$implementation,
      savings_per_active_user = input$savings,
      rrr = input$rrr / 100,
      engagement_year1 = input$engagement_year1 / 100,
      engagement_followup = input$engagement_followup / 100,
      review_minutes = input$review_minutes,
      digital_access = input$digital_access,
      digital_suitability = input$digital_suitability,
      interoperability_maturity = input$interoperability,
      readiness_domains = if (is.null(readiness)) NULL else readiness$domains,
      economic_status = status_of("Economic value"),
      uncertainty_status = status_of("Decision uncertainty"),
      budget_status = status_of("Budget impact"),
      evidence_status = status_of("Clinical evidence maturity")
    )
  })

  output$hta_evidence_summary <- renderText({
    hta_evidence()$summary
  })

  output$hta_evidence_table <- renderTable({
    hta_evidence()$table
  }, striped = TRUE, bordered = TRUE, hover = TRUE)

  # ------------------------------------------------------------------
  # Consolidated results export ("Download complete results package").
  #
  # Presentation only: it reuses the reactives already computed by the other
  # tabs and never reruns a model, PSA, simulation, budget-impact analysis or
  # readiness assessment. Redrawing an already-cached plot object is not a
  # re-analysis. Each button count is tested before its eventReactive is read,
  # because reading an untriggered eventReactive would block the download.
  # ------------------------------------------------------------------
  psa_settings_used <- reactiveVal(NULL)

  observeEvent(input$run_psa, {
    if (is.null(input$run_psa) || input$run_psa < 1) {
      return(NULL)
    }
    psa_settings_used(list(
      seed = isolate(input$psa_seed),
      n_sim = isolate(input$psa_n_sim)
    ))
  })

  results_export <- reactive({
    base <- hta_base()
    psa <- hta_psa()
    bia <- hta_bia()
    owsa_available <- !is.null(input$run_owsa) && input$run_owsa >= 1
    km_available <- !is.null(input$simulate_km) && input$simulate_km >= 1
    readiness <- readiness_state()
    reference_wtp <- input$psa_reference_wtp

    items <- list()
    available <- character(0)
    missing <- character(0)
    add_item <- function(name, data, width = 9, height = 6) {
      type <- if (grepl("\\.csv$", name)) {
        "csv"
      } else if (grepl("\\.txt$", name)) {
        "text"
      } else {
        "plot"
      }
      items[[length(items) + 1L]] <<- list(
        name = name, payload = data, type = type, width = width, height = height
      )
    }

    # Base-case cost-effectiveness ------------------------------------
    if (is.null(base)) {
      missing <- c(missing, paste(
        "Base-case cost-effectiveness - click Run model in the",
        "Cost-effectiveness tab"
      ))
    } else {
      add_item("model_assumptions.csv", base$input_values)
      add_item("cost_effectiveness_summary.csv", data.frame(
        Measure = c(
          "Incremental cost (EUR per person)",
          "Incremental QALYs (per person)",
          "ICER (EUR per QALY)"
        ),
        Value = c(base$incremental_cost, base$incremental_qalys, base$icer),
        stringsAsFactors = FALSE
      ))
      add_item("cost_effectiveness_plane.png", icer_plot_object())
      available <- c(available, paste(
        "Base-case cost-effectiveness (model assumptions, cost-effectiveness",
        "summary and cost-effectiveness plane)"
      ))
    }

    # Probabilistic sensitivity analysis and the CEAC ------------------
    if (is.null(psa)) {
      missing <- c(missing, paste(
        "Probabilistic sensitivity analysis - click Run probabilistic analysis",
        "in the Cost-effectiveness tab"
      ))
    } else {
      settings <- psa_settings_used()
      probability_text <- function(threshold) {
        sprintf(
          "%.1f%%",
          100 * psa_probability_cost_effective(psa$results, threshold)
        )
      }
      add_item("psa_summary.csv", data.frame(
        Measure = c(
          "Simulations requested",
          "Successful simulations",
          "Failed simulations",
          "PSA random seed (recorded when the PSA was last run)",
          "Mean incremental cost (EUR per person)",
          "Mean incremental QALYs (per person)",
          "Median ICER (EUR per QALY, where interpretable)",
          sprintf(
            "Probability cost-effective at the reference threshold (EUR %s per QALY)",
            format(reference_wtp, big.mark = ",", scientific = FALSE)
          ),
          "Probability cost-effective at EUR 50,000 per QALY",
          "Probability cost-effective at EUR 100,000 per QALY",
          "Probability cost-effective at EUR 150,000 per QALY"
        ),
        Value = c(
          format(psa$n_requested, big.mark = ","),
          format(psa$n_successful, big.mark = ","),
          format(psa$n_failed, big.mark = ","),
          if (is.null(settings)) {
            "Not recorded"
          } else {
            format(settings$seed, scientific = FALSE)
          },
          format(round(psa$mean_incremental_cost, 2), big.mark = ",",
                 nsmall = 2, scientific = FALSE),
          format(round(psa$mean_incremental_qalys, 6), nsmall = 6,
                 scientific = FALSE),
          if (is.na(psa$median_icer)) {
            "Not interpretable"
          } else {
            format(round(psa$median_icer, 2), big.mark = ",", nsmall = 2,
                   scientific = FALSE)
          },
          probability_text(reference_wtp),
          probability_text(50000),
          probability_text(100000),
          probability_text(150000)
        ),
        stringsAsFactors = FALSE
      ))
      add_item("ceac.png", psa_ceac_object())
      available <- c(
        available,
        "Probabilistic sensitivity analysis (PSA summary and CEAC)"
      )
    }

    # Deterministic one-way sensitivity analysis -----------------------
    if (owsa_available) {
      add_item("tornado_diagram.png", owsa_plot_object(), width = 10, height = 7)
      available <- c(
        available,
        "Deterministic one-way sensitivity analysis (tornado diagram)"
      )
    } else {
      missing <- c(missing, paste(
        "Deterministic one-way sensitivity analysis - click Run sensitivity",
        "analysis in the Sensitivity Analysis tab"
      ))
    }

    # Budget-impact analysis -------------------------------------------
    if (is.null(bia)) {
      missing <- c(missing, paste(
        "Five-year budget-impact analysis - click Run budget impact analysis",
        "in the Cost-effectiveness tab"
      ))
    } else {
      add_item("budget_impact_results.csv", bia)
      add_item("budget_impact_plot.png", bia_plot_object())
      available <- c(available, "Five-year budget-impact analysis")
    }

    # Kaplan-Meier simulation ------------------------------------------
    if (km_available) {
      add_item("km_results.csv", km_diagnostics()$summary)
      add_item("km_curve.png", km_plot_object(), width = 10, height = 8)
      available <- c(
        available,
        "Kaplan-Meier simulation (simulated illustrative data)"
      )
    } else {
      missing <- c(missing, paste(
        "Kaplan-Meier simulation - click Simulate and update curve in the",
        "Kaplan-Meier Curve tab"
      ))
    }

    # DHT readiness and implementation ---------------------------------
    if (is.null(readiness)) {
      missing <- c(missing, paste(
        "DHT readiness and implementation assessment - click Assess readiness",
        "in the DHT Readiness & Implementation tab"
      ))
    } else {
      numbers <- readiness$numbers
      names(numbers) <- c("Item", "Value", "Basis")
      numbers$Section <- "Quantitative output"
      numbers$Status <- ""
      domains <- readiness$domains
      names(domains) <- c("Item", "Status", "Value", "Basis")
      domains$Section <- "Readiness domain"
      add_item(
        "dht_readiness_results.csv",
        rbind(
          numbers[, c("Section", "Item", "Status", "Value", "Basis")],
          domains[, c("Section", "Item", "Status", "Value", "Basis")]
        )
      )
      available <- c(available, "DHT readiness and implementation assessment")
    }

    # HTA decision summary and evidence priorities ---------------------
    hta <- hta_summary()
    evidence <- hta_evidence()
    add_item("hta_decision_summary.txt", c(
      "eQalb interactive HTA model - HTA decision summary",
      paste("Exported:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
      "",
      paste("Overall status:", hta$overall_status),
      paste("Provisional HTA position:", hta$position),
      "",
      "Dashboard domains",
      "-----------------",
      unlist(lapply(seq_len(nrow(hta$domains)), function(i) c(
        paste0("Domain: ", hta$domains$Domain[[i]]),
        paste0("  Status: ", hta$domains$Status[[i]]),
        paste0("  Measure: ", hta$domains$Measure[[i]]),
        paste0("  Basis: ", hta$domains$Basis[[i]]),
        paste0("  Interpretation: ", hta$domains$Interpretation[[i]]),
        ""
      ))),
      "Plain-language interpretation",
      "-----------------------------",
      hta$interpretation,
      "",
      HTA_SUMMARY_RULE_NOTE
    ))
    add_item("evidence_priorities.csv", evidence$table)
    available <- c(available, "HTA decision summary and evidence priorities")

    # README -----------------------------------------------------------
    psa_settings <- psa_settings_used()
    psa_lines <- if (is.null(psa)) {
      paste(
        "PSA seed and number of simulations: not available, because the",
        "probabilistic analysis has not been run in this session."
      )
    } else {
      c(
        paste(
          "PSA random seed (recorded when the PSA was last run):",
          if (is.null(psa_settings)) {
            "not recorded"
          } else {
            format(psa_settings$seed, scientific = FALSE)
          }
        ),
        paste(
          "PSA simulations in the exported results:",
          format(psa$n_requested, big.mark = ","), "requested,",
          format(psa$n_successful, big.mark = ","), "successful and",
          format(psa$n_failed, big.mark = ","), "failed."
        )
      )
    }

    readme <- c(
      "eQalb interactive HTA model - complete results package",
      "==============================================================",
      "",
      "App: eQalb interactive HTA model (educational R Shiny app)",
      paste("Exported:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
      "",
      "IMPORTANT",
      "---------",
      "Every output in this package is a simulated, illustrative result of an",
      "educational teaching model for a fictional digital therapeutic. None of",
      "it is clinical evidence, a validated health-technology assessment, or a",
      "regulatory, security or reimbursement assessment.",
      "",
      "Comparator and usual-care cost assumption",
      "----------------------------------------",
      "Usual care is the comparator arm, and the model is an incremental",
      "comparison between eQalb plus usual care and usual care alone.",
      "Routine-care, medication, monitoring and visit costs that are assumed",
      "identical in both arms are omitted, so no routine-care cost line appears",
      "in either arm; this is a modelling assumption, not an estimate that",
      "usual care costs nothing. Event-related post-MI and post-stroke state",
      "costs are included in both arms and differ only through the health-state",
      "occupancy each arm produces. The eQalb arm additionally adds the",
      "annual intervention price in every cycle and a one-off implementation",
      "cost per new user in cycle 1, and subtracts the annual healthcare-use",
      "saving. Incremental cost is the eQalb total cost minus the",
      "usual-care total cost. This is an educational, illustrative assumption;",
      "a real health-technology assessment should replace it with empirically",
      "sourced comparator and usual-care costs.",
      "",
      "PSA seed and number of simulations",
      "---------------------------------",
      psa_lines,
      "",
      "Analyses included in this package",
      "--------------------------------",
      if (length(available) == 0L) "-- none" else paste0("- ", available),
      "",
      "Analyses that had not been run in this session (no file included)",
      "----------------------------------------------------------------",
      if (length(missing) == 0L) {
        "-- none: every analysis was available"
      } else {
        paste0("- ", missing)
      },
      "",
      "Files in this package",
      "---------------------",
      paste0(
        "- ",
        c(
          "README.txt",
          vapply(items, function(item) item$name, character(1))
        )
      ),
      "",
      "A file is only included when the corresponding analysis had been run,",
      "so this package contains the currently available results rather than a",
      "fixed set of files.",
      "",
      HTA_EVIDENCE_NOTE
    )

    list(items = items, readme = readme)
  })

  output$download_results_package <- downloadHandler(
    filename = function() {
      paste0(
        "eqalb_results_",
        format(Sys.time(), "%Y-%m-%d_%H%M"),
        ".zip"
      )
    },
    content = function(file) {
      package <- results_export()
      write_results_package(file, package$items, package$readme)
    },
    contentType = "application/zip"
  )

  # Landing-page navigation. Presentation only: it switches which container is
  # visible and does not touch any analysis, calculation or input value.
  observeEvent(input$open_dashboard, {
    updateSelectInput(session, "nav_page", selected = "dashboard")
  })

  observeEvent(input$go_home, {
    updateSelectInput(session, "nav_page", selected = "home")
  })

  observeEvent(input$home_start_analysis, {
    updateSelectInput(session, "nav_page", selected = "start")
  })

  observeEvent(input$home_project_description, {
    updateSelectInput(session, "nav_page", selected = "description")
  })

  observeEvent(input$home_download_results, {
    updateSelectInput(session, "nav_page", selected = "export")
  })

  observeEvent(input$home_back_from_description, {
    updateSelectInput(session, "nav_page", selected = "home")
  })

  observeEvent(input$home_back_from_export, {
    updateSelectInput(session, "nav_page", selected = "home")
  })

  observeEvent(input$home_back_from_start, {
    updateSelectInput(session, "nav_page", selected = "home")
  })
}
# nolint end: object_usage_linter

shinyApp(ui, server)