<script setup lang="ts">
/**
 * The fifth chapter's figure: one price comparison, drawn as two scales.
 *
 * The upper panel is an annual price track â€” the manufacturer's proposal, the price
 * the learner has chosen, and the price R solves for, all on one â‚¬-per-person-per-year
 * axis with whole-hundred ticks. The lower panel is a net-benefit display with its own
 * zero, which is usual care, so it carries negative and positive balances: a price
 * above what the case's reference supports shows a bar to the left of zero.
 *
 * The two are deliberately never put on one axis. A net benefit is not a price, and a
 * bar measured in euros per person per year would be a different quantity from a bar
 * measured in euros per person over the model's horizon; drawing them from a shared
 * zero would invite exactly that misreading.
 *
 * Nothing is invented. A price R could not identify, or one that falls outside the
 * track's range, draws no marker: the reason sits in the sentence under the figure.
 * Every amount, label and sentence is R's â€” this component turns three numbers into
 * pixel positions and decides nothing else.
 */

import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { JourneyFocus, JourneyPriceGraph, JourneyPriceResponse } from '../../api/types'
import { formatEuro } from '../../format'
import JourneySpotlight from './JourneySpotlight.vue'

const props = defineProps<{
  /** R's labels for both displays. */
  graph: JourneyPriceGraph
  /** R's answer, or null before it arrives. */
  result: JourneyPriceResponse | null
  /** How much of the figure this state draws. */
  reveal: 'track' | 'balance' | 'full'
  /** Which part of the figure this state brings forward. */
  focus: JourneyFocus
  /** Whether the guidance softens everything outside the focused region. */
  dim: boolean
  /**
   * Which chapter's picture these coordinates describe. The overlay places a cut-out
   * from a different chapter immediately instead of sliding to it, because two
   * chapters are two different charts.
   */
  scope?: string | null
}>()

/* --- Geometry -------------------------------------------------------------- */

interface Box {
  left: number
  top: number
  width: number
  height: number
}

/** The track's own rows, in pixels from its top, so the cut-outs can stop between them. */
const PROPOSAL_ROW = 0
const SOLVED_ROW = 22
const RAIL_Y = 52
const TICK_ROW = 56
const LEARNER_ROW = 74
const TRACK_HEIGHT = 96

/** The balance display's rows. The bar occupies the top, its ticks the floor. */
const BALANCE_HEIGHT = 86
const BALANCE_TICK_ROW = 66

/** A marker's reading width, and the clearance a cut-out leaves around it. */
const LABEL_WIDTH = 132
const CLEARANCE = 8

const rootEl = ref<HTMLElement | null>(null)
const trackEl = ref<HTMLElement | null>(null)
const balanceEl = ref<HTMLElement | null>(null)

const rootBox = ref<Box>({ left: 0, top: 0, width: 0, height: 0 })
const trackBox = ref<Box>({ left: 0, top: 0, width: 0, height: 0 })
const balanceBox = ref<Box>({ left: 0, top: 0, width: 0, height: 0 })

function boxOf(element: HTMLElement | null, root: HTMLElement | null): Box {
  if (!element || !root) return { left: 0, top: 0, width: 0, height: 0 }
  const own = element.getBoundingClientRect()
  const base = root.getBoundingClientRect()
  return {
    left: own.left - base.left,
    top: own.top - base.top,
    width: own.width,
    height: own.height,
  }
}

function measure(): void {
  const root = rootEl.value
  if (!root) return
  rootBox.value = { left: 0, top: 0, width: root.clientWidth, height: root.clientHeight }
  trackBox.value = boxOf(trackEl.value, root)
  balanceBox.value = boxOf(balanceEl.value, root)
}

let observer: ResizeObserver | null = null

onMounted(() => {
  measure()
  observer = new ResizeObserver(measure)
  if (rootEl.value) observer.observe(rootEl.value)
  window.addEventListener('resize', measure, { passive: true })
  window.addEventListener('orientationchange', measure, { passive: true })
})

onBeforeUnmount(() => {
  observer?.disconnect()
  observer = null
  window.removeEventListener('resize', measure)
  window.removeEventListener('orientationchange', measure)
})

/**
 * A state can change how tall the figure is — the balance panel appears, its amount
 * label is a different length — and the browser reports the new size only after it has
 * laid the update out. Measuring again once the panel has settled keeps the guidance's
 * cut-out describing the boxes that are actually on screen. `flush: 'post'` plus
 * `nextTick` is the layout being finished, not a delay.
 */
watch(
  () => [props.reveal, props.focus, props.scope, props.dim, props.result],
  () => {
    void nextTick(measure)
  },
  { flush: 'post' },
)

/* --- The price track ------------------------------------------------------- */

/** The lever's own bounds, from R. They are also the axis's ends. */
const range = computed(() => props.result?.price.range ?? { min: 40, max: 440 })

const trackWidth = computed(() => Math.max(0, trackBox.value.width))

/** The rail's usable width, inset so a marker at either end is still whole. */
const railInset = computed(() => Math.max(10, Math.min(28, trackWidth.value * 0.04)))

const railLeft = computed(() => railInset.value)
const railWidth = computed(() => Math.max(1, trackWidth.value - railInset.value * 2))

function trackX(value: number): number {
  const { min, max } = range.value
  const span = Math.max(max - min, 1e-9)
  const clamped = Math.max(min, Math.min(value, max))
  return railLeft.value + ((clamped - min) / span) * railWidth.value
}

/** A label centred on its marker, kept whole inside the panel. */
function labelLeft(x: number): number {
  const width = Math.min(LABEL_WIDTH, Math.max(60, trackWidth.value - 4))
  return Math.max(2, Math.min(x - width / 2, trackWidth.value - width - 2))
}

const labelBoxWidth = computed(() =>
  Math.min(LABEL_WIDTH, Math.max(60, trackWidth.value - 4)),
)

const proposal = computed(() => {
  const result = props.result
  if (!result) return null
  return { x: trackX(result.price.proposal.value), display: result.price.proposal.display }
})

const learner = computed(() => {
  const result = props.result
  if (!result) return null
  return { x: trackX(result.price.price), display: result.price.price_display }
})

/**
 * R's solved price, drawn only when it exists and lies inside the track's range. A
 * price outside the range would have to be clamped to be drawn, and a clamped marker
 * would place the crossing at a price the model did not solve for.
 */
const solved = computed(() => {
  const solvedPrice = props.result?.price.solved
  if (!solvedPrice || props.reveal !== 'full') return null
  if (!solvedPrice.available || !solvedPrice.within_range || solvedPrice.price === null) {
    return null
  }
  return { x: trackX(solvedPrice.price), display: solvedPrice.display }
})

const ticks = computed(() => {
  const result = props.result
  if (!result) return []
  return result.price.ticks.map((tick) => ({ ...tick, x: trackX(tick.value) }))
})

/* --- The balance display --------------------------------------------------- */

/**
 * The balance's own axis, from R: it always contains usual care's zero, and it is
 * padded so a balance of exactly zero is still a mark rather than the panel's edge.
 */
const balanceAxis = computed(() => props.result?.price.balance.axis ?? { min: -1, max: 1 })

const balanceWidth = computed(() => Math.max(0, balanceBox.value.width))

/** The bar's usable width, inset so a value label at either end stays whole. */
const balanceInset = computed(() => Math.max(12, Math.min(60, balanceWidth.value * 0.12)))

function balanceX(value: number): number {
  const { min, max } = balanceAxis.value
  const span = Math.max(max - min, 1e-9)
  const clamped = Math.max(min, Math.min(value, max))
  return balanceInset.value + ((clamped - min) / span) * Math.max(1, balanceWidth.value - balanceInset.value * 2)
}

const zeroX = computed(() => balanceX(0))

const balanceBar = computed(() => {
  const result = props.result
  if (!result || props.reveal === 'track') return null
  const start = zeroX.value
  const end = balanceX(result.price.balance.nmb)
  return {
    left: Math.min(start, end),
    width: Math.max(2, Math.abs(end - start)),
    positive: result.price.balance.positive,
    display: result.price.balance.display,
  }
})

/**
 * The balance's own amount, at the end of its own bar. It is R's formatted string,
 * placed beside the bar's far end so the number and the length are read together.
 */
const balanceLabel = computed(() => {
  const result = props.result
  if (!result || props.reveal === 'track') return null
  const end = balanceX(result.price.balance.nmb)
  const width = Math.min(108, Math.max(64, balanceWidth.value * 0.3))
  const beyond = end + 8
  const left = beyond + width <= balanceWidth.value - 2
    ? beyond
    : Math.max(2, end - width - 8)
  return { left, width, display: result.price.balance.display }
})

/** The balance panel is drawn from the second state onward; the track never leaves. */
const showBalancePanel = computed(() => props.reveal !== 'track')

const balanceTicks = computed(() => {
  if (!props.result || props.reveal === 'track') return []
  const { min, max } = balanceAxis.value
  return [
    { key: 'min', x: balanceX(min), display: formatEuro(min, 0) },
    { key: 'max', x: balanceX(max), display: formatEuro(max, 0) },
  ]
})

/* --- The guidance cut-out -------------------------------------------------- */

/**
 * The cut-outs, chosen so that the accent that marks them - painted inside them -
 * never crosses a label. Each one encloses the whole feature with its own amount and
 * stops between the track's label rows, so an edge can fall beside a label but never
 * through one.
 */
const hole = computed<Box | null>(() => {
  const { width, height } = rootBox.value
  if (!props.dim || width <= 4 || height <= 4) return null
  if (trackBox.value.width <= 0) return null

  const bandAround = (x: number, top: number, bottom: number): Box => {
    const left = Math.max(0, x - labelBoxWidth.value / 2 - CLEARANCE)
    const right = Math.min(width, x + labelBoxWidth.value / 2 + CLEARANCE)
    return {
      left,
      top: Math.max(0, top),
      width: Math.max(24, right - left),
      height: Math.max(16, bottom - Math.max(0, top)),
    }
  }

  if (props.focus === 'price_proposal') {
    if (!proposal.value) return null
    return bandAround(
      proposal.value.x,
      trackBox.value.top + PROPOSAL_ROW,
      trackBox.value.top + RAIL_Y + 10,
    )
  }

  if (props.focus === 'price_learner') {
    if (!learner.value) return null
    return bandAround(
      learner.value.x,
      trackBox.value.top + LEARNER_ROW,
      trackBox.value.top + RAIL_Y + 10,
    )
  }

  if (props.focus === 'price_solved') {
    const mark = solved.value
    if (!mark) return null
    return bandAround(
      mark.x,
      trackBox.value.top + SOLVED_ROW,
      trackBox.value.top + RAIL_Y + 10,
    )
  }

  if (props.focus === 'balance_bar') {
    if (!showBalancePanel.value || balanceBox.value.width <= 0) return null
    // The whole display above its own tick row: the bar, its amount and the zero line
    // the bar is measured from, with the axis's numbers left out.
    const top = balanceBox.value.top
    return {
      left: 0,
      top: Math.max(0, top),
      width,
      height: Math.max(16, top + BALANCE_TICK_ROW - 6 - top),
    }
  }

  return null
})
</script>

<template>
  <div ref="rootEl" class="chart journey__pricefig">
    <!-- The price track. One axis, in the lever's own annual unit, carrying the three
         prices this chapter is about. -->
    <div class="pricefig__panel">
      <p class="pricefig__axis-note">{{ graph.track_label }}</p>
      <div ref="trackEl" class="pricefig__track" :style="{ height: `${TRACK_HEIGHT}px` }">
        <span
          class="pricefig__rail"
          aria-hidden="true"
          :style="{
            left: `${railLeft}px`,
            width: `${railWidth}px`,
            top: `${RAIL_Y}px`,
          }"
        ></span>

        <template v-if="proposal">
          <span
            class="pricefig__stem pricefig__stem--proposal"
            aria-hidden="true"
            :style="{ left: `${proposal.x}px`, top: `${RAIL_Y - 8}px` }"
          ></span>
          <span
            class="pricefig__marker pricefig__marker--proposal"
            aria-hidden="true"
            :style="{ left: `${proposal.x}px`, top: `${RAIL_Y}px` }"
          ></span>
          <span
            class="pricefig__tag pricefig__tag--proposal"
            :style="{
              left: `${labelLeft(proposal.x)}px`,
              width: `${labelBoxWidth}px`,
              top: `${PROPOSAL_ROW}px`,
            }"
          >
            <span class="pricefig__tag-label">{{ graph.proposal_label }}</span>
            <span class="pricefig__tag-value">{{ proposal.display }}</span>
          </span>
        </template>

        <template v-if="solved">
          <span
            class="pricefig__stem pricefig__stem--solved"
            aria-hidden="true"
            :style="{ left: `${solved.x}px`, top: `${RAIL_Y - 10}px` }"
          ></span>
          <span
            class="pricefig__tag pricefig__tag--solved"
            :style="{
              left: `${labelLeft(solved.x)}px`,
              width: `${labelBoxWidth}px`,
              top: `${SOLVED_ROW}px`,
            }"
          >
            <span class="pricefig__tag-label">{{ graph.solved_label }}</span>
            <span class="pricefig__tag-value">{{ solved.display }}</span>
          </span>
        </template>

        <span
          v-for="tick in ticks"
          :key="`tick-${tick.value}`"
          class="pricefig__tick"
          :style="{ left: `${tick.x}px`, top: `${TICK_ROW}px` }"
          >{{ tick.display }}</span
        >

        <template v-if="learner">
          <span
            class="pricefig__marker pricefig__marker--learner"
            aria-hidden="true"
            :style="{ left: `${learner.x}px`, top: `${RAIL_Y}px` }"
          ></span>
          <span
            class="pricefig__tag pricefig__tag--learner"
            :style="{
              left: `${labelLeft(learner.x)}px`,
              width: `${labelBoxWidth}px`,
              top: `${LEARNER_ROW}px`,
            }"
          >
            <span class="pricefig__tag-label">{{ graph.learner_label }}</span>
            <span class="pricefig__tag-value">{{ learner.display }}</span>
          </span>
        </template>
      </div>
    </div>

    <!-- The balance, on its own axis with usual care's zero. Negative and positive
         are both drawn: the bar starts at zero and runs to R's figure. -->
    <div v-if="showBalancePanel" class="pricefig__panel">
      <p class="pricefig__panel-title">{{ graph.balance_title }}</p>
      <p class="pricefig__axis-note">{{ graph.balance_label }}</p>
      <div
        ref="balanceEl"
        class="pricefig__balance"
        :style="{ height: `${BALANCE_HEIGHT}px` }"
      >
        <span
          class="pricefig__zero-line"
          aria-hidden="true"
          :style="{ left: `${zeroX}px`, height: `${BALANCE_TICK_ROW - 18}px` }"
        ></span>
        <span
          v-if="balanceBar"
          class="pricefig__bar"
          :class="{ 'pricefig__bar--below': !balanceBar.positive }"
          :style="{
            left: `${balanceBar.left}px`,
            width: `${balanceBar.width}px`,
          }"
          aria-hidden="true"
        ></span>
        <span
          v-if="balanceLabel"
          class="pricefig__value"
          :style="{ left: `${balanceLabel.left}px`, width: `${balanceLabel.width}px` }"
          >{{ balanceLabel.display }}</span
        >
        <span v-if="balanceBar" class="pricefig__zero-label" :style="{ left: `${zeroX}px` }">
          {{ graph.zero_label }}
        </span>
        <span
          v-for="tick in balanceTicks"
          :key="tick.key"
          class="pricefig__tick pricefig__tick--balance"
          :style="{ left: `${tick.x}px` }"
          >{{ tick.display }}</span
        >
      </div>
    </div>

    <!-- The same cut-out the other chapters use. It carries no sentence of its own:
         the caption and the way forward sit in the panel under the figure. -->
    <JourneySpotlight
      v-if="dim && hole"
      :area="{ width: rootBox.width, height: rootBox.height }"
      :hole="hole"
      :scope="scope"
      :text="''"

    />
  </div>
</template>
