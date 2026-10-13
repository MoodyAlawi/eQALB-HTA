<script setup lang="ts">
/**
 * Tornado diagram of the one-way sensitivity analysis.
 *
 * Each parameter is drawn as one bar spanning the low and the high outcome R
 * returned for it, in the order R returned the rows: the API already ranks them
 * by the model's own `impact_range`, so the ranking is the model's and this
 * component neither re-sorts nor drops a row. R's base outcome is marked with a
 * line.
 *
 * ECharts 6 does not accept a two-element array as a bar's value range: it reads
 * an array data item as [x, y] coordinates, so every bar was dropped and the value
 * axis was scaled from the first element alone. The spans are therefore drawn by a
 * custom series, which is handed the two bound outcomes R returned and draws one
 * rectangle between them. No value is changed or derived — the two numbers only
 * become pixel positions — and every lookup goes through the `parameter_id` R
 * returns with the row rather than through a position in an array.
 */

import { CustomChart } from 'echarts/charts'
import { use as registerChartTypes } from 'echarts/core'
import type { EChartsCoreOption } from 'echarts/core'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import type { OwsaOutcome, OwsaRow } from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { isNum } from '../../format'

// A range bar is a custom series, which only this chart draws, so the type is
// registered here rather than widening the shared registration in useEcharts.ts.
// `use()` is global and idempotent.
registerChartTypes([CustomChart])

const props = defineProps<{
  rows: OwsaRow[]
  baseOutcome: number | null
  outcome: OwsaOutcome
  /** Formats an outcome value for the tooltip and the axis. */
  format: (value: number | null) => string
}>()

const palette = useChartPalette()

/**
 * The parameter column is sized from the chart's own width: at its full width
 * there is room to wrap the long parameter names, and on a phone the column
 * narrows so the plot area keeps enough room for the bars to be read.
 */
const wrapper = ref<HTMLElement | null>(null)
const wrapperWidth = ref(0)
let observer: ResizeObserver | null = null

onMounted(() => {
  const element = wrapper.value
  if (!element) return
  wrapperWidth.value = element.clientWidth
  observer = new ResizeObserver((entries) => {
    const width = entries[0]?.contentRect.width ?? 0
    if (width > 0) wrapperWidth.value = width
  })
  observer.observe(element)
})

onBeforeUnmount(() => {
  observer?.disconnect()
  observer = null
})

const labelWidth = computed(() => {
  const width = wrapperWidth.value
  return width > 0 && width < 520 ? 96 : 150
})

interface Bar {
  /** R's own parameter identifier: the stable key for every lookup. */
  id: string
  label: string
  low: number | null
  high: number | null
  /** R's own `impact_range` for the selected outcome, shown in the tooltip. */
  range: number | null
  /** The two bound outcomes as drawn geometry, lower first; null if unusable. */
  span: [number, number] | null
}

/**
 * R's rows, in R's order, with the geometry the bars need. Ranking is the model's:
 * the API sorts by `impact_range` and the table below the chart lists the same
 * rows, so nothing is re-sorted or dropped here.
 */
const bars = computed<Bar[]>(() =>
  props.rows.map((row) => {
    const low = isNum(row.selected_outcome_low) ? row.selected_outcome_low : null
    const high = isNum(row.selected_outcome_high) ? row.selected_outcome_high : null
    return {
      id: row.parameter_id,
      label: row.parameter,
      low,
      high,
      range: isNum(row.impact_range) ? row.impact_range : null,
      span: low === null || high === null ? null : [Math.min(low, high), Math.max(low, high)],
    }
  }),
)

/** R's rows by the identifier R returns with each of them. */
const rowsById = computed(() => new Map(props.rows.map((row) => [row.parameter_id, row])))

const baseline = computed(() => (isNum(props.baseOutcome) ? props.baseOutcome : null))

interface SpanDatum {
  /** [category index, start, end]: the part of this row's span on this side. */
  value: [number, number, number]
  parameter_id: string
}

/**
 * The visible part of each row's span for one side of R's base outcome, one entry
 * per row so a data index always belongs to the row at that index. The two series
 * meet at the base outcome, so a colour changes there and nowhere else; a row that
 * lies entirely on one side gets its full bar from one series and a zero-length
 * entry from the other, which draws nothing.
 */
function sideSpans(side: 'below' | 'above'): SpanDatum[] {
  const base = baseline.value
  return bars.value.map((bar, index) => {
    const span = bar.span
    if (!span) return { value: [index, 0, 0], parameter_id: bar.id }
    const [low, high] = span
    const start = side === 'below' ? low : base === null ? high : Math.max(low, base)
    const end = side === 'below' ? (base === null ? high : Math.min(high, base)) : high
    return { value: [index, start, Math.max(start, end)], parameter_id: bar.id }
  })
}

const belowSpans = computed(() => sideSpans('below'))
const aboveSpans = computed(() => sideSpans('above'))

/**
 * The value axis covers every bound R returned, plus R's base outcome so the
 * reference line stays visible. Bars are never extended to reach the baseline:
 * a span is drawn at its own two bounds.
 */
const domain = computed(() => {
  const values: number[] = []
  for (const bar of bars.value) {
    if (bar.span) values.push(bar.span[0], bar.span[1])
  }
  if (baseline.value !== null) values.push(baseline.value)
  if (values.length === 0) return null
  const min = Math.min(...values)
  const max = Math.max(...values)
  const pad = (max > min ? max - min : Math.abs(max) || 1) * 0.02
  return { min: min - pad, max: max + pad }
})

/** Bar thickness: the old barMaxWidth, within the category band. */
const BAR_MAX_WIDTH = 18
const BAR_BAND_FRACTION = 0.7

/** The two sides of the base outcome, coloured by which direction is better. */
const lowerIsBetter = computed(
  () => props.outcome !== 'inmb' && props.outcome !== 'incremental_qalys',
)
const belowColour = computed(() =>
  lowerIsBetter.value ? palette.value.positive : palette.value.negative,
)
const aboveColour = computed(() =>
  lowerIsBetter.value ? palette.value.negative : palette.value.positive,
)

/**
 * Draws one row's span for one side of the base outcome. The rectangle starts at
 * the value R returned for the start of the span and ends at the value it returned
 * for the end, so its extent is exactly the table's two bound outcomes.
 */
function renderSpan(colour: string) {
  return (
    params: { dataIndex: number },
    api: {
      value: (dimension: number) => unknown
      coord: (point: unknown[]) => number[]
      size: (size: unknown[]) => number | number[]
    },
  ) => {
    const category = params.dataIndex
    const start = api.coord([api.value(1), category])
    const end = api.coord([api.value(2), category])
    const width = end[0] - start[0]
    if (!(width > 0)) return undefined
    const band = api.size([0, 1])
    const bandHeight = Array.isArray(band) ? band[1] : band
    const height = Math.min(BAR_MAX_WIDTH, bandHeight * BAR_BAND_FRACTION)
    return {
      type: 'rect' as const,
      shape: { x: start[0], y: start[1] - height / 2, width, height },
      style: { fill: colour },
    }
  }
}

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)

  return {
    ...base,
    // containLabel sizes the parameter column from its own labels, so the plot
    // area keeps room on a phone rather than being eaten by a fixed margin.
    grid: { left: 8, right: 32, top: 34, bottom: 40, containLabel: true },
    legend: { top: 4, textStyle: { color: palette.value.text }, icon: 'roundRect' },
    tooltip: {
      ...base.tooltip,
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: (params: unknown) => {
        const list = params as { dataIndex: number }[]
        if (!Array.isArray(list) || list.length === 0) return ''
        // The row is found through the identifier R returns with it, which the
        // data item carries, so nothing is paired by array position.
        const item = belowSpans.value[list[0].dataIndex] ?? aboveSpans.value[list[0].dataIndex]
        const row = item ? rowsById.value.get(item.parameter_id) : undefined
        if (!row) return ''
        return [
          `<strong>${row.parameter}</strong>`,
          `Outcome at low bound: ${props.format(row.selected_outcome_low)}`,
          `Outcome at high bound: ${props.format(row.selected_outcome_high)}`,
          `Base case: ${props.format(baseline.value)}`,
          `Range: ${props.format(row.impact_range)}`,
        ].join('<br/>')
      },
    },
    xAxis: {
      type: 'value',
      name: 'Outcome',
      nameLocation: 'middle',
      nameGap: 26,
      ...base.axisStyle,
      ...(domain.value ? { min: domain.value.min, max: domain.value.max } : {}),
      axisLabel: { color: palette.value.muted, formatter: (value: number) => props.format(value) },
    },
    yAxis: {
      type: 'category',
      // R's first row is drawn at the top, matching the table's order.
      inverse: true,
      data: bars.value.map((bar) => bar.label),
      ...base.axisStyle,
      axisLabel: { color: palette.value.text, width: labelWidth.value, overflow: 'break' },
      splitLine: { show: false },
    },
    series: [
      {
        name: 'Below base case',
        type: 'custom',
        encode: { x: [1, 2], y: 0 },
        itemStyle: { color: belowColour.value },
        data: belowSpans.value,
        renderItem: renderSpan(belowColour.value),
      },
      {
        name: 'Above base case',
        type: 'custom',
        encode: { x: [1, 2], y: 0 },
        itemStyle: { color: aboveColour.value },
        data: aboveSpans.value,
        renderItem: renderSpan(aboveColour.value),
      },
      {
        // The spans cover the two sides of the base outcome, so it is drawn as a
        // reference line rather than a third series of bars.
        name: 'Base case',
        type: 'line',
        data: [],
        silent: true,
        markLine: {
          silent: true,
          symbol: 'none',
          label: { formatter: 'Base case', color: palette.value.text },
          lineStyle: { color: palette.value.text, type: 'dashed', width: 1.2 },
          data: baseline.value === null ? [] : [{ xAxis: baseline.value }],
        },
      },
    ],
  }
})

const { setCanvas } = useEcharts(() => option.value)
</script>

<template>
  <div ref="wrapper" class="chart chart--tall chart--tornado">
    <div :ref="setCanvas" class="chart__canvas"></div>
    <p v-if="bars.length === 0" class="chart__empty">
      No one-way sensitivity results to show yet. Run the analysis on this tab.
    </p>
  </div>
</template>
