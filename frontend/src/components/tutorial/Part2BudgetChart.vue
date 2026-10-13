<script setup lang="ts">
/**
 * The Part 2 budget-impact chart.
 *
 * Every value is R's: the annual net budget impact and the cumulative position per
 * year, the year labels, the axis names, the legend text and the two series. This
 * component plots the rows R returned and decides nothing about them — not the
 * sign, not the colour rule, not the total.
 *
 * Marks carry R's own per-year key, and the tooltip looks the hovered year up by
 * that key rather than by the mark's position, so a tooltip can never describe a
 * different year's numbers than the bar it belongs to.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import type { Part2BudgetResult, Part2BudgetRow } from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro } from '../../format'

const props = defineProps<{ budget: Part2BudgetResult }>()

const palette = useChartPalette()

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const rows = props.budget.rows
  const chart = props.budget.strings.chart
  const byKey = new Map<string, Part2BudgetRow>(rows.map((row) => [row.key, row]))

  return {
    ...base,
    grid: { left: 84, right: 78, top: 48, bottom: 46, containLabel: false },
    legend: { top: 4, textStyle: { color: palette.value.text }, icon: 'roundRect' },
    tooltip: {
      ...base.tooltip,
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: (params: unknown) => {
        const list = params as { name?: string; seriesName?: string }[]
        if (!Array.isArray(list) || list.length === 0) return ''
        // R's own year key, not the mark's index.
        const row = list[0]?.name ? byKey.get(list[0].name) : undefined
        if (!row) return ''
        return [
          `<strong>Year ${row.year}</strong>`,
          `Active users: ${row.active_users_display}`,
          `Net budget impact: ${row.net_budget_impact_display}`,
          `Cumulative: ${row.cumulative_display}`,
        ].join('<br/>')
      },
    },
    xAxis: {
      type: 'category',
      data: rows.map((row) => row.key),
      ...base.axisStyle,
      splitLine: { show: false },
      axisLabel: {
        color: palette.value.muted,
        formatter: (value: string) => value.replace('year-', 'Year '),
      },
    },
    yAxis: [
      {
        type: 'value',
        name: chart.y_label,
        nameLocation: 'middle',
        nameGap: 62,
        ...base.axisStyle,
        axisLabel: {
          color: palette.value.muted,
          formatter: (value: number) => formatEuro(value, 0),
        },
      },
      {
        type: 'value',
        name: chart.cumulative_label,
        nameLocation: 'middle',
        nameGap: 60,
        ...base.axisStyle,
        splitLine: { show: false },
        axisLabel: {
          color: palette.value.muted,
          formatter: (value: number) => formatEuro(value, 0),
        },
      },
    ],
    series: [
      {
        name: chart.annual_label,
        type: 'bar',
        data: rows.map((row) => ({
          name: row.key,
          value: row.net_budget_impact,
          itemStyle: {
            // The sign of R's own value decides the two colours; R's labels name
            // them.
            color:
              row.net_budget_impact <= 0 ? palette.value.positive : palette.value.negative,
            borderRadius: 3,
          },
        })),
        barMaxWidth: 44,
      },
      {
        name: chart.cumulative_label,
        type: 'line',
        yAxisIndex: 1,
        data: rows.map((row) => ({ name: row.key, value: row.cumulative_budget_impact })),
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
  <figure class="chart-figure">
    <figcaption>{{ budget.strings.chart.title }}</figcaption>
    <p class="chart__note">{{ budget.strings.chart.caption }}</p>
    <div class="chart">
      <div :ref="setCanvas" class="chart__canvas"></div>
    </div>
  </figure>
</template>
