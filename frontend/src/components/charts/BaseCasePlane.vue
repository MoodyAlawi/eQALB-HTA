<script setup lang="ts">
/**
 * Deterministic cost-effectiveness plane for the base case.
 *
 * Usual care sits at the origin by definition; the arrow, the eQalb point and
 * the dashed willingness-to-pay ray are the incremental cost, the incremental
 * QALYs and the threshold the API response carries. The ray is named directly,
 * and the ICER annotation the chart carries is repeated in the point's tooltip,
 * while the explanation of the two sides of the ray sits in the information
 * button beside the chart header, so no shaded area competes with the two
 * points.
 *
 * No economic value is derived here: the axis padding, the clipped ray and the
 * label anchor are chart geometry, and the annotation repeats the metric card's
 * wording through the same format helpers, so the two cannot disagree. A
 * non-estimable ICER is described in words and draws no value.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { costEffectivenessLabel, describeIcer, formatEuro, formatQaly, isNum } from '../../format'

const props = defineProps<{
  /** Incremental cost, EUR per person, as the response returned it. */
  cost: number | null
  /** Incremental QALYs per person, as the response returned it. */
  qalys: number | null
  /** The ratio, or null when R reported it as not interpretable. */
  icer: number | null
  /** The threshold the result was produced at, as the response carries it. */
  wtp: number
  costEffective: boolean | null
}>()

type Point = [number, number]

/** The increment arrow stops this fraction of the way to the marker, leaving room
 * for the open arrow head to be visible beside it. */
const ARROW_STOP = 0.86

const palette = useChartPalette()

const hasPoint = computed(() => isNum(props.cost) && isNum(props.qalys))

/** Extent covering zero and the model's point, padded so neither sits on the frame. */
function paddedExtent(value: number): [number, number] {
  const min = Math.min(0, value)
  let max = Math.max(0, value)
  if (min === max) max = min + (min === 0 ? 1 : Math.abs(min) * 0.2)
  const pad = (max - min) * 0.15
  return [min - pad, max + pad]
}

/**
 * The part of the threshold ray the label is anchored to, as a fraction of the
 * clipped segment. Kept short of the axis edge so the text stays inside the
 * plot box at every width.
 */
const RAY_LABEL_AT = 0.72

/**
 * The threshold ray, clipped to the box so it never overhangs the axes.
 */
function clippedRay(
  xMin: number,
  xMax: number,
  yMin: number,
  yMax: number,
  wtp: number,
): [Point, Point] {
  const startY = wtp * xMin
  const start: Point = startY >= yMin ? [xMin, startY] : [yMin / wtp, yMin]
  const endY = wtp * xMax
  const end: Point = endY <= yMax ? [xMax, endY] : [yMax / wtp, yMax]
  return [start, end]
}

const annotation = computed(() => {
  const ratio = describeIcer(props.icer, props.cost, props.qalys)
  const icerPart = isNum(props.icer) ? `ICER ${ratio} per QALY` : ratio
  return `${icerPart} · ${costEffectivenessLabel(props.costEffective, props.wtp)}.`
})

/** The ray's own label, using the threshold the response was produced at. */
const thresholdLabel = computed(() => `${formatEuro(props.wtp)}/QALY threshold`)

const option = computed<EChartsCoreOption>(() => {
  const base = chartBase(palette.value)
  const cost = isNum(props.cost) ? props.cost : 0
  const qalys = isNum(props.qalys) ? props.qalys : 0
  const threshold = props.wtp

  const [xMin, xMax] = paddedExtent(qalys)
  const [yMin, yMax] = paddedExtent(cost)
  const [rayStart, rayEnd] = clippedRay(xMin, xMax, yMin, yMax, threshold)
  const labelAnchor: Point = [
    rayStart[0] + RAY_LABEL_AT * (rayEnd[0] - rayStart[0]),
    rayStart[1] + RAY_LABEL_AT * (rayEnd[1] - rayStart[1]),
  ]

  const series: unknown[] = hasPoint.value
    ? [
        {
          // Zero-crossing guides, so the origin is readable as the quadrant corner.
          type: 'line',
          data: [],
          silent: true,
          showSymbol: false,
          lineStyle: { opacity: 0 },
          z: 2,
          tooltip: { show: false },
          markLine: {
            silent: true,
            symbol: 'none',
            label: { show: false },
            lineStyle: { color: palette.value.border, width: 1 },
            data: [{ xAxis: 0 }, { yAxis: 0 }],
          },
        },
        {
          // The threshold ray. Unnamed, so it adds no legend entry: the direct
          // label on it and the explanation in the header's information button
          // say what it is.
          type: 'line',
          data: [rayStart, rayEnd],
          silent: true,
          showSymbol: false,
          lineStyle: { color: palette.value.positive, width: 1.5, type: 'dashed' },
          z: 3,
          tooltip: { show: false },
        },
        {
          // An invisible anchor on the ray carries its label, just above the line.
          type: 'scatter',
          data: [labelAnchor],
          silent: true,
          symbolSize: 0,
          label: {
            show: true,
            formatter: () => thresholdLabel.value,
            position: 'top',
            color: palette.value.muted,
          },
          z: 4,
          tooltip: { show: false },
        },
        {
          name: 'Usual care',
          type: 'scatter',
          data: [[0, 0]],
          symbolSize: 10,
          itemStyle: {
            color: palette.value.control,
            borderColor: palette.value.panel,
            borderWidth: 2,
          },
          z: 4,
          tooltip: {
            formatter: () =>
              [
                '<strong>Usual care</strong>',
                'The reference strategy: zero incremental cost and zero incremental QALYs.',
              ].join('<br/>'),
          },
        },
        {
          name: 'eQalb + usual care',
          type: 'scatter',
          data: [[qalys, cost]],
          symbolSize: 13,
          itemStyle: {
            color: palette.value.intervention,
            borderColor: palette.value.panel,
            borderWidth: 2,
          },
          z: 5,
          tooltip: {
            formatter: () =>
              [
                '<strong>eQalb + usual care</strong>',
                `Incremental QALYs: ${formatQaly(qalys)}`,
                `Incremental cost: ${formatEuro(cost)}`,
                annotation.value,
              ].join('<br/>'),
          },
          markLine: {
            silent: true,
            symbol: ['none', 'arrow'],
            symbolSize: 12,
            label: { show: false },
            lineStyle: { color: palette.value.intervention, width: 2, type: 'solid' },
            // Stopped just short of the point, so the open arrow head is not
            // hidden under the eQalb marker.
            data: [
              [
                { coord: [0, 0] },
                { coord: [qalys * ARROW_STOP, cost * ARROW_STOP] },
              ],
            ],
          },
        },
      ]
    : []

  return {
    ...base,
    grid: { left: 70, right: 24, top: 40, bottom: 56, containLabel: false },
    legend: { top: 6, textStyle: { color: palette.value.text }, icon: 'circle' },
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
    <p v-if="!hasPoint" class="chart__empty">No deterministic point to show.</p>
  </div>
</template>
