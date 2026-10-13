/**
 * Guided Tutorial Part 1 session.
 *
 * This is the tutorial's own state, and it is deliberately separate from the
 * analysis dashboard: it never imports, reads or writes the `useModel` store, so
 * no tutorial control can move a dashboard input and no dashboard edit can move
 * a tutorial result. Everything the tutorial shows — defaults, ranges, labels,
 * statuses, thresholds, interpretations and formatted strings — arrives from R
 * through `GET /api/tutorial` (the contract) and `POST /api/tutorial/part1` (the
 * results for all four steps). Nothing here computes, classifies or rewords a
 * tutorial value.
 *
 * Update rule, matching the reference tutorial: the four steps have no run
 * button — a control change re-evaluates the whole Part 1 response, exactly as
 * the reference tutorial's reactive values did. The change is coalesced for a
 * moment so one drag of a slider is one request rather than one per pixel, and a
 * response that arrives out of order is discarded by its token.
 *
 * Session rule: the tutorial session is kept while the client is open and is
 * reset only by "Restart tutorial" (which restores R's own defaults) or by a page
 * reload. Navigating Home, into the full analysis, or between steps therefore
 * preserves the learner's values and place, which is what the reference tutorial
 * does by keeping its inputs in the page.
 */

import { computed, reactive, ref, shallowRef } from 'vue'
import { useAppBusy } from './useAppBusy'
import {
  fetchTutorial,
  fetchTutorialPart2,
  postTutorialPart1,
  postTutorialPart2Case,
  postTutorialPart2Evaluate,
} from '../api/client'
import type {
  Part2CaseResponse,
  Part2Contract,
  Part2EvaluateResponse,
  Part2ReadinessChoices,
  Part2ReadinessField,
  Part2Section,
  Part2SectionKey,
  TutorialContract,
  TutorialInputs,
  TutorialPart1Response,
  TutorialStepCopy,
} from '../api/types'

/** How long a control change is coalesced before one evaluation is requested. */
const EVALUATE_DEBOUNCE_MS = 220

/**
 * The Part 2 debounce is shorter than Part 1's because a Part 2 evaluation is a
 * single model run: the curve is posted back, so R re-classifies it instead of
 * re-running its forty-three points.
 */
const PART2_PRICE_DEBOUNCE_MS = 140

/**
 * The DHT readiness exercise's starting answers. This is static presentation
 * state, which is why it lives here rather than in R: R validates whatever level
 * ids it is sent and maps them onto the readiness inputs itself.
 */
const PART2_READINESS_DEFAULTS: Part2ReadinessChoices = {
  interoperability: 'strong',
  governance: 'partial',
  clinical_workflow: 'moderate',
  patient_engagement: 'low',
}

/**
 * The status sentences the app-wide loading indicator shows for the two Part 2
 * waits that can take time. A case draw uses R's own `entry_busy_label` once the
 * contract has arrived, so the loader speaks R's wording too; this fallback is
 * for the first draw, whose contract is still loading. The evaluation's sentence
 * is interface feedback about the request, like the "Updating…" lines the Part 2
 * sections already show, not tutorial content.
 */
const PART2_LOADING_LABEL = 'Loading the commissioning exercise…'
const PART2_EVALUATING_LABEL = 'Updating the commissioning results…'

const appBusy = useAppBusy()

const contract = shallowRef<TutorialContract | null>(null)
const contractBusy = ref(false)
const contractError = ref<string | null>(null)

const inputs = reactive<TutorialInputs>({})
const result = shallowRef<TutorialPart1Response | null>(null)
const resultError = ref<string | null>(null)
const evaluateBusy = ref(false)

const stepNumber = ref(1)
const completed = ref(false)

/**
 * Part 2 is a mode of the same tutorial session, not a second session: the part
 * flag is the only state Part 1 and Part 2 share, so switching between them
 * cannot disturb Part 1's step, inputs or results. Everything else about a
 * commissioning case — the opaque handle, the case's facts, the price lever, the
 * evaluation and the section — lives in `part2` below and has no connection to
 * the analysis dashboard at all.
 */
const tutorialPart = ref<'part1' | 'part2'>('part1')
const part2Contract = shallowRef<Part2Contract | null>(null)
const part2ContractBusy = ref(false)
const part2ContractError = ref<string | null>(null)
const part2Section = ref<Part2SectionKey>('brief')
/**
 * The exercise sections the learner has genuinely completed: the ones whose own
 * control produced a result. Opening a section never counts, and neither does
 * the case's own starting result, which R produces before the learner has
 * touched anything.
 */
const part2CompletedSections = ref<Part2SectionKey[]>([])
/**
 * The sections whose control the learner has just changed and whose result is
 * still on its way. A change is promoted to `part2CompletedSections` only when
 * the evaluation it asked for actually comes back, so a failed request cannot
 * mark an exercise as done. Not reactive: nothing renders it.
 */
const part2AwaitingResult = new Set<Part2SectionKey>()
/** The learner has already been congratulated, so it is not shown twice. */
const part2Congratulated = ref(false)
const part2Handle = ref<string | null>(null)
const part2Case = shallowRef<Part2CaseResponse | null>(null)
const part2Price = ref<number | null>(null)
const part2Coverage = ref<number | null>(null)
const part2Readiness = ref<Part2ReadinessChoices>({ ...PART2_READINESS_DEFAULTS })
const part2Evaluation = shallowRef<Part2EvaluateResponse | null>(null)
const part2Busy = ref(false)
const part2Error = ref<string | null>(null)

let part2ContractRequest: Promise<void> | null = null
let part2CaseRequest: Promise<void> | null = null
let part2EvaluateToken = 0
let part2Evaluating = false
let part2Queued = false
let part2Debounce: ReturnType<typeof setTimeout> | null = null

let contractRequest: Promise<void> | null = null
let evaluateToken = 0
let debounceTimer: ReturnType<typeof setTimeout> | null = null

function describe(error: unknown): string {
  if (error instanceof Error && error.message) return error.message
  return 'The tutorial results could not be loaded.'
}

/** Fills R's progress template, e.g. "Step {step} of {total}. {title}". */
function fill(template: string, values: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (match, key: string) =>
    key in values ? String(values[key]) : match,
  )
}

/**
 * Seeds the tutorial inputs from R's own defaults. Called when the contract
 * loads and on restart, so the tutorial always starts from the values R
 * published and never from anything the dashboard holds.
 */
function seedInputs(source: TutorialContract | null): void {
  const target = inputs as Record<string, number | boolean>
  for (const key of Object.keys(target)) {
    delete target[key]
  }
  if (!source) return
  for (const control of source.controls) {
    const value = source.defaults[control.id]
    if (typeof value === 'number' || typeof value === 'boolean') {
      target[control.id] = value
    }
  }
}

/**
 * Fetches the contract once and seeds the controls from it. A failed attempt
 * leaves the error visible and allows a retry.
 */
async function loadContract(): Promise<void> {
  if (contractRequest) return contractRequest
  contractBusy.value = true
  contractRequest = (async () => {
    try {
      const response = await fetchTutorial()
      contract.value = response.part1
      contractError.value = null
      seedInputs(response.part1)
    } catch (error) {
      contractError.value = describe(error)
      // Allow another attempt after a failure.
      contractRequest = null
    } finally {
      contractBusy.value = false
    }
  })()
  return contractRequest
}

/**
 * Evaluates all four steps in one request. The response is applied only if it is
 * still the newest one, so a slow reply cannot overwrite a newer result.
 */
async function evaluate(): Promise<void> {
  if (!contract.value) return
  const token = ++evaluateToken
  evaluateBusy.value = true
  try {
    const response = await postTutorialPart1({ ...inputs })
    if (token !== evaluateToken) return
    result.value = response
    resultError.value = null
  } catch (error) {
    if (token !== evaluateToken) return
    // The previous result stays on screen; the message beside it says the
    // current inputs could not be evaluated.
    resultError.value = describe(error)
  } finally {
    if (token === evaluateToken) evaluateBusy.value = false
  }
}

function scheduleEvaluate(): void {
  if (debounceTimer !== null) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    debounceTimer = null
    void evaluate()
  }, EVALUATE_DEBOUNCE_MS)
}

/** Sets one tutorial control and schedules one evaluation of the whole step set. */
function setInput(id: string, value: number | boolean): void {
  ;(inputs as Record<string, number | boolean>)[id] = value
  scheduleEvaluate()
}

/** One control's current value, for binding a rendered control. */
function inputValue(id: string): number | boolean | undefined {
  return (inputs as Record<string, number | boolean>)[id]
}

const stepCount = computed(() => contract.value?.progress.total ?? 4)
const steps = computed<TutorialStepCopy[]>(() => contract.value?.steps ?? [])
const currentStep = computed<TutorialStepCopy | null>(
  () => steps.value.find((step) => Number(step.id) === stepNumber.value) ?? null,
)

/** The controls that belong to one step, in R's order. */
function controlsForStep(stepIndex: number): TutorialContract['controls'] {
  return (contract.value?.controls ?? []).filter(
    (control) => control.step_index === stepIndex,
  )
}

/** R's progress line for the current state, with its numbers filled in. */
const progressText = computed(() => {
  const source = contract.value
  if (!source) return ''
  const total = source.progress.total
  if (completed.value) {
    return fill(source.progress.completed_template, { total })
  }
  return fill(source.progress.step_template, {
    step: stepNumber.value,
    total,
    title: currentStep.value?.progress ?? '',
  })
})

/** Moves to a step. A transition outside 1..total is refused rather than clamped away. */
function goToStep(step: number): void {
  const total = stepCount.value
  if (!Number.isFinite(step)) return
  const target = Math.round(step)
  if (target < 1 || target > total) return
  stepNumber.value = target
  completed.value = false
}

function next(): void {
  goToStep(stepNumber.value + 1)
}

function back(): void {
  goToStep(stepNumber.value - 1)
}

/** Shows the completion card. The four steps stay reachable afterwards. */
function finish(): void {
  completed.value = true
}

/** Restores R's own defaults and returns to Step 1, as "Restart tutorial" says. */
function restart(): void {
  seedInputs(contract.value)
  stepNumber.value = 1
  completed.value = false
  void evaluate()
}

// --- Guided Tutorial Part 2 -------------------------------------------------

/** Loads the Part 2 contract once, so the sections and labels are R's. */
async function loadPart2Contract(): Promise<void> {
  if (part2Contract.value || part2ContractRequest) return part2ContractRequest ?? undefined
  part2ContractBusy.value = true
  // The token settles exactly once, in the request's own `finally`, so a failed
  // contract load cannot leave the busy state behind.
  const done = appBusy.start(PART2_LOADING_LABEL)
  part2ContractRequest = (async () => {
    try {
      const response = await fetchTutorialPart2()
      part2Contract.value = response.part2
      part2ContractError.value = null
    } catch (error) {
      part2ContractError.value = describe(error)
      part2ContractRequest = null
    } finally {
      part2ContractBusy.value = false
      done()
    }
  })()
  return part2ContractRequest
}

/** R's banner sentence for the active case, from R's own template. */
const part2Banner = computed(() => part2Case.value?.case.banner ?? '')

/** R's heading for the active case, e.g. "Case A — Regional roll-out". */
const part2CaseHeading = computed(() => part2Case.value?.case.heading ?? '')

/** R's facts for the active case. */
const part2Facts = computed(() => part2Case.value?.case.facts ?? [])

/**
 * Enters Part 2, drawing a case if this session does not have one. A reload
 * starts a new case, because a fresh page holds no handle to send; returning to
 * Part 2 in the same session keeps the case the learner was working on.
 */
async function startPart2(): Promise<void> {
  tutorialPart.value = 'part2'
  part2Section.value = 'brief'
  await loadPart2Contract()
  if (part2Case.value) {
    // Already have a case: keep it, and re-evaluate the price currently chosen.
    if (part2Price.value !== null) {
      void evaluatePart2()
    }
    return
  }
  await createPart2Case()
}

/**
 * Draws a case from R. Only the opaque handle is kept.
 *
 * `excludeCaseId` is the retry rule: R draws from the other cases and reports the
 * draw as `redrawn`. Why the current handle is excluded rather than chosen in
 * TypeScript: only R knows which case a handle belongs to.
 */
async function createPart2Case(excludeCaseId?: string): Promise<void> {
  // The shell's own mount and the Part 1 entry both ask for a case, so the second
  // ask joins the first request instead of drawing a second case: two draws would
  // race, and the loser's curve could be evaluated under the winner's case id.
  if (part2CaseRequest) return part2CaseRequest
  part2Busy.value = true
  part2Error.value = null
  // One token for the whole draw, including the evaluation it awaits, and it is
  // called in the request's own `finally`, so a rejected draw clears both the
  // shell's busy line and the app-wide busy state.
  const done = appBusy.start(part2Contract.value?.entry_busy_label ?? PART2_LOADING_LABEL)
  part2CaseRequest = (async () => {
    try {
      const response = await postTutorialPart2Case(
        excludeCaseId ? { exclude_case_id: excludeCaseId } : {},
      )
      part2Case.value = response
      part2Handle.value = response.case.case_id
      part2Price.value = response.price.control.value
      // The coverage cap starts at the value R returned with the case, so the
      // budget section has a result the first time it is opened.
      part2Coverage.value = response.budget.control.value
      part2Evaluation.value = null
      // This is a new case, so the exercises are not done for it: the completions
      // belonged to the case just retired, and the evaluation below is R's own
      // starting result rather than the learner's work.
      resetPart2Completions()
      // One evaluation at the case's own starting price, so the value-for-money
      // section has a result the first time it is opened. The curve is posted back,
      // so this costs one model run rather than forty-four.
      await evaluatePart2()
    } catch (error) {
      part2Error.value = describe(error)
      part2CaseRequest = null
    } finally {
      part2Busy.value = false
      done()
    }
  })()
  return part2CaseRequest
}

/**
 * Evaluates the current price against R. The curve the case returned is posted
 * back so R re-classifies it instead of re-running it, which is what makes a
 * price change cost one model run. R decides every status in either path.
 */
async function evaluatePart2(): Promise<void> {
  const handle = part2Handle.value
  const price = part2Price.value
  const curve = part2Case.value?.price.curve
  if (!handle || price === null) return
  if (part2Evaluating) {
    // One evaluation is already in flight. The newest price or coverage wins, so
    // the next response cannot be overwritten by an older one.
    part2Queued = true
    return
  }
  const token = ++part2EvaluateToken
  part2Evaluating = true
  part2Busy.value = true
  // The token settles exactly once, in the `finally` below, whether the
  // evaluation resolves or rejects.
  const done = appBusy.start(PART2_EVALUATING_LABEL)
  try {
    // One request carries both levers: R evaluates the value-for-money section at
    // the price and the budget-impact section at the price and the coverage cap,
    // so the two sections always describe the same case at the same price.
    const response = await postTutorialPart2Evaluate({
      case_id: handle,
      price,
      coverage: part2Coverage.value ?? undefined,
      curve,
      ...part2Readiness.value,
    })
    if (token === part2EvaluateToken) {
      part2Evaluation.value = response
      part2Error.value = null
      // The result this change asked for has arrived, so the exercises it belongs
      // to are genuinely done. A failed evaluation never reaches this branch.
      if (part2AwaitingResult.size > 0) {
        for (const key of part2AwaitingResult) markPart2Completed(key)
        part2AwaitingResult.clear()
      }
    }
  } catch (error) {
    if (token === part2EvaluateToken) part2Error.value = describe(error)
  } finally {
    part2Evaluating = false
    if (token === part2EvaluateToken) part2Busy.value = false
    done()
    if (part2Queued) {
      part2Queued = false
      void evaluatePart2()
    }
  }
}

/** Sets the negotiated price and schedules one evaluation, coalesced. */
function setPart2Price(value: number): void {
  part2Price.value = value
  part2AwaitingResult.add('value')
  schedulePart2Evaluate()
}

/** Sets the coverage cap and schedules one evaluation, coalesced. */
function setPart2Coverage(value: number): void {
  part2Coverage.value = value
  part2AwaitingResult.add('budget')
  schedulePart2Evaluate()
}

/**
 * Retries Part 2 with different assumptions, from the completion card. R draws a
 * case other than the active one — the current handle is excluded, and R reports
 * the draw as `redrawn` — and the learner's own inputs go back to their defaults:
 * the four readiness answers to the exercise's defaults, and the price and the
 * coverage cap to the new case's own R-provided starting values. The learner stays
 * in Part 2, on the case brief, with the new case's results loading through the
 * same path the first case used.
 */
async function retryPart2(): Promise<void> {
  const previous = part2Handle.value
  // The retry is a new draw, never a join: an in-flight first draw must not
  // answer this request with the case being retried away from.
  part2CaseRequest = null
  part2Readiness.value = { ...PART2_READINESS_DEFAULTS }
  part2Section.value = 'brief'
  await createPart2Case(previous ?? undefined)
}

/** Sets one readiness answer and schedules one evaluation, coalesced. */
function setPart2Readiness(field: Part2ReadinessField, value: string): void {
  part2Readiness.value = { ...part2Readiness.value, [field]: value }
  part2AwaitingResult.add('readiness')
  schedulePart2Evaluate()
}

function schedulePart2Evaluate(): void {
  if (part2Debounce !== null) clearTimeout(part2Debounce)
  part2Debounce = setTimeout(() => {
    part2Debounce = null
    void evaluatePart2()
  }, PART2_PRICE_DEBOUNCE_MS)
}

/** R's progress line for the active Part 2 section. */
const part2ProgressText = computed(() => {
  const source = part2Contract.value
  if (!source) return ''
  const index = source.sections.findIndex((section) => section.key === part2Section.value)
  const step = index < 0 ? 1 : index + 1
  const name = source.sections[index < 0 ? 0 : index]?.name ?? ''
  return fill(source.progress.step_template, {
    step,
    total: source.progress.total,
    name,
  })
})

/** Moves to a Part 2 section. A section this slice does not implement is refused. */
function goToPart2Section(key: Part2SectionKey): void {
  const section = part2Contract.value?.sections.find((entry) => entry.key === key)
  if (!section || !section.available) return
  part2Section.value = key
}

/**
 * Records that a section has genuinely been worked through. It is what the
 * completion popup waits for: the three exercises before the recommendation must
 * each have produced a result from the learner's own input, so the congratulation
 * cannot appear before the learner has done the work it sums up. It reads no
 * status and no outcome, so no passing result, price or coverage level can decide
 * it.
 */
function markPart2Completed(key: Part2SectionKey): void {
  if (!part2CompletedSections.value.includes(key)) {
    part2CompletedSections.value = [...part2CompletedSections.value, key]
  }
}

/** The three exercises the completion popup waits for, in the reference order. */
const PART2_EXERCISE_SECTIONS: readonly Part2SectionKey[] = ['value', 'budget', 'readiness']

/** True once every exercise before the recommendation has produced a result. */
const part2ExercisesDone = computed(() =>
  PART2_EXERCISE_SECTIONS.every((key) => part2CompletedSections.value.includes(key)),
)

/** A new case carries no completions: they belonged to the case just retired. */
function resetPart2Completions(): void {
  part2CompletedSections.value = []
  part2AwaitingResult.clear()
}

const part2SectionIndex = computed(() => {
  const sections = part2Contract.value?.sections ?? []
  const index = sections.findIndex((section) => section.key === part2Section.value)
  return index < 0 ? 0 : index
})

const part2BackTarget = computed<Part2Section | null>(() => {
  const sections = part2Contract.value?.sections ?? []
  for (let index = part2SectionIndex.value - 1; index >= 0; index -= 1) {
    if (sections[index]?.available) return sections[index]
  }
  return null
})

const part2ForwardTarget = computed<Part2Section | null>(() => {
  const sections = part2Contract.value?.sections ?? []
  for (let index = part2SectionIndex.value + 1; index < sections.length; index += 1) {
    if (sections[index]?.available) return sections[index]
  }
  return null
})

/** Leaves Part 2 for the Part 1 completion screen, keeping Part 1 untouched. */
function leavePart2(): void {
  tutorialPart.value = 'part1'
  completed.value = true
}

export function useTutorialSession() {
  // Returned as a reactive object so a component reads `session.result` rather
  // than `session.result.value`, matching the dashboard store's convention and
  // avoiding ref-unwrapping mistakes in templates.
  return reactive({
    // contract
    contract,
    contractBusy,
    contractError,
    loadContract,
    // inputs
    inputs,
    setInput,
    controlsForStep,
    inputValue,
    // results
    result,
    resultError,
    evaluateBusy,
    evaluate,
    // navigation
    stepNumber,
    stepCount,
    steps,
    currentStep,
    completed,
    progressText,
    goToStep,
    next,
    back,
    finish,
    restart,
    // part 2
    tutorialPart,
    part2Contract,
    part2ContractBusy,
    part2ContractError,
    loadPart2Contract,
    startPart2,
    part2CompletedSections,
    part2ExercisesDone,
    part2Congratulated,
    createPart2Case,
    retryPart2,
    leavePart2,
    part2Section,
    goToPart2Section,
    part2ProgressText,
    part2BackTarget,
    part2ForwardTarget,
    part2Handle,
    part2Case,
    part2CaseHeading,
    part2Banner,
    part2Facts,
    part2Price,
    setPart2Price,
    part2Coverage,
    setPart2Coverage,
    part2Readiness,
    setPart2Readiness,
    part2Evaluation,
    part2Busy,
    part2Error,
    evaluatePart2,
  })
}
