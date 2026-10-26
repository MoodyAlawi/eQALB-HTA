<script setup lang="ts">
/**
 * The sixth chapter's figure.
 *
 * Two things are drawn, and they are the two the base app's budget-impact panel
 * draws: the net budget impact per year as bars, and the running total as a line on
 * its own axis. The option is adapted from `charts/BudgetImpactChart.vue` â€” the same
 * `chartBase()` styling, the same sign rule taken from R's own value, the same
 * separate cumulative axis â€” so a learner who has seen the dashboard reads this one
 * immediately. The one difference is that both axes are pinned from R's whole sweep,
 * so moving the coverage cap never rescales a figure already on screen.
 *
 * The spending and the savings are not explained in a paragraph. They are the
 * component figures the base app's budget panel also shows, as `MetricCard`s, revealed
 * one at a time: programme costs, setup costs, healthcare savings, then what remains.
 * Each carries R's amount beside the thing it measures, and the period line above them
 * says the amounts cover all five years so none can be read as an annual figure. A
 * component worth exactly zero is never sent by R, so no card stands for something
 * that did not happen.
 *
 * Nothing is invented. The year labels, the axis names, the label texts and every
 * amount are R's; this component turns values into pixels and places labels.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type {
  JourneyBudgetCoverage,
  JourneyBudgetGraph,
  JourneyFocus,
} from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuroCompact } from '../../format'
import MetricCard from '../MetricCard.vue'
import JourneySpotlight from './JourneySpotlight.vue'

const props = defineProps<{
  /** R's labels for both panels and for the axis names. */
  graph: JourneyBudgetGraph
  /** R's rows and components for the selected cap and price, or null before it arrives. */
  step: JourneyBudgetCoverage | null
  /** The population, horizon and cap the introductory states show. */
  populationDisplay: string
  horizonYears: number
  coverageDisplay: string | null
  /** R's extents for both axes, fixed from the whole sweep. */
  axis: { annual: { min: number; max: number }; cumulative: { min: number; max: number } }
  /** How much of the figure this state draws. */
  reveal: 'intro' | 'annual' | 'cumulative'
  /** How many component figures this state has revealed. Absent from older
   * answers, which revealed the components in one step. */
  componentsShown?: number
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

const palette = useChartPalette()

/** ECharts animates in JavaScript, so the media query has to be read here. */
const reducedMotion =
  typeof window !== 'undefined' &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches

const rows = computed(() => props.step?.rows ?? [])
const showAnnual = computed(() => props.reveal !== 'intro' && rows.value.length > 0)
const showCumulative = computed(
  () => props.reveal === 'cumulative' && rows.value.length > 0,
)

/** Every component R sent for this step, or none when the answer predates the field. */
const componentList = computed(() => props.step?.components ?? [])

/** The component figures to reveal, up to what this state asks for. */
const components = computed(() =>
  componentList.value.slice(0, Math.max(0, props.componentsShown ?? 0)),
)

/** A card's tone, from R's own label for what the component does. */
function toneFor(tone: 'cost' | 'saving' | 'net'): 'bad' | 'good' | null {
  if (tone === 'saving') return 'good'
  if (tone === 'net') return null
  return 'bad'
}

/* --- The net-impact and cumulative chart ---------------------------------- */

/**
 * The same option shape the base app's budget chart uses: a bar for each year's
 * amount, a line for the running total on a second axis, both named by R. The extents
 * are pinned from R's sweep rather than computed by ECharts, so a moved coverage cap
 * changes the bars without changing the scale they are read against.
 */
const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const data = rows.value
  const withCumulative = showCumulative.value

  return {
    ...base,
    animation: !reducedMotion,
    animationDuration: 220,
    animationDurationUpdate: 220,
    grid: { left: 76, right: withCumulative ? 72 : 16, top: 30, bottom: 38, containLabel: false },
    // No tooltip: every amount already sits beside its own mark, and the chapter never
    // asks anyone to hover to find a number.
    tooltip: { show: false },
    xAxis: {
      type: 'category',
      data: data.map((row) => row.year_label),
      ...base.axisStyle,
      splitLine: { show: false },
      axisLabel: { color: palette.value.muted },
    },
    yAxis: [
      {
        type: 'value',
        name: props.graph.annual_axis_label,
        nameLocation: 'middle',
        nameGap: 60,
        min: props.axis.annual.min,
        max: props.axis.annual.max,
        ...base.axisStyle,
        axisLabel: {
          color: palette.value.muted,
          formatter: (value: number) => formatEuroCompact(value),
        },
      },
      {
        type: 'value',
        name: props.graph.cumulative_axis_label,
        nameLocation: 'middle',
        nameGap: 56,
        min: props.axis.cumulative.min,
        max: props.axis.cumulative.max,
        ...base.axisStyle,
        splitLine: { show: false },
        axisLabel: {
          color: palette.value.muted,
          formatter: (value: number) => formatEuroCompact(value),
        },
      },
    ],
    series: [
      {
        name: props.graph.annual_title,
        type: 'bar',
        data: data.map((row) => ({
          value: row.net,
          itemStyle: {
            // R's own sign decides the colour, exactly as the base app's chart does.
            color: row.net <= 0 ? palette.value.positive : palette.value.negative,
            borderRadius: 3,
          },
        })),
        barMaxWidth: 40,
        // Exact amounts rather than a tooltip, because the chapter never asks anyone
        // to hover for a number. Where two labels would collide on a narrow screen,
        // the colliding one is dropped instead of printed over its neighbour; the
        // exact figures stay in the component cards above.
        labelLayout: { hideOverlap: true },
        label: {
          show: true,
          position: 'top',
          // The amount beside its own bar, so the length and the number are read
          // together instead of the number being hunted for in prose.
          formatter: (params: { dataIndex: number }) =>
            data[params.dataIndex]?.net_display ?? '',
          color: palette.value.text,
          fontSize: 10,
        },
      },
      {
        name: props.graph.cumulative_title,
        type: 'line',
        yAxisIndex: 1,
        showSymbol: false,
        data: withCumulative ? data.map((row) => row.cumulative) : [],
        lineStyle: { color: palette.value.series[1], width: 2 },
        itemStyle: { color: palette.value.series[1] },
        symbol: 'circle',
        symbolSize: 7,
      },
    ],
  }
})

const { setCanvas, render } = useEcharts(() => option.value)

/**
 * The chart is created when its element first has a size. A learner who lands on a
 * state that shows only the components reaches the chart later, and a chart
 * initialised while its container was hidden would latch onto nothing, so it is asked
 * to render again as soon as it becomes visible.
 */
watch(
  showAnnual,
  (visible) => {
    if (visible) void nextTick(() => render())
  },
  { flush: 'post' },
)

/* --- The guidance cut-out -------------------------------------------------- */

interface Box {
  left: number
  top: number
  width: number
  height: number
}

const rootEl = ref<HTMLElement | null>(null)
const chartEl = ref<HTMLElement | null>(null)
const cardEls = ref<Record<string, HTMLElement | null>>({})

const rootBox = ref<Box>({ left: 0, top: 0, width: 0, height: 0 })

function setCardRef(key: string, element: Element | null): void {
  cardEls.value[key] = element instanceof HTMLElement ? element : null
}

function boxOf(element: HTMLElement | null): Box {
  const root = rootEl.value
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
}

let observer: ResizeObserver | null = null

onMounted(() => {
  measure()
  observer = new ResizeObserver(measure)
  if (rootEl.value) observer.observe(rootEl.value)
  window.addEventListener('resize', measure, { passive: true })
})

onBeforeUnmount(() => {
  observer?.disconnect()
  observer = null
  window.removeEventListener('resize', measure)
})

/**
 * A state reveals another card and can make the figure taller, and the browser reports
 * the new size only after the update has been laid out. Measuring again once the panel
 * has settled keeps the guidance's cut-out describing the boxes on screen rather than
 * the previous state's. `flush: 'post'` plus `nextTick` is the layout finishing, not a
 * delay.
 */
watch(
  () => [props.reveal, props.componentsShown, props.focus, props.scope, props.step],
  () => {
    void nextTick(measure)
  },
  { flush: 'post' },
)

/**
 * The region a state brings forward.
 *
 * A component state marks its own card: a small accent around one figure, which is
 * what it identifies. Only the two chart states mark the chart, and even then the
 * cut-out stops at the plot rather than taking the whole panel, so no ring encloses
 * the figure as a whole and no border is drawn across a label.
 */
const hole = computed<Box | null>(() => {
  if (!props.dim || props.focus === 'none') return null

  const cardKey =
    props.focus === 'budget_programme'
      ? 'programme'
      : props.focus === 'budget_setup'
        ? 'setup'
        : props.focus === 'budget_savings'
          ? 'savings'
          : props.focus === 'budget_net'
            ? 'net'
            : null

  if (cardKey) {
    const box = boxOf(cardEls.value[cardKey] ?? null)
    if (box.width <= 4) return null
    const pad = 5
    return {
      left: Math.max(0, box.left - pad),
      top: Math.max(0, box.top - pad),
      width: box.width + pad * 2,
      height: box.height + pad * 2,
    }
  }

  const chart = boxOf(chartEl.value)
  if (chart.width <= 4) return null
  return {
    left: 0,
    top: Math.max(0, chart.top),
    width: rootBox.value.width,
    height: Math.max(16, chart.height),
  }
})
</script>

<template>
  <div ref="rootEl" class="chart journey__budgetfig">
    <!-- The introductory states: the assumptions the totals rest on, and no amounts,
         so a total cannot be read before it is explained. It also stands in while the
         answer is on its way, so the panel is never blank. -->
    <div v-if="reveal === 'intro' || !step" class="budgetfig__intro">
      <dl class="budgetfig__facts">
        <div class="budgetfig__fact">
          <dt>{{ graph.eligible_label }}</dt>
          <dd>{{ populationDisplay }}</dd>
        </div>
        <div v-if="coverageDisplay" class="budgetfig__fact">
          <dt>{{ graph.covered_label }}</dt>
          <dd>{{ coverageDisplay }}</dd>
        </div>
        <div class="budgetfig__fact">
          <dt>{{ graph.year_label }}s</dt>
          <dd>{{ horizonYears }}</dd>
        </div>
      </dl>
    </div>

    <template v-else>
      <!-- The component breakdown, built up one figure at a time. The period above
           them is R's, so a five-year amount is never read as a year's. -->
      <div v-if="components.length > 0" class="budgetfig__components">
        <p class="budgetfig__period">{{ step.components_period }}</p>
        <div class="metrics budgetfig__metrics">
          <div
            v-for="component in components"
            :key="component.key"
            :ref="(element) => setCardRef(component.key, element as Element | null)"
            class="budgetfig__metric"
          >
            <MetricCard
              :label="component.label"
              :value="component.amount_display"
              :sub="component.sub"
              :tone="toneFor(component.tone)"
            />
          </div>
        </div>
      </div>

      <!-- The annual amounts, with the running total drawn on its own axis only once
           the chapter has reached it. -->
      <div v-if="showAnnual" ref="chartEl" class="budgetfig__panel">
        <p class="budgetfig__panel-title">{{ graph.annual_title }}</p>
        <div
          :ref="setCanvas"
          class="chart__canvas budgetfig__canvas"
          :class="{ 'budgetfig__canvas--tall': showCumulative }"
          aria-hidden="true"
        ></div>
      </div>

      <!-- The running total, in R's own sentence, once it is what is on screen. -->
      <p v-if="showCumulative && step.notes.cumulative" class="budgetfig__total">
        {{ step.notes.cumulative }}
      </p>
    </template>

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
