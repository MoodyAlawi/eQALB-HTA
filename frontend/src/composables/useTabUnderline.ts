/**
 * The underline under the selected analysis tab.
 *
 * The strip's tabs are laid out by the browser — they wrap, they share a row until
 * they no longer fit, and the final tab is pushed to the end of whatever row it
 * lands on — so the underline is not a border on a tab but one element placed on
 * the selected tab's own box. It keeps the selected label's width and follows the
 * label when the selection changes, and the labels themselves never move.
 *
 * Two rules keep it honest rather than impressive:
 *
 *  - it animates only when the tab being left and the tab being selected are on
 *    the same row, because a move between rows is not a move along the strip;
 *  - anything that changes the layout — a resize, the strip wrapping, the web font
 *    arriving — repositions it with no transition at all, so it can never be drawn
 *    part-way across a strip it no longer describes.
 *
 * It is measured from `[role="tab"]` elements in the container, in their own DOM
 * order, which is the order the tabs are rendered in. Reading the layout happens
 * in a `flush: 'post'` watcher, so the selected tab's own font weight is already
 * applied when its width is measured. Nothing here reads or writes any tab state:
 * the selection belongs to the shell, and this only draws where it is.
 */

import { onBeforeUnmount, onMounted, ref, watch, type Ref } from 'vue'

/** How thick the underline is, in px; it must match `.tabs__indicator`. */
const UNDERLINE_HEIGHT = 3

interface Position {
  left: number
  top: number
  width: number
}

export function useTabUnderline(
  nav: Ref<HTMLElement | null>,
  activeIndex: Ref<number>,
): { position: Ref<Position | null>; moving: Ref<boolean> } {
  const position = ref<Position | null>(null)
  const moving = ref(false)
  let previousTop: number | null = null
  let observer: ResizeObserver | null = null
  let frame = 0

  function measure(animate: boolean): void {
    const container = nav.value
    if (!container) return
    const items = Array.from(container.querySelectorAll<HTMLElement>('[role="tab"]'))
    const item = items[activeIndex.value]
    if (!item) return

    const next: Position = {
      left: item.offsetLeft,
      top: item.offsetTop + item.offsetHeight - UNDERLINE_HEIGHT,
      width: item.offsetWidth,
    }
    // A first measurement, a wrap and a resize are all "jump" cases; only a move
    // within one row is animated.
    moving.value = animate && previousTop !== null && previousTop === next.top
    previousTop = next.top
    position.value = next
  }

  /** Reads the layout once, after the browser has finished the current update. */
  function schedule(animate: boolean): void {
    if (frame) cancelAnimationFrame(frame)
    frame = requestAnimationFrame(() => {
      frame = 0
      measure(animate)
    })
  }

  function observe(container: HTMLElement): void {
    observer?.disconnect()
    // The strip's own size changes when it wraps, when the window resizes and when
    // the sidebar is toggled; all three are repositioning, not moving.
    observer = new ResizeObserver(() => measure(false))
    observer.observe(container)
  }

  watch(nav, (container) => {
    if (container) observe(container)
    schedule(false)
  })

  watch(activeIndex, () => schedule(true), { flush: 'post' })

  onMounted(() => {
    schedule(false)
    // A web font arriving after the first paint changes every label's width.
    void document.fonts?.ready.then(() => schedule(false))
  })

  onBeforeUnmount(() => {
    observer?.disconnect()
    observer = null
    if (frame) cancelAnimationFrame(frame)
    frame = 0
  })

  return { position, moving }
}
