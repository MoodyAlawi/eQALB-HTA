/**
 * The keyboard behaviour of the app's modal dialogs.
 *
 * `role="dialog"` and `aria-modal="true"` describe a dialog; they do not make one.
 * This is what makes them true. While a dialog is open:
 *
 * - The focus moves into it, and Tab and Shift+Tab stay inside it, wrapping at the
 *   last and the first control. A dialog with nothing focusable of its own keeps
 *   the focus on its panel rather than letting it wander.
 * - Everything outside it is inert, so the page behind it can take no click, no
 *   key press and no focus. The page is still visible and still live — it simply
 *   cannot be reached until the dialog is answered.
 * - When it closes, the focus returns to whatever opened it. If that element is
 *   gone, or is present but cannot take the focus, a fallback may be named; with
 *   none named, the focus is left where it is rather than thrown at a page the
 *   learner has already left.
 *
 * The background is made inert through the dialog's *relatives*, never through an
 * ancestor: from the dialog up to the body, the other children of each ancestor
 * are turned off. Nothing that contains the dialog is ever switched off, so the
 * dialog cannot inert itself, and every element that is touched remembers its own
 * prior state — an element that was already inert stays inert when the dialog
 * closes, and the app can never be left inert by a dialog that closes, unmounts,
 * or has its page taken away underneath it.
 *
 * The dialogs are already transitioned by `useDialogTransition`; this is only
 * their keyboard half, and it is deliberately small enough to read in one sitting.
 */

import { onBeforeUnmount, watch, type Ref } from 'vue'

export interface ModalFocusOptions {
  /** Where the focus goes when the dialog opens. */
  initialFocus?: () => HTMLElement | null
  /**
   * Where it goes when the dialog closes and the element that opened it is gone,
   * or is present but cannot take the focus.
   */
  fallbackFocus?: () => HTMLElement | null
}

/** The controls a dialog can be tabbed through, in document order. */
const FOCUSABLE = [
  'a[href]',
  'button:not([disabled])',
  'input:not([disabled]):not([type="hidden"])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  'summary',
  '[tabindex]:not([tabindex="-1"])',
].join(',')

/** Whether an element can actually hold the focus where it is now. */
function focusable(element: HTMLElement | null): element is HTMLElement {
  return (
    element !== null &&
    // The page itself is not a focus target: it is what is left when a real one
    // has gone, and it is never somewhere to send a keyboard user on purpose.
    element !== document.body &&
    element !== document.documentElement &&
    element.isConnected &&
    !element.hasAttribute('disabled') &&
    element.getAttribute('aria-hidden') !== 'true' &&
    // Inside something inert — another dialog still leaving, a page behind a
    // dialog — or inside something not rendered at all.
    element.closest('[inert]') === null &&
    element.getClientRects().length > 0
  )
}

function tabbable(root: HTMLElement): HTMLElement[] {
  return Array.from(root.querySelectorAll<HTMLElement>(FOCUSABLE)).filter(
    (element) => element.tabIndex >= 0 && focusable(element),
  )
}

/**
 * The dialog's panel, made programmatically focusable so a dialog with no control
 * of its own — or one whose focus target has just been unmounted — has somewhere
 * to keep the focus. The dialog's own markup names it; every dialog in the app has
 * one.
 */
function panel(modal: HTMLElement): HTMLElement {
  const found = modal.querySelector<HTMLElement>('.modal__panel') ?? modal
  if (!found.hasAttribute('tabindex')) found.setAttribute('tabindex', '-1')
  return found
}

export function useModalFocus(
  open: Ref<boolean>,
  modal: Ref<HTMLElement | null>,
  options: ModalFocusOptions = {},
): void {
  /** The elements turned off for this dialog, and whether they already were. */
  let background: { element: HTMLElement; wasInert: boolean }[] = []
  /** What held the focus when the dialog opened. */
  let opener: HTMLElement | null = null

  function focusInto(element: HTMLElement): void {
    const preferred = options.initialFocus?.() ?? null
    const target = focusable(preferred) ? preferred : (tabbable(element)[0] ?? panel(element))
    target.focus()
  }

  function trap(event: KeyboardEvent): void {
    if (event.key !== 'Tab') return
    const element = modal.value
    if (!element || !open.value) return
    const items = tabbable(element)
    if (items.length === 0) {
      // Nothing to tab to: the dialog holds the focus on its own panel.
      event.preventDefault()
      panel(element).focus()
      return
    }
    const first = items[0]
    const last = items[items.length - 1]
    const active = document.activeElement
    if (!(active instanceof HTMLElement) || !items.includes(active)) {
      // The focus is on the panel, or outside the dialog altogether: the next
      // stop is the first control going forwards and the last going backwards.
      event.preventDefault()
      ;(event.shiftKey ? last : first).focus()
      return
    }
    if (!event.shiftKey && active === last) {
      event.preventDefault()
      first.focus()
    } else if (event.shiftKey && active === first) {
      event.preventDefault()
      last.focus()
    }
  }

  /**
   * The page behind a dialog is inert, so it cannot be focused by hand — this is
   * for the programmatic case only, and for a browser that does not honour inert.
   * Anything else that moves the focus while a dialog is open is putting it
   * somewhere the learner cannot use, so it is brought back.
   */
  function hold(event: FocusEvent): void {
    const element = modal.value
    if (!element || !open.value) return
    const target = event.target
    if (target instanceof Node && element.contains(target)) return
    focusInto(element)
  }

  function release(): void {
    for (const entry of background) entry.element.inert = entry.wasInert
    background = []
    document.removeEventListener('keydown', trap, true)
    document.removeEventListener('focusin', hold, true)
  }

  function enter(): void {
    const element = modal.value
    if (!element) return
    // A dialog whose leave was cancelled by a quick reopen is still marked inert
    // by the exit transition; the dialog being opened must never be inert itself.
    element.inert = false
    const active = document.activeElement
    opener =
      active instanceof HTMLElement &&
      active !== document.body &&
      active !== document.documentElement &&
      !element.contains(active)
        ? active
        : null

    // Each ancestor's other children, from the dialog to the body. The dialog's
    // own ancestor chain is never touched, so the dialog stays reachable.
    let node: HTMLElement = element
    while (node !== document.body && node.parentElement) {
      const parent: HTMLElement = node.parentElement
      for (const sibling of Array.from(parent.children)) {
        if (sibling === node || !(sibling instanceof HTMLElement)) continue
        background.push({ element: sibling, wasInert: sibling.inert })
        sibling.inert = true
      }
      node = parent
    }

    document.addEventListener('keydown', trap, true)
    document.addEventListener('focusin', hold, true)
    focusInto(element)
  }

  function exit({ restoreFocus = true } = {}): void {
    release()
    const from = opener
    opener = null
    if (!restoreFocus) return
    if (focusable(from)) {
      from.focus()
      return
    }
    const fallback = options.fallbackFocus?.() ?? null
    if (focusable(fallback)) fallback.focus()
  }

  watch(open, (isOpen) => (isOpen ? enter() : exit()), { flush: 'post' })

  onBeforeUnmount(() => {
    // A dialog that goes away with its page must not take the page with it: the
    // background is restored and the focus is left to whatever replaces it.
    exit({ restoreFocus: false })
  })
}
