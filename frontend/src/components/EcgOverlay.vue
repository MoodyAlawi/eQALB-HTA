<script setup lang="ts">
/**
 * The one overlay box: an ECG perimeter with an interior inside it.
 *
 * Every overlay in the app is this box — the dialogs (the welcome prompt, the Home menu,
 * the PSA confirmation, the Part 2 case facts and the congratulations), the journey's
 * completion overlay, the chapter-transition bridges and the floating information
 * panels. They differ only in width, in alignment and in the words their host passes in,
 * so the shape, the padding, the typography and the opening are defined once, here and in
 * the stylesheet's `.ocard` block, rather than per view. The loading card is deliberately
 * not one of them.
 *
 * The opening is one sequence for every host, and this component is where it runs:
 *
 *   1. the two origins light at the south-west and north-east corners;
 *   2. the four traces leave them and close the perimeter;
 *   3. the interior, the words and the actions arrive together;
 *   4. the signal keeps passing along that same perimeter.
 *
 * Steps 1, 2 and 4 belong to `EcgFrame`, which owns the geometry and the timings (see
 * the constants it exports). This component waits exactly `ECG_REVEAL_MS` for step 3 and
 * flips one class, so there is one sequence and no host can time itself differently.
 *
 * Until the perimeter has closed, the words and the actions are hidden in the layout but
 * unreachable: the content box carries `inert`, so a click cannot land on it and a
 * keyboard cannot tab into it, and `visibility: hidden` keeps it out of the accessibility
 * tree for the same period. When it is revealed, the focus is handed to the box's own
 * first control if — and only if — nothing else has taken it in the meantime, so a
 * learner who already tabbed to the close control keeps it. Under
 * `prefers-reduced-motion: reduce` there is no sequence at all: the perimeter and the
 * content are simply there.
 *
 * The caller owns the words, so nothing here invents or rewrites a sentence.
 */

import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import EcgFrame, { ECG_REVEAL_MS } from './EcgFrame.vue'

const props = withDefaults(
  defineProps<{
    /**
     * `centre` for a short announcement or a transition, whose heading, sentence and
     * actions are centred and whose box is sized to a reading width; `reading` for
     * longer informational content that stays left-aligned; `dense` for the floating
     * information panel.
     */
    variant?: 'centre' | 'reading' | 'dense'
    /** The accessible name of the corner close control. Omitted renders no control. */
    closeLabel?: string
  }>(),
  { variant: 'centre', closeLabel: undefined },
)

const emit = defineEmits<{ (event: 'close'): void }>()

const root = ref<HTMLElement | null>(null)
const stack = ref<HTMLElement | null>(null)
const close = ref<HTMLButtonElement | null>(null)
const revealed = ref(false)

let timer: ReturnType<typeof setTimeout> | null = null

function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches
  )
}

/** The first control the content offers, or the first the box can reach at all. */
function firstControl(): HTMLElement | null {
  const marked = root.value?.querySelector<HTMLElement>('[data-overlay-initial]')
  if (marked) return marked
  return stack.value?.querySelector<HTMLElement>('button, [href], input, select, textarea') ?? null
}

/**
 * Hands the keyboard to the content that has just appeared — but only when nothing has
 * claimed the focus. A dialog controller parks the focus on the panel (or on the close
 * control) while the content is still inert; that parked focus is what moves.
 */
function reveal(): void {
  revealed.value = true
  void nextTick(() => {
    const host =
      root.value?.closest<HTMLElement>(
        '.modal__panel, .joverlay__panel, .infotip__panel, .recap__card',
      ) ?? null
    const active = document.activeElement
    if (active !== null && active !== document.body && active !== host && active !== close.value) {
      return
    }
    firstControl()?.focus()
  })
}

onMounted(() => {
  if (prefersReducedMotion()) {
    reveal()
    return
  }
  timer = setTimeout(reveal, ECG_REVEAL_MS)
})

onBeforeUnmount(() => {
  if (timer !== null) clearTimeout(timer)
  timer = null
})
</script>

<template>
  <div
    ref="root"
    class="ocard"
    :class="[`ocard--${props.variant}`, { 'is-revealed': revealed }]"
  >
    <!-- The interior: a plain surface with no edge of its own, so the trace stays the
         only outline. It arrives with the words, not before them. -->
    <div class="ocard__backing" aria-hidden="true"></div>

    <EcgFrame />

    <div ref="stack" class="ocard__stack" :inert="revealed ? undefined : true">
      <div class="ocard__content">
        <slot />
      </div>
      <div v-if="$slots.actions" class="ocard__actions">
        <slot name="actions" />
      </div>
    </div>

    <button
      v-if="closeLabel"
      ref="close"
      type="button"
      class="ocard__close"
      :aria-label="closeLabel"
      :title="closeLabel"
      @click="emit('close')"
    >
      <span aria-hidden="true">×</span>
    </button>
  </div>
</template>
