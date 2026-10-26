#!/usr/bin/env Rscript
# Synthetic tests for the HTA decision-summary rule.
#
# Every case calls assess_hta_decision_summary() with hand-written incremental
# costs and health differences. Nothing is simulated, no model is run and no
# service is contacted, so the whole file finishes in a fraction of a second:
#
#   Rscript tests/test_hta_summary_rule.R
#
# The rule used to compare the base-case ICER with the threshold. That test is
# not sign-safe: a negative ICER is "below" any positive threshold, so an option
# that cost more and provided less health could be marked Green. The cases below
# pin the replacement, which compares the incremental net monetary benefit
# (INMB = lambda * incremental health - incremental cost) and never reads the
# ICER for a verdict.
#
# The script exits non-zero if any check fails, so it can gate a change.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg) > 0L) {
  sub("^--file=", "", file_arg[1])
} else {
  file.path("tests", "test_hta_summary_rule.R")
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

# The economic row of a summary built from the given differences. `icer` is
# derived the way the model derives it (undefined when there is no incremental
# health) unless a case supplies its own, which is how the "the ICER is not read
# for a verdict" checks are written.
economic_row <- function(incremental_cost,
                         incremental_qalys,
                         p_ce = 0.9,
                         icer = NULL,
                         mean_nmb = NA_real_,
                         reference_wtp = WTP) {
  if (is.null(icer)) {
    icer <- if (is.na(incremental_qalys) || incremental_qalys == 0) {
      NA_real_
    } else {
      incremental_cost / incremental_qalys
    }
  }
  summary <- assess_hta_decision_summary(
    icer = icer,
    reference_wtp = reference_wtp,
    probability_cost_effective = p_ce,
    mean_incremental_nmb = mean_nmb,
    evpi = NA_real_,
    highest_evppi = NA_real_,
    cumulative_budget_impact = NA_real_,
    readiness_domains = NULL,
    incremental_cost = incremental_cost,
    incremental_qalys = incremental_qalys
  )
  row <- summary$domains[summary$domains$Domain == "Economic value", ]
  list(
    status = row$Status,
    measure = row$Measure,
    basis = row$Basis,
    interpretation = row$Interpretation,
    summary = summary
  )
}

contains <- function(haystack, needle) grepl(needle, haystack, fixed = TRUE)

cat("\n1. More costly and less effective (dominated)\n")
dominated <- economic_row(5000, -0.10, p_ce = 0.9)
check(
  "dominated with a 90% cost-effectiveness probability is Amber, not Green",
  identical(dominated$status, "Amber"),
  dominated$status
)
check(
  "the interpretation does not claim it is cost-effective",
  !contains(dominated$interpretation, "cost-effective in the majority"),
  dominated$interpretation
)
check(
  "the interpretation says it costs more and provides less health",
  contains(dominated$interpretation, "costs more and provides less health"),
  dominated$interpretation
)
check(
  "the negative ICER is not printed as a comparable number",
  !contains(dominated$measure, "ICER \u20ac"),
  dominated$measure
)
check(
  "a negative health difference is described as less health, not no health",
  contains(dominated$measure, "provides less health than usual care"),
  dominated$measure
)
check(
  "dominated with a 0% probability is Red",
  identical(economic_row(5000, -0.10, p_ce = 0)$status, "Red")
)

cat("\n2. Less costly and more effective (dominant)\n")
dominant <- economic_row(-5000, 0.10, p_ce = 0.9)
check(
  "dominant is Green",
  identical(dominant$status, "Green"),
  dominant$status
)
check(
  "the interpretation says it costs less and provides more health",
  contains(dominant$interpretation, "costs less and provides more health"),
  dominant$interpretation
)
check(
  "a dominant option is described as dominant, not as a negative ICER",
  contains(dominant$measure, "less costly and more effective, so no ICER is needed") &&
    !contains(dominant$measure, "ICER \u20ac"),
  dominant$measure
)
check(
  "dominant stays Green even with an absurd ICER supplied",
  identical(economic_row(-5000, 0.10, p_ce = 0.9, icer = 1e12)$status, "Green")
)

cat("\n3. Positive incremental health above and below the threshold\n")
above <- economic_row(50000, 0.10, p_ce = 0.02)
check("above the threshold (ICER 500,000) is Red at 2%", identical(above$status, "Red"), above$status)
check(
  "above the threshold reports the ICER as the ratio it is",
  contains(above$measure, "ICER \u20ac500,000.00/QALY"),
  above$measure
)
check(
  "above the threshold with a 60% probability is Amber, not Green",
  identical(economic_row(50000, 0.10, p_ce = 0.6)$status, "Amber")
)
below <- economic_row(5000, 0.10, p_ce = 0.9)
check("below the threshold (ICER 50,000) is Green at 90%", identical(below$status, "Green"), below$status)
check(
  "below the threshold with a 2% probability is Amber, not Red",
  identical(economic_row(5000, 0.10, p_ce = 0.02)$status, "Amber")
)

cat("\n4. Zero incremental health\n")
equal_health_extra <- economic_row(2000, 0, p_ce = 0)
check(
  "no incremental health at a higher cost is Red at 0%",
  identical(equal_health_extra$status, "Red"),
  equal_health_extra$status
)
check(
  "no incremental health means no ICER is printed",
  contains(equal_health_extra$measure, "no incremental health at a higher cost") &&
    contains(equal_health_extra$measure, "so no ICER"),
  equal_health_extra$measure
)
check(
  "the interpretation reports the same health at a higher cost",
  contains(equal_health_extra$interpretation, "same health at a higher cost"),
  equal_health_extra$interpretation
)
equal_health_cheaper <- economic_row(-2000, 0, p_ce = 0.9)
check(
  "no incremental health at a lower cost is Green at 90%",
  identical(equal_health_cheaper$status, "Green"),
  equal_health_cheaper$status
)
check(
  "the interpretation reports the same health at a lower cost",
  contains(equal_health_cheaper$interpretation, "same health at a lower cost"),
  equal_health_cheaper$interpretation
)

cat("\n5. Less health with cost savings\n")
compensated <- economic_row(-50000, -0.10, p_ce = 0.9)
check(
  "savings that exceed the value of the lost health are Green at 90%",
  identical(compensated$status, "Green"),
  compensated$status
)
check(
  "the interpretation names the trade-off",
  contains(compensated$interpretation, "less health at a lower cost"),
  compensated$interpretation
)
check(
  "the negative ICER is not printed for this quadrant either",
  !contains(compensated$measure, "ICER \u20ac"),
  compensated$measure
)
uncompensated <- economic_row(-5000, -0.10, p_ce = 0.01)
check(
  "savings that do not cover the lost health are Red at 1%",
  identical(uncompensated$status, "Red"),
  uncompensated$status
)
check(
  "the same negative-ish ICER sign does not make the two cases agree",
  !identical(compensated$status, uncompensated$status)
)

cat("\n6. Exact net-benefit equality\n")
equal <- economic_row(10000, 0.10, p_ce = 0.99)
check(
  "INMB exactly zero is Amber even at a 99% probability",
  identical(equal$status, "Amber"),
  equal$status
)
check(
  "the interpretation says the net benefit is equal",
  contains(equal$interpretation, "equal net monetary benefit"),
  equal$interpretation
)
check(
  "the measure reports zero net benefit",
  contains(equal$measure, "incremental NMB \u20ac0.00"),
  equal$measure
)

cat("\n7. The ICER never decides on its own\n")
# icer = 1 is "below" every threshold; the differences say dominated.
check(
  "a favourable-looking ICER cannot make a dominated option Green",
  identical(economic_row(5000, -0.10, p_ce = 0.9, icer = 1)$status, "Amber")
)
# icer = 1e12 is "above" every threshold; the differences say dominant.
check(
  "an unfavourable-looking ICER cannot make a dominant option Red",
  identical(economic_row(-5000, 0.10, p_ce = 0.01, icer = 1e12)$status, "Amber")
)

cat("\n8. Fallbacks when the base case differences are missing\n")
psa_mean <- economic_row(NA_real_, NA_real_, p_ce = 0.01, mean_nmb = -100)
check(
  "the PSA mean NMB decides when the differences are absent",
  identical(psa_mean$status, "Red"),
  psa_mean$status
)
check(
  "the measure says the comparison is the PSA mean",
  contains(psa_mean$measure, "PSA mean incremental NMB"),
  psa_mean$measure
)
nothing <- economic_row(NA_real_, NA_real_, p_ce = NA_real_)
check(
  "no threshold comparison at all is Not available",
  identical(nothing$status, "Not available"),
  nothing$status
)
check(
  "no reference threshold is Not available",
  identical(economic_row(5000, 0.10, p_ce = 0.9, reference_wtp = NA_real_)$status, "Not available")
)

cat("\n9. The other domains are unchanged\n")
domains <- assess_hta_decision_summary(
  icer = 50000,
  reference_wtp = WTP,
  probability_cost_effective = 0.9,
  mean_incremental_nmb = 5000,
  evpi = 50,
  highest_evppi = 20,
  cumulative_budget_impact = 5e6,
  readiness_domains = data.frame(
    Domain = c("Access", "Workflow", "Governance", "Interoperability"),
    Status = c("Green", "Green", "Amber", "Green"),
    stringsAsFactors = FALSE
  ),
  incremental_cost = 5000,
  incremental_qalys = 0.10
)
status_of <- function(domain) {
  domains$domains$Status[domains$domains$Domain == domain]
}
check("economic value is Green", identical(status_of("Economic value"), "Green"), status_of("Economic value"))
check(
  "budget impact keeps its EUR 1m / EUR 10m bands",
  identical(status_of("Budget impact"), "Amber"),
  status_of("Budget impact")
)
check(
  "clinical evidence maturity is always Red",
  identical(status_of("Clinical evidence maturity"), "Red")
)
check(
  "implementation readiness keeps its amber/quarter-of-domains rule",
  identical(status_of("Implementation readiness"), "Amber"),
  status_of("Implementation readiness")
)
check(
  "an all-Green-favourable case is still an illustrative position",
  identical(domains$position, "Potentially favourable"),
  domains$position
)
check(
  "the interpretation still carries the simulated-data qualifier",
  contains(domains$interpretation, "Simulated illustrative analysis"),
  domains$interpretation
)

cat("\n10. The published rule matches the implemented rule\n")
check(
  "the popover rule names the net monetary benefit",
  contains(HTA_RULE_ITEMS[[1]], "net monetary benefit")
)
check(
  "the popover rule no longer describes an ICER-threshold test",
  !contains(HTA_RULE_ITEMS[[1]], "ICER is at or below")
)
check(
  "the popover rule warns that a negative ICER does not decide",
  contains(HTA_RULE_ITEMS[[1]], "negative ICER never decides")
)
check(
  "the exported note names the net monetary benefit",
  contains(HTA_SUMMARY_RULE_NOTE, "net monetary benefit")
)
check(
  "the exported note no longer describes an ICER-threshold test",
  !contains(HTA_SUMMARY_RULE_NOTE, "ICER is at or below")
)
check(
  "the exported note still states the same three status bands",
  contains(HTA_SUMMARY_RULE_NOTE, "at least 50%") &&
    contains(HTA_SUMMARY_RULE_NOTE, "below 5%")
)
check(
  "every rule item is a non-empty paragraph",
  length(HTA_RULE_ITEMS) >= 6L && all(nzchar(HTA_RULE_ITEMS))
)

cat(sprintf("\n%d checks, %d failed\n", checks, failures))
if (failures > 0L) {
  cat("FAILED\n")
  quit(status = 1L)
}
cat("PASSED\n")
quit(status = 0L)
