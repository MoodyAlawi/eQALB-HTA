<script setup lang="ts">
/**
 * Interactive cost-effectiveness plane: the PSA cloud, the mean of the
 * iterations, the deterministic base case and the willingness-to-pay threshold
 * line. Moving the threshold in the assumptions panel re-draws the line, which is
 * what makes the four quadrants interpretable (more QALYs and more cost, cheaper
 * and better, dominated, and cheaper with fewer QALYs).
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import type { PsaCloudPoint } from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro, formatNumber, formatQaly, isNum } from '../../format'

const props = withDefaults(
  defineProps<{
    cloud: PsaCloudPoint[]
    wtp: number
    /** Mean of the PSA iterations, when a result exists. */
    mean?: { cost: number | null; qalys: number | null } | null
    baseCase?: { cost: number | null; qalys: number | null } | null
  }>(),
  { mean: null, baseCase: null },
)

const palette = useChartPalette()

interface PlottedPoint {
  simulation: number
  qalys: number
  cost: number
  icer: number | null
}

const points = computed<PlottedPoint[]>(() =>
  props.cloud
    .filter((point) => isNum(point.incremental_qalys) && isNum(point.incremental_cost))
    .map((point) => ({
      simulation: point.simulation,
      qalys: point.incremental_qalys as number,
      cost: point.incremental_cost as number,
      icer: point.icer,
    })),
)

function paddedExtent(values: number[], includeZero = true): [number, number] {
  const candidates = includeZero ? [...values, 0] : values
  if (candidates.length === 0) return [-1, 1]
  let min = Math.min(...candidates)
  let max = Math.max(...candidates)
  if (min === max) {
    const pad = Math.abs(min) > 0 ? Math.abs(min) * 0.1 : 1
    min -= pad
    max += pad
  }
  const pad = (max - min) * 0.08
  return [min - pad, max + pad]
}

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const plotted = points.value
  const baseCost = props.baseCase?.cost ?? null
  const baseQalys = props.baseCase?.qalys ?? null
  const meanCost = props.mean?.cost ?? null
  const meanQalys = props.mean?.qalys ?? null

  const [xMin, xMax] = paddedExtent(plotted.map((point) => point.qalys))
  const [yMin, yMax] = paddedExtent(plotted.map((point) => point.cost))

  const threshold = props.wtp
  const lineAt = (x: number) => threshold * x
  const costEffectiveRegion: [number, number][] = [
    [xMin, lineAt(xMin)],
    [xMax, lineAt(xMax)],
    [xMax, yMax],
    [xMin, yMax],
  ]

  const series: unknown[] = [
    {
      // Half-plane where the net monetary benefit is positive: Î”Cost <= WTP x Î”QALYs.
      name: `Cost-effective at ${formatEuro(threshold)}/QALY`,
      type: 'line',
      data: costEffectiveRegion,
      silent: true,
      showSymbol: false,
      lineStyle: { opacity: 0 },
      areaStyle: { color: palette.value.isDark ? 'rgba(76, 175, 125, 0.14)' : 'rgba(46, 125, 79, 0.10)' },
      z: 1,
      tooltip: { show: false },
      // Zero-crossing guides, so the four quadrants are readable at a glance.
      markLine: {
        silent: true,
        symbol: 'none',
        label: { show: false },
        lineStyle: { color: palette.value.border, width: 1 },
        z: 1,
        data: [{ xAxis: 0 }, { yAxis: 0 }],
      },
    },
    {
      name: 'Threshold line',
      type: 'line',
      data: [
        [xMin, lineAt(xMin)],
        [xMax, lineAt(xMax)],
      ],
      silent: true,
      showSymbol: false,
      lineStyle: { color: palette.value.positive, width: 1.5, type: 'dashed' },
      z: 2,
      tooltip: { show: false },
    },
    {
      name: 'Simulated iterations',
      type: 'scatter',
      data: plotted.map((point) => [point.qalys, point.cost, point.simulation, point.icer]),
      symbolSize: 7,
      itemStyle: {
        color: palette.value.isDark ? 'rgba(127, 209, 216, 0.55)' : 'rgba(23, 107, 115, 0.45)',
        borderColor: palette.value.accent,
        borderWidth: 0.5,
      },
      z: 3,
      tooltip: {
        formatter: (params: unknown) => {
          const value = (params as { value: [number, number, number, number | null] }).value
          return [
            `<strong>Simulation ${formatNumber(value[2])}</strong>`,
            `Incremental QALYs: ${formatQaly(value[0])}`,
            `Incremental cost: ${formatEuro(value[1])}`,
            `ICER: ${isNum(value[3]) ? formatEuro(value[3]) : 'not interpretable'}`,
          ].join('<br/>')
        },
      },
    },
  ]

  if (isNum(meanQalys) && isNum(meanCost)) {
    series.push({
      name: 'Mean of iterations',
      type: 'scatter',
      data: [[meanQalys, meanCost, 'Mean']],
      symbol: 'diamond',
      symbolSize: 20,
      // Hollow, so the deterministic marker and the cloud stay visible when the
      // mean coincides with them.
      itemStyle: { color: 'transparent', borderColor: palette.value.accent, borderWidth: 2 },
      z: 6,
      tooltip: {
        formatter: () =>
          [
            '<strong>Mean of iterations</strong>',
            `Mean incremental QALYs: ${formatQaly(meanQalys)}`,
            `Mean incremental cost: ${formatEuro(meanCost)}`,
          ].join('<br/>'),
      },
    })
  }

  if (isNum(baseQalys) && isNum(baseCost)) {
    series.push({
      name: 'Deterministic base case',
      type: 'scatter',
      data: [[baseQalys, baseCost, 'Base case']],
      symbolSize: 14,
      itemStyle: { color: palette.value.series[1], borderColor: palette.value.panel, borderWidth: 2 },
      z: 5,
      tooltip: {
        formatter: () =>
          [
            '<strong>Deterministic base case</strong>',
            `Incremental QALYs: ${formatQaly(baseQalys)}`,
            `Incremental cost: ${formatEuro(baseCost)}`,
          ].join('<br/>'),
      },
    })
  }

  return {
    ...base,
    // The legend names up to five series and wraps to several rows at phone
    // widths, so it is given a band of its own above the plot: the grid starts
    // below the tallest the wrapped legend gets, and the two cannot run into
    // each other at any width.
    grid: { left: 70, right: 24, top: 104, bottom: 56, containLabel: false },
    legend: {
      top: 6,
      left: 'center',
      icon: 'circle',
      itemGap: 10,
      textStyle: { color: palette.value.text, fontSize: 11 },
    },
    tooltip: { ...base.tooltip, trigger: 'item' },
    xAxis: {
      type: 'value',
      name: 'Incremental QALYs',
      nameLocation: 'middle',
      nameGap: 30,
      min: xMin,
      max: xMax,
      ...base.axisStyle,
    },
    yAxis: {
      type: 'value',
      name: 'Incremental cost (EUR)',
      nameLocation: 'middle',
      nameGap: 52,
      min: yMin,
      max: yMax,
      ...base.axisStyle,
      axisLabel: { color: palette.value.muted, formatter: (value: number) => formatEuro(value) },
    },
    series,
  }
})

const { setCanvas } = useEcharts(() => option.value)
</script>

<template>
  <div class="chart">
    <div :ref="setCanvas" class="chart__canvas"></div>
    <p v-if="points.length === 0" class="chart__empty">
      No simulated iterations to show yet. Run the PSA on this tab.
    </p>
  </div>
</template>
