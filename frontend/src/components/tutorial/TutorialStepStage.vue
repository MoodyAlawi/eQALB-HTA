<script setup lang="ts">
/**
 * The stage a tutorial step — or a commissioning section — is rendered on.
 *
 * It plays one short transition when the step changes: the step being left fades
 * out and slides a few pixels toward the side it is leaving for, then the step
 * being arrived at fades in from the opposite side, so Forward and Back move in
 * opposite directions. Nothing else moves: the step strip, the navigation and the
 * live region sit outside this element and stay exactly where they are.
 *
 * Exactly one step is in the document at a time, which is why the move is driven
 * here rather than by `<Transition mode="out-in">`. An out-in transition can
 * leave the outgoing element in the document when a second move arrives while the
 * first is still running, and two steps at once would put two elements with the
 * same step-heading id in the document and leave the outgoing step's controls
 * clickable and focusable. Here a move that arrives mid-transition only replaces
 * the step that is about to be shown, so the stage always lands on the step the
 * learner is actually on however fast they move; and a move back onto the step
 * already on screen cancels the move instead of playing it. The stage's own timer
 * is the only thing that hands the screen over, so a superseded move has no
 * callback left to arrive late.
 *
 * Focus: once the arriving step is rendered, its heading is focused, so a
 * keyboard or screen-reader user is told which step they are on. The heading is
 * the step's existing focus target (`.tutorial__step-title`, `tabindex="-1"`);
 * when the arriving step has none — a section whose result is still being
 * evaluated, say — focus is left where it was rather than sent somewhere
 * arbitrary. `focusHeading` lets the caller keep its own focus decision: Part 2's
 * congratulation takes the focus when it opens, and it must not be taken back by
 * the section that arrives underneath it.
 *
 * Under `prefers-reduced-motion: reduce` no transition runs at all: the swap
 * happens straight away, so no content ever waits on an animation. Setting up the
 * step, moving between steps and leaving a step all keep the session's own state:
 * nothing here writes an input, a step number or a result, and mounting a step
 * requests nothing.
 */

import { nextTick, onBeforeUnmount, ref, watch } from 'vue'

const props = withDefaults(
  defineProps<{
    /**
     * The step on screen, as its position in its own sequence: the step number in
     * Part 1, the section index in Part 2, and one past the last step for the
     * completion card. The number is both the step's identity and its order, which
     * is what lets a move's direction be read from it.
     */
    step: number
    /** Whether the arriving step's heading may take the focus. */
    focusHeading?: boolean
  }>(),
  { focusHeading: true },
)

/**
 * The two halves of the move, in milliseconds. They are this component's own
 * timings — the stylesheet only supplies the animation they select — so the two
 * are kept in step in the stylesheet's comments.
 */
const LEAVE_MS = 180
const ENTER_MS = 220

const root = ref<HTMLElement | null>(null)
/** The step that is on screen. Only ever one step's number. */
const displayed = ref(props.step)
const phase = ref<'idle' | 'leaving' | 'entering'>('idle')
const direction = ref<'forward' | 'back'>('forward')

let timer: ReturnType<typeof setTimeout> | null = null
let disposed = false

function stopTimer(): void {
  if (timer !== null) clearTimeout(timer)
  timer = null
}

function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches
  )
}

/** Gives the focus to the arriving step's heading, when it has one. */
function focusArrivedStep(): void {
  if (!props.focusHeading) return
  root.value?.querySelector<HTMLElement>('.tutorial__step-title')?.focus()
}

/**
 * Hands the screen to the step that is waiting. The target is read here rather
 * than carried in: a move that arrived during the fade has already replaced it,
 * so the stage lands on the newest step and never on the one it passed through.
 */
function arrive(): void {
  stopTimer()
  if (disposed) return
  displayed.value = props.step
  phase.value = 'entering'
  void nextTick(() => {
    if (disposed) return
    focusArrivedStep()
  })
  timer = setTimeout(() => {
    timer = null
    if (!disposed) phase.value = 'idle'
  }, ENTER_MS)
}

/** Starts, or continues, the move towards the step that is now waiting. */
function begin(): void {
  // A fade-out is already running: its own timer will hand over to the newest
  // target, so only the direction has been refreshed.
  if (phase.value === 'leaving') return
  if (prefersReducedMotion()) {
    // No fade at all: the arriving step is simply shown, immediately.
    arrive()
    return
  }
  phase.value = 'leaving'
  stopTimer()
  timer = setTimeout(arrive, LEAVE_MS)
}

watch(
  () => props.step,
  (step) => {
    if (step === displayed.value) {
      // Moved back onto the step already on screen: cancel rather than play a
      // move that would end where it started.
      stopTimer()
      phase.value = 'idle'
      return
    }
    direction.value = step > displayed.value ? 'forward' : 'back'
    begin()
  },
)

onBeforeUnmount(() => {
  disposed = true
  stopTimer()
})
</script>

<template>
  <div ref="root" class="tut-stage" :class="[`is-${phase}`, `is-${direction}`]">
    <slot :shown="displayed" />
  </div>
</template>
