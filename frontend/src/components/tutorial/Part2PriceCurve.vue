<script setup lang="ts">
/**
 * The Part 2 negotiated-price curve: the deterministic ICER at every lever value,
 * with the payer's threshold line and a marker at the learner's price.
 *
 * Every number, label, colour and classification is R's. The series split (which
 * points meet the threshold and which do not), the maximum acceptable price, the
 * threshold's value and its legend text, the marker's price and colour, and the
 * chart's title, caption and axis names all arrive in the response, so this
 * component draws R's answer rather than deciding anything.
 *
 * Marks are identified by R's own stable `key` per point, never by array index:
 * the tooltip looks the hovered mark up by that key, so a series R splits
 * differently can never show another row's numbers. The axis extents and tick
 * spacing are chart geometry; the two vertical extents cover R's own threshold
 * line and data.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import type { Part2Chart, Part2Curve, Part2CurvePoint } from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro, formatNumber } from '../../format'
import InfoTip from '../InfoTip.vue'

const props = defineProps<{
  curve: Part2Curve
  chart: Part2Chart
  /** R's marker for the evaluated price. */
  marker: { price: number; key: string; colour: string; label: string }
  /** R's note about what the curve is; shown behind the caption's information control. */
  note?: string
}>()

const palette = useChartPalette()

/** R's series metadata, keyed so the two series keep R's colours. */
const seriesFor = (key: string) =>
  props.chart.series.find((series) => series.key === key) ?? { key, label: key, colour: '' }

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const points = props.curve.points
  const prices = points.map((point) => point.price)
  const icers = points.map((point) => (typeof point.icer === 'number' ? point.icer : null))

  const xMin = Math.min(...prices)
  const xMax = Math.max(...prices)
  const finite = icers.filter((value): value is number => typeof value === 'number')
  const yTop = Math.max(
    props.chart.threshold_line.value,
    ...(finite.length > 0 ? finite : [0]),
  )
  const yBottom = Math.min(0, ...(finite.length > 0 ? finite : [0]))
  const yPad = Math.max((yTop - yBottom) * 0.08, 1000)

  // One series per R classification. R decides membership; these two groups are
  // drawn with R's own colours and labels.
  const series = props.chart.series.map((entry) => {
    const rows = points.filter((point) => point.series_key === entry.key)
    return {
      name: entry.label,
      type: 'line' as const,
      data: rows.map((point) => ({
        name: point.key,
        value: [point.price, typeof point.icer === 'number' ? point.icer : null],
      })),
      symbol: 'circle',
      symbolSize: 7,
      connectNulls: false,
      lineStyle: { color: entry.colour, width: 2 },
      itemStyle: { color: entry.colour },
      markLine:
        entry.key === props.chart.series[0]?.key
          ? {
              silent: true,
              symbol: 'none',
              data: [
                {
                  yAxis: props.chart.threshold_line.value,
                  lineStyle: {
                    color: props.chart.threshold_line.colour,
                    type: props.chart.threshold_line.dash,
                    width: 1.4,
                  },
                  label: {
                    formatter: props.chart.threshold_line.label,
                    position: 'insideEndTop' as const,
                    color: props.chart.threshold_line.colour,
                  },
                },
                {
                  xAxis: props.marker.price,
                  lineStyle: { color: props.marker.colour, width: 1.6 },
                  label: {
                    formatter: props.marker.label,
                    position: 'insideStartTop' as const,
                    color: props.marker.colour,
                  },
                },
              ],
            }
          : undefined,
    }
  })

  const byKey = new Map<string, Part2CurvePoint>(points.map((point) => [point.key, point]))

  return {
    ...base,
    grid: { left: 92, right: 34, top: 54, bottom: 62, containLabel: false },
    legend: { top: 4, textStyle: { color: palette.value.text }, icon: 'roundRect' },
    tooltip: {
      ...base.tooltip,
      trigger: 'item',
      formatter: (params: unknown) => {
        const item = params as { name?: string }
        // The row is found by R's own point key, never by the mark's position.
        const point = item.name ? byKey.get(item.name) : undefined
        if (!point) return ''
        const series = seriesFor(point.series_key)
        return [
          `<strong>${formatEuro(point.price, 2)} per active user per year</strong>`,
          `ICER: ${point.icer_display}${typeof point.icer === 'number' ? ' per QALY' : ''}`,
          `Incremental cost: ${formatEuro(point.incremental_cost, 2)} per person`,
          `Incremental QALYs: ${formatNumber(point.incremental_qalys, 5)}`,
          series.label,
        ].join('<br/>')
      },
    },
    xAxis: {
      type: 'value',
      name: props.chart.x_label,
      nameLocation: 'middle',
      nameGap: 34,
      min: xMin,
      max: xMax,
      ...base.axisStyle,
      axisLabel: {
        color: palette.value.muted,
        formatter: (value: number) => formatEuro(value, 0),
      },
    },
    yAxis: {
      type: 'value',
      name: props.chart.y_label,
      nameLocation: 'middle',
      nameGap: 76,
      min: yBottom - yPad,
      max: yTop + yPad,
      ...base.axisStyle,
      axisLabel: {
        color: palette.value.muted,
        formatter: (value: number) => formatEuro(value, 0),
      },
    },
    series,
  }
})

const { setCanvas } = useEcharts(() => option.value)
</script>

<template>
  <figure class="chart-figure">
    <figcaption>{{ chart.title }}</figcaption>
    <p class="chart__note">
      {{ chart.caption }}
      <InfoTip v-if="note" :text="note" topic="this curve" />
    </p>
    <div class="chart chart--part2-curve">
      <div :ref="setCanvas" class="chart__canvas"></div>
    </div>
  </figure>
</template>
