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
 *     status sentence, and — for a wait that keeps going — one light line from
 *     the approved list below it (see useLoadingMessages).
 *
 * The moment the last operation settles both levels are removed again, so
 * nothing lingers over a finished result, and the light line goes with them.
 *
 * Neither level is a modal: no backdrop, nothing focusable, `pointer-events:
 * none`, and the light line carries no control of its own, so tab order, Escape,
 * disclosures and navigation are exactly as they were and no click can land on
 * the loader. The status sentence is the polite live region and every light line
 * sits outside it, so the operation is announced and the decoration is not.
 * The bar is decorative.
 *
 * The ECG line reuses the home title's trace morphology, drawn complete at low
 * opacity with one dash travelling along it and then holding off-screen, which
 * is the home composition's own restrained motion. The light line changes every
 * few seconds — but only while the card is up, and only as a crossfade: every
 * message is laid in the same place, the message being replaced and the message
 * replacing it fade over each other, and the rest stay transparent. Under
 * prefers-reduced-motion the assembly is still: the bar becomes a quiet
 * full-width line, the trace is drawn complete, and the light line is one static
 * sentence — never a rotating or fading one.
 */

import { computed, onUnmounted, ref, watch } from 'vue'
import { useAppBusy } from '../composables/useAppBusy'
import { LOADING_MESSAGES, useLoadingMessages } from '../composables/useLoadingMessages'

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

/**
 * The light line under the status sentence, and the message fading out under it.
 * Both follow the card: the line only has somewhere to appear while the card is
 * up, and a wait that ends before the card's own grace period passes never shows
 * one at all. Every message is rendered, so the area is as tall as the longest of
 * them and neither the first message arriving nor a change of message can resize
 * the card.
 */
const { current: quipIndex, leaving: quipLeaving } = useLoadingMessages(
  computed(() => showCard.value),
)

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

  <div v-if="showCard" class="app-loading__card">
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
    <p class="app-loading__label" role="status">{{ busy.label }}</p>
    <!-- The light line's own area is sized by the longest message at the current
         width, because every message is laid in the same grid cell: neither the
         first message arriving nor a change of message can resize the card, and a
         wrapped line grows the area rather than being clipped. Only the message on
         screen and — for the length of the crossfade — the one it replaces are
         opaque; the rest are transparent, and the block is decorative and outside
         the live region above it. It is rendered for as long as the card is, so the
         card also keeps one height from its first frame to its last. -->
    <p class="app-loading__quip" aria-hidden="true">
      <span
        v-for="(line, index) in LOADING_MESSAGES"
        :key="line"
        class="app-loading__quip-line"
        :class="{ 'is-current': index === quipIndex, 'is-leaving': index === quipLeaving }"
        >{{ line }}</span
      >
    </p>
  </div>
</template>
