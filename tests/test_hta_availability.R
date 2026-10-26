#!/usr/bin/env Rscript
# Regression tests for the HTA summary's availability gate.
#
# The economic verdict is the sign of the incremental net monetary benefit, which
# the endpoint computes from the base case's `incremental_cost` and
# `incremental_qalys`. The availability block used to treat a present ICER as the
# proxy for "the base case was supplied", which misreported exactly the cases the
# new rule exists to handle:
#
#   * an option with no incremental health has no ICER by construction, so a
#     perfectly good Amber verdict arrived beside "Base case: not included" and
#     listed `icer` among the values that were not supplied;
#   * a request that sent only an ICER claimed the base case was included although
#     the rule could not reach a verdict from a ratio alone.
#
# These cases run through the real handler: this script evaluates the
# `POST /api/hta-summary` route function out of api/plumber.R and calls it with a
# synthetic request body, so the gate, the response shape and the rule are all the
# code the service runs. No model is executed, no worker is started and no HTTP
# request is made.
#
#   Rscript tests/test_hta_availability.R
#
# The script exits non-zero if any check fails.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg) > 0L) {
  sub("^--file=", "", file_arg[1])
} else {
  file.path("tests", "test_hta_availability.R")
}
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
setwd(root)

options(eqalb.api.root = root)

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

# --- Load the endpoint the way the worker does -------------------------------

endpoint_path <- "api/plumber.R"
lines <- readLines(endpoint_path, warn = FALSE)
exprs <- parse(endpoint_path, keep.source = TRUE)
srcref <- attr(exprs, "srcref")
starts <- vapply(srcref, function(ref) as.integer(ref[1]), integer(1))
is_function <- vapply(
  exprs, function(x) is.call(x) && identical(x[[1]], as.name("function")), logical(1)
)
annotation <- grep("@post /api/hta-summary", lines)[1]
handler_index <- which(is_function & starts > annotation)[1]

# Every non-handler top-level expression is a definition or a constant; evaluating
# them populates the environment the handler closes over. The other routes are not
# needed, so their bodies are skipped.
env <- new.env(parent = globalenv())
env$API_ROOT <- root
for (index in seq_along(exprs)) {
  if (index == handler_index || is_function[index]) next
  eval(exprs[[index]], envir = env)
}
suppressWarnings(suppressMessages(env$load_model_modules(root)))
handler <- eval(exprs[[handler_index]], envir = env)

call_endpoint <- function(body) {
  handler(list(
    postBody = jsonlite::toJSON(body, auto_unbox = TRUE, null = "null"),
    argsQuery = list(),
    REQUEST_METHOD = "POST"
  ))
}

# The economic row and the availability block of one response, in the shapes the
# frontend reads: `missing_inputs` and `not_assessable_domains` are character
# vectors, exactly as the JSON serialiser writes them.
result <- function(body) {
  response <- call_endpoint(body)
  economic <- response$summary$domains[
    response$summary$domains$Domain == "Economic value", ,
    drop = FALSE
  ]
  list(
    status = economic$Status,
    measure = economic$Measure,
    base_case = isTRUE(response$availability$base_case),
    missing = as.character(unlist(response$availability$missing_inputs)),
    not_assessable = as.character(unlist(
      response$availability$not_assessable_domains
    )),
    assessed = response$availability$assessed_domains
  )
}

# Everything except the base case, so the base-case fields are the only ones the
# gate can report and the assertions stay about this change.
rest <- list(wtp = 100000, probability_cost_effective = 0.9, evpi = 50)

cat("\n1. The rule's verdict is produced without any ICER\n")

positive <- result(c(rest, list(incremental_cost = 5000, incremental_qalys = 0.10)))
check("positive health with no ICER is Green", identical(positive$status, "Green"), positive$status)
check("the base case counts as supplied", isTRUE(positive$base_case))
check("the ICER is not reported as missing", !("icer" %in% positive$missing), positive$missing)
check(
  "no base-case field is reported as missing",
  !any(c("icer", "incremental_cost", "incremental_qalys") %in% positive$missing),
  positive$missing
)

zero <- result(c(rest, list(incremental_cost = 5000, incremental_qalys = 0)))
check("zero health is Amber at a 90% probability", identical(zero$status, "Amber"), zero$status)
check(
  "zero health still counts as a supplied base case",
  isTRUE(zero$base_case)
)
check(
  "zero health does not report the ICER as missing",
  !("icer" %in% zero$missing),
  zero$missing
)
check(
  "the measure explains that no ICER exists rather than printing one",
  grepl("no incremental health", zero$measure, fixed = TRUE),
  zero$measure
)

negative <- result(c(rest, list(incremental_cost = 5000, incremental_qalys = -0.10)))
check("negative health at 90% is Amber", identical(negative$status, "Amber"), negative$status)
check("negative health counts as a supplied base case", isTRUE(negative$base_case))
check(
  "negative health does not report the ICER as missing",
  !("icer" %in% negative$missing),
  negative$missing
)
check(
  "the measure refuses to print the negative ratio",
  !grepl("ICER \u20ac", negative$measure, fixed = TRUE),
  negative$measure
)

dominated <- result(c(
  list(wtp = 100000, probability_cost_effective = 0, evpi = 50),
  list(incremental_cost = 5000, incremental_qalys = -0.10)
))
check(
  "a dominated option with no ICER is Red, not Green",
  identical(dominated$status, "Red"),
  dominated$status
)
check(
  "the economic domain is assessed in every one of these cases",
  all(c(positive$assessed, zero$assessed, negative$assessed, dominated$assessed) >= 3L)
)
check(
  "the economic domain is never listed as not assessable here",
  !any(vapply(
    list(positive, zero, negative, dominated),
    function(entry) "Economic value" %in% entry$not_assessable,
    logical(1)
  ))
)

cat("\n2. An explicitly null ICER is treated the same as an absent one\n")
null_icer <- result(c(
  rest,
  list(icer = NA, incremental_cost = 5000, incremental_qalys = 0)
))
check("a null ICER is not a missing input", !("icer" %in% null_icer$missing), null_icer$missing)
check("a null ICER still counts as a supplied base case", isTRUE(null_icer$base_case))
check("a null ICER does not change the verdict", identical(null_icer$status, "Amber"), null_icer$status)

cat("\n3. A present ICER keeps working, and is still not required\n")
with_icer <- result(c(
  rest,
  list(icer = 50000, incremental_cost = 5000, incremental_qalys = 0.10)
))
check("a supplied ICER is still reported in the measure", grepl("ICER", with_icer$measure, fixed = TRUE), with_icer$measure)
check("a supplied ICER is Green", identical(with_icer$status, "Green"), with_icer$status)
check("a supplied ICER adds no base-case field to the missing list", !any(c("icer", "incremental_cost", "incremental_qalys") %in% with_icer$missing), with_icer$missing)

cat("\n4. The base case genuinely absent is reported by what it needs\n")
nothing <- result(rest)
check(
  "no base-case result at all is Not available",
  identical(nothing$status, "Not available"),
  nothing$status
)
check("the base case is reported as not supplied", !isTRUE(nothing$base_case))
check(
  "the missing fields name the two differences, not the ICER",
  all(c("incremental_cost", "incremental_qalys") %in% nothing$missing) &&
    !("icer" %in% nothing$missing),
  nothing$missing
)

half <- result(c(rest, list(incremental_cost = 5000)))
check(
  "with only the cost supplied, the missing base-case field is the health difference",
  identical(
    intersect(half$missing, c("icer", "incremental_cost", "incremental_qalys")),
    "incremental_qalys"
  ),
  half$missing
)

cat("\n5. A legacy ICER-only request: included, but honest about the verdict\n")
legacy <- result(c(rest, list(icer = 50000)))
check(
  "an ICER-only request still counts as a supplied base case",
  isTRUE(legacy$base_case)
)
check(
  "its verdict is Not available, because a ratio cannot decide the rule",
  identical(legacy$status, "Not available"),
  legacy$status
)
check(
  "the response asks for the two differences it needs",
  all(c("incremental_cost", "incremental_qalys") %in% legacy$missing),
  legacy$missing
)

cat("\n6. The other availability flags are untouched\n")
full <- call_endpoint(c(
  list(
    wtp = 100000,
    probability_cost_effective = 0.9,
    evpi = 50,
    cumulative_budget_impact = 5e6,
    readiness = list()
  ),
  list(incremental_cost = 5000, incremental_qalys = 0.10)
))$availability
check("psa is reported present when its two values arrive", isTRUE(full$psa))
check("value of information follows the EVPI", isTRUE(full$value_of_information))
check("budget impact is reported present when its total arrives", isTRUE(full$budget_impact))
check("readiness follows the supplied block", isTRUE(full$readiness))
check("nothing is missing in a fully supplied request", length(as.character(unlist(full$missing_inputs))) == 0L, full$missing_inputs)

cat(sprintf("\n%d checks, %d failed\n", checks, failures))
if (failures > 0L) {
  cat("FAILED\n")
  quit(status = 1L)
}
cat("PASSED\n")
quit(status = 0L)
