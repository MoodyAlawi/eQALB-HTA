/**
 * The short entrance a page plays when an internal link or button moves the
 * visitor to it.
 *
 * One class, toggled on the shell's page wrapper: the arriving page fades in over
 * `160ms` from the stylesheet's `.page-entry` rules, opacity only — no slide, no
 * scale, nothing moves and nothing is delayed. The page is composed and
 * interactive from the moment it is mounted; the fade is paint, and it never
 * gates a click, a key or a focus.
 *
 * The class is put on in a post-flush watcher, which is the same microtask as the
 * DOM update, so it lands before the arriving page is first painted: the page is
 * never shown at full strength and then faded. Nothing here reads or writes an
 * input, a result or the address, and the shell's own navigation is not touched —
 * the wrapper is a plain block around the page content, and neither the store's
 * `show`/`showPost`, nor the history entry, nor the browser's own scroll
 * restoration knows this exists.
 *
 * It plays once per *entry*: the key it watches is the page, plus the post's slug
 * on the blog, so the blog index, one post and another post are three entries
 * even though the same component renders them. A rerender, an input change, a
 * theme change, a loading message, a tutorial step or an analysis-tab switch
 * leaves the key alone and so replays nothing.
 *
 * Five things are shown immediately instead, and each is a case where a fade
 * would be wrong rather than merely unnecessary:
 *
 *  - **Reduced motion.** The stylesheet's own `prefers-reduced-motion` rule removes
 *    every animation, so the page is simply there.
 *  - **The first paint.** A page loaded directly is not an arrival from an
 *    internal link; the browser has already shown it.
 *  - **Back and Forward.** That is the browser's own move, and the page it puts
 *    back is one the browser is still restoring the scroll of; `cameFromHistory()`
 *    is the store's own signal for it.
 *  - **The landing page's crossing into the app.** `useAppLaunch` owns that
 *    sequence; this fade must not be a second entrance over it.
 *  - **A page being entered while the document is scrolled, and any page listed in
 *    `skip`.** While an element is below full opacity it is the containing block
 *    for any fixed-position descendant, so a scrolled arrival would re-anchor
 *    fixed chrome for the length of the fade: the landing page's header sits at
 *    the top of its document, and the app's Home screen pins its theme button to
 *    the window's corner while its column is narrower than the window. Those
 *    arrivals are shown as they are, and the rest of the entry points fade.
 *
 * Nothing can leave a page invisible: the animation's own end state is full
 * opacity, a stalled animation is cleared by a safety timer, and an animation
 * that never runs at all leaves the element with no animation and so at its
 * ordinary opacity.
 */

import { onBeforeUnmount, ref, watch, type Ref } from 'vue'
import { cameFromHistory } from './useAppView'
import { useAppLaunch } from './useAppLaunch'

/**
 * The fade's length in milliseconds. It is the stylesheet's animation length —
 * keep the two in step — and it is only used for the safety clear below.
 */
const ENTER_MS = 160

/**
 * How long the animation may run before the class is dropped regardless. Three
 * times the fade, so it cannot fight a legitimate animation, and it is what
 * guarantees a stalled animation cannot keep the wrapper's opacity anywhere but
 * its resting value.
 */
const SAFETY_MS = ENTER_MS * 3

export function usePageEntrance(
  entryKey: Ref<string>,
  options: { skip?: readonly string[] } = {},
): { enterClass: Ref<string> } {
  // Two identical keyframe pairs, alternated: an animation only restarts when its
  // name changes, so a move that lands while the previous fade is still running
  // has to be given a name of its own.
  const enterClass = ref('')
  const skip = options.skip ?? []
  const { launching } = useAppLaunch()

  let timer: ReturnType<typeof setTimeout> | null = null
  /** Bumped by every move, so a fade that has been superseded cannot clear the newer one. */
  let revision = 0
  let useFirst = true

  function stopTimer(): void {
    if (timer !== null) clearTimeout(timer)
    timer = null
  }

  /** Drops the class without touching the current move's timer. */
  function clear(): void {
    enterClass.value = ''
  }

  /**
   * The scroll position the arriving page will actually be at: the viewport's
   * offset, clamped to the page that has just been rendered. The clamp is read
   * from the new content rather than from the browser, because this runs before
   * the browser has re-clamped the offset itself — a long page left for a short
   * one is at the top however far down the long one was.
   */
  function arrivingScroll(): number {
    if (typeof document === 'undefined') return 0
    const max = Math.max(0, document.documentElement.scrollHeight - window.innerHeight)
    return Math.min(Math.max(0, window.scrollY), max)
  }

  function play(): void {
    const current = ++revision
    stopTimer()
    useFirst = !useFirst
    enterClass.value = useFirst ? 'is-entering-a' : 'is-entering-b'
    timer = setTimeout(() => {
      timer = null
      if (current !== revision) return
      clear()
    }, SAFETY_MS)
  }

  watch(
    entryKey,
    () => {
      // The callback runs only when the entry changes, so the page the document
      // opened on never reaches here: a direct load is not an arrival from a link.
      const key = entryKey.value
      if (
        skip.includes(key) ||
        cameFromHistory() ||
        launching.value ||
        // A dialog of the page's own is fixed-positioned inside the wrapper, and
        // would re-anchor while the wrapper is below full opacity.
        (typeof document !== 'undefined' && document.querySelector('.modal') !== null) ||
        arrivingScroll() > 1
      ) {
        revision += 1
        stopTimer()
        clear()
        return
      }
      play()
    },
    // Post-flush: the arriving page is in the DOM, so the layout this reads is the
    // one being entered, and the class still lands before the first paint.
    { flush: 'post' },
  )

  onBeforeUnmount(() => {
    revision += 1
    stopTimer()
  })

  return { enterClass }
}
