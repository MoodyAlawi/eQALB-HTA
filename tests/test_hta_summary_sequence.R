#!/usr/bin/env Rscript
# Synthetic tests for what the HTA decision summary needs before it can state a
# position, and for the wording that tells the reader what to run next.
#
# The "Not yet assessable" message used to ask for the base case, the PSA and
# the budget impact. A position actually needs the PSA's probability of
# cost-effectiveness and the EVPI from the value-of-information analysis; the
# base case, the budget impact and readiness add their own rows but are not
# required. These checks pin that sequence against the rule itself, so the
# message cannot drift from what the rule needs.
#
# Every case calls assess_hta_decision_summary() with hand-written values. Nothing
# is simulated, no model is run and no service is contacted:
#
#   Rscript tests/test_hta_summary_sequence.R
#
# The script exits non-zero if any check fails.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg) > 0L) {
  sub("^--file=", "", file_arg[1])
} else {
  file.path("tests", "test_hta_summary_sequence.R")
}
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
setwd(root)

suppressWarnings(suppressMessages({
  source("eqalb_markov.R")
  source("eqalb_ui_copy.R")
}))

WTP <- 100000

checks <- 0L
failures <- 0L

check <- function(label, ok, detail = NULL) {
  checks <<- checks + 1L
  if (isTRUE(ok)) {
    cat(sprintf("  ok    %s\n", label))
  } else {
    failures <<- failures + 1L
    cat(sprintf(
      "  FAIL  %s%s\n",
      label,
      if (is.null(detail)) "" else paste0(" -> ", paste(detail, collapse = " | "))
    ))
  }
}

contains <- function(haystack, needle) grepl(needle, haystack, fixed = TRUE)

# A summary from the given completed-analysis values. Anything not supplied is
# absent, exactly as the endpoint passes an analysis that has not been run.
summary_with <- function(p_ce = NA_real_, mean_nmb = NA_real_, evpi = NA_real_,
                         incremental_cost = NA_real_,
                         incremental_qalys = NA_real_,
                         budget = NA_real_) {
  assess_hta_decision_summary(
    icer = NA_real_,
    reference_wtp = WTP,
    probability_cost_effective = p_ce,
    mean_incremental_nmb = mean_nmb,
    evpi = evpi,
    highest_evppi = NA_real_,
    cumulative_budget_impact = budget,
    readiness_domains = NULL,
    incremental_cost = incremental_cost,
    incremental_qalys = incremental_qalys
  )
}

uncertainty_row <- function(summary) {
  summary$domains[summary$domains$Domain == "Decision uncertainty", ]
}

cat("\n1. Nothing run yet\n")
empty <- summary_with()
check("position is not yet assessable", identical(empty$position, "Not yet assessable"))
check(
  "the message asks for the PSA and then the value of information",
  contains(empty$interpretation, "run the PSA, then the value-of-information analysis"),
  empty$interpretation
)
check(
  "the message no longer asks for the budget impact",
  !contains(empty$interpretation, "budget"),
  empty$interpretation
)
check(
  "the simulated-data caveat is kept",
  contains(empty$interpretation, "Simulated illustrative analysis") &&
    contains(empty$interpretation, "not clinical evidence"),
  empty$interpretation
)

cat("\n2. PSA run, value of information not yet run\n")
psa_only <- summary_with(p_ce = 0.434, mean_nmb = -75)
check(
  "a PSA alone is not enough for a position",
  identical(psa_only$position, "Not yet assessable"),
  psa_only$position
)
check(
  "the uncertainty row names the value-of-information step",
  contains(
    uncertainty_row(psa_only)$Interpretation,
    "run the PSA, then the value-of-information analysis"
  ),
  uncertainty_row(psa_only)$Interpretation
)

cat("\n3. PSA and value of information, no base case and no budget impact\n")
psa_voi <- summary_with(p_ce = 0.434, mean_nmb = -75, evpi = 254.71)
check(
  "the PSA and the value of information are enough for a position",
  !identical(psa_voi$position, "Not yet assessable"),
  psa_voi$position
)
check(
  "the budget-impact row still reports it was not run",
  identical(
    psa_voi$domains$Status[psa_voi$domains$Domain == "Budget impact"],
    "Not available"
  )
)

cat("\n4. Budget impact wording follows the selected horizon\n")
with_budget <- summary_with(p_ce = 0.434, mean_nmb = -75, evpi = 254.71,
                            budget = 5e5)
budget_row <- with_budget$domains[with_budget$domains$Domain == "Budget impact", ]
check(
  "the budget measure does not assume five years",
  !contains(tolower(budget_row$Measure), "five-year") &&
    contains(budget_row$Measure, "over the selected horizon"),
  budget_row$Measure
)

cat(sprintf("\n%d checks, %d failed\n", checks, failures))
if (failures > 0L) {
  cat("FAILED\n")
  quit(status = 1L)
}
cat("PASSED\n")
quit(status = 0L)
