<script setup lang="ts">
/**
 * An on-demand explanation control.
 *
 * Shiny shows these as a bslib popover behind a small "i" button (cc_info() in
 * app.R). This is the same control with the same interaction, built as a real
 * disclosure so it needs no library and no focus trap:
 *
 *  - the trigger is a real <button>, so it opens with a click, Enter or Space;
 *  - Escape closes the panel and returns focus to the trigger;
 *  - a click outside closes it;
 *  - the panel is the element the button controls (`aria-controls`), and the
 *    button reports `aria-expanded`, so assistive technology follows the state.
 *
 * The panel is an overlay, never an in-flow element: it is teleported to <body>
 * and positioned in viewport coordinates, clamped to the viewport edges. Opening
 * it therefore cannot expand, shift or resize the card, row or table the trigger
 * sits in, and at narrow widths it stays fully visible — scrolling inside its own
 * box when the explanation is taller than the viewport.
 *
 * The text is R's where R provides it (CC_INFO_TEXT through /api/defaults), and
 * otherwise the explanation the interface already carried — a chart's subtext,
 * for instance, moved into the button that belongs to its header. This component
 * only renders the text it is given — it never rewords, shortens or summarises
 * it.
 *
 * A caller may also pass content through the default slot, for the one case where
 * an explanation has to carry its own control: the QALY panel's one-year line and
 * its way back to the model's own assumption. The slot sits under the text, and the
 * button opens for either source, so neither an explanation nor its control can be
 * lost when only one of them is supplied.
 *
 * The trigger sits beside the label rather than inside it: a button nested in a
 * <label> would make the label click toggle the panel instead of focusing the
 * field, and is invalid interactive content.
 */

import { computed, nextTick, onBeforeUnmount, onMounted, ref, useId, useSlots } from 'vue'
import EcgOverlay from './EcgOverlay.vue'

const props = withDefaults(
  defineProps<{
    /** The explanation, verbatim from the API. Empty or missing renders nothing. */
    text?: string | null
    /** What the explanation is about, for the button's accessible name. */
    topic: string
    /** Optional heading inside the panel; omitted keeps the panel to the text. */
    title?: string
  }>(),
  { text: null, title: undefined },
)

const open = ref(false)
const trigger = ref<HTMLButtonElement | null>(null)
const panel = ref<HTMLElement | null>(null)
const panelId = `infotip-${useId()}`
const slots = useSlots()

const hasText = computed(() => typeof props.text === 'string' && props.text.trim().length > 0)
/** Content supplied by the caller, e.g. a control that belongs with the explanation. */
const hasDetail = computed(() => Boolean(slots.default))
const hasPanel = computed(() => hasText.value || hasDetail.value)
const label = computed(() => `Information about ${props.topic}`)

/** Viewport edge gap, in px, that the overlay keeps clear. */
const EDGE = 8
/** Gap between the trigger and the overlay, in px. */
const OFFSET = 6

/**
 * Overlay coordinates in viewport space; null until the panel has been measured.
 * The panel is hidden for that one frame so it never flashes at an unpositioned
 * spot.
 */
const position = ref<{ left: number; top: number } | null>(null)

const panelStyle = computed(() =>
  position.value
    ? { left: `${position.value.left}px`, top: `${position.value.top}px` }
    : { visibility: 'hidden' as const },
)

/**
 * Measures the trigger and the panel and clamps the overlay inside the viewport:
 * prefer below the trigger, flip above when it does not fit there either, and
 * otherwise use the full remaining height (the panel then scrolls internally).
 */
function place(): void {
  const triggerEl = trigger.value
  const panelEl = panel.value
  if (!triggerEl || !panelEl) return

  const viewportWidth = document.documentElement.clientWidth
  const viewportHeight = document.documentElement.clientHeight

  // The stylesheet's cap is expressed in vw, which includes the scrollbar; the
  // binding cap has to be the client area actually available.
  panelEl.style.maxWidth = `${viewportWidth - 2 * EDGE}px`
  panelEl.style.maxHeight = `${viewportHeight - 2 * EDGE}px`

  const triggerRect = triggerEl.getBoundingClientRect()
  const panelRect = panelEl.getBoundingClientRect()

  let left = triggerRect.left
  if (left + panelRect.width > viewportWidth - EDGE) left = viewportWidth - EDGE - panelRect.width
  if (left < EDGE) left = EDGE

  let top = triggerRect.bottom + OFFSET
  if (top + panelRect.height > viewportHeight - EDGE) {
    const above = triggerRect.top - OFFSET - panelRect.height
    top = above >= EDGE ? above : Math.max(EDGE, viewportHeight - EDGE - panelRect.height)
  }

  position.value = { left, top }
}

async function openPanel(): Promise<void> {
  position.value = null
  open.value = true
  await nextTick()
  place()
}

function close(): void {
  open.value = false
}

function toggle(): void {
  if (open.value) close()
  else void openPanel()
}

/**
 * Escape closes the open panel from anywhere — not only while the trigger has
 * focus — and returns focus to the trigger. stopPropagation keeps the close from
 * also reaching page-level Escape handlers.
 */
function onDocumentKeydown(event: KeyboardEvent): void {
  if (!open.value || event.key !== 'Escape' || event.defaultPrevented) return
  event.stopPropagation()
  close()
  trigger.value?.focus()
}

function onDocumentClick(event: MouseEvent): void {
  if (!open.value) return
  const target = event.target as Node | null
  if (target && (trigger.value?.contains(target) || panel.value?.contains(target))) {
    return
  }
  close()
}

/** Keep the overlay attached to its trigger while the page scrolls or resizes. */
function onViewportChange(): void {
  if (open.value) place()
}

onMounted(() => {
  document.addEventListener('click', onDocumentClick)
  document.addEventListener('keydown', onDocumentKeydown)
  window.addEventListener('scroll', onViewportChange, true)
  window.addEventListener('resize', onViewportChange)
})

onBeforeUnmount(() => {
  document.removeEventListener('click', onDocumentClick)
  document.removeEventListener('keydown', onDocumentKeydown)
  window.removeEventListener('scroll', onViewportChange, true)
  window.removeEventListener('resize', onViewportChange)
})
</script>

<template>
  <span v-if="hasPanel" class="infotip">
    <button
      ref="trigger"
      type="button"
      class="infotip__trigger"
      :class="{ 'is-open': open }"
      :aria-label="label"
      :aria-expanded="open"
      :aria-controls="panelId"
      :title="label"
      @click="toggle()"
    >
      <span aria-hidden="true">i</span>
    </button>
    <Teleport to="body">
      <!-- A <div>, not a <span>: callers may put block content in the slot, and a
           panel with role="region" is a block-level element anyway. -->
      <div
        v-if="open"
        :id="panelId"
        ref="panel"
        class="infotip__panel"
        role="region"
        :aria-label="label"
        :style="panelStyle"
      >
        <EcgOverlay variant="dense">
          <strong v-if="title" class="infotip__title">{{ title }}</strong>
          <template v-if="hasText">{{ text }}</template>
          <div v-if="hasDetail" class="infotip__detail"><slot /></div>
        </EcgOverlay>
      </div>
    </Teleport>
  </span>
</template>
