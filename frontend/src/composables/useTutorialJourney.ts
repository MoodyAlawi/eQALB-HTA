/**
 * The Journey's own session.
 *
 * It is deliberately separate from the analysis app: the journey has its own
 * screen, its own case and its own one lever, and it never reads or writes the
 * `useModel` store, so editing the dashboard cannot move a journey result.
 *
 * Everything the learner reads comes from R. This module holds the state a
 * session needs — which chapter is on screen, which state of the chapter's single
 * graph the learner has reached, the price they moved, and the two results — and
 * sends the price. It calculates nothing, compares nothing with a threshold and
 * interprets nothing.
 *
 * Chapter 1 has no forward control: the learner moves between the graph's states
 * by activating the graph, which is a learner action rather than a timer, so this
 * module advances one state per activation and nothing advances on its own.
 */

import { computed, ref, shallowRef, watch } from 'vue'
import {
  fetchTutorialJourney,
  postTutorialJourneyBaseCase,
  postTutorialJourneyBudget,
  postTutorialJourneyPrice,
  postTutorialJourneyReadiness,
  postTutorialJourneySensitivity,
  postTutorialJourneySurvival,
  postTutorialJourneyUncertainty,
  postTutorialJourneyVoi,
} from '../api/client'
import type {
  JourneyBaseCaseResponse,
  JourneyBudgetCandidate,
  JourneyBudgetCoverage,
  JourneyBudgetResponse,
  JourneyContractResponse,
  JourneyModuleIdentity,
  JourneyPlaneLabels,
  JourneyPriceResponse,
  JourneyPriceSolvePayload,
  JourneyReadinessAnswerKey,
  JourneyReadinessAnswers,
  JourneyReadinessResponse,
  JourneyRecap,
  JourneyStage,
  JourneySensitivityResponse,
  JourneySurvivalResponse,
  JourneyUncertaintyResponse,
  JourneyVoiResponse,
} from '../api/types'
import { useAppBusy } from './useAppBusy'

/** One slider drag is one request: movement is coalesced, not queued. */
const ADJUST_DEBOUNCE_MS = 220

/**
 * The chapter ids R publishes. They are stable, so code may name them; nothing
 * depends on their number or their order, which R's chapter list owns.
 */
const UNCERTAINTY_CHAPTER_ID = 'uncertainty'
const SENSITIVITY_CHAPTER_ID = 'sensitivity'
const VOI_CHAPTER_ID = 'voi'
const PRICE_CHAPTER_ID = 'price'
const BUDGET_CHAPTER_ID = 'budget'
const READINESS_CHAPTER_ID = 'readiness'
const SURVIVAL_CHAPTER_ID = 'survival'

/**
 * The status sentence the app-wide loader shows for each chapter's calculation.
 * It is the learner-facing name of what is happening, so it is stated once, here,
 * and the shared loader renders whichever the open bridge started.
 */
const LOADING_LABELS: Record<string, string> = {
  [UNCERTAINTY_CHAPTER_ID]: 'Simulating how much the comparison can vary…',
  [SENSITIVITY_CHAPTER_ID]: 'Testing one assumption at a time…',
  [VOI_CHAPTER_ID]: 'Valuing better evidence…',
  [PRICE_CHAPTER_ID]: 'Working out the balance at each price…',
  [BUDGET_CHAPTER_ID]: 'Totalling what adoption would cost…',
  [READINESS_CHAPTER_ID]: 'Checking what delivery would take…',
  [SURVIVAL_CHAPTER_ID]: 'Simulating how events fall over time…',
}

const appBusy = useAppBusy()

const contract = shallowRef<JourneyContractResponse | null>(null)
const contractBusy = ref(false)
const contractError = ref<string | null>(null)

/** The chapter on screen, by R's own id. */
const chapterId = ref<string>('')

const price = ref<number | null>(null)
/**
 * The scenario's second lever: the no-event quality-of-life score. It is a model
 * input, so it travels in the body of every request whose calculation reads it, and a
 * change to either lever invalidates everything derived from the previous scenario.
 *
 * Null before the contract arrives, then seeded from R's own default.
 */
const utility = ref<number | null>(null)
const initialResult = shallowRef<JourneyBaseCaseResponse | null>(null)
const adjustedResult = shallowRef<JourneyBaseCaseResponse | null>(null)
const evaluateBusy = ref(false)
const evaluateError = ref<string | null>(null)

const uncertaintyResult = shallowRef<JourneyUncertaintyResponse | null>(null)
/**
 * A simulation is in flight. It is deliberately separate from whether the shared
 * loading screen is showing: the recap stays readable while this is true, and the
 * loader appears only when the learner asks to leave the recap before the answer
 * has arrived.
 */
const uncertaintyBusy = ref(false)
const uncertaintyError = ref<string | null>(null)

/** Chapter 3's two rankings, once R has returned them. */
const sensitivityResult = shallowRef<JourneySensitivityResponse | null>(null)
const sensitivityBusy = ref(false)
const sensitivityError = ref<string | null>(null)

/** Chapter 4's value of information, once R has valued the draws it was given. */
const voiResult = shallowRef<JourneyVoiResponse | null>(null)
const voiBusy = ref(false)
const voiError = ref<string | null>(null)
/**
 * The very PSA response the value of information was computed from, and the
 * reference value it was computed at. The answer is reused only while both still
 * describe the comparison on screen: a price change replaces the PSA response
 * object, so a value derived from a different set of draws can never be shown
 * against this one — the cache is keyed by the source, not by the price.
 */
const voiSource = shallowRef<JourneyUncertaintyResponse | null>(null)
const voiThreshold = ref<number | null>(null)

/**
 * Chapter 5's price comparison.
 *
 * There is no price lever in this chapter: it compares the price the learner chose in
 * the base case with the price at which the balance reaches zero. The answers are
 * cached against the scenario R names — which folds in both levers — and the price they
 * describe, so a cached response can never be shown against a different scenario. The
 * solve is separate from the per-scenario answers because the price at which the
 * balance reaches zero is a property of the case and the reference rather than of the
 * price being looked at; it is stored with the scenario key it was solved for and
 * dropped whenever that scenario changes.
 */
const priceResult = shallowRef<JourneyPriceResponse | null>(null)
const priceSolve = shallowRef<JourneyPriceSolvePayload | null>(null)
const priceSolveKey = ref<string | null>(null)
const priceBusy = ref(false)
const priceError = ref<string | null>(null)
/** The scenario-and-price key of the request in flight, so a repeat is refused. */
const priceInFlight = ref<string | null>(null)
const priceAnswers = new Map<string, JourneyPriceResponse>()
let priceToken = 0

/**
 * Chapter 6's budget impact.
 *
 * One selection is local to this chapter: what share of the population to cover. It is
 * not written back to the journey, so nothing earlier changes when the cap moves.
 *
 * One response carries the whole coverage sweep for the journey's one price, so the
 * coverage lever selects a row R has already computed and never asks again. The answer
 * is cached against the price it was computed for, so re-entering the chapter with the
 * same price costs nothing and a different price fetches its own sweep.
 */
const budgetPrice = ref<number | null>(null)
const budgetCoverage = ref<number | null>(null)
const budgetResult = shallowRef<JourneyBudgetResponse | null>(null)
const budgetBusy = ref(false)
const budgetError = ref<string | null>(null)
/** The price whose sweep is in flight, so an identical request is refused. */
const budgetInFlight = ref<number | null>(null)
const budgetAnswers = new Map<number, JourneyBudgetResponse>()
let budgetToken = 0

/**
 * Chapter 7's readiness assessment.
 *
 * The learner's four answers are the only thing this chapter can move, and they live
 * here rather than in the chapter component so that going Back and returning keeps
 * them. The assessment reads none of the economic scenario — it is arithmetic over the
 * case's own ten inputs, four of them the answers — so a price or score change does
 * not invalidate it and it is deliberately absent from `invalidateDerivedResults()`.
 *
 * Its answers are cached against R's own `readiness_key`, which names every input the
 * assessment received: the four answers *and* the six the case fixes. A changed fixed
 * input therefore cannot be served from a cache entry computed against different ones.
 */
const readinessAnswers = ref<Partial<JourneyReadinessAnswers>>({})
const readinessResult = shallowRef<JourneyReadinessResponse | null>(null)
const readinessBusy = ref(false)
const readinessError = ref<string | null>(null)
/** The answer set whose assessment is in flight, so a duplicate is refused. */
const readinessInFlight = ref<string | null>(null)
const readinessAnswersCache = new Map<string, JourneyReadinessResponse>()
let readinessToken = 0

/**
 * Chapter 8's simulated survival curves.
 *
 * The simulation reads no price and no quality-of-life score, so the chapter is
 * deliberately absent from `invalidateDerivedResults()`: moving either lever earlier in
 * the journey cannot change these curves, and re-simulating them would suggest it could.
 *
 * Its answer is cached against the key R composes from every input the simulation reads
 * — the sample size, the follow-up, the seed, the effect assumption and the three annual
 * risks — so a stored answer is reused only while it describes the same simulation, and
 * a contract that changed any of them would not be served the old one. The chosen time
 * is chapter state, not an input: one response carries all three times.
 */
const survivalTime = ref<string | null>(null)
const survivalResult = shallowRef<JourneySurvivalResponse | null>(null)
const survivalBusy = ref(false)
const survivalError = ref<string | null>(null)
/** The key whose simulation is in flight, so an identical request is refused. */
const survivalInFlight = ref<string | null>(null)
const survivalAnswers = new Map<string, JourneySurvivalResponse>()
let survivalToken = 0

/** Which chapter's work the bridge on screen is waiting for. */
const loaderLabel = ref(LOADING_LABELS[UNCERTAINTY_CHAPTER_ID] ?? '')

/** Whether the bridge between the two chapters is on screen. */
const recapVisible = ref(false)

/**
 * Whether the shared loading screen should show for the simulation.
 *
 * The request's own in-flight state (`uncertaintyBusy`) is not the same thing: the
 * recap has to stay readable while the simulation runs, so the loader is switched on
 * only when the learner leaves the recap before the answer has arrived, and switched
 * off again the moment it lands.
 */
const showingLoader = ref(false)

/** The chapter to open as soon as the simulation answers, if one is waiting. */
const pendingChapterId = ref<string | null>(null)

/** Which state of the chapter's single graph the learner has reached. */
const stageIndex = ref(0)

let contractRequest: Promise<void> | null = null
let evaluateToken = 0
let uncertaintyToken = 0
let sensitivityToken = 0
let voiToken = 0
let adjustTimer: ReturnType<typeof setTimeout> | null = null

function describe(error: unknown): string {
  if (error instanceof Error && error.message) return error.message
  return 'The journey results could not be loaded.'
}

/** Fills R's progress template, e.g. "Chapter {step} of {total}. {title}". */
function fill(template: string, values: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (match, key: string) =>
    key in values ? String(values[key]) : match,
  )
}

const chapters = computed(() => contract.value?.journey.chapters ?? [])

const chapterIndex = computed(() => {
  const index = chapters.value.findIndex((chapter) => chapter.id === chapterId.value)
  return index < 0 ? 0 : index
})

/** The chapter's position in R's list, which is what the stage animates between. */
const chapterStep = computed(() => chapterIndex.value + 1)

const currentChapter = computed(() => chapters.value[chapterIndex.value] ?? null)

const progressText = computed(() => {
  const source = contract.value
  const chapter = currentChapter.value
  if (!source || !chapter) return ''
  return fill(source.journey.progress.step_template, {
    step: chapterStep.value,
    total: source.journey.progress.total,
    title: chapter.progress,
  })
})

/** The chapter ids in R's order, so the navigation never invents one. */
const chapterIds = computed(() => chapters.value.map((chapter) => chapter.id))

/**
 * The chapter that follows the one on screen, in R's order, or null at the end of
 * the journey. Every forward decision reads this rather than naming a successor, so
 * reordering the chapters moves the bridges with them.
 */
const nextChapterId = computed<string | null>(
  () => chapterIds.value[chapterIndex.value + 1] ?? null,
)

/** The chapter before the one on screen, or null when there is none. */
const previousChapterId = computed<string | null>(
  () => chapterIds.value[chapterIndex.value - 1] ?? null,
)

/** One chapter's own states, read from whichever copy R publishes for it. */
function stagesFor(id: string): JourneyStage[] {
  const source = contract.value
  if (!source) return []
  if (id === SENSITIVITY_CHAPTER_ID) return source.sensitivity.copy.stages
  if (id === UNCERTAINTY_CHAPTER_ID) return source.uncertainty.copy.stages
  if (id === VOI_CHAPTER_ID) return source.voi.copy.stages
  if (id === PRICE_CHAPTER_ID) return source.price.copy.stages
  if (id === BUDGET_CHAPTER_ID) return source.budget.copy.stages
  if (id === READINESS_CHAPTER_ID) return source.readiness?.copy.stages ?? []
  if (id === SURVIVAL_CHAPTER_ID) return source.survival?.copy.stages ?? []
  return source.base_case.copy.stages
}

/** One chapter's own heading, or an empty string before the contract arrives. */
function titleFor(id: string): string {
  const source = contract.value
  if (!source) return ''
  if (id === SENSITIVITY_CHAPTER_ID) return source.sensitivity.copy.title
  if (id === UNCERTAINTY_CHAPTER_ID) return source.uncertainty.copy.title
  if (id === VOI_CHAPTER_ID) return source.voi.copy.title
  if (id === PRICE_CHAPTER_ID) return source.price.copy.title
  if (id === BUDGET_CHAPTER_ID) return source.budget.copy.title
  if (id === READINESS_CHAPTER_ID) return source.readiness?.copy.title ?? ''
  if (id === SURVIVAL_CHAPTER_ID) return source.survival?.copy.title ?? ''
  return source.base_case.copy.title
}

/** The heading of the chapter on screen. */
const chapterTitle = computed(() => titleFor(chapterId.value))

/** One chapter's own name for the way forward. */
function advanceLabelFor(id: string): string | null {
  const source = contract.value
  if (!source) return null
  if (id === SENSITIVITY_CHAPTER_ID) return source.sensitivity.copy.advance_label
  if (id === UNCERTAINTY_CHAPTER_ID) return source.uncertainty.copy.advance_label
  if (id === VOI_CHAPTER_ID) return source.voi.copy.advance_label
  if (id === PRICE_CHAPTER_ID) return source.price.copy.advance_label
  if (id === BUDGET_CHAPTER_ID) return source.budget.copy.advance_label
  if (id === READINESS_CHAPTER_ID) return source.readiness?.copy.advance_label ?? null
  if (id === SURVIVAL_CHAPTER_ID) return source.survival?.copy.advance_label ?? null
  return source.base_case.copy.advance_label
}

/**
 * Which of R's chapters is on screen. The journey reads the id rather than a
 * step number, so the same panel component can render every chapter without
 * being rebuilt: moving between them changes these values and nothing else.
 */
const isUncertainty = computed(() => chapterId.value === UNCERTAINTY_CHAPTER_ID)
const isSensitivity = computed(() => chapterId.value === SENSITIVITY_CHAPTER_ID)
const isVoi = computed(() => chapterId.value === VOI_CHAPTER_ID)
const isPrice = computed(() => chapterId.value === PRICE_CHAPTER_ID)
const isBudget = computed(() => chapterId.value === BUDGET_CHAPTER_ID)
const isReadiness = computed(() => chapterId.value === READINESS_CHAPTER_ID)
const isSurvival = computed(() => chapterId.value === SURVIVAL_CHAPTER_ID)

/**
 * The chapter advances one state per learner activation. Nothing schedules it and
 * nothing times it: the graph is the way forward, so `stageIndex` only moves when
 * the learner acts, and Back moves it down without erasing anything drawn.
 */
const stages = computed<JourneyStage[]>(() => stagesFor(chapterId.value))

const stageCount = computed(() => stages.value.length)

const stage = computed<JourneyStage | null>(() => stages.value[stageIndex.value] ?? null)

const canAdvance = computed(() => stageIndex.value < stageCount.value - 1)

/**
 * Whether the graph is the chapter's activation for this state. It stops being one
 * where the state provides its own control — the base case's QALY illustration and
 * its price state — so the learner is never offered a target that skips the control
 * they are meant to use.
 */
const graphActivates = computed(
  () => canAdvance.value && stage.value?.interactive !== true,
)

/**
 * The graph's labels, or null before the contract arrives, and null in the third
 * chapter, which draws no plane. The first two chapters publish the four labels
 * the plane draws; the first chapter alone names its two differences, so the
 * second chapter's are left undefined and drawn unlabelled.
 */
const graph = computed<JourneyPlaneLabels | null>(() => {
  const source = contract.value
  if (!source) return null
  if (isSensitivity.value) return null
  if (isVoi.value) return null
  if (isPrice.value) return null
  if (isBudget.value) return null
  if (isReadiness.value) return null
  if (isSurvival.value) return null
  if (isUncertainty.value) {
    const labels = source.uncertainty.graph
    return {
      x_label: labels.x_label,
      y_label: labels.y_label,
      origin_label: labels.origin_label,
      point_label: labels.point_label,
    }
  }
  const labels = source.base_case.graph
  return {
    x_label: labels.x_label,
    y_label: labels.y_label,
    origin_label: labels.origin_label,
    point_label: labels.point_label,
    cost_leg_label: labels.cost_leg_label,
    health_leg_label: labels.health_leg_label,
  }
})

/** The price the learner is looking at: the moved one once there is one. */
const currentResult = computed(() => adjustedResult.value ?? initialResult.value)

/** The deterministic comparison at the learner's price, from whichever chapter. */
const baseCaseValues = computed(() => {
  const uncertainty = uncertaintyResult.value
  if (isUncertainty.value && uncertainty) return uncertainty.uncertainty.base_case
  const result = currentResult.value
  if (!result) return null
  return {
    incremental_cost: result.base_case.incremental_cost,
    incremental_qalys: result.base_case.incremental_qalys,
  }
})

/**
 * The one line the current state adds below the graph: R's value sentence when the
 * state names one, and otherwise the state's own caption.
 */
const stageNote = computed<string>(() => {
  const current = stage.value
  if (!current) return ''
  const key = current.note_key
  if (key) {
    if (isSensitivity.value) {
      const notes = sensitivityResult.value?.sensitivity.notes
      const sentence = notes ? notes[key] : undefined
      if (sentence) return sentence
    } else if (isUncertainty.value) {
      const notes = uncertaintyResult.value?.uncertainty.notes
      const sentence = notes ? (notes as Record<string, string>)[key] : undefined
      if (sentence) return sentence
    } else if (isVoi.value) {
      const notes = voiResult.value?.voi.notes
      const sentence = notes ? (notes as Record<string, string>)[key] : undefined
      if (sentence) return sentence
    } else if (isPrice.value) {
      const notes = priceShown.value?.price.notes
      const sentence = notes ? (notes as Record<string, string>)[key] : undefined
      if (sentence) return sentence
    } else if (isBudget.value) {
      const notes = budgetShownNotes.value
      const sentence = notes ? notes[key] : undefined
      if (sentence) return sentence
    } else if (isReadiness.value) {
      const notes = readinessShown.value?.readiness.notes
      const sentence = notes ? (notes as Record<string, string>)[key] : undefined
      if (sentence) return sentence
    } else if (currentResult.value) {
      const notes = currentResult.value.base_case.notes as Record<string, string>
      const sentence = notes[key]
      if (sentence) return sentence
    }
  }
  return current.caption
})

/** The chapter's own name for the way forward, or null when nothing follows. */
const chapterAdvanceLabel = computed<string | null>(() =>
  advanceLabelFor(chapterId.value),
)
/**
 * The visible label of the way forward, or null when there is none.
 *
 * A state may name its own transition — the QALY state does, and so does the last
 * state of a chapter, because both lead into the question that follows rather than to
 * another change on the chart. A state with no name of its own uses the chapter's, and
 * a chapter with none uses the journey's own word for it. The text is rendered as the
 * control's visible label, not hidden in an accessible name, so what a learner reads is
 * what the control does.
 *
 * At the end of a chapter the control opens the bridge into the next one if the
 * chapter list has one. At the end of the journey it does not exist: the last chapter
 * closes on a question rather than a completion screen.
 */
const nextLabel = computed<string | null>(() => {
  const source = contract.value
  if (!source) return null
  if (!canAdvance.value && nextChapterId.value === null) return null
  return (
    stage.value?.advance_label ??
    chapterAdvanceLabel.value ??
    source.journey.navigation.forward
  )
})

/** Whether there is a control for the way forward at this state. */
const hasNext = computed(() => nextLabel.value !== null)

/**
 * Whether the value of information already answers for the comparison on screen.
 * It answers only for the exact PSA response it was computed from, at the reference
 * it was computed at, so a stored answer cannot outlive the draws behind it.
 */
const voiCached = computed(
  () =>
    voiResult.value !== null &&
    voiSource.value !== null &&
    voiSource.value === uncertaintyResult.value &&
    voiThreshold.value === (contract.value?.voi.threshold ?? null),
)

/** Whether R is running anything for the chapter on screen. */
const chapterBusy = computed(() => {
  if (isSensitivity.value) return sensitivityBusy.value
  if (isPrice.value) return priceBusy.value
  if (isBudget.value) return budgetBusy.value
  if (isReadiness.value) return readinessBusy.value
  if (isSurvival.value) return survivalBusy.value
  if (isVoi.value) {
    // A learner who jumps straight to this chapter has no draws to value yet, so the
    // chapter waits for the simulation it is derived from as well as for its own
    // answer.
    return voiBusy.value || (!voiCached.value && uncertaintyBusy.value)
  }
  return isUncertainty.value ? uncertaintyBusy.value : evaluateBusy.value
})

/**
 * Loads the contract once and seeds the one control and the first chapter from
 * it. A failed attempt leaves the error visible and allows a retry.
 */
async function loadContract(): Promise<void> {
  if (contractRequest) return contractRequest
  contractBusy.value = true
  contractRequest = (async () => {
    try {
      const response = await fetchTutorialJourney()
      contract.value = response
      contractError.value = null
      if (!chapterId.value) chapterId.value = response.journey.chapters[0]?.id ?? ''
      if (price.value === null) {
        const control = response.base_case.controls[0]
        price.value =
          typeof control?.default === 'number'
            ? control.default
            : response.case.proposed_price
      }
      if (utility.value === null) {
        const control = response.base_case.qaly?.control
        utility.value =
          typeof control?.default === 'number' ? control.default : null
      }
    } catch (error) {
      contractError.value = describe(error)
      contractRequest = null
    } finally {
      contractBusy.value = false
    }
  })()
  return contractRequest
}

/**
 * Evaluates the base case for the scenario on screen. The response is applied only if
 * it is still the newest one, and only if it describes the levers the learner is
 * actually looking at, so a slow answer for a superseded scenario cannot overwrite the
 * newer one.
 *
 * The first result fills the initial slot and every later result fills the adjusted
 * slot, so the before-and-after screen always has both.
 */
async function evaluateBaseCase(priceValue: number, utilityValue: number): Promise<void> {
  if (!contract.value) return
  const token = ++evaluateToken
  evaluateBusy.value = true
  try {
    const response = await postTutorialJourneyBaseCase({
      price: priceValue,
      utility_no_event: utilityValue,
    })
    if (token !== evaluateToken) return
    if (
      response.inputs.price !== priceValue ||
      response.inputs.utility_no_event !== utilityValue
    ) {
      return
    }
    if (initialResult.value === null) {
      initialResult.value = response
    } else {
      adjustedResult.value = response
    }
    evaluateError.value = null
  } catch (error) {
    if (token !== evaluateToken) return
    evaluateError.value = describe(error)
  } finally {
    if (token === evaluateToken) evaluateBusy.value = false
  }
}

function clearAdjustTimer(): void {
  if (adjustTimer !== null) clearTimeout(adjustTimer)
  adjustTimer = null
}

/**
 * Drops everything derived from the scenario that is no longer on screen.
 *
 * Both levers go through this: a different price or a different score is a different
 * comparison, so the repeats, the rankings, the value of information, the balance and
 * its solve, and the budget sweep are all answers about a scenario that has moved. They
 * are dropped rather than relabelled, and each in-flight request is cancelled by
 * bumping its token so a late answer for the old scenario is discarded.
 */
function invalidateDerivedResults(): void {
  if (uncertaintyResult.value !== null) {
    uncertaintyResult.value = null
    uncertaintyError.value = null
  }
  if (sensitivityResult.value !== null) {
    sensitivityResult.value = null
    sensitivityError.value = null
  }
  // The value of better evidence is derived from the cloud: a new scenario means new
  // draws, so the stored value neither describes them nor may be shown against them.
  if (voiResult.value !== null || voiSource.value !== null) {
    voiResult.value = null
    voiSource.value = null
    voiError.value = null
  }
  // The balance and the price at which it reaches zero are properties of the whole
  // scenario, and the scenario key folds in both levers, so the solve is dropped with
  // the answers rather than reused against a score it was not solved for.
  if (priceResult.value !== null) {
    priceResult.value = null
    priceError.value = null
  }
  if (priceSolve.value !== null) {
    priceSolve.value = null
    priceSolveKey.value = null
  }
  priceAnswers.clear()
  if (budgetResult.value !== null) {
    budgetResult.value = null
    budgetError.value = null
  }
  budgetAnswers.clear()
  uncertaintyToken += 1
  uncertaintyBusy.value = false
  sensitivityToken += 1
  sensitivityBusy.value = false
  voiToken += 1
  voiBusy.value = false
  priceToken += 1
  priceBusy.value = false
  priceInFlight.value = null
  budgetToken += 1
  budgetBusy.value = false
  budgetInFlight.value = null
}

/** Sets the price and requests the result once the drag has settled. */
function setPrice(value: number): void {
  price.value = value
  invalidateDerivedResults()
  // Nothing is requested before the base case exists: the slider only ever changes a
  // graph that is already on screen.
  if (initialResult.value === null || utility.value === null) return
  clearAdjustTimer()
  const score = utility.value
  adjustTimer = setTimeout(() => {
    adjustTimer = null
    void evaluateBaseCase(value, score)
  }, ADJUST_DEBOUNCE_MS)
}

/**
 * Sets the no-event quality-of-life score, the scenario's second lever.
 *
 * The control moves immediately and the model is asked once the change is committed,
 * exactly as the price is: the slider is debounced, and a change invalidates every
 * answer derived from the previous score rather than relabelling it.
 */
function setUtility(value: number): void {
  const control = contract.value?.base_case.qaly?.control
  const bounded =
    control && typeof control.min === 'number' && typeof control.max === 'number'
      ? Math.min(Math.max(value, control.min), control.max)
      : value
  if (utility.value === bounded) return
  utility.value = bounded
  invalidateDerivedResults()
  if (initialResult.value === null || price.value === null) return
  clearAdjustTimer()
  const cost = price.value
  adjustTimer = setTimeout(() => {
    adjustTimer = null
    void evaluateBaseCase(cost, bounded)
  }, ADJUST_DEBOUNCE_MS)
}

/**
 * Draws the second chapter's simulation.
 *
 * R owns how many combinations there are and which seed they use; the request
 * carries only the price, which is the one the learner chose in the first chapter.
 * Nothing calls this until the learner clicks the price state's arrow, so no work
 * happens while they are still reading the graph.
 *
 * A stored answer is reused when it describes the price being asked about, and the
 * `uncertaintyBusy` guard makes repeated clicks one request rather than several.
 * The app-wide loader is deliberately *not* started here: the recap has to stay
 * readable while this runs, and the loader is turned on by the caller when — and
 * only when — the learner asks to leave the recap before the answer has arrived.
 */
async function evaluateUncertainty(): Promise<void> {
  if (!contract.value) return
  if (uncertaintyResult.value !== null || uncertaintyBusy.value) return
  const value = price.value
  const score = utility.value
  if (value === null || score === null) return

  const token = ++uncertaintyToken
  uncertaintyBusy.value = true
  try {
    const response = await postTutorialJourneyUncertainty({
      price: value,
      utility_no_event: score,
    })
    if (token !== uncertaintyToken) return
    uncertaintyResult.value = response
    uncertaintyError.value = null
  } catch (error) {
    if (token !== uncertaintyToken) return
    uncertaintyError.value = describe(error)
  } finally {
    if (token === uncertaintyToken) uncertaintyBusy.value = false
  }
}

/**
 * Draws the third chapter's two rankings.
 *
 * R owns the tested ranges, the order and every sentence; the request carries only
 * the price. Nothing calls this until the learner leaves the second chapter, so no
 * work happens while they are still reading the dots. A stored answer is reused
 * when it describes the price being asked about, and the guard makes repeated
 * clicks one request rather than several — the same contract the second chapter's
 * simulation follows.
 */
async function evaluateSensitivity(): Promise<void> {
  if (!contract.value) return
  if (sensitivityResult.value !== null || sensitivityBusy.value) return
  const value = price.value
  const score = utility.value
  if (value === null || score === null) return

  const token = ++sensitivityToken
  sensitivityBusy.value = true
  try {
    const response = await postTutorialJourneySensitivity({
      price: value,
      utility_no_event: score,
    })
    if (token !== sensitivityToken) return
    sensitivityResult.value = response
    sensitivityError.value = null
  } catch (error) {
    if (token !== sensitivityToken) return
    sensitivityError.value = describe(error)
  } finally {
    if (token === sensitivityToken) sensitivityBusy.value = false
  }
}

/**
 * Values better evidence on the draws the second chapter already returned.
 *
 * Nothing is simulated here: the request carries the rows R produced for this price,
 * and R's value-of-information functions put a value on them. Nothing is requested
 * until the learner leaves the second chapter, and the answer is reused only while it
 * describes the same draws at the same reference value.
 */
async function evaluateVoi(): Promise<void> {
  if (!contract.value) return
  if (voiCached.value) return
  if (voiBusy.value) return
  const source = uncertaintyResult.value
  const value = price.value
  const threshold = contract.value.voi.threshold
  if (!source || value === null) return

  const token = ++voiToken
  voiBusy.value = true
  try {
    const response = await postTutorialJourneyVoi({
      price: value,
      threshold,
      results: source.uncertainty.draws,
    })
    if (token !== voiToken) return
    voiResult.value = response
    voiSource.value = source
    voiThreshold.value = threshold
    voiError.value = null
  } catch (error) {
    if (token !== voiToken) return
    voiError.value = describe(error)
  } finally {
    if (token === voiToken) voiBusy.value = false
  }
}

/**
 * Whether the price chapter's stored answer describes the scenario on screen.
 *
 * The response carries the price and the score it was computed at, so both are
 * compared rather than the scenario key: the key is R's, and the client never has to
 * reconstruct it to know whether an answer still belongs on screen.
 */
const priceShown = computed<JourneyPriceResponse | null>(() => {
  const result = priceResult.value
  const value = price.value
  const score = utility.value
  if (!result || value === null || score === null) return null
  if (result.inputs.price !== value) return null
  return result.inputs.utility_no_event === score ? result : null
})

/**
 * The solve object posted back to R, when one describes this scenario.
 *
 * The solve is dropped whenever either lever changes (see `invalidateDerivedResults`),
 * so what is held here was solved for the scenario on screen. R still validates the
 * posted key and threshold and refuses a solve that does not match, so this is a
 * convenience rather than a trust boundary.
 */
const priceSolvePayload = computed<JourneyPriceSolvePayload | null>(() =>
  priceSolve.value ?? null,
)

/**
 * Requests the price chapter's answer for the scenario on screen.
 *
 * The balance is always R's own model run at that price and score; the solve is posted
 * back only when one already describes this scenario, so the first visit solves and a
 * return visit reuses it. An answer already held for the same scenario and price is
 * reused without a request, and a duplicate or superseded request is refused by the
 * guard and the token.
 */
async function evaluatePrice(target: number, score: number, force = false): Promise<void> {
  const source = contract.value
  if (!source) return
  const key = `${source.price.scenario_key}|${score}|${target}`
  if (!force) {
    const cached = priceAnswers.get(key)
    if (cached) {
      priceResult.value = cached
      priceError.value = null
      return
    }
    // The same scenario asked for twice while its answer is in flight is one request.
    if (priceInFlight.value === key) return
  }
  priceInFlight.value = key

  const token = ++priceToken
  priceBusy.value = true
  try {
    const response = await postTutorialJourneyPrice({
      price: target,
      utility_no_event: score,
      threshold: source.price.threshold,
      solve: priceSolvePayload.value ?? undefined,
    })
    if (token !== priceToken) return
    priceAnswers.set(key, response)
    priceResult.value = response
    priceSolve.value = {
      scenario_key: response.price.scenario_key,
      threshold: source.price.threshold,
      available: response.price.solved.available,
      max_acceptable_price: response.price.solved.available
        ? (response.price.solved.price ?? undefined)
        : undefined,
      method: response.price.solved.method,
      verified: response.price.solved.verified,
      reason: response.price.solved.reason,
    }
    priceSolveKey.value = response.price.scenario_key
    priceError.value = null
  } catch (error) {
    if (token !== priceToken) return
    priceError.value = describe(error)
  } finally {
    if (token === priceToken) {
      priceBusy.value = false
      priceInFlight.value = null
    }
  }
}

/**
 * Opens the price chapter on the scenario the learner carries.
 *
 * There is no price lever here: the chapter compares the price chosen in the base case
 * with the price at which the balance reaches zero. Both levers are read at entry, so a
 * learner who goes back, changes one, and returns sees the chapter at the new scenario
 * rather than at a remembered one.
 */
function enterPriceChapter(): void {
  const value = price.value
  const score = utility.value
  if (value === null || score === null) return
  void evaluatePrice(value, score)
}

/* --- Chapter 6: the budget ------------------------------------------------- */

/** True only when the answer describes the price this chapter is charging. */
const budgetShown = computed<JourneyBudgetResponse | null>(() => {
  const result = budgetResult.value
  if (!result) return null
  return result.inputs.price === budgetPrice.value ? result : null
})

/** The answer's own block, once it describes the price on screen. */
const budgetData = computed(() => budgetShown.value?.budget ?? null)

/** The one price this chapter charges. */
const budgetCandidate = computed<JourneyBudgetCandidate | null>(() => {
  const candidates = budgetData.value?.candidates ?? []
  return candidates[0] ?? null
})

/** The coverage step the learner has selected, from the rows R already returned. */
const budgetStep = computed<JourneyBudgetCoverage | null>(() => {
  const coverages = budgetCandidate.value?.coverages ?? []
  if (coverages.length === 0) return null
  const selected = budgetCoverage.value
  return coverages.find((entry) => entry.coverage === selected) ?? coverages[0]
})

/**
 * The sentences that belong to the selections on screen.
 *
 * Only `adoption` comes from the response's own budget-level notes: the chapter's
 * limits are published in `budget.disclosure`, and no state carries a `note_key` for
 * them, so there is no sentence to map here.
 */
const budgetShownNotes = computed<Record<string, string> | null>(() => {
  const result = budgetData.value
  const step = budgetStep.value
  if (!result || !step) return null
  return {
    population: step.notes.population,
    cumulative: step.notes.cumulative,
    adoption: result.notes.adoption,
  }
})

/**
 * Requests the budget sweep for the two prices in play.
 *
 * The response carries every coverage step for every candidate, so this is asked once
 * per pair of prices and the coverage lever afterwards only selects a row. An answer
 * already held for the same pair is reused, and a duplicate request is refused.
 */
/**
 * Requests the budget sweep for the journey's price.
 *
 * The response carries every coverage step, so this is asked once per price and the
 * coverage lever afterwards only selects a row. An answer already held for the same
 * price is reused, and a duplicate request is refused. The price is read from the
 * journey at call time, so a learner who changes it and comes back gets that price's
 * sweep rather than a remembered one.
 */
async function evaluateBudget(force = false): Promise<void> {
  if (!contract.value) return
  const value = budgetPrice.value
  if (value === null) return
  const key = value
  if (!force) {
    const cached = budgetAnswers.get(key)
    if (cached) {
      budgetResult.value = cached
      budgetError.value = null
      return
    }
    if (budgetInFlight.value === key) return
  }
  budgetInFlight.value = key
  const token = ++budgetToken
  budgetBusy.value = true
  try {
    const response = await postTutorialJourneyBudget({ price: value })
    if (token !== budgetToken) return
    budgetAnswers.set(key, response)
    budgetResult.value = response
    budgetError.value = null
  } catch (error) {
    if (token !== budgetToken) return
    budgetError.value = describe(error)
  } finally {
    if (token === budgetToken) {
      budgetBusy.value = false
      budgetInFlight.value = null
    }
  }
}

/**
 * Opens the budget chapter on the price the journey carries.
 *
 * There is one price, so there is nothing to choose between and no selection is
 * offered. The coverage cap keeps its own value across visits, because it is the
 * chapter's interaction rather than part of the scenario.
 */
function enterBudgetChapter(): void {
  const value = price.value
  if (value === null) return
  budgetPrice.value = value
  if (budgetCoverage.value === null) {
    const fallback = contract.value?.budget.control.default
    budgetCoverage.value = typeof fallback === 'number' ? fallback : null
  }
  void evaluateBudget()
}

/** Chooses a coverage step from the rows R already returned. Local to the chapter. */
function setBudgetCoverage(value: number): void {
  budgetCoverage.value = value
}

/* --- Chapter 7: readiness -------------------------------------------------- */

/** The answers on screen: the learner's, falling back to the case's own values. */
const readinessShownAnswers = computed<JourneyReadinessAnswers>(() => {
  const source = contract.value?.readiness
  const defaults = (source?.defaults ?? {}) as Partial<JourneyReadinessAnswers>
  return { ...defaults, ...readinessAnswers.value } as JourneyReadinessAnswers
})

/** R's answer only when it describes the answers on screen. */
const readinessShown = computed<JourneyReadinessResponse | null>(() => {
  const result = readinessResult.value
  if (!result) return null
  const shown = readinessShownAnswers.value
  const echoed = result.inputs.answers
  const keys = Object.keys(shown) as (keyof JourneyReadinessAnswers)[]
  if (!keys.every((key) => echoed[key] === shown[key])) return null
  return result
})

const readinessData = computed(() => readinessShown.value?.readiness ?? null)

/** The question this chapter is asking, from R's list of them. */
function readinessQuestion(id: string | null | undefined) {
  if (!id) return null
  return contract.value?.readiness?.questions.find((q) => q.id === id) ?? null
}

/** The area the answer on screen changed, so the figure can bring it forward. */
const readinessChanged = computed(() => readinessData.value?.changed ?? null)

/**
 * Requests the assessment for the answers on screen.
 *
 * The cache key is R's own ten-input set for the case together with the four answers,
 * so an assessment is reused only when every input is unchanged — including the six
 * case values the learner cannot edit — and a different case can never reuse a
 * previous case's result. `focus_question` names the question the learner just
 * answered, so R can report which area that answer changed; it is not part of the
 * key, because it changes no input.
 */
async function evaluateReadiness(
  focusQuestion: JourneyReadinessAnswerKey | null = null,
  force = false,
): Promise<void> {
  if (!contract.value) return
  const answers = readinessShownAnswers.value
  const key = JSON.stringify([contract.value.readiness?.inputs ?? null, answers])
  if (!force) {
    const cached = readinessAnswersCache.get(key)
    if (cached) {
      readinessResult.value = cached
      readinessError.value = null
      return
    }
    if (readinessInFlight.value === key) return
  }
  readinessInFlight.value = key
  const token = ++readinessToken
  readinessBusy.value = true
  try {
    const response = await postTutorialJourneyReadiness({
      answers,
      focus_question: focusQuestion ?? undefined,
    })
    if (token !== readinessToken) return
    readinessAnswersCache.set(key, response)
    readinessResult.value = response
    readinessError.value = null
  } catch (error) {
    if (token !== readinessToken) return
    readinessError.value = describe(error)
  } finally {
    if (token === readinessToken) {
      readinessBusy.value = false
      readinessInFlight.value = null
    }
  }
}

/**
 * Opens the readiness chapter on the answers the learner already chose, so returning
 * to it after going Back shows the same assessment rather than resetting it.
 */
function enterReadinessChapter(): void {
  if (!contract.value) return
  void evaluateReadiness()
}

/**
 * Records one answer and re-assesses. The answer set is the chapter's own, so nothing
 * earlier changes, and the statuses themselves remain R's.
 */
function setReadinessAnswer(
  questionId: JourneyReadinessAnswerKey,
  optionId: string,
): void {
  const question = readinessQuestion(questionId)
  if (!question) return
  if (!question.options.some((option) => option.id === optionId)) return
  if (readinessShownAnswers.value[questionId] === optionId) return
  readinessAnswers.value = { ...readinessAnswers.value, [questionId]: optionId }
  void evaluateReadiness(questionId)
}

/**
 * Asks for the assessment once more after a failed request, for the answers already
 * on screen.
 *
 * It is a manual retry and nothing else: it runs on the learner's click, it is subject
 * to the same in-flight guard as every other request, and it schedules nothing, so a
 * failure cannot become a loop.
 */
function retryReadiness(): void {
  if (!contract.value || readinessBusy.value) return
  void evaluateReadiness(null, true)
}

/* --- Chapter 8: time to a first heart attack or stroke --------------------- */

/**
 * The simulation's own key: every input and setting R reads, composed in R and
 * published with the contract.
 *
 * It is the cache key, so a stored set of curves is reused only while it describes the
 * same sample size, follow-up, seed, effect assumption and annual risks. The price and
 * the quality-of-life score are not in it because the curves do not read them, which is
 * why moving either lever earlier in the journey leaves this chapter alone.
 */
const survivalKey = computed<string | null>(() => contract.value?.survival?.inputs_key ?? null)

/** R's curves, but only while they describe the simulation this contract names. */
const survivalShown = computed<JourneySurvivalResponse | null>(() => {
  const result = survivalResult.value
  const key = survivalKey.value
  if (!result || key === null) return null
  if (result.inputs.survival_key !== key) return null
  return result
})

const survivalData = computed(() => survivalShown.value?.survival ?? null)

/** The three times R returned, in R's order. */
const survivalReads = computed(() => survivalData.value?.reads ?? [])

/**
 * The time on screen: the learner's choice, or R's first time before they have made
 * one. It is chapter state only — every time comes from the one response, so choosing
 * another never asks R for anything.
 */
const survivalShownTime = computed(() => {
  const reads = survivalReads.value
  if (reads.length === 0) return null
  const chosen = survivalTime.value
  return reads.find((read) => read.id === chosen) ?? reads[0]
})

/** R's reading of both curves at the time on screen. */
const survivalRead = computed(() => survivalShownTime.value)

/** Chooses one of the times R already returned. Local to the chapter. */
function setSurvivalTime(id: string): void {
  const reads = survivalReads.value
  if (!reads.some((read) => read.id === id)) return
  survivalTime.value = id
}

/**
 * Requests the simulated curves for the key on screen.
 *
 * The response carries every time the chapter can be read at, so this is asked once per
 * simulation and the time control afterwards only selects a reading. A stored answer
 * already held for the same key is reused, and a duplicate request is refused.
 */
async function evaluateSurvival(force = false): Promise<void> {
  if (!contract.value) return
  const key = survivalKey.value
  if (key === null) return
  if (!force) {
    const cached = survivalAnswers.get(key)
    if (cached) {
      survivalResult.value = cached
      survivalError.value = null
      return
    }
    if (survivalInFlight.value === key) return
  }
  survivalInFlight.value = key
  const token = ++survivalToken
  survivalBusy.value = true
  try {
    const response = await postTutorialJourneySurvival()
    if (token !== survivalToken) return
    survivalAnswers.set(key, response)
    survivalResult.value = response
    survivalError.value = null
  } catch (error) {
    if (token !== survivalToken) return
    survivalError.value = describe(error)
  } finally {
    if (token === survivalToken) {
      survivalBusy.value = false
      survivalInFlight.value = null
    }
  }
}

/**
 * Opens the last chapter on the time the learner already chose, so returning to it after
 * going Back shows the same reading rather than resetting it.
 *
 * Nothing else is prepared here: the time control falls back to R's first time when no
 * choice has been made, so a first visit needs no state of its own.
 */
function enterSurvivalChapter(): void {
  if (!contract.value) return
  void evaluateSurvival()
}

/**
 * Asks for the curves once more after a failed request. It is a manual retry and
 * nothing else: it runs on the learner's click, it is subject to the same in-flight
 * guard as every other request, and it schedules nothing, so a failure cannot become a
 * loop.
 */
function retrySurvival(): void {
  if (!contract.value || survivalBusy.value) return
  void evaluateSurvival(true)
}

/* --- Standalone explainer mode -------------------------------------------- */

/**
 * Whether the journey is showing one chapter on its own, opened from the dashboard
 * module it explains.
 *
 * The lesson is the same lesson: the same component, the same R copy and the same
 * request. What changes is only what surrounds it — a standalone orientation instead
 * of the journey's navigation, and a return to the module rather than a bridge into a
 * chapter the learner has not read.
 */
const isExplainer = ref(false)

/**
 * The whole journey's position and readiness state, held while an explainer is open.
 *
 * The explainer is a separate visit: it starts at the chapter's first state with no
 * assessment, and its answers are its own. The journey's chapter, stage, answers and
 * cached results are put aside here and restored when the learner returns, so opening
 * a refresher cannot move the journey's position or lose the answers it had. The
 * scenario is not part of this because explainer mode never writes it: no chapter of
 * the standalone lesson reads or sets the price or the score.
 */
interface JourneyHold {
  chapterId: string
  stageIndex: number
  recapVisible: boolean
  readinessAnswers: Partial<JourneyReadinessAnswers>
  readinessResult: JourneyReadinessResponse | null
  readinessError: string | null
  readinessCache: Map<string, JourneyReadinessResponse>
  budgetPrice: number | null
  budgetCoverage: number | null
  budgetResult: JourneyBudgetResponse | null
  budgetError: string | null
  survivalTime: string | null
  survivalResult: JourneySurvivalResponse | null
  survivalError: string | null
  survivalCache: Map<string, JourneySurvivalResponse>
}

let journeyHold: JourneyHold | null = null

/**
 * The dashboard module a chapter explains, as R publishes it: its label, the one
 * orientation sentence a standalone reader needs, and the two control labels. Only a
 * chapter that publishes one can be opened on its own, so the interface cannot invent
 * a standalone lesson R has not written.
 */
function moduleFor(id: string): JourneyModuleIdentity | null {
  if (id === READINESS_CHAPTER_ID) return contract.value?.readiness?.module ?? null
  if (id === BUDGET_CHAPTER_ID) return contract.value?.budget?.module ?? null
  if (id === SURVIVAL_CHAPTER_ID) return contract.value?.survival?.module ?? null
  return null
}

/** The module identity of the chapter an explainer is showing, or null. */
const moduleIdentity = computed<JourneyModuleIdentity | null>(() =>
  isExplainer.value ? moduleFor(chapterId.value) : null,
)

/**
 * Whether this session has journey progress to resume.
 *
 * It reads only state the journey already holds — never the model service — so Home
 * can choose its wording without making a request, which is what keeps Home free of
 * API calls. Before the contract has loaded there is nothing to resume, and after it
 * has, any chapter beyond the brief or any state beyond a chapter's first counts.
 */
const hasProgress = computed(() => {
  if (contract.value === null) return false
  const first = chapterIds.value[0]
  if (!first) return false
  if (chapterId.value !== first) return true
  return stageIndex.value > 0
})

/**
 * Opens one chapter as a standalone explainer.
 *
 * Nothing is requested here: opening a lesson must not run the analysis it explains.
 * The chapter's own first advance is what asks R for anything, and for this chapter
 * that is one readiness assessment. A chapter R publishes no module identity for
 * cannot be opened this way, and the caller keeps the journey as it is.
 */
function enterExplainer(id: string): void {
  if (!contract.value || !chapterIds.value.includes(id)) return
  if (isExplainer.value || moduleFor(id) === null) return
  journeyHold = {
    chapterId: chapterId.value,
    stageIndex: stageIndex.value,
    recapVisible: recapVisible.value,
    readinessAnswers: { ...readinessAnswers.value },
    readinessResult: readinessResult.value,
    readinessError: readinessError.value,
    readinessCache: new Map(readinessAnswersCache),
    budgetPrice: budgetPrice.value,
    budgetCoverage: budgetCoverage.value,
    budgetResult: budgetResult.value,
    budgetError: budgetError.value,
    survivalTime: survivalTime.value,
    survivalResult: survivalResult.value,
    survivalError: survivalError.value,
    survivalCache: new Map(survivalAnswers),
  }
  isExplainer.value = true
  // The explainer is its own visit: its own state of the chapter, its own answers,
  // and no bridge from a chapter the learner has not read.
  recapVisible.value = false
  chapterId.value = id
  stageIndex.value = 0
  readinessToken += 1
  readinessAnswers.value = {}
  readinessResult.value = null
  readinessError.value = null
  readinessBusy.value = false
  readinessInFlight.value = null
  readinessAnswersCache.clear()
  // The budget lesson charges the case's own fixed price, published with the module,
  // so it never reads the journey's selected scenario and cannot be mistaken for it.
  budgetToken += 1
  budgetResult.value = null
  budgetError.value = null
  budgetBusy.value = false
  budgetInFlight.value = null
  budgetAnswers.clear()
  budgetPrice.value = contract.value?.budget?.module?.price ?? null
  // The coverage control's default is a `number | boolean` in the shared control shape,
  // so the chapter takes it only when it is a number, exactly as the chapter's own entry
  // does, rather than asserting a type the contract does not guarantee.
  const coverageDefault = contract.value?.budget?.control.default
  budgetCoverage.value = typeof coverageDefault === 'number' ? coverageDefault : null
  // The survival lesson is its own visit too: its position and time selection start
  // again, but a set of curves already computed for the same simulation is kept, so a
  // second visit reuses it instead of asking R again. Only entries whose key no longer
  // matches the contract are dropped, because those can never describe this lesson.
  survivalToken += 1
  survivalTime.value = null
  survivalResult.value = null
  survivalError.value = null
  survivalBusy.value = false
  survivalInFlight.value = null
  const key = survivalKey.value
  if (key !== null) {
    for (const cached of [...survivalAnswers.keys()]) {
      if (cached !== key) survivalAnswers.delete(cached)
    }
  }
}

/**
 * Closes the explainer and puts the journey back exactly where it was. It is safe to
 * call twice, and it discards any answer still in flight for the explainer, so a late
 * response cannot land in the journey's state.
 */
function leaveExplainer(): void {
  if (!isExplainer.value) return
  isExplainer.value = false
  const hold = journeyHold
  journeyHold = null
  readinessToken += 1
  readinessBusy.value = false
  readinessInFlight.value = null
  readinessAnswersCache.clear()
  budgetToken += 1
  budgetBusy.value = false
  budgetInFlight.value = null
  budgetAnswers.clear()
  survivalToken += 1
  survivalBusy.value = false
  survivalInFlight.value = null
  // The simulated curves are not cleared here: they are keyed by every input the
  // simulation reads, so an entry can only ever be shown against the simulation it
  // describes. Keeping them is what lets a lesson reopened from the module reuse its
  // own answer instead of asking R for the same curves a second time. The journey's
  // held entries are merged back below, which is a no-op when they are already here.
  if (hold === null) {
    // No journey position was held (a direct link opened the explainer before the
    // journey had one), so the journey stays where it is and reports nothing.
    readinessAnswers.value = {}
    readinessResult.value = null
    readinessError.value = null
    budgetResult.value = null
    budgetError.value = null
    budgetPrice.value = null
    budgetCoverage.value = null
    survivalTime.value = null
    survivalResult.value = null
    survivalError.value = null
    return
  }
  chapterId.value = hold.chapterId
  stageIndex.value = hold.stageIndex
  recapVisible.value = hold.recapVisible
  readinessAnswers.value = hold.readinessAnswers
  readinessResult.value = hold.readinessResult
  readinessError.value = hold.readinessError
  hold.readinessCache.forEach((value, key) => readinessAnswersCache.set(key, value))
  budgetPrice.value = hold.budgetPrice
  budgetCoverage.value = hold.budgetCoverage
  budgetResult.value = hold.budgetResult
  budgetError.value = hold.budgetError
  survivalTime.value = hold.survivalTime
  survivalResult.value = hold.survivalResult
  survivalError.value = hold.survivalError
  hold.survivalCache.forEach((value, key) => survivalAnswers.set(key, value))
  // A lesson whose curves were fetched while the journey's own hold had none leaves
  // them here under the same key, so they are dropped only if the contract's key has
  // moved on since.
  const current = survivalKey.value
  if (current !== null) {
    for (const cached of [...survivalAnswers.keys()]) {
      if (cached !== current) survivalAnswers.delete(cached)
    }
  }
}

/**
 * Moves the chapter to the next state of the graph. This is the chapter's only
 * advance, and the learner makes it by activating the graph or its own control, so
 * nothing moves on a timer. *
 * The state that first shows eQalb is also the state that needs the model, so the
 * request is made here and the chapter waits for R's answer before it moves: the
 * learner never sees a graph state drawn from a result that has not arrived.
 *
 * At the end of a chapter the way forward is the next question rather than another
 * state, so the same action opens the bridge into the chapter that follows. When
 * the journey has no chapter after this one, the last state stays where it is.
 */
function advanceStage(): void {
  if (!canAdvance.value) {
    // Nothing follows the last chapter, and an explainer has no bridge at all: its
    // lesson ends where R's copy ends.
    if (nextChapterId.value !== null && !isExplainer.value) openRecap()
    return
  }
  const next = stages.value[stageIndex.value + 1]
  if (!next) return

  // A standalone lesson opens without asking R for anything, so its chapter's first
  // intentional advance is what calls that chapter's own endpoint. No other chapter is
  // opened and nothing earlier is re-run: readiness asks for one assessment, and the
  // budget asks for one coverage sweep of calculate_budget_impact().
  if (isExplainer.value) {
    if (
      isReadiness.value &&
      readinessShown.value === null &&
      readinessError.value === null &&
      !readinessBusy.value
    ) {
      void evaluateReadiness()
    }
    if (
      isBudget.value &&
      budgetShown.value === null &&
      budgetError.value === null &&
      !budgetBusy.value
    ) {
      void evaluateBudget()
    }
    // The last chapter is the one whose first beat is the curves themselves. Its first
    // advance therefore fetches them and stays where it is, so the learner reads the
    // two estimates the sentence is about before moving on; the next two advances walk
    // the remaining beats. A lesson that already holds its curves — a Back to the first
    // beat — falls through and moves on as usual, and so does a contract that publishes
    // no key, which is one this build cannot ask for curves under.
    if (isSurvival.value && survivalShown.value === null && survivalKey.value !== null) {
      if (survivalError.value === null && !survivalBusy.value) void evaluateSurvival()
      return
    }
    if (
      isSurvival.value &&
      survivalShown.value === null &&
      survivalError.value === null &&
      !survivalBusy.value
    ) {
      void evaluateSurvival()
    }
  }

  if (next.id === 'add_eqalb' && initialResult.value === null) {
    const value = price.value
    const score = utility.value
    if (value === null || score === null) return
    void evaluateBaseCase(value, score)
  }
  stageIndex.value += 1
}

/* --- The bridge between chapters ------------------------------------------ */

/**
 * The bridge the chapter on screen ends at: the recap R wrote for the chapter that
 * follows, the chapter it opens, and the work that chapter needs.
 *
 * Everything is read from the journey's order: the destination is the next chapter
 * in R's list, the recap is the one R publishes under that chapter's id, and the
 * work is chosen by that chapter's own id. So reordering the chapters moves the
 * bridges with them, and no code here names a predecessor or a successor.
 *
 * Every bridge shares this one shape, so the panel, the recap, the loader and the
 * error handling are one implementation used as many times as the journey has
 * chapters.
 */
interface Bridge {
  /** Which chapter's calculation the bridge is waiting for, or null at the end. */
  kind:
    | 'uncertainty'
    | 'sensitivity'
    | 'voi'
    | 'price'
    | 'budget'
    | 'readiness'
    | 'survival'
    | null
  targetId: string
  recap: JourneyRecap | null
  ready: boolean
  error: string | null
}

const bridge = computed<Bridge>(() => {
  const source = contract.value
  const targetId = nextChapterId.value
  // The last chapter has no bridge: nothing follows it yet, so a request made from
  // here would have no destination.
  if (!source || targetId === null) {
    return { kind: null, targetId: '', recap: null, ready: true, error: null }
  }
  if (targetId === SENSITIVITY_CHAPTER_ID) {
    return {
      kind: 'sensitivity',
      targetId,
      recap: source.recaps[targetId] ?? null,
      ready: sensitivityResult.value !== null,
      error: sensitivityError.value,
    }
  }
  if (targetId === UNCERTAINTY_CHAPTER_ID) {
    return {
      kind: 'uncertainty',
      targetId,
      recap: source.recaps[targetId] ?? null,
      ready: uncertaintyResult.value !== null,
      error: uncertaintyError.value,
    }
  }
  if (targetId === VOI_CHAPTER_ID) {
    return {
      kind: 'voi',
      targetId,
      recap: source.recaps[targetId] ?? null,
      ready: voiCached.value,
      error: voiError.value,
    }
  }
  if (targetId === PRICE_CHAPTER_ID) {
    return {
      kind: 'price',
      targetId,
      recap: source.recaps[targetId] ?? null,
      ready: priceShown.value !== null,
      error: priceError.value,
    }
  }
  if (targetId === BUDGET_CHAPTER_ID) {
    return {
      kind: 'budget',
      targetId,
      recap: source.recaps[targetId] ?? null,
      ready: budgetShown.value !== null,
      error: budgetError.value,
    }
  }
  if (targetId === READINESS_CHAPTER_ID) {
    return {
      kind: 'readiness',
      targetId,
      recap: source.recaps[targetId] ?? null,
      ready: readinessShown.value !== null,
      error: readinessError.value,
    }
  }
  if (targetId === SURVIVAL_CHAPTER_ID) {
    return {
      kind: 'survival',
      targetId,
      recap: source.recaps[targetId] ?? null,
      ready: survivalShown.value !== null,
      error: survivalError.value,
    }
  }
  return { kind: null, targetId, recap: null, ready: true, error: null }
})

/** The recap on screen, as R wrote it. */
const recap = computed(() => bridge.value.recap)

/** Starts the work the open bridge is about. */
function runBridge(
  kind:
    | 'uncertainty'
    | 'sensitivity'
    | 'voi'
    | 'price'
    | 'budget'
    | 'readiness'
    | 'survival'
    | null,
): void {
  if (kind === null) return
  loaderLabel.value = LOADING_LABELS[kind] ?? ''
  if (kind === 'sensitivity') {
    void evaluateSensitivity()
    return
  }
  if (kind === 'voi') {
    void evaluateVoi()
    return
  }
  if (kind === 'price') {
    void enterPriceChapter()
    return
  }
  if (kind === 'budget') {
    void enterBudgetChapter()
    return
  }
  if (kind === 'readiness') {
    void enterReadinessChapter()
    return
  }
  if (kind === 'survival') {
    void enterSurvivalChapter()
    return
  }
  void evaluateUncertainty()
}

/** Clears the error of the bridge being retried, so the next answer is fresh. */
function clearBridgeError(
  kind:
    | 'uncertainty'
    | 'sensitivity'
    | 'voi'
    | 'price'
    | 'budget'
    | 'readiness'
    | 'survival'
    | null,
): void {
  if (kind === 'sensitivity') {
    sensitivityError.value = null
    return
  }
  if (kind === 'voi') {
    voiError.value = null
    return
  }
  if (kind === 'price') {
    priceError.value = null
    return
  }
  if (kind === 'budget') {
    budgetError.value = null
    return
  }
  if (kind === 'readiness') {
    readinessError.value = null
    return
  }
  if (kind === 'survival') {
    survivalError.value = null
    return
  }
  if (kind === 'uncertainty') uncertaintyError.value = null
}

/**
 * Opens the bridge at the end of a chapter and starts the work it is about.
 *
 * The learner arrives here by clicking the chapter's own advance control, which is
 * the one explicit moment at which the price they want the next chapter run at is
 * settled. So this is where the run starts — nowhere earlier. The recap stays on
 * screen while it runs, and repeated clicks cannot duplicate the request because
 * each calculation's own guard refuses a second one.
 */
function openRecap(): void {
  if (recapVisible.value) return
  const current = bridge.value
  if (!current.recap) return
  recapVisible.value = true
  clearBridgeError(current.kind)
  runBridge(current.kind)
}

/**
 * Leaves the open bridge for the chapter it names — or, after a failed run, tries
 * again.
 *
 * If the calculation has already answered, the chapter opens on its results. If it
 * has not, the shared loading screen is switched on for the wait and the chapter
 * opens the moment the answer lands — the recap itself is never swapped for a
 * loader, so a learner reading it is not interrupted.
 *
 * A failed run leaves the recap where it is, with the error under it. This control
 * is then a manual retry: it asks once more, and does nothing further on its own, so
 * a failure can never become a loop.
 */
function leaveRecap(): void {
  if (!recapVisible.value) return
  const current = bridge.value
  if (!current.recap) {
    recapVisible.value = false
    return
  }
  if (current.error !== null && !current.ready) {
    recapVisible.value = false
    showingLoader.value = true
    pendingChapterId.value = current.targetId
    clearBridgeError(current.kind)
    runBridge(current.kind)
    return
  }
  recapVisible.value = false
  if (current.ready) {
    goToChapter(current.targetId)
    return
  }
  // Still running: show the app-wide loader and wait for the answer.
  showingLoader.value = true
  loaderLabel.value = current.kind ? (LOADING_LABELS[current.kind] ?? '') : ''
  pendingChapterId.value = current.targetId
}

/**
 * Steps back one state. It only lowers what is on show: every point, arrow, leg and
 * bar stays drawn, so going back inspects the same graph rather than erasing it.
 *
 * Stepping back from the first state of a chapter returns to the last state of the
 * chapter before it, read from the journey's order. The case brief is not a chapter
 * of the panel, so the first chapter's first state is the end of the backward
 * journey rather than the brief.
 *
 * A standalone explainer has no chapter before it: its backward move stops at its own
 * first state, so revisiting a lesson can never walk into a chapter the learner did
 * not open.
 */
function previousStage(): void {
  if (recapVisible.value) {
    recapVisible.value = false
    return
  }
  if (isExplainer.value) {
    if (stageIndex.value > 0) stageIndex.value -= 1
    return
  }
  if (stageIndex.value > 0) {
    stageIndex.value -= 1
    return
  }
  const previous = previousChapterId.value
  if (previous === null || previous === chapterIds.value[0]) return
  chapterId.value = previous
  stageIndex.value = Math.max(0, stagesFor(previous).length - 1)
}

/** Switches to one of the chapters R publishes. */
function goToChapter(id: string): void {
  if (!chapterIds.value.includes(id)) return
  if (chapterId.value === id) return
  chapterId.value = id
  // Each chapter numbers its own states, and two chapters meet at the first state
  // of the next, so the state index restarts with the chapter.
  stageIndex.value = 0
  // A learner who jumps straight to a chapter from the navigation gets its results
  // without a bridge to read first. The linear journey never arrives here with work
  // outstanding, so this cannot start a calculation before a recap.
  if (id === SENSITIVITY_CHAPTER_ID) void evaluateSensitivity()
  if (id === UNCERTAINTY_CHAPTER_ID) void evaluateUncertainty()
  // The value of information is computed from the draws, not from the price, so a
  // jump here starts the simulation those draws come from and values them when they
  // land. The watcher below does the second half; neither step runs twice.
  if (id === VOI_CHAPTER_ID) void evaluateUncertainty()
  // The price chapter compares the price the learner chose with the price at which the
  // balance reaches zero. It has no lever of its own.
  if (id === PRICE_CHAPTER_ID) void enterPriceChapter()
  // The budget chapter reprices the same scenario under its own payment assumption. It
  // reads the journey's price and rewrites nothing.
  if (id === BUDGET_CHAPTER_ID) void enterBudgetChapter()
  // The readiness chapter reads none of the economic scenario: it assesses the case's
  // own ten inputs, four of which the learner chooses here. Entering it therefore
  // cannot disturb the price, the score or any earlier result.
  //
  // An explainer never arrives here; it sets its chapter directly, so opening a
  // lesson asks R for nothing.
  if (id === READINESS_CHAPTER_ID && !isExplainer.value) void enterReadinessChapter()
  // The last chapter reads the case's effect assumption and the model's own annual
  // risks only, so entering it cannot disturb any earlier result either. An explainer
  // sets its chapter directly, so opening the lesson asks R for nothing.
  if (id === SURVIVAL_CHAPTER_ID && !isExplainer.value) void enterSurvivalChapter()
}

/**
 * Opens the chapter that was waiting for its calculation, and takes the shared
 * loader down with it, so the loader exists only for the wait that asked for it.
 */
function settlePending(): void {
  const waiting = pendingChapterId.value
  if (waiting === null) return
  const ready =
    waiting === SENSITIVITY_CHAPTER_ID
      ? sensitivityResult.value !== null
      : waiting === VOI_CHAPTER_ID
        ? voiCached.value
        : waiting === PRICE_CHAPTER_ID
          ? priceShown.value !== null
          : waiting === BUDGET_CHAPTER_ID
            ? budgetShown.value !== null
            : waiting === READINESS_CHAPTER_ID
              ? readinessShown.value !== null
              : waiting === SURVIVAL_CHAPTER_ID
                ? survivalShown.value !== null
                : uncertaintyResult.value !== null
  if (!ready) return
  showingLoader.value = false
  pendingChapterId.value = null
  goToChapter(waiting)
}

watch(uncertaintyResult, settlePending)
watch(sensitivityResult, settlePending)
watch(voiResult, settlePending)
watch(priceResult, settlePending)
watch(budgetResult, settlePending)
watch(readinessResult, settlePending)
watch(survivalResult, settlePending)

/**
 * Values the draws as soon as they exist while the value chapter is on screen. A
 * jump into that chapter has no draws to value yet, so this is what completes it;
 * on the linear journey the draws are already there and the bridge has started the
 * work, so nothing is duplicated.
 */
watch(uncertaintyResult, (result) => {
  if (result !== null && isVoi.value) void evaluateVoi()
})

/**
 * A failed run puts the loader away and leaves the learner where they were. The
 * recap can be reopened and its arrow tried again; nothing retries on its own.
 */
function failPending(): void {
  const waiting = pendingChapterId.value
  if (waiting === null) return
  const failed =
    waiting === SENSITIVITY_CHAPTER_ID
      ? sensitivityError.value !== null
      : waiting === VOI_CHAPTER_ID
        ? voiError.value !== null
        : waiting === PRICE_CHAPTER_ID
          ? priceError.value !== null
          : waiting === BUDGET_CHAPTER_ID
            ? budgetError.value !== null
            : waiting === READINESS_CHAPTER_ID
              ? readinessError.value !== null
              : waiting === SURVIVAL_CHAPTER_ID
                ? survivalError.value !== null
                : uncertaintyError.value !== null
  if (!failed) return
  showingLoader.value = false
  pendingChapterId.value = null
}

watch(uncertaintyError, failPending)
watch(sensitivityError, failPending)
watch(voiError, failPending)
watch(priceError, failPending)
watch(budgetError, failPending)
watch(readinessError, failPending)
watch(survivalError, failPending)

/** Drives the app-wide loader for as long as the journey asks it to. */
let releaseLoader: (() => void) | null = null
watch(showingLoader, (show) => {
  if (show) {
    if (releaseLoader === null) releaseLoader = appBusy.start(loaderLabel.value)
    return
  }
  if (releaseLoader !== null) {
    releaseLoader()
    releaseLoader = null
  }
})

/** Restores R's own defaults and returns to the case brief. */
function restart(): void {
  clearAdjustTimer()
  evaluateToken += 1
  uncertaintyToken += 1
  sensitivityToken += 1
  voiToken += 1
  priceToken += 1
  recapVisible.value = false
  showingLoader.value = false
  pendingChapterId.value = null
  const control = contract.value?.base_case.controls[0]
  price.value =
    typeof control?.default === 'number'
      ? control.default
      : (contract.value?.case.proposed_price ?? null)
  const qalyControl = contract.value?.base_case.qaly?.control
  utility.value =
    typeof qalyControl?.default === 'number' ? qalyControl.default : null
  initialResult.value = null
  adjustedResult.value = null
  evaluateError.value = null
  evaluateBusy.value = false
  uncertaintyResult.value = null
  uncertaintyError.value = null
  uncertaintyBusy.value = false
  sensitivityResult.value = null
  sensitivityError.value = null
  sensitivityBusy.value = false
  voiResult.value = null
  voiSource.value = null
  voiThreshold.value = null
  voiError.value = null
  voiBusy.value = false
  priceResult.value = null
  priceSolve.value = null
  priceSolveKey.value = null
  priceError.value = null
  priceBusy.value = false
  priceAnswers.clear()
  budgetToken += 1
  budgetPrice.value = null
  budgetCoverage.value = null
  budgetResult.value = null
  budgetInFlight.value = null
  budgetError.value = null
  budgetBusy.value = false
  budgetAnswers.clear()
  readinessToken += 1
  readinessAnswers.value = {}
  readinessResult.value = null
  readinessInFlight.value = null
  readinessError.value = null
  readinessBusy.value = false
  readinessAnswersCache.clear()
  survivalToken += 1
  survivalTime.value = null
  survivalResult.value = null
  survivalInFlight.value = null
  survivalError.value = null
  survivalBusy.value = false
  survivalAnswers.clear()
  stageIndex.value = 0
  chapterId.value = chapters.value[0]?.id ?? ''
}

export function useTutorialJourney() {
  return {
    contract,
    contractBusy,
    contractError,
    chapterId,
    chapterStep,
    chapterIds,
    currentChapter,
    progressText,
    isUncertainty,
    isSensitivity,
    isVoi,
    isPrice,
    isBudget,
    isReadiness,
    isSurvival,
    chapterTitle,
    nextChapterId,
    previousChapterId,
    stage,
    stages,
    stageIndex,
    stageCount,
    canAdvance,
    graphActivates,
    stageNote,
    nextLabel,
    hasNext,
    chapterBusy,
    graph,
    price,
    utility,
    initialResult,
    adjustedResult,
    currentResult,
    baseCaseValues,
    evaluateBusy,
    evaluateError,
    uncertaintyResult,
    uncertaintyError,
    uncertaintyBusy,
    sensitivityResult,
    sensitivityError,
    sensitivityBusy,
    voiResult,
    voiError,
    voiBusy,
    priceShown,
    priceLatest: priceResult,
    priceError,
    priceBusy,
    budgetShown,
    budgetData,
    budgetCandidate,
    budgetStep,
    budgetShownNotes,
    budgetCoverage,
    budgetBusy,
    budgetError,
    setBudgetCoverage,
    readinessShown,
    readinessData,
    readinessChanged,
    readinessShownAnswers,
    readinessBusy,
    readinessError,
    readinessQuestion,
    setReadinessAnswer,
    retryReadiness,
    survivalShown,
    survivalData,
    survivalReads,
    survivalRead,
    survivalShownTime,
    survivalBusy,
    survivalError,
    setSurvivalTime,
    retrySurvival,
    isExplainer,
    moduleIdentity,
    hasProgress,
    enterExplainer,
    leaveExplainer,
    recap,
    recapVisible,
    showingLoader,
    openRecap,
    leaveRecap,
    loadContract,
    setPrice,
    setUtility,
    advanceStage,
    goToChapter,
    previousStage,
    restart,
  }
}
