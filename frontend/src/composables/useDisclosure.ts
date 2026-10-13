/**
 * Shared disclosure behaviour: Escape closes the secondary-information
 * disclosure the keyboard focus is inside and returns focus to its trigger.
 *
 * A native <details> already opens by mouse, Enter and Space and is keyboard
 * reachable, but it has no built-in Escape handling. Instead of repeating one
 * keydown handler on every disclosure — and leaving the ones in the standalone
 * views without it — a single document listener serves them all.
 *
 * It only ever acts on `details.details`: those are the disclosures used for
 * secondary information. The assumptions sidebar's `details.group` blocks are
 * input groups rather than disclosures, and must not close while they are being
 * edited. Nothing here touches an InfoTip: an open tip closes on the same key and
 * sits above the page, so the tip is allowed to close alone.
 *
 * Installation happens in useAppView(), the composable every screen already
 * calls, because the shell (App.vue) is not part of this batch and the behaviour
 * has to hold on the dashboard, the Home screen and both subviews alike.
 */

/** The selector a disclosure must match to be closable this way. */
const SECONDARY_DISCLOSURE = 'details.details[open]'

let installed = false

function disclosureFor(node: Element | null): HTMLDetailsElement | null {
  const details = node?.closest(SECONDARY_DISCLOSURE)
  return details instanceof HTMLDetailsElement ? details : null
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Escape' || event.defaultPrevented) return
  // An open InfoTip sits above the page and closes on the same key; closing the
  // disclosure behind it as well would close two things with one press.
  if (document.querySelector('.infotip__panel')) return
  const active = document.activeElement
  const details = disclosureFor(active instanceof Element ? active : null)
  if (!details) return
  // The disclosure is what the key press was aimed at, so it stops here: the
  // standalone views use Escape as "back to Home", and stepping out of a
  // disclosure should not also leave the page.
  event.stopPropagation()
  details.open = false
  const summary = details.querySelector('summary')
  if (summary instanceof HTMLElement) summary.focus()
}

/** Installs the listener once per document, so repeated calls are harmless. */
export function installDisclosureEscape(): void {
  if (installed || typeof document === 'undefined') return
  installed = true
  document.addEventListener('keydown', onKeydown)
}
