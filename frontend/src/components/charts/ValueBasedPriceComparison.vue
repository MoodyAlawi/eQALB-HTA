<script setup lang="ts">
/**
 * Current annual price against the maximum acceptable annual price.
 *
 * Every value drawn is R's: the two prices and the status band that colours the
 * current-price bar. Nothing is compared, classified or coloured in TypeScript —
 * the headroom R reports between the two prices, and R's own wording for a run
 * in which it identified no maximum price, are stated by the information button
 * beside the chart header, which the panel renders from the same response.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro } from '../../format'

const props = defineProps<{
  /** The price the analysis ran at, as R returned it. */
  currentPrice: number | null
  /** The highest annual price R identified, or null when it identified none. */
  maxAcceptablePrice: number | null
  /** R's band for the current price; drives the colour, never a client rule. */
  status: string
}>()

const palette = useChartPalette()

/**
 * R's status band, mapped to the palette tone the app already uses for statuses.
 * "Not available" and an unrecognised band fall back to the muted tone, so a
 * missing result never looks like a decision.
 */
const barColour = computed(() => {
  if (props.status === 'Green') return palette.value.positive
  if (props.status === 'Red') return palette.value.negative
  return palette.value.neutral
})

/** The axis covers zero and both prices, so the bars stay comparable. */
const axisMax = computed(() => {
  const values = [props.currentPrice ?? 0, props.maxAcceptablePrice ?? 0]
  return Math.max(...values, 1) * 1.25
})

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const current = props.currentPrice ?? 0
  const maximum = props.maxAcceptablePrice ?? 0

  return {
    ...base,
    grid: { left: 78, right: 96, top: 20, bottom: 44, containLabel: false },
    tooltip: {
      ...base.tooltip,
      trigger: 'item',
      formatter: (params: unknown) => {
        const item = params as { dataIndex: number }
        const label =
          item.dataIndex === 0 ? 'Maximum acceptable annual price' : 'Current annual price'
        const value = item.dataIndex === 0 ? maximum : current
        return [
          `<strong>${label}</strong>`,
          `${formatEuro(value, 2)} per active user per year`,
          `R's status for the current price: ${props.status}`,
        ].join('<br/>')
      },
    },
    xAxis: {
      type: 'value',
      ...base.axisStyle,
      min: 0,
      max: axisMax.value,
      axisLabel: { color: palette.value.muted, formatter: (value: number) => formatEuro(value, 0) },
    },
    yAxis: {
      type: 'category',
      data: ['Maximum acceptable', 'Current'],
      ...base.axisStyle,
      splitLine: { show: false },
      axisLabel: { color: palette.value.text },
    },
    series: [
      {
        name: 'Annual price per active user',
        type: 'bar',
        barMaxWidth: 30,
        data: [
          {
            value: maximum,
            itemStyle: { color: palette.value.accent, borderRadius: 3 },
            label: {
              show: true,
              position: 'right',
              formatter: () => formatEuro(maximum, 2),
              color: palette.value.text,
            },
          },
          {
            value: current,
            itemStyle: { color: barColour.value, borderRadius: 3 },
            label: {
              show: true,
              position: 'right',
              formatter: () => formatEuro(current, 2),
              color: palette.value.text,
            },
          },
        ],
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
