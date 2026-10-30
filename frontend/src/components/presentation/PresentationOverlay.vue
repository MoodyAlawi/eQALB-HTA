<script setup lang="ts">
/**
 * The presentation overlay: one completed analysis, shown viewport-sized for a
 * screen share.
 *
 * It is the app's own dialog — the shared `.modal` markup, the shared `dialog`
 * transition and the focus containment from `useModalFocus` — with one scoped
 * class for a larger panel. It owns the parts every analysis shows the same way:
 * the small eQalb identity line with the analysis title, the Close control, the
 * line that names what has moved since the run, the disclosure the run's settings
 * sit in, and R's own simulated-data notice. What each analysis shows in between
 * is its own, through the default slot.
 *
 * The overlay is rendered by the panel that opened it and is unmounted when it
 * closes, so a panel passes `v-if` on its snapshot; that teardown is also what
 * disposes the charts inside it. Opening it runs nothing: no request, no
 * recalculation, and no change to the panel it came from.
 */

import { onBeforeUnmount, onMounted, ref } from 'vue'
import { DIALOG_TRANSITION_NAME, onDialogLeave } from '../../composables/useDialogTransition'
import { useModalFocus } from '../../composables/useModalFocus'
import EcgOverlay from '../EcgOverlay.vue'

const props = withDefaults(
  defineProps<{
    /** The analysis name, as the tab's own heading has it. */
    title: string
    /**
     * R's notice line for the presented response, printed at the foot, or '' when
     * the presented content already carries R's own, stronger caveat.
     */
    notice: string
    /** The sentence naming what has moved since the run, or '' when nothing has. */
    stale?: string
    /**
     * A line shown when the panel's own result has been replaced by a later run
     * while this presentation is open, or '' when it has not.
     */
    superseded?: string
    /** The disclosure's heading. */
    settingsLabel?: string
    /** The paragraph above the settings rows. */
    settingsNote?: string
    /**
     * Where the focus goes when the invoking Present action is gone or cannot take
     * it. Normally the opener is still there and the focus returns to it.
     */
    fallbackFocus?: () => HTMLElement | null
  }>(),
  {
    stale: '',
    superseded: '',
    settingsLabel: 'Assumptions used in this run',
    settingsNote:
      'The values the model ran with, as its response reports them — not the panel’s controls, which may have moved since.',
    fallbackFocus: undefined,
  },
)

const emit = defineEmits<{ close: [] }>()

const modal = ref<HTMLElement | null>(null)
const closeButton = ref<HTMLButtonElement | null>(null)
/**
 * The dialog is open for as long as this component is mounted; the containment
 * composable watches this flag, so it is set once the overlay is in the document
 * and is cleared by `close()` before the panel unmounts. Clearing it first is what
 * returns the focus to the Present action while the overlay is still there: a
 * teardown on its own leaves the focus where it was, since the page it would go
 * back to may already be gone.
 */
/**
 * Whether an element can actually take the focus where it is now: the same test
 * the containment composable applies to the element that opened a dialog.
 */
function focusable(element: HTMLElement | null): element is HTMLElement {
  return (
    element !== null &&
    element !== document.body &&
    element !== document.documentElement &&
    element.isConnected &&
    !element.hasAttribute('disabled') &&
    element.getAttribute('aria-hidden') !== 'true' &&
    element.closest('[inert]') === null &&
    element.getClientRects().length > 0
  )
}

/**
 * The action that opened the overlay, remembered here because the overlay is what
 * gets unmounted when it closes — the containment composable's own teardown cannot
 * restore the focus, and it is the teardown that runs last.
 */
let opener: HTMLElement | null = null

const open = ref(false)

onMounted(() => {
  opener = document.activeElement instanceof HTMLElement ? document.activeElement : null
  open.value = true
})

useModalFocus(open, modal, {
  initialFocus: () => closeButton.value,
  fallbackFocus: () => props.fallbackFocus?.() ?? null,
})

/**
 * Closes the overlay: the containment is released and the focus returns to the
 * Present action, then the panel takes the overlay out of the document. A click on
 * the Close control, the backdrop and Escape all come through here, so the three
 * cannot behave differently.
 */
function close(): void {
  if (!open.value) return
  open.value = false
  emit('close')
}

/**
 * The focus goes back to the Present action once the overlay is out of the
 * document — after its leave fade, since that is when this component is torn down.
 * The element that opened it is preferred; a Present action that has gone (its
 * result cleared, its tab left) falls back to the one this panel named.
 */
onBeforeUnmount(() => {
  const target = focusable(opener) ? opener : (props.fallbackFocus?.() ?? null)
  if (focusable(target)) target.focus()
  opener = null
})

/**
 * Escape closes the overlay. When the focus is inside an open disclosure, that is
 * what the key press was aimed at, so the app-wide disclosure behaviour closes it
 * and the overlay stays up — the same order the rest of the app uses.
 */
function onKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Escape' || event.defaultPrevented) return
  const target = event.target
  if (target instanceof Element && target.closest('details.details[open]')) return
  event.stopPropagation()
  close()
}
</script>

<template>
  <Transition :name="DIALOG_TRANSITION_NAME" @leave="onDialogLeave">
    <div
      ref="modal"
      class="modal modal--present"
      role="dialog"
      aria-modal="true"
      aria-labelledby="present-title"
      @keydown="onKeydown"
    >
      <div class="modal__backdrop" @click="close()"></div>
      <div class="modal__panel">
        <EcgOverlay variant="reading" class="present">
          <header class="present__head">
            <p class="present__identity">
              <span class="present__brand">eQalb</span>
              <span class="present__title" id="present-title">{{ title }}</span>
            </p>
            <button ref="closeButton" type="button" class="btn" @click="close()">Close</button>
          </header>

          <p v-if="stale" class="alert alert--warning">{{ stale }}</p>
          <p v-if="superseded" class="alert alert--info">{{ superseded }}</p>

          <slot />

          <details v-if="$slots.settings" class="details">
            <summary>{{ settingsLabel }}</summary>
            <p class="muted">{{ settingsNote }}</p>
            <slot name="settings" />
          </details>

          <slot name="footer" />

          <p v-if="notice" class="present__notice">{{ notice }}</p>
        </EcgOverlay>
      </div>
    </div>
  </Transition>
</template>
