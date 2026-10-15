/**
 * The shared behaviour of the app's modal dialogs.
 *
 * Every dialog in the app — the once-per-session welcome question, the PSA
 * confirmation, the case facts and the congratulation — is dismissed and opened
 * through the same Vue transition, so they all arrive and leave the same way: the
 * backdrop fades while the panel fades and lifts a couple of pixels. The name is
 * defined once, here, and the motion itself lives in the dialog block of
 * `styles.css`.
 *
 * The one thing the transition must not do is leave a dialog behind. A dialog that
 * is on its way out is still in the document while it fades, so it is marked inert
 * for that moment: it can take no click and no key press, and nothing inside it can
 * hold the focus or be reached by one. The element is Vue's to remove once the fade
 * is over, so nothing here has to time it out; and because a transition whose
 * property is not animatable (as under `prefers-reduced-motion`, where transitions
 * are turned off) completes immediately, the removal is never waiting on the
 * motion.
 */

/** The transition name the dialog rules in `styles.css` are written for. */
export const DIALOG_TRANSITION_NAME = 'dialog'

/**
 * Bound to a dialog's `leave` hook: while it fades out it is inert, so it cannot
 * block the page or keep the focus. `inert` is removed again by nothing, because
 * the element is removed from the document when the fade finishes.
 */
export function onDialogLeave(element: Element): void {
  if (element instanceof HTMLElement) element.inert = true
}
