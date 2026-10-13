/**
 * The app-wide busy state behind the loading indicator.
 *
 * An operation that can visibly take time announces itself with `start(label)`
 * and settles exactly once. `start()` therefore returns the operation's own
 * completion, `done()`: call it in a `finally`, so a rejection, a cancel or an
 * unmount at the call site clears the loader too, and calling it twice is
 * harmless — a stray second call cannot decrement another operation. `finish()`
 * remains the raw decrement behind that token.
 *
 * The state is a depth rather than a flag because operations nest: Part 2's case
 * draw awaits its own first evaluation, and both announce the same wait. While
 * anything is running, only the first operation's label is kept, so the sentence
 * on the card describes the wait the user actually started rather than
 * flickering between the inner and outer operations.
 *
 * A completion that never arrives — a request whose connection died without
 * erroring, say — is the one way this state could stick, so each operation
 * carries its own watchdog. It is deliberately generous (see below), so it
 * cannot hide a genuine calculation early; all it can do is recover a wait that
 * will never end. Only in development does it also warn, naming the operation,
 * because a watchdog that fired silently would hide a real defect.
 *
 * Only operations that are known to be slow are wired to this (the model runs,
 * the Part 2 case draw, the initial service load). Short requests are
 * deliberately left out: the indicator itself also waits before it appears.
 *
 * This is presentation state only. It reads no model value and no component
 * decides anything from it, so nothing about a result depends on when a loader
 * was shown.
 */

import { computed, reactive, ref } from 'vue'

/**
 * How long one operation may stay open before its completion is treated as lost
 * and the state is cleared anyway.
 *
 * The bound is measured, not guessed. The API's R worker abandons a model run at
 * `EQALB_R_TIMEOUT` (900 s by default), and the slowest run the interface itself
 * can request is a 10,000-draw PSA, about 30 minutes at the measured 0.18 s per
 * iteration. One hour is twice that slowest possible run, so a wait the model
 * can still legitimately be serving never reaches this watchdog.
 */
const WATCHDOG_MS = 60 * 60 * 1000

/** How many operations are currently running. */
const depth = ref(0)

/** The status sentence of the operation that started the current busy period. */
const label = ref('')

/** The raw decrement. `start()` hands out a token that calls it exactly once. */
function finish(): void {
  depth.value = Math.max(0, depth.value - 1)
}

function start(next: string): () => void {
  if (depth.value === 0) label.value = next
  depth.value += 1

  let settled = false
  let watchdog: ReturnType<typeof setTimeout> | null = null

  function settle(): void {
    if (settled) return
    settled = true
    if (watchdog !== null) clearTimeout(watchdog)
    finish()
  }

  watchdog = setTimeout(() => {
    if (settled) return
    if (import.meta.env.DEV) {
      console.warn(
        `[eQalb] "${next}" was still busy after ${WATCHDOG_MS / 60000} minutes and has been cleared.`,
      )
    }
    settle()
  }, WATCHDOG_MS)

  return settle
}

const isActive = computed(() => depth.value > 0)

export function useAppBusy() {
  // Returned as a reactive object so a component reads `busy.isActive` rather
  // than `busy.isActive.value`, matching the dashboard store's convention.
  return reactive({
    start,
    finish,
    isActive,
    label,
  })
}
