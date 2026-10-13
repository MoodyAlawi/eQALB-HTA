<script setup lang="ts">
/**
 * The Step-1 cost-effectiveness plane.
 *
 * The two points, their labels and the chart's title, subtitle and axis names
 * all come from R's response; this component only turns them into a chart. The
 * axis extents are chart geometry (both axes must include zero, with padding so
 * a point never sits on the frame), not an economic value, so no model number is
 * derived here. The arrow from the origin to the eQalb point shows the increment
 * the ICER divides, exactly as the reference figure does.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import type { TutorialCe } from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro, formatQaly } from '../../format'

const props = defineProps<{ chart: TutorialCe['chart'] }>()

const palette = useChartPalette()

/** Extent over the points, padded by a fraction of its own span (with a floor),
 * so a point never sits on the frame and zero is always inside the view. */
function limits(values: number[], padFraction: number, minPad: number): [number, number] {
  const low = Math.min(...values)
  const high = Math.max(...values)
  const pad = Math.max((high - low) * padFraction, minPad)
  return [low - pad, high + pad]
}

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const points = props.chart.points
  const qalys = points.map((point) => point.incremental_qalys)
  const costs = points.map((point) => point.incremental_cost)
  // Both series include the origin, so the axis ranges bracket zero.
  const xExtent = limits([0, ...qalys], 0.4, 0.001)
  const yExtent = limits([0, ...costs], 0.2, 1)

  return {
    ...base,
    grid: { left: 84, right: 30, top: 52, bottom: 52, containLabel: false },
    tooltip: {
      ...base.tooltip,
      trigger: 'item',
      formatter: (params: unknown) => {
        const item = params as { dataIndex: number }
        const point = points[item.dataIndex]
        if (!point) return ''
        return [
          `<strong>${point.label}</strong>`,
          `Incremental QALYs: ${formatQaly(point.incremental_qalys, 5)}`,
          `Incremental cost: ${formatEuro(point.incremental_cost, 2)}`,
        ].join('<br/>')
      },
    },
    xAxis: {
      type: 'value',
      name: props.chart.x_label,
      nameLocation: 'middle',
      nameGap: 30,
      min: xExtent[0],
      max: xExtent[1],
      ...base.axisStyle,
      axisLabel: { color: palette.value.muted, formatter: (value: number) => formatQaly(value, 3) },
    },
    yAxis: {
      type: 'value',
      name: props.chart.y_label,
      nameLocation: 'middle',
      nameGap: 68,
      min: yExtent[0],
      max: yExtent[1],
      ...base.axisStyle,
      axisLabel: { color: palette.value.muted, formatter: (value: number) => formatEuro(value, 0) },
    },
    series: [
      {
        name: props.chart.title,
        type: 'scatter',
        data: points.map((point, index) => ({
          value: [point.incremental_qalys, point.incremental_cost],
          itemStyle: { color: index === 0 ? palette.value.negative : palette.value.positive },
          symbolSize: 12,
        })),
        label: {
          show: true,
          position: 'right',
          formatter: (params: { dataIndex: number }) => points[params.dataIndex]?.label ?? '',
          color: palette.value.text,
        },
      },
      {
        // The increment the ICER divides, drawn from usual care to eQalb.
        name: 'Increment',
        type: 'line',
        data: [
          [points[0]?.incremental_qalys ?? 0, points[0]?.incremental_cost ?? 0],
          [points[1]?.incremental_qalys ?? 0, points[1]?.incremental_cost ?? 0],
        ],
        symbol: ['none', 'arrow'],
        symbolSize: 12,
        lineStyle: { color: palette.value.series[0], width: 2 },
        itemStyle: { color: palette.value.series[0] },
        tooltip: { show: false },
        silent: true,
      },
    ],
  }
})

const { setCanvas } = useEcharts(() => option.value)
</script>

<template>
  <figure class="chart-figure">
    <figcaption>{{ chart.title }}</figcaption>
    <p class="chart__note">{{ chart.subtitle }}</p>
    <div class="chart chart--tall">
      <div :ref="setCanvas" class="chart__canvas"></div>
    </div>
  </figure>
</template>
