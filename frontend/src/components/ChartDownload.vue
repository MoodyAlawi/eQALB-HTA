<script setup lang="ts">
/**
 * The per-chart PNG action.
 *
 * It sits inside the figure that holds the chart, under it, and saves that chart
 * as it is on screen at that moment. The live ECharts instance is asked for its
 * own image, so nothing is rerun, no result is recomputed, no option is changed
 * and no second chart is created for the export — the instance is looked up from
 * the chart's own container (`getInstanceByDom` returns undefined rather than
 * initialising one), and the themed panel colour is painted behind the image, so
 * a dark-theme chart exports as readable text on the dark panel rather than as
 * light text on transparency.
 *
 * The outcome is reported by the app's single download notice, exactly as the CSV
 * exports are: "Download prepared." with the file name, or the reason it could not
 * be prepared. A failure changes nothing on screen — the chart and the result stay
 * where they are — and nothing in the caption or the figure moves when the button
 * is used, because the button is always there while its result is.
 *
 * It is not rendered in presentation mode: the overlays build their own captions
 * and do not include this component.
 */

import { getInstanceByDom } from 'echarts/core'
import { ref } from 'vue'
import { prepareDownload } from '../composables/useDownloadNotice'
import { useChartPalette } from '../composables/useTheme'
import { bytesFromDataUrl } from '../export/png'
import { downloadBytes } from '../export/zip'

const props = defineProps<{
  /** The file to save, naming the analysis and the chart. */
  filename: string
  /** The chart's name, as the caption reads, for the accessible label. */
  name: string
}>()

/** Twice the on-screen pixels, so the saved image stays sharp when enlarged. */
const PIXEL_RATIO = 2

const palette = useChartPalette()
const button = ref<HTMLButtonElement | null>(null)

function save(): void {
  prepareDownload(props.filename, () => {
    const container = button.value?.closest('figure')?.querySelector('.chart__canvas')
    const chart = container instanceof HTMLElement ? getInstanceByDom(container) : undefined
    if (!chart) throw new Error('The chart is not on screen yet.')
    const dataUrl = chart.getDataURL({
      type: 'png',
      pixelRatio: PIXEL_RATIO,
      backgroundColor: palette.value.panel,
    })
    downloadBytes(bytesFromDataUrl(dataUrl), props.filename, 'image/png')
  })
}
</script>

<template>
  <p class="chart-figure__actions">
    <button
      ref="button"
      type="button"
      class="btn btn--ghost btn--tiny"
      :aria-label="`Download the ${name} chart as a PNG`"
      :title="`Save this chart as ${filename}`"
      @click="save()"
    >
      Download chart
    </button>
  </p>
</template>
