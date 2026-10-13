<script setup lang="ts">
/**
 * EVPI as it is defined: two R-provided expected net monetary benefits, with
 * current evidence and with perfect information, and the difference between them
 * which R returns as the EVPI.
 *
 * The three figures are the response's own `expected_nmb_current`,
 * `expected_nmb_perfect` and `evpi`. Nothing is compared, ranked or recomputed
 * here: the gap label prints the EVPI R returned, and the tooltip prints R's
 * `mean_nmb` and the threshold the run used.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro, formatThreshold, isNum } from '../../format'

const props = defineProps<{
  /** R's expected NMB with current evidence (`max(mean_nmb, 0)` in R). */
  expectedCurrent: number | null
  /** R's expected NMB with perfect information. */
  expectedPerfect: number | null
  /** R's EVPI, the difference the model reports. */
  evpi: number | null
  /** R's mean incremental NMB, shown in the tooltip as returned. */
  meanNmb: number | null
  /** The threshold the run used. */
  wtp: number
}>()

const palette = useChartPalette()

const hasValues = computed(() => isNum(props.expectedCurrent) && isNum(props.expectedPerfect))

/** Bars sit above or below zero, so the axis covers zero and both values. */
const axis = computed<{ min: number; max: number }>(() => {
  const values = [0, props.expectedCurrent ?? 0, props.expectedPerfect ?? 0]
  const min = Math.min(...values)
  const max = Math.max(...values)
  const pad = (max - min) * 0.12 || 1
  return { min: min - pad, max: max + pad }
})

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const current = props.expectedCurrent ?? 0
  const perfect = props.expectedPerfect ?? 0

  return {
    ...base,
    grid: { left: 84, right: 96, top: 20, bottom: 44, containLabel: false },
    tooltip: {
      ...base.tooltip,
      trigger: 'item',
      formatter: (params: unknown) => {
        const item = params as { dataIndex: number }
        const label = item.dataIndex === 0 ? 'Current evidence' : 'Perfect information'
        return [
          `<strong>${label}</strong>`,
          `Expected net monetary benefit: ${formatEuro(
            item.dataIndex === 0 ? current : perfect,
            2,
          )}`,
          `Mean incremental net monetary benefit: ${formatEuro(props.meanNmb, 2)}`,
          `At ${formatThreshold(props.wtp)}`,
        ].join('<br/>')
      },
    },
    xAxis: {
      type: 'value',
      ...base.axisStyle,
      min: axis.value.min,
      max: axis.value.max,
      axisLabel: { color: palette.value.muted, formatter: (value: number) => formatEuro(value, 2) },
    },
    yAxis: {
      type: 'category',
      data: ['Perfect information', 'Current evidence'],
      ...base.axisStyle,
      splitLine: { show: false },
      axisLabel: { color: palette.value.text },
    },
    series: [
      {
        name: 'Expected net monetary benefit',
        type: 'bar',
        barMaxWidth: 34,
        data: [
          {
            value: current,
            itemStyle: { color: palette.value.neutral, borderRadius: 3 },
            label: {
              show: true,
              position: 'right',
              formatter: () => formatEuro(current, 2),
              color: palette.value.text,
            },
          },
          {
            value: perfect,
            itemStyle: { color: palette.value.accent, borderRadius: 3 },
            label: {
              show: true,
              position: 'right',
              formatter: () => formatEuro(perfect, 2),
              color: palette.value.text,
            },
          },
        ],
        markLine: {
          silent: true,
          symbol: 'none',
          label: { show: false },
          lineStyle: { color: palette.value.border, width: 1 },
          data: [{ xAxis: 0 }],
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
    <p v-if="!hasValues" class="chart__empty">No value-of-information result to show.</p>
  </div>
</template>
