<script setup lang="ts">
/**
 * The app-wide loading indicator.
 *
 * Two levels, both driven by the shared `useAppBusy` state, and both hidden
 * until a wait has outlived its grace period so a request that completes
 * quickly shows nothing at all:
 *
 *   - a thin teal bar at the top of the app from 350ms;
 *   - a small centred card from 2.5s, for the genuinely long operations (a PSA
 *     run, a one-way analysis, a Part 2 case draw). It carries the compact eQalb
 *     wordmark, a quiet ECG line in the app's own teal and the operation's own
 *     status sentence.
 *
 * The moment the last operation settles both levels are removed again, so
 * nothing lingers over a finished result.
 *
 * Neither level is a modal: no backdrop, nothing focusable and
 * `pointer-events: none`, so tab order, Escape, disclosures and navigation are
 * exactly as they were and no click can land on the loader. The card is a
 * polite live region, so assistive technology hears the status sentence once;
 * the bar is decorative.
 *
 * The ECG line reuses the home title's trace morphology, drawn complete at low
 * opacity with one dash travelling along it and then holding off-screen, which
 * is the home composition's own restrained motion. Under
 * prefers-reduced-motion the assembly is still: the bar becomes a quiet
 * full-width line and the trace is drawn complete.
 */

import { onUnmounted, ref, watch } from 'vue'
import { useAppBusy } from '../composables/useAppBusy'

/** The grace period before any loader is shown, so a fast request never flickers. */
const BAR_DELAY_MS = 350

/**
 * The grace period before the card. It sits well above the operations that
 * merely take about a second (a survival simulation) and well below the long
 * ones (a Part 2 case draw, a PSA run), so the card appears only when the wait
 * is genuinely long.
 */
const CARD_DELAY_MS = 2500

/**
 * The trace, in the home title's 200 x 100 box with the baseline at y = 64 and
 * the same P-QRS-T morphology, so the card reads as the same signal.
 */
const TRACE = 'M0 64 H56 Q66 48 76 64 L82 74 L92 30 L106 88 L118 64 H134 Q146 38 158 64 H200'

const busy = useAppBusy()
const showBar = ref(false)
const showCard = ref(false)

let barTimer: ReturnType<typeof setTimeout> | null = null
let cardTimer: ReturnType<typeof setTimeout> | null = null

function clearTimers(): void {
  if (barTimer !== null) clearTimeout(barTimer)
  if (cardTimer !== null) clearTimeout(cardTimer)
  barTimer = null
  cardTimer = null
}

watch(
  () => busy.isActive,
  (active) => {
    clearTimers()
    if (!active) {
      showBar.value = false
      showCard.value = false
      return
    }
    barTimer = setTimeout(() => {
      showBar.value = true
    }, BAR_DELAY_MS)
    cardTimer = setTimeout(() => {
      showCard.value = true
    }, CARD_DELAY_MS)
  },
  { immediate: true },
)

onUnmounted(clearTimers)
</script>

<template>
  <div v-if="showBar" class="app-loading__bar" aria-hidden="true">
    <span class="app-loading__bar-segment"></span>
  </div>

  <div v-if="showCard" class="app-loading__card" role="status">
    <p class="app-loading__brand">eQalb</p>
    <svg
      class="app-loading__trace"
      viewBox="0 0 200 100"
      preserveAspectRatio="none"
      aria-hidden="true"
      focusable="false"
    >
      <path class="app-loading__trace-track" :d="TRACE" />
      <path class="app-loading__trace-pulse" :d="TRACE" pathLength="100" />
    </svg>
    <p class="app-loading__label">{{ busy.label }}</p>
  </div>
</template>
