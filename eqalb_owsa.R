# Parameter definitions: low/high bounds are illustrative assumptions, not CIs.
eqalb_owsa_parameters <- function() {
  data.frame(
    id = c(
      "intervention_price", "implementation_cost", "healthcare_savings", "rrr",
      "engagement_year1", "engagement_followup", "utility_no_event",
      "utility_post_mi", "utility_post_stroke", "cost_post_mi",
      "cost_post_stroke", "discount_rate_cost", "discount_rate_effect",
      "time_horizon"
    ),
    parameter = c(
      "Annual intervention price",
      "Implementation cost",
      "Annual healthcare-use savings",
      "Relative risk reduction among engaged users",
      "Year-1 engagement",
      "Follow-up engagement",
      "Utility: no prior cardiovascular event",
      "Utility: post-MI",
      "Utility: post-stroke",
      "Cost: post-MI (year-1 anchor)",
      "Cost: post-stroke (year-1 anchor)",
      "Cost discount rate",
      "Effect discount rate",
      "Time horizon"
    ),
    model_arg = c(
      "scenario_intervention_price", "scenario_implementation_cost",
      "scenario_healthcare_savings", "scenario_rrr",
      "scenario_engagement_year1", "scenario_engagement_followup",
      "scenario_utility_no_event", "scenario_utility_post_mi",
      "scenario_utility_post_stroke", "scenario_cost_post_mi_year1",
      "scenario_cost_post_stroke_year1", "scenario_discount_rate_cost",
      "scenario_discount_rate_effect", "scenario_cycles"
    ),
    low_default = c(180, 0, 0, 0.05, 0.50, 0.20, 0.80, 0.70, 0.45,
                    10000, 15000, 0.00, 0.00, 5),
    high_default = c(540, 100, 60, 0.15, 0.85, 0.60, 0.92, 0.90, 0.75,
                     20000, 25000, 0.05, 0.05, 20),
    stringsAsFactors = FALSE
  )
}

eqalb_owsa_outcome_labels <- c(
  inmb = "Incremental net monetary benefit",
  icer = "ICER",
  incremental_cost = "Incremental costs",
  incremental_qalys = "Incremental QALYs"
)

eqalb_owsa_format_wtp <- function(value) {
  format(round(value), big.mark = ",", scientific = FALSE, trim = TRUE)
}

eqalb_owsa_selected_value <- function(result, outcome, wtp) {
  if (!isTRUE(result$valid)) return(NA_real_)
  switch(
    outcome,
    inmb = result$inmb,
    icer = result$icer,
    incremental_cost = result$incremental_cost,
    incremental_qalys = result$incremental_qalys,
    stop("Unknown OWSA outcome.", call. = FALSE)
  )
}

# Scenario execution: every low/high call reuses the complete production model.
# nolint start: object_usage_linter
eqalb_owsa_run_scenario <- function(parameter, value, base_args, wtp, outcome) {
  scenario_args <- base_args
  scenario_args[[parameter$model_arg]] <- value

  if (parameter$id == "cost_post_mi") {
    followup_ratio <- base_args$scenario_cost_post_mi_followup /
      base_args$scenario_cost_post_mi_year1
    scenario_args$scenario_cost_post_mi_followup <- value * followup_ratio
  } else if (parameter$id == "cost_post_stroke") {
    followup_ratio <- base_args$scenario_cost_post_stroke_followup /
      base_args$scenario_cost_post_stroke_year1
    scenario_args$scenario_cost_post_stroke_followup <- value * followup_ratio
  }

  tryCatch({
    result <- do.call(run_eqalb_model, scenario_args)
    incremental_cost <- result$incremental_cost
    incremental_qalys <- result$incremental_qalys
    if (!is.finite(incremental_cost) || !is.finite(incremental_qalys)) {
      stop("The model returned a non-finite incremental result.")
    }

    inmb <- incremental_qalys * wtp - incremental_cost
    icer_is_interpretable <- incremental_qalys > 0 && is.finite(result$icer)
    warning <- if (incremental_qalys < 0 && incremental_cost > 0) {
      "Dominated: higher cost and fewer QALYs; ICER not interpretable."
    } else if (incremental_qalys <= 0) {
      "Non-positive incremental QALYs; ICER not interpretable."
    } else {
      ""
    }

    list(
      valid = TRUE,
      incremental_cost = incremental_cost,
      incremental_qalys = incremental_qalys,
      icer = if (icer_is_interpretable) result$icer else NA_real_,
      inmb = inmb,
      cost_effective = inmb >= 0,
      warning = warning
    )
  }, error = function(error) {
    list(
      valid = FALSE,
      incremental_cost = NA_real_,
      incremental_qalys = NA_real_,
      icer = NA_real_,
      inmb = NA_real_,
      cost_effective = NA,
      warning = paste("Model failed:", conditionMessage(error))
    )
  })
}

# OWSA calculation: compute the base case once, then run one low and one high
# scenario per parameter while holding all other model inputs fixed.
run_eqalb_owsa <- function(base_args, bounds, wtp, outcome) {
  base_result <- tryCatch(
    do.call(run_eqalb_model, base_args),
    error = function(error) stop(
      paste("Base-case model failed:", conditionMessage(error)),
      call. = FALSE
    )
  )
  base_values <- list(
    valid = TRUE,
    incremental_cost = base_result$incremental_cost,
    incremental_qalys = base_result$incremental_qalys,
    icer = if (base_result$incremental_qalys > 0) base_result$icer else NA_real_,
    inmb = base_result$incremental_qalys * wtp - base_result$incremental_cost
  )
  base_outcome <- eqalb_owsa_selected_value(base_values, outcome, wtp)
  if (!is.finite(base_outcome)) {
    stop("The selected base-case outcome is not interpretable.", call. = FALSE)
  }

  rows <- lapply(seq_len(nrow(bounds)), function(i) {
    parameter <- bounds[i, , drop = FALSE]
    base_value <- base_args[[parameter$model_arg]]
    low <- eqalb_owsa_run_scenario(
      parameter, parameter$low, base_args, wtp, outcome
    )
    high <- eqalb_owsa_run_scenario(
      parameter, parameter$high, base_args, wtp, outcome
    )
    selected_low <- eqalb_owsa_selected_value(low, outcome, wtp)
    selected_high <- eqalb_owsa_selected_value(high, outcome, wtp)
    impact <- if (is.finite(selected_low) && is.finite(selected_high)) {
      abs(selected_high - selected_low)
    } else {
      NA_real_
    }

    data.frame(
      parameter = parameter$parameter,
      parameter_id = parameter$id,
      base_value = base_value,
      low_value = parameter$low,
      high_value = parameter$high,
      low_incremental_cost = low$incremental_cost,
      high_incremental_cost = high$incremental_cost,
      low_incremental_qalys = low$incremental_qalys,
      high_incremental_qalys = high$incremental_qalys,
      low_icer = low$icer,
      high_icer = high$icer,
      low_inmb = low$inmb,
      high_inmb = high$inmb,
      selected_outcome_low = selected_low,
      selected_outcome_high = selected_high,
      impact_range = impact,
      low_cost_effective = low$cost_effective,
      high_cost_effective = high$cost_effective,
      low_warning = low$warning,
      high_warning = high$warning,
      stringsAsFactors = FALSE
    )
  })

  table <- do.call(rbind, rows)
  table <- table[order(table$impact_range, decreasing = TRUE, na.last = TRUE), ]
  rownames(table) <- NULL

  list(
    table = table,
    base = base_values,
    base_outcome = base_outcome,
    wtp = wtp,
    outcome = outcome,
    outcome_label = unname(eqalb_owsa_outcome_labels[[outcome]])
  )
}
# nolint end: object_usage_linter

eqalb_owsa_format_icer <- function(icer, incremental_cost, incremental_qalys) {
  if (incremental_qalys < 0 && incremental_cost > 0) return("Dominated")
  if (!is.finite(icer)) return("ICER not interpretable")
  format(round(icer, 2), big.mark = ",", nsmall = 2)
}

# Data reshaping: keep invalid ICER scenarios out of the numeric tornado while
# retaining their warning and numeric NAs in the full results table.
eqalb_owsa_tornado_data <- function(result) {
  table <- result$table
  valid <- is.finite(table$selected_outcome_low) &
    is.finite(table$selected_outcome_high) &
    is.finite(table$impact_range)
  plot_data <- table[valid, , drop = FALSE]
  plot_data <- plot_data[order(plot_data$impact_range, decreasing = TRUE), , drop = FALSE]
  plot_data$parameter <- factor(plot_data$parameter, levels = rev(plot_data$parameter))
  plot_data$base_outcome <- result$base_outcome
  plot_data$low_hover <- vapply(seq_len(nrow(plot_data)), function(i) {
    row <- plot_data[i, ]
    paste0(
      "<b>", row$parameter, " - low input</b><br>",
      "Base: ", signif(row$base_value, 5), "<br>",
      "Low: ", signif(row$low_value, 5), "<br>",
      "High: ", signif(row$high_value, 5), "<br>",
      "Low ICER: ", eqalb_owsa_format_icer(
        row$low_icer, row$low_incremental_cost, row$low_incremental_qalys
      ), "<br>",
      "High ICER: ", eqalb_owsa_format_icer(
        row$high_icer, row$high_incremental_cost, row$high_incremental_qalys
      ), "<br>",
      "Low INMB: ", format(round(row$low_inmb, 2), big.mark = ","), "<br>",
      "High INMB: ", format(round(row$high_inmb, 2), big.mark = ","), "<br>",
      "Low cost-effective: ", row$low_cost_effective, "<br>",
      "High cost-effective: ", row$high_cost_effective
    )
  }, character(1))
  plot_data$high_hover <- sub("low input", "high input", plot_data$low_hover, fixed = TRUE)
  plot_data
}

# Plotting: interactive Plotly tornado; downloadable static image uses the same
# ranked low/high results and base reference line.
eqalb_owsa_plotly <- function(result) {
  plot_data <- eqalb_owsa_tornado_data(result)
  if (nrow(plot_data) == 0L) return(NULL)

  plotly::plot_ly() |>
    plotly::add_segments(
      data = plot_data,
      x = ~base_outcome, xend = ~selected_outcome_low,
      y = ~parameter, yend = ~parameter,
      text = ~low_hover, hoverinfo = "text",
      line = list(color = "#2F6DB0", width = 8), name = "Low parameter value"
    ) |>
    plotly::add_segments(
      data = plot_data,
      x = ~base_outcome, xend = ~selected_outcome_high,
      y = ~parameter, yend = ~parameter,
      text = ~high_hover, hoverinfo = "text",
      line = list(color = "#E68613", width = 8), name = "High parameter value"
    ) |>
    plotly::add_markers(
      data = plot_data,
      x = ~selected_outcome_low, y = ~parameter,
      text = ~low_hover, hoverinfo = "text",
      marker = list(color = "#2F6DB0", size = 9), name = "Low value"
    ) |>
    plotly::add_markers(
      data = plot_data,
      x = ~selected_outcome_high, y = ~parameter,
      text = ~high_hover, hoverinfo = "text",
      marker = list(color = "#E68613", size = 9), name = "High value"
    ) |>
    plotly::layout(
      title = paste0(
        "eQalb OWSA: ", result$outcome_label,
        " (WTP €", eqalb_owsa_format_wtp(result$wtp), "/QALY)"
      ),
      xaxis = list(title = result$outcome_label, zeroline = TRUE),
      yaxis = list(
        title = "Parameter",
        categoryorder = "array",
        categoryarray = as.character(plot_data$parameter)
      ),
      shapes = list(list(
        type = "line", xref = "x", yref = "paper",
        x0 = result$base_outcome, x1 = result$base_outcome, y0 = 0, y1 = 1,
        line = list(color = "black", dash = "dash", width = 2)
      )),
      annotations = list(list(
        x = result$base_outcome, xref = "x", y = 1, yref = "paper",
        text = "Base case", showarrow = FALSE, yanchor = "bottom"
      )),
      margin = list(l = 200, r = 30, b = 70, t = 90),
      legend = list(orientation = "h", x = 0, y = -0.18),
      hovermode = "closest"
    )
}

# nolint start: object_usage_linter
eqalb_owsa_ggplot <- function(result) {
  plot_data <- eqalb_owsa_tornado_data(result)
  if (nrow(plot_data) == 0L) return(NULL)
  long_data <- rbind(
    data.frame(parameter = plot_data$parameter,
               value = plot_data$selected_outcome_low, bound = "Low parameter value"),
    data.frame(parameter = plot_data$parameter,
               value = plot_data$selected_outcome_high, bound = "High parameter value")
  )
  long_data$base_outcome <- result$base_outcome

  ggplot2::ggplot(long_data, ggplot2::aes(y = parameter)) +
    ggplot2::geom_vline(xintercept = result$base_outcome, linetype = "dashed") +
    ggplot2::geom_segment(
      ggplot2::aes(x = base_outcome, xend = value, yend = parameter, colour = bound),
      linewidth = 4, lineend = "round", position = ggplot2::position_dodge(width = 0.5)
    ) +
    ggplot2::geom_point(
      ggplot2::aes(x = value, colour = bound), size = 2.5,
      position = ggplot2::position_dodge(width = 0.5)
    ) +
    ggplot2::scale_colour_manual(values = c(
      "Low parameter value" = "#2F6DB0", "High parameter value" = "#E68613"
    )) +
    ggplot2::labs(
      title = paste0(
        "eQalb OWSA: ", result$outcome_label,
        " (WTP €", eqalb_owsa_format_wtp(result$wtp), "/QALY)"
      ),
      subtitle = "Base case shown as a dashed black reference line",
      x = result$outcome_label, y = NULL, colour = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
}
  # nolint end: object_usage_linter