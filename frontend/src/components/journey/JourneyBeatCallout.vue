<script setup lang="ts">
/**
 * The teaching beat's callout: the one sentence that changes as the learner moves
 * through a lesson.
 *
 * Every chapter of the journey states its beat in R's own words — one caption, or
 * one value sentence — and until now each chapter printed it as plain body copy in
 * a slightly different place. This is that sentence, once, in one shape: a compact
 * blue-tinted card with an accent edge and a small step indicator, so the learner
 * can see at a glance that the lesson has moved and where they are in it.
 *
 * The highlight is a brief one-shot tint on the callout when the sentence changes,
 * not a loop: it draws the eye to the new line and then leaves it alone. It is
 * keyed on the text, so it fires for a caption change and for a value sentence that
 * changed because R recomputed; moving Back fires it too, because the sentence
 * changed in the other direction. Nothing animates under
 * `prefers-reduced-motion` — the callout is simply there, already readable.
 *
 * The component owns no state and no wording: it renders the sentence and the step
 * numbers it is given, so a chapter cannot end up with two slightly different
 * callouts.
 */

import { computed, ref, watch } from 'vue'

const props = withDefaults(
  defineProps<{
    /** R's sentence for the beat on screen. Nothing renders without one. */
    text: string
    /** The state's position in its chapter, counted from one, and the total. */
    step: number
    total: number
    /** R's one-sentence explanation of a measure the beat introduces, if any. */
    measure?: string | null
  }>(),
  { measure: null },
)

/**
 * Whether the callout is playing its one-shot highlight. It is set when the
 * sentence changes and cleared when the animation ends, so a new change can restart
 * it and a long-running state never keeps a tint on screen.
 */
const flashing = ref(false)

const indicator = computed(() =>
  props.total > 0 ? `${props.step} of ${props.total}` : '',
)

watch(
  () => props.text,
  () => {
    flashing.value = false
    // Re-set on the next frame so the class actually toggles: a synchronous
    // false-then-true in one tick would be coalesced and the animation would not
    // restart.
    requestAnimationFrame(() => {
      flashing.value = true
    })
  },
)
</script>

<template>
  <div v-if="text" class="beat" :class="{ 'is-new': flashing }" @animationend="flashing = false">
    <div class="beat__body">
      <p class="beat__text" aria-live="polite">{{ text }}</p>
      <p v-if="measure" class="beat__measure" aria-live="polite">{{ measure }}</p>
    </div>
    <p v-if="indicator" class="beat__step" aria-hidden="true">{{ indicator }}</p>
  </div>
</template>
