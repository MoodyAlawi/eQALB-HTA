<script setup lang="ts">
/**
 * The journey's overlay shell.
 *
 * It is the app's own dialog underneath — `useModalFocus` gives it the focus trap,
 * the inert background and the focus restore — with the journey's own surface: a dimmed
 * page and the dark blue interior the shared overlay box paints behind its words.
 *
 * It is built as a shell rather than as the completion card so a later chapter
 * transition can use the same surface without a second implementation; today only the
 * end of the journey opens it.
 *
 * The caller owns the words and the actions: this renders slots, so the content stays
 * R's where R supplies it and the overlay itself never invents a sentence.
 */

import { onBeforeUnmount, onMounted, ref, toRef } from 'vue'
import { useModalFocus } from '../../composables/useModalFocus'
import EcgOverlay from '../EcgOverlay.vue'

const props = defineProps<{
  /** Whether the overlay is on screen. */
  open: boolean
  /** The id of the element that names the dialog, for assistive technology. */
  labelledBy: string
}>()

const emit = defineEmits<{ (event: 'close'): void }>()

const root = ref<HTMLElement | null>(null)
const panel = ref<HTMLElement | null>(null)

useModalFocus(toRef(props, 'open'), root, {
  // The overlay's first action is the one it is for, so the keyboard lands there
  // rather than on the close control that happens to come first in the corner.
  initialFocus: () =>
    panel.value?.querySelector<HTMLElement>('[data-overlay-initial]') ?? null,
})

/**
 * Escape closes the overlay, exactly as it closes the app's other dialogs. The event
 * is stopped so the page's own Escape handling cannot also act on it.
 */
function onKeydown(event: KeyboardEvent): void {
  if (!props.open || event.key !== 'Escape') return
  event.stopPropagation()
  emit('close')
}

onMounted(() => {
  document.addEventListener('keydown', onKeydown)
})

onBeforeUnmount(() => {
  document.removeEventListener('keydown', onKeydown)
})
</script>

<template>
  <Teleport to="body">
    <div v-if="open" ref="root" class="joverlay" @click.self="emit('close')">
      <div class="joverlay__veil" aria-hidden="true"></div>

      <div
        ref="panel"
        class="joverlay__panel"
        role="dialog"
        aria-modal="true"
        :aria-labelledby="labelledBy"
      >
        <!-- The box is the app's shared overlay: one perimeter, one interior, one opening
             sequence. This view supplies only R's words and the two actions. -->
        <EcgOverlay variant="centre" close-label="Close" @close="emit('close')">
          <slot />
          <template v-if="$slots.actions" #actions>
            <slot name="actions" />
          </template>
        </EcgOverlay>
      </div>
    </div>
  </Teleport>
</template>
