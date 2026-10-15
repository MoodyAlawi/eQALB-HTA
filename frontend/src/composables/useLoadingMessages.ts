/**
 * The lighthearted second line shown under a long operation's factual status.
 *
 * The factual sentence — the operation's own label, from `useAppBusy` — is what
 * says what is happening; this only adds a light line below it once the wait has
 * proved to be a real one, and it keeps out of the way of everything else:
 *
 *  - nothing appears until the wait has outlived its grace period, so a request
 *    that finishes in a moment never shows a message or a flicker;
 *  - the message changes every seven seconds, measured between the starts of two
 *    changes, drawn from a shuffled cycle, so every message is shown once before
 *    any of them comes back and the one just shown is never repeated back to back;
 *  - a change is a crossfade, so the caller is handed both the message on screen
 *    and — for the length of the swap — the one it is replacing, and fades one out
 *    as the other fades in (the opacity itself is the stylesheet's);
 *  - the wait is what ends it: when the operation settles the message and its
 *    timers go at once — no message is ever finished off, and nothing waits for a
 *    transition before completing;
 *  - each operation is its own lifecycle: the timers are cleared when the wait
 *    starts, when it ends, and when the component that shows them unmounts, so a
 *    new operation cannot inherit a timer from the last one;
 *  - under `prefers-reduced-motion: reduce` one static message is shown for the
 *    whole wait: nothing rotates, and a preference that changes during the wait
 *    stops the rotation and drops any crossfade in flight.
 *
 * The messages are deliberately about the modelling rather than about people: they
 * never suggest how far along a run is, what it will conclude, or that anyone
 * clinical is involved.
 */

import { onBeforeUnmount, ref, watch, type Ref } from 'vue'

/**
 * The approved messages. This list is the one place to edit them; each is shown in
 * turn before any is repeated, and the area they are shown in is as tall as the
 * longest of them, so a longer message only makes that area a little taller.
 */
export const LOADING_MESSAGES: readonly string[] = [
  'Exploring our options. All several thousand of them.',
  'Taking uncertainty very seriously. Ourselves, less so.',
  'Giving the assumptions a little sensitivity training.',
  'The willingness to wait threshold is being tested.',
  'Checking whether “it depends” is statistically robust.',
  'Somewhere, a spreadsheet is feeling threatened.',
  'Putting the ‘probable’ in probabilistic.',
  'The model has entered its ‘what if’ era.',
  'Our relationship with certainty remains complicated.',
  'A little less guesswork. A lot more iterations.',
  'The assumptions have been called in for questioning.',
  'Looking for value in all the right distributions.',
  'The confidence interval would like some personal space.',
  'Asking ‘what if?’ with considerably more computing power.',
  'The spreadsheet walked so this model could run.',
  'No crystal ball. Just a rather busy model.',
  'Some assumptions are doing more heavy lifting than others.',
  'Making room for a healthy amount of doubt.',
  'The model is working through its options. Relatable.',
  'Opportunity cost: what you could be doing while this runs.',
  'Still a better loading screen than a frozen spreadsheet.',
  'We asked for a simple answer. The model requested a distribution.',
  'Keeping our expectations appropriately uncertain.',
  'This is what happens when ‘it depends’ gets a Run button.',
]

/** How long a wait must last before a message appears at all. */
const GRACE_MS = 1000

/** How long a message is shown before the next one starts replacing it. */
const ROTATE_MS = 7000

/**
 * The whole crossfade, in milliseconds: the message being replaced fades out and
 * the message replacing it follows. The stylesheet is what plays it — this is the
 * value its two halves add up to, kept in step in the `.app-loading__quip` block —
 * and it is how long the outgoing message is kept on screen, so it is the length
 * of the swap and nothing else.
 */
const FADE_MS = 280

function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches
  )
}

/** A fresh shuffle of the cycle the messages are drawn from, by position. */
function shuffled(): number[] {
  const cycle = LOADING_MESSAGES.map((_, position) => position)
  for (let i = cycle.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1))
    const held = cycle[i]
    cycle[i] = cycle[j]
    cycle[j] = held
  }
  return cycle
}

export function useLoadingMessages(active: Ref<boolean>): {
  /** The message on screen, as its position in LOADING_MESSAGES. */
  current: Ref<number | null>
  /** The message being replaced, for the length of the crossfade, or null. */
  leaving: Ref<number | null>
} {
  const current = ref<number | null>(null)
  const leaving = ref<number | null>(null)

  let grace: ReturnType<typeof setTimeout> | null = null
  let rotation: ReturnType<typeof setInterval> | null = null
  let fade: ReturnType<typeof setTimeout> | null = null
  let cycle: number[] = []
  let index = 0
  let previous: number | null = null

  /**
   * The motion preference, watched for the whole life of this composable: a
   * preference that turns on while an operation is running has to stop the
   * rotation and take any crossfade with it, not wait for the next operation.
   */
  const motion =
    typeof window !== 'undefined' && typeof window.matchMedia === 'function'
      ? window.matchMedia('(prefers-reduced-motion: reduce)')
      : null

  function clearTimers(): void {
    if (grace !== null) clearTimeout(grace)
    if (rotation !== null) clearInterval(rotation)
    if (fade !== null) clearTimeout(fade)
    grace = null
    rotation = null
    fade = null
  }

  /** The next message in the cycle, never the one that was just shown. */
  function take(): number {
    if (index >= cycle.length) {
      cycle = shuffled()
      if (cycle.length > 1 && cycle[0] === previous) {
        // Opening a new cycle with the message still on screen would read as a
        // repeat, so that one is moved to the end of the cycle.
        cycle.push(cycle.shift() as number)
      }
      index = 0
    }
    const next = cycle[index]
    index += 1
    previous = next
    return next
  }

  /**
   * Puts a message on screen. The one already there stays for the crossfade — the
   * caller fades the two over each other, opacity only — and is dropped when the
   * swap is over, never before, so there is no moment with nothing to read.
   */
  function show(next: number): void {
    if (fade !== null) clearTimeout(fade)
    leaving.value = current.value
    current.value = next
    fade = setTimeout(() => {
      fade = null
      leaving.value = null
    }, FADE_MS)
  }

  function stop(): void {
    clearTimers()
    current.value = null
    leaving.value = null
    cycle = []
    index = 0
    previous = null
  }

  function start(): void {
    stop()
    grace = setTimeout(() => {
      grace = null
      if (prefersReducedMotion()) {
        // One message, held for the rest of the wait, with nothing rotating.
        current.value = LOADING_MESSAGES.length > 0 ? 0 : null
        return
      }
      show(take())
      rotation = setInterval(() => {
        show(take())
      }, ROTATE_MS)
    }, GRACE_MS)
  }

  /**
   * Reduced motion turned on or off during a wait. On: the rotation stops and any
   * crossfade is dropped, leaving the message on screen as the one static line —
   * and if the wait is still inside its grace period, the grace's own callback
   * reads the preference and shows that one line. Off again: the rotation resumes
   * from the message that is showing, without building a second interval.
   */
  function onMotionPreferenceChange(): void {
    if (!active.value) return
    if (prefersReducedMotion()) {
      if (rotation !== null) {
        clearInterval(rotation)
        rotation = null
      }
      if (fade !== null) {
        clearTimeout(fade)
        fade = null
      }
      leaving.value = null
      return
    }
    if (current.value !== null && rotation === null) {
      rotation = setInterval(() => {
        show(take())
      }, ROTATE_MS)
    }
  }

  watch(
    active,
    (running) => {
      if (running) start()
      else stop()
    },
    { immediate: true },
  )

  if (motion) motion.addEventListener('change', onMotionPreferenceChange)

  onBeforeUnmount(() => {
    if (motion) motion.removeEventListener('change', onMotionPreferenceChange)
    stop()
  })

  return { current, leaving }
}
