<script setup lang="ts">
/**
 * The journey's cost-effectiveness plane.
 *
 * It is the chapters' only learning surface: one graph that stays on screen while
 * the chapter changes which part of it is lit. It draws two chapters from the same
 * component, which is what lets the second chapter's cloud appear around the first
 * chapter's point without the chart being rebuilt.
 *
 * Chapter 1 states:
 *   0  usual care alone, framed tightly
 *   1  eQalb appears, with an arrow leading from usual care
 *   2  the health difference is drawn and labelled
 *   3  the cost difference is drawn and labelled
 *   4  both differences, equally lit
 *   5  the price state: the cost difference is the one that changes
 *
 * Chapter 2 states bring a cloud of repeats into the same frame: the repeats
 * themselves, their centre, their spread, the two sides of usual care, and the
 * sentence that says what the spread does not cover. The deterministic point is
 * drawn in every one of them, because the cloud is only meaningful as the company
 * that point keeps.
 *
 * Dimming is opacity inside the canvas, so the active point, leg and label stay
 * sharp while the rest recedes. On top of that, the guidance overlay softens the
 * parts of the plane the current state is not about, leaving the state's own
 * region bare. Nothing is hidden by colour alone: an element is either drawn or
 * not, and every label is R's own string.
 *
 * Motion: the point travels because price changes cost, so the chart merges its
 * options rather than replacing them; the cloud appears the same way. Under
 * `prefers-reduced-motion` there is no animation at all and each state is drawn
 * straight away.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type {
  JourneyFocus,
  JourneyLead,
  JourneyPlaneLabels,
  JourneyRepeat,
  TutorialCe,
} from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro, formatQaly } from '../../format'
import JourneySpotlight from './JourneySpotlight.vue'

/** A pixel rectangle from the chart's top-left corner. */
interface Box {
  left: number
  top: number
  width: number
  height: number
}

const props = defineProps<{
  /** R's chart data, or null before the first result exists. */
  chart: TutorialCe['chart'] | null
  graph: JourneyPlaneLabels
  /** The chapter's state, 0 to 5. */
  state: number
  /** Which region of the plane this state brings forward. */
  focus: JourneyFocus
  /** The pair of regions R asks the guide to connect, when it asks for one. */
  lead?: JourneyLead | null
  /** R's one sentence for this state, shown beside that region. */
  note: string
  /** R's one-sentence explanation of a measure this state introduces, if any. */
  measureNote?: string | null
  /**
   * Which chapter's picture these coordinates describe. The overlay places a cut-out
   * from a different chapter immediately instead of sliding to it, because two
   * chapters are two different charts.
   */
  scope?: string | null
  /**
   * Whether the overlay softens the parts of the plane this state is not about.
   * The price state turns it off: the learner is reading the whole plane while
   * they set the price, so nothing may sit over it.
   */
  dim: boolean
  /**
   * The second chapter's repeats, or null in the first chapter. Each entry is one
   * run of the model, so the plane draws exactly the draws R sent.
   */
  cloud?: JourneyRepeat[] | null
  /** The average of those repeats, or null in the first chapter. */
  mean?: { incremental_cost: number; incremental_qalys: number } | null
  /** R's name for the cloud and for its average, when the cloud is drawn. */
  cloudLabel?: string | null
  meanLabel?: string | null
}>()

const palette = useChartPalette()

/**
 * The plot's own margins, which the chart and the guidance overlay must agree on:
 * the overlay turns data values into the same pixels ECharts does, so the region
 * it leaves sharp is exactly the region the state is drawing.
 */
const GRID = { left: 96, right: 40, top: 48, bottom: 64 } as const

/** ECharts animates in JavaScript, so the media query has to be read here. */
const reducedMotion =
  typeof window !== 'undefined' &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches

/** Extent over the values, padded by a fraction of its span (with a floor), so
 * a point never sits on the frame and zero is always inside the view. */
function limits(values: number[], padFraction: number, minPad: number): [number, number] {
  const low = Math.min(...values)
  const high = Math.max(...values)
  const pad = Math.max((high - low) * padFraction, minPad)
  return [low - pad, high + pad]
}

const point = computed(() => props.chart?.points[1] ?? null)
const qalys = computed(() => point.value?.incremental_qalys ?? 0)
const cost = computed(() => point.value?.incremental_cost ?? 0)

/** The repeats the second chapter draws, once R has sent them. */
const cloud = computed<JourneyRepeat[]>(() => props.cloud ?? [])
const hasCloud = computed(() => cloud.value.length > 0)
const mean = computed(() => props.mean ?? null)

/**
 * Whether the eQalb point is drawn.
 *
 * The first chapter introduces it on its second state. The second chapter does not
 * introduce it at all: it is the comparison the repeats repeat, and it is already
 * known, so it is on screen from the chapter's first state and stays there while
 * the repeats gather around it.
 */
const showsEqalb = computed(() => (hasCloud.value || props.state >= 1) && point.value !== null)

/**
 * The differences drawn. The first chapter reveals them one at a time; the second
 * chapter draws both from its first state, because they are the comparison being
 * repeated rather than something still to be introduced.
 */
const showsHealth = computed(() => showsEqalb.value && (hasCloud.value || props.state >= 2))
const showsCost = computed(() => showsEqalb.value && (hasCloud.value || props.state >= 3))

/**
 * Whether a repeat fell on the other side of usual care. When none did, the frame
 * does not have to reach the origin, and the cloud fills the plane instead of
 * being squeezed into a corner of it.
 */
const crossesZero = computed(
  () =>
    hasCloud.value &&
    cloud.value.some((repeat) => repeat.cost <= 0 || repeat.qalys <= 0),
)

/**
 * The axis extents. State 0 frames usual care alone, so the learner starts where
 * the payer starts; from state 1 the frame fits both points. When the repeats are
 * on screen the frame holds them as well, and it does not move between the second
 * chapter's states: the same frame is what lets the cloud be read against the same
 * axes from one state to the next.
 */
const xExtent = computed<[number, number]>(() => {
  if (hasCloud.value) {
    const values = cloud.value.map((repeat) => repeat.qalys)
    if (crossesZero.value) values.push(0)
    return limits(values, 0.12, 0.001)
  }
  return showsEqalb.value ? limits([0, qalys.value], 0.5, 0.002) : [-0.001, 0.004]
})

const yExtent = computed<[number, number]>(() => {
  if (hasCloud.value) {
    const values = cloud.value.map((repeat) => repeat.cost)
    if (crossesZero.value) values.push(0)
    return limits(values, 0.12, 60)
  }
  return showsEqalb.value
    ? limits([0, cost.value], 0.35, Math.max(Math.abs(cost.value) * 0.2, 60))
    : [-140, 320]
})

/* --- The guidance geometry ------------------------------------------------ */

const planeEl = ref<HTMLElement | null>(null)
const area = ref({ width: 0, height: 0 })
let areaObserver: ResizeObserver | null = null

function measure(): void {
  const element = planeEl.value
  if (!element) return
  const width = element.clientWidth
  const height = element.clientHeight
  if (width !== area.value.width || height !== area.value.height) {
    area.value = { width, height }
  }
}

onMounted(() => {
  measure()
  areaObserver = new ResizeObserver(measure)
  if (planeEl.value) areaObserver.observe(planeEl.value)
  // The viewport is watched as well as the element: a narrow window can change the
  // chart's width without the observer having delivered by the time the learner
  // looks again, and the guidance must never be laid out for a size the plane no
  // longer has.
  window.addEventListener('resize', measure, { passive: true })
  window.addEventListener('orientationchange', measure, { passive: true })
})

onBeforeUnmount(() => {
  areaObserver?.disconnect()
  areaObserver = null
  window.removeEventListener('resize', measure)
  window.removeEventListener('orientationchange', measure)
})

/**
 * Re-measure after the DOM for a new state or a new chapter has been laid out.
 *
 * The panel above the plane can change height between states — a caption that wraps, a
 * measure note the previous state did not have, the stacked strip appearing on a narrow
 * screen — and this component can be reused across two chapters, so its previous
 * measurement can describe a panel that no longer exists. The browser reports the new
 * size only after it has laid the update out, so the measurement is taken once the
 * update is complete. `flush: 'post'` plus `nextTick` is that moment; nothing is timed,
 * and no frame is waited on speculatively.
 */
watch(
  () => [props.state, props.focus, props.scope, props.dim, props.cloud, props.chart],
  () => {
    void nextTick(measure)
  },
  { flush: 'post' },
)

/** A value's pixel column, using the same frame ECharts is drawing. */
function toX(value: number): number {
  const [min, max] = xExtent.value
  const span = area.value.width - GRID.left - GRID.right
  return GRID.left + ((value - min) / (max - min)) * span
}

/** A value's pixel row, measured from the chart's top. */
function toY(value: number): number {
  const [min, max] = yExtent.value
  const span = area.value.height - GRID.top - GRID.bottom
  return area.value.height - GRID.bottom - ((value - min) / (max - min)) * span
}

/**
 * The region the state brings forward, in pixels: the data-space corners of the
 * cue, grown by the room its own label needs so that the label is inside the
 * sharp area rather than in the softened part.
 *
 * Chapter 1: `origin` is the starting point alone, `health` the horizontal
 * difference, `lead` and `cost` the two points with the change between them.
 *
 * Chapter 2: `cloud` and `spread` take the whole cloud, `sides` takes it with the
 * origin included because that is the line the repeats are said to cross, and
 * `centre` takes only the average and the point, so the repeats around them are
 * what gets softened.
 */
const hole = computed<Box | null>(() => {
  const { width, height } = area.value
  if (width <= 4 || height <= 4) return null

  const q = qalys.value
  const c = cost.value
  const edge = 6
  let xs: number[] = [0]
  let ys: number[] = [0]
  let padding = { left: 42, right: 150, top: 46, bottom: 42 }

  if (hasCloud.value && props.focus === 'centre' && mean.value) {
    // The middle of the cloud, with room for the two labels that sit beside the
    // average and the point.
    xs = [mean.value.incremental_qalys, q]
    ys = [mean.value.incremental_cost, c]
    padding = { left: 46, right: 168, top: 46, bottom: 46 }
  } else if (hasCloud.value) {
    // The repeats themselves. The origin is deliberately left out of the cut-out
    // even when a repeat crossed to its side: the zero lines are drawn across the
    // whole plane, so the side a repeat falls on is still visible where the cloud
    // meets them, and keeping the corner out leaves the panel room for the
    // sentence that describes it.
    xs = cloud.value.map((repeat) => repeat.qalys)
    ys = cloud.value.map((repeat) => repeat.cost)
    padding = { left: 24, right: 150, top: 24, bottom: 24 }
  } else if (showsEqalb.value && props.focus === 'health') {
    xs = [0, q]
    ys = [c]
    padding = { left: 42, right: 150, top: 40, bottom: 56 }
  } else if (showsEqalb.value && (props.focus === 'lead' || props.focus === 'cost')) {
    xs = [0, q]
    ys = [0, c]
    padding = { left: 46, right: 150, top: 40, bottom: 42 }
  }

  const left = Math.min(Math.min(...xs.map(toX)) - padding.left, width - edge)
  const right = Math.max(Math.max(...xs.map(toX)) + padding.right, edge)
  const top = Math.min(Math.min(...ys.map(toY)) - padding.top, height - edge)
  const bottom = Math.max(Math.max(...ys.map(toY)) + padding.bottom, edge)

  // The axis labels are text, so the cut-out stops clear of them: the value axis's
  // labels end eight pixels left of the plot and the date axis's labels begin eight
  // pixels below it. An edge inside either would cut a label in two, and the accent
  // that marks the cut-out is painted on its inside, so an edge through a label is
  // a line through a label. Clamping only ever narrows the cut-out.
  const axisSafeLeft = GRID.left - 6
  const axisSafeBottom = height - GRID.bottom + 4

  const l = Math.max(edge, Math.min(left, width - edge - 48), axisSafeLeft)
  const t = Math.max(edge, Math.min(top, height - edge - 48))
  const b = Math.min(Math.min(bottom, height - edge), axisSafeBottom)
  return {
    left: l,
    top: t,
    width: Math.max(48, Math.min(right, width - edge) - l),
    height: Math.min(Math.max(48, b - t), Math.max(16, axisSafeBottom - t)),
  }
})

/* --- The directional guide ------------------------------------------------ */

/** A short segment drawn over the plane, with its head at its end. */
interface Arrow {
  x1: number
  y1: number
  x2: number
  y2: number
}

/**
 * The arrows that lead attention from one feature of the plane to the next.
 *
 * R names the pair (`lead`); this turns the pair into pixels, using the same frame
 * the chart is drawn in. Every arrow starts and ends clear of the feature it points
 * at, so it never covers a dot, the point, a label or an axis: it is a slim trace
 * beside them, not a bar across them.
 */
const leadArrows = computed<Arrow[]>(() => {
  const { width, height } = area.value
  const lead = props.lead
  if (width <= 4 || height <= 4) return []
  if (!lead || !hasCloud.value) return []

  const margin = 14
  const clampX = (value: number) => Math.max(margin, Math.min(value, width - margin))
  const clampY = (value: number) => Math.max(margin, Math.min(value, height - margin))

  const pointX = toX(qalys.value)
  const pointY = toY(cost.value)
  const meanX = mean.value ? toX(mean.value.incremental_qalys) : pointX
  const meanY = mean.value ? toY(mean.value.incremental_cost) : pointY

  // The repeat furthest from the base case, in pixels, gives the direction a
  // lead takes: it is the edge of the cloud in the direction the eye should go.
  let farX = pointX
  let farY = pointY
  let farDistance = 0
  for (const repeat of cloud.value) {
    const x = toX(repeat.qalys)
    const y = toY(repeat.cost)
    const distance = Math.hypot(x - pointX, y - pointY)
    if (distance > farDistance) {
      farDistance = distance
      farX = x
      farY = y
    }
  }

  const direction = (dx: number, dy: number) => {
    const length = Math.hypot(dx, dy) || 1
    return { ux: dx / length, uy: dy / length }
  }

  if (lead === 'point_to_cloud') {
    // From the base case, out along the direction the repeats run furthest.
    const { ux, uy } = direction(farX - pointX, farY - pointY)
    const start = 22
    const end = Math.max(start + 24, Math.min(farDistance - 16, start + 96))
    return [
      {
        x1: clampX(pointX + ux * start),
        y1: clampY(pointY + uy * start),
        x2: clampX(pointX + ux * end),
        y2: clampY(pointY + uy * end),
      },
    ]
  }

  if (lead === 'cloud_to_centre') {
    // From a repeat at the edge of the cloud inward, to the average the repeats
    // gather around. It is kept short: it marks the direction attention moves,
    // rather than drawing a line across the whole plane.
    const { ux, uy } = direction(farX - meanX, farY - meanY)
    const start = Math.min(farDistance - 24, 92)
    const end = 26
    return [
      {
        x1: clampX(meanX + ux * Math.max(start, end + 30)),
        y1: clampY(meanY + uy * Math.max(start, end + 30)),
        x2: clampX(meanX + ux * end),
        y2: clampY(meanY + uy * end),
      },
    ]
  }

  if (lead === 'centre_to_spread') {
    // The vertical extent the repeats ran over, beside the cloud rather than across
    // it: two short arrows out from the middle, so the span is read without any dot
    // being covered.
    const costs = cloud.value.map((repeat) => toY(repeat.cost))
    const top = Math.max(margin, Math.min(...costs) - 8)
    const bottom = Math.min(height - margin, Math.max(...costs) + 8)
    const x = clampX(Math.max(...cloud.value.map((repeat) => toX(repeat.qalys))) + 20)
    const middle = (top + bottom) / 2
    return [
      { x1: x, y1: middle, x2: x, y2: top },
      { x1: x, y1: middle, x2: x, y2: bottom },
    ]
  }

  // `spread_to_zero`: from the nearest repeat toward the corner where usual care
  // sits, so the zero lines the repeats are measured from are the place the eye is
  // sent next.
  const originX = clampX(toX(0))
  const originY = clampY(toY(0))
  const { ux, uy } = direction(originX - meanX, originY - meanY)
  const start = 24
  const end = 22
  const reach = Math.min(Math.hypot(originX - meanX, originY - meanY) - end, 150)
  return [
    {
      x1: clampX(meanX + ux * start),
      y1: clampY(meanY + uy * start),
      x2: clampX(meanX + ux * Math.max(start + 24, reach)),
      y2: clampY(meanY + uy * Math.max(start + 24, reach)),
    },
  ]
})

/**
 * How lit one part of the graph is. The state's own subject is at full strength;
 * what it has already taught stays visible but recedes, so the learner keeps the
 * whole picture while attention moves.
 */
function alpha(part: 'points' | 'health' | 'cost' | 'arrow'): number {
  if (hasCloud.value) {
    // Chapter 2: the differences of the first chapter stay drawn at full strength,
    // because the cloud is only meaningful against the comparison it repeats. What
    // the state changes is the cloud's own emphasis, below.
    return part === 'arrow' ? 0 : 1
  }
  const state = props.state
  if (state === 0) return part === 'points' ? 1 : 0
  if (state === 1) return part === 'arrow' || part === 'points' ? 1 : 0
  if (state === 2) return part === 'health' ? 1 : part === 'arrow' ? 0 : 0.4
  if (state === 3) return part === 'cost' ? 1 : part === 'arrow' ? 0 : 0.32
  if (state === 4) return part === 'arrow' ? 0 : 1
  // The price state shows the whole plane without the overlay's softening, so the
  // cost difference leads at full strength and the health difference stays clearly
  // legible beside it: the point of this state is that one difference moves while
  // the other does not.
  return part === 'cost' ? 1 : part === 'health' ? 0.62 : part === 'arrow' ? 0 : 1
}

/** A label attached to a point in the middle of a difference. */
function legLabel(
  label: string,
  position: 'top' | 'right' | 'bottom',
  x: number,
  y: number,
  opacity: number,
): EChartsCoreOption {
  return {
    type: 'scatter',
    name: label,
    data: [{ value: [x, y] }],
    symbolSize: 1,
    itemStyle: { opacity: 0 },
    label: {
      show: true,
      formatter: label,
      position,
      color: palette.value.text,
      opacity,
      fontSize: 12,
      fontWeight: 'bold',
    },
    silent: true,
    tooltip: { show: false },
    animation: !reducedMotion,
    animationDuration: 240,
    animationDurationUpdate: 240,
  }
}

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const hasPoint = showsEqalb.value
  const q = qalys.value
  const c = cost.value
  const state = props.state
  const [xMin, xMax] = xExtent.value
  const [yMin, yMax] = yExtent.value

  const arrow = alpha('arrow')
  const costAlpha = alpha('cost')
  const healthAlpha = alpha('health')
  const pointAlpha = alpha('points')

  /**
   * How lit the repeats are. The states of the second chapter take turns: the
   * cloud, its centre, its spread and the two sides of usual care. The cloud stays
   * drawn in every one of them, because it is the same cloud being looked at; what
   * changes is whether it or the point at its centre is the subject.
   */
  const cloudAlpha = (() => {
    if (!hasCloud.value) return 0
    if (props.focus === 'centre') return 0.34
    return 1
  })()

  const meanAlpha = (() => {
    if (!hasCloud.value || !mean.value) return 0
    return props.focus === 'centre' || props.focus === 'cloud' ? 1 : 0.7
  })()

  const series: EChartsCoreOption[] = []

  // The repeats, drawn under everything else so the point they cluster around
  // stays on top. One dot is one run of the model: R sent every draw, so the
  // picture is the draws rather than a summarised version of them.
  if (hasCloud.value) {
    series.push({
      name: props.cloudLabel ?? '',
      type: 'scatter',
      data: cloud.value.map((repeat) => [repeat.qalys, repeat.cost]),
      symbolSize: area.value.width > 0 && area.value.width < 420 ? 5 : 7,
      itemStyle: {
        color: palette.value.intervention,
        opacity: 0.45 * cloudAlpha,
        borderWidth: 0,
      },
      emphasis: { disabled: true },
      silent: true,
      tooltip: { show: false },
      animation: !reducedMotion,
      animationDuration: 320,
      animationDurationUpdate: 200,
    })

    // The average of the repeats, labelled with R's own name for it, and — in the
    // state about the two sides of usual care — the two zero lines those sides are
    // measured from. They are drawn as context, never as a boundary.
    if (mean.value) {
      series.push({
        name: props.meanLabel ?? '',
        type: 'scatter',
        data: [{ value: [mean.value.incremental_qalys, mean.value.incremental_cost] }],
        symbolSize: 16,
        itemStyle: {
          color: palette.value.panel,
          opacity: meanAlpha,
          borderColor: palette.value.text,
          borderWidth: 2,
        },
        label: {
          show: true,
          formatter: props.meanLabel ?? '',
          position: 'left',
          distance: 8,
          color: palette.value.text,
          fontSize: 12,
          fontWeight: 'bold',
          opacity: meanAlpha,
        },
        silent: true,
        tooltip: { show: false },
        animation: !reducedMotion,
        animationDuration: 260,
        animationDurationUpdate: 260,
        markLine:
          props.focus === 'sides'
            ? {
                silent: true,
                symbol: 'none',
                label: { show: false },
                lineStyle: {
                  color: palette.value.muted,
                  width: 1,
                  type: 'dashed' as const,
                  opacity: 0.9,
                },
                data: [{ xAxis: 0 }, { yAxis: 0 }],
              }
            : undefined,
      })
    }
  }

  series.push({
    name: props.graph.point_label,
    type: 'scatter',
    data: hasPoint
      ? [
          {
            value: [0, 0],
            symbolSize: state === 0 ? 18 : 13,
            itemStyle: {
              color: palette.value.control,
              opacity: pointAlpha,
              borderColor: palette.value.panel,
              borderWidth: state === 0 ? 3 : 2,
            },
          },
          {
            value: [q, c],
            symbolSize: state === 1 ? 18 : 14,
            itemStyle: {
              color: palette.value.intervention,
              opacity: pointAlpha,
              borderColor: palette.value.panel,
              borderWidth: state === 1 ? 3 : 2,
            },
          },
        ]
      : [
          {
            value: [0, 0],
            symbolSize: 18,
            itemStyle: {
              color: palette.value.control,
              borderColor: palette.value.panel,
              borderWidth: 3,
            },
          },
        ],
    emphasis: { scale: 1.15 },
    label: {
      show: true,
      position: 'right',
      formatter: (params: { dataIndex: number }) =>
        params.dataIndex === 0 ? props.graph.origin_label : props.graph.point_label,
      color: palette.value.text,
      fontSize: 13,
      fontWeight: 'bold',
      opacity: pointAlpha,
    },
    animation: !reducedMotion,
    animationDuration: 260,
    animationDurationUpdate: 260,
    tooltip: { show: false },
  })

  // State 1: the arrow that leads from usual care to usual care plus eQalb.
  if (hasPoint && arrow > 0) {
    series.push({
      name: 'lead',
      type: 'line',
      data: [
        [0, 0],
        [q, c],
      ],
      symbol: ['none', 'arrow'],
      symbolSize: 12,
      lineStyle: {
        color: palette.value.intervention,
        width: 2,
        type: 'dashed',
        opacity: 0.65,
      },
      itemStyle: { color: palette.value.intervention, opacity: 0.65 },
      silent: true,
      tooltip: { show: false },
      animation: !reducedMotion,
      animationDuration: 420,
      animationDurationUpdate: 260,
    })
  }

  // The differences. Each leg is its own series so the chapter can introduce one
  // at a time and keep the other visible but receded. The second chapter draws the
  // same two legs behind its cloud, unlabelled: they are the comparison the
  // repeats are repeats of, and its own sentences carry the words.
  if (hasPoint && showsHealth.value && props.graph.health_leg_label) {
    series.push({
      name: props.graph.health_leg_label,
      type: 'line',
      data: [
        [0, c],
        [q, c],
      ],
      symbol: 'none',
      lineStyle: {
        color: palette.value.accent,
        width: !hasCloud.value && state === 2 ? 4 : 3,
        opacity: healthAlpha,
      },
      silent: true,
      tooltip: { show: false },
      animation: !reducedMotion,
      animationDuration: 300,
      animationDurationUpdate: 300,
    })
    series.push(legLabel(props.graph.health_leg_label, 'bottom', q / 2, c, healthAlpha))
  }

  if (hasPoint && showsCost.value && props.graph.cost_leg_label) {
    series.push({
      name: props.graph.cost_leg_label,
      type: 'line',
      data: [
        [0, 0],
        [0, c],
      ],
      symbol: 'none',
      lineStyle: {
        color: palette.value.intervention,
        width: !hasCloud.value && (state === 3 || state === 5) ? 4 : 3,
        opacity: costAlpha,
      },
      silent: true,
      tooltip: { show: false },
      animation: !reducedMotion,
      animationDuration: 300,
      animationDurationUpdate: 300,
    })
    series.push(legLabel(props.graph.cost_leg_label, 'right', 0, c / 2, costAlpha))
  }

  return {
    ...base,
    animation: !reducedMotion,
    animationDuration: 260,
    animationDurationUpdate: 260,
    animationEasingUpdate: 'cubicOut',
    grid: { left: GRID.left, right: GRID.right, top: GRID.top, bottom: GRID.bottom, containLabel: false },
    tooltip: { ...base.tooltip, show: false },
    xAxis: {
      type: 'value',
      name: props.graph.x_label,
      nameLocation: 'middle',
      nameGap: 32,
      min: xMin,
      max: xMax,
      ...base.axisStyle,
      axisLabel: {
        color: palette.value.muted,
        opacity: !hasCloud.value && state === 0 ? 0.55 : 1,
        formatter: (value: number) => formatQaly(value, 3),
      },
    },
    yAxis: {
      type: 'value',
      name: props.graph.y_label,
      nameLocation: 'middle',
      nameGap: 78,
      min: yMin,
      max: yMax,
      ...base.axisStyle,
      axisLabel: {
        color: palette.value.muted,
        opacity: !hasCloud.value && state === 0 ? 0.55 : 1,
        formatter: (value: number) => formatEuro(value, 0),
      },
    },
    series,
  }
})

const { setCanvas } = useEcharts(() => option.value, { merge: true })
</script>

<template>
  <div ref="planeEl" class="chart chart--tall journey__plane">
    <div :ref="setCanvas" class="chart__canvas" aria-hidden="true"></div>
    <!-- The guidance overlay. It leaves the state's own region bare and softens
         the rest of the same plane, so the learner's eye stays on the graph. The
         price state draws it without any softening, so the whole plane is legible
         while the learner moves the price. -->
    <JourneySpotlight
      v-if="dim"
      ref="spotlight"
      :area="area"
      :hole="hole"
      :text="note"
      :measure="measureNote"
      :arrows="leadArrows"
      :scope="scope"
    />
  </div>
</template>
