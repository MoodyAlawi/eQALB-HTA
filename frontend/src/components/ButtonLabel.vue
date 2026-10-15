<script setup lang="ts">
/**
 * A run button's label, in both of its states.
 *
 * The buttons that start an analysis are the ones whose text changes while their
 * request is in flight, and a button that resizes under the pointer is a control
 * that moves away from the hand watching it. Both labels are therefore rendered,
 * stacked in one grid cell, so the button is always as wide as its widest state and
 * exactly as tall as one line: nothing around it moves when a run starts or ends.
 *
 * Only the label belonging to the current state is exposed: the other is hidden
 * with `visibility`, which takes it out of the accessibility tree without taking it
 * out of the layout, so the button's accessible name is exactly its visible text —
 * `Run PSA` while it is idle, `Running 1,000 iterations…` while it runs. That is
 * what the button said before, word for word; all that changed is that neither
 * state can resize it.
 *
 * The pending state carries a very small ECG — the app's own trace, with one dash
 * running along it — as decoration beside the label. It is aria-hidden, it carries
 * no text, and it is never a progress bar: the label says what is happening and
 * nothing here suggests how far along it is.
 *
 * This is presentation only. The button keeps its own element, its own classes, its
 * own disabled state and its own handler; this renders its contents.
 */

defineProps<{
  /** Whether the request this button starts is in flight. */
  busy: boolean
  /** The label while the button is idle, exactly as it reads today. */
  idle: string
  /** The label while the request is pending; it must state what is happening. */
  pending: string
}>()

/**
 * The trace, in the app's 200 x 100 box with the baseline at y = 64 and the same
 * P-QRS-T morphology the rest of the app draws, so the mark is the same signal at
 * button scale.
 */
const TRACE = 'M0 64 H56 Q66 48 76 64 L82 74 L92 30 L106 88 L118 64 H134 Q146 38 158 64 H200'
</script>

<template>
  <span class="btn-label" :class="{ 'is-pending': busy }">
    <span class="btn-label__slot btn-label__slot--idle">{{ idle }}</span>
    <span class="btn-label__slot btn-label__slot--pending">
      <svg
        class="btn-label__trace"
        viewBox="0 0 200 100"
        preserveAspectRatio="none"
        aria-hidden="true"
        focusable="false"
      >
        <path class="btn-label__trace-track" :d="TRACE" />
        <path class="btn-label__trace-pulse" :d="TRACE" pathLength="100" />
      </svg>
      {{ pending }}
    </span>
  </span>
</template>
