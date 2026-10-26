# eQalb Guided Tutorial journey: the case brief and Chapter 1 (base case).
#
# The journey is a teaching sequence over the same economic model the rest of the
# application uses. This module owns only what the first slice needs: the fixed
# case the learner is asked about, the wording of the brief and of Chapter 1, one
# price lever, and the R-side interpretation of the base-case result.
#
# No arithmetic is defined here. The base case is produced by
# eqalb_tutorial_ce(), which calls run_eqalb_model() exactly as the analysis
# dashboard and Guided Tutorial Part 1 do; this module passes it the case's own
# values and re-presents what it returns. Every number, formatted string, status
# word and interpretation is therefore the same value the other screens show.
#
# The case is self-contained. Its fixed assumptions are the tutorial's own
# defaults, so a journey result cannot move when the dashboard is edited, and the
# journey's price lever cannot move a dashboard input.
#
# The willingness-to-pay reference is published for context, and the value-of-
# information chapter passes it to voi_evpi() and voi_evppi(), which need one to put
# a value on a QALY. It stays a benchmark and never a funding test: no status,
# recommendation or cost-effectiveness verdict is derived from it anywhere here.
#
# Sourced by api/plumber.R, which is what the browser interface talks to.

# --- Journey constants ------------------------------------------------------

EQALB_JOURNEY_CASE_ID <- "eqalb-regional-payer"
EQALB_JOURNEY_CASE_VERSION <- 1L

# The one control this slice exposes. R's price control is published under this
# id so the request body stays about the decision, not about the tutorial's
# internal naming.
EQALB_JOURNEY_PRICE_ID <- "price"

# The case's willingness-to-pay reference. The brief mentions it, and the
# value-of-information chapter hands it to the analysis functions that need a value
# for a QALY. Nothing in this module tests a result against it.
EQALB_JOURNEY_THRESHOLD_PER_QALY <- 100000

# The price range the learner may explore. Inside it the incremental cost per
# person runs from a saving to roughly six times the proposed price, so the point
# visibly changes its position relative to the axis and the ratio stays
# interpretable at every step. The bounds are the lever's own limits, not a
# result: no status, decision or interpretation is derived from them.
EQALB_JOURNEY_PRICE_MIN <- 40
EQALB_JOURNEY_PRICE_MAX <- 440

# The budget chapter's own lever. R's coverage control is published under this id, so
# the request body and the response stay about the decision rather than about the
# tutorial's internal naming.
EQALB_JOURNEY_COVERAGE_ID <- "coverage"

# The scenario's second lever: the quality-of-life score of a year without a prior
# cardiovascular event. It is a model input, not an illustration, so it travels with
# the price in the body of every request whose calculation reads it.
#
# The range is the one the chapter teaches in. It is wide enough to move the result
# visibly and narrow enough that the score stays a score; the default is the model's
# own assumption, read from the tutorial defaults rather than retyped.
EQALB_JOURNEY_UTILITY_ID <- "utility_no_event"
EQALB_JOURNEY_UTILITY_MIN <- 0.80
EQALB_JOURNEY_UTILITY_MAX <- 1.00
EQALB_JOURNEY_UTILITY_STEP <- 0.01

# The one score at which the model and its uncertainty analysis part company, and
# the sentence that says so. `psa_beta_parameters()` keeps a beta inside its valid
# region, so a mean of exactly 1 is drawn from a very narrow distribution just below
# 1 and its spread is not the usual one. Deterministic runs use the score exactly as
# chosen. Only this one endpoint is affected, which is why only it carries a note.
EQALB_JOURNEY_UTILITY_CEILING <- 1.00

# The chapters this slice implements, in teaching order. Later chapters are added
# to this list as they are built, so the navigation never advertises a chapter
# that cannot be opened.
#
# The list is the only place the order lives. A chapter's number, its heading and
# the chapter it follows all come from its position here, so reordering the
# journey is a matter of moving a line rather than renaming anything: the ids are
# stable, and no function, endpoint or component depends on a chapter's number.
EQALB_JOURNEY_CHAPTERS <- list(
  list(id = "case", name = "Case brief", progress = "Case brief"),
  list(id = "base_case", name = "The base case", progress = "Base case"),
  list(
    id = "sensitivity",
    name = "Which assumptions matter most?",
    progress = "Sensitivity"
  ),
  list(
    id = "uncertainty",
    name = "How certain is the comparison?",
    progress = "Uncertainty"
  ),
  list(
    id = "voi",
    name = "What would better evidence be worth?",
    progress = "Better evidence"
  ),
  list(
    id = "price",
    name = "What price is justified?",
    progress = "Price"
  ),
  list(
    id = "budget",
    name = "What would adoption cost in total?",
    progress = "Budget"
  ),
  list(
    id = "readiness",
    name = "Can it be delivered as planned?",
    progress = "Readiness"
  ),
  list(
    id = "survival",
    name = "Time to a first heart attack or stroke",
    progress = "Over time"
  )
)

# The chapters as the interface reads them: a numbered heading for every entry after
# the brief, composed here so a moved chapter cannot keep an old number.
#
# The number is the entry's own position in this list, which is the number the
# interface's stepper and its "Chapter {step} of {total}" line already show. Computing
# it from the position rather than counting chapters after the brief is what keeps the
# heading and the navigation saying the same thing: the brief is entry 1 and names
# itself, the base case is entry 2 and is headed "Chapter 2", and the last chapter's
# number is the list's length.
eqalb_journey_chapters <- function() {
  chapters <- EQALB_JOURNEY_CHAPTERS
  lapply(seq_along(chapters), function(index) {
    chapter <- chapters[[index]]
    list(
      id = chapter$id,
      title = if (index == 1L) {
        chapter$name
      } else {
        paste0("Chapter ", index, ". ", chapter$name)
      },
      progress = chapter$progress
    )
  })
}

# One chapter's own heading, by id. A chapter's copy asks for its heading rather
# than spelling it out, so the heading and the navigation cannot disagree.
eqalb_journey_chapter_title <- function(id) {
  chapters <- eqalb_journey_chapters()
  matches <- vapply(chapters, function(chapter) identical(chapter$id, id), logical(1))
  if (!any(matches)) return("")
  chapters[[which(matches)[1]]]$title
}

# The chapter that follows one, or NULL at the end of the journey. The bridges use
# this, so a bridge cannot point at a predecessor or successor that has moved.
eqalb_journey_next_chapter_id <- function(id) {
  ids <- vapply(EQALB_JOURNEY_CHAPTERS, function(chapter) chapter$id, character(1))
  index <- match(id, ids)
  if (is.na(index) || index >= length(ids)) return(NULL)
  ids[[index + 1L]]
}

# --- The fixed case ---------------------------------------------------------

# The case's fixed assumptions are the tutorial's own defaults, read rather than
# retyped, so the journey and Guided Tutorial Part 1 cannot disagree about the
# evidence, engagement or utility values.
#
# `utility_no_event` is the one of these the learner moves. It is still returned
# here as the default, so every reader that has no score in hand gets the model's
# own assumption rather than a guess.
eqalb_journey_fixed_assumptions <- function() {
  defaults <- eqalb_tutorial_defaults()
  fixed <- eqalb_tutorial_fixed()
  list(
    rrr_pct = defaults$tutorial_rrr,
    engagement_year1_pct = defaults$tutorial_engagement_year1,
    engagement_followup_pct = defaults$tutorial_engagement_followup,
    utility_no_event = defaults$tutorial_utility_no_event,
    implementation_cost = fixed$implementation_cost,
    healthcare_savings = fixed$healthcare_savings,
    utility_post_mi = fixed$utility_post_mi,
    utility_post_stroke = fixed$utility_post_stroke,
    # The readiness chapter's own non-editable inputs. They live here so the
    # chapter's starting assessment is built from the same place as everything else,
    # and so the scenario key gains them without a second table of case values.
    digital_access_pct = fixed$digital_access_pct,
    digital_suitability_pct = fixed$digital_suitability_pct,
    accessibility_features = isTRUE(fixed$accessibility_features),
    supported_languages = fixed$supported_languages_available,
    interoperability_available = fixed$interoperability_available,
    algorithm_governance = fixed$algorithm_governance
  )
}

# The case's assumptions with the learner's score in place of the default. Every
# calculation asks for its assumptions through this function, so the score is
# applied once rather than remembered at each call site, and a caller that has no
# score gets exactly the case that was published before the score existed.
eqalb_journey_case_assumptions <- function(utility_no_event = NULL) {
  assumptions <- eqalb_journey_fixed_assumptions()
  if (!is.null(utility_no_event)) {
    assumptions$utility_no_event <- utility_no_event
  }
  assumptions
}

# The learner's score from a request body, bounded by the chapter's own range.
# Absent, it is the model's assumption; outside the range it is refused rather than
# clamped, so a score the interface cannot produce never becomes a model input.
eqalb_journey_utility <- function(body = list()) {
  default <- eqalb_journey_fixed_assumptions()$utility_no_event
  value <- body[[EQALB_JOURNEY_UTILITY_ID]]
  if (is.null(value)) return(default)
  eqalb_tutorial_number(
    body,
    EQALB_JOURNEY_UTILITY_ID,
    default,
    min = EQALB_JOURNEY_UTILITY_MIN,
    max = EQALB_JOURNEY_UTILITY_MAX
  )
}

# The score as the interface prints it: two decimals, because the control's step is
# a hundredth and a score is read as a value on a scale.
eqalb_journey_utility_display <- function(value) {
  format(round(value, 2), nsmall = 2, trim = TRUE)
}

# The model's own horizon and discounting, echoed so the brief describes the case
# the model actually ran rather than a remembered number.
eqalb_journey_horizon_years <- function() {
  cycles <- eqalb_tutorial_model_constant("cycles", 10)
  as.integer(round(cycles))
}

eqalb_journey_discounting_display <- function() {
  rate <- eqalb_tutorial_model_constant("discount_rate_cost", 0.03)
  paste0(format(round(rate * 100, 2), nsmall = 0, trim = TRUE), "% a year")
}

# The case as the interface publishes it: the decision, the two points, the
# proposed price and the two explanations the brief keeps behind disclosures. It
# stays short on purpose - the case brief is four lines, and everything a learner
# might want defined is one click away. QALYs and the threshold are deliberately
# not explained here: QALYs arrive on the screen that first plots health, and the
# threshold is not part of this slice at all.
eqalb_journey_case <- function() {
  assumptions <- eqalb_journey_fixed_assumptions()
  defaults <- eqalb_tutorial_defaults()
  horizon <- eqalb_journey_horizon_years()
  population <- defaults$tutorial_population
  proposed_price <- defaults$tutorial_price

  list(
    case_id = EQALB_JOURNEY_CASE_ID,
    case_version = EQALB_JOURNEY_CASE_VERSION,
    title = "Should this payer fund eQalb?",
    # The brief is a picture rather than a page: one line of context, then the
    # labels the drawing needs. Each label is short enough to sit beside or under a
    # node in the diagram, and every number in it is R's own.
    intro = "A regional payer is considering eQalb for adults with hypertension.",
    payer_label = "Regional payer",
    # The connector labels are worded as facts about the drawing rather than as
    # actions: the payer is not described as deciding anything yet, and the fork is
    # named as a choice between two options so it cannot read as a sequence.
    funds_label = "covers care for",
    population_label = paste0(
      format(population, big.mark = ",", scientific = FALSE),
      " eligible adults"
    ),
    population_arrow_label = "one of two options",
    option_labels = list(
      list(id = "usual_care", label = "Usual care", role = "already funded"),
      list(id = "eqalb", label = "Usual care + eQalb", role = "being considered")
    ),
    comparison_label = "These two options are compared.",
    price_lead = "The manufacturer proposes",
    # The model charges the annual price to every person in the eQalb arm in every
    # cycle: engagement scales the modelled benefit, not the charge. So the price is
    # per person per year, which is also the tutorial price control's own unit.
    price_unit = "per person per year",
    # Two money strings, both R's: the amount on its own so the drawing can set it
    # large, and the whole tag so nothing else has to join an amount to its unit.
    price_amount = eqalb_tutorial_money(proposed_price),
    price_display = paste0(
      eqalb_tutorial_money(proposed_price),
      " ",
      "per person per year"
    ),
    proposed_price = proposed_price,
    task = "See what eQalb buys, then test the price.",
    # The brief is the first entry in the chapter list, so the chapter it opens is
    # numbered two. The label names the chapter it actually starts, which is the number
    # its heading and the progress line both show.
    start_label = "Start Chapter 2",
    # One collapsed disclosure rather than two open ones: perspective, horizon and
    # discounting are details a learner asks for, not the first thing they read.
    assumptions = list(
      title = "Model assumptions",
      lines = list(
        paste(
          "The health system payer: only the costs that payer bears are",
          "counted."
        ),
        paste0(
          "The model runs for ", horizon, " years, with costs and health",
          " discounted at ", eqalb_journey_discounting_display(), "."
        )
      )
    ),
    fixed_assumptions = assumptions
  )
}

# --- Chapter 1 wording ------------------------------------------------------

# One entry per screen: a heading, one sentence of guidance and, where the
# screen has an action, that action's label. The wording carries no computed
# value: every number-bearing sentence comes back with the result, so R formats
# both the words and the values and the interface only prints them.
#
# The screens introduce one idea at a time and never ask the learner to pick an
# answer from a list. The two ideas that need naming - QALY and ICER - are
# introduced only after the learner has seen the relationship on the graph, and
# both are explained inside the screen that uses them.
eqalb_journey_base_case_copy <- function() {
  list(
    title = eqalb_journey_chapter_title("base_case"),
    # Six states of one graph. Each state highlights one thing on the same plane
    # and says one sentence about it. The learner moves between the states by
    # activating the graph itself, so the chapter publishes no forward control:
    # `advance_label` is the accessible name of that activation, not a button.
    #
    # `note_key` names which of the response's own sentences this state shows
    # beside the graph, because that sentence carries a value that only the model
    # can produce. A state with no note shows only its caption.
    #
    # `focus` is the state's cue for the guidance overlay: which part of the same
    # plane the learner should be looking at. It names a region, not a result, so
    # the interface can light that region and soften the rest without knowing
    # anything economic. The cues are `origin` (the starting point alone), `lead`
    # (the two points and the move between them), `health` (the horizontal
    # difference) and `cost` (the vertical difference).
    stages = list(
      list(
        id = "usual_care",
        caption = "Usual care is where the comparison starts.",
        focus = "origin"
      ),
      list(
        id = "add_eqalb",
        caption = "eQalb is added on top of usual care.",
        focus = "lead"
      ),
      list(
        id = "more_health",
        caption = "eQalb also adds health, which moves the point right.",
        note_key = "health",
        focus = "health"
      ),
      list(
        id = "additional_cost",
        caption = "It also adds cost, which moves the point up.",
        note_key = "cost",
        focus = "cost"
      ),
      list(
        id = "both",
        caption = "So it buys health, and it costs more than usual care.",
        focus = "lead"
      ),
      list(
        id = "qaly",
        # What the health figure the learner has just met actually measures. It is a
        # state of its own because it is the one interactive explanation in the
        # chapter, and because it must arrive before the price is moved: the price
        # changes only the cost side, and the learner should know what the health
        # side is before that.
        caption = "Here is what a QALY measures.",
        focus = "health",
        # Its own control is the slider, so activating the graph must not skip it.
        interactive = TRUE,
        advance_label = "Change the price"
      ),
      list(
        id = "price",
        caption = "A higher price buys the same health for more money.",
        note_key = "cost",
        focus = "cost",
        # The price state's own control is the slider, so activating the graph must
        # not advance past it.
        interactive = TRUE,
        # The price state is where the base case ends, so its advance control opens
        # the bridge into the assumptions behind the comparison rather than moving
        # to another state of the graph.
        advance_label = "The assumptions behind it",
        observation = paste(
          "The health gain stays the same at every price; only the extra cost",
          "moves."
        )
      )
    ),
    advance_label = "Next change on the graph",
    advance_hint = "Activate the graph to carry on.",
    price_label = "Change the price"
  )
}

# The one-year QALY illustration that sits beside the base case's health state.
#
# The score it shows is the model's own no-event utility, and moving it now moves the
# model: the slider sets that input rather than a figure drawn beside it, and the
# chapter's own results are re-run for the score on screen. What R still owns is
# every word, every bound and every number that does not depend on the slider; the
# one-year line is arithmetic on the score and is labelled as the illustration it is.
#
# The panel shows the caption, the definition, the slider and its value and the two
# utilities the interaction holds fixed. Everything else — what the scale means, what the
# score is for, the one-year line, the model's answer at the score on screen, the note
# for the one score the uncertainty analysis cannot draw exactly, and the way back to the
# model's own assumption — is published as one information block, so the step carries one
# disclosure rather than a disclosure and a details block side by side.
eqalb_journey_qaly_illustration <- function() {
  assumptions <- eqalb_journey_fixed_assumptions()
  score <- assumptions$utility_no_event
  two_dp <- eqalb_journey_utility_display

  list(
    heading = paste(
      "A QALY combines how long someone lives with their quality of life."
    ),
    control = list(
      id = "qaly_score",
      label = "Quality-of-life score before a cardiovascular event",
      min = EQALB_JOURNEY_UTILITY_MIN,
      max = EQALB_JOURNEY_UTILITY_MAX,
      step = EQALB_JOURNEY_UTILITY_STEP,
      default = score,
      default_display = two_dp(score)
    ),
    # The formula's own words, so the line the learner reads is composed from R's
    # text rather than from a sentence built in the interface. This line is the
    # illustration: one year in one state, at the score on screen.
    formula_label = "One year in this state, at this score",
    formula = list(
      year = "1 year",
      times = "\u00d7",
      equals = "=",
      unit = "QALYs"
    ),
    # The two values the model holds fixed while this score moves. They stay visible
    # beside the slider, because a learner comparing quality-of-life scores needs them
    # to read the interaction; only the explanation behind them is behind the panel's
    # information button.
    fixed_title = "Values the model uses for the other states",
    fixed = list(
      list(
        label = "After a heart attack",
        value = assumptions$utility_post_mi,
        display = two_dp(assumptions$utility_post_mi)
      ),
      list(
        label = "After a stroke",
        value = assumptions$utility_post_stroke,
        display = two_dp(assumptions$utility_post_stroke)
      )
    ),
    # Everything the panel does not need on screen at once: what the scale means, what
    # the score is used for, how the model turns scores into QALYs, and what the extra
    # QALYs are. One information button carries it, together with the one-year line, the
    # model's answer at the score on screen (published by the base-case response, so it
    # can follow the slider) and the way back to the model's own assumption, so the panel
    # keeps the caption, the definition, the slider, its value and the two held values.
    info_title = "How this score is used",
    info = paste(
      "0 is as bad as death, 1 is full health. This score is one of the model's",
      "assumptions, so the results above use it. The model adds time in each health",
      "state weighted by its quality-of-life score, and extra QALYs are the",
      "difference between eQalb and usual care."
    ),
    reset_label = "Use the model's assumption",
    # The one score the uncertainty analysis cannot represent exactly. Shown only
    # when the learner is at that score, and never as a claim about the model.
    ceiling_note = paste(
      "The model uses 1.00; uncertainty simulations use values just below 1."
    )
  )
}

# Whether the score on screen is the one the note above is about.
eqalb_journey_utility_at_ceiling <- function(value) {
  isTRUE(abs(value - EQALB_JOURNEY_UTILITY_CEILING) < 1e-9)
}

# The recap between the two chapters.
#
# It is a narrative bridge, not a completion screen and not a question the learner
# has to answer: it says back what they have just done and asks what would happen
# if the assumptions behind it changed. R writes all of it, including the label of
# the control that leaves it, because the wording is part of the teaching rather
# than part of the interface.
# The recaps that bridge one chapter into the next.
#
# Each one is keyed by the chapter it opens, not by the chapter it leaves, so a
# bridge travels with its destination when the journey is reordered and cannot end
# up pointing at a chapter that has moved. A recap is a narrative bridge, not a
# completion screen and not a question the learner has to answer: it says back what
# they have just done and asks the question the next chapter answers. R writes all
# of it, including the label of the control that leaves it, because the wording is
# part of the teaching rather than part of the interface.
eqalb_journey_recaps <- function() {
  list(
    # The base case depends on assumptions; the next chapter moves one of them.
    sensitivity = list(
      lines = list(
        paste(
          "The comparison uses assumptions about price, health and what happens",
          "over time."
        )
      ),
      question = "What if one of those assumptions changes?",
      advance_label = "Show one assumption at a time"
    ),
    # One assumption at a time gives way to several varying together.
    uncertainty = list(
      lines = list("So far, we changed one assumption at a time."),
      question = paste(
        "What happens when several uncertain assumptions vary together?"
      ),
      advance_label = "How much it can vary"
    ),
    # The repeats give way to the question of whether better evidence would help.
    # The question is asked of the two options, not of the dots: the journey never
    # suggests that one simulated combination is the answer.
    voi = list(
      lines = list(
        paste(
          "The repeats showed how far the comparison can move when several",
          "assumptions vary."
        )
      ),
      question = "Could better evidence help us choose between the two options?",
      advance_label = "What better evidence is worth"
    ),
    # The price chapter opens on what the previous one left standing: every result so
    # far used one annual price. The question is where the price has to sit for the
    # balance to hold, which is a different question from whether the balance is
    # certain, and the chapter keeps the two apart.
    price = list(
      lines = list(
        paste(
          "Every result so far used one annual price, and a different price would",
          "change only the cost side of the comparison."
        )
      ),
      question = "Where does the price have to sit for the balance to hold?",
      advance_label = "Show what the price changes"
    ),
    # The budget chapter opens on the difference the previous one left: a price per
    # person is not a budget, and the module that totals spending counts a different
    # set of people from the model that produced the balance.
    budget = list(
      lines = list(
        paste(
          "The last chapter answered a per-person question about one year's price."
        )
      ),
      question = "What would it cost to offer eQalb to a whole population?",
      advance_label = "Show what adoption would cost"
    ),
    # The readiness chapter opens on what every chapter so far took for granted: that
    # the technology can be delivered at all. The question is about conditions, not
    # about value, so it cannot be answered by the economic results however they
    # turned out.
    readiness = list(
      lines = list(
        paste(
          "The economic results describe value and spending if eQalb is delivered",
          "as modelled."
        )
      ),
      question = paste(
        "What would it take to deliver it, and what has to be in place first?"
      ),
      advance_label = "What gets checked"
    ),
    # The last chapter opens on what every chapter before it compressed into a risk per
    # year: the same comparison is drawn as time to a first event, so the learner can
    # read when events happen rather than only how many occur in a cycle. It is a
    # different view of the same effect assumption, not a further calculation of value.
    survival = list(
      lines = list(
        paste(
          "Every chapter so far treated the chance of an event as a risk in a year."
        )
      ),
      question = paste(
        "What does the same comparison look like when events are timed?",
        "One final view."
      ),
      advance_label = "Show how events unfold over time"
    )
  )
}

# The bridge that opens one chapter, or NULL when nothing follows the one given.
# Both the contract and the response for a chapter ask for it here, so the journey
# has one definition of each bridge.
eqalb_journey_recap_for <- function(target_id) {
  if (is.null(target_id)) return(NULL)
  recaps <- eqalb_journey_recaps()
  if (!target_id %in% names(recaps)) return(NULL)
  recaps[[target_id]]
}

# The PSA chapter's copy. Six states of the same plane: the dots appear, the learner
# is told which one is the comparison they already know, the amount the result can
# change is read, the two sides of usual care are described from the counts R
# measured, the chapter says what the dots do and do not cover, and it ends on the
# question the next chapter answers.
#
# Each caption names the assumption or economic fact in play, its consequence for
# extra cost or extra health, and the feature that shows it; the number-bearing
# sentence arrives with the result. The wording is deliberately plain, and the
# technical name arrives after the dots have been explained visually.
#
# Nothing here is a threshold, a probability of being cost-effective, an expected
# value or a recommendation. It makes no claim the numbers do not support: it does
# not say the dots must gather around the base case, it does not say any result fell
# on the other side of usual care unless R measured that it did, and it never says
# every assumption varied.
eqalb_journey_uncertainty_copy <- function() {
  list(
    title = eqalb_journey_chapter_title("uncertainty"),
    # The quiet disclosure under the chart, for a learner who wants the detail
    # behind "several uncertain assumptions". Its contents come from the analysis's
    # own parameter table, and its title is here so the panel invents nothing.
    variation_title = "Which assumptions varied",
    stages = list(
      list(
        id = "repeats",
        caption = paste(
          "Each dot repeats the comparison with several uncertain assumptions",
          "varying together."
        ),
        focus = "cloud",
        note_key = "repeats",
        # The guide's directional cue: the feature this state's arrow leads from
        # and to. It names two regions of the same plane, so the interface draws
        # the connection R asked for without deciding anything itself.
        lead = "point_to_cloud"
      ),
      list(
        id = "cluster",
        caption = "The highlighted point is the comparison you explored earlier.",
        focus = "centre",
        note_key = "mean",
        lead = "cloud_to_centre"
      ),
      list(
        id = "spread",
        caption = "The dots show how far the extra cost and extra health move.",
        focus = "spread",
        note_key = "spread",
        lead = "centre_to_spread"
      ),
      list(
        id = "sides",
        caption = "Look at where the dots sit on either side of usual care.",
        focus = "sides",
        note_key = "sides",
        lead = "spread_to_zero"
      ),
      list(
        id = "limit",
        caption = paste(
          "This shows uncertainty in the assumptions we varied, not every",
          "possible uncertainty."
        ),
        focus = "cloud"
      ),
      # The journey's temporary end: the question the next chapter will answer. It
      # carries no advance control, because nothing follows it yet, and it is not a
      # completion screen - the panel and the chart stay exactly as they are.
      list(
        id = "opens_next",
        caption = paste(
          "So would better evidence change the decision, and what would that be",
          "worth? That is the next question."
        ),
        focus = "cloud"
      )
    ),
    advance_label = "Next part of the comparison"
  )
}

# Chapter 2's own graph labels. Same plane, same axes, so the two chapters read as
# one picture; only the two things the dots add are named.
eqalb_journey_uncertainty_graph <- function() {
  list(
    x_label = "Extra QALYs per person",
    y_label = "Extra cost (EUR per person)",
    origin_label = "Usual care",
    point_label = "Usual care + eQalb",
    cloud_label = "Combinations of assumptions",
    mean_label = "Average of the dots"
  )
}

# --- The price lever --------------------------------------------------------
# The price lever this slice offers, narrowed to the range where the learner can
# actually see the point change its position relative to the axis: inside it the
# extra cost per person runs from a saving to about six times the proposed price.
# The label, unit, step, default and explanation stay the tutorial's own.
eqalb_journey_price_control <- function() {
  controls <- eqalb_tutorial_controls()
  matches <- vapply(
    controls, function(control) identical(control$id, "tutorial_price"), logical(1)
  )
  control <- controls[[which(matches)[1]]]
  control$id <- EQALB_JOURNEY_PRICE_ID
  control$step_index <- 1L
  control$min <- EQALB_JOURNEY_PRICE_MIN
  control$max <- EQALB_JOURNEY_PRICE_MAX
  control
}

# --- The static contract ----------------------------------------------------

# Everything the interface needs before any calculation. Building it runs no
# model.
eqalb_journey_contract <- function() {
  total <- length(EQALB_JOURNEY_CHAPTERS)
  list(
    journey = list(
      title = "Guided tutorial",
      kicker = "Funding eQalb: from a base case to a recommendation",
      progress = list(
        total = total,
        step_template = "Chapter {step} of {total}. {title}"
      ),
      navigation = list(
        back = "Back",
        forward = "Next",
        exit = "Exit tutorial",
        restart = "Restart journey"
      ),
      # The method note behind each module's "How this is calculated" control, the
      # same dictionary the analysis app reads from /api/defaults. The journey
      # republishes it so a chapter can show its own note without a second request,
      # and so the analysis app and the lesson can never describe a method
      # differently.
      methods = MODULE_METHOD_NOTES,
      # The end of the journey as it stands: the overlay the journey opens after the
      # last state of its last chapter. It is a handoff, not a verdict and not a
      # summary of a decision. The interface shows it only when the chapter list has
      # nothing after the chapter on screen, so the sentence counts no chapters and
      # names no last topic - a chapter added later cannot make it wrong. `title` and
      # `body` are the overlay's two lines; `open_label` and `restart_label` are its
      # two actions, and the overlay's own close control returns the learner to the
      # chart. `exit_label` stays published for the contract's sake; the overlay reaches
      # Home through the analysis app's own header rather than through a third action.
      end = list(
        title = "You\u2019ve completed The Journey",
        body = "Explore the analysis workspace with your own assumptions.",
        sentence = paste(
          "That is the whole case: what eQalb buys, what it would cost, and what",
          "delivery would take."
        ),
        note = paste(
          "The analysis app runs the same model, with controls for your own",
          "assumptions."
        ),
        open_label = "Open analysis workspace",
        restart_label = "Restart The Journey",
        exit_label = "Exit to Home"
      ),
      chapters = eqalb_journey_chapters()
    ),
    case = eqalb_journey_case(),
    base_case = list(
      copy = eqalb_journey_base_case_copy(),
      # The graph's own labels. Kept minimal on purpose: the two points, the two
      # differences the chapter teaches, and the two axis names. There is no
      # threshold line, no status colour and no annotation of its own.
      graph = list(
        title = "Extra cost against extra health",
        x_label = "Extra QALYs per person",
        y_label = "Extra cost (EUR per person)",
        origin_label = "Usual care",
        point_label = "Usual care + eQalb",
        cost_leg_label = "Additional cost",
        health_leg_label = "More health",
        select_hint = "The comparison starts here."
      ),
      controls = list(eqalb_journey_price_control()),
      # The base case's one-year QALY illustration. It is copy and two model
      # assumptions, not a result: nothing here touches the model or its caches.
      qaly = eqalb_journey_qaly_illustration(),
      # R's column names for the result table, taken from the tutorial's own
      # contract so the two screens cannot label the same table differently.
      table_headings = eqalb_tutorial_contract()$part1$table_headings
    ),
    # Every bridge, keyed by the chapter it opens. The interface looks one up by the
    # next chapter's id, so the bridges follow the order and cannot point at a
    # chapter that has moved. Copy, not a result.
    recaps = eqalb_journey_recaps(),
    # The one-at-a-time chapter's copy and labels. It has no control of its own: it
    # runs at the price the learner left the base case at, so the assumptions are
    # tested on the comparison they actually built.
    sensitivity = list(
      copy = eqalb_journey_sensitivity_copy(),
      graph = eqalb_journey_sensitivity_graph(),
      # The chapter's methodological notes, kept out of the panel: the method's name,
      # what a flat bar means, and what a long bar does not mean.
      disclosure = eqalb_journey_sensitivity_disclosure()
    ),
    # The uncertainty chapter's copy and labels, with the same rule: it repeats the
    # learner's own comparison, and has no lever of its own.
    uncertainty = list(
      copy = eqalb_journey_uncertainty_copy(),
      graph = eqalb_journey_uncertainty_graph()
    ),
    # The value-of-information chapter's copy and chart labels. It also has no
    # lever: it values the repeats the learner has already been shown. The reference
    # value is published so the client can echo exactly the value it was shown
    # instead of holding one of its own.
    voi = list(
      copy = eqalb_journey_voi_copy(),
      graph = eqalb_journey_voi_graph(),
      threshold = EQALB_JOURNEY_THRESHOLD_PER_QALY,
      threshold_display = eqalb_journey_voi_threshold_display(
        EQALB_JOURNEY_THRESHOLD_PER_QALY
      )
    ),
    # The price chapter's copy, chart labels and its own price lever. The lever is the
    # same one the base case publishes, so the learner meets one slider rather than a
    # second one; the chapter moves a local copy of it and leaves every earlier result
    # at the price those results were computed for. `scenario_key` names every input
    # the price solve depends on, so a stored solve can never be shown against a
    # different case or a different reference.
    price = list(
      copy = eqalb_journey_price_copy(),
      graph = eqalb_journey_price_graph(),
      control = eqalb_journey_price_control(),
      threshold = EQALB_JOURNEY_THRESHOLD_PER_QALY,
      threshold_display = eqalb_journey_voi_threshold_display(
        EQALB_JOURNEY_THRESHOLD_PER_QALY
      ),
      scenario_key = eqalb_journey_price_scenario_key()
    ),
    # The budget chapter's copy, chart labels, its own coverage lever, and the case
    # figures its sentences are built from. It runs no model: the whole calculation is
    # calculate_budget_impact(), five rows of arithmetic per coverage step.
    budget = list(
      copy = eqalb_journey_budget_copy(),
      graph = eqalb_journey_budget_graph(),
      control = eqalb_journey_coverage_control(),
      population = eqalb_journey_budget_population(),
      horizon_years = eqalb_journey_budget_horizon(),
      assumptions = eqalb_journey_budget_assumptions(),
      # What the budget module publishes so its own panel can open this lesson on its
      # own. The orientation is the one sentence a reader who arrived from the module
      # needs: the fixed tutorial price the lesson uses, and that it reads none of
      # their settings. The price is the case's own proposal, so the standalone lesson
      # charges exactly what the journey's example charges and nothing here can be
      # confused for the learner's own scenario.
      module = list(
        label = "Budget impact",
        orientation = paste0(
          "A standalone explainer of the tutorial's own example: 100,000 eligible ",
          "adults at the case's ",
          eqalb_price_format_money(eqalb_journey_price_control()$default),
          " per person per year. It reads none of your analysis settings and ",
          "changes none of them."
        ),
        price = eqalb_journey_price_control()$default,
        enter_label = "Explain this",
        return_label = "Back to analysis"
      )
    ),
    # The readiness chapter's copy, its figure's labels, the four questions with their
    # scenario-worded answers, and the case's own non-editable inputs. It runs no
    # model: calculate_readiness() is arithmetic over ten inputs and seven fixed rules.
    readiness = list(
      copy = eqalb_journey_readiness_copy(),
      graph = eqalb_journey_readiness_graph(),
      questions = eqalb_journey_readiness_questions(),
      defaults = eqalb_journey_readiness_defaults(),
      fixed = eqalb_journey_readiness_fixed(),
      inputs = eqalb_journey_readiness_inputs(
        eqalb_journey_readiness_defaults()
      ),
      # What the readiness module publishes so its own panel can open this lesson as
      # a standalone explainer. The orientation is the one sentence a learner who
      # arrived from the module needs: which case the lesson uses, and that it reads
      # none of their settings. Nothing here changes the journey's own wording, and no
      # chapter's captions are duplicated.
      module = list(
        label = "DHT readiness",
        orientation = paste(
          "A standalone explainer of the tutorial's own example: 100,000 eligible",
          "adults, with the case's access and engagement values. It reads none of",
          "your analysis settings and changes none of them."
        ),
        enter_label = "Explain this",
        return_label = "Back to analysis"
      )
    ),
    # The last chapter's copy, its figure's labels, the three times it can be read at,
    # and the key naming every input its simulation reads. It is a different view of the
    # same effect assumption rather than a further calculation: it reads no price and no
    # score, so nothing earlier can change it and it changes nothing earlier.
    survival = list(
      copy = eqalb_journey_survival_copy(),
      graph = eqalb_journey_survival_graph(),
      # Every input and setting the simulation reads, composed in R, so a client can
      # cache against all of them rather than against this session.
      inputs_key = eqalb_journey_survival_inputs_key(),
      # What the survival module publishes so its own panel can open this lesson on its
      # own. The orientation is the one sentence a reader who arrived from the module
      # needs: the fixed example, and that it reads none of their settings.
      module = list(
        label = "Simulated survival",
        orientation = paste0(
          "A standalone explainer of the tutorial's own example: 1,000 simulated ",
          "people per arm over 10 years, at the case's effect assumptions. It reads ",
          "none of your analysis settings and changes none of them."
        ),
        enter_label = "Explain this",
        return_label = "Back to analysis"
      )
    ),
    # The journey states that its data are illustrative once, in the shell, so
    # no screen or result component repeats it.
    notice = eqalb_tutorial_notice()
  )
}

# --- The base case ----------------------------------------------------------

# The case's assumptions plus the learner's two levers, expressed as the tutorial
# inputs eqalb_tutorial_ce() already accepts. Nothing else is read, so a request
# cannot reach a dashboard or Part 1 setting.
eqalb_journey_inputs <- function(price, utility_no_event = NULL) {
  assumptions <- eqalb_journey_case_assumptions(utility_no_event)
  list(
    tutorial_price = price,
    tutorial_rrr = assumptions$rrr_pct,
    tutorial_engagement_year1 = assumptions$engagement_year1_pct,
    tutorial_engagement_followup = assumptions$engagement_followup_pct,
    tutorial_utility_no_event = assumptions$utility_no_event
  )
}

# Plain-language reading of the base case, from the sign of R's own values. It
# states what the numbers mean and stops there: no affordability, readiness or
# evidence claim is made, and the threshold is not applied.
eqalb_journey_reading <- function(incremental_cost, incremental_qalys, icer) {
  if (is.na(incremental_cost) || is.na(incremental_qalys)) {
    return(list(
      code = "not_assessed",
      sentence = "The model could not produce a result for these assumptions."
    ))
  }
  if (incremental_qalys < 0) {
    return(list(
      code = "health_loss",
      sentence = paste0(
        "eQalb produces ",
        eqalb_tutorial_qalys(abs(incremental_qalys)),
        " fewer QALYs per person than usual care, so the ratio describes a ",
        "loss of health and cannot be read as a price per QALY."
      )
    ))
  }
  if (incremental_qalys == 0) {
    return(list(
      code = "no_health_gain",
      sentence = paste0(
        "eQalb adds no QALYs per person under these assumptions, so there is ",
        "no extra health to divide the extra cost by."
      )
    ))
  }
  if (incremental_cost == 0) {
    return(list(
      code = "same_cost_adds_health",
      sentence = paste0(
        "eQalb costs the same as usual care and adds ",
        eqalb_tutorial_qalys(incremental_qalys),
        " QALYs per person, so it is the better option at no extra cost."
      )
    ))
  }
  if (incremental_cost < 0) {
    return(list(
      code = "costs_less_adds_health",
      sentence = paste0(
        "eQalb costs ",
        eqalb_tutorial_money_signed(abs(incremental_cost)),
        " less per person than usual care and adds ",
        eqalb_tutorial_qalys(incremental_qalys),
        " QALYs, so it is the better option on both counts."
      )
    ))
  }
  list(
    code = "costs_more_adds_health",
    sentence = paste0(
      "eQalb costs ",
      eqalb_tutorial_money_signed(incremental_cost),
      " more per person than usual care and adds ",
      eqalb_tutorial_qalys(incremental_qalys),
      " QALYs, so each additional QALY costs ",
      eqalb_tutorial_money(icer),
      "."
    )
  )
}

# The sentences that carry a value, one per reveal, so a screen can show a single
# idea at a time. R writes the words and formats the numbers together; the
# interface prints the sentence it is given and decides nothing.
eqalb_journey_notes <- function(ce) {
  cost <- ce$incremental_cost
  qalys <- ce$incremental_qalys
  icer <- ce$icer

  cost_note <- if (cost > 0) {
    paste0(
      "eQalb costs ", eqalb_tutorial_money_signed(cost),
      " more per person than usual care."
    )
  } else if (cost < 0) {
    paste0(
      "eQalb costs ", eqalb_tutorial_money_signed(abs(cost)),
      " less per person than usual care."
    )
  } else {
    "eQalb costs the same as usual care."
  }

  health_note <- if (qalys > 0) {
    paste0(
      "It also adds ", eqalb_tutorial_qalys(qalys), " QALYs per person."
    )
  } else if (qalys < 0) {
    paste0(
      "It gives up ", eqalb_tutorial_qalys(abs(qalys)), " QALYs per person."
    )
  } else {
    "It adds no QALYs per person."
  }

  ratio_note <- if (qalys <= 0) {
    "With no extra health there is no price per QALY to read."
  } else if (cost < 0) {
    "It also costs less, so there is no price per QALY to pay."
  } else if (cost == 0) {
    "It adds health at no extra cost."
  } else if (!is.na(icer) && is.finite(icer)) {
    paste0(
      "One extra QALY costs ", eqalb_tutorial_money(icer), " per person."
    )
  } else {
    paste0("The ratio reads: ", EQALB_TUTORIAL_ICER_UNAVAILABLE, ".")
  }

  list(
    cost = cost_note,
    health = health_note,
    ratio = ratio_note
  )
}

# The base case for one price. A request carries only the price; a missing value
# takes R's default and an out-of-range value is rejected with R's own message.
eqalb_journey_base_case <- function(body = list()) {
  control <- eqalb_journey_price_control()
  price <- eqalb_tutorial_number(
    body,
    EQALB_JOURNEY_PRICE_ID,
    control$default,
    min = control$min,
    max = control$max
  )
  utility <- eqalb_journey_utility(body)

  ce <- eqalb_tutorial_ce(
    eqalb_journey_inputs(price, utility), eqalb_tutorial_fixed()
  )
  status_code <- eqalb_tutorial_ce_status(
    ce$incremental_cost, ce$incremental_qalys
  )

  list(
    # R's own rendering of the two levers, so the interface never formats a currency
    # or a score, and never has to decide whether its own value is the one the
    # answer describes.
    inputs = list(
      price = price,
      price_display = eqalb_tutorial_money(price),
      utility_no_event = utility,
      utility_display = eqalb_journey_utility_display(utility),
      utility_at_ceiling = eqalb_journey_utility_at_ceiling(utility)
    ),
    base_case = list(
      incremental_cost = ce$incremental_cost,
      incremental_qalys = ce$incremental_qalys,
      icer = ce$icer,
      icer_display = ce$icer_display,
      table = ce$table,
      chart = ce$chart,
      status = list(
        domain = "Cost-effectiveness",
        code = status_code,
        interpretation = eqalb_tutorial_status_text(
          "Cost-effectiveness", status_code
        )
      ),
      reading = eqalb_journey_reading(
        ce$incremental_cost, ce$incremental_qalys, ce$icer
      ),
      notes = eqalb_journey_notes(ce),
      # What the score on screen does to the result, in R's words, because it is the
      # one sentence that has to change with the learner's own input.
      utility_note = paste0(
        "At a score of ",
        eqalb_journey_utility_display(utility),
        " the model uses for a year without a prior cardiovascular event, eQalb adds ",
        eqalb_tutorial_qalys(ce$incremental_qalys),
        " QALYs per person."
      ),
      # The one score the uncertainty analysis cannot represent exactly. Null at
      # every other score, so the interface shows the sentence only when it applies.
      ceiling_note = if (eqalb_journey_utility_at_ceiling(utility)) {
        eqalb_journey_qaly_illustration()$ceiling_note
      } else {
        NULL
      }
    ),
    notice = eqalb_tutorial_notice()
  )
}

# --- Chapter 2: how certain is the comparison? ------------------------------

# How many repeats Chapter 2 draws, and the seed they use. Both belong to the
# journey: the learner does not set them, so the same seed always produces the
# same cloud and the chapter's own sentences can say how many repeats it is
# describing. The count is kept deliberately modest because every repeat is a full
# run of the model; 100 repeats show the shape of the spread, and the chapter says
# in its own words that the spread is not a complete account of uncertainty.
EQALB_JOURNEY_PSA_STUDIES <- 100L
EQALB_JOURNEY_PSA_SEED <- 20261022L

# A count, as the chapter's sentences read it.
eqalb_journey_count <- function(value) {
  format(
    as.integer(round(value)),
    big.mark = ",",
    scientific = FALSE,
    trim = TRUE
  )
}

# What the two sides of usual care look like, in words, from the counts R
# measured. The sentence states the counts and stops: which side a result falls on
# is a description of the results, not a recommendation, and no decision rule is
# applied to it. It also never says a result crossed the line unless R counted one
# that did.
eqalb_journey_uncertainty_sides_note <- function(sides) {
  total <- sides$total
  cheaper <- sides$cost_below
  no_health <- sides$health_no_gain

  if (cheaper == 0L && no_health == 0L) {
    return(paste0(
      "Here, all ", eqalb_journey_count(total),
      " results added health and cost more than usual care: none landed on the ",
      "other side."
    ))
  }
  if (no_health == 0L) {
    return(paste0(
      "In ", eqalb_journey_count(cheaper), " of the ",
      eqalb_journey_count(total), " results eQalb cost less than usual care; ",
      "in the other ", eqalb_journey_count(total - cheaper), " it cost more."
    ))
  }
  if (cheaper == 0L) {
    return(paste0(
      "In ", eqalb_journey_count(no_health), " of the ",
      eqalb_journey_count(total), " results eQalb added no health, so on those ",
      "it was no better than usual care."
    ))
  }
  paste0(
    "In ", eqalb_journey_count(cheaper), " of the ",
    eqalb_journey_count(total), " results eQalb cost less than usual care, and ",
    "in ", eqalb_journey_count(no_health), " it added no health."
  )
}

# The sentences that carry Chapter 2's values, one per state, written and
# formatted by R for the same reason Chapter 1's are: the interface prints what
# it is given. Each one describes the results; none of them evaluates them.
eqalb_journey_uncertainty_notes <- function(
  n_repeats,
  mean_cost,
  mean_qalys,
  cost_low,
  cost_high,
  sides
) {
  list(
    repeats = paste0(
      "Each dot repeats the comparison with several uncertain assumptions",
      " varying together. Here are ", eqalb_journey_count(n_repeats), " results."
    ),
    mean = paste0(
      "On average the dots add ",
      eqalb_tutorial_money_signed(mean_cost), " and ",
      eqalb_tutorial_qalys(mean_qalys), " QALYs per person."
    ),
    spread = paste0(
      "Extra cost ranged from ", eqalb_tutorial_money_signed(cost_low),
      " to ", eqalb_tutorial_money_signed(cost_high), " per person."
    ),
    sides = eqalb_journey_uncertainty_sides_note(sides)
  )
}

# Which assumptions the PSA actually varies, and which it holds fixed, read from
# the analysis's own parameter table and the one-way analysis's own range
# specifications. Nothing is typed twice: the nine sampled parameters and the ones
# the one-way analysis tests but the PSA does not are both derived, so the quiet
# disclosure under the chart cannot drift from what the simulation does.
#
# The two analyses use different uncertainty: the PSA draws from distributions, the
# one-way analysis moves each value to a tested low and high. This function reports
# only which parameters are in play, never that one is the other's range.
# The successful simulation rows, as the value-of-information chapter needs them: the
# two outcome columns the analysis always produces, plus every sampled parameter
# column it stored. The column list is read from the analysis's own parameter table,
# so a parameter the analysis samples cannot be missing from here, and a column it
# stops sampling cannot linger. The rows are returned exactly as the analysis built
# them; nothing is recomputed.
eqalb_journey_psa_draws <- function(results) {
  sampled <- psa_parameter_table()$model_argument
  columns <- c("simulation", "incremental_cost", "incremental_qalys")
  columns <- c(columns, sampled[sampled %in% names(results)])
  columns <- columns[columns %in% names(results)]
  lapply(seq_len(nrow(results)), function(index) {
    as.list(results[index, columns, drop = FALSE])
  })
}

eqalb_journey_psa_variation <- function(utility_no_event = NULL) {
  sampled <- psa_parameter_table()$model_argument
  specs <- eqalb_owsa_range_specs()
  labels <- eqalb_journey_sensitivity_plot_labels()
  varied <- specs$model_arg %in% sampled
  plot_label <- function(id) {
    if (!id %in% names(labels)) return(id)
    unname(labels[[id]])
  }
  varied_ids <- specs$id[varied]
  held_ids <- specs$id[!varied]
  list(
    varied_count = length(varied_ids),
    tested_count = nrow(specs),
    varied = lapply(varied_ids, plot_label),
    held = lapply(held_ids, plot_label),
    # The method's name, moved out of the panel: it was the state's note beside the
    # chart, and it is vocabulary rather than a value the learner has to read, so it
    # opens the disclosure instead. The word is the same one the analysis uses.
    method_sentence = paste(
      "Showing uncertainty this way is called probabilistic sensitivity analysis",
      "(PSA)."
    ),
    # One sentence for the disclosure, in the same plain voice as the chapter.
    varied_sentence = paste0(
      "The simulation varied ", eqalb_journey_count(length(varied_ids)), " of the ",
      eqalb_journey_count(nrow(specs)), " assumptions tested in the ", "previous chapter."
    ),
    held_sentence = if (length(held_ids) == 0L) {
      ""
    } else {
      paste0(
        "It held ", eqalb_journey_sensitivity_list(lapply(held_ids, plot_label)),
        " fixed."
      )
    },
    # What the disclosure says about the relationship between the two analyses, so
    # no caption has to claim it.
    ranges_sentence = paste(
      "The simulation draws each assumption from a distribution. Those draws are",
      "not the low and high values tested one at a time."
    ),
    # The one score the simulation cannot represent exactly. At every other score the
    # distribution's mean is the score and its spread is unchanged, so there is
    # nothing to disclose; at 1.00 the beta's own validity guard applies, and this
    # line states what that means rather than leaving it to be assumed.
    utility_sentence = if (is.null(utility_no_event) ||
      !eqalb_journey_utility_at_ceiling(utility_no_event)) {
      ""
    } else {
      paste(
        "The score of 1.00 is the one value the simulation cannot draw exactly:",
        "a beta distribution has to stay below 1, so the draws centre just under",
        "it and are narrower than at any other score. The model's own results use",
        "1.00 exactly."
      )
    }
  )
}

# The chapter's one expensive calculation. The repeats are produced by
# run_psa_eqalb(), the same function the analysis dashboard's probabilistic
# analysis uses, given this journey's own assumptions and the price the learner
# chose in Chapter 1. Nothing here draws a distribution or runs a model itself.
#
# The request carries the price and, when the learner has moved it, the no-event
# utility. Both are handed to the same two entry points the dashboard uses: the
# deterministic comparison and the simulation, so the point and the cloud around it
# are computed from one scenario. The utility enters as the mean of the existing beta
# for that parameter; no distribution or spread is invented here.
#
# The deterministic comparison is evaluated alongside the repeats so the point that
# stays on the graph while the cloud appears around it is the same value Chapter 1
# showed.
eqalb_journey_uncertainty <- function(body = list()) {
  control <- eqalb_journey_price_control()
  price <- eqalb_tutorial_number(
    body,
    EQALB_JOURNEY_PRICE_ID,
    control$default,
    min = control$min,
    max = control$max
  )
  utility <- eqalb_journey_utility(body)

  ce <- eqalb_tutorial_ce(
    eqalb_journey_inputs(price, utility), eqalb_tutorial_fixed()
  )

  assumptions <- eqalb_journey_case_assumptions(utility)
  psa <- run_psa_eqalb(
    n_sim = EQALB_JOURNEY_PSA_STUDIES,
    seed = EQALB_JOURNEY_PSA_SEED,
    # The chapter asks nothing about willingness to pay, so the curve the
    # analysis elsewhere uses is built over the smallest grid the model accepts
    # and is not published.
    max_wtp = 1000,
    wtp_thresholds = numeric(0),
    intervention_price = price,
    implementation = assumptions$implementation_cost,
    savings = assumptions$healthcare_savings,
    rrr = assumptions$rrr_pct / 100,
    engagement_year1 = assumptions$engagement_year1_pct / 100,
    engagement_followup = assumptions$engagement_followup_pct / 100,
    no_event_utility = assumptions$utility_no_event,
    post_mi_utility = assumptions$utility_post_mi,
    post_stroke_utility = assumptions$utility_post_stroke
  )

  results <- psa$results
  sides <- list(
    total = psa$n_successful,
    cost_below = sum(results$incremental_cost <= 0),
    health_no_gain = sum(results$incremental_qalys <= 0)
  )
  cost_low <- min(results$incremental_cost)
  cost_high <- max(results$incremental_cost)

  list(
    inputs = list(
      price = price,
      price_display = eqalb_tutorial_money(price),
      utility_no_event = utility,
      utility_display = eqalb_journey_utility_display(utility)
    ),
    uncertainty = list(
      n_repeats = psa$n_successful,
      seed = EQALB_JOURNEY_PSA_SEED,
      # One entry per repeat: the shape of the cloud is the whole point, so every
      # successful repeat is sent rather than a summary of them.
      cloud = lapply(seq_len(psa$n_successful), function(index) {
        list(
          cost = results$incremental_cost[index],
          qalys = results$incremental_qalys[index]
        )
      }),
      # The successful rows themselves, with the sampled parameter columns, so the
      # value-of-information chapter can value better evidence on exactly these
      # comparisons instead of simulating them a second time. They are the analysis's
      # own rows, unchanged: nothing is rounded, resampled or reconstructed, and the
      # price they were drawn at travels with them.
      draws = eqalb_journey_psa_draws(results),
      mean = list(
        incremental_cost = psa$mean_incremental_cost,
        incremental_qalys = psa$mean_incremental_qalys
      ),
      # The deterministic comparison at the same price, so the point the learner
      # already knows stays on the graph.
      base_case = list(
        incremental_cost = ce$incremental_cost,
        incremental_qalys = ce$incremental_qalys
      ),
      spread = list(
        cost_low = cost_low,
        cost_high = cost_high,
        qalys_low = min(results$incremental_qalys),
        qalys_high = max(results$incremental_qalys)
      ),
      sides = sides,
      # The quiet disclosure: which assumptions the simulation actually varied, and
      # which it held fixed. Derived from the analysis's own tables.
      variation = eqalb_journey_psa_variation(utility),
      notes = eqalb_journey_uncertainty_notes(
        psa$n_successful,
        psa$mean_incremental_cost,
        psa$mean_incremental_qalys,
        cost_low,
        cost_high,
        sides
      )
    ),
    notice = eqalb_tutorial_notice()
  )
}

# --- The one-at-a-time chapter ----------------------------------------------
#
# The base case moved a single assumption by moving the price. This chapter moves
# each assumption in turn, holding the rest at the learner's own base case, and
# ranks them twice: once by how far they move the extra cost per person, and once
# by how far they move the extra health. Both rankings come from run_eqalb_owsa(),
# the same one-way analysis the dashboard's sensitivity tab uses, with the ranges
# it derives from the scenario being analysed. Nothing here draws a range, invents
# a bound or runs a scenario itself.
#
# The two outcomes are kept apart on purpose. An assumption that does not move the
# cost is not therefore unimportant: it may move the health, and the second view is
# where that is read. Neither ranking is presented as overall importance, and no
# threshold, net monetary benefit or decision is computed or returned.

EQALB_JOURNEY_SENSITIVITY_CHAPTER_ID <- "sensitivity"

# The short names the ranked chart's category axis uses: the model's own parameters
# under a name that fits a bar's label column on a phone. The full name the
# analysis returns is published beside every row as well, so the short name is
# never the only description of a parameter.
eqalb_journey_sensitivity_plot_labels <- function() {
  c(
    intervention_price = "Annual price",
    implementation_cost = "Implementation cost",
    healthcare_savings = "Healthcare savings",
    rrr = "Risk reduction",
    engagement_year1 = "Year-1 engagement",
    engagement_followup = "Follow-up engagement",
    utility_no_event = "No-event utility",
    utility_post_mi = "Post-MI utility",
    utility_post_stroke = "Post-stroke utility",
    cost_post_mi = "Post-MI cost",
    cost_post_stroke = "Post-stroke cost",
    discount_rate_cost = "Cost discount rate",
    discount_rate_effect = "Effect discount rate",
    time_horizon = "Time horizon"
  )
}

# A name as it reads inside a sentence: unchanged when it starts with an acronym,
# otherwise lower-cased at its first letter.
eqalb_journey_sensitivity_mid <- function(label) {
  if (!nzchar(label)) return(label)
  paste0(tolower(substr(label, 1, 1)), substr(label, 2, nchar(label)))
}

# A list of names as one readable phrase: "A", "A and B", "A, B and C".
eqalb_journey_sensitivity_list <- function(values) {
  values <- unlist(values, use.names = FALSE)
  if (length(values) == 0L) return("")
  if (length(values) == 1L) return(values[[1]])
  paste0(
    paste(values[-length(values)], collapse = ", "),
    " and ",
    values[[length(values)]]
  )
}

# One tested input value as an annotation reads it: money in the model's own money
# string, shares as percentages, utilities as decimals, the horizon in years. The
# unit is read from R's own range specification, so an annotation cannot describe a
# value in a unit the analysis is not using.
eqalb_journey_sensitivity_input_display <- function(value, unit) {
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || !is.finite(value)) return("not available")
  if (identical(unit, "years")) {
    return(paste0(format(round(value), trim = TRUE, scientific = FALSE), " years"))
  }
  if (grepl("^EUR", unit)) return(eqalb_tutorial_money(value))
  if (grepl("^fraction", unit)) {
    return(paste0(format(round(value * 100, 2), trim = TRUE, scientific = FALSE), "%"))
  }
  format(round(value, 2), nsmall = 2, trim = TRUE)
}

# One outcome value as the same kind of string everywhere it is printed. Money is
# formatted with its sign ahead of the currency symbol, because an incremental cost
# can be a saving at the low end of the price range.
eqalb_journey_sensitivity_value_display <- function(value, value_kind) {
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || !is.finite(value)) return("not available")
  if (identical(value_kind, "money")) {
    return(paste0(if (value < 0) "-", eqalb_tutorial_money(abs(value))))
  }
  eqalb_tutorial_qalys(value)
}

eqalb_journey_sensitivity_units <- function() {
  specs <- eqalb_owsa_range_specs()
  stats::setNames(specs$unit, specs$id)
}

# One outcome's ranking, in the order the analysis returned it. Every row keeps the
# pair of tested inputs beside the pair of results they produced, so an interface
# never has to pair a bound with a value itself; `flat` marks a row the outcome did
# not respond to and `reversed` marks one whose second end ran the other way.
eqalb_journey_sensitivity_outcome <- function(result, kind) {
  table <- result$table
  labels <- eqalb_journey_sensitivity_plot_labels()
  units <- eqalb_journey_sensitivity_units()
  value_kind <- if (identical(kind, "cost")) "money" else "qalys"
  # A bar is flat when the two ends coincide. The tolerance is far below anything
  # the model reports, so it separates an exact non-response from a real one.
  tolerance <- if (identical(kind, "cost")) 1e-6 else 1e-12

  rows <- lapply(seq_len(nrow(table)), function(index) {
    id <- table$parameter_id[[index]]
    unit <- if (id %in% names(units)) unname(units[[id]]) else ""
    full_label <- table$parameter[[index]]
    low <- eqalb_owsa_number(table$selected_outcome_low[[index]])
    high <- eqalb_owsa_number(table$selected_outcome_high[[index]])
    impact <- eqalb_owsa_number(table$impact_range[[index]])
    available <- is.finite(low) && is.finite(high) && is.finite(impact)
    list(
      parameter_id = id,
      label = full_label,
      plot_label = if (id %in% names(labels)) unname(labels[[id]]) else full_label,
      available = available,
      flat = available && impact <= tolerance,
      reversed = available && low > high,
      low_input = eqalb_journey_sensitivity_input_display(table$low_value[[index]], unit),
      high_input = eqalb_journey_sensitivity_input_display(table$high_value[[index]], unit),
      low_outcome = if (available) low else NULL,
      high_outcome = if (available) high else NULL,
      impact = if (available) impact else NULL,
      low_display = eqalb_journey_sensitivity_value_display(low, value_kind),
      high_display = eqalb_journey_sensitivity_value_display(high, value_kind),
      impact_display = eqalb_journey_sensitivity_value_display(impact, value_kind)
    )
  })

  usable <- Filter(function(row) isTRUE(row$available), rows)
  unusable <- Filter(function(row) !isTRUE(row$available), rows)
  flat <- Filter(function(row) isTRUE(row$flat), usable)

  list(
    kind = kind,
    outcome = result$outcome,
    outcome_label = result$outcome_label,
    value_kind = value_kind,
    base_outcome = result$base_outcome,
    base_display = eqalb_journey_sensitivity_value_display(result$base_outcome, value_kind),
    rows = usable,
    unavailable = lapply(unusable, function(row) {
      list(parameter_id = row$parameter_id, label = row$label)
    }),
    tested = length(usable) + length(unusable),
    moving = length(usable) - length(flat),
    flat = length(flat),
    flat_labels = lapply(flat, function(row) row$plot_label),
    top = if (length(usable) > 0L) usable[[1]] else NULL,
    second = if (length(usable) > 1L) usable[[2]] else NULL
  )
}

# The first bar, explained before any ranking: one assumption, moved between the
# two values the analysis tested for it, with everything else left where it was.
eqalb_journey_sensitivity_one_bar_note <- function(outcome) {
  top <- outcome$top
  if (is.null(top)) {
    return("No assumption could be varied for this comparison.")
  }
  noun <- if (identical(outcome$kind, "cost")) "cost" else "health"
  paste0(
    "This bar shows how changing the ",
    eqalb_journey_sensitivity_mid(top$plot_label),
    " changes the extra ", noun, "."
  )
}

# What the two ends of that bar are. The noun follows the parameter actually
# ranked, so the sentence cannot call a price a value or the reverse.
eqalb_journey_sensitivity_ends_note <- function(outcome) {
  top <- outcome$top
  if (is.null(top)) return("The bar connects the results at the two tested values.")
  noun <- if (identical(top$parameter_id, "intervention_price")) "prices" else "values"
  paste0("The bar connects the results at the two tested ", noun, ".")
}

# The full ranking, described from its own counts: how many assumptions move the
# extra cost, which one moves it furthest, and - only when the analysis found such a
# row - that some bars run the other way. The bars carry their own numbers, so the
# sentence does not repeat them or inventory the parameters.
eqalb_journey_sensitivity_ranking_note <- function(outcome) {
  noun <- if (identical(outcome$kind, "cost")) "cost" else "health"
  top <- outcome$top
  leader <- if (is.null(top)) {
    ""
  } else {
    paste0(" The longest bar is the ", eqalb_journey_sensitivity_mid(top$plot_label), ".")
  }
  reversed <- Filter(function(row) isTRUE(row$reversed) && !isTRUE(row$flat), outcome$rows)
  other_way <- if (length(reversed) == 0L) {
    ""
  } else {
    " Some bars run the other way: a higher input gives a lower result."
  }
  held <- if (length(outcome$unavailable) > 0L) {
    paste0(
      " ", eqalb_journey_count(length(outcome$unavailable)),
      " assumptions could not be varied here and are not ranked."
    )
  } else {
    ""
  }
  paste0(
    eqalb_journey_count(outcome$moving), " assumptions move the extra ", noun,
    " and ", eqalb_journey_count(outcome$flat), " leave it unchanged.",
    leader, other_way, held
  )
}

# The assumptions the selected outcome did not respond to, counted rather than
# listed: the shaded bars show which ones, and a flat bar is described as what it is
# - no response in this outcome - never as an assumption that does not matter.
eqalb_journey_sensitivity_flat_note <- function(outcome) {
  noun <- if (identical(outcome$kind, "cost")) "cost" else "health"
  if (outcome$flat == 0L) {
    return(paste0("Every assumption tested moved the extra ", noun, "."))
  }
  paste0(
    eqalb_journey_count(outcome$flat), " assumptions leave the extra ", noun,
    " unchanged, because they change ",
    if (identical(outcome$kind, "cost")) "health" else "cost",
    " rather than ", noun, "."
  )
}

# The health ranking, described from its own order: which assumption now moves
# furthest, and how many assumptions the health did not respond to. The scale itself
# is on the axis, so no endpoint number is repeated here.
eqalb_journey_sensitivity_health_note <- function(outcome) {
  top <- outcome$top
  if (is.null(top)) {
    return("The extra health could not be ranked for this comparison.")
  }
  paste0(
    "Ranked by extra health, the ",
    eqalb_journey_sensitivity_mid(top$plot_label),
    " moves furthest. ", eqalb_journey_count(outcome$flat),
    " assumptions leave the extra health unchanged."
  )
}

# The one-at-a-time chapter's copy. Six states of one panel: a single bar, its two
# ends, the ranked cost chart, the assumptions that chart did not respond to, the
# same chart ranked by health, and what the order depends on, which is also where
# the chapter hands over to uncertainty.
#
# Each caption names the assumption in play and its consequence, and points at the
# feature that shows it; the bars carry the numbers, and the one number-bearing
# sentence arrives with the result beneath the chart. No state lists the whole
# parameter set.
eqalb_journey_sensitivity_copy <- function() {
  list(
    title = eqalb_journey_chapter_title("sensitivity"),
    stages = list(
      list(
        id = "cost_bar",
        caption = paste(
          "Move one assumption on its own, and its bar shows what that does to",
          "the extra cost."
        ),
        focus = "bar_top",
        note_key = "one_bar",
        view = "cost",
        reveal = "top",
        advance_label = "Show the two ends of the bar"
      ),
      list(
        id = "cost_ends",
        caption = "The bar connects the results at the two tested prices.",
        focus = "bar_ends",
        note_key = "ends",
        view = "cost",
        reveal = "top",
        ends = TRUE,
        advance_label = "Show every assumption"
      ),
      list(
        id = "cost_ranking",
        caption = paste(
          "Every assumption moved alone, on the same scale. The longer the bar,",
          "the more it changes the extra cost."
        ),
        focus = "none",
        note_key = "ranking",
        view = "cost",
        reveal = "all",
        advance_label = "What did not move"
      ),
      list(
        id = "cost_flat",
        caption = paste(
          "Some assumptions change health, so they leave the extra cost exactly",
          "where it was."
        ),
        focus = "flat",
        note_key = "flat",
        view = "cost",
        reveal = "all",
        advance_label = "Rank the health side"
      ),
      list(
        id = "health_ranking",
        caption = paste(
          "Ranked by extra health instead, other assumptions take the lead.",
          "Health and cost are not sensitive to the same things."
        ),
        focus = "none",
        note_key = "health",
        view = "health",
        reveal = "all",
        advance_label = "What the order depends on"
      ),
      list(
        id = "ranges",
        caption = "The order holds only for the outcome and the ranges tested.",
        focus = "none",
        view = "health",
        reveal = "all",
        # The chapter ends by opening the bridge into uncertainty.
        advance_label = "Go on to uncertainty"
      )
    ),
    advance_label = "Next part of the comparison"
  )
}

# The labels the ranked chart itself draws. The axis names restate the outcome and
# its unit for each view, so a bar is never read without knowing what it measures.
eqalb_journey_sensitivity_graph <- function() {
  list(
    cost_axis_label = "Extra cost (EUR per person)",
    health_axis_label = "Extra QALYs per person",
    reference_label = "This comparison",
    low_end_label = "Lowest tested",
    high_end_label = "Highest tested"
  )
}

# The chapter's quiet disclosure. Its three sentences used to sit beside the bars as
# the state's own note; they are secondary explanation - the method's name, what a
# flat bar means, and what a long bar does not mean - so they live here, where a
# learner who wants them can read them, and the caption beside the chart stays the
# teaching sentence. Nothing is reworded: these are the sentences the states used to
# carry, moved rather than rewritten.
eqalb_journey_sensitivity_disclosure <- function() {
  list(
    title = "What this ranking does and does not show",
    lines = list(
      "Changing one assumption at a time is called one-way sensitivity analysis.",
      paste(
        "A flat bar does not mean an assumption is unimportant: it means this",
        "outcome does not respond to it."
      ),
      paste(
        "A long bar shows where this answer is sensitive, not where better evidence",
        "would be most valuable."
      )
    )
  )
}

# The chapter's one expensive calculation, and the same analysis run twice: once
# ranked by incremental cost and once by incremental QALYs. Both calls are the
# existing one-way analysis, unchanged, given the learner's price and the ranges R
# derives from that scenario. The willingness-to-pay value the shared function
# requires is passed so the analysis can run; it is not used by either ranking and
# is not returned, because no threshold or net-benefit quantity belongs to this
# chapter.
eqalb_journey_sensitivity <- function(body = list()) {
  control <- eqalb_journey_price_control()
  price <- eqalb_tutorial_number(
    body,
    EQALB_JOURNEY_PRICE_ID,
    control$default,
    min = control$min,
    max = control$max
  )
  utility <- eqalb_journey_utility(body)

  # The learner's two levers are the scenario analysed; the rest are the case's own
  # values, so the ranges are the ones this scenario implies rather than the ones the
  # model's own defaults would.
  args <- eqalb_owsa_base_args()
  args$scenario_intervention_price <- price
  args$scenario_utility_no_event <- utility
  bounds <- eqalb_owsa_range_bounds(args)

  cost_result <- run_eqalb_owsa(
    base_args = args,
    bounds = bounds,
    wtp = EQALB_JOURNEY_THRESHOLD_PER_QALY,
    outcome = "incremental_cost"
  )
  health_result <- run_eqalb_owsa(
    base_args = args,
    bounds = bounds,
    wtp = EQALB_JOURNEY_THRESHOLD_PER_QALY,
    outcome = "incremental_qalys"
  )

  cost <- eqalb_journey_sensitivity_outcome(cost_result, "cost")
  health <- eqalb_journey_sensitivity_outcome(health_result, "health")

  list(
    inputs = list(
      price = price,
      price_display = eqalb_tutorial_money(price),
      utility_no_event = utility,
      utility_display = eqalb_journey_utility_display(utility)
    ),
    sensitivity = list(
      outcomes = list(cost = cost, health = health),
      # The sentences that carry the chapter's values, one per state that names a
      # number. The ranking's own sentence also carries the reversed-direction
      # explanation, because that is the state in which the bar it describes is on
      # screen.
      notes = list(
        one_bar = eqalb_journey_sensitivity_one_bar_note(cost),
        ends = eqalb_journey_sensitivity_ends_note(cost),
        ranking = eqalb_journey_sensitivity_ranking_note(cost),
        flat = eqalb_journey_sensitivity_flat_note(cost),
        health = eqalb_journey_sensitivity_health_note(health)
      ),
      notice = eqalb_tutorial_notice()
    ),
    notice = eqalb_tutorial_notice()
  )
}

# --- Chapter 4: what would better evidence be worth? -------------------------
#
# The chapter values better information on the repeats the learner has already been
# shown. It runs no model and no simulation: the rows Chapter 2 produced are posted
# back unchanged and handed to voi_evpi() and voi_evppi(), the same two functions the
# analysis dashboard's value-of-information tab uses. Nothing is regenerated from the
# seed and nothing is imputed, so the value is attached to the comparisons the
# learner actually saw at the price they chose.
#
# Both figures are per person over the model's own horizon and both are values of
# information, not values of eQalb. EVPI is one figure for the included uncertainty
# as a whole; each EVPPI row is the value of resolving one assumption on its own, so
# the rows are neither shares of EVPI nor additive. The eligible population is never
# multiplied in: population-level value would need assumptions this chapter does not
# make.

# The chapter's short names for the sampled parameters, keyed by the model argument
# the analysis draws. The analysis's long names stay on each row as well, so a
# parameter cannot be renamed by the chapter.
eqalb_journey_voi_plot_labels <- function() {
  list(
    scenario_rrr = "Relative risk reduction",
    scenario_engagement_year1 = "Year-1 engagement",
    scenario_engagement_followup = "Follow-up engagement",
    scenario_utility_no_event = "Utility: no event",
    scenario_utility_post_mi = "Utility: post-MI",
    scenario_utility_post_stroke = "Utility: post-stroke",
    scenario_intervention_price = "Annual price",
    scenario_implementation_cost = "Implementation cost",
    scenario_healthcare_savings = "Healthcare savings"
  )
}

# The reference value as the chapter names it: whole euros, because it is a round
# teaching figure and its cents carry no meaning.
eqalb_journey_voi_threshold_display <- function(threshold) {
  paste0(
    "\u20ac",
    format(round(threshold), big.mark = ",", scientific = FALSE, trim = TRUE),
    " per QALY"
  )
}

# What the reference does, said before it is used to say which option is preferred.
# The chapter's one sentence per state. Most states need no result to be worded, so
# the caption is the sentence the learner reads; the first state names the option the
# evidence favours, so its response sentence replaces this fallback once R has
# answered. Short on purpose: the figure carries the comparison, and the words say
# what to look for.
eqalb_journey_voi_captions <- function() {
  list(
    choice_now = paste(
      "With today's evidence, we would choose the option with the better average",
      "balance."
    ),
    choice_resolved = "Imagine knowing the uncertain inputs before choosing.",
    evpi = "How much better could that make the decision?",
    evppi = "Which assumption would be most useful to learn about?",
    # The dash is the en-dash character, so the sentence reads as one aside rather
    # than two claims.
    limits = paste0(
      "These are approximate values per person\u2014not the payoff from a particular",
      " study."
    ),
    opens_next = "What changes if the price changes instead?"
  )
}

eqalb_journey_voi_reference_note <- function(threshold_display) {
  paste0(
    "Health and cost are combined using this case's reference of ",
    threshold_display,
    ": its own teaching value, not an official payer rule. Net benefit values health",
    " in money at that reference; it is not cash saved."
  )
}

# Why the first bar has the height it has, in R's own values. The sentence names the
# option the evidence favours, which is only ever said of the option R's own mean
# balance puts ahead. When usual care is ahead the bar is exactly zero - usual care's
# net benefit is the axis's own zero - and the sentence says so rather than leaving an
# unexplained gap at the bottom of the chart.
eqalb_journey_voi_choose_now_note <- function(evpi) {
  tolerance <- 1e-6
  if (is.na(evpi$mean_nmb)) {
    return(paste(
      "With today's evidence, the average balance could not be compared here."
    ))
  }
  if (evpi$mean_nmb > tolerance) {
    return(paste0(
      "With today's evidence, we would choose eQalb: ",
      voi_format_euros(evpi$expected_nmb_current),
      " per person better than usual care."
    ))
  }
  if (evpi$mean_nmb < -tolerance) {
    return(paste(
      "With today's evidence, we would choose usual care: choosing it adds nothing",
      "over usual care, so the axis starts there."
    ))
  }
  "With today's evidence, the two options are close to equal."
}

# The imagined choice, said as a conditional rather than as a result: this figure
# is what the balance would be if the uncertain inputs were already known, and the
# sentence names the quantity R's own perfect-information value measures.
eqalb_journey_voi_resolved_note <- function(evpi) {
  paste0(
    "If we knew the uncertain inputs before choosing, the expected net benefit",
    " would be ",
    voi_format_euros(evpi$expected_nmb_perfect),
    " per person."
  )
}

# Why the value is what it is. A value of zero is reported with its reason rather than
# as a bare zero: when every comparison falls the same way, settling the assumptions
# could not change the choice, and the sentence says which way the comparisons fell
# and that this is a statement about this reference, not about evidence in general.
eqalb_journey_voi_evpi_note <- function(evpi) {
  tolerance <- 1e-6
  if (!is.finite(evpi$evpi)) {
    return("The expected gain could not be estimated here.")
  }
  if (evpi$evpi > tolerance) {
    return(paste0(
      "The expected gain is ",
      voi_format_euros(evpi$evpi),
      " per person."
    ))
  }
  # Every draw fell the same way when the expected value with perfect information
  # equals either the mean or nothing at all.
  all_usual_care <- isTRUE(evpi$expected_nmb_perfect <= tolerance) &&
    isTRUE(evpi$mean_nmb < -tolerance)
  all_eqalb <- isTRUE(evpi$mean_nmb > tolerance) &&
    abs(evpi$expected_nmb_perfect - evpi$mean_nmb) <= tolerance
  reason <- if (all_usual_care) {
    paste(
      "every simulated comparison favoured usual care, so the estimate is",
      "exactly zero"
    )
  } else if (all_eqalb) {
    paste(
      "every simulated comparison favoured eQalb, so the estimate is exactly zero"
    )
  } else {
    "resolving them would not change the choice on average, so the estimate is exactly zero"
  }
  paste0(
    "The expected gain is ",
    voi_format_euros(evpi$evpi),
    " per person: ",
    reason,
    ". That is a statement about this reference and these simulated comparisons,",
    " not about evidence in general."
  )
}

# The largest row is named only when it actually carries a value. When every row is
# zero, naming one would anoint an arbitrary leader.
eqalb_journey_voi_evppi_note <- function(evppi, rows) {
  if (!isTRUE(evppi$available)) {
    return(as.character(evppi$reason))
  }
  if (length(rows) == 0L) {
    return("No assumption could be valued on its own with these comparisons.")
  }
  if (isTRUE(rows[[1]]$value <= 1e-6)) {
    return(paste(
      "Here none of them carries a measurable value on its own: at this reference",
      "resolving any one of these assumptions would not change the choice."
    ))
  }
  paste0(
    "The largest is ",
    rows[[1]]$plot_label,
    ", at ",
    rows[[1]]$value_display,
    " per person."
  )
}

# The limits, from the analysis's own counts. A row that came back exactly zero is
# described as no estimated extra decision value for that assumption alone - never as
# the technology having no value, and never as research being worthless - and a
# positive estimate too small to print is described as small rather than as zero.
eqalb_journey_voi_limits_note <- function(evpi, evppi, rows) {
  parts <- character(0)
  if (!isTRUE(evppi$available)) {
    parts <- c(parts, as.character(evppi$reason))
  } else {
    parts <- c(parts, paste0(
      "They come from ",
      eqalb_journey_count(evpi$n),
      " simulated comparisons at one reference value, and they are not parts of the",
      " first figure: they do not add up to it."
    ))
    zero <- sum(vapply(rows, function(row) isTRUE(row$zero), logical(1)))
    small <- sum(vapply(rows, function(row) isTRUE(row$small), logical(1)))
    total <- length(rows)
    if (zero > 0L) {
      parts <- c(parts, if (identical(zero, total)) {
        paste(
          "Every one is exactly zero: resolving that assumption alone would not",
          "change the choice."
        )
      } else if (zero == 1L) {
        paste(
          "One is exactly zero: resolving that assumption alone would not change",
          "the choice."
        )
      } else {
        paste0(
          eqalb_journey_count(zero),
          " of them are exactly zero: resolving that assumption alone would not",
          " change the choice."
        )
      })
    }
    if (small > 0L) {
      parts <- c(parts, if (small == 1L) {
        paste0(
          "One more is above zero but rounds to ",
          voi_format_euros(0),
          " per person, so it is a small estimate rather than an exact zero."
        )
      } else {
        paste0(
          eqalb_journey_count(small),
          " more are above zero but round to ",
          voi_format_euros(0),
          " per person, so they are small estimates rather than exact zeros."
        )
      })
    }
    if (isTRUE(evppi$exceeds)) {
      parts <- c(parts, paste(
        "Some single estimates are larger than the first figure, which this",
        "approximation can produce; they are not shares of it."
      ))
    }
    if (isTRUE(evppi$any_clamped)) {
      parts <- c(parts, paste(
        "Estimates that rounding pushed slightly below zero were set to zero."
      ))
    }
  }
  paste(parts, collapse = " ")
}

# The quiet disclosure: scope and the population question, in R's words, so no
# caption has to carry them. The qualifications of the two measures live here too -
# what the imagined certainty includes, that the EVPI figure is an upper limit and the
# gap rather than a bar, and that each EVPPI bar leaves the others uncertain - because
# each is a limit rather than the definition itself. The short definitions of EVPI and
# EVPPI stay on the screens that introduce them, so a learner never has to open this
# to know what the figure in front of them is called.
eqalb_journey_voi_disclosure <- function() {
  list(
    title = "What these figures cover",
    lines = list(
      paste0(
        "Every figure is per person, over the model's ",
        eqalb_journey_horizon_years(),
        " years. That is the model's outcome horizon, not a research horizon: it",
        " says nothing about how long a study would take or how long its answer",
        " would stay useful."
      ),
      paste(
        "The value of better evidence across the whole eligible population is not",
        "calculated here. It would need additional assumptions about how widely the",
        "answer would be used."
      ),
      paste(
        "Knowing the uncertain assumptions exactly is only the uncertainty included",
        "in this model, not everything about the real world."
      ),
      paste(
        "The EVPI figure is an upper limit, not the benefit of a particular study:",
        "it is the gap between the two bars, not the height of either."
      ),
      paste(
        "Each EVPPI bar leaves the other assumptions uncertain, so the bars are",
        "separate questions rather than shares of the EVPI."
      )
    )
  )
}

# The chapter's copy. Six states: the choice made today, the same choice with the
# model's parameter uncertainty resolved, the gap between them, the value of
# resolving one assumption at a time, the limits, and the question the pricing
# chapter will answer.
#
# The reference value arrives in the first state, before any state uses it to say
# which option is preferred. The two gap states are a comparison of choices, not a
# claim about the technology: nothing here says eQalb is worth its price, that any
# research project is worth funding, or that better evidence would change the
# decision.
eqalb_journey_voi_copy <- function() {
  captions <- eqalb_journey_voi_captions()
  list(
    title = eqalb_journey_chapter_title("voi"),
    stages = list(
      list(
        id = "choice_now",
        caption = captions$choice_now,
        focus = "choice_now",
        note_key = "choose_now",
        reveal = "now",
        # The reference, before it is used for anything.
        aside = eqalb_journey_voi_reference_note(
          eqalb_journey_voi_threshold_display(EQALB_JOURNEY_THRESHOLD_PER_QALY)
        ),
        advance_label = "Imagine knowing the answer"
      ),
      list(
        id = "choice_resolved",
        caption = captions$choice_resolved,
        focus = "choice_resolved",
        note_key = "resolved",
        reveal = "both",
        advance_label = "Show the gap"
      ),
      list(
        id = "evpi",
        caption = captions$evpi,
        focus = "evpi_gap",
        note_key = "evpi",
        reveal = "gap",
        # The definition, kept visible on the screen that introduces the idea: a learner
        # should not have to open a disclosure to know what the figure is called. The
        # qualifications that go with it are in "What these figures cover".
        aside = paste(
          "EVPI is what it would be worth to know every uncertain assumption exactly."
        ),
        advance_label = "Resolve one assumption instead"
      ),
      list(
        id = "evppi",
        caption = captions$evppi,
        focus = "evppi_bars",
        note_key = "evppi",
        reveal = "evppi",
        # The same rule: the short definition is visible here, where the bars first
        # appear, and the detail stays in the disclosure.
        aside = paste(
          "EVPPI asks that question for one assumption at a time."
        ),
        advance_label = "What these figures leave out"
      ),
      list(
        id = "limits",
        caption = captions$limits,
        focus = "none",
        note_key = "limits",
        reveal = "evppi",
        advance_label = "Go on to price"
      ),
      # The journey's temporary end: the question the pricing chapter will answer.
      # It carries no advance control, because nothing follows it yet, and it is not
      # a completion screen. It does not claim a different price would settle the
      # uncertainty.
      list(
        id = "opens_next",
        caption = captions$opens_next,
        focus = "none",
        reveal = "evppi"
      )
    ),
    advance_label = "Next part of the comparison"
  )
}

# The labels the chapter's two panels draw. The two choice bars share one axis, and
# the EVPPI bars have their own, so a bar in the lower panel is never read against
# the upper panel's scale.
eqalb_journey_voi_graph <- function() {
  list(
    axis_label = "Net benefit relative to usual care (EUR per person)",
    evppi_axis_label = "Value of resolving one assumption (EUR per person)",
    now_label = "Choose with what we know",
    perfect_label = "Choose knowing the answer",
    gap_label = "Value of better information",
    evppi_title = "One assumption at a time"
  )
}

# The chapter's calculation. It performs none: both value-of-information functions
# are handed the rows the client posted, which are the rows Chapter 2 returned for
# this price. The threshold is the reference R publishes; accepting it in the body
# lets the client echo exactly the value it was shown instead of holding one of its
# own.
eqalb_journey_voi <- function(body = list()) {
  control <- eqalb_journey_price_control()
  price <- eqalb_tutorial_number(
    body,
    EQALB_JOURNEY_PRICE_ID,
    control$default,
    min = control$min,
    max = control$max
  )
  threshold <- eqalb_tutorial_number(
    body,
    "threshold",
    EQALB_JOURNEY_THRESHOLD_PER_QALY,
    min = 0
  )

  # The rows Chapter 2 returned for this price, posted back unchanged and validated by
  # the request layer with the same helper every value-of-information request uses, so
  # rows missing a required column fail with the analysis's own message rather than
  # producing a number from data that was not supplied. This module only checks that
  # it was handed the validated frame.
  draws <- body[["results"]]
  if (!is.data.frame(draws) || nrow(draws) == 0L) {
    stop(
      "The request body must contain the `results` data frame of a completed PSA.",
      call. = FALSE
    )
  }

  evpi <- voi_evpi(draws, wtp = threshold)
  evppi <- voi_evppi(draws, wtp = threshold)

  labels <- eqalb_journey_voi_plot_labels()
  rows <- if (isTRUE(evppi$available)) {
    lapply(seq_len(nrow(evppi$table)), function(index) {
      argument <- evppi$table$model_argument[index]
      label <- evppi$table$parameter[index]
      value <- evppi$table$evppi[index]
      list(
        parameter_id = argument,
        label = label,
        plot_label = if (argument %in% names(labels)) {
          unname(labels[[argument]])
        } else {
          label
        },
        value = value,
        value_display = voi_format_euros(value),
        # Exactly zero and too small to print are different findings, and the
        # chapter says so in different words.
        zero = is.finite(value) && value <= 0,
        small = is.finite(value) && value > 0 && round(value, 2) == 0
      )
    })
  } else {
    list()
  }

  # The two axes, padded so no bar touches the frame and a state that reveals a bar
  # never rescales the one already drawn.
  pad <- function(value) if (value > 0) value * 1.18 else 1
  evppi_max <- if (length(rows) > 0L) {
    max(vapply(rows, function(row) row$value, numeric(1)), na.rm = TRUE)
  } else {
    0
  }

  list(
    inputs = list(
      price = price,
      price_display = eqalb_tutorial_money(price),
      threshold = threshold,
      threshold_display = eqalb_journey_voi_threshold_display(threshold)
    ),
    voi = list(
      n = evpi$n,
      rows_posted = nrow(draws),
      threshold = threshold,
      threshold_display = eqalb_journey_voi_threshold_display(threshold),
      evpi = list(
        per_person = evpi$evpi,
        display = voi_format_euros(evpi$evpi),
        # The two bars: what choosing on today's information is worth relative to
        # usual care, and what choosing with the included uncertainty resolved would
        # be worth. Usual care's net benefit is the axis's zero.
        choose_now = evpi$expected_nmb_current,
        choose_now_display = voi_format_euros(evpi$expected_nmb_current),
        perfect = evpi$expected_nmb_perfect,
        perfect_display = voi_format_euros(evpi$expected_nmb_perfect),
        mean_nmb = evpi$mean_nmb,
        preferred = if (is.na(evpi$mean_nmb)) {
          ""
        } else if (evpi$mean_nmb > 1e-6) {
          "eQalb"
        } else if (evpi$mean_nmb < -1e-6) {
          "usual care"
        } else {
          ""
        }
      ),
      evppi = list(
        available = isTRUE(evppi$available),
        reason = if (isTRUE(evppi$available)) "" else as.character(evppi$reason),
        rows = rows,
        largest = if (length(rows) > 0L) rows[[1]] else NULL,
        zero = sum(vapply(rows, function(row) isTRUE(row$zero), logical(1))),
        small = sum(vapply(rows, function(row) isTRUE(row$small), logical(1))),
        clamped = isTRUE(evppi$any_clamped),
        exceeds = isTRUE(evppi$exceeds)
      ),
      axis = list(
        max = pad(evpi$expected_nmb_perfect),
        evppi_max = pad(evppi_max)
      ),
      disclosure = eqalb_journey_voi_disclosure(),
      notes = list(
        reference = eqalb_journey_voi_reference_note(
          eqalb_journey_voi_threshold_display(threshold)
        ),
        choose_now = eqalb_journey_voi_choose_now_note(evpi),
        resolved = eqalb_journey_voi_resolved_note(evpi),
        evpi = eqalb_journey_voi_evpi_note(evpi),
        evppi = eqalb_journey_voi_evppi_note(evppi, rows),
        limits = eqalb_journey_voi_limits_note(evpi, evppi, rows)
      )
    ),
    notice = eqalb_tutorial_notice()
  )
}

# --- The price chapter --------------------------------------------------------
#
# The fifth chapter asks a different question from the fourth: not whether the
# balance is certain, but where the price has to sit for the balance to hold. It
# draws two scales side by side and never mixes them - an annual price track with
# the manufacturer's proposal, the learner's price and the price R solves for, and a
# separate net-benefit display with its own zero that carries negative and positive
# values.
#
# Nothing here is a new calculation. The balance is eqalb_price_run() and
# eqalb_price_nmb(), the price is eqalb_price_solve(), and every amount is one of
# the price module's own formatters. This module assembles the arguments from the
# same fixed assumptions the base case uses, then re-presents what those functions
# return.

# Every input the price solve depends on, as one opaque string. The client compares
# it to decide whether a solve it is holding still describes this case and this
# reference; it never parses it. Composing it here rather than in TypeScript keeps
# the list of inputs R's own.
eqalb_journey_price_scenario_key <- function(utility_no_event = NULL) {
  assumptions <- eqalb_journey_case_assumptions(utility_no_event)
  values <- vapply(
    names(assumptions),
    function(name) {
      value <- assumptions[[name]]
      if (is.character(value)) {
        paste0("s:", value)
      } else {
        format(as.numeric(value), digits = 15)
      }
    },
    character(1)
  )
  paste0(
    EQALB_JOURNEY_CASE_ID,
    "|v", EQALB_JOURNEY_CASE_VERSION,
    "|wtp=", format(EQALB_JOURNEY_THRESHOLD_PER_QALY, scientific = FALSE),
    "|", paste(paste0(names(values), "=", values), collapse = ",")
  )
}

# The model's argument list for this case at one price and one score. It passes the
# same nine assumptions eqalb_tutorial_ce() passes, so a balance computed here and a
# base case computed for the same price and score are the same model run.
eqalb_journey_price_model_args <- function(price, utility_no_event = NULL) {
  assumptions <- eqalb_journey_case_assumptions(utility_no_event)
  list(
    scenario_intervention_price = price,
    scenario_implementation_cost = assumptions$implementation_cost,
    scenario_healthcare_savings = assumptions$healthcare_savings,
    scenario_rrr = assumptions$rrr_pct / 100,
    scenario_engagement_year1 = assumptions$engagement_year1_pct / 100,
    scenario_engagement_followup = assumptions$engagement_followup_pct / 100,
    scenario_utility_no_event = assumptions$utility_no_event,
    scenario_utility_post_mi = assumptions$utility_post_mi,
    scenario_utility_post_stroke = assumptions$utility_post_stroke
  )
}

# The price track's own ticks: whole hundreds inside the lever's range, so the track
# reads as a scale without the endpoints crowding its own labels.
eqalb_journey_price_ticks <- function(control) {
  first <- ceiling(control$min / 100) * 100
  last <- floor(control$max / 100) * 100
  if (last < first) return(list())
  values <- seq(first, last, by = 100)
  lapply(values, function(value) {
    list(value = as.numeric(value), display = eqalb_price_format_money(value))
  })
}

# The labels the chapter's two displays draw. The two are separate scales, and each
# says what it measures and in which unit, so a learner never reads the balance off
# the price axis.
eqalb_journey_price_graph <- function() {
  list(
    track_label = "Annual price (EUR per person per year)",
    proposal_label = "Proposed price",
    learner_label = "The price you choose",
    solved_label = "Balance reaches zero",
    balance_title = "Balance at that price",
    balance_label = "Net benefit relative to usual care (EUR per person)",
    zero_label = "Usual care"
  )
}

# The chapter's states. Every sentence is short and points at something the figure
# draws: the proposal marker, the balance bar, the price the learner chose, the
# crossing. The two sentences that carry an amount are `note_key`s, so R's calculated
# sentence replaces the fallback the moment the answer exists.
#
# There is no price control in this chapter. The price was chosen in the base case and
# is the one price the whole journey uses, so this chapter's figure places it on a
# track beside the proposal and beside the price at which the balance reaches zero.
eqalb_journey_price_copy <- function() {
  control <- eqalb_journey_price_control()
  # The proposal is priced in the brief's own unit, so the two screens cannot
  # describe the same price differently.
  unit <- eqalb_journey_case()$price_unit
  proposed <- eqalb_price_format_money(control$default)
  list(
    title = eqalb_journey_chapter_title("price"),
    stages = list(
      list(
        id = "proposal",
        # The proposal is a fixed fact about the case, so its sentence is complete
        # before any calculation runs.
        caption = paste0(
          "The manufacturer proposes ",
          proposed,
          " ",
          unit,
          "."
        ),
        focus = "price_proposal",
        reveal = "track",
        advance_label = "Where your price sits"
      ),
      list(
        id = "learner",
        caption = "Your price is the one you chose in the first chapter.",
        focus = "price_learner",
        reveal = "track",
        note_key = "learner",
        advance_label = "The balance at your price"
      ),
      list(
        id = "move",
        # Kept under its own id because the chapter's figure reveals the balance
        # here; what has gone is the slider, not the state.
        caption = "At your price, the balance is the bar below.",
        focus = "balance_bar",
        reveal = "balance",
        note_key = "balance",
        advance_label = "Where the balance reaches zero"
      ),
      list(
        id = "crossover",
        caption = "Where does the balance reach zero?",
        focus = "price_solved",
        reveal = "full",
        note_key = "crossover",
        advance_label = "What this leaves out"
      ),
      list(
        id = "scope",
        caption = "Changing the price changes the balance, not the uncertainty.",
        focus = "none",
        reveal = "full",
        advance_label = "Go on to the budget"
      ),
      # The question the budget chapter answers. It is no longer the end of the
      # journey, so it carries the label of the control that opens that chapter's
      # bridge.
      list(
        id = "opens_next",
        caption = paste(
          "A price per person is not a budget. What would adoption cost in total?"
        ),
        focus = "none",
        reveal = "full",
        advance_label = "Show what adoption would cost"
      )
    ),
    advance_label = "Next part of the comparison"
  )
}

# The balance at one price, said with the price it belongs to so a moved slider can
# never leave a sentence about another price on screen. The two units are kept
# distinct: the price is a rate per person per year, and the balance is a total per
# person over the model's horizon.
eqalb_journey_price_balance_note <- function(price, nmb, threshold_display, unit,
                                             horizon_years) {
  paste0(
    "At ",
    eqalb_price_format_money(price),
    " ",
    unit,
    " the balance is ",
    eqalb_price_format_money_signed(nmb),
    " per person over the model's ",
    horizon_years,
    " years, at this case's ",
    threshold_display,
    "."
  )
}

# The learner's own price, named as theirs and set against the proposal, so the two
# markers on the track are read as one scenario rather than as two options. The
# sentence is a `note_key` because it carries the amount and because whether the
# learner's price is the proposal's is a fact about the values, not about the words.
eqalb_journey_price_learner_note <- function(price, proposal, unit) {
  if (isTRUE(abs(price - proposal) < 1e-9)) {
    return(paste0(
      "You kept the proposed price of ",
      eqalb_price_format_money(price),
      " ",
      unit,
      ", so the two markers sit together."
    ))
  }
  paste0(
    "You chose ",
    eqalb_price_format_money(price),
    " ",
    unit,
    ", which is ",
    if (price < proposal) "below" else "above",
    " the manufacturer's proposal of ",
    eqalb_price_format_money(proposal),
    "."
  )
}

# Where the balance reaches zero. The sentence follows the solver rather than
# assuming it succeeded: an unavailable solve reports R's own reason, and a price
# outside the track's range says so instead of being drawn somewhere it does not sit.
eqalb_journey_price_crossover_note <- function(solved, threshold_display, unit) {
  if (!isTRUE(solved$available)) {
    return(as.character(solved$reason))
  }
  base <- paste0(
    "The balance reaches zero at ",
    solved$display,
    " ",
    unit
  )
  if (isTRUE(solved$within_range)) {
    return(paste0(
      base,
      ": the highest annual price this model supports at this case's ",
      threshold_display,
      "."
    ))
  }
  side <- if (identical(solved$outside, "above")) "above" else "below"
  paste0(
    base,
    ", ",
    side,
    " the range the track covers, so no marker is drawn for it."
  )
}

# What the chapter does not claim. It keeps the price question separate from the
# evidence question on purpose: a different price moves the balance, and the
# uncertainty the previous chapters measured is still there. It also names the one
# difference a learner is certain to notice - this figure is the single comparison at
# the chosen price, while the previous chapter's bars were averages over its
# simulated comparisons, and a net monetary benefit is not linear in its inputs, so
# the two need not agree.
eqalb_journey_price_scope_note <- function() {
  paste(
    "Changing the price changes the balance. It does not remove the uncertainty in",
    "the simulated comparisons the earlier chapters measured, and those results",
    "keep the price and score they were computed for. The balance here is the single",
    "comparison at the price you chose, while the previous chapter's bars were",
    "averages over its simulated comparisons, so the two need not match."
  )
}

# The definition the chapter's figures are read against, and the qualifications that
# belong with it. Closed by default, so the story stays short.
eqalb_journey_price_disclosure <- function(threshold_display, control,
                                           horizon_years) {
  list(
    title = "What this comparison covers",
    lines = list(
      paste0(
        "The price is an annual rate per person, and the balance is the total per ",
        "person over the model's ",
        horizon_years,
        " years. The two units are different: the price is not multiplied by that ",
        "horizon again."
      ),
      paste0(
        "The balance is a net monetary benefit at this case's reference of ",
        threshold_display,
        ": health is valued in money at that reference, so it is not cash saved."
      ),
      paste0(
        "It is the single comparison at the price you chose. The previous ",
        "chapter's bars were averages over its simulated comparisons, and net ",
        "monetary benefit is not linear in its inputs, so the two figures need not ",
        "agree."
      ),
      paste0(
        "The price where the balance reaches zero is the annual price at which ",
        "the model's incremental net benefit is zero. The solver treats extra ",
        "cost as a straight line in the price and re-runs the model at the price ",
        "it finds to check it."
      ),
      paste0(
        "It holds every other assumption in this case fixed, it lies inside the ",
        "track's range of ",
        eqalb_price_format_money(control$min),
        " to ",
        eqalb_price_format_money(control$max),
        " when a marker is drawn, and it is not a negotiated price, a ",
        "recommendation, or a guarantee that the technology is affordable."
      ),
      # What the chapter does not claim. It sits here rather than beside the figure,
      # because the state on screen already says the short version: changing the price
      # moves the balance and does not remove the uncertainty.
      eqalb_journey_price_scope_note(),
      EQALB_PRICE_LIMITATION
    )
  )
}

# One solve, as the chapter reports it: whether it exists, what it is, whether it can
# be drawn on this track, and which side of the track it falls on when it cannot.
eqalb_journey_price_solved <- function(solve, control) {
  available <- isTRUE(solve$available) && length(solve$max_acceptable_price) == 1L &&
    is.finite(solve$max_acceptable_price)
  value <- if (available) as.numeric(solve$max_acceptable_price) else NA_real_
  within <- available && value >= control$min && value <= control$max
  outside <- if (!available || within) {
    ""
  } else if (value > control$max) {
    "above"
  } else {
    "below"
  }
  list(
    available = available,
    price = value,
    display = if (available) eqalb_price_format_money(value) else "",
    within_range = within,
    outside = outside,
    method = as.character(solve$method %||% ""),
    verified = isTRUE(solve$verified),
    reason = if (available) "" else as.character(solve$reason)
  )
}

# The balance display's own axis. It always contains zero, because zero is usual
# care, and it is padded so a bar that is exactly zero is still a visible mark rather
# than the edge of the panel.
eqalb_journey_price_axis <- function(nmb) {
  if (!is.finite(nmb)) return(list(min = -1, max = 1))
  low <- min(0, nmb)
  high <- max(0, nmb)
  pad <- max((high - low) * 0.25, 50)
  list(min = low - pad, max = high + pad)
}

# A posted solve is only ever a reuse of a number R itself produced for this case at
# this reference. Its shape and its scenario are checked before it is used at all: a
# payload for another case, another reference, or one that is missing a field the
# chapter draws is an R error rather than a silently accepted number.
eqalb_journey_price_solve_from_body <- function(body, scenario_key, threshold) {
  supplied <- body[["solve"]]
  required <- c("scenario_key", "threshold", "available", "reason", "method")
  missing <- required[!vapply(required, function(name) {
    length(supplied[[name]]) == 1L
  }, logical(1))]
  if (!is.list(supplied) || length(missing) > 0L) {
    stop(
      paste0(
        "A supplied 'solve' must be the solve object this chapter returned, with ",
        paste(missing, collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }
  if (!identical(as.character(supplied$scenario_key), scenario_key)) {
    stop(
      paste(
        "A supplied 'solve' must belong to this case and this reference: its",
        "'scenario_key' does not match the scenario being requested."
      ),
      call. = FALSE
    )
  }
  supplied_threshold <- suppressWarnings(as.numeric(supplied$threshold))
  if (!is.finite(supplied_threshold) || abs(supplied_threshold - threshold) > 1e-6) {
    stop(
      "A supplied 'solve' must be the solve computed at the requested threshold.",
      call. = FALSE
    )
  }
  available <- as.logical(supplied$available)
  if (length(available) != 1L || is.na(available)) {
    stop("A supplied 'solve' must carry a single logical 'available'.", call. = FALSE)
  }
  if (available) {
    value <- suppressWarnings(as.numeric(supplied$max_acceptable_price))
    if (length(value) != 1L || !is.finite(value) || value < 0) {
      stop(
        paste(
          "A supplied 'solve' that is available must carry a finite, non-negative",
          "'max_acceptable_price'."
        ),
        call. = FALSE
      )
    }
  }
  reason <- as.character(supplied$reason)
  if (!available && !nzchar(reason)) {
    stop(
      paste(
        "A supplied 'solve' that is not available must carry R's reason in",
        "'reason'."
      ),
      call. = FALSE
    )
  }
  list(
    available = available,
    max_acceptable_price = if (available) {
      as.numeric(supplied$max_acceptable_price)
    } else {
      NA_real_
    },
    method = as.character(supplied$method),
    verified = isTRUE(supplied$verified),
    reason = reason
  )
}

# The chapter's calculation. The balance is always R's own model run at the submitted
# price and score; the price solve is computed once and then reused, because the price
# at which the balance reaches zero is a property of the case and the reference rather
# than of the price being looked at. A reused solve is validated against the scenario
# key and the threshold before it is used, and it only ever supplies the marker: the
# number the learner reads beside the bar comes from the fresh run.
#
# There is no price lever in this chapter, so the price arrives as the one the learner
# chose in the base case. A solve computed at a different score produces a different
# scenario key, so it is refused rather than reused.
eqalb_journey_price <- function(body = list()) {
  control <- eqalb_journey_price_control()
  price <- eqalb_tutorial_number(
    body,
    EQALB_JOURNEY_PRICE_ID,
    control$default,
    min = control$min,
    max = control$max
  )
  utility <- eqalb_journey_utility(body)
  threshold <- eqalb_tutorial_number(
    body,
    "threshold",
    EQALB_JOURNEY_THRESHOLD_PER_QALY,
    min = 0
  )
  threshold_display <- eqalb_journey_voi_threshold_display(threshold)
  scenario_key <- eqalb_journey_price_scenario_key(utility)
  # The price's own unit, in the phrase a sentence reads: the same string the case
  # brief and the track's unit label use, so no screen describes the price as
  # anything else.
  unit <- eqalb_journey_case()$price_unit
  horizon_years <- eqalb_journey_horizon_years()

  args <- eqalb_journey_price_model_args(price, utility)
  run <- eqalb_price_run(args, price)
  if (!isTRUE(run$ok)) {
    stop(paste("The model did not run:", run$message), call. = FALSE)
  }
  nmb <- eqalb_price_nmb(run, threshold)

  solve <- if (is.null(body[["solve"]])) {
    eqalb_price_solve(args, threshold, price, run)
  } else {
    eqalb_journey_price_solve_from_body(body, scenario_key, threshold)
  }
  solved <- eqalb_journey_price_solved(solve, control)

  list(
    inputs = list(
      price = price,
      price_display = eqalb_price_format_money(price),
      utility_no_event = utility,
      utility_display = eqalb_journey_utility_display(utility),
      threshold = threshold,
      threshold_display = threshold_display,
      scenario_key = scenario_key
    ),
    price = list(
      scenario_key = scenario_key,
      price = price,
      price_display = eqalb_price_format_money(price),
      # The unit as a sentence reads it, so a caller never has to decide whether the
      # amount it holds is per person or per active user.
      unit = unit,
      unit_label = control$unit,
      range = list(min = control$min, max = control$max),
      ticks = eqalb_journey_price_ticks(control),
      proposal = list(
        value = control$default,
        display = eqalb_price_format_money(control$default)
      ),
      solved = solved,
      balance = list(
        nmb = nmb,
        display = eqalb_price_format_money_signed(nmb),
        positive = nmb >= 0,
        incremental_cost = run$incremental_cost,
        incremental_qalys = run$incremental_qalys,
        axis = eqalb_journey_price_axis(nmb)
      ),
      notes = list(
        learner = eqalb_journey_price_learner_note(
          price, control$default, unit
        ),
        balance = eqalb_journey_price_balance_note(
          price, nmb, threshold_display, unit, horizon_years
        ),
        crossover = eqalb_journey_price_crossover_note(
          solved, threshold_display, unit
        )
      ),
      limitation = EQALB_PRICE_LIMITATION,
      disclosure = eqalb_journey_price_disclosure(
        threshold_display, control, horizon_years
      )
    ),
    notice = eqalb_tutorial_notice()
  )
}


# --- The budget chapter -------------------------------------------------------
#
# The sixth chapter asks what adoption would cost the payer. It runs no model: the
# whole calculation is calculate_budget_impact(), the function the budget-impact tab
# and Guided Tutorial Part 2 already use, evaluated over the coverage lever's own
# steps.
#
# The two modules in this journey do not count the same people, and this chapter says
# so before it shows a total. The Markov model charges the annual price to everyone
# receiving eQalb, in every cycle, over its ten-year horizon and with its costs
# discounted. calculate_budget_impact() charges it to ACTIVE users only - the enrolled
# population after follow-up engagement - over five undiscounted years. Applying the
# same price here therefore applies it under a different payment assumption, and the
# two totals are not a population-scale continuation of one another. This slice does
# not harmonise them; it reports each from the function that owns it.

# The coverage lever, read from the constants Part 2 already uses so the two screens
# cannot offer different steps. The lookups fall back to the same numbers, so this
# module does not depend on load order.
eqalb_journey_coverage_bounds <- function() {
  number <- function(name, fallback) {
    value <- get0(name, envir = globalenv(), ifnotfound = fallback)
    value <- suppressWarnings(as.numeric(value))
    if (length(value) != 1L || !is.finite(value)) return(fallback)
    value
  }
  list(
    min = number("EQALB_PART2_COVERAGE_MIN", 10),
    max = number("EQALB_PART2_COVERAGE_MAX", 100),
    step = number("EQALB_PART2_COVERAGE_STEP", 5),
    default = number("EQALB_PART2_COVERAGE_DEFAULT", 100)
  )
}

# The coverage steps, highest first. They are the values the sweep is evaluated at, so
# the learner's slider only ever selects a row R has already returned.
eqalb_journey_coverage_steps <- function() {
  bounds <- eqalb_journey_coverage_bounds()
  seq(bounds$max, bounds$min, by = -bounds$step)
}

# The coverage control, in the tutorial's own control shape. Its help text is R's, and
# it says what the cap does and does not change.
eqalb_journey_coverage_control <- function() {
  bounds <- eqalb_journey_coverage_bounds()
  list(
    id = EQALB_JOURNEY_COVERAGE_ID,
    step_index = 1L,
    type = "slider",
    label = "Share of eligible people covered by the programme",
    unit = "%",
    info_topic = "the coverage cap",
    info = paste(
      "The share of the eligible population the programme is offered to. It changes",
      "how many people enrol and therefore what is spent; it does not change the",
      "clinical evidence, the price or the per-person result."
    ),
    default = bounds$default,
    min = bounds$min,
    max = bounds$max,
    step = bounds$step
  )
}

# The case's eligible population, read from the tutorial's own default rather than
# taken from the budget-impact route's fallback, which is a different number.
eqalb_journey_budget_population <- function() {
  defaults <- eqalb_tutorial_defaults()
  as.numeric(defaults$tutorial_population)
}

eqalb_journey_budget_population_display <- function() {
  format(
    eqalb_journey_budget_population(),
    big.mark = ",", scientific = FALSE, trim = TRUE
  )
}

eqalb_journey_budget_horizon <- function() {
  as.integer(eqalb_tutorial_fixed()$bia_horizon_years)
}

# The adoption assumptions the calculation actually uses, in R's own words. They are
# constants of the tutorial, not controls, so they are published rather than offered.
eqalb_journey_budget_assumptions <- function() {
  fixed <- eqalb_tutorial_fixed()
  assumptions <- eqalb_journey_fixed_assumptions()
  list(
    year1_uptake_pct = as.numeric(fixed$bia_year1_uptake_pct),
    annual_uptake_increase_pp = as.numeric(fixed$bia_annual_uptake_increase_pp),
    followup_engagement_pct = as.numeric(assumptions$engagement_followup_pct),
    implementation_cost = as.numeric(fixed$implementation_cost),
    healthcare_savings = as.numeric(fixed$healthcare_savings),
    avoided_event_savings = as.numeric(
      fixed$bia_avoided_event_savings_per_active_user
    )
  )
}

# The labels the chapter's figure draws. Each panel names its own scale, because the
# annual amounts and the running total are different quantities.
eqalb_journey_budget_graph <- function() {
  list(
    annual_title = "Net budget impact by year",
    annual_axis_label = "Annual net budget impact (EUR, not discounted)",
    cumulative_title = "Running total from adoption",
    cumulative_axis_label = paste0(
      "Cumulative net budget impact (EUR, running sum over all ",
      eqalb_journey_budget_horizon(),
      " years)"
    ),
    year_label = "Year",
    eligible_label = "Eligible people",
    covered_label = "Covered at this cap",
    enrolled_label = "Enrolled",
    active_label = "Active users",
    new_label = "New users",
    zero_label = "Break-even"
  )
}

# The chapter's states. The first three explain the costing difference and the
# population before any total appears; the fourth shows the annual amounts and the
# components that produce them; the fifth adds the running total on its own scale.
eqalb_journey_budget_copy <- function() {
  bounds <- eqalb_journey_coverage_bounds()
  horizon <- eqalb_journey_budget_horizon()
  list(
    title = eqalb_journey_chapter_title("budget"),
    stages = list(
      list(
        id = "costing",
        # The condition this chapter is built on: the two modules charge different
        # people, so this is not the previous chapter scaled up.
        caption = paste(
          "This budget module charges only active users. The earlier model charged",
          "everyone receiving the intervention."
        ),
        focus = "none",
        reveal = "intro",
        advance_label = "Who the cap covers"
      ),
      list(
        id = "population",
        caption = paste0(
          "The cap decides how many of the ",
          eqalb_journey_budget_population_display(),
          " eligible people are offered eQalb."
        ),
        focus = "budget_intro",
        reveal = "intro",
        note_key = "population",
        advance_label = "How adoption changes"
      ),
      list(
        id = "adoption",
        caption = "Adoption rises each year, so the cost changes by year.",
        focus = "budget_annual",
        reveal = "annual",
        note_key = "adoption",
        # The annual amounts appear here, with the lever that moves them. The four
        # component states that follow add nothing but one card each.
        components_shown = 0L,
        # The coverage lever is this state's control, so activating the figure must
        # not skip past it.
        interactive = TRUE,
        advance_label = "What the spending is"
      ),
      list(
        id = "programme",
        caption = "Active users generate programme costs.",
        focus = "budget_programme",
        reveal = "annual",
        components_shown = 1L,
        advance_label = "What else it costs"
      ),
      list(
        id = "setup",
        caption = "New users also need setup.",
        focus = "budget_setup",
        reveal = "annual",
        components_shown = 2L,
        advance_label = "What offsets it"
      ),
      list(
        id = "savings",
        caption = "Healthcare savings offset part of that spending.",
        focus = "budget_savings",
        reveal = "annual",
        components_shown = 3L,
        advance_label = "What remains"
      ),
      list(
        id = "net",
        caption = "What remains is the net budget impact.",
        focus = "budget_net",
        reveal = "annual",
        components_shown = 4L,
        advance_label = "The running total"
      ),
      list(
        id = "cumulative",
        caption = "Adding the years together gives the running total.",
        focus = "budget_cumulative",
        reveal = "cumulative",
        note_key = "cumulative",
        # The four figures the chapter has built up stay beside the figure, so the
        # running total is read against the spending it sums rather than on its own.
        components_shown = 4L,
        advance_label = "What this total is not"
      ),
      list(
        id = "limits",
        caption = "This is the payer's spending, not a value judgement.",
        focus = "none",
        reveal = "cumulative",
        components_shown = 4L,
        advance_label = "What is needed first"
      ),
      # The bridge into the readiness chapter. It carries no advance control, because
      # nothing follows it yet, and it is not a completion screen.
      list(
        id = "opens_next",
        caption = paste(
          "Spending is only part of the decision. What has to be in place before",
          "this could be offered responsibly?"
        ),
        focus = "none",
        reveal = "cumulative",
        components_shown = 4L,
        # The chapter now opens a bridge into readiness, so this state's control
        # carries that chapter's own label rather than the budget's "next part".
        advance_label = "What delivery would take"
      )
    ),
    advance_label = "Next part of the budget",
    coverage_note = paste0(
      "The cap runs from ",
      format(bounds$min, trim = TRUE),
      "% to ",
      format(bounds$max, trim = TRUE),
      "% of the eligible population."
    ),
    horizon_note = paste0(
      "These figures cover ",
      horizon,
      " years and are not discounted."
    )
  )
}

# What the population state says, with the case's own figures. It is computed per
# coverage step rather than typed, so the sentence always describes the row on screen.
eqalb_journey_budget_population_note <- function(population_display, coverage_display,
                                                 covered_display) {
  paste0(
    population_display,
    " people are eligible. At a cap of ",
    coverage_display,
    " the programme is offered to ",
    covered_display,
    " of them, and only a share of those enrol."
  )
}

# The adoption path, from the same constants the calculation uses.
eqalb_journey_budget_adoption_note <- function(assumptions, years) {
  first <- assumptions$year1_uptake_pct
  last <- min(
    100,
    assumptions$year1_uptake_pct +
      (max(years) - 1L) * assumptions$annual_uptake_increase_pp
  )
  paste0(
    "Enrolment starts at ",
    format(first, trim = TRUE),
    "% of the covered population and rises ",
    format(assumptions$annual_uptake_increase_pp, trim = TRUE),
    " percentage points a year, reaching ",
    format(last, trim = TRUE),
    "% by year ",
    max(years),
    ". Of those enrolled, ",
    format(assumptions$followup_engagement_pct, trim = TRUE),
    "% stay active, and the price is charged for each active user."
  )
}

# What the running total says, and the one thing it must not be read as.
eqalb_journey_budget_cumulative_note <- function(total_display, years) {
  paste0(
    "Over ",
    years,
    " years the payer's net outlay adds up to ",
    total_display,
    ". That is a total, not a yearly amount, and it is not discounted."
  )
}

# The quiet disclosure: the costing difference as a model limitation, the horizon and
# the discounting, and what the figure does not include. It also carries the two
# sentences the chapter used to print beside the figure — why the same price here is
# not the last chapter continued, and what the totals are not — so the panel keeps
# only the short caption and the amounts.
eqalb_journey_budget_disclosure <- function(horizon) {
  list(
    title = "What this total covers",
    lines = list(
      paste(
        "Payment assumption: this module charges the annual price for each active",
        "user only. The Markov model behind the earlier chapters charges everyone",
        "receiving eQalb, every cycle. The two conventions are not harmonised in",
        "this slice, so a total here is not the earlier per-person result multiplied",
        "by a population, and the price the earlier chapter solved for was not",
        "solved for this basis."
      ),
      paste0(
        "The figures cover ",
        horizon,
        " years and are not discounted. The model's ten-year per-person results are ",
        "discounted, so the two cannot be reconciled directly."
      ),
      paste(
        "Net budget impact is the payer's spending minus the healthcare savings the",
        "model expects. A positive figure means extra spending; it says nothing",
        "about whether the money buys good value."
      ),
      paste(
        "The totals are the payer's own cash flows at the price selected for this",
        "journey. They are not a per-person value judgement, not the benefit the",
        "technology produces, and not savings."
      ),
      paste(
        "Avoided-event savings are set to zero in this case, so they are not counted:",
        "they are subtracted as nothing rather than shown as a component."
      ),
      paste(
        "No budget ceiling is applied, so no affordability verdict is produced here.",
        "Whether the total is affordable is a separate question, and this chapter",
        "does not answer it."
      )
    )
  )
}

# The one price this chapter charges, as the chapter offers it. The label is R's, and
# it says where the price came from rather than asking the client to describe it.
#
# There is exactly one candidate because there is now exactly one price in the
# journey: the one chosen in the base case. The chapter keeps the list shape so the
# sweep, the cache key and the client's selection are unchanged in structure, but a
# list of one cannot be selected between and never shows a redundant choice.
eqalb_journey_budget_candidate <- function(key, label, price) {
  list(
    key = key,
    label = label,
    price = price,
    price_display = eqalb_price_format_money(price)
  )
}

eqalb_journey_budget_candidates <- function(price) {
  list(
    eqalb_journey_budget_candidate(
      "journey",
      "The price chosen in the first chapter",
      price
    )
  )
}

# The annual rows for one price and one coverage cap. calculate_budget_impact() is
# unchanged: the population is the case's own, scaled by the cap exactly as Part 2
# scales it, and every other input is a tutorial constant.
eqalb_journey_budget_rows <- function(price, coverage) {
  fixed <- eqalb_tutorial_fixed()
  assumptions <- eqalb_journey_budget_assumptions()
  population <- eqalb_journey_budget_population()
  calculate_budget_impact(
    population = population * coverage / 100,
    year1_uptake_pct = fixed$bia_year1_uptake_pct,
    annual_uptake_increase_pp = fixed$bia_annual_uptake_increase_pp,
    horizon_years = eqalb_journey_budget_horizon(),
    intervention_price = price,
    implementation_cost_per_new_user = fixed$implementation_cost,
    healthcare_savings_per_active_user = fixed$healthcare_savings,
    avoided_event_savings_per_active_user = assumptions$avoided_event_savings,
    followup_engagement_pct = assumptions$followup_engagement_pct
  )
}

# R's own count formatting, so a population is never formatted by the client.
eqalb_journey_budget_count <- function(value) {
  format(round(value), big.mark = ",", scientific = FALSE, trim = TRUE)
}

# One coverage step, as the figure and the sentences read it. The three sentences that
# depend on the cap are built here, so the client renders a row R has already
# described rather than choosing a sentence for a row.
eqalb_journey_budget_coverage <- function(price, coverage, graph) {
  table <- eqalb_journey_budget_rows(price, coverage)
  rows <- lapply(seq_len(nrow(table)), function(index) {
    list(
      year = table$year[index],
      key = paste0("year-", table$year[index]),
      year_label = paste0(graph$year_label, " ", table$year[index]),
      enrolled = table$cumulative_users[index],
      enrolled_display = eqalb_journey_budget_count(table$cumulative_users[index]),
      new_users = table$new_users[index],
      new_users_display = eqalb_journey_budget_count(table$new_users[index]),
      active_users = table$active_users[index],
      active_users_display = eqalb_journey_budget_count(table$active_users[index]),
      uptake_pct = table$uptake_pct[index],
      gross_intervention_cost = table$gross_intervention_cost[index],
      implementation_cost = table$implementation_cost[index],
      healthcare_savings = table$healthcare_savings[index],
      avoided_event_savings = table$avoided_event_savings[index],
      net = table$net_budget_impact[index],
      net_display = eqalb_tutorial_money_signed(table$net_budget_impact[index]),
      cumulative = table$cumulative_budget_impact[index],
      cumulative_display = eqalb_tutorial_money_signed(
        table$cumulative_budget_impact[index]
      )
    )
  })

  totals <- list(
    gross_display = eqalb_tutorial_money(sum(table$gross_intervention_cost)),
    gross = sum(table$gross_intervention_cost),
    implementation_display = eqalb_tutorial_money(
      sum(table$implementation_cost)
    ),
    implementation = sum(table$implementation_cost),
    savings_display = eqalb_tutorial_money(sum(table$healthcare_savings)),
    savings = sum(table$healthcare_savings),
    avoided_display = eqalb_tutorial_money(sum(table$avoided_event_savings)),
    avoided = sum(table$avoided_event_savings),
    net_display = eqalb_tutorial_money_signed(sum(table$net_budget_impact)),
    net = sum(table$net_budget_impact)
  )

  coverage_display <- paste0(format(coverage, trim = TRUE), "%")
  covered <- table$eligible_population[[1]]
  covered_display <- eqalb_journey_budget_count(covered)
  cumulative <- table$cumulative_budget_impact[[nrow(table)]]
  cumulative_display <- eqalb_tutorial_money_signed(cumulative)

  # The component breakdown the chapter reveals one step at a time. Each entry is a
  # labelled figure with its own period and unit, so an amount sits beside the thing
  # it measures instead of being listed in a sentence. The components are the ones
  # calculate_budget_impact() actually subtracted or added, in that order; a
  # zero-valued component is not given a card, so avoided-event savings appear only
  # in the disclosure.
  components <- list(
    list(
      key = "programme",
      label = "Programme costs",
      sub = "Price charged for each active user",
      amount_display = totals$gross_display,
      amount = totals$gross,
      tone = "cost"
    ),
    list(
      key = "setup",
      label = "Setup costs",
      sub = "One-off, for each new user",
      amount_display = totals$implementation_display,
      amount = totals$implementation,
      tone = "cost"
    ),
    list(
      key = "savings",
      label = "Healthcare savings",
      sub = "Subtracted from the spending",
      amount_display = totals$savings_display,
      amount = totals$savings,
      tone = "saving"
    ),
    list(
      key = "net",
      label = "Net budget impact",
      sub = "What remains after the savings",
      amount_display = totals$net_display,
      amount = totals$net,
      tone = "net"
    )
  )

  list(
    coverage = coverage,
    coverage_display = coverage_display,
    covered_population = covered,
    covered_display = covered_display,
    rows = rows,
    years = nrow(table),
    # The running total is the last cumulative value, not a second sum.
    cumulative = cumulative,
    cumulative_display = cumulative_display,
    totals = totals,
    components = components,
    # The period the components cover, said once above them so a five-year amount
    # cannot be read as a year's amount.
    components_period = paste0(
      "All ",
      nrow(table),
      " years added together, not discounted"
    ),
    notes = list(
      population = eqalb_journey_budget_population_note(
        eqalb_journey_budget_population_display(),
        coverage_display,
        covered_display
      ),
      cumulative = eqalb_journey_budget_cumulative_note(
        cumulative_display,
        nrow(table)
      )
    )
  )
}

# The axis each panel draws against, from every value the sweep contains, so changing
# the coverage cap never rescales a figure the learner is already reading.
eqalb_journey_budget_axis <- function(candidates) {
  net <- unlist(lapply(candidates, function(candidate) {
    unlist(lapply(candidate$coverages, function(step) {
      vapply(step$rows, function(row) row$net, numeric(1))
    }))
  }))
  cumulative <- unlist(lapply(candidates, function(candidate) {
    vapply(candidate$coverages, function(step) step$cumulative, numeric(1))
  }))
  span <- function(values) {
    if (length(values) == 0L) return(list(min = -1, max = 1))
    low <- min(0, min(values, na.rm = TRUE))
    high <- max(0, max(values, na.rm = TRUE))
    pad <- max((high - low) * 0.18, 100)
    list(min = low - pad, max = high + pad)
  }
  list(annual = span(net), cumulative = span(cumulative))
}

# The chapter's calculation. It calls no model: every figure comes from
# calculate_budget_impact(), evaluated at each of the coverage lever's steps for the
# one price the journey carries. One response therefore carries the whole sweep, and
# moving the cap selects a row that has already been computed rather than asking R
# again.
#
# The selected price arrives as `price`, the same field the base case and the price
# chapter read, so there is one name for one value across the journey. Budget impact
# does not read the utility: calculate_budget_impact() prices active users and knows
# nothing about quality of life, so moving the score changes nothing here and the
# chapter does not claim it does.
eqalb_journey_budget <- function(body = list()) {
  control <- eqalb_journey_price_control()
  price <- eqalb_tutorial_number(
    body,
    EQALB_JOURNEY_PRICE_ID,
    control$default,
    min = control$min,
    max = control$max
  )

  graph <- eqalb_journey_budget_graph()
  assumptions <- eqalb_journey_budget_assumptions()
  horizon <- eqalb_journey_budget_horizon()
  bounds <- eqalb_journey_coverage_bounds()
  coverage_steps <- eqalb_journey_coverage_steps()

  candidates <- lapply(
    eqalb_journey_budget_candidates(price),
    function(candidate) {
      coverages <- lapply(coverage_steps, function(coverage) {
        eqalb_journey_budget_coverage(candidate$price, coverage, graph)
      })
      c(candidate, list(coverages = coverages))
    }
  )

  years <- vapply(
    candidates[[1]]$coverages[[1]]$rows, function(row) row$year, numeric(1)
  )

  list(
    inputs = list(
      price = price,
      price_display = eqalb_price_format_money(price),
      population = eqalb_journey_budget_population(),
      horizon_years = horizon,
      scenario_key = eqalb_journey_price_scenario_key()
    ),
    budget = list(
      population = eqalb_journey_budget_population(),
      population_display = eqalb_journey_budget_population_display(),
      horizon_years = horizon,
      coverage_control = eqalb_journey_coverage_control(),
      coverage_steps = as.numeric(coverage_steps),
      coverage_default = bounds$default,
      assumptions = assumptions,
      candidates = candidates,
      axis = eqalb_journey_budget_axis(candidates),
      # The one sentence that depends on neither the cap nor the price. The chapter's
      # limits are in its disclosure rather than beside the figure.
      notes = list(
        adoption = eqalb_journey_budget_adoption_note(assumptions, years)
      ),
      disclosure = eqalb_journey_budget_disclosure(horizon)
    ),
    notice = eqalb_tutorial_notice()
  )
}

# --- Chapter 7: can it be delivered as planned? -----------------------------
#
# The seventh chapter turns from what the comparison is worth to what delivering it
# would take. Every earlier chapter assumed eQalb could be offered as modelled;
# calculate_readiness() is the only function in the project that tests the conditions
# that assumption rests on, so the chapter runs it rather than describing it.
#
# Nothing here adds a rule. calculate_readiness() keeps its own ten inputs, seven
# domains, three statuses and per-domain sentences; this module maps four learner
# answers onto four of those inputs, holds the other six at the case's values, and
# publishes the function's own answers. The statuses are therefore the same statuses
# the analysis dashboard's readiness tab produces for the same inputs, and no
# threshold is restated anywhere in the journey.
#
# What the chapter must not claim: that the checklist verifies the intervention can
# achieve the modelled outcomes, that it validates the model's assumptions, or that a
# status is a regulatory, certification or funding judgement. The traffic-light rules
# are teaching rules, and a Red says an area needs attention under them.

EQALB_JOURNEY_READINESS_CHAPTER_ID <- "readiness"

# The four areas the learner chooses. Each is a decision a deployment actually makes,
# rather than a quality of the population: how information is exchanged, how the
# algorithm changes, how much clinician time each patient takes, and which languages
# are offered. The other three domains are not choices of this kind — the two access
# shares describe the population, accessibility is a single yes/no, and engagement is
# the journey's own scenario assumption — so they are held at the case's values and
# shown on demand instead of being asked about.
#
# Every option carries the string calculate_readiness() already accepts, and the
# answer's own wording is a short scenario rather than the level's technical name, so
# a reader who does not know what "FHIR" means can still choose. The status is not
# stored here: it is whatever calculate_readiness() returns for the string chosen, so
# this table cannot disagree with the function.
eqalb_journey_readiness_questions <- function() {
  list(
    list(
      id = "interoperability",
      domain = "Interoperability",
      focus = "ready_interop",
      caption = "Can it exchange data with the systems already in use?",
      label = "How would it share information with the clinical record system?",
      options = list(
        list(
          id = "none",
          label = paste(
            "Nothing is sent automatically. Staff read the results and type them",
            "into the record themselves."
          ),
          input_display = "No data exchange",
          input = "No data exchange"
        ),
        list(
          id = "basic",
          label = paste(
            "Staff export a structured file and re-enter some fields, so the record",
            "is only partly up to date."
          ),
          input_display = "PDF/manual export",
          input = "PDF/manual export"
        ),
        list(
          id = "strong",
          label = paste(
            "The app writes structured data into the record system through a",
            "defined interface, so staff do not retype it."
          ),
          input_display = "FHIR-based exchange",
          input = "FHIR-based exchange"
        )
      )
    ),
    list(
      id = "governance",
      domain = "Algorithm governance",
      focus = "ready_governance",
      caption = "An algorithm that changes after go-live needs governing.",
      label = "How does the algorithm change after deployment?",
      options = list(
        list(
          id = "learning",
          label = paste(
            "It keeps learning from new data, so its behaviour changes",
            "continuously."
          ),
          input_display = "Continuously learning algorithm",
          input = "Continuously learning algorithm"
        ),
        list(
          id = "partial",
          label = paste(
            "It is updated in planned releases, and each release is reviewed and",
            "re-tested before it goes live."
          ),
          input_display = "Periodic controlled updates",
          input = "Periodic controlled updates"
        ),
        list(
          id = "strong",
          label = paste(
            "It is fixed when it is deployed; changing it means issuing and",
            "testing a new version."
          ),
          input_display = "Locked algorithm",
          input = "Locked algorithm"
        )
      )
    ),
    list(
      id = "workflow",
      domain = "Workflow burden",
      focus = "ready_workflow",
      caption = "How much clinician review does each patient need?",
      label = "How much clinician time does each patient take each month?",
      options = list(
        list(
          id = "low",
          label = paste(
            "Under five minutes: staff look only when the app flags a patient who",
            "is not following the plan."
          ),
          input_display = "4 clinician-review minutes per patient per month",
          input = 4
        ),
        list(
          id = "moderate",
          label = paste(
            "About ten minutes: a routine monthly check of each patient's readings",
            "and messages."
          ),
          input_display = "10 clinician-review minutes per patient per month",
          input = 10
        ),
        list(
          id = "high",
          label = paste(
            "About twenty minutes: a detailed monthly review of each patient's",
            "data and adherence."
          ),
          input_display = "20 clinician-review minutes per patient per month",
          input = 20
        )
      )
    ),
    list(
      id = "languages",
      domain = "Language access",
      focus = "ready_language",
      caption = "Which languages does it support?",
      label = "How many languages would the programme be offered in?",
      options = list(
        list(
          id = "one",
          label = "One language, the one the pilot ran in.",
          input_display = "1 supported language",
          input = 1
        ),
        list(
          id = "two",
          label = paste(
            "Two languages, covering the two largest groups in the population."
          ),
          input_display = "2 supported languages",
          input = 2
        ),
        list(
          id = "three",
          label = paste(
            "Three or more, including the smaller language groups in the",
            "population."
          ),
          input_display = "3 supported languages",
          input = 3
        )
      )
    )
  )
}

# One question, by id. The chapter renders the questions in the order this list
# publishes, and a request naming an id is checked against it.
eqalb_journey_readiness_question <- function(id) {
  questions <- eqalb_journey_readiness_questions()
  matches <- vapply(
    questions, function(question) identical(question$id, id), logical(1)
  )
  if (!any(matches)) return(NULL)
  questions[[which(matches)[1]]]
}

# One option of one question, by id, or NULL when the pair does not exist. A request
# is validated through this, so an answer the chapter does not offer cannot become an
# input to the assessment.
eqalb_journey_readiness_option <- function(question_id, option_id) {
  question <- eqalb_journey_readiness_question(question_id)
  if (is.null(question)) return(NULL)
  matches <- vapply(
    question$options,
    function(option) identical(option$id, option_id),
    logical(1)
  )
  if (!any(matches)) return(NULL)
  question$options[[which(matches)[1]]]
}

# The case's own non-editable readiness inputs. Population, the two access shares,
# the two engagement values and accessibility come from the case's published
# assumptions, so the assessment starts from the same scenario the economic chapters
# used and the learner is not asked about values the journey has already fixed.
eqalb_journey_readiness_fixed <- function() {
  assumptions <- eqalb_journey_fixed_assumptions()
  defaults <- eqalb_tutorial_defaults()
  list(
    target_population = defaults$tutorial_population,
    digital_access = assumptions$digital_access_pct,
    digital_suitability = assumptions$digital_suitability_pct,
    readiness_year1_engagement = assumptions$engagement_year1_pct,
    readiness_followup_engagement = assumptions$engagement_followup_pct,
    accessibility_features = isTRUE(assumptions$accessibility_features)
  )
}

# The ten inputs calculate_readiness() takes, from the case's values and the
# learner's four answers. The two engagement values are the journey's own scenario
# assumptions and are never taken from an answer, so the readiness result cannot
# contradict the economics the earlier chapters computed with the same engagement.
eqalb_journey_readiness_inputs <- function(answers) {
  fixed <- eqalb_journey_readiness_fixed()
  interoperability <- eqalb_journey_readiness_option(
    "interoperability", answers$interoperability
  )
  governance <- eqalb_journey_readiness_option("governance", answers$governance)
  workflow <- eqalb_journey_readiness_option("workflow", answers$workflow)
  languages <- eqalb_journey_readiness_option("languages", answers$languages)

  list(
    target_population = fixed$target_population,
    digital_access = fixed$digital_access,
    digital_suitability = fixed$digital_suitability,
    readiness_year1_engagement = fixed$readiness_year1_engagement,
    readiness_followup_engagement = fixed$readiness_followup_engagement,
    review_minutes = workflow$input,
    supported_languages = languages$input,
    accessibility_features = fixed$accessibility_features,
    interoperability = interoperability$input,
    algorithm_governance = governance$input
  )
}

# The default answer set: the option that matches the case's own value for each of the
# four questions, read from the case rather than chosen for looks. The workflow and
# language answers are the case's review minutes and language count; the
# interoperability and governance answers are the case's own levels.
eqalb_journey_readiness_defaults <- function() {
  assumptions <- eqalb_journey_fixed_assumptions()
  tutorial <- eqalb_tutorial_defaults()
  match_input <- function(question_id, value) {
    question <- eqalb_journey_readiness_question(question_id)
    inputs <- vapply(
      question$options, function(option) as.character(option$input), character(1)
    )
    match <- which(inputs == as.character(value))
    if (length(match) == 0L) return(question$options[[1]]$id)
    question$options[[match[1]]]$id
  }
  list(
    interoperability = match_input(
      "interoperability", assumptions$interoperability_available
    ),
    governance = match_input("governance", assumptions$algorithm_governance),
    workflow = match_input("workflow", tutorial$tutorial_review_minutes),
    languages = match_input("languages", assumptions$supported_languages)
  )
}

# One answer set, as the response echoes it: every question with the option chosen,
# so the interface prints R's own wording for the answer on screen rather than
# remembering which label it drew.
eqalb_journey_readiness_answer_list <- function(answers) {
  lapply(eqalb_journey_readiness_questions(), function(question) {
    option_id <- answers[[question$id]]
    option <- eqalb_journey_readiness_option(question$id, option_id)
    list(
      question_id = question$id,
      domain = question$domain,
      caption = question$caption,
      label = question$label,
      option_id = option$id,
      option_label = option$label,
      input_display = option$input_display
    )
  })
}

# The labels the chapter's own figure draws. The seven chips use the domain names
# calculate_readiness() returns, so a chip cannot be labelled differently from the
# assessment row behind it.
eqalb_journey_readiness_graph <- function() {
  list(
    chips_title = "Seven areas, each judged on its own",
    chips_note = paste(
      "Each area has its own rule. A status names an area to look at; it is not a",
      "score for the technology."
    ),
    counts_title = "How the seven areas fall",
    green_label = "Green",
    amber_label = "Amber",
    red_label = "Red",
    fixed_title = "Values the chapter holds fixed",
    fixed_note = paste(
      "These describe the case rather than a deployment choice, so they are not",
      "asked about here."
    ),
    options_title = "Who this case is"
  )
}

# The chapter's states. Each question is a state of its own, so the figure can bring
# that one area forward while the learner answers it, and the sentence under the
# figure is R's own explanation of the status the answer produced. Nothing requires a
# Green: an answer that turns a chip Amber or Red is a complete answer, and the
# chapter never suggests the areas should all be Green before moving on.
eqalb_journey_readiness_copy <- function() {
  list(
    title = eqalb_journey_chapter_title("readiness"),
    stages = list(
      list(
        id = "intro",
        caption = paste(
          "The results so far assume eQalb can be delivered as modelled."
        ),
        focus = "none",
        reveal = "intro",
        advance_label = "What gets checked"
      ),
      list(
        id = "dimensions",
        caption = "Seven areas are checked, each against its own rule.",
        focus = "ready_chips",
        reveal = "chips",
        advance_label = "How systems connect"
      ),
      list(
        id = "interoperability",
        caption = "Can it exchange data with the systems already in use?",
        focus = "ready_interop",
        reveal = "chips",
        question_id = "interoperability",
        # The question is the control here, so activating the figure must not skip it.
        interactive = TRUE,
        advance_label = "How the algorithm changes"
      ),
      list(
        id = "governance",
        caption = "How the algorithm changes after go-live is a delivery condition.",
        focus = "ready_governance",
        reveal = "chips",
        question_id = "governance",
        interactive = TRUE,
        advance_label = "How much review it needs"
      ),
      list(
        id = "workflow",
        caption = "How much clinician review does each patient need?",
        focus = "ready_workflow",
        reveal = "chips",
        question_id = "workflow",
        interactive = TRUE,
        advance_label = "Which languages it supports"
      ),
      list(
        id = "language",
        caption = "Which languages does it support?",
        focus = "ready_language",
        reveal = "chips",
        question_id = "languages",
        interactive = TRUE,
        advance_label = "What the check says"
      ),
      list(
        id = "statuses",
        caption = "Every area is judged against its own illustrative rule.",
        focus = "ready_counts",
        reveal = "chips",
        note_key = "statuses",
        advance_label = "What this is not"
      ),
      list(
        id = "limits",
        caption = "This is a teaching check, not a certification.",
        focus = "none",
        reveal = "chips",
        advance_label = "What this leaves"
      ),
      # The chapter ends on a statement rather than a control, and its way forward
      # leads into the chapter that follows: the last view of the same comparison, with
      # events timed rather than counted per year. The label names that transition
      # instead of the chapter's own wording, because this state opens a bridge rather
      # than moving to another part of the check.
      list(
        id = "opens_next",
        caption = paste(
          "Value, spending and delivery all bear on one decision."
        ),
        focus = "none",
        reveal = "chips",
        advance_label = "How events unfold over time"
      )
    ),
    advance_label = "Next part of the check"
  )
}

# The chapter's own sentences. The summary is built from the assessment's own counts
# and domain names, so it cannot describe a different set of statuses from the chips
# beside it. Nothing here scores, ranks or totals the seven areas.
eqalb_journey_readiness_statuses_note <- function(readiness) {
  counts <- readiness$counts
  red <- readiness$domains$Domain[readiness$domains$Status == "Red"]
  amber <- readiness$domains$Domain[readiness$domains$Status == "Amber"]
  paste(
    sprintf(
      "%d Green, %d Amber and %d Red across %d areas.",
      counts[["Green"]], counts[["Amber"]], counts[["Red"]],
      nrow(readiness$domains)
    ),
    if (length(red) > 0L) {
      paste0(
        "Areas needing attention first (Red): ",
        paste(red, collapse = ", "),
        "."
      )
    } else if (length(amber) > 0L) {
      paste0(
        "No Red areas. Areas needing mitigation (Amber): ",
        paste(amber, collapse = ", "),
        "."
      )
    } else {
      "No Red or Amber areas under these answers."
    }
  )
}

# What the check is and is not. It states the boundary the chapter has to hold: the
# assessment describes conditions under teaching rules, and it neither proves the
# intervention can achieve the modelled outcomes nor validates the economic model.
eqalb_journey_readiness_limits_note <- function(readiness) {
  paste(
    "These are the case's own assumptions, judged by illustrative rules.",
    "They do not verify that eQalb would achieve the modelled outcomes, they do not",
    "validate the economic assumptions, and they are not a regulatory,",
    "cybersecurity or funding decision.",
    "A Red area is one to resolve before broad deployment under these rules."
  )
}

# The quiet disclosure: how the statuses are decided, what the rules are not, what was
# held fixed, and the limits of the exercise. The per-domain sentences themselves are
# the assessment's, not this chapter's.
#
# The three caveats this chapter used to print beside the figure now live here: that
# the rules are teaching rules rather than an official standard, that a Red under the
# governance rule is an area needing attention rather than a verdict on adaptive
# technology, and that the check neither verifies the modelled outcomes nor validates
# the economics. The panel keeps the caption that says the same thing in a sentence.
eqalb_journey_readiness_disclosure <- function(readiness) {
  list(
    title = "How this check works",
    lines = c(
      paste(
        "The seven areas and their rules come from the readiness assessment the",
        "rest of the application uses. Each area is judged separately, and the",
        "counts are a summary of those judgements rather than a score."
      ),
      paste(
        "The rules are teaching rules for this case. They are not an official",
        "standard, and a status is not a certification."
      ),
      paste(
        "The thresholds are illustrative teaching assumptions for the fictional",
        "eQalb digital therapeutic. They are not official HTA, DiGA, regulatory,",
        "cybersecurity or reimbursement standards."
      ),
      paste(
        "A Red under the governance rule says the teaching rule wants more",
        "governance attention. It is not a judgement that adaptive technology is",
        "unsuitable."
      ),
      paste(
        "The access shares, the two engagement values and accessibility are the",
        "case's own values rather than choices, and they are held fixed so this",
        "chapter cannot change the economics the earlier chapters computed."
      ),
      eqalb_journey_readiness_limits_note(readiness),
      DHT_DISCLAIMER
    )
  )
}

# The chapter's calculation. It runs no model: calculate_readiness() is arithmetic
# over ten inputs and seven fixed rules, so one request is one assessment.
#
# The request carries only the four answers. The other six inputs are the case's own
# values, read here, so an answer cannot move the population, the access shares, the
# engagement the economics used, or accessibility.
eqalb_journey_readiness <- function(body = list()) {
  defaults <- eqalb_journey_readiness_defaults()
  answers <- lapply(eqalb_journey_readiness_questions(), function(question) {
    supplied <- if (is.null(body[["answers"]])) {
      NULL
    } else {
      body[["answers"]][[question$id]]
    }
    if (is.null(supplied) || !is.character(supplied) || length(supplied) != 1L) {
      return(defaults[[question$id]])
    }
    if (is.null(eqalb_journey_readiness_option(question$id, supplied))) {
      stop(sprintf(
        "'%s' must be one of: %s.",
        question$id,
        paste(
          vapply(question$options, function(o) o$id, character(1)),
          collapse = ", "
        )
      ), call. = FALSE)
    }
    supplied
  })
  names(answers) <- vapply(
    eqalb_journey_readiness_questions(), function(q) q$id, character(1)
  )

  inputs <- eqalb_journey_readiness_inputs(answers)
  readiness <- do.call(calculate_readiness, inputs)
  echo <- eqalb_journey_readiness_answer_list(answers)

  # The one area the answer on screen changed. A request may name the question the
  # learner just answered, and that answer is the one named when it differs from the
  # case's own value; otherwise the first differing answer is named, so a learner who
  # returns to the chapter with answers already set still sees something to read.
  # An answer equal to the case's own value is not a change.
  differs <- Filter(function(answer) {
    !identical(answer$option_id, defaults[[answer$question_id]])
  }, echo)
  answered <- if (is.null(body[["focus_question"]])) {
    NULL
  } else {
    Filter(
      function(answer) identical(answer$question_id, body[["focus_question"]]),
      differs
    )
  }
  current <- if (length(answered) > 0L) {
    answered[[1]]
  } else if (length(differs) > 0L) {
    differs[[1]]
  } else {
    NULL
  }

  domains <- lapply(seq_len(nrow(readiness$domains)), function(index) {
    domain <- readiness$domains$Domain[index]
    question <- Filter(
      function(q) identical(q$domain, domain),
      eqalb_journey_readiness_questions()
    )
    list(
      domain = domain,
      status = readiness$domains$Status[index],
      input_display = readiness$domains[["Current input"]][index],
      # The assessment's own per-domain sentence: it is what explains why this
      # status follows from this input, and the chapter does not rewrite it.
      explanation = readiness$domains$Interpretation[index],
      question_id = if (length(question) == 0L) NULL else question[[1]]$id,
      focus = if (length(question) == 0L) NULL else question[[1]]$focus
    )
  })

  numbers <- lapply(seq_len(nrow(readiness$numbers)), function(index) {
    list(
      measure = readiness$numbers$Measure[index],
      value = readiness$numbers$Value[index],
      basis = readiness$numbers[["Illustrative basis"]][index]
    )
  })

  fixed <- eqalb_journey_readiness_fixed()
  fixed_rows <- list(
    list(
      label = "Eligible population",
      value_display = format(
        fixed$target_population, big.mark = ",", scientific = FALSE, trim = TRUE
      )
    ),
    list(
      label = "Smartphone/internet access",
      value_display = paste0(dht_format_rate(fixed$digital_access), "%")
    ),
    list(
      label = "Digitally suitable population",
      value_display = paste0(dht_format_rate(fixed$digital_suitability), "%")
    ),
    list(
      label = "Year-1 engagement",
      value_display = paste0(dht_format_rate(fixed$readiness_year1_engagement), "%")
    ),
    list(
      label = "Follow-up engagement",
      value_display = paste0(dht_format_rate(fixed$readiness_followup_engagement), "%")
    ),
    list(
      label = "Accessibility features",
      value_display = if (isTRUE(fixed$accessibility_features)) "Available" else "Not available"
    )
  )

  # Every input the assessment received, so a client can cache against all ten rather
  # than against the four it can edit.
  input_key <- paste(
    vapply(
      names(inputs),
      function(name) {
        paste0(name, "=", paste(format(as.character(inputs[[name]]), trim = TRUE), collapse = ""))
      },
      character(1)
    ),
    collapse = "|"
  )

  list(
    inputs = list(
      answers = answers,
      readiness_key = input_key
    ),
    readiness = list(
      questions = eqalb_journey_readiness_questions(),
      answers = echo,
      domains = domains,
      counts = list(
        green = readiness$counts[["Green"]],
        amber = readiness$counts[["Amber"]],
        red = readiness$counts[["Red"]],
        total = nrow(readiness$domains)
      ),
      changed = if (is.null(current)) NULL else current,
      numbers = numbers,
      fixed = fixed_rows,
      # The assessment's own summary and account; the chapter adds only what it is
      # and is not, never a different set of statuses.
      assessment = readiness$interpretation,
      notes = list(
        statuses = eqalb_journey_readiness_statuses_note(readiness)
      ),
      disclosure = eqalb_journey_readiness_disclosure(readiness)
    ),
    notice = eqalb_tutorial_notice()
  )
}

# --- Chapter 8: time to a first heart attack or stroke ----------------------

# The one simulation this chapter reads, stated once so the response, the contract's
# cache key and the cache itself cannot disagree about what was simulated. Nothing the
# learner moves earlier in the journey is here: the chapter is a different view of the
# same effect assumption, not a further calculation of value, so the price and the
# score are deliberately absent.
EQALB_JOURNEY_SURVIVAL_GROUPS <- c("Usual care", "eQalb plus usual care")
EQALB_JOURNEY_SURVIVAL_N <- 1000L
EQALB_JOURNEY_SURVIVAL_SEED <- 20261004L
# The three times the chapter can be read at. They are the chapter's own choice: one
# response carries all three, so reading another time never asks R again. The last one
# is within the model's own horizon, which is what the follow-up below uses.
EQALB_JOURNEY_SURVIVAL_TIMES <- c(1L, 5L, 10L)

# Everything the simulation reads, in one place. The case's own effect assumption, the
# model's own horizon and its annual event risks are read rather than retyped, so this
# chapter cannot describe a different case from the chapters before it. They are read
# inside the function rather than at the top of the file, so sourcing this module needs
# no other module to have been sourced first.
eqalb_journey_survival_inputs <- function() {
  assumptions <- eqalb_journey_fixed_assumptions()
  list(
    n_per_arm = EQALB_JOURNEY_SURVIVAL_N,
    followup_years = as.integer(cycles),
    seed = EQALB_JOURNEY_SURVIVAL_SEED,
    rrr = assumptions$rrr_pct / 100,
    engagement_year1 = assumptions$engagement_year1_pct / 100,
    engagement_followup = assumptions$engagement_followup_pct / 100,
    p_mi = p_mi_usual_care,
    p_stroke = p_stroke_usual_care,
    p_other_death = p_other_death
  )
}

# The same inputs as one string, so a stored response describes exactly one simulation.
# It is published in the contract as well as returned, which is what lets the interface
# cache against every input rather than against the session it happens to be in.
eqalb_journey_survival_inputs_key <- function() {
  inputs <- eqalb_journey_survival_inputs()
  paste(
    vapply(
      names(inputs),
      function(name) {
        paste0(name, "=", format(inputs[[name]], trim = TRUE, scientific = FALSE))
      },
      character(1)
    ),
    collapse = "|"
  )
}

# The figure's own words. The title names what is timed and what the event is; the
# qualifier under it says the curves are simulated and that other-cause deaths are
# censored, so the two distinctions a reader has to hold are on screen rather than
# only behind the information button.
eqalb_journey_survival_graph <- function() {
  list(
    title = "Time to a first heart attack or stroke",
    qualifier = "Simulated KM estimates; other-cause deaths are censored.",
    times_title = "Read the curves at"
  )
}

# The three states. Each one reads the same curves at the time the learner has chosen:
# the first reads the two estimates, the second shows what a downward movement is, and
# the third compares the two estimates at that one time. Nothing here ranks, tests or
# summarises the curves, and no time is recommended.
eqalb_journey_survival_copy <- function() {
  list(
    title = eqalb_journey_chapter_title("survival"),
    stages = list(
      list(
        id = "time",
        caption = "One final view shows how health events unfold over time.",
        focus = "none",
        beat = "time",
        # The time is the chapter's one control, so activating the figure must not skip
        # the state it belongs to.
        interactive = TRUE,
        advance_label = "What a downward movement is"
      ),
      list(
        id = "step",
        caption = "The curve only moves when someone has a first event.",
        focus = "none",
        beat = "step",
        interactive = TRUE,
        advance_label = "How the two curves compare"
      ),
      list(
        id = "compare",
        caption = "The two curves can be compared at the same time.",
        focus = "none",
        beat = "compare",
        interactive = TRUE
      )
    ),
    advance_label = "Next view of the curves"
  )
}

# The quiet disclosure: what the curves estimate, why a censored estimate is not the
# real-world chance of an event, how the two groups were simulated, and what the curves
# do not say. The hypothetical reading and the distinction from real-world probability
# live here in full; the panel keeps one sentence of it beside the title.
eqalb_journey_survival_disclosure <- function() {
  list(
    title = "What these curves estimate",
    lines = list(
      paste(
        "Each curve estimates the time to a first MI or stroke. Someone who dies of",
        "another cause before an event leaves the group being followed at that point",
        "and is counted as censored, not as an event."
      ),
      paste(
        "That makes the curve the chance of staying free of a first MI or stroke in a",
        "hypothetical world where nobody could die of another cause. It is not the",
        "real-world probability of having an event, because in reality other causes",
        "of death can come first."
      ),
      paste(
        "The shaded band is the estimator's 95% confidence interval around each curve,",
        "and it describes sampling variability in this simulation rather than",
        "uncertainty about the true effect."
      ),
      paste(
        "Both groups are simulated from the case's own annual risks, with 1,000 people",
        "per arm, 10 years of follow-up and a fixed seed. A different seed would move",
        "every number slightly."
      ),
      paste(
        "The curves are not a test of the economic results: they use the same effect",
        "assumption and say nothing about costs, QALYs or the ICER."
      )
    )
  )
}

# One percentage to one decimal place, in R, so every visible share is formatted once.
eqalb_journey_survival_percent <- function(value) {
  if (!is.finite(value)) return("not available")
  paste0(format(round(value * 100, 1), nsmall = 1, trim = TRUE), "%")
}

# The estimate one arm's curve reads at a time: its last step at or before that time.
# It is the same estimator the figure is drawn from, so a sentence can never describe a
# different curve from the one on screen.
eqalb_journey_survival_at <- function(steps, treatment, years) {
  arm <- steps[steps$treatment == treatment, , drop = FALSE]
  index <- which(arm$time_years <= years)
  if (length(index) == 0L) return(NA_real_)
  arm$survival[max(index)]
}

# How many first events one arm recorded in an interval, from the same steps.
eqalb_journey_survival_events_between <- function(steps, treatment, from, to) {
  arm <- steps[steps$treatment == treatment & steps$time_years > from &
    steps$time_years <= to, , drop = FALSE]
  if (nrow(arm) == 0L) return(0)
  sum(arm$n_event)
}

# What one reading says: the two estimates at the chosen time, in R's words. Both
# groups are named in full so the sentence cannot be read as being about one arm.
eqalb_journey_survival_reading <- function(label, usual_display, eqalb_display) {
  paste0(
    "At ",
    label,
    " the curves read ",
    usual_display,
    " for usual care and ",
    eqalb_display,
    " for eQalb plus usual care: the estimated share of each group with no first ",
    "heart attack or stroke by then."
  )
}

# What the downward movement between two times says. It names the two readings and the
# people whose first events produced the fall, and states the one mechanic the state is
# for: the line holds its level between events and steps down when one happens, so it
# never rises.
eqalb_journey_survival_step_note <- function(from_label, to_label, from_display,
                                             to_display, events) {
  paste0(
    "Between ",
    from_label,
    " and ",
    to_label,
    " the usual-care curve falls from ",
    from_display,
    " to ",
    to_display,
    ". Over that year ",
    events,
    if (events == 1) " person" else " people",
    " in the usual-care group had a first event. The line holds its level between ",
    "events and steps down when one happens, so it never rises; each step's height ",
    "is the events at that moment divided by the people still under observation."
  )
}

# What the comparison at one time says, and nothing beyond it: the sign is read from
# R's own numbers, the two estimates are named, and the gap is stated in percentage
# points of the event-free estimate. No test, ratio or median is offered, because the
# chapter compares two readings rather than testing them.
eqalb_journey_survival_compare_note <- function(label, usual_display, eqalb_display,
                                               difference_points, higher) {
  if (is.na(difference_points)) {
    return(paste0("At ", label, " the two curves could not be compared."))
  }
  if (difference_points < 0.05) {
    return(paste0(
      "At ",
      label,
      " the two estimates are level to one decimal place: ",
      usual_display,
      " for usual care and ",
      eqalb_display,
      " for eQalb plus usual care."
    ))
  }
  paste0(
    "At ",
    label,
    " the eQalb estimate is ",
    format(round(difference_points, 1), nsmall = 1, trim = TRUE),
    " percentage points ",
    if (higher) "higher" else "lower",
    " than usual care: ",
    eqalb_display,
    " against ",
    usual_display,
    "."
  )
}

# One label for a year, so the sentences and the choice share one wording.
eqalb_journey_survival_year_label <- function(years) {
  if (years == 1L) "1 year" else paste0(years, " years")
}

# The chapter's calculation: one simulated dataset, the two Kaplan-Meier step sets the
# figure is drawn from, and R's reading of them at each of the three times.
#
# simulate_eqalb_survival() is the function the Simulated survival tab runs, and the
# step coordinates come from the same survfit() estimator summarize_eqalb_survival()
# uses, so the figure, the readings and the tab cannot describe different runs. Every
# number on screen is computed here; the interface only chooses which time to show.
eqalb_journey_survival <- function() {
  inputs <- eqalb_journey_survival_inputs()

  data <- simulate_eqalb_survival(
    n_per_arm = inputs$n_per_arm,
    followup_years = inputs$followup_years,
    seed = inputs$seed,
    rrr = inputs$rrr,
    engagement_year1 = inputs$engagement_year1,
    engagement_followup = inputs$engagement_followup,
    p_mi = inputs$p_mi,
    p_stroke = inputs$p_stroke,
    p_other_death = inputs$p_other_death
  )

  steps <- do.call(rbind, lapply(EQALB_JOURNEY_SURVIVAL_GROUPS, function(group) {
    arm <- data[data$treatment == group, , drop = FALSE]
    fit <- survival::survfit(
      survival::Surv(time_years, event_status) ~ 1,
      data = arm
    )
    data.frame(
      treatment = group,
      time_years = c(0, fit$time),
      survival = c(1, fit$surv),
      lower = c(1, fit$lower),
      upper = c(1, fit$upper),
      n_risk = c(nrow(arm), fit$n.risk),
      n_event = c(0, fit$n.event),
      stringsAsFactors = FALSE
    )
  }))

  usual <- EQALB_JOURNEY_SURVIVAL_GROUPS[[1]]
  eqalb <- EQALB_JOURNEY_SURVIVAL_GROUPS[[2]]

  reads <- lapply(EQALB_JOURNEY_SURVIVAL_TIMES, function(years) {
    label <- eqalb_journey_survival_year_label(years)
    usual_display <- eqalb_journey_survival_percent(
      eqalb_journey_survival_at(steps, usual, years)
    )
    eqalb_display <- eqalb_journey_survival_percent(
      eqalb_journey_survival_at(steps, eqalb, years)
    )
    difference <- (eqalb_journey_survival_at(steps, eqalb, years) -
      eqalb_journey_survival_at(steps, usual, years)) * 100
    from_label <- eqalb_journey_survival_year_label(years - 1L)
    from_display <- eqalb_journey_survival_percent(
      eqalb_journey_survival_at(steps, usual, years - 1L)
    )
    list(
      id = as.character(years),
      years = years,
      label = label,
      arms = list(
        list(
          treatment = usual,
          estimate = eqalb_journey_survival_at(steps, usual, years),
          display = usual_display
        ),
        list(
          treatment = eqalb,
          estimate = eqalb_journey_survival_at(steps, eqalb, years),
          display = eqalb_display
        )
      ),
      reading = eqalb_journey_survival_reading(label, usual_display, eqalb_display),
      difference_points = difference,
      compare = eqalb_journey_survival_compare_note(
        label, usual_display, eqalb_display, abs(difference), difference > 0
      ),
      step = list(
        # The arm the sentence describes and the interval it describes, with the two
        # numbers the figure needs to shade that interval: the year it starts and ends
        # at, and the level the curve reads at its end. They are R's own values, so the
        # shading cannot mark a different interval from the one the sentence names.
        treatment = usual,
        from_years = years - 1L,
        to_years = years,
        to_estimate = eqalb_journey_survival_at(steps, usual, years),
        from_label = from_label,
        to_label = label,
        from_display = from_display,
        to_display = usual_display,
        events = eqalb_journey_survival_events_between(
          steps, usual, years - 1L, years
        ),
        note = eqalb_journey_survival_step_note(
          from_label,
          label,
          from_display,
          usual_display,
          eqalb_journey_survival_events_between(steps, usual, years - 1L, years)
        )
      )
    )
  })

  list(
    inputs = list(
      n_per_arm = inputs$n_per_arm,
      followup_years = inputs$followup_years,
      seed = inputs$seed,
      rrr = inputs$rrr,
      engagement_year1 = inputs$engagement_year1,
      engagement_followup = inputs$engagement_followup,
      p_mi = inputs$p_mi,
      p_stroke = inputs$p_stroke,
      p_other_death = inputs$p_other_death,
      # The response names the simulation it describes, so a stored answer is shown
      # only against the same one.
      survival_key = eqalb_journey_survival_inputs_key()
    ),
    survival = list(
      followup_years = inputs$followup_years,
      steps = steps,
      reads = reads,
      disclosure = eqalb_journey_survival_disclosure(),
      # R's own note for the simulated nature of the data, printed beside the figure
      # with the shorter qualifier the graph block publishes.
      note = SIMULATED_EVENT_NOTE
    ),
    notice = eqalb_tutorial_notice()
  )
}
