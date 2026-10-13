/**
 * Minimal ECharts binding for Vue.
 *
 * ECharts is used with explicit modular imports so the bundle only contains the
 * chart types this app draws (line, bar, scatter) and the components it needs.
 * The composable owns the instance lifecycle: it creates the chart when the
 * container has a real size, re-renders whenever the option changes, keeps the
 * chart sized to its container, and disposes it on unmount.
 *
 * Usage: `const { setCanvas } = useEcharts(() => option.value)` and bind the
 * setter with `:ref="setCanvas"`. A function ref is used rather than a string
 * ref because the string form resolves to the unwrapped element, which does not
 * type as a ref.
 */

import { BarChart, LineChart, ScatterChart } from 'echarts/charts'
import {
  GridComponent,
  LegendComponent,
  MarkAreaComponent,
  MarkLineComponent,
  TooltipComponent,
} from 'echarts/components'
import * as echarts from 'echarts/core'
import type { EChartsCoreOption } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { onBeforeUnmount, onMounted, ref, watch, type ComponentPublicInstance } from 'vue'

echarts.use([
  BarChart,
  LineChart,
  ScatterChart,
  GridComponent,
  LegendComponent,
  MarkAreaComponent,
  MarkLineComponent,
  TooltipComponent,
  CanvasRenderer,
])

export interface EchartsHandle {
  /** Bind to the chart's element with `:ref="setCanvas"`. */
  setCanvas: (element: Element | ComponentPublicInstance | null) => void
  /** Force a re-render, e.g. after the element became visible. */
  render: () => void
}

export function useEcharts(option: () => EChartsCoreOption): EchartsHandle {
  const container = ref<HTMLElement | null>(null)
  let chart: echarts.ECharts | null = null
  let observer: ResizeObserver | null = null

  function setCanvas(element: Element | ComponentPublicInstance | null): void {
    container.value = element instanceof HTMLElement ? element : null
    render()
  }

  function observe(element: HTMLElement, onResize: () => void): void {
    observer?.disconnect()
    observer = new ResizeObserver(onResize)
    observer.observe(element)
  }

  function render(): void {
    const element = container.value
    if (!element) return

    if (!chart) {
      // A chart initialised while hidden would latch onto a 0x0 canvas, so wait
      // until the element has a size; the observer calls back when it does.
      if (element.clientWidth === 0 || element.clientHeight === 0) {
        observe(element, render)
        return
      }
      chart = echarts.init(element)
      observe(element, () => chart?.resize())
    }
    chart.setOption(option(), { notMerge: true })
  }

  onMounted(render)
  watch(option, render, { deep: true })

  onBeforeUnmount(() => {
    observer?.disconnect()
    observer = null
    chart?.dispose()
    chart = null
  })

  return { setCanvas, render }
}
