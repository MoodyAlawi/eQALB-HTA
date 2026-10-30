#!/usr/bin/env Rscript
# Synthetic checks for the parameter metadata the model API publishes to the
# assumptions panel (`parameter_specs()` in api/plumber.R, served by
# GET /api/defaults).
#
# The annual price was labelled "EUR per active user per year", but the
# cost-effectiveness model charges it for every treated person alive and only
# the budget impact charges active users. The unit is now "EUR per year" and the
# help text states both conventions. These checks pin that wording and that
# nothing else about the price's metadata moved: its default, range, step and
# the other inputs' units are unchanged.
#
# The API's definitions are evaluated the way the worker loads them, but no
# route handler is called, no model is run and no service is contacted:
#
#   Rscript tests/test_parameter_copy.R
#
# The script exits non-zero if any check fails.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg) > 0L) {
  sub("^--file=", "", file_arg[1])
} else {
  file.path("tests", "test_parameter_copy.R")
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

# --- Load the API's definitions, skipping every route handler -----------------

endpoint_path <- "api/plumber.R"
exprs <- parse(endpoint_path, keep.source = TRUE)
is_function <- vapply(
  exprs, function(x) is.call(x) && identical(x[[1]], as.name("function")), logical(1)
)
env <- new.env(parent = globalenv())
env$API_ROOT <- root
for (index in seq_along(exprs)) {
  if (is_function[index]) next
  eval(exprs[[index]], envir = env)
}
suppressWarnings(suppressMessages(env$load_model_modules(root)))

specs <- env$parameter_specs()
price <- specs[specs$id == "intervention_price", , drop = FALSE]

cat("\n1. The annual price's unit and help text\n")
check("the price's unit is \"EUR per year\"",
      identical(price$unit, "EUR per year"), price$unit)
check(
  "the help text states both charging conventions",
  identical(
    price$info,
    paste(
      "The annual price per person. In the cost-effectiveness model, it is",
      "charged for every treated person alive; in budget impact, it is charged",
      "only for active users."
    )
  ),
  price$info
)
check("the unit still starts with EUR, which the panel reads as its euro badge",
      startsWith(price$unit, "EUR"))

cat("\n2. Nothing else about the metadata moved\n")
model_price <- get("intervention_price_annual", envir = env, inherits = TRUE)
check("the price default is the model's own annual price",
      is.numeric(model_price) && isTRUE(all.equal(price$default, model_price)),
      c(price$default, model_price))
check("the price range and step are unchanged",
      identical(c(price$min, price$max, price$step), c(0, 2000, 10)),
      c(price$min, price$max, price$step))
check("the healthcare-use saving keeps its own unit",
      identical(specs$unit[specs$id == "healthcare_savings"], "EUR per active user per year"))
check("the implementation cost keeps its own unit",
      identical(specs$unit[specs$id == "implementation_cost"], "EUR per new user"))
check("all 16 inputs are still published",
      nrow(specs) == 16L && !anyDuplicated(specs$id), nrow(specs))

cat(sprintf("\n%d checks, %d failed\n", checks, failures))
if (failures > 0L) {
  cat("FAILED\n")
  quit(status = 1L)
}
cat("PASSED\n")
quit(status = 0L)
