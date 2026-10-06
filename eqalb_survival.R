SIMULATED_DATA_NOTICE <- "Simulated illustrative data — not clinical evidence"
SIMULATED_EVENT_NOTE <- paste(
  "The event proxy is first MI or stroke. A cardiovascular-death incidence",
  "input is not available in the supplied model; other-cause death is treated",
  "as a competing censoring event."
)

simulate_eqalb_survival <- function(
  n_per_arm = 1000L,
  followup_years = 10L,
  seed = 20261004L,
  rrr = 0.10,
  engagement_year1 = 0.70,
  engagement_followup = 0.42,
  p_mi = 0.015,
  p_stroke = 0.010,
  p_other_death = 0.020
) {
  if (length(n_per_arm) != 1L || is.na(n_per_arm) || n_per_arm < 1) {
    stop("n_per_arm must be a positive number.", call. = FALSE)
  }
  if (length(followup_years) != 1L || is.na(followup_years) || followup_years < 1) {
    stop("followup_years must be at least 1.", call. = FALSE)
  }
  if (length(seed) != 1L || is.na(seed) || seed < 0 || seed > .Machine$integer.max) {
    stop("seed must be an integer between 0 and .Machine$integer.max.", call. = FALSE)
  }
  if (any(c(rrr, engagement_year1, engagement_followup, p_mi, p_stroke,
            p_other_death) < 0) ||
      any(c(rrr, engagement_year1, engagement_followup, p_mi, p_stroke,
            p_other_death) > 1)) {
    stop("Risks, engagement rates, and relative risk reduction must be in [0, 1].",
         call. = FALSE)
  }

  n_per_arm <- as.integer(n_per_arm)
  followup_years <- as.integer(followup_years)
  set.seed(as.integer(seed))

  event_risk_usual <- p_mi + p_stroke
  if (event_risk_usual + p_other_death > 1) {
    stop("The event and competing-death probabilities cannot sum above 1.",
         call. = FALSE)
  }

  simulate_arm <- function(treatment) {
    n <- n_per_arm
    is_eqalb <- treatment == "eQalb plus usual care"
    event_time <- rep(followup_years, n)
    event_status <- integer(n)
    censoring_reason <- rep("Administrative end of follow-up", n)
    event_type <- rep(NA_character_, n)
    year1_engaged <- rep(NA, n)
    active <- seq_len(n)

    for (year in seq_len(followup_years)) {
      if (length(active) == 0L) break

      if (is_eqalb) {
        engagement_probability <- if (year == 1L) engagement_year1 else engagement_followup
        engaged_this_year <- stats::runif(length(active)) < engagement_probability
        if (year == 1L) year1_engaged[active] <- engaged_this_year
      } else {
        engaged_this_year <- rep(FALSE, length(active))
      }

      risk_this_year <- rep(event_risk_usual, length(active))
      if (is_eqalb) {
        risk_this_year[engaged_this_year] <- event_risk_usual * (1 - rrr)
      }

      outcome_draw <- stats::runif(length(active))
      has_event <- outcome_draw < risk_this_year
      has_competing_death <- outcome_draw >= risk_this_year &
        outcome_draw < risk_this_year + p_other_death
      terminal <- has_event | has_competing_death

      if (any(terminal)) {
        terminal_ids <- active[terminal]
        event_time[terminal_ids] <- year - 1 + stats::runif(sum(terminal))
        event_ids <- active[has_event]
        event_status[event_ids] <- 1L
        censoring_reason[event_ids] <- "First major cardiovascular event"
        if (length(event_ids) > 0L) {
          event_type[event_ids] <- ifelse(
            stats::runif(length(event_ids)) < p_mi / event_risk_usual,
            "Myocardial infarction",
            "Stroke"
          )
        }
        death_ids <- active[has_competing_death]
        censoring_reason[death_ids] <- "Competing other-cause death"
      }

      active <- active[!terminal]
    }

    data.frame(
      patient_id = paste0(if (is_eqalb) "CC" else "UC", "_", seq_len(n)),
      treatment = treatment,
      time_years = event_time,
      event_status = event_status,
      event_type = event_type,
      engagement_status = if (is_eqalb) {
        ifelse(year1_engaged, "Engaged in year 1", "Not engaged in year 1")
      } else {
        "Not applicable"
      },
      censoring_reason = censoring_reason,
      stringsAsFactors = FALSE
    )
  }

  simulated <- dplyr::bind_rows(
    simulate_arm("Usual care"),
    simulate_arm("eQalb plus usual care")
  )
  simulated$time_years <- pmin(simulated$time_years, followup_years)
  simulated$event_definition <- SIMULATED_EVENT_NOTE
  simulated$data_notice <- SIMULATED_DATA_NOTICE
  simulated
}

summarize_eqalb_survival <- function(data, followup_years) {
  groups <- c("Usual care", "eQalb plus usual care")
  dplyr::bind_rows(lapply(groups, function(group) {
    arm <- data[data$treatment == group, , drop = FALSE]
    fit <- survival::survfit(survival::Surv(time_years, event_status) ~ 1, data = arm)
    median_time <- unname(fit$table["median"])
    if (length(median_time) == 0L || !is.finite(median_time)) median_time <- NA_real_

    survival_at <- function(year) {
      if (year > followup_years) return(NA_real_)
      estimate <- summary(fit, times = year, extend = TRUE)$surv
      if (length(estimate) == 0L || !is.finite(estimate[[1]])) NA_real_ else estimate[[1]]
    }

    data.frame(
      treatment = group,
      patients_enrolled = nrow(arm),
      events = sum(arm$event_status == 1L),
      censored = sum(arm$event_status == 0L),
      median_event_free_survival_years = median_time,
      event_free_at_1_year = survival_at(1),
      event_free_at_5_years = survival_at(5),
      event_free_at_10_years = survival_at(10),
      stringsAsFactors = FALSE
    )
  }))
}

CENSORING_REASON_ADMIN <- "Administrative end of follow-up"
CENSORING_REASON_COMPETING_DEATH <- "Competing other-cause death"

# Diagnostics are derived from the same simulated patient-level dataset that
# feeds survfit() and the Kaplan-Meier plot; no new simulation is performed.
diagnose_eqalb_survival <- function(data, followup_years) {
  groups <- c("Usual care", "eQalb plus usual care")
  followup_years <- as.integer(followup_years)
  event <- data$event_status == 1L
  admin_censored <- data$censoring_reason == CENSORING_REASON_ADMIN
  competing_death <- data$censoring_reason == CENSORING_REASON_COMPETING_DEATH

  summary_rows <- lapply(groups, function(group) {
    in_arm <- data$treatment == group
    arm_event <- in_arm & event
    arm_event_times <- data$time_years[arm_event]
    n_enrolled <- sum(in_arm)
    n_events <- sum(arm_event)
    n_censored <- sum(in_arm & !event)
    mean_event_time <- if (n_events > 0L) mean(arm_event_times) else NA_real_
    median_event_time <- if (n_events > 0L) {
      stats::median(arm_event_times)
    } else {
      NA_real_
    }
    data.frame(
      treatment = group,
      patients_enrolled = n_enrolled,
      events = n_events,
      censored = n_censored,
      competing_deaths = sum(in_arm & competing_death),
      admin_censored = sum(in_arm & admin_censored),
      event_free_observed_at_end = sum(in_arm & admin_censored),
      mean_event_time_years = mean_event_time,
      median_event_time_years = median_event_time,
      event_rate_per_100 = 100 * n_events / n_enrolled,
      censoring_rate_per_100 = 100 * n_censored / n_enrolled,
      stringsAsFactors = FALSE
    )
  })

  yearly_rows <- lapply(groups, function(group) {
    in_arm <- data$treatment == group
    times <- data$time_years[in_arm]
    arm_event <- event[in_arm]
    years <- 0:followup_years
    data.frame(
      treatment = group,
      year = years,
      at_risk = vapply(years, function(year) sum(times >= year), numeric(1)),
      cumulative_events = vapply(
        years,
        function(year) sum(arm_event & times <= year),
        numeric(1)
      ),
      cumulative_censored = vapply(
        years,
        function(year) sum(!arm_event & times <= year),
        numeric(1)
      ),
      remaining_event_free_observed = vapply(
        years,
        function(year) sum(times > year),
        numeric(1)
      ),
      stringsAsFactors = FALSE
    )
  })

  list(
    summary = dplyr::bind_rows(summary_rows),
    yearly = dplyr::bind_rows(yearly_rows)
  )
}

# Deterministic expectation of the number of composite events under the modelled
# relative risk reduction, used as a benchmark for the simulated arm contrast.
expected_eqalb_events <- function(
  n_per_arm,
  followup_years,
  rrr,
  engagement_year1,
  engagement_followup,
  p_mi,
  p_stroke,
  p_other_death
) {
  event_risk <- p_mi + p_stroke
  followup_years <- as.integer(followup_years)

  cumulative_event_probability <- function(risk_year1, risk_followup) {
    survivors <- 1
    total <- 0
    for (year in seq_len(followup_years)) {
      risk <- event_risk * if (year == 1L) risk_year1 else risk_followup
      total <- total + survivors * risk
      survivors <- survivors * (1 - risk - p_other_death)
    }
    total
  }

  c(
    "Usual care" = n_per_arm * cumulative_event_probability(1, 1),
    "eQalb plus usual care" = n_per_arm * cumulative_event_probability(
      1 - rrr * engagement_year1,
      1 - rrr * engagement_followup
    )
  )
}

# Reports whether the eQalb arm has fewer events, more censoring, a
# reversed treatment effect, or a difference consistent with simulation noise.
assess_eqalb_arm_contrast <- function(data, expected_events = NULL) {
  usual_care <- "Usual care"
  eqalb <- "eQalb plus usual care"
  check_labels <- c(
    "1. Fewer composite cardiovascular events in eQalb",
    "2. More censoring in eQalb",
    "3. Reversed treatment effect (eQalb appears worse)",
    "4. Difference consistent with random simulation variation"
  )

  cc <- data[data$treatment == eqalb, , drop = FALSE]
  uc <- data[data$treatment == usual_care, , drop = FALSE]
  cc_events <- sum(cc$event_status == 1L)
  uc_events <- sum(uc$event_status == 1L)
  cc_censored <- sum(cc$event_status == 0L)
  uc_censored <- sum(uc$event_status == 0L)
  cc_deaths <- sum(cc$censoring_reason == CENSORING_REASON_COMPETING_DEATH)
  uc_deaths <- sum(uc$censoring_reason == CENSORING_REASON_COMPETING_DEATH)

  if (sum(data$event_status == 1L) < 2L) {
    not_estimable <- rep(
      "Not estimable: too few simulated events.",
      length(check_labels)
    )
    return(list(
      checks = data.frame(
        Check = check_labels,
        Finding = not_estimable,
        stringsAsFactors = FALSE
      ),
      logrank_p = NA_real_,
      hazard_ratio_cc_vs_uc = NA_real_,
      verdict = paste(
        "Too few simulated events to assess the arm contrast.",
        SIMULATED_DATA_NOTICE
      )
    ))
  }

  model_data <- data
  model_data$treatment <- factor(
    model_data$treatment,
    levels = c(usual_care, eqalb)
  )
  test <- survival::survdiff(
    survival::Surv(time_years, event_status) ~ treatment,
    data = model_data
  )
  p_value <- stats::pchisq(test$chisq, df = 1L, lower.tail = FALSE)
  hazard_ratio <- unname(exp(stats::coef(survival::coxph(
    survival::Surv(time_years, event_status) ~ treatment,
    data = model_data
  ))))

  fewer_events <- cc_events < uc_events
  more_censoring <- cc_censored > uc_censored
  reversed <- hazard_ratio > 1
  significant <- p_value < 0.05

  competing_death_p <- if (cc_deaths + uc_deaths > 0L) {
    stats::fisher.test(matrix(
      c(
        cc_deaths, cc_censored - cc_deaths,
        uc_deaths, uc_censored - uc_deaths
      ),
      nrow = 2L, byrow = TRUE
    ))$p.value
  } else {
    NA_real_
  }
  competing_death_display <- if (is.na(competing_death_p)) {
    "not estimable"
  } else {
    format.pval(competing_death_p, digits = 3, eps = 0.001)
  }

  expected_display <- if (!is.null(expected_events)) {
    sprintf(
      " Modelled expectation: %.0f vs %.0f events.",
      expected_events[[eqalb]], expected_events[[usual_care]]
    )
  } else {
    ""
  }

  events_finding <- sprintf(
    "%s (%d vs %d events; %+.0f).",
    if (fewer_events) "Yes" else "No",
    cc_events, uc_events, cc_events - uc_events
  )
  if (!is.null(expected_events)) {
    events_finding <- paste0(events_finding, expected_display)
  }

  censoring_finding <- paste0(
    if (more_censoring) "Yes" else "No",
    sprintf(
      " (%d vs %d censored; %+.0f): ",
      cc_censored, uc_censored, cc_censored - uc_censored
    ),
    sprintf(
      "%d vs %d are competing other-cause deaths (Fisher p = %s); ",
      cc_deaths, uc_deaths, competing_death_display
    ),
    sprintf(
      "%d vs %d are administrative end-of-follow-up censoring. ",
      cc_censored - cc_deaths, uc_censored - uc_deaths
    ),
    "The model applies the same other-cause death risk to both arms."
  )

  if (reversed && significant) {
    reversal_finding <- sprintf(
      paste(
        "Yes - the eQalb hazard ratio is %.3f (>1) with a",
        "significant log-rank difference (p = %s)."
      ),
      hazard_ratio, format.pval(p_value, digits = 3, eps = 0.001)
    )
  } else if (reversed) {
    reversal_finding <- sprintf(
      paste(
        "No - the point estimate is directionally reversed (hazard ratio",
        "%.3f) but the difference is not statistically significant (p = %s)."
      ),
      hazard_ratio, format.pval(p_value, digits = 3, eps = 0.001)
    )
  } else {
    reversal_finding <- sprintf(
      paste(
        "No - the direction matches the modelled relative risk reduction",
        "(hazard ratio %.3f)."
      ),
      hazard_ratio
    )
  }

  variation_finding <- sprintf(
    "%s - log-rank p = %s for the composite event.",
    if (significant) {
      "No, the between-arm difference is larger than simulation noise alone"
    } else {
      "Yes, the between-arm difference is within simulation noise"
    },
    format.pval(p_value, digits = 3, eps = 0.001)
  )

  expected_display <- if (!is.null(expected_events)) {
    sprintf(
      " Modelled expectation: %.0f vs %.0f events.",
      expected_events[[eqalb]], expected_events[[usual_care]]
    )
  } else {
    ""
  }

  verdict <- paste0(
    sprintf(
      paste(
        "Simulated composite events: eQalb %d vs usual care %d",
        "(hazard ratio %.3f, log-rank p = %s). "
      ),
      cc_events, uc_events, hazard_ratio,
      format.pval(p_value, digits = 3, eps = 0.001)
    ),
    if (reversed) {
      "The point estimate is directionally reversed; "
    } else {
      "The eQalb arm does not show more events; "
    },
    if (significant) {
      paste(
        "the difference is statistically significant within this",
        "simulated dataset. "
      )
    } else {
      paste(
        "the difference is not statistically significant and is",
        "consistent with random simulation variation. "
      )
    },
    if (more_censoring) {
      paste0(
        sprintf(
          "Total censoring is higher in eQalb (%d vs %d); ",
          cc_censored, uc_censored
        ),
        sprintf(
          "%d vs %d of these are competing other-cause deaths ",
          cc_deaths, uc_deaths
        ),
        sprintf(
          "(Fisher p = %s) and %d vs %d are administrative ",
          competing_death_display, cc_censored - cc_deaths,
          uc_censored - uc_deaths
        ),
        "end-of-follow-up censoring. Higher event-free survival leaves ",
        "more participants exposed to the competing death hazard, and ",
        "the model uses the same other-cause death risk in both arms. "
      )
    } else {
      paste0(
        sprintf(
          "Total censoring is not higher in eQalb (%d vs %d; ",
          cc_censored, uc_censored
        ),
        sprintf(
          "%d vs %d competing other-cause deaths). ",
          cc_deaths, uc_deaths
        )
      )
    },
    SIMULATED_DATA_NOTICE, "."
  )

  list(
    checks = data.frame(
      Check = check_labels,
      Finding = c(
        events_finding, censoring_finding, reversal_finding, variation_finding
      ),
      stringsAsFactors = FALSE
    ),
    logrank_p = p_value,
    hazard_ratio_cc_vs_uc = hazard_ratio,
    competing_death_p = competing_death_p,
    verdict = verdict
  )
}