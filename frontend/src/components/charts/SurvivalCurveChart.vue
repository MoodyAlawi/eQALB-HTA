<script setup lang="ts">
/**
 * Simulated Kaplan-Meier curves for both arms, with the 95% confidence band the
 * R estimator produced. The confidence interval is drawn as a filled band (the
 * upper edge masks the fill), which keeps the two arms readable when the bands
 * overlap.
 *
 * An optional `highlight` shades one year interval on one arm and draws a dashed level
 * at the estimate it ends on. The journey's downward-step beat uses it to point at
 * exactly the interval its sentence describes; with no highlight — every other caller —
 * the chart is drawn exactly as before.
 */

import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import type { KmStep } from '../../api/types'
import { useEcharts } from '../../composables/useEcharts'
import { chartBase, useChartPalette } from '../../composables/useTheme'
import { isNum } from '../../format'

const props = withDefaults(
  defineProps<{
    steps: KmStep[]
    followupYears: number
    /**
     * What to emphasise on the figure, or null for the chart as it always was.
     *
     * `from`/`to` shade one interval on `treatment` (a single year when they are
     * equal, which draws the time mark instead); `level` draws that arm's level and
     * `compareLevel` the other arm's, so a beat that compares two readings can show
     * both lines at the time it is talking about.
     */
    highlight?: {
      treatment: string
      from: number
      to: number
      level: number | null
      compareLevel?: { level: number | null; treatment: string } | null
      atTime?: number | null
    } | null
  }>(),
  { highlight: null },
)

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

  /**
   * The emphasis to draw, or null. It is taken as given: the years and the levels are
   * R's, and the arms are the ones R's sentence is about, so this component decides
   * only how the marks look.
   */
  const mark =
    props.highlight && isNum(props.highlight.from) && isNum(props.highlight.to)
      ? {
          treatment: props.highlight.treatment,
          from: props.highlight.from,
          to: props.highlight.to,
          level: isNum(props.highlight.level) ? props.highlight.level : null,
          compare: props.highlight.compareLevel ?? null,
          atTime: isNum(props.highlight.atTime) ? props.highlight.atTime : null,
          // One year exactly is a point in time rather than a span, so it is drawn as
          // a time mark instead of a shaded column.
          isPoint: props.highlight.from === props.highlight.to,
        }
      : null

  /** The level line for one arm, silent and unlabelled: it is an annotation. */
  const levelLine = (level: number, color: string) => ({
    silent: true,
    symbol: 'none',
    label: { show: false },
    lineStyle: { color, width: 1.2, type: 'dashed', opacity: 0.9 },
    data: [{ yAxis: level }],
  })

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
      // The emphasis, on the arm the caller names and nowhere else: a shaded column
      // between two years states which interval is being read, or a single time mark
      // where the beat is about one moment. The dashed levels show where each arm's
      // curve reads at that point, so a beat comparing two numbers has its two lines.
      // All of it is silent: it is an annotation, not a target.
      ...(mark && group === mark.treatment
        ? {
            ...(mark.isPoint
              ? {
                  markLine: {
                    silent: true,
                    symbol: 'none',
                    label: { show: false },
                    lineStyle: { color, width: 1.2, type: 'dashed', opacity: 0.9 },
                    data: [
                      { xAxis: mark.from },
                      ...(mark.level !== null ? [{ yAxis: mark.level }] : []),
                    ],
                  },
                }
              : {
                  markArea: {
                    silent: true,
                    itemStyle: { color, opacity: 0.16 },
                    data: [[{ xAxis: mark.from }, { xAxis: mark.to }]],
                  },
                  ...(mark.level !== null
                    ? { markLine: levelLine(mark.level, color) }
                    : {}),
                }),
          }
        : mark &&
            mark.compare &&
            mark.compare.treatment === group &&
            isNum(mark.compare.level)
          ? {
              // The comparison beat's other arm: only its own level at that one time.
              markLine: levelLine(mark.compare.level as number, color),
            }
          : {}),
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
