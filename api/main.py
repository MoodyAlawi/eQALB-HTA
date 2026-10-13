"""eQalb illustrative HTA model API (FastAPI).

The economic model lives in R (eqalb_markov.R, eqalb_owsa.R, eqalb_survival.R)
and is never re-implemented here. This service validates nothing about the
model numbers: it forwards each request to the R route handlers in
api/plumber.R through the persistent worker pool in api/r_client.py, and
returns the resulting JSON unchanged. That keeps a single source of truth for
every cost, QALY and ICER the project reports.

Contract notes
--------------
* Endpoint names, request fields and response shapes mirror api/plumber.R
  exactly, so the two services are interchangeable on the port they share.
* Scenario parameters are optional. An omitted value means "use the base-case
  constant from eqalb_markov.R"; the R layer owns all defaults and all
  validation, so ranges and messages never drift between the two stacks.
* Analysis controls such as ``wtp``, ``n_sim`` and ``seed`` travel as query
  parameters, exactly as in the plumber contract.
* Every response carries ``notice``: "Simulated illustrative data - not
  clinical evidence".
* All clinical, cost and utility values are simulated and illustrative. This is
  a teaching model, not a validated reimbursement submission.

Run it with api/run_api.py (binds to http://127.0.0.1:8788, docs at /docs).
"""

from __future__ import annotations

import logging
import os
import threading
from contextlib import asynccontextmanager
from typing import Any

from fastapi import Body, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict

try:  # running as api/run_api.py, where api/ is sys.path[0]
    from r_client import RModelError, RModelPool, RModelUnavailable, create_pool
except ImportError:  # running as `uvicorn api.main:app` from the project root
    from api.r_client import RModelError, RModelPool, RModelUnavailable, create_pool

LOGGER = logging.getLogger("eqalb.api")

SIMULATED_NOTICE = "Simulated illustrative data \u2014 not clinical evidence"

SERVICE_NAME = "eQalb illustrative HTA model API"

# The Vite dev server and its preview build are the intended browser clients.
ALLOWED_ORIGINS = [
    "http://127.0.0.1:5173",
    "http://localhost:5173",
    "http://127.0.0.1:4173",
    "http://localhost:4173",
]


# --- Request bodies ----------------------------------------------------------
# Every field is optional: omitted parameters fall back to the base case in
# eqalb_markov.R. Unknown fields are allowed and forwarded, so a parameter added
# to the R model is usable immediately without touching this file.


class ScenarioInputs(BaseModel):
    """Deterministic model inputs (all optional; R supplies the base case)."""

    model_config = ConfigDict(extra="allow")

    intervention_price: float | None = None
    implementation_cost: float | None = None
    healthcare_savings: float | None = None
    rrr: float | None = None
    engagement_year1: float | None = None
    engagement_followup: float | None = None
    utility_no_event: float | None = None
    utility_post_mi: float | None = None
    utility_post_stroke: float | None = None
    cost_post_mi_year1: float | None = None
    cost_post_mi_followup: float | None = None
    cost_post_stroke_year1: float | None = None
    cost_post_stroke_followup: float | None = None
    discount_rate_cost: float | None = None
    discount_rate_effect: float | None = None
    cycles: int | None = None


class BaseCaseRequest(ScenarioInputs):
    """Base-case inputs; query parameter ``wtp`` sets the net-benefit threshold."""


class PsaRequest(ScenarioInputs):
    """PSA inputs; query parameters ``n_sim``, ``seed``, ``wtp``, ``max_wtp``."""


class OwsaBounds(BaseModel):
    """One supplied one-way range; ``id`` must match an id in
    ``eqalb_owsa_range_specs()`` (eqalb_owsa.R), which is the list
    ``POST /api/owsa-defaults`` returns."""

    model_config = ConfigDict(extra="allow")

    id: str | None = None
    low: float | None = None
    high: float | None = None


class OwsaRequest(ScenarioInputs):
    """One-way sensitivity inputs; ``outcome`` and ``bounds`` are optional."""

    outcome: str | None = None
    bounds: list[OwsaBounds] | None = None


class BudgetImpactRequest(ScenarioInputs):
    """Budget-impact inputs; the fields below default to the Shiny app values."""

    population: float | None = None
    year1_uptake_pct: float | None = None
    annual_uptake_increase_pp: float | None = None
    horizon_years: float | None = None
    avoided_event_savings_per_active_user: float | None = None
    followup_engagement_pct: float | None = None


class ValueOfInformationRequest(BaseModel):
    """Value of information from PSA draws supplied by the client.

    ``results`` is the ``results`` array returned by /api/psa, so the expensive
    PSA is never rerun for a VOI calculation.
    """

    model_config = ConfigDict(extra="allow")

    results: list[dict[str, Any]] | None = None


class SurvivalRequest(ScenarioInputs):
    """Simulated survival inputs; ``n_per_arm``, ``followup_years``, ``seed`` etc."""

    n_per_arm: float | None = None
    followup_years: float | None = None
    seed: float | None = None
    p_mi: float | None = None
    p_stroke: float | None = None
    p_other_death: float | None = None


class ReadinessRequest(BaseModel):
    """DHT readiness inputs for calculate_readiness() in eqalb_readiness.R.

    Units follow the R function and the Shiny full-analysis readiness tab, so
    nothing is rescaled on the way in: ``digital_access``, ``digital_suitability``,
    ``readiness_year1_engagement`` and ``readiness_followup_engagement`` are
    percentages (0-100), ``review_minutes`` is minutes per patient per month, and
    ``interoperability`` / ``algorithm_governance`` must be one of the levels
    returned by /api/defaults under ``readiness.choices``. An omitted value means
    "use the readiness default" (the values the Shiny tab preselects).
    """

    model_config = ConfigDict(extra="allow")

    target_population: float | None = None
    digital_access: float | None = None
    digital_suitability: float | None = None
    readiness_year1_engagement: float | None = None
    readiness_followup_engagement: float | None = None
    review_minutes: float | None = None
    supported_languages: float | None = None
    accessibility_features: bool | None = None
    interoperability: str | None = None
    algorithm_governance: str | None = None


class HtaSummaryRequest(ScenarioInputs):
    """HTA decision-summary inputs: completed analyses plus readiness.

    Every field is optional. A field that is omitted means "that analysis has
    not been run", and the R decision-summary functions then report their own
    "Not available" / "Not yet available" wording; nothing is guessed here or in
    the R layer. ``wtp`` is the reference threshold (also accepted as a query
    parameter). The scenario fields inherited from ``ScenarioInputs`` are the
    evidence-priority signals (price, implementation cost, savings, relative
    risk reduction and the two engagement values). ``readiness`` carries the
    same inputs as POST /api/readiness; the seven domains are derived in R, so
    domain statuses are never accepted from the client.
    """

    wtp: float | None = None
    icer: float | None = None
    probability_cost_effective: float | None = None
    mean_incremental_nmb: float | None = None
    evpi: float | None = None
    highest_evppi: float | None = None
    cumulative_budget_impact: float | None = None
    bia_intervention_cost: float | None = None
    bia_implementation_cost: float | None = None
    bia_healthcare_savings: float | None = None
    evppi_table: list[dict[str, Any]] | None = None
    readiness: dict[str, Any] | None = None


class TutorialPart1Request(BaseModel):
    """Guided Tutorial Part 1 controls for ``eqalb_tutorial_part1()``.

    Only the tutorial's own nine controls are accepted. Every other value the
    tutorial needs is an R-owned tutorial constant, so a tutorial request can
    never read or move a full-analysis setting. An omitted field takes the
    tutorial default from ``GET /api/tutorial`` (``part1.defaults``), and a value
    outside a control's own range is rejected by R with its own message.

    ``utility_post_mi`` and ``utility_post_stroke`` are deliberately not
    accepted: the tutorial's post-event utilities are fixed R constants, so the
    two values cannot be influenced from the client.
    """

    model_config = ConfigDict(extra="allow")

    tutorial_price: float | None = None
    tutorial_rrr: float | None = None
    tutorial_engagement_year1: float | None = None
    tutorial_engagement_followup: float | None = None
    tutorial_utility_no_event: float | None = None
    tutorial_population: float | None = None
    tutorial_review_minutes: float | None = None
    tutorial_interop_available: bool | None = None
    tutorial_language_available: bool | None = None


class TutorialPart2CaseRequest(BaseModel):
    """Guided Tutorial Part 2 case creation or resume.

    With no ``case_id`` R draws a case for a new session and returns its opaque
    handle. With the handle it returns that same case unchanged, so a client
    resumes instead of re-drawing. ``exclude_case_id`` exists for the retry rule
    and is not used by this slice's interface. ``seed`` exists so a fixture can
    pin the draw. No case internals are exposed: the handle carries no meaning a
    client could select on.
    """

    model_config = ConfigDict(extra="allow")

    case_id: str | None = None
    exclude_case_id: str | None = None
    seed: float | None = None


class TutorialPart2EvaluateRequest(BaseModel):
    """Guided Tutorial Part 2 evaluation for one case, price and coverage cap.

    ``case_id`` and ``price`` are the value-for-money request; ``coverage`` is the
    budget-impact section's lever and is optional, taking the contract's default
    when omitted. ``curve`` is optional: it is the curve the same case already
    returned, and posting it lets R re-classify the curve instead of re-running its
    forty-three model runs, so moving the price lever costs one model run. R
    decides which points meet the payer's threshold, the highest acceptable price,
    the maximum affordable coverage and every affordability status in both paths,
    so nothing about a status, a threshold, a price or a coverage cap is taken from
    the caller.

    ``interoperability``, ``governance``, ``clinical_workflow`` and
    ``patient_engagement`` are the DHT readiness exercise's four answers. Each is
    an optional short level id; R validates it against the levels it accepts,
    maps it onto the readiness input it represents and decides every readiness
    status, so no readiness input is taken from the caller either.
    """

    model_config = ConfigDict(extra="allow")

    case_id: str | None = None
    price: float | None = None
    coverage: float | None = None
    curve: dict[str, Any] | None = None
    interoperability: str | None = None
    governance: str | None = None
    clinical_workflow: str | None = None
    patient_engagement: str | None = None


class ValueBasedPriceRequest(ScenarioInputs):
    """Value-based price inputs.

    ``current_price`` is the annual intervention price the analysis runs at and
    compares the maximum acceptable price against; when it is absent, the body's
    ``intervention_price`` (or the model's base-case constant) is used, so the
    model run, the price solve and the headroom always describe one price.
    ``wtp`` is the reference threshold, also accepted as a query parameter.
    """

    current_price: float | None = None
    wtp: float | None = None


def query_docs(*parameters: tuple[str, str]) -> dict[str, Any]:
    """Describe pass-through query parameters in the OpenAPI schema.

    The R layer reads these from the raw query string, so they are documented
    here rather than declared as typed arguments: the R model stays the only
    place that validates them and applies its own defaults.
    """
    return {
        "parameters": [
            {
                "name": name,
                "in": "query",
                "required": False,
                "schema": {"type": "string"},
                "description": description,
            }
            for name, description in parameters
        ]
    }


# --- Application -------------------------------------------------------------


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.pool = None
    app.state.model_error = None
    try:
        pool = create_pool()
    except RModelUnavailable as error:
        app.state.model_error = str(error)
        LOGGER.error("The R model is unavailable: %s", error)
    else:
        app.state.pool = pool
        # Warm the workers in the background so startup is not blocked by R.
        worker = threading.Thread(target=_warmup, args=(pool,), daemon=True)
        worker.start()
    try:
        yield
    finally:
        if app.state.pool is not None:
            app.state.pool.close()


def _warmup(pool: RModelPool) -> None:
    try:
        pool.warmup()
        LOGGER.info("Model workers ready: %s", pool.status())
    except Exception as error:  # noqa: BLE001 - surfaced through /api/health
        LOGGER.error("Model warm-up failed: %s", error)


app = FastAPI(
    title=SERVICE_NAME,
    version="2.0.0",
    description=(
        "HTTP wrapper around the eQalb R model modules. Every number is "
        "computed in R; this service only transports requests. "
        + SIMULATED_NOTICE
        + "."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=r"http://(127\.0\.0\.1|localhost):\d+",
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


def get_pool(request: Request) -> RModelPool:
    pool = getattr(request.app.state, "pool", None)
    if pool is None:
        raise HTTPException(
            status_code=503,
            detail=(
                request.app.state.model_error
                or "The R model is unavailable. Start it with api/run_api.py."
            ),
        )
    return pool


def call_model(
    request: Request, endpoint: str, body: BaseModel | None = None
) -> dict[str, Any]:
    """Forward one request to the R model and translate its errors."""
    pool = get_pool(request)
    payload = body.model_dump(exclude_none=True) if body is not None else {}
    try:
        return pool.request(endpoint, dict(request.query_params), payload)
    except RModelError as error:
        # Input problems detected by the R layer, e.g. "'rrr' must be between
        # 0 and 1." Passed through verbatim so the UI can show the R message.
        raise HTTPException(status_code=400, detail=str(error)) from error
    except RModelUnavailable as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@app.get("/", summary="Service pointer")
def root() -> dict[str, Any]:
    """Points at the interactive docs and the Vue frontend."""
    return {
        "service": SERVICE_NAME,
        "docs": "/docs",
        "openapi": "/openapi.json",
        "frontend": "http://127.0.0.1:5173 (npm run dev in frontend/)",
        "model": "R modules rendered through api/plumber.R handlers",
        "notice": SIMULATED_NOTICE,
    }


@app.get("/api/health", summary="Liveness and model-module status")
def health(request: Request) -> dict[str, Any]:
    """Reports service liveness and which R model modules loaded.

    Returns 200 with ``status: "degraded"`` when the R model is not reachable,
    so a browser can explain the problem instead of showing a transport error.
    """
    pool = getattr(request.app.state, "pool", None)
    if pool is None:
        return {
            "status": "degraded",
            "service": SERVICE_NAME,
            "error": request.app.state.model_error
            or "The R model is unavailable.",
            "r_model": {"configured_workers": 0, "ready_workers": 0},
            "notice": SIMULATED_NOTICE,
        }

    status = pool.status()
    try:
        model = call_model(request, "health")
    except HTTPException as error:
        # A worker that cannot answer is a health finding, not a failure of the
        # health endpoint.
        return {
            "status": "degraded",
            "service": SERVICE_NAME,
            "error": str(error.detail),
            "r_model": status,
            "notice": SIMULATED_NOTICE,
        }

    ready = status["ready_workers"] > 0 and bool(model.get("model_ready"))
    return {
        **model,
        "status": "ok" if ready else "degraded",
        "service": SERVICE_NAME,
        "r_model": status,
        "r_model_error": status.get("startup_error"),
        "notice": model.get("notice", SIMULATED_NOTICE),
    }


@app.get("/api/defaults", summary="Base-case values, UI contract, defaults")
def defaults(request: Request) -> dict[str, Any]:
    """Base-case constants from eqalb_markov.R, the parameter-form contract, the
    one-way sensitivity-analysis ranges derived for that base case, the
    simulation defaults and the analysis explanations, so the client cannot drift
    from the R base case or from the wording the Shiny app shows.

    ``info_text`` and each parameter's ``info`` field carry ``CC_INFO_TEXT`` from
    eqalb_ui_copy.R verbatim; only the keys the browser interface uses are
    published (see api_contract.md). ``owsa_parameters`` rows are the ranges
    ``POST /api/owsa`` derives, in the shape that endpoint echoes them.
    """
    return call_model(request, "defaults")


@app.post(
    "/api/base-case",
    summary="Deterministic base case",
    openapi_extra=query_docs(("wtp", "Willingness-to-pay threshold in EUR per QALY. Default 100000.")),
)
def base_case(
    request: Request,
    body: BaseCaseRequest | None = Body(default=None),
) -> dict[str, Any]:
    """Incremental cost, incremental QALYs, ICER, net monetary benefit and the
    reconciled cost/QALY component decomposition. The parts always sum to the
    totals (checked in R); ``cost_effective`` compares NMB with the threshold."""
    return call_model(request, "base-case", body)


@app.post(
    "/api/psa",
    summary="Probabilistic sensitivity analysis, CEAC and cloud",
    openapi_extra=query_docs(
        ("n_sim", "Number of simulations, 100-10000 in steps of 100. Default 1000."),
        ("seed", "Random seed (minimum 1), so results are reproducible. Default 12345."),
        ("wtp", "Willingness-to-pay threshold in EUR per QALY. Default 100000."),
        ("max_wtp", "Upper x-axis limit of the CEAC. Default max(150000, 2 x wtp)."),
    ),
)
def psa(request: Request, body: PsaRequest | None = Body(default=None)) -> dict[str, Any]:
    """PSA summary (means, median ICER, probability cost-effective), the CEAC
    curve and the simulation cloud. ``results`` carries every draw so it can be
    posted back to /api/value-of-information without rerunning the PSA."""
    return call_model(request, "psa", body)


@app.post(
    "/api/owsa",
    summary="One-way sensitivity analysis (tornado)",
    openapi_extra=query_docs(
        (
            "outcome",
            "Ranking outcome: one of inmb, incremental_qalys, incremental_cost "
            "(see eqalb_owsa_outcome_labels). Default inmb.",
        ),
        ("wtp", "Willingness-to-pay threshold in EUR per QALY. Default 100000."),
    ),
)
def owsa(request: Request, body: OwsaRequest | None = Body(default=None)) -> dict[str, Any]:
    """Ranked tornado table plus the base outcome. Optional ``bounds`` rows
    ({id, low, high}) replace the range R derives from the submitted scenario for
    the parameter they name; ``bounds`` in the response carries the ranges in
    force, each labelled with R's own source, rationale and model-default or
    adjusted state. A range R cannot use is rejected with R's own sentence.

    ``summary`` is the interpretation R writes with summarize_eqalb_owsa() — the base
        case and its decision reference, the parameters that move the selected outcome
        most, whether the conclusion survives the tested ranges, and the one-way
        limitation, one sentence per line — and ``summary_note`` the paragraph above it;
        both are R's own wording."""
    return call_model(request, "owsa", body)


@app.post(
    "/api/owsa-defaults",
    summary="One-way ranges for a scenario, without running the analysis",
)
def owsa_defaults(
    request: Request,
    body: OwsaRequest | None = Body(default=None),
) -> dict[str, Any]:
    """The same ``bounds`` block ``POST /api/owsa`` returns, derived for the
    submitted scenario and without running a single model run, so a range editor
    always shows the ranges that are in force for the assumptions in the form.

    Optional ``bounds`` rows are applied and judged the same way; a range R cannot
    use is reported in that row (``range_status`` ``invalid`` and R's sentence in
    ``range_note``) instead of failing the request, because a range editor needs
    the sentence while the caller is still choosing values. An optional ``outcome``
    is accepted and ignored: the ranges do not depend on the ranking."""
    return call_model(request, "owsa-defaults", body)


@app.post("/api/budget-impact", summary="Five-year budget impact")
def budget_impact(
    request: Request,
    body: BudgetImpactRequest | None = Body(default=None),
) -> dict[str, Any]:
    """Per-year eligible population, uptake, gross intervention cost,
    implementation cost, healthcare and avoided-event savings, and the net and
    cumulative budget impact. Horizon defaults to 5 years, population to 70000."""
    return call_model(request, "budget-impact", body)


@app.post(
    "/api/value-of-information",
    summary="EVPI and EVPPI from supplied PSA draws",
    openapi_extra=query_docs(("wtp", "Willingness-to-pay threshold in EUR per QALY. Default 100000.")),
)
def value_of_information(
    request: Request,
    body: ValueOfInformationRequest | None = Body(default=None),
) -> dict[str, Any]:
    """EVPI per patient and regression-based EVPPI per patient for the sampled
    PSA parameters, reusing the ``results`` array posted by the client."""
    return call_model(request, "value-of-information", body)


@app.post("/api/survival", summary="Simulated Kaplan-Meier analysis")
def survival(
    request: Request, body: SurvivalRequest | None = Body(default=None)
) -> dict[str, Any]:
    """Simulated Kaplan-Meier steps with confidence bands, the risk table, the
    arm summary, diagnostics, expected event counts, the log-rank contrast and the
    traffic-light interpretation.

    ``interpretation`` is the unchanged result of R's
    ``assess_km_interpretation()`` (eqalb_km_interpretation.R, the function the
    Shiny Kaplan-Meier tab calls) and ``logrank_note`` is R's descriptive
    log-rank line; no status or wording is produced here.
    """
    return call_model(request, "survival", body)


@app.post(
    "/api/readiness",
    summary="DHT readiness and implementation assessment",
)
def readiness(
    request: Request, body: ReadinessRequest | None = Body(default=None)
) -> dict[str, Any]:
    """Illustrative DHT readiness assessment from ``calculate_readiness()``.

    Returns the calculation object unchanged: the five engagement and workload
    figures, the ``numbers``, ``domains`` and ``cards`` tables, the
    Green/Amber/Red ``counts`` and the plain-language ``interpretation``. Sharing
    and scoring rules live in eqalb_readiness.R; the endpoint only validates the
    inputs and passes them on, so the readiness logic exists once.
    """
    return call_model(request, "readiness", body)


@app.post(
    "/api/hta-summary",
    summary="HTA decision summary and evidence priorities",
    openapi_extra=query_docs(
        ("wtp", "Reference willingness-to-pay threshold in EUR per QALY. Default 100000.")
    ),
)
def hta_summary(
    request: Request, body: HtaSummaryRequest | None = Body(default=None)
) -> dict[str, Any]:
    """Traffic-light decision summary from completed analyses.

    Returns ``assess_hta_decision_summary()`` unchanged (the five ``domains``,
    ``overall_status``, ``position`` and ``interpretation``) and
    ``build_hta_evidence_priorities()`` unchanged (``table`` and ``summary``),
    plus ``availability`` describing which upstream analyses were supplied and the
    three rule strings from eqalb_ui_copy.R (``rules``, ``evidence_note`` and
    ``rule_note``) that the Shiny tab shows, verbatim. Both functions live in
    eqalb_markov.R; this route only transports their inputs and output, so no
    status, threshold, wording or priority is computed outside R.
    """
    return call_model(request, "hta-summary", body)


@app.post(
    "/api/value-based-price",
    summary="Value-based price, headroom and required effect",
    openapi_extra=query_docs(
        (
            "wtp",
            "Reference willingness-to-pay threshold in EUR per QALY. Default 100000.",
        )
    ),
)
def value_based_price(
    request: Request, body: ValueBasedPriceRequest | None = Body(default=None)
) -> dict[str, Any]:
    """Highest annual price the model supports at the reference threshold.

    Returns the price solve (``max_acceptable_price``, ``status``, the headroom
    against ``current_price`` and the verification residual), the relative risk
    reduction the current price would require, and the 3 x 3 scan across the
    model's own relative-risk-reduction and year-1 engagement bounds. Every
    figure comes from ``calculate_value_based_price()`` (eqalb_price.R), which
    reads ``run_eqalb_model()`` outputs only; ``availability`` reports which
    values the model could identify and why an unavailable one is unavailable.
    """
    return call_model(request, "value-based-price", body)


@app.get(
    "/api/tutorial",
    summary="Guided Tutorial Part 1 contract: defaults, controls, wording",
)
def tutorial(request: Request) -> dict[str, Any]:
    """The Guided Tutorial Part 1 contract, so the client cannot drift from it.

    Returns ``part1`` only: the tutorial's own defaults, one row per control with
    its label, unit, valid range, step and explanation (from ``CC_INFO_TEXT``),
    the fixed R-owned values the tutorial uses — including the post-event
    utilities — the step titles and objectives, and the instructional wording the
    steps show before any calculation. Building the contract runs no model.

    The full-analysis contract stays at ``GET /api/defaults``; the tutorial
    values are deliberately not mixed into it.
    """
    return call_model(request, "tutorial")


@app.post(
    "/api/tutorial/part1",
    summary="Guided Tutorial Part 1 results for all four steps",
)
def tutorial_part1(
    request: Request, body: TutorialPart1Request | None = Body(default=None)
) -> dict[str, Any]:
    """Every Part 1 result in one deterministic response.

    Returns the base case and its cost-effectiveness presentation data, the
    budget-impact result with its annual table and chart series, the readiness
    assessment restricted to the domains the tutorial shows, and the
    tutorial-only decision summary — with the statuses, interpretations, table
    rows and formatted strings all produced by ``eqalb_tutorial_part1()`` in
    eqalb_tutorial.R. The tutorial's simplified traffic-light rules deliberately
    differ from the full-analysis rules and are returned by the contract.

    The work is a handful of model runs, so the client may re-request it as the
    learner moves a slider. Nothing in the response is derived outside R, and the
    same body always returns the same response.
    """
    return call_model(request, "tutorial-part1", body)


@app.get(
    "/api/tutorial/part2",
    summary="Guided Tutorial Part 2 contract: sections, copy, price control",
)
def tutorial_part2(request: Request) -> dict[str, Any]:
    """The Guided Tutorial Part 2 contract, so the client cannot drift from it.

    Returns ``part2`` only: the five section names with only the two this slice
    implements marked available, the R-owned instructional copy (brief, task
    statement, lever hint, case-facts headings and overlay labels), the
    negotiated-price control's metadata including its explanation, the
    value-for-money presentation labels and status wording, the chart's title,
    caption, axis names, legend entries and series colours, and the fixed inputs
    the later sections will use. Building it runs no model and draws no case.
    """
    return call_model(request, "tutorial-part2")


@app.post(
    "/api/tutorial/part2/case",
    summary="Create or resume a Guided Tutorial Part 2 case",
)
def tutorial_part2_case(
    request: Request, body: TutorialPart2CaseRequest | None = Body(default=None)
) -> dict[str, Any]:
    """Creates a case, or returns the one the caller already holds.

    The response carries the opaque ``case_id`` (the only part of the draw a
    client ever stores or sends), the case's label, title, heading and banner
    sentence, all fourteen read-only case facts, the brief's introduction, the
    price lever's initial value and the case's complete 43-point price curve with
    R's pass/fail classification and the highest acceptable price. It also
    publishes the fixed per-case inputs the later sections will use, derived from
    the case rather than from any dashboard setting.

    The curve is one model run per lever value, so this call costs about forty
    four model runs and belongs behind an explicit action with progress. An
    unknown handle is an R error rather than a silent re-draw, so one case's
    facts can never appear beside another case's numbers.
    """
    return call_model(request, "tutorial-part2-case", body)


@app.post(
    "/api/tutorial/part2/evaluate",
    summary="Part 2 value-for-money and budget-impact result for one case",
)
def tutorial_part2_evaluate(
    request: Request,
    body: TutorialPart2EvaluateRequest | None = Body(default=None),
) -> dict[str, Any]:
    """The value-for-money and budget-impact result for one case.

    ``price`` drives the value-for-money section and both sections share it;
    ``coverage`` is the budget-impact section's own lever and affects only the
    case's budget-impact population, never the per-person result or the price
    curve. The response carries the current-price card (its state, the model detail
    behind it and the nudge towards the one lever that can change the case), the
    highest acceptable negotiated price, the current-price marker, the full price
    curve with R's per-point pass/fail classification, the covered and potentially
    eligible populations, the five annual budget-impact rows with their formatted
    values and chart series, the five-year total with R's own summary sentence, the
    affordability state and message, the maximum affordable coverage at this price,
    the current-settings line and the annual disclosure's headings and wording.

    Every status, threshold, formatted string, chart label, row and sentence comes
    from ``eqalb_tutorial_part2_evaluate()`` in eqalb_tutorial.R, including the
    maximum affordable coverage, which R finds by evaluating the permitted coverage
    steps against the case ceiling rather than by any formula the client could
    invert. The client renders them and classifies nothing.

    The optional ``curve`` is the curve this case already returned, and posting it
    makes R re-classify that curve instead of re-running it, so a price change
    costs one model run rather than forty-four. R derives the classifications and
    the highest acceptable price in both paths, so a caller cannot supply a
    status, and both paths return the same response.
    """
    return call_model(request, "tutorial-part2-evaluate", body)


def main() -> None:
    import uvicorn

    host = os.environ.get("EQALB_API_HOST", "127.0.0.1")
    port = int(os.environ.get("EQALB_API_PORT", "8788"))
    logging.basicConfig(
        level=os.environ.get("EQALB_LOG_LEVEL", "INFO").upper(),
        format="%(levelname)s %(name)s: %(message)s",
    )
    print(f"eQalb model API on http://{host}:{port} (docs at /docs)")
    print(SIMULATED_NOTICE + ".")
    uvicorn.run(app, host=host, port=port, log_level="info")


if __name__ == "__main__":
    main()
