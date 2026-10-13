<script setup lang="ts">
/**
 * Simulated Kaplan-Meier curves for both arms, with the 95% confidence band the
 * R estimator produced. The confidence interval is drawn as a filled band (the
 * upper edge masks the fill), which keeps the two arms readable when the bands
 * overlap.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import type { KmStep } from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { isNum } from '../../format'

const props = defineProps<{
  steps: KmStep[]
  followupYears: number
}>()

const palette = useChartPalette()

const GROUPS = ['Usual care', 'eQalb plus usual care'] as const

function seriesFor(group: string, pick: (step: KmStep) => number | null) {
  return props.steps
    .filter((step) => step.treatment === group)
    .filter((step) => isNum(step.time_years) && isNum(pick(step)))
    .map((step) => [step.time_years as number, pick(step) as number])
}

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const armColor = (group: string) =>
    group === GROUPS[0] ? palette.value.control : palette.value.intervention

  const series: unknown[] = []

  for (const group of GROUPS) {
    const color = armColor(group)
    // Lower edge of the band, filled downwards.
    series.push({
      name: `${group} 95% CI`,
      type: 'line',
      step: 'end',
      showSymbol: false,
      data: seriesFor(group, (step) => step.lower),
      lineStyle: { color, width: 0.8, opacity: 0.55, type: 'dashed' },
      areaStyle: { color: palette.value.band, origin: 'start' },
      silent: true,
      legendHoverLink: false,
      z: 1,
    })
    // Upper edge filled in the panel colour, which leaves only the band visible.
    series.push({
      name: `${group} 95% CI upper`,
      type: 'line',
      step: 'end',
      showSymbol: false,
      data: seriesFor(group, (step) => step.upper),
      lineStyle: { color, width: 0.8, opacity: 0.55, type: 'dashed' },
      areaStyle: { color: palette.value.panel, origin: 'start' },
      silent: true,
      legendHoverLink: false,
      z: 2,
    })
    series.push({
      name: group,
      type: 'line',
      step: 'end',
      showSymbol: false,
      data: seriesFor(group, (step) => step.survival),
      lineStyle: { color, width: 2.2 },
      itemStyle: { color },
      z: 3,
      tooltip: {
        formatter: (params: unknown) => {
          const value = (params as { value: [number, number] }).value
          return `${group}<br/>Year ${value[0].toFixed(2)}<br/>Event-free: ${(value[1] * 100).toFixed(1)}%`
        },
      },
    })
  }

  return {
    ...base,
    grid: { left: 64, right: 24, top: 40, bottom: 56, containLabel: false },
    legend: {
      top: 6,
      textStyle: { color: palette.value.text },
      icon: 'roundRect',
      // The band helper series are not legend entries.
      data: [...GROUPS],
    },
    tooltip: { ...base.tooltip, trigger: 'item' },
    xAxis: {
      type: 'value',
      name: 'Years since start of treatment',
      nameLocation: 'middle',
      nameGap: 30,
      min: 0,
      max: props.followupYears,
      ...base.axisStyle,
    },
    yAxis: {
      type: 'value',
      name: 'Event-free survival',
      nameLocation: 'middle',
      nameGap: 46,
      min: 0.5,
      max: 1,
      ...base.axisStyle,
      axisLabel: {
        color: palette.value.muted,
        formatter: (value: number) => `${Math.round(value * 100)}%`,
      },
    },
    series,
  }
})

const { setCanvas } = useEcharts(() => option.value)
</script>

<template>
  <div class="chart chart--tall">
    <div :ref="setCanvas" class="chart__canvas"></div>
    <p v-if="steps.length === 0" class="chart__empty">
      No survival simulation to show yet. Run the analysis on this tab.
    </p>
  </div>
</template>
