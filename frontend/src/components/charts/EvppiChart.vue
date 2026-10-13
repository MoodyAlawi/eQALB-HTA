<script setup lang="ts">
/**
 * EVPPI per patient by parameter, one horizontal bar per row of the table the API
 * returned, in that exact order: R ranks the table itself, and this component
 * neither sorts nor re-ranks it. A dashed line marks the EVPI the same response
 * carries, so each bar can be read against the value of removing all uncertainty.
 *
 * A clamped estimate keeps the qualifier the table already displays in its title
 * attribute, carried into the tooltip unchanged.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import type { EvppiRow } from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { formatEuro, isNum } from '../../format'

const props = defineProps<{
  /** Rows as the response returned them, in the response's own order. */
  rows: EvppiRow[]
  /** R's EVPI for the same run, drawn as the reference line. */
  evpi: number | null
}>()

const palette = useChartPalette()

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  // ECharts draws categories bottom-up, so reverse only for display; every value
  // and label still comes from the row at its own index.
  const plotted = [...props.rows].reverse()

  return {
    ...base,
    // containLabel sizes the parameter column from its own labels, and the media
    // query narrows that column on a phone, so the plot area stays usable at 390px
    // instead of being eaten by a fixed margin.
    grid: { left: 8, right: 64, top: 20, bottom: 44, containLabel: true },
    tooltip: {
      ...base.tooltip,
      trigger: 'item',
      formatter: (params: unknown) => {
        const item = params as { dataIndex: number }
        const row = plotted[item.dataIndex]
        if (!row) return ''
        const lines = [
          `<strong>${row.parameter}</strong>`,
          `EVPPI per patient: ${formatEuro(row.evppi, 2)}`,
          `Unclamped estimate: ${formatEuro(row.evppi_raw, 2)}`,
        ]
        if (row.clamped) lines.push('Negative regression estimate, reported as zero')
        return lines.join('<br/>')
      },
    },
    xAxis: {
      type: 'value',
      ...base.axisStyle,
      axisLabel: { color: palette.value.muted, formatter: (value: number) => formatEuro(value, 2) },
    },
    yAxis: {
      type: 'category',
      data: plotted.map((row) => row.parameter),
      ...base.axisStyle,
      splitLine: { show: false },
      axisLabel: { color: palette.value.text, width: 170, overflow: 'break' },
    },
    series: [
      {
        name: 'EVPPI per patient',
        type: 'bar',
        barMaxWidth: 18,
        data: plotted.map((row) => (isNum(row.evppi) ? row.evppi : '-')),
        itemStyle: { color: palette.value.accent, borderRadius: 2 },
        markLine: {
          silent: true,
          symbol: 'none',
          label: {
            formatter: `EVPI ${formatEuro(props.evpi, 2)}`,
            color: palette.value.text,
            position: 'insideEndTop',
          },
          lineStyle: { color: palette.value.series[1], type: 'dashed', width: 1.5 },
          data: isNum(props.evpi) ? [{ xAxis: props.evpi }] : [],
        },
      },
    ],
    // Narrow viewports: a shorter parameter column and fewer value ticks, so the
    // bars and their labels both stay readable on a phone.
    media: [
      {
        query: { maxWidth: 520 },
        option: {
          grid: { right: 40 },
          xAxis: { splitNumber: 3 },
          yAxis: { axisLabel: { width: 92 } },
        },
      },
    ],
  }
})

const { setCanvas } = useEcharts(() => option.value)
</script>

<template>
  <div class="chart chart--tall">
    <div :ref="setCanvas" class="chart__canvas"></div>
    <p v-if="rows.length === 0" class="chart__empty">
      No parameter-level decomposition to show for this run.
    </p>
  </div>
</template>
