/**
 * The first-visit intro: a short video shown once per browser profile on the first
 * entry into /app, before the app's own launch animation.
 *
 * This module owns whether the intro is due, which way it was entered, and the one
 * guarded way out of it. Playback, its timers and the overlay's look live in
 * `IntroTrailer.vue` and `styles.css`; the hand-over into Home is the existing launch
 * sequence (`useAppLaunch`), reused rather than copied:
 *
 *  - `finish()` runs once, whatever ended the intro - the video ending, Skip,
 *    Escape, a playback failure or a watchdog - records completion and calls
 *    `startLaunch`. The launch's own `navigate` callback is the moment Home is
 *    mounted, so no timing of the launch is repeated here.
 *  - The intro overlay is removed as soon as the launch overlay has faded in on top
 *    of it (its `launch-veil-in` animation has ended), so no dark layer is left
 *    behind while the launch overlay dissolves into Home.
 *  - The welcome question waits for `holding` to clear: the intro and the launch it
 *    started are both over.
 *
 * Nothing here requests anything from the model service.
 */

import { computed, nextTick, ref, watch } from 'vue'
import { useAppLaunch } from './useAppLaunch'

const INTRO_STORAGE_KEY = 'eqalb.intro.v1'

export type IntroOrigin = 'landing' | 'direct'

/** The intro overlay is mounted. */
const active = ref(false)
/** Which way the visitor came in: the landing page's button or a direct /app load. */
const origin = ref<IntroOrigin>('direct')
/** `finish()` has run and the launch has been asked for. */
const handedOff = ref(false)
/** A direct-/app intro keeps Home unmounted until the launch hands the page over. */
const homeHeld = ref(false)

let navigateTo: (() => void) | null = null
let finished = false
/** The intro has been shown in this page load, so it is never shown twice in one. */
let shownThisLoad = false
let stopCoverWatch: (() => void) | null = null
let coverTarget: HTMLElement | null = null

const launch = useAppLaunch()

function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches
  )
}

/**
 * Due only on a first visit in this browser profile. Reduced-motion visitors bypass
 * it (and the flag is left unset), and a browser whose storage cannot be read
 * bypasses it too, so it can never replay on every visit.
 */
function introDue(): boolean {
  if (shownThisLoad || active.value || prefersReducedMotion()) return false
  try {
    return localStorage.getItem(INTRO_STORAGE_KEY) !== 'done'
  } catch {
    return false
  }
}

function markDone(): void {
  try {
    localStorage.setItem(INTRO_STORAGE_KEY, 'done')
  } catch {
    /* best-effort: the intro is still never shown twice in this page load */
  }
}

/**
 * Opens the intro. `navigate` is what the launch will call at its hand-over - the
 * landing page's move to Home, or nothing for a direct /app load, where the page is
 * already Home and only its mount is being held.
 */
function startIntro(from: IntroOrigin, navigate: () => void): boolean {
  if (active.value || shownThisLoad) return false
  shownThisLoad = true
  finished = false
  handedOff.value = false
  origin.value = from
  navigateTo = navigate
  homeHeld.value = from === 'direct'
  active.value = true
  return true
}

function stopCovering(): void {
  stopCoverWatch?.()
  stopCoverWatch = null
  coverTarget?.removeEventListener('animationend', onCoverEnd)
  coverTarget = null
}

function removeOverlay(): void {
  stopCovering()
  active.value = false
}

function onCoverEnd(event: AnimationEvent): void {
  if (event.target === coverTarget && event.animationName === 'launch-veil-in') removeOverlay()
}

/** A keyboard user who skipped lands on Home's first action rather than nowhere. */
function focusHome(): void {
  const current = document.activeElement
  if (current instanceof HTMLElement && current !== document.body && current.isConnected) return
  document.querySelector<HTMLElement>('.home__action')?.focus({ preventScroll: true })
}

/** The one way out of the intro. Safe to call any number of times. */
function finish(): void {
  if (!active.value || finished) return
  finished = true
  markDone()
  handedOff.value = true
  const navigate = navigateTo
  navigateTo = null

  const arrive = () => {
    homeHeld.value = false
    navigate?.()
    void nextTick(focusHome)
  }

  launch.startLaunch(arrive)
  if (!launch.launching.value) {
    // The launch refused to start (one was already running): hand over directly.
    arrive()
    removeOverlay()
    return
  }

  // Keep the intro on screen until the launch overlay covers it, then remove it -
  // before the launch overlay dissolves, so nothing dark sits over Home. The
  // overlay's own fade-in is the signal; its later states are the fallback.
  void nextTick(() => {
    if (!active.value) return
    coverTarget = document.querySelector<HTMLElement>('.launch')
    coverTarget?.addEventListener('animationend', onCoverEnd)
  })
  stopCoverWatch = watch(
    [launch.leaving, launch.launching],
    ([leaving, launching]) => {
      if (leaving || !launching) removeOverlay()
    },
  )
}

/** The visitor left the intro's page (Back, a link): drop it without recording it. */
function cancelIntro(): void {
  if (!active.value || handedOff.value) return
  stopCovering()
  navigateTo = null
  homeHeld.value = false
  active.value = false
}

/** The intro, or the launch it started, is still running. */
const holding = computed(() => active.value || (handedOff.value && launch.launching.value))

export function useIntro() {
  return {
    active,
    origin,
    handedOff,
    homeHeld,
    holding,
    introDue,
    startIntro,
    finish,
    cancelIntro,
  }
}
