/**
 * The landing page's transition into the application.
 *
 * "Open the app" is not a bare page swap: the landing page fades out, a band of
 * light crosses the screen and the eQalb wordmark is revealed behind it, the
 * light falls into its own quiet looping state, and the overlay dissolves as the
 * app arrives underneath. Only the sequence lives here; the look is in the
 * `Landing to app transition` section of `styles.css`, whose durations are the
 * animation's own and are kept in step with the timings below.
 *
 * The sequence deliberately owns nothing that matters:
 *
 *  - the overlay it drives is decoration only - `aria-hidden`, nothing
 *    focusable and `pointer-events: none` - so it can never trap the keyboard, a
 *    click or a screen reader;
 *  - `navigate` runs in a `finally`, so a failure still moves the visitor on;
 *  - the app is mounted and interactive from the moment it is called: the
 *    overlay is simply dissolving over a page that already works;
 *  - a hard safety timer clears the overlay whatever happens to the rest, and
 *    `cancelLaunch` drops it at once if the visitor leaves the trip early;
 *  - with `prefers-reduced-motion: reduce` the sweep and the reveal are dropped
 *    entirely and the whole crossing is a quick fade.
 */

import { ref } from 'vue'

/**
 * The sequence, in milliseconds. `arrive` is the point at which the app is
 * handed the page - the moment the logo has been revealed - and `leave` is the
 * overlay's own fade, which is what a visitor watches as the app rises in
 * underneath. Keep durations in step with the CSS: `leave` matches
 * `--launch-fade`, and the reveal pass there is `--launch-sheen`.
 *
 * Every step is a plain timer here, and both fades are CSS animations rather
 * than a Vue transition, so nothing in the crossing depends on a frame being
 * produced at the right moment: if rendering stalls, the animation is simply
 * further along when the frame does arrive, and the overlay is cleared on
 * schedule either way.
 */
export const LAUNCH_TIMING = {
  /** The reveal pass: the light has crossed and the logo is revealed. */
  arrive: 820,
  /** The overlay's cross-dissolve, while the app's own entrance plays. */
  leave: 360,
  /** Safety: whatever else happens, the overlay is gone by here. */
  clear: 2400,
  /** Reduced motion: a quick fade, with no sweep and no reveal to wait for. */
  reducedArrive: 140,
  reducedLeave: 160,
  reducedClear: 900,
} as const

const launching = ref(false)
const looping = ref(false)
const leaving = ref(false)

let timers: ReturnType<typeof setTimeout>[] = []

function schedule(action: () => void, delay: number): void {
  timers.push(setTimeout(action, delay))
}

function clearTimers(): void {
  for (const timer of timers) clearTimeout(timer)
  timers = []
}

function reset(): void {
  launching.value = false
  looping.value = false
  leaving.value = false
}

function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches
  )
}

export function useAppLaunch() {
  return {
    /** The overlay is mounted (and the landing page is fading out under it). */
    launching,
    /** The reveal has finished and the light has fallen into its looping state. */
    looping,
    /** The overlay is on its way out, dissolving over the app. */
    leaving,

    /**
     * Starts the transition and moves to the app.
     *
     * `navigate` is the visitor's own destination - the view store's own `show`
     * for /app - and it is called once, exactly once, whether the animation runs
     * to its end or the reduced-motion branch skips it. A second call while the
     * transition is running is ignored, so a double click cannot queue a second
     * crossing.
     */
    startLaunch(navigate: () => void): void {
      if (launching.value) return
      clearTimers()
      reset()
      launching.value = true

      const reduced = prefersReducedMotion()
      const arriveAt = reduced ? LAUNCH_TIMING.reducedArrive : LAUNCH_TIMING.arrive
      const leaveFor = reduced ? LAUNCH_TIMING.reducedLeave : LAUNCH_TIMING.leave

      schedule(() => {
        try {
          navigate()
        } finally {
          // The app is mounted and interactive from here; what is left is the
          // overlay dissolving over it, and the landing page is already gone.
          leaving.value = true
          looping.value = !reduced
        }
      }, arriveAt)

      schedule(reset, arriveAt + leaveFor)
      // A second, later clear: if a step above somehow never ran, the overlay
      // still cannot outlive the crossing.
      schedule(reset, reduced ? LAUNCH_TIMING.reducedClear : LAUNCH_TIMING.clear)
    },

    /** Drops the overlay and its timers, wherever the sequence had got to. */
    cancelLaunch(): void {
      clearTimers()
      reset()
    },
  }
}
