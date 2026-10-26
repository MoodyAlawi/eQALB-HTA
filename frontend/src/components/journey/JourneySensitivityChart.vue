<script setup lang="ts">
/**
 * The third chapter's ranked chart: one row per assumption, drawn between the two
 * results R returned for it.
 *
 * R ranks the rows and hands over, for each one, the tested input at both ends and
 * the outcome those inputs produced. This component turns those numbers into pixel
 * positions and nothing else: it never re-sorts, never compares a value with a
 * threshold and never derives a sentence. The dashed line is R's base case, which
 * every bar is measured from.
 *
 * The same component draws both views, cost and health, because the only difference
 * between them is which of R's two rankings is handed in. Moving from one to the
 * other therefore replaces the data rather than the chart, and the learner sees the
 * same frame re-ranked rather than a new screen.
 *
 * Two things are drawn outside ECharts, in HTML: the two end annotations of the
 * first bar, so their text wraps and scales like the rest of the page instead of
 * being baked into the canvas, and the guidance cut-out, which is the same
 * `JourneySpotlight` the earlier chapters use. There is no tooltip: the chart is
 * read from its labels and from R's sentence, and a hover box would show numbers
 * for bars that are still moving during the cost-to-health redraw.
 */

import { CustomChart } from 'echarts/charts'
import { use as registerChartTypes } from 'echarts/core'
import type { EChartsCoreOption } from 'echarts/core'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type {
  JourneyFocus,
  JourneySensitivityGraph,
  JourneySensitivityOutcome,
} from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro, formatQaly } from '../../format'
import JourneySpotlight from './JourneySpotlight.vue'

// A span bar is a custom series, which only the ranked charts draw. Registration is
// global and idempotent, so doing it here cannot affect any other chart.
registerChartTypes([CustomChart])

const props = defineProps<{
  /** R's labels for the frame: both axis names, the reference and the two ends. */
  graph: JourneySensitivityGraph
  /** R's ranking for the view on screen, or null before it arrives. */
  outcome: JourneySensitivityOutcome | null
  /** Which of R's rankings is drawn. */
  view: 'cost' | 'health'
  /** Which region of the chart this state brings forward. */
  focus: JourneyFocus
  /** One bar, or the whole ranked chart. */
  reveal: 'top' | 'all'
  /** Whether the single bar's two ends are annotated. */
  ends: boolean
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

/** ECharts animates in JavaScript, so the media query has to be read here. */
const reducedMotion =
  typeof window !== 'undefined' &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches

/* --- Geometry -------------------------------------------------------------- */

/**
 * The plot's margins. The label column has to be a fixed width for the guidance
 * cut-out and the end annotations to be placed in exactly the pixels ECharts is
 * drawing in, so the chart is given these margins rather than a container-relative
 * grid.
 */
const GRID_WIDE = { left: 150, right: 26, top: 46, bottom: 54 } as const
const GRID_NARROW = { left: 104, right: 14, top: 38, bottom: 54 } as const

const chartEl = ref<HTMLElement | null>(null)
const area = ref({ width: 0, height: 0 })
let observer: ResizeObserver | null = null

function measure(): void {
  const element = chartEl.value
  if (!element) return
  const canvas = element.querySelector<HTMLElement>('.chart__canvas')
  const width = element.clientWidth
  const height = canvas?.clientHeight ?? 0
  if (width === area.value.width && height === area.value.height) return
  area.value = { width, height }
}

onMounted(() => {
  measure()
  observer = new ResizeObserver(measure)
  if (chartEl.value) observer.observe(chartEl.value)
  const canvas = chartEl.value?.querySelector<HTMLElement>('.chart__canvas')
  if (canvas) observer.observe(canvas)
  // The viewport is watched as well as the elements: the canvas height comes from a
  // media query, which can change without either element reporting a new size.
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
 * A state can change the height above the chart — a caption that wraps to another line,
 * a measure note the previous state did not have — and the browser reports the new size
 * only after it has laid the update out. Measuring again once the DOM is settled keeps
 * the guidance's cut-out describing the boxes that are actually on screen, rather than
 * the ones the previous state was laid out with.
 *
 * `flush: 'post'` runs after this component's own update, and `nextTick` runs after the
 * whole panel has finished, which is the point at which the sizes are final. There is no
 * delay: nothing waits, and no timer decides when the position is right.
 */
watch(
  () => [props.view, props.reveal, props.ends, props.scope, props.dim],
  () => {
    void nextTick(measure)
  },
  { flush: 'post' },
)

const narrow = computed(() => area.value.width > 0 && area.value.width < 520)
const grid = computed(() => (narrow.value ? GRID_NARROW : GRID_WIDE))

/** The rows this state draws: the first bar alone, or every ranked assumption. */
const rows = computed(() => {
  const outcome = props.outcome
  if (!outcome) return []
  return props.reveal === 'top' ? outcome.rows.slice(0, 1) : outcome.rows
})

const plotHeight = computed(
  () => Math.max(0, area.value.height - grid.value.top - grid.value.bottom),
)
const plotWidth = computed(
  () => Math.max(0, area.value.width - grid.value.left - grid.value.right),
)
const band = computed(() => (rows.value.length > 0 ? plotHeight.value / rows.value.length : 0))

/** The value axis, padded so no bar touches the frame. */
const domain = computed(() => {
  const values = [props.outcome?.base_outcome ?? 0]
  for (const row of rows.value) values.push(row.low_outcome, row.high_outcome)
  const min = Math.min(...values)
  const max = Math.max(...values)
  const pad = (max > min ? max - min : Math.abs(max) || 1) * 0.14
  return { min: min - pad, max: max + pad }
})

/** A value's pixel column, using the same frame the chart is drawn in. */
function toX(value: number): number {
  const { min, max } = domain.value
  const span = max - min
  if (!(span > 0)) return grid.value.left
  return grid.value.left + ((value - min) / span) * plotWidth.value
}

/** A row's pixel row centre, in R's order, the first row at the top. */
function rowCentre(index: number): number {
  return grid.value.top + (index + 0.5) * band.value
}

/* --- The two end annotations ---------------------------------------------- */

interface EndLabel {
  key: 'low' | 'high'
  eyebrow: string
  input: string
  value: string
  left: number
  top: number
  width: number
}

const END_WIDTH_WIDE = 132
const END_WIDTH_NARROW = 104

/**
 * The two ends of the first bar, each with the tested input that produced it.
 *
 * They are placed above and below the bar respectively, so the pair can never
 * overlap however close the two results are, and each is centred on the value it
 * describes. When an assumption runs the other way its labels cross: the lowest
 * tested input is annotated wherever its result actually sits.
 */
const endLabels = computed<EndLabel[]>(() => {
  if (!props.ends || !props.outcome) return []
  const row = rows.value[0]
  const { width, height } = area.value
  if (!row || width <= 0 || height <= 0) return []

  const labelWidth = narrow.value ? END_WIDTH_NARROW : END_WIDTH_WIDE
  const centre = rowCentre(0)
  const halfBar = Math.min(9, Math.max(5, band.value * 0.31))
  const clampLeft = (value: number) =>
    Math.max(2, Math.min(value - labelWidth / 2, width - labelWidth - 2))
  const above = Math.max(2, centre - halfBar - 8 - 52)
  const below = Math.min(height - 54, centre + halfBar + 8)

  return [
    {
      key: 'low',
      eyebrow: props.graph.low_end_label,
      input: row.low_input,
      value: row.low_display,
      left: clampLeft(toX(row.low_outcome)),
      top: above,
      width: labelWidth,
    },
    {
      key: 'high',
      eyebrow: props.graph.high_end_label,
      input: row.high_input,
      value: row.high_display,
      left: clampLeft(toX(row.high_outcome)),
      top: Math.max(below, above + 60),
      width: labelWidth,
    },
  ]
})

/* --- The guidance cut-out -------------------------------------------------- */

interface Box {
  left: number
  top: number
  width: number
  height: number
}

/**
 * The region the state brings forward.
 *
 * The cut-outs read across the panel's full width and are measured in whole rows.
 * A parameter's label is as much part of its bar as the bar itself, so the label
 * column is inside the sharp region rather than bisected by its boundary, and an
 * edge that falls on a row boundary never lands inside another row's label. One bar
 * takes the band it is drawn in; its two labelled ends take that band, and the
 * annotations the ends carry fit inside it because the state draws the single bar
 * over the full plot height.
 */
const hole = computed<Box | null>(() => {
  const { width, height } = area.value
  if (!props.dim || width <= 4 || height <= 4) return null
  const g = grid.value
  const fullWidth = Math.max(24, width)

  if (props.focus === 'flat') {
    const first = rows.value.findIndex((row) => row.flat)
    if (first < 0) return null
    const count = rows.value.filter((row) => row.flat).length
    return {
      left: 0,
      top: Math.max(2, g.top + first * band.value),
      width: fullWidth,
      height: count * band.value,
    }
  }

  if (props.focus === 'bar_top' || props.focus === 'bar_ends') {
    if (rows.value.length === 0) return null
    const centre = rowCentre(0)
    // Never taller than the band it belongs to, so the edge cannot reach a
    // neighbouring row's label even when the plot is short.
    const pad = Math.min(
      props.focus === 'bar_ends' ? 80 : 30,
      Math.max(10, band.value - 12),
    )
    const top = Math.max(2, centre - pad)
    const bottom = Math.min(height - 2, centre + pad)
    return {
      left: 0,
      top,
      width: fullWidth,
      height: Math.max(16, bottom - top),
    }
  }

  return null
})

/* --- The chart ------------------------------------------------------------- */

/** One value as an axis tick reads it, in the units R named for this view. */
function tick(value: number): string {
  if (props.outcome?.value_kind === 'money') return formatEuro(value, 0)
  return formatQaly(value, 3)
}

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const g = grid.value
  const span = domain.value

  return {
    ...base,
    animation: !reducedMotion,
    animationDuration: 280,
    animationDurationUpdate: 240,
    animationEasingUpdate: 'cubicOut',
    // The bars are read from their labels and R's sentence; a hover box could
    // report numbers for rows that are still travelling.
    tooltip: { show: false },
    grid: {
      left: g.left,
      right: g.right,
      top: g.top,
      bottom: g.bottom,
      containLabel: false,
    },
    xAxis: {
      type: 'value',
      name: props.view === 'cost' ? props.graph.cost_axis_label : props.graph.health_axis_label,
      nameLocation: 'middle',
      nameGap: 32,
      min: span.min,
      max: span.max,
      ...base.axisStyle,
      axisLabel: { color: palette.value.muted, formatter: (value: number) => tick(value) },
    },
    yAxis: {
      type: 'category',
      // R's first row is drawn at the top.
      inverse: true,
      data: rows.value.map((row) => row.plot_label),
      ...base.axisStyle,
      axisLabel: {
        color: palette.value.text,
        width: g.left - 12,
        overflow: 'break',
        interval: 0,
        fontSize: narrow.value ? 10 : 11,
      },
      splitLine: { show: false },
    },
    series: [
      {
        // One rectangle per row, from the lower of R's two ends to the higher.
        type: 'custom',
        encode: { x: [1, 2], y: 0 },
        data: rows.value.map((row, index) => ({
          value: [index, row.low_outcome, row.high_outcome],
          parameter_id: row.parameter_id,
        })),
        renderItem: (
          params: { dataIndex: number },
          api: {
            value: (dimension: number) => unknown
            coord: (point: unknown[]) => number[]
            size: (size: unknown[]) => number | number[]
          },
        ) => {
          const index = params.dataIndex
          const row = rows.value[index]
          if (!row) return undefined
          const low = api.coord([api.value(1), index])
          const high = api.coord([api.value(2), index])
          const start = Math.min(low[0], high[0])
          const size = Math.abs(high[0] - low[0])
          const bandSize = api.size([0, 1])
          const bandHeight = Array.isArray(bandSize) ? bandSize[1] : bandSize
          const height = Math.min(18, Math.max(6, bandHeight * 0.62))
          if (size < 1.5) {
            // Nothing moved: a short tick at the reference, so the row is visibly
            // present with no length rather than missing from the chart.
            return {
              type: 'rect' as const,
              shape: {
                x: start - 1.5,
                y: low[1] - Math.min(7, bandHeight * 0.28),
                width: 3,
                height: Math.min(14, bandHeight * 0.56),
              },
              style: { fill: palette.value.muted },
            }
          }
          return {
            type: 'rect' as const,
            shape: { x: start, y: low[1] - height / 2, width: size, height },
            style: { fill: palette.value.accent },
          }
        },
      },
      {
        // R's base case: the comparison every bar is measured from.
        type: 'line',
        data: [],
        silent: true,
        markLine: {
          silent: true,
          symbol: 'none',
          label: {
            formatter: props.graph.reference_label,
            color: palette.value.text,
            position: 'insideEndTop',
          },
          lineStyle: { color: palette.value.text, type: 'dashed', width: 1.2 },
          data: props.outcome ? [{ xAxis: props.outcome.base_outcome }] : [],
        },
      },
    ],
  }
})

const { setCanvas } = useEcharts(() => option.value)
</script>

<template>
  <div
    ref="chartEl"
    class="chart journey__bars"
    :class="{ 'journey__bars--single': reveal === 'top' }"
  >
    <div :ref="setCanvas" class="chart__canvas" aria-hidden="true"></div>

    <!-- The two ends of the single bar, as page text rather than canvas text, so
         they wrap and scale with everything around them. -->
    <div
      v-for="label in endLabels"
      :key="`${outcome?.kind}-${label.key}`"
      class="bars__end"
      :style="{ left: `${label.left}px`, top: `${label.top}px`, width: `${label.width}px` }"
    >
      <span class="bars__end-eyebrow">{{ label.eyebrow }}</span>
      <span class="bars__end-input">{{ label.input }}</span>
      <span class="bars__end-value">{{ label.value }}</span>
    </div>

    <!-- The same cut-out the other chapters use. It carries no sentence of its
         own: the caption and the way forward sit in the panel under the chart, in
         one place at every state. -->
    <JourneySpotlight
      v-if="dim && hole"
      :area="area"
      :hole="hole"
      :scope="scope"
      :text="''"

    />
  </div>
</template>
