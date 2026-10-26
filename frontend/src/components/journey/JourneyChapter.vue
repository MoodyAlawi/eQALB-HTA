<script setup lang="ts">
/**
 * The journey's chapter panel.
 *
 * One component renders every journey chapter, which is what lets the first
 * chapter's price state give way to the second chapter's cloud inside the same
 * panel: moving between chapters changes this component's values, not the
 * component, so the ECharts instance, the axes and the panel itself survive the
 * move. Nothing is torn down, and nothing fades out and back in.
 *
 * The panel is the only learning surface. It holds the plane, the guidance that
 * moves attention across it, the one sentence each state adds, the control that
 * moves to the next state, and — while the price is the question — the price
 * control. Every label, caption and value is R's; this component places them and
 * decides which state is lit, and it never formats a number or interprets one.
 *
 * The chart area is a convenience click target beside the overlay's labelled
 * control: it is in the pointer path, not the keyboard order, so the chapter
 * offers one announced way forward rather than two.
 */
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { JourneyPlaneLabels } from '../../api/types'
import InfoTip from '../InfoTip.vue'
import EcgOverlay from '../EcgOverlay.vue'
import MethodInfo from '../MethodInfo.vue'
import TutorialControl from '../tutorial/TutorialControl.vue'
import JourneyCostEffectivenessPlane from './JourneyCostEffectivenessPlane.vue'
import JourneyBudgetChart from './JourneyBudgetChart.vue'
import JourneyBeatCallout from './JourneyBeatCallout.vue'
import JourneyOverlay from './JourneyOverlay.vue'
import JourneyNextButton from './JourneyNextButton.vue'
import JourneyReadinessChart from './JourneyReadinessChart.vue'
import JourneyPriceChart from './JourneyPriceChart.vue'
import JourneySensitivityChart from './JourneySensitivityChart.vue'
import JourneyValueOfInformationChart from './JourneyValueOfInformationChart.vue'
import SurvivalCurveChart from '../charts/SurvivalCurveChart.vue'
import { useTutorialJourney } from '../../composables/useTutorialJourney'
import { useAppView } from '../../composables/useAppView'

const {
  contract,
  chapterId,
  chapterTitle,
  isUncertainty,
  isSensitivity,
  isVoi,
  isPrice,
  isBudget,
  isReadiness,
  isSurvival,
  stage,
  stages,
  stageIndex,
  stageNote,
  graphActivates,
  hasNext,
  nextLabel,
  chapterBusy,
  price,
  utility,
  initialResult,
  currentResult,
  evaluateError,
  uncertaintyResult,
  uncertaintyError,
  sensitivityResult,
  sensitivityError,
  voiResult,
  voiError,
  priceShown,
  priceLatest,
  priceError,
  budgetData,
  budgetShown,
  budgetStep,
  budgetCoverage,
  budgetError,
  setBudgetCoverage,
  readinessData,
  readinessShown,
  readinessChanged,
  readinessShownAnswers,
  readinessBusy,
  readinessError,
  readinessQuestion,
  setReadinessAnswer,
  retryReadiness,
  survivalData,
  survivalReads,
  survivalRead,
  survivalShownTime,
  survivalBusy,
  survivalError,
  setSurvivalTime,
  retrySurvival,
  isExplainer,
  recap,
  recapVisible,
  setPrice,
  setUtility,
  advanceStage,
  leaveRecap,
  restart,
} = useTutorialJourney()

const { show } = useAppView()

/**
 * The one sentence R writes to explain something the state introduces: the measure
 * in the base case, the method's name in each later chapter. Only the state that
 * introduces it carries one, so it appears once and is not repeated.
 */
const measureNote = computed(() => stage.value?.aside ?? null)

const control = computed(() => contract.value?.base_case.controls[0] ?? null)

/**
 * The plane's labels. The first two chapters publish the four labels the plane
 * draws; the first chapter alone names its two differences, so the second
 * chapter's are left undefined and the plane draws them without a label. The third
 * chapter draws no plane at all.
 */
const planeGraph = computed<JourneyPlaneLabels | null>(() => {
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

/** R's chart data for the deterministic point, from whichever chapter holds it. */
const chart0 = computed(() => currentResult.value?.base_case.chart ?? null)

const chart = computed(() => {
  const uncertainty = uncertaintyResult.value
  if (isUncertainty.value && uncertainty) {
    const point = chart0.value
    if (!point) return null
    const values = uncertainty.uncertainty.base_case
    return {
      ...point,
      points: [
        point.points[0],
        {
          label: point.points[1]?.label ?? '',
          incremental_cost: values.incremental_cost,
          incremental_qalys: values.incremental_qalys,
        },
      ],
    }
  }
  return chart0.value
})

/** The repeats, once R has drawn them. */
const cloud = computed(() =>
  isUncertainty.value ? (uncertaintyResult.value?.uncertainty.cloud ?? null) : null,
)
const mean = computed(() =>
  isUncertainty.value ? (uncertaintyResult.value?.uncertainty.mean ?? null) : null,
)

const isPriceState = computed(
  () =>
    !isUncertainty.value &&
    !isSensitivity.value &&
    !isVoi.value &&
    !isPrice.value &&
    !isBudget.value &&
    stage.value?.id === 'price',
)

/**
 * The base case's one-year QALY illustration. It is a state of its own with its own
 * control, so the graph does not advance past it and the sentence sits with the
 * slider rather than in the chart's call-out.
 */
const isQalyState = computed(
  () =>
    !isUncertainty.value &&
    !isSensitivity.value &&
    !isVoi.value &&
    !isPrice.value &&
    !isBudget.value &&
    stage.value?.id === 'qaly',
)

/** R's copy and the two model utilities for that illustration. */
const qaly = computed(() => contract.value?.base_case.qaly ?? null)

/**
 * The score the learner is dragging to, or null while the slider sits on the model's
 * own input. It exists only so the number and the one-year line follow the pointer:
 * `utility` is the model input, and it is written only when the change is committed.
 */
const qalyDraft = ref<number | null>(null)

/**
 * The score on screen: the value being dragged, otherwise the journey's own scenario
 * value, which is a model input. The control's default is the last fallback, for the
 * moment before the contract has supplied the model's own assumption.
 */
const qalyScoreValue = computed(
  () => qalyDraft.value ?? utility.value ?? qaly.value?.control.default ?? 0,
)

const qalyScoreDisplay = computed(() => qalyScoreValue.value.toFixed(2))

/** One year at that score: the illustration, not the model's calculation. */
const qalyResultDisplay = computed(() => qalyScoreValue.value.toFixed(2))

/** R's own words for the formula, with the two numbers the learner moves. */
const qalyFormula = computed(() => {
  const f = qaly.value?.formula
  if (!f) return ''
  return `${f.year} ${f.times} ${qalyScoreDisplay.value} ${f.equals} ${qalyResultDisplay.value} ${f.unit}`
})

/** R's sentence about the scenario's own score, or '' before the first answer. */
const qalyUtilityNote = computed(() => currentResult.value?.base_case.utility_note ?? '')

/**
 * R's note for the one score the uncertainty analysis cannot draw exactly, shown only
 * while that score is the one on screen. R decides which score that is; the interface
 * only shows what it is sent. It sits in the panel's information button with the answer
 * it qualifies, because it is about that one value rather than about the lesson.
 */
const qalyCeilingNote = computed(() => currentResult.value?.base_case.ceiling_note ?? null)

/**
 * The slider follows the pointer; the model is asked once the value is committed.
 *
 * A range input fires `input` on every pointer movement and `change` when the value is
 * settled, including when a keyboard learner releases an arrow key. Writing the model
 * input on `input` would therefore put one model run behind every pixel of a drag, so
 * the draft carries the live reading and only the commit reaches the scenario.
 */
function onQalyInput(event: Event): void {
  const target = event.target as HTMLInputElement | null
  if (!target) return
  const value = Number(target.value)
  if (Number.isFinite(value)) qalyDraft.value = value
}

function onQalyChange(event: Event): void {
  const target = event.target as HTMLInputElement | null
  if (!target) return
  const value = Number(target.value)
  if (!Number.isFinite(value)) return
  qalyDraft.value = null
  setUtility(value)
}

function resetQalyScore(): void {
  const fallback = qaly.value?.control.default
  qalyDraft.value = null
  if (typeof fallback === 'number') setUtility(fallback)
}

/**
 * A score that changed for a reason other than this slider — a restart, or the
 * scenario being reset — replaces whatever the learner was dragging, so the control
 * always shows the value the model is actually using.
 */
watch(utility, () => {
  qalyDraft.value = null
})

/** R's answer only when it describes the scenario on screen, so it is never stale. */
const priceView = computed(() => priceShown.value)

const priceReveal = computed<'track' | 'balance' | 'full'>(() => {
  const reveal = stage.value?.reveal
  if (reveal === 'track' || reveal === 'balance' || reveal === 'full') return reveal
  return 'full'
})

const priceGraph = computed(() => contract.value?.price.graph ?? null)

/** The price chapter's quiet detail: what the figures cover and what they do not. */
const priceDisclosure = computed(() => {
  if (!isPrice.value) return null
  const disclosure = priceLatest.value?.price.disclosure
  if (!disclosure || disclosure.lines.length === 0) return null
  return disclosure
})

/* --- Chapter 6: the budget ------------------------------------------------ */

/** R's chart labels for the budget chapter, and how much of the figure a state draws. */
const budgetGraph = computed(() => contract.value?.budget.graph ?? null)

const budgetReveal = computed<'intro' | 'annual' | 'cumulative'>(() => {
  const reveal = stage.value?.reveal
  if (reveal === 'intro' || reveal === 'annual' || reveal === 'cumulative') return reveal
  return 'cumulative'
})

/** How many of the component figures R has asked this state to reveal. */
const budgetComponentsShown = computed(() => {
  const shown = stage.value?.components_shown
  return typeof shown === 'number' ? shown : 0
})

/** The cap on screen, from whichever row R supplied for it. */
const budgetCoverageDisplay = computed(() => budgetStep.value?.coverage_display ?? null)

/**
 * The coverage lever, shown from the state that asks the learner to move it onward.
 * Its value is local: moving it selects a row R has already returned.
 */
const budgetStageIndex = computed(() =>
  stages.value.findIndex((entry: { id: string }) => entry.id === 'adoption'),
)

const budgetSliderVisible = computed(
  () =>
    isBudget.value &&
    budgetStageIndex.value >= 0 &&
    stageIndex.value >= budgetStageIndex.value,
)

const budgetSliderControl = computed(() => contract.value?.budget.control ?? null)

const budgetSliderValue = computed(() => {
  const value = budgetCoverage.value ?? budgetSliderControl.value?.default
  return typeof value === 'number' ? value : 0
})

function onBudgetSliderInput(event: Event): void {
  const target = event.target as HTMLInputElement | null
  if (!target) return
  const value = Number(target.value)
  if (Number.isFinite(value)) setBudgetCoverage(value)
}

const budgetDisclosure = computed(() => {
  if (!isBudget.value) return null
  const disclosure = budgetData.value?.disclosure
  if (!disclosure || disclosure.lines.length === 0) return null
  return disclosure
})

/** R's axis extents for the two panels, fixed from the whole sweep. */
const budgetAxis = computed(
  () => budgetData.value?.axis ?? { annual: { min: -1, max: 1 }, cumulative: { min: -1, max: 1 } },
)

const budgetPopulationDisplay = computed(
  () =>
    budgetData.value?.population_display ??
    (typeof contract.value?.budget.population === 'number'
      ? String(contract.value.budget.population)
      : ''),
)

const budgetHorizon = computed(
  () => budgetData.value?.horizon_years ?? contract.value?.budget.horizon_years ?? 0,
)

/* --- Chapter 7: the readiness check --------------------------------------- */

/** R's labels for the readiness figure, and how much of it this state draws. */
const readinessGraph = computed(() => contract.value?.readiness.graph ?? null)

const readinessReveal = computed<'intro' | 'chips'>(() =>
  stage.value?.reveal === 'chips' ? 'chips' : 'intro',
)

/** The question this state asks, from R's list, or null in the reading states. */
const readinessCurrentQuestion = computed(() =>
  readinessQuestion(stage.value?.question_id),
)

/** The chosen option of every question, for the answered state of each group. */
function readinessSelected(questionId: string): string | null {
  const answers = readinessShownAnswers.value as Record<string, string>
  return answers[questionId] ?? null
}

/** The answers to one question, as R publishes them. */
function readinessOptions(questionId: string) {
  return readinessQuestion(questionId)?.options ?? []
}

/**
 * The one explanation a state shows when the answer on screen produced a status: the
 * assessment's own sentence for that area, which is what R assigns the status from.
 * It appears only for the area the current answer changed, so the panel carries one
 * explanation rather than a page of repeated status text.
 */
const readinessFeedback = computed(() => {
  const data = readinessData.value
  const changed = readinessChanged.value
  if (!data) return null
  const domain = data.domains.find((entry) => entry.domain === changed?.domain)
  if (!domain) return null
  return {
    domain: domain.domain,
    status: domain.status,
    explanation: domain.explanation,
    optionLabel: changed?.option_label ?? '',
  }
})

/** The values the chapter holds fixed, shown on demand rather than asked about. */
const readinessFixed = computed(() => readinessData.value?.fixed ?? [])

const readinessDisclosure = computed(() => {
  if (!isReadiness.value) return null
  const disclosure = readinessData.value?.disclosure
  if (!disclosure || disclosure.lines.length === 0) return null
  return disclosure
})

function chooseReadiness(questionId: string, optionId: string): void {
  setReadinessAnswer(questionId as Parameters<typeof setReadinessAnswer>[0], optionId)
}

function statusClass(status: string): string {
  if (status === 'Green') return 'ready__status--green'
  if (status === 'Amber') return 'ready__status--amber'
  return 'ready__status--red'
}

/* --- The last chapter: time to a first event ------------------------------ */

/** The figure's own labels: what is timed, what the event is, and the qualifier. */
const survivalGraph = computed(() => contract.value?.survival.graph ?? null)

/**
 * Which beat of the lesson this state is. Each one reads the same curves at the time
 * the learner chose, so the state only decides which sentences and figures are shown.
 */
const survivalBeat = computed<'time' | 'step' | 'compare'>(() => {
  const beat = stage.value?.beat
  if (beat === 'step' || beat === 'compare') return beat
  return 'time'
})

/** R's account of what the curves estimate, and what they do not. */
const survivalDisclosure = computed(() => {
  if (!isSurvival.value) return null
  const disclosure = survivalData.value?.disclosure
  if (!disclosure || disclosure.lines.length === 0) return null
  return disclosure
})

/**
 * The interval to mark on the figure, and — on the reading and comparison beats —
 * the time the beat is about.
 *
 * The emphasis follows the beat, so the figure says the same thing as the sentence
 * beside it: the reading beat marks the time being read, the downward-movement beat
 * shades the interval it describes and draws the level the curve ends on, and the
 * comparison beat draws both arms' levels at that one time so the two numbers in the
 * sentence have their two lines on the chart. The arm, the two years and every value
 * are R's, so the emphasis cannot point at a stretch of curve the sentence is not
 * about. Every value is null outside this chapter, and the plane chapters pass
 * nothing at all, so no other caller's chart changes.
 */
const survivalHighlight = computed(() => {
  if (!isSurvival.value) return null
  const read = survivalRead.value
  if (!read) return null
  const beat = survivalBeat.value
  if (beat === 'step') {
    return {
      treatment: read.step.treatment,
      from: read.step.from_years,
      to: read.step.to_years,
      level: read.step.to_estimate,
      compareLevel: null,
      atTime: null,
    }
  }
  // The reading and comparison beats: one vertical mark at the chosen time, and on the
  // comparison beat a level line for each arm at that time, in R's own order.
  const [first, second] = read.arms
  return {
    treatment: first?.treatment ?? '',
    from: read.years,
    to: read.years,
    level: beat === 'compare' ? (first?.estimate ?? null) : null,
    compareLevel:
      beat === 'compare' && second
        ? { level: second.estimate ?? null, treatment: second.treatment }
        : null,
    atTime: read.years,
  }
})

/* --- The journey's end ---------------------------------------------------- */

/**
 * The journey's own ending, as R writes it: the overlay's heading and line, and its two
 * actions. It is shown only when the chapter list has nothing after the chapter on
 * screen, so a chapter added later moves the overlay with the contract and no copy here
 * has to change. A standalone explainer never shows it: its lesson ends with its own
 * return to the module that opened it.
 */
const endCard = computed(() => contract.value?.journey.end ?? null)

/**
 * Whether the learner has closed the completion overlay without choosing an action.
 *
 * Closing returns them to the final chart, and the overlay must not immediately
 * reopen — that would be a loop with no way out. The flag is cleared whenever the
 * chapter or the state changes, so moving away and coming back shows the ending again
 * rather than hiding it for the rest of the session.
 */
const endDismissed = ref(false)
watch([chapterId, stageIndex], () => {
  endDismissed.value = false
})

/** Whether the completion overlay is on screen: the last state, and not dismissed. */
const endOpen = computed(
  () =>
    !isExplainer.value &&
    !hasNext.value &&
    !recapVisible.value &&
    endCard.value !== null &&
    !endDismissed.value,
)

/** Closes the overlay and leaves the learner on the final chart. */
function closeEnd(): void {
  endDismissed.value = true
}

/** The overlay's primary action: hand the learner to the analysis app as it stands. */
function openAnalysis(): void {
  endDismissed.value = true
  show('dashboard')
}

/**
 * The overlay's secondary action: the journey's own restart, unchanged.
 *
 * It resets the journey and nothing else — the dashboard's inputs, results and selected
 * tab are untouched — which is what the restart has always done. The overlay closes
 * with it because the reset moves the journey back to its first chapter.
 */
function restartJourney(): void {
  endDismissed.value = true
  restart()
}

/**
 * The value-of-information chapter's own chart inputs: R's labels, R's figures, and
 * how much of the figure this state draws.
 */
const voiGraph = computed(() => contract.value?.voi.graph ?? null)

const voiReveal = computed<'now' | 'both' | 'gap' | 'evppi'>(() => {
  const reveal = stage.value?.reveal
  if (reveal === 'now' || reveal === 'both' || reveal === 'gap' || reveal === 'evppi') {
    return reveal
  }
  return 'evppi'
})

/** The ranking the third chapter is drawing at this state, or null in a plane chapter. */
const sensitivityOutcome = computed(() => {
  const result = sensitivityResult.value
  if (!isSensitivity.value || !result) return null
  return stage.value?.view === 'health'
    ? result.sensitivity.outcomes.health
    : result.sensitivity.outcomes.cost
})

/** The third chapter's chart labels: both axis names, the reference and the ends. */
const barsGraph = computed(() => contract.value?.sensitivity.graph ?? null)

/**
 * The third chapter's quiet disclosure: the three methodological notes its states
 * used to print beside the bars. R publishes them with the chapter's contract, so
 * the panel keeps the caption and the bars, and the caveats are one click away.
 */
const sensitivityDisclosure = computed(() => {
  const disclosure = contract.value?.sensitivity.disclosure
  if (!disclosure || disclosure.lines.length === 0) return null
  return disclosure
})

/**
 * The quiet disclosure under the uncertainty chart: which assumptions the
 * simulation actually varied and which it held fixed, with R's sentences. It is a
 * closed disclosure, so the main story stays short and the detail is one click away
 * for a learner who wants it.
 */
const variation = computed(() => {
  if (!isUncertainty.value) return null
  const result = uncertaintyResult.value
  if (!result) return null
  const info = result.uncertainty.variation
  const title = contract.value?.uncertainty.copy.variation_title ?? ''
  if (!info || !title) return null
  return {
    title,
    lines: [
      info.method_sentence ?? '',
      info.varied_sentence,
      info.held_sentence,
      info.ranges_sentence,
    ].filter((line) => line.length > 0),
    varied: info.varied,
    held: info.held,
  }
})

/**
 * The quiet disclosure under the value-of-information chart: what the figures cover,
 * that the model's horizon is not a research horizon, and that the population figure
 * is not calculated. Closed by default, so the story stays short.
 */
const voiDisclosure = computed(() => {
  if (!isVoi.value) return null
  const disclosure = voiResult.value?.voi.disclosure
  if (!disclosure || disclosure.lines.length === 0) return null
  return disclosure
})

/**
 * How long the ranked chart takes to redraw when the view changes. Only the
 * presentation moves: R's numbers are replaced in one step, but the bars travel, so
 * the way forward is held for the duration rather than letting a learner advance
 * past a chart that is still rearranging itself.
 */
const VIEW_TRANSITION_MS = 320

const reducedMotion =
  typeof window !== 'undefined' &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches

const chartSettling = ref(false)
let settleTimer: ReturnType<typeof setTimeout> | null = null

watch(
  () => (isSensitivity.value ? (stage.value?.view ?? null) : null),
  (view, previous) => {
    if (settleTimer !== null) clearTimeout(settleTimer)
    settleTimer = null
    if (!view || !previous || view === previous || reducedMotion) {
      chartSettling.value = false
      return
    }
    chartSettling.value = true
    settleTimer = setTimeout(() => {
      settleTimer = null
      chartSettling.value = false
    }, VIEW_TRANSITION_MS)
  },
)

/**
 * The first request of the first chapter is the one the learner has nothing to
 * look at yet: the graph holds a single point and no values. Later requests only
 * move a point that is already drawn.
 *
 * The second chapter never waits inside its own panel: its simulation is started
 * from the recap, and the shared app-wide loader covers any wait, so this is the
 * first chapter's state alone.
 */
const showPreparing = computed(
  () =>
    chapterBusy.value &&
    initialResult.value === null &&
    !isUncertainty.value &&
    !isSensitivity.value &&
    !isVoi.value &&
    !isPrice.value &&
    !isBudget.value,
)

const priceBlock = ref<HTMLElement | null>(null)
const chartBlock = ref<HTMLElement | null>(null)
const surface = ref<HTMLElement | null>(null)
const recapHeading = ref<HTMLElement | null>(null)
/** The panel's own way forward, wherever the journey currently shows it. */
const footerNext = ref<HTMLButtonElement | null>(null)

/**
 * Whether the sentence sits under the chart instead of beside the feature. The
 * plane knows its own width, so it is asked rather than guessed here; the overlay's
 * own threshold and this one are the same number.
 *
 * The third chapter always uses the strip: its chart carries no call-out, and the
 * ranked views are read best with the whole width of the panel, so the caption and
 * the way forward stay in one place at every state.
 */
const narrowPlane = ref(false)
let planeObserver: ResizeObserver | null = null

function measurePlane(): void {
  const element = chartBlock.value
  if (!element) return
  narrowPlane.value = element.clientWidth < 520
  if (!planeObserver) {
    planeObserver = new ResizeObserver(measurePlane)
    planeObserver.observe(element)
  }
}

onMounted(() => {
  measurePlane()
  window.addEventListener('resize', measurePlane, { passive: true })
})

onBeforeUnmount(() => {
  planeObserver?.disconnect()
  planeObserver = null
  window.removeEventListener('resize', measurePlane)
  if (settleTimer !== null) clearTimeout(settleTimer)
  settleTimer = null
})

/**
 * Whether the plane's own sentence has to sit under the chart instead of beside the
 * feature.
 *
 * Only the plane chapters use this: they draw their sentence inside the plane,
 * anchored to the region they point at, and on a narrow screen that card cannot fit
 * beside the feature without covering it. Every other chapter shows its sentence in
 * the shared callout, so this is not used there and a chapter cannot print the same
 * sentence twice.
 */
const stackedNote = computed(
  () =>
    stageNote.value.length > 0 &&
    !isQalyState.value &&
    !isSensitivity.value &&
    !isVoi.value &&
    !isPrice.value &&
    !isBudget.value &&
    !isReadiness.value &&
    !isSurvival.value &&
    narrowPlane.value &&
    !isPriceState.value,
)

/**
 * Focus follows the learner's own control. The overlay's control persists across
 * the states that have one, so a keyboard learner's focus survives the change on
 * its own; the price state removes it in favour of the slider, so focus moves
 * there rather than being dropped on the page body.
 */
watch(stageIndex, () => {
  void nextTick(() => {
    if (isPriceState.value) {
      priceBlock.value?.querySelector<HTMLInputElement>('input[type="range"]')?.focus()
    }
  })
})

/**
 * The recap is a surface that covers the panel, so focus goes into it when it
 * opens and comes back out to the control it covered when it closes: the price
 * control in the first chapter, the ranking's own way forward in the third.
 * Moving focus is what makes the covered controls unreachable for a keyboard
 * learner as well as a pointer one, and the recap's own heading is announced on
 * arrival.
 */
watch(recapVisible, (visible) => {
  void nextTick(() => {
    if (visible) {
      recapHeading.value?.focus()
      return
    }
    // Focus returns to whatever covered control the learner was using: the panel's own
    // way forward, the price control when that is what the recap covered, and
    // otherwise the panel itself.
    const nextControl = surface.value?.querySelector<HTMLButtonElement>(
      '.journey__next:not([disabled])',
    )
    if (nextControl) {
      nextControl.focus()
      return
    }
    const slider = priceBlock.value?.querySelector<HTMLInputElement>('input[type="range"]')
    if (slider) {
      slider.focus()
      return
    }
    chartBlock.value?.focus()
  })
})

/**
 * The last state of a chapter has no way forward of its own, so the control the
 * learner was using is removed. Focus moves to the panel rather than being dropped
 * on the page body; the sentence itself is already announced by the live region.
 */
watch(hasNext, (available) => {
  if (available) return
  void nextTick(() => {
    const active = document.activeElement
    const lost =
      !active || active === document.body || active.closest('.journey__next')
    if (lost) chartBlock.value?.focus()
  })
})

/**
 * The advance control is held while R works, and a disabled control cannot hold
 * focus, so the learner is put back on it once the answer lands. Only a lost focus
 * is restored: a learner who has moved on with Tab is left alone.
 *
 * There is now one such control for the whole journey, in the panel's footer, so this
 * no longer has to know which chapter is on screen.
 */
watch(chapterBusy, (busy) => {
  if (busy) return
  void nextTick(() => {
    if (!hasNext.value) return
    const active = document.activeElement
    const lost = !active || active === document.body
    if (!lost) return
    footerNext.value?.focus()
  })
})

/**
 * The sentence the chapter's one callout shows, or '' where the state's own control
 * carries the lesson instead.
 *
 * The base-case chapters draw their sentence inside the plane, anchored to the region
 * they are pointing at, so it is already a callout on the figure and is not repeated
 * here. Every other chapter states its beat in this one place: the value chapter's
 * notes, the price and budget sentences, the readiness captions and the survival
 * beats. A readiness question state is skipped while its question is on screen,
 * because that state's feedback card carries the same idea with the status beside it.
 */
const beatText = computed(() => {
  if (isUncertainty.value || isSensitivity.value || isVoi.value) return stageNote.value
  if (isPrice.value || isBudget.value) return stageNote.value
  if (isReadiness.value) return readinessCurrentQuestion.value ? '' : stageNote.value
  if (isSurvival.value) return stageNote.value
  return ''
})

/**
 * R's one-sentence explanation of a measure a beat introduces, when the state names
 * one and the sentence is not already inside the plane's own callout.
 */
const beatMeasure = computed(() => {
  if (!beatText.value) return null
  return measureNote.value
})

/**
 * The dashboard module a chapter explains, for its method note. It is the module id
 * R's own dictionary keys the note by, so the lesson and the tab show one note; a
 * chapter with no module counterpart — the case brief and the base case — has none.
 */
const chapterModuleId = computed<string | null>(() => {
  if (isSensitivity.value) return 'sensitivity'
  if (isUncertainty.value) return 'uncertainty'
  if (isVoi.value) return 'voi'
  if (isPrice.value) return 'price'
  if (isBudget.value) return 'budget'
  if (isReadiness.value) return 'readiness'
  if (isSurvival.value) return 'survival'
  return null
})

/**
 * Whether the chart is mid-redraw and the way forward is held for it. *
 * The readiness chapter holds it while it has no assessment for the answers on screen:
 * its states read that assessment, so advancing before it exists would move the panel
 * to a state with nothing in it. The last chapter holds it for the same reason while it
 * has no simulated curves: every one of its states reads them. A failed request
 * therefore leaves the arrow disabled and the error's own retry is the way forward.
 *
 * A standalone lesson is the one exception, and deliberately so: it opens without
 * asking R for anything, so there is no assessment, sweep or set of curves yet, and the
 * first advance is what requests one. Only a failed request holds the arrow there, so a
 * failure can never leave a silently dead control.
 */
const advanceHeld = computed(
  () =>
    chapterBusy.value ||
    chartSettling.value ||
    (isReadiness.value &&
      readinessShown.value === null &&
      (!isExplainer.value || readinessError.value !== null)) ||
    (isBudget.value &&
      budgetShown.value === null &&
      (!isExplainer.value || budgetError.value !== null)) ||
    (isSurvival.value &&
      survivalData.value === null &&
      (!isExplainer.value || survivalError.value !== null)),
)

function activate(): void {
  // While the recap covers the panel, the only way forward is the recap's own
  // control: a click that lands on the panel behind it must not advance anything,
  // which is what stops the click that opened the recap from also leaving it.
  if (recapVisible.value) return
  if (advanceHeld.value) return
  advanceStage()
}

/**
 * The chart's own click target. It advances only where the graph is the state's
 * activation, so a state that provides its own control — the QALY illustration, the
 * price slider — cannot be skipped by a click aimed at the chart behind it.
 */
function activateGraph(): void {
  if (!graphActivates.value) return
  activate()
}
</script>

<template>
  <section class="tutorial__step journey__chapter" aria-labelledby="journey-chapter-title">
    <!-- The chapter's heading row, with its module's method note beside it: the same
         control the analysis module carries, keyed by the dashboard module the chapter
         explains, so a learner can read the method in the lesson and in the app and get
         the same R-owned answer in both. The base-case chapter has no module of its own
         in that dictionary, so its heading keeps its plain shape. -->
    <div class="panel__title-row journey__heading-row">
      <h3 id="journey-chapter-title" class="tutorial__step-title" tabindex="-1">
        {{ chapterTitle }}
      </h3>
      <MethodInfo v-if="chapterModuleId" :module="chapterModuleId" />
    </div>

    <!-- One panel for every chapter: the chart, its guidance, the sentence the
         state adds and, while the price is the question, the price control. The
         third chapter replaces the chart inside this panel rather than the panel
         itself, so the surface and the navigation around it are carried across. -->
    <div ref="surface" class="journey__surface">
      <div
        ref="chartBlock"
        class="journey__chart"
        :class="{ 'is-activatable': graphActivates }"
        data-journey-advance
        tabindex="-1"
        :data-chapter="chapterId"
        @click="activateGraph()"
      >
        <JourneySensitivityChart
          v-if="isSensitivity && barsGraph"
          :graph="barsGraph"
          :outcome="sensitivityOutcome"
          :view="stage?.view ?? 'cost'"
          :focus="stage?.focus ?? 'none'"
          :reveal="stage?.reveal === 'top' ? 'top' : 'all'"
          :ends="stage?.ends === true"
          :dim="stage?.focus !== 'none'"
          :scope="chapterId"
        />
        <JourneyValueOfInformationChart
          v-else-if="isVoi && voiGraph"
          :graph="voiGraph"
          :result="voiResult?.voi ?? null"
          :reveal="voiReveal"
          :focus="stage?.focus ?? 'none'"
          :dim="stage?.focus !== 'none'"
          :scope="chapterId"
        />
        <JourneyPriceChart
          v-else-if="isPrice && priceGraph"
          :graph="priceGraph"
          :result="priceView"
          :reveal="priceReveal"
          :focus="stage?.focus ?? 'none'"
          :dim="stage?.focus !== 'none'"
          :scope="chapterId"
        />
        <JourneyBudgetChart
          v-else-if="isBudget && budgetGraph"
          :graph="budgetGraph"
          :step="budgetStep"
          :population-display="budgetPopulationDisplay"
          :horizon-years="budgetHorizon"
          :coverage-display="budgetCoverageDisplay"
          :axis="budgetAxis"
          :reveal="budgetReveal"
          :components-shown="budgetComponentsShown"
          :focus="stage?.focus ?? 'none'"
          :dim="stage?.focus !== 'none'"
          :scope="chapterId"
        />
        <JourneyReadinessChart
          v-else-if="isReadiness && readinessGraph"
          :graph="readinessGraph"
          :result="readinessData"
          :reveal="readinessReveal"
          :focus="stage?.focus ?? 'none'"
          :dim="stage?.focus !== 'none'"
          :scope="chapterId"
        />
        <!-- The last chapter reuses the Simulated survival tab's own chart, unchanged:
             the same step coordinates, the same two arms and the same 95% bands. Only
             the labels around it are the journey's. The figure keeps its own title and
             qualifier even before the curves arrive, so the panel says what it is about
             while the first request runs. -->
        <div v-else-if="isSurvival && survivalGraph" class="journey__km">
          <p class="journey__km-title">{{ survivalGraph.title }}</p>
          <p class="journey__km-qualifier">{{ survivalGraph.qualifier }}</p>
          <SurvivalCurveChart
            v-if="survivalData"
            :steps="survivalData.steps"
            :followup-years="survivalData.followup_years"
            :highlight="survivalHighlight"
          />
          <p v-else class="journey__km-pending">
            The curves appear once the simulation has run.
          </p>
        </div>
        <JourneyCostEffectivenessPlane
          v-else-if="planeGraph"
          ref="plane"
          :chart="chart"
          :graph="planeGraph"
          :state="stageIndex"
          :focus="stage?.focus ?? 'origin'"
          :lead="stage?.lead ?? null"
          :note="isQalyState || stackedNote ? '' : stageNote"
          :measure-note="stage?.aside ?? null"
          :dim="!isPriceState"
          :scope="chapterId"
          :cloud="cloud"
          :mean="mean"
          :cloud-label="isUncertainty ? contract?.uncertainty.graph.cloud_label : null"
          :mean-label="isUncertainty ? contract?.uncertainty.graph.mean_label : null"
        />
        <!-- The first calculation of the first chapter is the only wait long
             enough to need saying inside the panel. Every later wait is the shared
             app-wide loader's job, started from the bridge. -->
        <p v-if="showPreparing" class="journey__preparing" role="status">
          <span class="journey__preparing-track" aria-hidden="true">
            <span class="journey__preparing-segment"></span>
          </span>
          <span class="journey__preparing-text">Preparing the first results…</span>
        </p>
        <p v-else-if="chapterBusy" class="journey__busy" aria-live="polite">
          Working it out…
        </p>
      </div>

      <!-- The chapter's teaching beat, in the one callout shape the whole journey
           uses: R's sentence for the state, and R's note where the state introduces a
           measure. It is the same component in every chapter, so the sentence changes
           in exactly one place as the learner moves. The readiness chapter keeps its
           question state's sentence out of it while a question is on screen, because
           the question's own feedback carries that state. -->
      <JourneyBeatCallout
        v-if="beatText"
        :text="beatText"
        :measure="beatMeasure"
        :step="stageIndex + 1"
        :total="stages.length"
      />

      <!-- The one-at-a-time chapter's quiet detail: the method's name, what a flat bar
           means and what a long bar does not mean. Closed by default, so the caption
           and the bars carry the story. -->
      <details
        v-if="
          isSensitivity &&
          sensitivityDisclosure &&
          sensitivityDisclosure.title &&
          sensitivityDisclosure.lines.length > 0
        "
        class="details journey__variation"
      >
        <summary>{{ sensitivityDisclosure.title }}</summary>
        <p v-for="(line, index) in sensitivityDisclosure.lines" :key="index">{{ line }}</p>
      </details>

      <!-- The uncertainty chapter's quiet detail: which assumptions the repeat
           simulation varied, and which it held. Closed by default, so it never
           competes with the sentence that carries the story. -->
      <details v-if="variation" class="details journey__variation">
        <summary>{{ variation.title }}</summary>
        <p v-for="(line, index) in variation.lines" :key="index">{{ line }}</p>
        <p class="journey__variation-list">
          <span class="journey__variation-label">Varied:</span>
          {{ variation.varied.join('; ') }}
        </p>
        <p v-if="variation.held.length" class="journey__variation-list">
          <span class="journey__variation-label">Held:</span>
          {{ variation.held.join('; ') }}
        </p>
      </details>

      <!-- The value-of-information chapter's quiet detail: what the figures cover,
           that the model's horizon is not a research horizon, and that the
           population figure is not calculated here. -->
      <details v-if="voiDisclosure" class="details journey__variation">
        <summary>{{ voiDisclosure.title }}</summary>
        <p v-for="(line, index) in voiDisclosure.lines" :key="index">{{ line }}</p>
      </details>

      <!-- The price chapter's quiet detail: how the balance and the solved price are
           defined, what they hold fixed, and what they do not claim. -->
      <details v-if="priceDisclosure" class="details journey__variation">
        <summary>{{ priceDisclosure.title }}</summary>
        <p v-for="(line, index) in priceDisclosure.lines" :key="index">{{ line }}</p>
      </details>

      <!-- The budget chapter's quiet detail: the two payment assumptions, the horizon
           and the discounting, and the affordability question this chapter does not
           answer. -->
      <details v-if="budgetDisclosure" class="details journey__variation">
        <summary>{{ budgetDisclosure.title }}</summary>
        <p v-for="(line, index) in budgetDisclosure.lines" :key="index">{{ line }}</p>
      </details>

      <!-- The readiness chapter's quiet detail: what is held fixed, how the statuses
           are decided, and what the exercise is not. -->
      <details v-if="readinessDisclosure" class="details journey__variation">
        <summary>{{ readinessDisclosure.title }}</summary>
        <p v-for="(line, index) in readinessDisclosure.lines" :key="index">{{ line }}</p>
      </details>

      <!-- The readiness chapter's four questions. Each answer is a short scenario
           rather than a level's technical name, and choosing one re-assesses the case
           through calculate_readiness(). No answer is required to be the strongest:
           the group marks the answer on screen and leaves the rest readable, so a
           learner can see what each choice would mean. -->
      <div
        v-if="isReadiness && readinessCurrentQuestion"
        class="ready ready--question"
      >
        <fieldset class="ready__fieldset">
          <legend class="ready__legend">{{ readinessCurrentQuestion.label }}</legend>
          <div class="ready__options">
            <button
              v-for="option in readinessOptions(readinessCurrentQuestion.id)"
              :key="option.id"
              type="button"
              class="ready__option"
              :class="{ 'is-selected': readinessSelected(readinessCurrentQuestion.id) === option.id }"
              :aria-pressed="readinessSelected(readinessCurrentQuestion.id) === option.id"
              :disabled="readinessBusy"
              @click.stop="chooseReadiness(readinessCurrentQuestion.id, option.id)"
            >
              <span class="ready__option-text">{{ option.label }}</span>
            </button>
          </div>
        </fieldset>
      </div>

      <!-- What the answer on screen did to the assessment: the area's status and the
           assessment's own sentence for it, so the learner reads why this model assigns
           that status rather than being told to try again. -->
      <div v-if="isReadiness && readinessFeedback" class="ready__feedback" aria-live="polite">
        <p class="ready__feedback-head">
          <span class="ready__feedback-domain">{{ readinessFeedback.domain }}</span>
          <span class="ready__status" :class="statusClass(readinessFeedback.status)">
            {{ readinessFeedback.status }}
          </span>
        </p>
        <p class="ready__feedback-text">{{ readinessFeedback.explanation }}</p>
      </div>

      <!-- The values the chapter holds fixed, on demand: the two access shares, the two
           engagement values and accessibility are the case's, not the learner's to
           change here. -->
      <details v-if="isReadiness && readinessFixed.length > 0" class="details ready__fixed">
        <summary>{{ readinessGraph?.fixed_title }}</summary>
        <p class="ready__fixed-note">{{ readinessGraph?.fixed_note }}</p>
        <ul class="ready__fixed-list">
          <li v-for="row in readinessFixed" :key="row.label">
            <span>{{ row.label }}</span>
            <span class="ready__fixed-value">{{ row.value_display }}</span>
          </li>
        </ul>
      </details>

      <!-- The last chapter's one control: which time to read the curves at. All three
           times come from the one response, so choosing another only selects a reading
           R has already computed — no request is made and nothing earlier changes. -->
      <div v-if="isSurvival && survivalReads.length > 0" class="ready ready--question">
        <fieldset class="ready__fieldset">
          <legend class="ready__legend">{{ survivalGraph?.times_title }}</legend>
          <div class="ready__options">
            <button
              v-for="read in survivalReads"
              :key="read.id"
              type="button"
              class="ready__option"
              :class="{ 'is-selected': survivalShownTime?.id === read.id }"
              :aria-pressed="survivalShownTime?.id === read.id"
              @click.stop="setSurvivalTime(read.id)"
            >
              <span class="ready__option-text">{{ read.label }}</span>
            </button>
          </div>
        </fieldset>
      </div>

      <!-- The two estimates at the chosen time, in R's numbers, whatever beat this is:
           they are the reading every beat is built on. -->
      <div v-if="isSurvival && survivalRead" class="journey__km-reads" aria-live="polite">
        <div v-for="arm in survivalRead.arms" :key="arm.treatment" class="journey__km-read">
          <p class="journey__km-read-label">{{ arm.treatment }}</p>
          <p class="journey__km-read-value">{{ arm.display }}</p>
        </div>
      </div>

      <!-- Beat one: read the two curves at the chosen time. -->
      <p
        v-if="isSurvival && survivalRead && survivalBeat === 'time'"
        class="journey__observation"
      >
        {{ survivalRead.reading }}
      </p>

      <!-- Beat two: what a downward movement is. R names the two readings over the year
           ending at the chosen time and the events that produced the fall, then states
           the mechanic — the line holds its level between events and steps down, so it
           never rises. -->
      <template v-if="isSurvival && survivalRead && survivalBeat === 'step'">
        <p class="journey__observation">{{ survivalRead.step.note }}</p>
      </template>

      <!-- Beat three: compare the two estimates at the same time. The two numbers are
           the read-outs above; R's sentence states the gap between them in percentage
           points, and nothing here tests it. -->
      <p
        v-if="isSurvival && survivalRead && survivalBeat === 'compare'"
        class="journey__observation"
      >
        {{ survivalRead.compare }}
      </p>

      <!-- What the curves estimate, what the censoring does to the reading, and what
           the curves do not say. Closed by default: the panel keeps the title, the
           qualifier and the sentence each beat adds. -->
      <details v-if="survivalDisclosure" class="details journey__variation">
        <summary>{{ survivalDisclosure.title }}</summary>
        <p v-for="(line, index) in survivalDisclosure.lines" :key="index">{{ line }}</p>
        <p v-if="survivalData?.note" class="journey__variation-list">{{ survivalData.note }}</p>
      </details>

      <!-- The budget chapter's own lever. Moving it selects a coverage step R has
           already returned, so no request is made and nothing earlier changes. It is
           the chapter's own interaction and is kept separate from the scenario: the
           price is not chosen here. -->
      <div
        v-if="budgetSliderVisible && budgetSliderControl"
        class="journey__price journey__price--chapter"
      >
        <p class="journey__price-label">{{ budgetSliderControl.label }}</p>
        <div class="journey__price-row">
          <input
            id="journey-budget-coverage"
            class="journey__price-slider"
            type="range"
            :min="budgetSliderControl.min"
            :max="budgetSliderControl.max"
            :step="budgetSliderControl.step"
            :value="budgetSliderValue"
            :aria-valuetext="`${budgetSliderValue}${budgetSliderControl.unit}`"
            @input="onBudgetSliderInput"
          />
          <output class="journey__price-value" for="journey-budget-coverage">
            {{ budgetSliderValue }}
          </output>
          <span class="journey__price-unit">{{ budgetSliderControl.unit }}</span>
        </div>
        <p class="journey__observation">{{ contract?.budget.copy.coverage_note }}</p>
      </div>

      <!-- On a narrow plane the sentence cannot sit beside the feature without
           covering the graph, so it sits directly under the chart, inside the same
           panel. The way forward is not printed here: it is in the panel's footer,
           where it is in every other state. -->
      <div v-if="stackedNote" class="journey__stacked">
        <div class="journey__stacked-body">
          <p class="journey__stacked-text" aria-live="polite">{{ stageNote }}</p>
          <p v-if="measureNote" class="journey__stacked-measure" aria-live="polite">
            {{ measureNote }}
          </p>
        </div>
      </div>

      <!-- The base case's QALY lesson. It sits in the panel below the chart, before
           the price can be moved, because the price changes only the cost side and the
           learner should know what the health side measures. The score is one of the
           model's assumptions: moving it re-runs the scenario, which is why the
           sentence above it changes with the answer. -->
      <div v-if="isQalyState && qaly" class="journey__qaly">
        <div class="journey__qaly-head">
          <p class="journey__qaly-caption" aria-live="polite">{{ stageNote }}</p>
        </div>

        <p class="journey__qaly-heading">{{ qaly.heading }}</p>

        <!-- The slider's label carries the one information button. Everything that
             explains the score — what the scale means, what the model does with it,
             the one-year arithmetic, the model's answer at the score on screen and the
             way back to the model's own assumption — is behind it, so the panel keeps
             the caption, the definition, the slider, its value and the two held
             values. -->
        <div class="journey__qaly-label-row">
          <label class="journey__qaly-label" for="journey-qaly-score">
            {{ qaly.control.label }}
          </label>
          <InfoTip :text="qaly.info" :title="qaly.info_title" :topic="qaly.control.label">
            <p class="journey__qaly-formula-label">{{ qaly.formula_label }}</p>
            <p class="journey__qaly-formula">{{ qalyFormula }}</p>
            <!-- R's answer at the score on screen, and R's note for the one score the
                 uncertainty analysis cannot draw exactly. Both belong with the
                 explanation of what the score does, because both are about it. -->
            <p v-if="qalyUtilityNote" class="journey__qaly-live">{{ qalyUtilityNote }}</p>
            <p v-if="qalyCeilingNote" class="journey__qaly-ceiling">{{ qalyCeilingNote }}</p>
            <button type="button" class="journey__qaly-reset" @click.stop="resetQalyScore()">
              {{ qaly.reset_label }}
            </button>
          </InfoTip>
        </div>

        <div class="journey__qaly-row">
          <input
            id="journey-qaly-score"
            class="journey__qaly-slider"
            type="range"
            :min="qaly.control.min"
            :max="qaly.control.max"
            :step="qaly.control.step"
            :value="qalyScoreValue"
            @input="onQalyInput"
            @change="onQalyChange"
          />
          <output class="journey__qaly-score" for="journey-qaly-score">
            {{ qalyScoreDisplay }}
          </output>
        </div>

        <!-- The two utilities the model holds fixed while this score moves. They stay
             visible beside the slider: a learner comparing quality-of-life scores
             needs them to read the interaction, so they are not behind a disclosure. -->
        <div class="journey__qaly-fixed">
          <p class="journey__qaly-fixed-title">{{ qaly.fixed_title }}</p>
          <ul class="journey__qaly-fixed-list">
            <li v-for="item in qaly.fixed" :key="item.label">
              <span>{{ item.label }}</span>
              <span class="journey__qaly-fixed-value">{{ item.display }}</span>
            </li>
          </ul>
        </div>
      </div>

      <!-- The price state's own control, in the same panel as the graph and below
           the chart so it is never dimmed or covered. This is the one place the
           journey's price is set; every later chapter uses it. The state's sentence
           sits here too, and the way on is in the panel's footer. -->
      <div v-if="isPriceState && control" ref="priceBlock" class="journey__price">
        <div class="journey__price-head">
          <p class="journey__price-note" aria-live="polite">{{ stageNote }}</p>
        </div>
        <p class="journey__price-label">{{ contract?.base_case.copy.price_label }}</p>
        <TutorialControl
          :control="control"
          :value="price ?? undefined"
          @update:value="(value) => typeof value === 'number' && setPrice(value)"
        />
        <p v-if="stage?.observation" class="journey__observation">
          {{ stage.observation }}
        </p>
      </div>

      <!-- The bridge into the second chapter. It sits over the panel the learner is
           already reading, with the graph still mounted and their price still
           chosen behind it, and it stays until they move on from it themselves. -->
      <div
        v-if="recapVisible && recap"
        class="recap"
        role="group"
        aria-labelledby="recap-heading"
      >
        <!-- The transition's box. It is the app's shared overlay: the ECG perimeter is its
             only outline, the interior is the shared surface, and the opening sequence is
             the same one every other overlay runs. Only the words are this chapter's. -->
        <EcgOverlay variant="centre">
          <h4 id="recap-heading" ref="recapHeading" class="recap__heading" tabindex="-1">
            <span v-for="(line, index) in recap.lines" :key="index">{{ line }} </span>
          </h4>
          <p class="recap__question">{{ recap.question }}</p>
          <template #actions>
            <!-- The bridge's own control is the one place a transition keeps its words
                 visible: it is a whole sentence that leaves the recap, not a small arrow
                 in the panel's footer, so it is styled on its own rather than borrowing
                 the arrow button's surface. -->
            <button type="button" class="recap__advance" @click.stop="leaveRecap()">
              <span>{{ recap.advance_label }}</span>
              <svg
                viewBox="0 0 16 16"
                width="14"
                height="14"
                aria-hidden="true"
                focusable="false"
              >
                <path
                  d="M3 8h9M8.5 4.5 12 8l-3.5 3.5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.8"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
            </button>
          </template>
        </EcgOverlay>
      </div>

      <!-- The way forward, in the same place in every chapter and every state: the
           panel's own footer. It is absent where nothing follows, so the journey's
           integration boundary carries no control at all. -->
      <JourneyNextButton
        v-if="hasNext && nextLabel && !recapVisible"
        ref="footerNext"
        :label="nextLabel"
        :busy="advanceHeld"
        @next="activate()"
      />

      <!-- The end of the whole journey: the overlay R wrote, after the last state of
           the last chapter the contract publishes. It is shown only when nothing
           follows this chapter, so adding a chapter later moves it automatically, and
           it is absent from a standalone explainer, which ends at its own lesson. -->
      <JourneyOverlay
        :open="endOpen"
        labelled-by="journey-end-title"
        @close="closeEnd()"
      >
        <template v-if="endCard">
          <h4 id="journey-end-title">{{ endCard.title }}</h4>
          <p>{{ endCard.body }}</p>
        </template>
        <template v-if="endCard" #actions>
          <button
            type="button"
            class="btn joverlay__primary"
            data-overlay-initial
            @click="openAnalysis()"
          >
            {{ endCard.open_label }}
          </button>
          <button type="button" class="btn joverlay__secondary" @click="restartJourney()">
            {{ endCard.restart_label }}
          </button>
        </template>
      </JourneyOverlay>
    </div>

    <p
      v-if="
        evaluateError || uncertaintyError || sensitivityError || voiError || priceError || budgetError || readinessError || survivalError
      "
      class="alert alert--danger"
    >
      {{
        evaluateError || uncertaintyError || sensitivityError || voiError || priceError || budgetError || readinessError || survivalError
      }}
    </p>

    <!-- A failed readiness request is answered by this control rather than by the way
         forward: the chapter's states read the assessment, so there is nothing to
         advance through until it arrives, and the arrow above is held until it does. -->
    <p v-if="isReadiness && readinessError" class="journey__retry">
      <button
        type="button"
        class="btn btn--ghost"
        :disabled="readinessBusy"
        @click="retryReadiness()"
      >
        Try the check again
      </button>
    </p>

    <!-- The same for the last chapter: its states read the simulated curves, so a failed
         request is answered by asking for them again rather than by an arrow that could
         not move the panel. -->
    <p v-if="isSurvival && survivalError" class="journey__retry">
      <button
        type="button"
        class="btn btn--ghost"
        :disabled="survivalBusy"
        @click="retrySurvival()"
      >
        Try the simulation again
      </button>
    </p>
  </section>
</template>
