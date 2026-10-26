<script setup lang="ts">
/**
 * The fourth chapter's figure: two panels over the same comparison.
 *
 * The upper panel draws the two quantities R returns for the choice â€” the balance of
 * choosing on today's information against usual care, and the balance if the model's
 * parameter uncertainty were resolved â€” as bars measured from the same zero. Usual
 * care's own net benefit is that zero, which is why an option that is not ahead on
 * average is drawn at exactly no length rather than given an invented height.
 *
 * The lower panel draws R's EVPPI rows: one bar per assumption, on its own axis,
 * because each is the value of resolving that assumption alone and the rows are not
 * shares of the upper figure.
 *
 * The gap between the two choice bars is annotated in a strip below them, using the
 * same value scale, so a gap too small to see still carries a readable amount and
 * the scale is never stretched to make it visible. Nothing is animated: the bars are
 * drawn at their final length, so no intermediate number can be read as a result.
 *
 * Every number, label and sentence is R's. This component turns values into pixel
 * positions and decides nothing else.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch, type ComponentPublicInstance } from 'vue'
import type { JourneyFocus, JourneyVoiGraph, JourneyVoiResult, JourneyVoiRow } from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro } from '../../format'
import JourneySpotlight from './JourneySpotlight.vue'

const props = defineProps<{
  /** R's labels for both panels. */
  graph: JourneyVoiGraph
  /** R's figures, or null before the answer arrives. */
  result: JourneyVoiResult | null
  /** How much of the figure this state draws. */
  reveal: 'now' | 'both' | 'gap' | 'evppi'
  /** Which region of the figure this state brings forward. */
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

const palette = useChartPalette()

/* --- Geometry -------------------------------------------------------------- */

/**
 * Both panels are drawn in fixed margins rather than a container-relative grid, so
 * the annotation strip can be placed in exactly the pixels ECharts is drawing in.
 * The right margin holds a value label beside the longest bar.
 */
const GRID_WIDE = { left: 150, right: 96, top: 26, bottom: 22 } as const
const GRID_NARROW = { left: 104, right: 78, top: 24, bottom: 20 } as const

/** The strip below the choice bars. It is always reserved, so the layout does not jump. */
const GAP_STRIP_HEIGHT = 52

interface Box {
  left: number
  top: number
  width: number
  height: number
}

const rootEl = ref<HTMLElement | null>(null)
const choiceEl = ref<HTMLElement | null>(null)
const evppiEl = ref<HTMLElement | null>(null)

const rootBox = ref<Box>({ left: 0, top: 0, width: 0, height: 0 })
const choiceBox = ref<Box>({ left: 0, top: 0, width: 0, height: 0 })
const evppiBox = ref<Box>({ left: 0, top: 0, width: 0, height: 0 })

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
  choiceBox.value = boxOf(choiceEl.value, root)
  evppiBox.value = boxOf(evppiEl.value, root)
}

let observer: ResizeObserver | null = null

onMounted(() => {
  measure()
  observer = new ResizeObserver(measure)
  if (rootEl.value) observer.observe(rootEl.value)
  if (choiceEl.value) observer.observe(choiceEl.value)
  if (evppiEl.value) observer.observe(evppiEl.value)
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
 * A state reveals another panel of the figure, and the browser reports the new size
 * only after the update has been laid out. Measuring again once the panel has settled
 * keeps the guidance's cut-out describing the boxes on screen rather than the previous
 * state's. `flush: 'post'` plus `nextTick` is the layout finishing, not a delay.
 */
watch(
  () => [props.reveal, props.focus, props.scope, props.dim, props.result],
  () => {
    void nextTick(measure)
  },
  { flush: 'post' },
)

const narrow = computed(() => rootBox.value.width > 0 && rootBox.value.width < 520)
const grid = computed(() => (narrow.value ? GRID_NARROW : GRID_WIDE))

/* --- The choice panel ------------------------------------------------------ */

interface ChoiceBar {
  key: 'now' | 'perfect'
  label: string
  value: number
  display: string
}

/**
 * The two bars. The first state draws only the choice made today; from the second
 * state on, the resolved choice is drawn beside it.
 */
const choiceBars = computed<ChoiceBar[]>(() => {
  const result = props.result
  if (!result) return []
  const bars: ChoiceBar[] = [
    {
      key: 'now',
      label: props.graph.now_label,
      // A bar is never given a length the figure does not have.
      value: Math.max(0, result.evpi.choose_now),
      display: result.evpi.choose_now_display,
    },
  ]
  if (props.reveal !== 'now') {
    bars.push({
      key: 'perfect',
      label: props.graph.perfect_label,
      value: Math.max(0, result.evpi.perfect),
      display: result.evpi.perfect_display,
    })
  }
  return bars
})

/** The axis R sized, so revealing a bar never rescales one already drawn. */
const choiceMax = computed(() => Math.max(props.result?.axis.max ?? 1, 1e-9))

const choicePlotWidth = computed(() =>
  Math.max(0, choiceBox.value.width - grid.value.left - grid.value.right),
)
const choicePlotHeight = computed(() =>
  Math.max(0, choiceBox.value.height - grid.value.top - grid.value.bottom),
)
const choiceBand = computed(
  () => choicePlotHeight.value / Math.max(1, choiceBars.value.length),
)

function choiceToX(value: number): number {
  const span = choiceMax.value
  return grid.value.left + (Math.max(0, Math.min(value, span)) / span) * choicePlotWidth.value
}

function choiceRowCentre(index: number): number {
  return grid.value.top + (index + 0.5) * choiceBand.value
}

/* --- The EVPPI panel ------------------------------------------------------- */

const evppiRows = computed<JourneyVoiRow[]>(() => {
  if (props.reveal !== 'evppi') return []
  const evppi = props.result?.evppi
  // R's own availability decides whether a ranking is drawn. When it is not
  // available, R's reason is the chapter's sentence and no bars are invented.
  if (!evppi || !evppi.available) return []
  return evppi.rows
})

const evppiMax = computed(() => Math.max(props.result?.axis.evppi_max ?? 1, 1e-9))

const evppiPlotWidth = computed(() =>
  Math.max(0, evppiBox.value.width - grid.value.left - grid.value.right),
)
const evppiPlotHeight = computed(() =>
  Math.max(0, evppiBox.value.height - grid.value.top - grid.value.bottom),
)
const evppiBand = computed(
  () => evppiPlotHeight.value / Math.max(1, evppiRows.value.length),
)

function evppiToX(value: number): number {
  return grid.value.left + (Math.max(0, Math.min(value, evppiMax.value)) / evppiMax.value) * evppiPlotWidth.value
}

function evppiRowCentre(index: number): number {
  return grid.value.top + (index + 0.5) * evppiBand.value
}

/** The panel's own height, from the rows R returned. */
const evppiHeight = computed(() => Math.max(170, evppiRows.value.length * 38 + 62))

/* --- The gap between the two choice bars ----------------------------------- */

interface GapMark {
  /** The bracket, in the strip's own pixels. */
  left: number
  width: number
  /** Whether the gap is too small to point along, so the bracket carries the amount. */
  tiny: boolean
  noteLeft: number
  noteWidth: number
  amount: string
  label: string
}

const LABEL_WIDTH = computed(() => (narrow.value ? 84 : 100))

const gap = computed<GapMark | null>(() => {
  const result = props.result
  if (!result || choiceBox.value.width <= 0) return null
  if (props.reveal === 'now' || props.reveal === 'both') return null
  const x1 = choiceToX(Math.max(0, result.evpi.choose_now))
  const x2 = choiceToX(Math.max(0, result.evpi.perfect))
  const left = Math.min(x1, x2)
  const width = Math.abs(x2 - x1)
  const noteWidth = LABEL_WIDTH.value
  // A narrow gap gets its amount to the right of the bracket, so the value stays
  // readable while the bracket keeps the true distance.
  const tiny = width < 26
  const noteLeft = tiny
    ? Math.min(Math.max(x1, x2) + 8, Math.max(2, choiceBox.value.width - noteWidth - 2))
    : Math.min(Math.max(2, (x1 + x2) / 2 - noteWidth / 2), Math.max(2, choiceBox.value.width - noteWidth - 2))
  return {
    left,
    width,
    tiny,
    noteLeft,
    noteWidth,
    amount: result.evpi.display,
    label: props.graph.gap_label,
  }
})

/** The bracket's own geometry, in the strip's coordinates. */
const bracket = computed(() => {
  const mark = gap.value
  if (!mark) return null
  const width = Math.max(1, mark.width)
  return {
    width,
    height: 14,
    arrow: !mark.tiny,
    head: 6,
  }
})

/* --- Value labels ---------------------------------------------------------- */

interface ValueLabel {
  key: string
  text: string
  left: number
  top: number
  width: number
  /** A bar of exactly no length is marked at the axis, so the row is visibly present. */
  tick: boolean
  tickLeft: number
  tickTop: number
}

function labelsFor(
  bars: { key: string; value: number; display: string }[],
  series: Box,
  toX: (value: number) => number,
  rowCentre: (index: number) => number,
): ValueLabel[] {
  if (series.width <= 0) return []
  const width = LABEL_WIDTH.value
  return bars.map((bar, index) => {
    const x = toX(bar.value)
    return {
      key: bar.key,
      text: bar.display,
      left: Math.min(x + 6, Math.max(2, series.width - width - 2)),
      top: Math.max(2, rowCentre(index) - 9),
      width,
      tick: bar.value <= 0,
      tickLeft: x - 1.5,
      tickTop: rowCentre(index) - 8,
    }
  })
}

const choiceLabels = computed<ValueLabel[]>(() =>
  labelsFor(choiceBars.value, choiceBox.value, choiceToX, choiceRowCentre),
)

const evppiLabels = computed<ValueLabel[]>(() =>
  labelsFor(
    evppiRows.value.map((row) => ({
      key: row.parameter_id,
      value: row.value,
      display: row.value_display,
    })),
    evppiBox.value,
    evppiToX,
    evppiRowCentre,
  ),
)

/* --- The guidance cut-out -------------------------------------------------- */

/**
 * The region the state brings forward.
 *
 * Each cut-out is chosen so that it holds the focused feature together with the
 * labels that belong to it, and so that its edges fall between text blocks rather
 * than through them: the accent that marks the cut-out is painted inside it, so a
 * cut-out that keeps whole blocks together is what keeps every label, tick, axis
 * title and amount sharp. The row states therefore take the panel's full width â€”
 * the category label column is as much part of the bar as the bar itself â€” and
 * stop short, vertically, of the neighbouring row's label and of the value axis's
 * own ticks.
 */
const hole = computed<Box | null>(() => {
  const { width, height } = rootBox.value
  if (!props.dim || width <= 4 || height <= 4) return null
  const g = grid.value

  if (props.focus === 'choice_now' || props.focus === 'choice_resolved') {
    if (choiceBars.value.length === 0) return null
    const index = props.focus === 'choice_now' ? 0 : 1
    if (index >= choiceBars.value.length) return null
    const centre = choiceBox.value.top + choiceRowCentre(index)
    const plotBottom = choiceBox.value.top + choiceBox.value.height - g.bottom
    // Wide enough for the bar, never so tall that the edge lands on a label: the
    // rows' labels are about nine pixels either side of a row's centre.
    const pad = Math.min(
      Math.max(20, choiceBand.value * 0.42),
      Math.max(10, choiceBand.value - 12),
    )
    const top = Math.max(2, centre - pad)
    return {
      left: 0,
      top,
      width: Math.max(24, width),
      height: Math.max(16, Math.min(plotBottom, centre + pad) - top),
    }
  }

  if (props.focus === 'evpi_gap') {
    if (!gap.value) return null
    // The band from the top of the bars to just below the annotation strip. It
    // reads across the full panel, because the gap's bracket sits beneath the same
    // axis and tick labels the bars above it are measured on, and it ends below the
    // strip's own amount so no edge falls on that text.
    const top = Math.max(2, choiceBox.value.top + g.top)
    const bottom = choiceBox.value.top + choiceBox.value.height + GAP_STRIP_HEIGHT + 4
    return {
      left: 0,
      top,
      width: Math.max(24, width),
      height: Math.max(24, bottom - top),
    }
  }

  if (props.focus === 'evppi_bars') {
    if (evppiBox.value.width <= 0) return null
    return {
      left: 0,
      top: Math.max(2, evppiBox.value.top - 6),
      width: Math.max(24, width),
      height: Math.min(height - 2, evppiBox.value.height + 12),
    }
  }

  return null
})

/* --- The charts ------------------------------------------------------------ */

/** One value as an axis tick reads it: whole euros, R's own unit. */
function tick(value: number): string {
  return formatEuro(value, 0)
}

function axisOption(max: number): Record<string, unknown> {
  const base = chartBase(palette.value)
  const g = grid.value
  return {
    ...base,
    animation: false,
    tooltip: { show: false },
    grid: { left: g.left, right: g.right, top: g.top, bottom: g.bottom, containLabel: false },
    xAxis: {
      type: 'value',
      min: 0,
      max,
      ...base.axisStyle,
      axisLabel: { color: palette.value.muted, formatter: (value: number) => tick(value) },
    },
  }
}

const choiceOption = computed<EChartsCoreOption>(() => {
  const base = axisOption(choiceMax.value)
  const g = grid.value
  const paletteValue = palette.value
  return {
    ...base,
    yAxis: {
      type: 'category',
      inverse: true,
      data: choiceBars.value.map((bar) => bar.label),
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: {
        color: paletteValue.text,
        width: g.left - 12,
        overflow: 'break',
        interval: 0,
        fontSize: narrow.value ? 10 : 11,
      },
      splitLine: { show: false },
    },
    series: [
      {
        type: 'bar',
        barMaxWidth: 20,
        data: choiceBars.value.map((bar) => bar.value),
        itemStyle: { color: paletteValue.accent, borderRadius: [0, 3, 3, 0] },
        label: { show: false },
      },
    ],
  }
})

const evppiOption = computed<EChartsCoreOption>(() => {
  const base = axisOption(evppiMax.value)
  const g = grid.value
  const paletteValue = palette.value
  return {
    ...base,
    yAxis: {
      type: 'category',
      inverse: true,
      data: evppiRows.value.map((row) => row.plot_label),
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: {
        color: paletteValue.text,
        width: g.left - 12,
        overflow: 'break',
        interval: 0,
        fontSize: narrow.value ? 10 : 11,
      },
      splitLine: { show: false },
    },
    series: [
      {
        type: 'bar',
        barMaxWidth: 18,
        data: evppiRows.value.map((row) => row.value),
        itemStyle: { color: paletteValue.accent, borderRadius: [0, 3, 3, 0] },
        label: { show: false },
      },
    ],
  }
})

const choiceChart = useEcharts(() => choiceOption.value)
const evppiChart = useEcharts(() => evppiOption.value)

function setChoiceCanvas(element: Element | ComponentPublicInstance | null): void {
  choiceEl.value = element instanceof HTMLElement ? element : null
  choiceChart.setCanvas(element)
}

function setEvppiCanvas(element: Element | ComponentPublicInstance | null): void {
  evppiEl.value = element instanceof HTMLElement ? element : null
  evppiChart.setCanvas(element)
}
</script>

<template>
  <div ref="rootEl" class="chart journey__voi">
    <!-- The two choice bars. Their amounts sit beside their own ends, so the bar
         length and the number can always be read together. -->
    <div class="voi__panel">
      <p class="voi__axis-note">{{ graph.axis_label }}</p>
      <div class="voi__plot">
        <div :ref="setChoiceCanvas" class="chart__canvas voi__canvas voi__canvas--choice"></div>

        <span
          v-for="label in choiceLabels"
          :key="label.key"
          class="voi__value"
          :style="{ left: `${label.left}px`, top: `${label.top}px`, width: `${label.width}px` }"
          >{{ label.text }}</span
        >
        <span
          v-for="label in choiceLabels.filter((row) => row.tick)"
          :key="`tick-${label.key}`"
          class="voi__zero"
          :style="{ left: `${label.tickLeft}px`, top: `${label.tickTop}px` }"
          aria-hidden="true"
        ></span>
      </div>

      <!-- The gap, measured on the same scale as the bars above it. A gap too small
           to point along is drawn as a bracket with the amount beside it, so the
           value stays readable without the scale being stretched. -->
      <div class="voi__gap-strip">
        <template v-if="gap && bracket">
          <svg
            class="voi__gap-line"
            :style="{ left: `${gap.left}px`, width: `${bracket.width}px` }"
            :viewBox="`0 0 ${bracket.width} ${bracket.height}`"
            :height="bracket.height"
            aria-hidden="true"
            focusable="false"
          >
            <line :x1="0" :y1="bracket.height / 2" :x2="bracket.width" :y2="bracket.height / 2" />
            <line x1="0" y1="1" x2="0" :y2="bracket.height - 1" />
            <line :x1="bracket.width" y1="1" :x2="bracket.width" :y2="bracket.height - 1" />
            <path
              v-if="bracket.arrow"
              :d="`M${bracket.width - bracket.head} 1 L${bracket.width} ${bracket.height / 2} L${bracket.width - bracket.head} ${bracket.height - 1}`"
            />
          </svg>
          <span
            class="voi__gap-note"
            :style="{ left: `${gap.noteLeft}px`, width: `${gap.noteWidth}px` }"
          >
            <span class="voi__gap-eyebrow">{{ gap.label }}</span>
            <span class="voi__gap-value">{{ gap.amount }}</span>
          </span>
        </template>
      </div>
    </div>

    <!-- R's ranking of the value of resolving one assumption at a time. It has its
         own axis: these rows are not shares of the figure above. -->
    <div v-if="evppiRows.length > 0" class="voi__panel">
      <p class="voi__panel-title">{{ graph.evppi_title }}</p>
      <p class="voi__axis-note">{{ graph.evppi_axis_label }}</p>
      <div class="voi__plot">
        <div
          :ref="setEvppiCanvas"
          class="chart__canvas voi__canvas voi__canvas--evppi"
          :style="{ height: `${evppiHeight}px` }"
        ></div>
        <span
          v-for="label in evppiLabels"
          :key="label.key"
          class="voi__value"
          :style="{ left: `${label.left}px`, top: `${label.top}px`, width: `${label.width}px` }"
          >{{ label.text }}</span
        >
        <span
          v-for="label in evppiLabels.filter((row) => row.tick)"
          :key="`tick-${label.key}`"
          class="voi__zero"
          :style="{ left: `${label.tickLeft}px`, top: `${label.tickTop}px` }"
          aria-hidden="true"
        ></span>
      </div>
    </div>

    <!-- The same cut-out the other chapters use. It carries no sentence of its own:
         the caption and the way forward sit in the panel under the chart. -->
    <JourneySpotlight
      v-if="dim && hole"
      :area="{ width: rootBox.width, height: rootBox.height }"
      :hole="hole"
      :scope="scope"
      :text="''"

    />
  </div>
</template>
