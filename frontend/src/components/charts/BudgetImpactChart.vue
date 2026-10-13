<script setup lang="ts">
/**
 * Budget impact by year: the net budget impact per year as bars (cost increases
 * above the axis, savings below it) and the cumulative position as a line.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import type { BudgetImpactRow } from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro, formatEuroCompact, isNum } from '../../format'

const props = defineProps<{
  rows: BudgetImpactRow[]
}>()

const palette = useChartPalette()

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const rows = props.rows
  const labels = rows.map((row) => `Year ${row.year}`)

  return {
    ...base,
    grid: { left: 76, right: 76, top: 44, bottom: 40, containLabel: false },
    legend: { top: 6, textStyle: { color: palette.value.text }, icon: 'roundRect' },
    tooltip: {
      ...base.tooltip,
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: (params: unknown) => {
        const list = params as { seriesName: string; value: number; dataIndex: number }[]
        if (!Array.isArray(list) || list.length === 0) return ''
        const row = rows[list[0].dataIndex]
        if (!row) return ''
        return [
          `<strong>Year ${row.year}</strong>`,
          `Active users: ${row.active_users ?? 'â€”'}`,
          `Gross intervention cost: ${formatEuro(row.gross_intervention_cost)}`,
          `Implementation cost: ${formatEuro(row.implementation_cost)}`,
          `Healthcare savings: ${formatEuro(row.healthcare_savings)}`,
          `Avoided-event savings: ${formatEuro(row.avoided_event_savings)}`,
          `Net budget impact: ${formatEuro(row.net_budget_impact)}`,
          `Cumulative: ${formatEuro(row.cumulative_budget_impact)}`,
        ].join('<br/>')
      },
    },
    xAxis: { type: 'category', data: labels, ...base.axisStyle, splitLine: { show: false } },
    yAxis: [
      {
        type: 'value',
        name: 'Per year (EUR)',
        nameLocation: 'middle',
        nameGap: 60,
        ...base.axisStyle,
        axisLabel: { color: palette.value.muted, formatter: (value: number) => formatEuroCompact(value) },
      },
      {
        type: 'value',
        name: 'Cumulative (EUR)',
        nameLocation: 'middle',
        nameGap: 58,
        ...base.axisStyle,
        splitLine: { show: false },
        axisLabel: { color: palette.value.muted, formatter: (value: number) => formatEuroCompact(value) },
      },
    ],
    series: [
      {
        name: 'Net budget impact (per year)',
        type: 'bar',
        data: rows.map((row) => ({
          value: row.net_budget_impact,
          itemStyle: {
            color:
              isNum(row.net_budget_impact) && row.net_budget_impact <= 0
                ? palette.value.positive
                : palette.value.negative,
            borderRadius: 3,
          },
        })),
        barMaxWidth: 44,
      },
      {
        name: 'Cumulative net budget impact',
        type: 'line',
        yAxisIndex: 1,
        data: rows.map((row) => row.cumulative_budget_impact),
        symbol: 'circle',
        symbolSize: 7,
        lineStyle: { color: palette.value.series[1], width: 2 },
        itemStyle: { color: palette.value.series[1] },
      },
    ],
  }
})

const { setCanvas } = useEcharts(() => option.value)
</script>

<template>
  <div class="chart">
    <div :ref="setCanvas" class="chart__canvas"></div>
    <p v-if="rows.length === 0" class="chart__empty">
      No budget-impact results to show yet. Run the analysis on this tab.
    </p>
  </div>
</template>
