<script setup lang="ts">
/**
 * Cost-effectiveness acceptability curve: the proportion of PSA iterations that
 * are cost-effective at each threshold, as the R model computed it. The
 * reference threshold from the assumptions panel is marked with a dot on the
 * curve, and the stated probability is always read from the curve, never
 * estimated here — the panel's information button states the same figure,
 * because both read it through `probabilityAtThreshold`.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import type { CeacPoint } from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro, formatPercent, isNum } from '../../format'
import { probabilityAtThreshold } from './ceac'

const props = defineProps<{
  ceac: CeacPoint[]
  wtp: number
}>()

const palette = useChartPalette()

/** Probability at the reference threshold, read off the returned curve. */
const atThreshold = computed<number | null>(() => probabilityAtThreshold(props.ceac, props.wtp))

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const series = props.ceac
    .filter((point) => isNum(point.probability))
    .map((point) => [point.wtp, (point.probability as number) * 100])

  return {
    ...base,
    grid: { left: 64, right: 24, top: 28, bottom: 56, containLabel: false },
    tooltip: {
      ...base.tooltip,
      trigger: 'axis',
      valueFormatter: (value: number) => `${value.toFixed(1)}%`,
      formatter: (params: unknown) => {
        const list = params as { value: [number, number] }[]
        if (!Array.isArray(list) || list.length === 0) return ''
        const [threshold, probability] = list[0].value
        return `Threshold ${formatEuro(threshold)}/QALY<br/>Cost-effective in ${probability.toFixed(1)}% of iterations`
      },
    },
    xAxis: {
      type: 'value',
      name: 'Willingness to pay (EUR/QALY)',
      nameLocation: 'middle',
      nameGap: 30,
      min: 0,
      ...base.axisStyle,
      axisLabel: { color: palette.value.muted, formatter: (value: number) => formatEuro(value) },
    },
    yAxis: {
      type: 'value',
      name: 'Probability cost-effective (%)',
      nameLocation: 'middle',
      nameGap: 42,
      min: 0,
      max: 100,
      ...base.axisStyle,
    },
    series: [
      {
        name: 'Probability cost-effective',
        type: 'line',
        data: series,
        showSymbol: false,
        smooth: false,
        lineStyle: { color: palette.value.accent, width: 2 },
        areaStyle: {
          color: palette.value.isDark ? 'rgba(127, 209, 216, 0.14)' : 'rgba(23, 107, 115, 0.10)',
        },
        markLine: {
          silent: true,
          symbol: 'none',
          label: {
            formatter: `Reference threshold (${formatEuro(props.wtp)})`,
            color: palette.value.text,
            position: 'insideEndTop',
          },
          lineStyle: { color: palette.value.series[1], type: 'dashed', width: 1.5 },
          data: [{ xAxis: props.wtp }],
        },
      },
      {
        // The point of the curve at the selected threshold, so the probability
        // the panel reports is visible where it is read.
        name: 'At the reference threshold',
        type: 'scatter',
        data: atThreshold.value === null ? [] : [[props.wtp, (atThreshold.value as number) * 100]],
        symbolSize: 11,
        itemStyle: {
          color: palette.value.series[1],
          borderColor: palette.value.panel,
          borderWidth: 2,
        },
        z: 5,
        label: {
          show: true,
          distance: 8,
          // Above the dot unless the curve is near the top of the axes, where the
          // label would be clipped.
          position: (atThreshold.value ?? 0) > 0.85 ? 'bottom' : 'top',
          formatter: () => formatPercent(atThreshold.value),
          color: palette.value.text,
        },
        tooltip: {
          formatter: () =>
            [
              `<strong>${formatEuro(props.wtp)}/QALY</strong>`,
              `${formatPercent(atThreshold.value)} of iterations cost-effective`,
            ].join('<br/>'),
        },
      },
    ],
  }
})

const { setCanvas } = useEcharts(() => option.value)
</script>

<template>
  <div class="chart">
    <div :ref="setCanvas" class="chart__canvas"></div>
  </div>
</template>
