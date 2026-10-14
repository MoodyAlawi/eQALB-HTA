<script setup lang="ts">
/**
 * The overlay that carries the visitor from the landing page into the app.
 *
 * It shows one thing: the app's own logo composition - the two decorative ECG
 * segments flanking the eQalb wordmark - wiped in from the left behind a band of
 * light, which then keeps passing on its own quiet cycle. The composition is
 * deliberately still: no pulse and no letter wave, because the app's Home screen
 * supplies exactly that the moment it mounts, and two copies of the same signal
 * competing would be the duplicate animation this is meant to avoid. The classes
 * are the Home screen's own (`home__title`, `home__trace*`, `home__wordmark`),
 * so the still composition here and the animated one there are one design, and
 * the overlay's dissolve into that screen reads as the same logo continuing.
 *
 * The overlay is decoration - `aria-hidden`, nothing focusable,
 * `pointer-events: none` - so it never holds the keyboard, a click or a screen
 * reader, and the app underneath it is live from the moment it is swapped in.
 * See `useAppLaunch.ts` for the sequence and `styles.css` for the look.
 */

import { onUnmounted, watch } from 'vue'
import { useAppView } from '../composables/useAppView'
import { useAppLaunch } from '../composables/useAppLaunch'

const { launching, looping, leaving, cancelLaunch } = useAppLaunch()
const { page } = useAppView()

/**
 * The overlay belongs to the trip from the landing page into the app. If the
 * visitor ends up anywhere other than that trip while it is running - Back, a
 * link, a reload that restores a page - it goes at once rather than hanging over
 * a page it does not belong to. Both ends are allowed: the landing page while
 * the crossing is still running, and the app once it has been handed over.
 */
watch(page, (next) => {
  if (next !== 'openhealth' && next !== 'home') cancelLaunch()
})

onUnmounted(cancelLaunch)

/**
 * The same two trace segments the Home screen draws, in the same 200 x 100 box,
 * so the composition the visitor sees here is the one they arrive at.
 */
const TRACE_LEAD = 'M0 64 H70 Q80 48 90 64 L96 74 L106 30 L120 88 L132 64 H146 Q158 38 170 64 H200'
const TRACE_TRAIL = 'M0 64 H20 Q30 48 40 64 L46 74 L56 30 L70 88 L82 64 H96 Q108 38 120 64 H200'
</script>

<template>
  <div
    v-if="launching"
    class="launch"
    :class="{ 'launch--looping': looping, 'launch--leaving': leaving }"
    aria-hidden="true"
  >
    <span class="launch__sheen"></span>

    <div class="home__title launch__logo">
      <svg
        class="home__trace home__trace--lead"
        viewBox="0 0 200 100"
        preserveAspectRatio="none"
        aria-hidden="true"
        focusable="false"
      >
        <path class="home__trace-track" :d="TRACE_LEAD" />
      </svg>

      <p class="home__wordmark launch__word">eQalb</p>

      <svg
        class="home__trace home__trace--trail"
        viewBox="0 0 200 100"
        preserveAspectRatio="none"
        aria-hidden="true"
        focusable="false"
      >
        <path class="home__trace-track" :d="TRACE_TRAIL" />
      </svg>
    </div>
  </div>
</template>
