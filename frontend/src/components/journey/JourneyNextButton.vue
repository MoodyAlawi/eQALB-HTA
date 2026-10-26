<script setup lang="ts">
import { computed, ref } from 'vue'

/**
 * The journey's way forward, in one place.
 *
 * Every chapter and every state uses this control, and it always sits in the panel's
 * footer, so the learner looks in the same place for it whether the state is a chart
 * with a sentence beside it, a slider with its own instructions, or the last state of
 * a chapter.
 *
 * It draws an arrow only. The wording R publishes for the transition is still what the
 * control *is* — it is its accessible name, so a screen reader announces "The balance
 * at your price, button" — but it is not printed beside the arrow, because the sentence
 * the state already shows says what the state is about and a second line of text beside
 * a small control competes with it.
 *
 * The halo is one slow breath on the surface the button is already painted with. It
 * does not move the arrow, change the layout or blink: it is a box-shadow whose alpha
 * rises and falls over roughly four seconds. It pauses whenever the button is hovered,
 * focused or held, so a learner who has found the control is not still being drawn to
 * it, and it is switched off entirely under `prefers-reduced-motion`, where the button
 * is simply a static accent. The shadow's extent is a few pixels, well inside the
 * footer's own padding, so it can never reach a label or leave the panel.
 *
 * Where nothing follows — the end of a chapter that opens another chapter's bridge, and
 * the last state of the journey — the caller renders nothing, so an integration
 * boundary carries no control.
 */

const props = defineProps<{
  /** R's transition wording, used as the control's accessible name. */
  label: string | null
  /** Whether R is still working, in which case the control is held, not usable. */
  busy?: boolean
}>()

const emit = defineEmits<{ next: [] }>()

const button = ref<HTMLButtonElement | null>(null)

/** Moves focus here, for a caller restoring it after the control it was on went away. */
function focus(): void {
  button.value?.focus()
}

defineExpose({ focus })

/**
 * The control's accessible name: R's own wording for this transition.
 *
 * An arrow alone would be announced as "button", which tells a screen reader nothing
 * about where it goes. R's label is the sentence the chapter wrote for exactly this
 * step, so it is used unchanged rather than softened into "Next".
 */
const accessibleName = computed(() => {
  const label = props.label?.trim()
  return label && label.length > 0 ? label : 'Next'
})
</script>

<template>
  <div class="journey__footer">
    <button
      ref="button"
      type="button"
      class="journey__next"
      :aria-label="accessibleName"
      :disabled="busy"
      @click.stop="emit('next')"
    >
      <svg
        class="journey__next-icon"
        viewBox="0 0 16 16"
        width="18"
        height="18"
        aria-hidden="true"
        focusable="false"
      >
        <path
          d="M2.75 8h9.5M8.75 4.25 12.5 8l-3.75 3.75"
          fill="none"
          stroke="currentColor"
          stroke-width="1.9"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </button>
  </div>
</template>
