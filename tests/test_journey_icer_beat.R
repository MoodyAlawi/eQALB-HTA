#!/usr/bin/env Rscript
# Synthetic tests for the journey's ICER teaching beat.
#
# The base case used to name the two differences and then move straight to the
# price lever, so the ratio the chapter exists to teach was never read on screen
# even though R publishes it. These checks pin the beat that reads it:
#
#   1. beat ordering, and that every note a beat names actually resolves;
#   2. the units and the numbers the note quotes, and that they are the same
#      values the one response publishes rather than a second calculation;
#   3. the wording of the results that have no price per QALY to report;
#   4. the price beat and its neighbours, so adding the beat changed nothing else.
#
# The wording checks call eqalb_journey_ratio_note() with hand-written values, so
# the exceptional branches are covered without needing a case that produces them.
# The ordering and resolution checks read the contract's own copy and notes. No
# simulation is run and no service is contacted:
#
#   Rscript tests/test_journey_icer_beat.R
#
# The script exits non-zero if any check fails, so it can gate a change.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg) > 0L) {
  sub("^--file=", "", file_arg[1])
} else {
  file.path("tests", "test_journey_icer_beat.R")
}
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
setwd(root)

suppressWarnings(suppressMessages({
  source("eqalb_markov.R")
  source("eqalb_ui_copy.R")
  source("eqalb_tutorial.R")
  source("eqalb_tutorial_journey.R")
}))

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

contains <- function(haystack, needle) {
  is.character(haystack) && length(haystack) > 0L &&
    !is.na(haystack[1]) && grepl(needle, haystack[1], fixed = TRUE)
}

# The money and QALY formatters the note itself uses, so a check compares against
# the same rendering the learner sees rather than a second format.
money <- eqalb_tutorial_money
qalys <- eqalb_tutorial_qalys

# --- 1. Beat ordering and note resolution ----------------------------------

cat("\nBeat ordering\n")

copy <- eqalb_journey_base_case_copy()
ids <- vapply(copy$stages, function(stage) stage$id, character(1))

check(
  "the base case has eight beats",
  length(ids) == 8L,
  list(length(ids))
)
check(
  "the ratio beat exists exactly once",
  sum(ids == "ratio") == 1L,
  list(sum(ids == "ratio"))
)
check(
  "the ratio beat comes immediately after the QALY beat",
  which(ids == "ratio") == which(ids == "qaly") + 1L,
  list(which(ids == "qaly"), which(ids == "ratio"))
)
check(
  "the price beat comes immediately after the ratio beat",
  which(ids == "price") == which(ids == "ratio") + 1L,
  list(which(ids == "ratio"), which(ids == "price"))
)
check(
  "the ratio beat is not interactive, so the graph advances past it",
  !isTRUE(copy$stages[[which(ids == "ratio")]]$interactive)
)
check(
  "the ratio beat points the guide at the lead between the two points",
  identical(copy$stages[[which(ids == "ratio")]]$focus, "lead")
)
check(
  "the ratio beat names the ratio note",
  identical(copy$stages[[which(ids == "ratio")]]$note_key, "ratio")
)

# Every beat that names a note must find one: the interface falls back to the
# caption on a miss, so a typo would silently show the wrong sentence.
result <- eqalb_journey_base_case(list())
notes <- result$base_case$notes
named <- Filter(Negate(is.null), lapply(copy$stages, function(stage) stage$note_key))
check(
  "at least one beat names a note",
  length(named) > 0L,
  list(length(named))
)
check(
  "every note a beat names resolves to a non-empty sentence",
  all(vapply(named, function(key) {
    text <- notes[[key]]
    is.character(text) && length(text) == 1L && nzchar(text)
  }, logical(1))),
  as.list(unlist(named))
)
check(
  "the ratio beat's sentence is the published ratio note",
  identical(
    notes$ratio,
    eqalb_journey_ratio_note(
      result$base_case$incremental_cost,
      result$base_case$incremental_qalys,
      result$base_case$icer
    )
  )
)

# --- 2. Units and numeric consistency ---------------------------------------

cat("\nUnits and the numbers the note quotes\n")

ratio <- notes$ratio
check(
  "the note names the incremental cost-effectiveness ratio",
  contains(ratio, "incremental cost-effectiveness ratio")
)
check(
  "the note gives the acronym ICER",
  contains(ratio, "ICER")
)
check(
  "the note explains the ratio as extra cost divided by extra QALYs",
  contains(ratio, "Dividing the extra") && contains(ratio, "by the extra")
)
check(
  "the note quotes the unit per additional QALY gained",
  contains(ratio, "per additional QALY gained")
)
check(
  "the note does not report the ratio per person",
  !contains(ratio, "per person"),
  list(ratio)
)

# The three numbers in the sentence must be the one response's own values.
check(
  "the note quotes the response's own incremental cost",
  contains(ratio, money(result$base_case$incremental_cost)),
  list(money(result$base_case$incremental_cost), ratio)
)
check(
  "the note quotes the response's own incremental QALYs",
  contains(ratio, qalys(result$base_case$incremental_qalys)),
  list(qalys(result$base_case$incremental_qalys), ratio)
)
check(
  "the note quotes the response's own ICER",
  contains(ratio, money(result$base_case$icer)),
  list(money(result$base_case$icer), ratio)
)
check(
  "the ICER the note quotes is the one icer_display renders",
  contains(result$base_case$icer_display, money(result$base_case$icer)),
  list(result$base_case$icer_display)
)
check(
  "the quoted ICER is the quotient of the two differences it names",
  isTRUE(all.equal(
    result$base_case$incremental_cost / result$base_case$incremental_qalys,
    result$base_case$icer,
    tolerance = 1e-9
  )),
  list(result$base_case$incremental_cost / result$base_case$incremental_qalys,
       result$base_case$icer)
)
check(
  "the cost and QALY notes still carry their own values",
  contains(notes$cost, money(result$base_case$incremental_cost)) &&
    contains(notes$health, qalys(result$base_case$incremental_qalys))
)

# The score is a model input, so moving it must move the ratio note with the
# result rather than leaving the previous sentence on screen.
moved <- eqalb_journey_base_case(list(utility_no_event = 0.95))
moved_notes <- moved$base_case$notes
check(
  "the ratio note follows the score to a different result",
  !identical(moved_notes$ratio, ratio),
  list(ratio, moved_notes$ratio)
)
check(
  "the moved note quotes the moved response's own ICER",
  contains(moved_notes$ratio, money(moved$base_case$icer)),
  list(money(moved$base_case$icer), moved_notes$ratio)
)
check(
  "the moved note still names the ratio and its unit",
  contains(moved_notes$ratio, "incremental cost-effectiveness ratio") &&
    contains(moved_notes$ratio, "per additional QALY gained")
)
check(
  "the moved note still avoids a per-person reading",
  !contains(moved_notes$ratio, "per person")
)

# A different price moves the numerator only, which is the point of the beat.
priced <- eqalb_journey_base_case(list(price = 240))
check(
  "the ratio note follows the price to a different result",
  contains(priced$base_case$notes$ratio, money(priced$base_case$icer)) &&
    !identical(priced$base_case$icer, result$base_case$icer),
  list(money(priced$base_case$icer), money(result$base_case$icer))
)

# --- 3. Results with no price per QALY to report ----------------------------

cat("\nExceptional results\n")

# Hand-written values, so each branch is covered without needing a case that
# produces it. The model is not asked for any of them.
note <- eqalb_journey_ratio_note

loss <- note(-500, -0.02, 25000)
check(
  "a loss of health is not reported as a price per QALY gained",
  contains(loss, "not a price per additional QALY gained") &&
    contains(loss, "gives up") &&
    !contains(loss, "Dividing the extra"),
  list(loss)
)
check(
  "the loss branch names the ICER so the term is not left undefined",
  contains(loss, "incremental cost-effectiveness ratio (ICER)")
)

none <- note(500, 0, NA_real_)
check(
  "no extra health reports that no ratio can be read",
  contains(none, "no incremental cost-effectiveness ratio (ICER) can be read") &&
    !contains(none, "per additional QALY gained"),
  list(none)
)
check(
  "no extra health is not described as a zero price per QALY",
  !contains(none, money(0))
)

saving <- note(-800, 0.05, -16000)
check(
  "costing less while adding health is not reported as a price to pay",
  contains(saving, "better on both counts") &&
    contains(saving, "not a price per additional QALY gained"),
  list(saving)
)
check(
  "the saving branch does not quote the negative ratio as an amount",
  !contains(saving, money(-16000)) && !contains(saving, money(16000)),
  list(saving)
)

free <- note(0, 0.05, 0)
check(
  "adding health at no extra cost reports a zero ICER per QALY gained",
  contains(free, "at no extra cost") &&
    contains(free, paste0(money(0), " per additional QALY gained")),
  list(free)
)

opaque <- note(1000, 0.01, NA_real_)
check(
  "an uninterpretable ratio says so and quotes no amount",
  contains(opaque, "not interpretable") && !contains(opaque, money(1000)),
  list(opaque)
)
check(
  "an uninterpretable ratio names the ICER",
  contains(opaque, "incremental cost-effectiveness ratio (ICER)")
)

check(
  "no branch describes the ratio per person",
  !any(vapply(
    list(loss, none, saving, free, opaque),
    function(text) contains(text, "per person"),
    logical(1)
  ))
)
check(
  "every branch returns one non-empty sentence",
  all(vapply(
    list(loss, none, saving, free, opaque),
    function(text) is.character(text) && length(text) == 1L && nzchar(text),
    logical(1)
  ))
)

# --- 4. The beats around the new one are unchanged -------------------------

cat("\nNeighbouring beats\n")

qaly_stage <- copy$stages[[which(ids == "qaly")]]
price_stage <- copy$stages[[which(ids == "price")]]

check(
  "the QALY beat is still interactive",
  isTRUE(qaly_stage$interactive)
)
check(
  "the QALY beat's advance label now names the ratio it leads to",
  identical(qaly_stage$advance_label, "Work out the ratio"),
  list(qaly_stage$advance_label)
)
check(
  "the QALY beat still points at the health difference",
  identical(qaly_stage$focus, "health")
)
check(
  "the price beat is still interactive",
  isTRUE(price_stage$interactive)
)
check(
  "the price beat still opens the bridge with its own label",
  identical(price_stage$advance_label, "The assumptions behind it"),
  list(price_stage$advance_label)
)
check(
  "the price beat still shows the cost note",
  identical(price_stage$note_key, "cost")
)
check(
  "the price beat still points at the cost difference",
  identical(price_stage$focus, "cost")
)
check(
  "the price beat still carries its own observation",
  contains(price_stage$observation, "health gain stays the same at every price"),
  list(price_stage$observation)
)
check(
  "the chapter still names one price label and one advance label",
  identical(copy$price_label, "Change the price") &&
    identical(copy$advance_label, "Next change on the graph")
)
check(
  "the two earlier beats keep their notes and cues",
  identical(copy$stages[[which(ids == "more_health")]]$note_key, "health") &&
    identical(copy$stages[[which(ids == "additional_cost")]]$note_key, "cost") &&
    identical(copy$stages[[which(ids == "both")]]$focus, "lead")
)
check(
  "the QALY illustration is still published for its beat",
  !is.null(result$base_case$utility_note) && nzchar(result$base_case$utility_note)
)
check(
  "the whole result is still published for a chapter that reads it",
  identical(result$base_case$reading$code, "costs_more_adds_health"),
  list(result$base_case$reading$code)
)

cat(sprintf("\n%d checks, %d failed\n", checks, failures))
if (failures > 0L) {
  cat("FAILED\n")
  quit(status = 1L)
}
cat("PASSED\n")
quit(status = 0L)
