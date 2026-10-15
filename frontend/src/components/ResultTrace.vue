<script setup lang="ts">
/**
 * The ECG trace that passes under an analysis panel's heading when a result is
 * committed.
 *
 * It is one short line carrying a single P-QRS-T complex — the same morphology as
 * the Home title's segments and the loading card's trace — in a slim strip
 * between the heading and its descriptive text. When a result arrives the line
 * draws itself from left to right with a soft teal highlight running along it,
 * and the whole strip then fades away, leaving the heading clean. Nothing here
 * loops, and nothing here stays: at rest the strip is transparent.
 *
 * It is decoration only. The strip is `aria-hidden`, it carries no text, and it
 * is never a signal, a progress bar, a clinical reading or a success
 * announcement; the panel's own heading keeps the name it always had and the
 * result is readable the moment it is committed.
 *
 * `revealClass` is the entrance class from useResultEntrance, so the summary and
 * the trace are driven by one committed revision rather than two. A run that
 * lands while the previous trace is still playing swaps to the other animation
 * name, which restarts the sequence on this same element: nothing stacks and no
 * element is duplicated.
 */

defineProps<{
  /**
   * The entrance class for this result, or an empty string when nothing is being
   * revealed.
   */
  revealClass: string
}>()

/**
 * The trace, in a 220 x 20 box with the baseline at y = 11: a flat lead-in, a P
 * bump, the QRS beat, a flat segment, a T bump and a flat tail — one complete
 * complex, so the strip reads as the app's own signal rather than a generic
 * squiggle.
 */
const TRACE = 'M0 11 H56 Q64 6 72 11 L78 15 L88 3 L100 18 L106 11 H140 Q152 5 164 11 H220'
</script>

<template>
  <div class="result-trace" :class="revealClass" aria-hidden="true">
    <svg
      class="result-trace__svg"
      viewBox="0 0 220 20"
      preserveAspectRatio="xMinYMid meet"
      focusable="false"
    >
      <path class="result-trace__line" :d="TRACE" pathLength="100" />
      <path class="result-trace__highlight" :d="TRACE" pathLength="100" />
    </svg>
  </div>
</template>
