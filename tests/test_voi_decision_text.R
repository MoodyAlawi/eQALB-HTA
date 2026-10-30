#!/usr/bin/env Rscript
# Synthetic tests for the decision sentence in the decision-uncertainty
# interpretation (voi_uncertainty_status() and voi_decision_text()).
#
# The sentence used to name the option with the higher mean net monetary
# benefit and then describe how often "the other" option won, using
# min(p, 1 - p). The mean and the share of simulations can disagree, so it could
# say the mean-preferred option won "in most simulations" when it did not. The
# sentence now reports the two measures separately. These checks pin that, and
# that the traffic-light status, its label and the returned fields did not move.
#
# Every case calls the functions with hand-written values. Nothing is simulated,
# no model is run and no service is contacted:
#
#   Rscript tests/test_voi_decision_text.R
#
# The script exits non-zero if any check fails.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg) > 0L) {
  sub("^--file=", "", file_arg[1])
} else {
  file.path("tests", "test_voi_decision_text.R")
}
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
setwd(root)

suppressWarnings(suppressMessages(source("eqalb_markov.R")))

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

assess <- function(p, mean_nmb, evpi = 50) {
  voi_uncertainty_status(
    probability_cost_effective = p,
    evpi = evpi,
    mean_nmb = mean_nmb
  )
}

DISAGREE <- "point in different directions"

cat("\n1. The average and the majority agree\n")
agree <- assess(p = 0.8, mean_nmb = 500)
check("names eQalb as higher on average",
      contains(agree$interpretation, "On average, eQalb has the higher net monetary benefit"),
      agree$interpretation)
check("reports the eQalb share and the usual-care share",
      contains(agree$interpretation, "in most simulations (80%)") &&
        contains(agree$interpretation, "the other 20%"),
      agree$interpretation)
check("adds no disagreement sentence", !contains(agree$interpretation, DISAGREE))

cat("\n2. Higher average for eQalb, but usual care wins most simulations\n")
eqalb_mean <- assess(p = 0.3, mean_nmb = 500)
check("names eQalb as higher on average",
      contains(eqalb_mean$interpretation, "On average, eQalb has the higher"),
      eqalb_mean$interpretation)
check("says usual care is as good or better in most simulations (70%)",
      contains(eqalb_mean$interpretation,
               "Usual care is as good or better in most simulations (70%)"),
      eqalb_mean$interpretation)
check("never says eQalb wins most simulations",
      !contains(eqalb_mean$interpretation, "eQalb has a positive net monetary benefit in most"),
      eqalb_mean$interpretation)
check("explains that the two measures disagree",
      contains(eqalb_mean$interpretation, DISAGREE))

cat("\n3. Higher average for usual care, but eQalb wins most simulations\n")
usual_mean <- assess(p = 0.7, mean_nmb = -500)
check("names usual care as higher on average",
      contains(usual_mean$interpretation, "On average, usual care has the higher"),
      usual_mean$interpretation)
check("says eQalb has a positive net benefit in most simulations (70%)",
      contains(usual_mean$interpretation,
               "eQalb has a positive net monetary benefit in most simulations (70%)"),
      usual_mean$interpretation)
check("explains that the two measures disagree",
      contains(usual_mean$interpretation, DISAGREE))

cat("\n4. An even 50/50 split\n")
split <- assess(p = 0.5, mean_nmb = 200)
check("says the simulations are split evenly",
      contains(split$interpretation, "split evenly") &&
        contains(split$interpretation, "exactly half of them (50%)"),
      split$interpretation)
check("does not say 'most' at exactly 50%", !contains(split$interpretation, "most"))
check("adds no disagreement sentence at 50%", !contains(split$interpretation, DISAGREE))

cat("\n5. Missing and near-zero inputs\n")
no_probability <- assess(p = NA_real_, mean_nmb = 500)
check("missing probability: says the shares could not be estimated",
      contains(no_probability$interpretation, "could not be estimated") &&
        contains(no_probability$interpretation, "On average, eQalb has the higher"),
      no_probability$interpretation)
no_mean <- assess(p = 0.3, mean_nmb = NA_real_)
check("missing mean: says the average could not be estimated, not that it is zero",
      contains(no_mean$interpretation, "The average net monetary benefit could not be estimated") &&
        !contains(no_mean$interpretation, "approximately zero"),
      no_mean$interpretation)
check("missing mean: still reports the shares",
      contains(no_mean$interpretation, "in most simulations (70%)"),
      no_mean$interpretation)
zero_mean <- assess(p = 0.55, mean_nmb = 0)
check("near-zero mean: says neither option is better on average",
      contains(zero_mean$interpretation, "neither option is better"),
      zero_mean$interpretation)
check("near-zero mean: adds no disagreement sentence",
      !contains(zero_mean$interpretation, DISAGREE))
both_missing <- assess(p = NA_real_, mean_nmb = NA_real_, evpi = NA_real_)
check("both missing: still returns a sentence",
      is.character(both_missing$interpretation) && nzchar(both_missing$interpretation))

cat("\n6. Edges of the percentage wording\n")
check("every simulation", contains(assess(1, 500)$interpretation, "in every simulation"))
check("no simulation", contains(assess(0, -500)$interpretation, "in any simulation"))
near_all <- assess(0.9996, 500)
check("never rounds a minority to 0% or a majority to 100%",
      contains(near_all$interpretation, "more than 99.9%") &&
        contains(near_all$interpretation, "less than 0.1%"),
      near_all$interpretation)
check("one decimal place where needed",
      contains(assess(0.434, -75)$interpretation, "(56.6%)") &&
        contains(assess(0.434, -75)$interpretation, "the other 43.4%"),
      assess(0.434, -75)$interpretation)

cat("\n7. Status, label and returned fields are unchanged\n")
check("returned fields are the same set",
      identical(names(agree),
                c("status", "label", "magnitude", "p_loser", "preferred",
                  "interpretation", "what_this_means", "thresholds")),
      names(agree))
# The documented rule, written out independently of the implementation.
expected_status <- function(p, evpi) {
  magnitude <- voi_evpi_magnitude(evpi)
  if (is.na(p)) {
    return(if (magnitude == "material") "Red" else if (magnitude == "negligible") "Green" else "Amber")
  }
  loser <- min(p, 1 - p)
  if (loser >= 0.40 || magnitude == "material") "Red"
  else if (loser >= 0.01 || magnitude != "negligible") "Amber"
  else "Green"
}
grid <- expand.grid(
  p = c(NA, 0, 0.005, 0.01, 0.3, 0.5, 0.6, 0.995, 1),
  mean_nmb = c(NA, -500, 0, 500),
  evpi = c(NA, 0.5, 50, 5000)
)
mismatches <- 0L
for (i in seq_len(nrow(grid))) {
  row <- grid[i, ]
  result <- assess(row$p, row$mean_nmb, row$evpi)
  want_preferred <- if (is.na(row$mean_nmb) || abs(row$mean_nmb) <= 1e-6) NA_character_
                    else if (row$mean_nmb > 0) "eQalb" else "usual care"
  ok <- identical(result$status, expected_status(row$p, row$evpi)) &&
    identical(result$preferred, want_preferred) &&
    identical(result$p_loser, if (is.na(row$p)) NA_real_ else min(row$p, 1 - row$p))
  if (!ok) mismatches <- mismatches + 1L
}
check(sprintf("status, preferred and p_loser follow the rule across %d cases", nrow(grid)),
      mismatches == 0L, paste(mismatches, "mismatches"))

cat("\n8. The HTA decision summary carries the new sentence\n")
summary <- assess_hta_decision_summary(
  icer = NA_real_, reference_wtp = 1e5, probability_cost_effective = 0.3,
  mean_incremental_nmb = 500, evpi = 50, highest_evppi = NA_real_,
  cumulative_budget_impact = NA_real_, readiness_domains = NULL
)
row <- summary$domains[summary$domains$Domain == "Decision uncertainty", ]
check("the decision-uncertainty row uses the corrected wording",
      contains(row$Interpretation, "Usual care is as good or better in most simulations (70%)") &&
        contains(row$Interpretation, DISAGREE),
      row$Interpretation)

cat(sprintf("\n%d checks, %d failed\n", checks, failures))
if (failures > 0L) {
  cat("FAILED\n")
  quit(status = 1L)
}
cat("PASSED\n")
quit(status = 0L)
