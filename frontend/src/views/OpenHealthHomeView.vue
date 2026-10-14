<script setup lang="ts">
/**
 * OpenHealth landing page: the public front door, shown at "/".
 *
 * One scrolling page in three panels - eQalb, OpenHealth, About me - beneath a
 * compact floating navigation panel. It is presentation only: no input, no
 * result and no API call is involved, and the one action that matters, "Open the
 * app", is a link to the application's own address, /app. Arriving here or
 * leaving again never disturbs a run.
 *
 * The landing page is meant to read as a portfolio rather than as the app. Its
 * palette, typography and light/dark choice live in `landing.css` and
 * `useLandingTheme.ts`, which publish the landing theme as their own
 * `<html data-landing-theme>` attribute and take it away again when this page
 * unmounts. `eqalb.theme` and `<html data-theme>` are neither read nor written
 * here, so the interface behind this page keeps the theme it had.
 *
 * Motion is restrained and never load-bearing: a panel fades and lifts once, as
 * it first arrives, into its plain visible state; scrolling is the browser's own
 * with proximity snapping only; and `prefers-reduced-motion` removes the
 * entrance animation, the scroll hint's pulse, smooth scrolling and the snapping
 * together, leaving the same content in the same order.
 *
 * The copy is honest about what exists: eQalb is described as an illustrative
 * teaching model, OpenHealth as a personal project with one tool released rather
 * than as an organisation, and the three contact links are the email address,
 * repository and profile already used elsewhere in the project. The page carries
 * no simulated-data notice of its own: that belongs inside the application,
 * which presents the educational and simulated-data wording where the results
 * are, and repeating a shortened version here would only duplicate it.
 */

import { defineAsyncComponent, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { followLink, pagePath, useAppView } from '../composables/useAppView'
import { useLandingTheme } from '../composables/useLandingTheme'
import { useAppLaunch } from '../composables/useAppLaunch'

/**
 * The portrait in the About me panel. It is imported rather than referenced from
 * `public/` so the build fingerprints it and a missing file fails the build
 * instead of 404ing in the browser; Vite emits it as its own file (it is far
 * above the inline limit), so it stays out of the JavaScript bundle.
 *
 * The file is a web-ready derivative of the author's original
 * (`mahmood.png`, 1305 x 1206, 962 kB), resized to 640 x 591 - a little over
 * twice the 288px the layout can display it at - which is 345 kB. It has to stay
 * a PNG: the original is a cut-out with a transparent background (about 60% of
 * its pixels), which a JPEG would flatten. The resize preserves the alpha
 * channel, the cut-out edge and the aspect ratio, and the original is kept
 * beside it as the source of any future re-export.
 */
import portrait from '../assets/mahmood-portrait.png'

// Installs the app-wide disclosure behaviour and the history listener; this page
// navigates with its own anchors and hands the app's arrival to the launch
// sequence, so it needs the view store's address and `show` and nothing else.
const { page, show } = useAppView()

const { isDark, toggle: toggleTheme } = useLandingTheme()
const { launching, startLaunch } = useAppLaunch()

type SectionId = 'eqalb' | 'openhealth' | 'about-me'

/** The three panels, in order: the navigation and both observers read this list. */
const SECTIONS: readonly { id: SectionId; label: string }[] = [
  { id: 'eqalb', label: 'eQalb' },
  { id: 'openhealth', label: 'OpenHealth' },
  { id: 'about-me', label: 'About me' },
]

/** The contact details already used elsewhere in the project. */
const EMAIL = 'smalawi2018@gmail.com'
const LINKEDIN_URL = 'https://www.linkedin.com/in/mahmoodalawi'
const GITHUB_URL = 'https://github.com/MoodyAlawi/eQALB-HTA'

/** The panel an address such as "/#about-me" names, so a deep link starts in place. */
function hashSection(): SectionId | null {
  const match = SECTIONS.find((section) => section.id === window.location.hash.replace(/^#/, ''))
  return match ? match.id : null
}

const heading = ref<HTMLHeadingElement | null>(null)
const activeSection = ref<SectionId>(hashSection() ?? 'eqalb')

/**
 * Whether the scroll-linked reveal can run, decided before the first render so
 * nothing flickers. The stylesheet only holds a section back while the page is
 * armed, and the page arms itself only when it has the browser feature the
 * reveal is built on: in any other browser - or if the setup below throws -
 * every section is simply shown as it stands.
 */
const revealArmed =
  typeof window !== 'undefined' && typeof window.requestAnimationFrame === 'function'

/**
 * The two sections whose content fades with the scroll. The hero is deliberately
 * not one of them: it is the doorway to the app, so it is fully visible from the
 * first paint and its button is never behind a scroll.
 */
const REVEAL_SECTIONS: readonly SectionId[] = ['openhealth', 'about-me']

/**
 * The band the fade spans, as fractions of the viewport height, read from the
 * content wrapper's own untransformed bounds.
 *
 * Entry looks at the wrapper's top edge: the content is transparent with its top
 * at or below 90% of the viewport - it is only just arriving at the bottom - and
 * fully opaque by 55%, so it is already solid well before it reaches the middle
 * of the screen, which is where it is read. Linear in between, so the change is
 * spread across the range rather than arriving all at once.
 *
 * Exit looks at the wrapper's bottom edge instead, which is what keeps long
 * content legible: the fade waits until only the top 22% of the screen still
 * holds the content, so a tall block is fully readable the whole way through and
 * is only faded once it is genuinely on its way out. A group that cannot reach
 * that point - the last section, which the document ends beneath - stays fully
 * visible, because its bottom edge never gets that high and no space was added
 * to force it.
 */
const ENTER_FROM = 0.9
const ENTER_DONE = 0.55
const EXIT_START = 0.22
const EXIT_DONE = 0

/**
 * One section's two parts: the wrapper the progress is measured from, which is
 * never transformed, and the inner element the progress is painted on, whose own
 * transform therefore cannot feed back into that measurement.
 */
interface RevealTarget {
  id: SectionId
  wrapper: HTMLElement
  inner: HTMLElement
}

/**
 * The reveal targets, in order. An empty list means the page is not the shape
 * this view expects, which is treated like a browser without the features above:
 * the page is not armed and every section is shown as it stands.
 */
function revealTargets(): RevealTarget[] {
  const targets: RevealTarget[] = []
  for (const id of REVEAL_SECTIONS) {
    const panel = document.getElementById(id)
    const wrapper = panel?.querySelector<HTMLElement>('.landing__reveal')
    const inner = wrapper?.querySelector<HTMLElement>('.landing__reveal-inner')
    if (!wrapper || !inner) return []
    targets.push({ id, wrapper, inner })
  }
  return targets
}

/** The panels, in order, for the navigation's scroll spy. */
function panels(): HTMLElement[] {
  const found: HTMLElement[] = []
  for (const section of SECTIONS) {
    const panel = document.getElementById(section.id)
    if (!panel) return []
    found.push(panel)
  }
  return found
}

let sectionObserver: IntersectionObserver | null = null
let targets: RevealTarget[] = []

/** The pending repaint, so scroll events never paint the page synchronously. */
let frame = 0

/**
 * How opaque a group is as it arrives from below: 0 while its top edge is at or
 * below `ENTER_FROM`, 1 once that edge has reached `ENTER_DONE`, linear between.
 */
function enterProgress(top: number, viewport: number): number {
  const from = ENTER_FROM * viewport
  const done = ENTER_DONE * viewport
  if (top >= from) return 0
  if (top <= done) return 1
  return (from - top) / (from - done)
}

/**
 * How opaque a group is as it leaves above, read from its bottom edge: 1 until
 * that edge rises above `EXIT_START`, 0 once it reaches `EXIT_DONE`, linear
 * between. A group whose bottom edge cannot get that high is always 1 here.
 */
function exitProgress(bottom: number, viewport: number): number {
  const start = EXIT_START * viewport
  const done = EXIT_DONE * viewport
  if (bottom >= start) return 1
  if (bottom <= done) return 0
  return (bottom - done) / (start - done)
}

/**
 * The value to paint for one group. Opacity is whichever of the two ends is
 * further along, so arriving and leaving are each gradual and they meet in a
 * wide fully-visible band between them. The lift belongs to the entry alone, so
 * content does not drift downwards as it leaves.
 */
function revealFor(rect: DOMRect, viewport: number): { opacity: number; lift: number } {
  const enter = enterProgress(rect.top, viewport)
  return { opacity: Math.min(enter, exitProgress(rect.bottom, viewport)), lift: enter }
}

function setReveal(target: RevealTarget, opacity: number, lift: number): void {
  target.inner.style.setProperty('--reveal', String(opacity))
  target.inner.style.setProperty('--reveal-lift', String(lift))
}

/**
 * Paints every group from where it is now. Nothing latches: the value is a
 * function of the scroll position, so it fades in and out both ways and repeats
 * on every pass. The measurement is taken fresh each time rather than cached, so
 * a resize, a reflow or the portrait arriving cannot leave a stale value behind.
 */
function paintReveal(): void {
  frame = 0
  if (targets.length === 0) return
  const viewport = window.innerHeight || document.documentElement.clientHeight || 1
  const active = document.activeElement
  for (const target of targets) {
    // Focus outranks the scroll: a control is never focused while it is
    // transparent, and the scroll takes over again once focus leaves. Both
    // signals are read, so the override holds whichever the browser has updated.
    const focused =
      target.wrapper.matches(':focus-within') ||
      (active !== null && target.wrapper.contains(active))
    if (focused) {
      setReveal(target, 1, 1)
      continue
    }
    const { opacity, lift } = revealFor(target.wrapper.getBoundingClientRect(), viewport)
    setReveal(target, opacity, lift)
  }
}

/** Batches a repaint into the next frame. */
function scheduleReveal(): void {
  if (frame !== 0) return
  frame = window.requestAnimationFrame(paintReveal)
}

/**
 * A focus change is a one-off event rather than a stream, so it is painted in the
 * same turn instead of waiting for a frame: a control must never be left invisible
 * while it holds focus, and the scroll value must come back the moment focus
 * leaves, whether or not a frame is due.
 */
function paintFocusChange(): void {
  if (frame !== 0) {
    window.cancelAnimationFrame(frame)
    frame = 0
  }
  paintReveal()
}

/**
 * Keyboard focus lands on real controls - the About panel's contact links - so a
 * link must never be focused while it is invisible.
 */
function onFocusIn(): void {
  paintFocusChange()
}

/**
 * Focus may only have moved to another control inside the same group, so this
 * repaints and lets the focus test decide, rather than assuming the group was left.
 */
function onFocusOut(): void {
  paintFocusChange()
}

function stopReveal(): void {
  window.removeEventListener('scroll', scheduleReveal)
  window.removeEventListener('resize', scheduleReveal)
  document.removeEventListener('focusin', onFocusIn)
  document.removeEventListener('focusout', onFocusOut)
  if (frame !== 0) {
    window.cancelAnimationFrame(frame)
    frame = 0
  }
  if (debugFrame !== 0) {
    window.cancelAnimationFrame(debugFrame)
    debugFrame = 0
  }
}

/**
 * Development-only diagnostic, opt-in through the address: `?debugReveal=1`.
 *
 * It exists because the effect is reported as invisible on a machine that cannot
 * be inspected directly, and "the numbers are right here" is not the same claim as
 * "the numbers are right there". It reads the same values the reveal itself uses -
 * the scrolling element, the scroll offset, each wrapper's top and bottom edges,
 * the entry and exit progress, and the painted opacity of the element the reader
 * actually sees - so a difference between two environments can be read off rather
 * than guessed at.
 *
 * `import.meta.env.DEV` is false in a production build, so the flag below is a
 * constant false there and this never runs; nothing here changes any behaviour,
 * because it only reads.
 *
 * The markup lives in `RevealDiagnostic.vue`, reached through the dynamic import
 * below rather than rendered inline, so that a production build emits no chunk for
 * it and none of its wording ships. An inline `v-if` would have left the compiled
 * template - each label and heading as a string - in the bundle, permanently false
 * but present.
 */
const debugReveal =
  import.meta.env.DEV && new URLSearchParams(window.location.search).has('debugReveal')

const RevealDiagnostic = debugReveal
  ? defineAsyncComponent(() => import('../components/RevealDiagnostic.vue'))
  : null

interface DebugSection {
  id: SectionId
  top: number | null
  topFraction: number | null
  bottomFraction: number | null
  enter: number | null
  exit: number | null
  opacity: string | null
}

interface DebugState {
  scrollTarget: string
  scrollY: number
  scrollMax: number
  viewport: number
  reducedMotion: boolean
  armed: boolean
  section: SectionId
  sections: DebugSection[]
}

const debugState = ref<DebugState | null>(null)
let debugFrame = 0

function refreshDebug(): void {
  const viewport = window.innerHeight || 1
  const inner = (id: SectionId): HTMLElement | null => {
    const live = targets.find((target) => target.id === id)
    if (live) return live.inner
    const panel = document.getElementById(id)
    return panel?.querySelector<HTMLElement>('.landing__reveal-inner') ?? null
  }
  const wrapperOf = (id: SectionId): HTMLElement | null => {
    const live = targets.find((target) => target.id === id)
    if (live) return live.wrapper
    const panel = document.getElementById(id)
    return panel?.querySelector<HTMLElement>('.landing__reveal') ?? null
  }
  const scrolling = document.scrollingElement
  debugState.value = {
    scrollTarget:
      scrolling === document.documentElement
        ? 'html (document)'
        : (scrolling?.nodeName.toLowerCase() ?? 'none'),
    scrollY: Math.round(window.scrollY),
    scrollMax: Math.max(0, document.documentElement.scrollHeight - viewport),
    viewport,
    reducedMotion: prefersReducedMotion(),
    armed: revealArmed,
    section: activeSection.value,
    sections: REVEAL_SECTIONS.map((id) => {
      const wrapper = wrapperOf(id)
      const content = inner(id)
      const rect = wrapper?.getBoundingClientRect() ?? null
      const top = rect ? Math.round(rect.top) : null
      const bottom = rect ? Math.round(rect.bottom) : null
      return {
        id,
        top,
        topFraction: top === null ? null : Number((top / viewport).toFixed(3)),
        bottomFraction: bottom === null ? null : Number((bottom / viewport).toFixed(3)),
        enter: rect ? Number(enterProgress(rect.top, viewport).toFixed(3)) : null,
        exit: rect ? Number(exitProgress(rect.bottom, viewport).toFixed(3)) : null,
        opacity: content ? getComputedStyle(content).opacity : null,
      }
    }),
  }
}

/** Keeps the overlay live while it is open; only ever runs in development. */
function startDebug(): void {
  if (!debugReveal) return
  const tick = (): void => {
    refreshDebug()
    debugFrame = window.requestAnimationFrame(tick)
  }
  debugFrame = window.requestAnimationFrame(tick)
}

/** Every group shown, with the enhancement out of the picture entirely. */
function showEverything(): void {
  for (const target of targets) setReveal(target, 1, 1)
  targets = []
}

function prefersReducedMotion(): boolean {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

/**
 * Anchor navigation, shared by the section links, the wordmark, the scroll hint
 * and the footer's "Back to top". A plain left click is taken over so the target
 * panel can be scrolled to smoothly - or jumped to under reduced motion - while
 * modified and middle clicks keep the href's ordinary meaning (a new tab, "copy
 * link address").
 *
 * The address is updated with `replaceState` rather than with a history entry:
 * every section can still be linked to and shared, and Back leaves the landing
 * page instead of walking back through the sections the visitor passed through.
 */
function goToSection(event: MouseEvent, id: SectionId): void {
  if (event.defaultPrevented || event.button !== 0) return
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
  const panel = document.getElementById(id)
  if (!panel) return
  event.preventDefault()
  panel.scrollIntoView({ behavior: prefersReducedMotion() ? 'auto' : 'smooth', block: 'start' })
  activeSection.value = id
  window.history.replaceState(window.history.state, '', `#${id}`)
}

/**
 * "Open the app": still the real link to /app the page has always carried, so a
 * modified or middle click opens it in a new tab or copies the address as
 * before; a plain left click plays the app's arrival first. The transition never
 * owns the destination - it hands the page to the view store on its own timer,
 * and the app is mounted and interactive from that moment, with the overlay
 * dissolving over it - and `useAppLaunch` drops the whole thing for a visitor
 * who asked for reduced motion.
 */
function openApp(event: MouseEvent): void {
  if (event.defaultPrevented || event.button !== 0) return
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
  event.preventDefault()
  // The hand-over only happens if the landing page is still the page the visitor
  // is on: if something moved them on during the crossing, the sequence's own
  // timer must not drag them to /app afterwards.
  startLaunch(() => {
    if (page.value === 'openhealth') show('home')
  })
}

onMounted(() => {
  // The heading takes focus so a keyboard or screen-reader user is placed on the
  // page they asked for. `preventScroll` leaves a "#section" address on its own
  // section, which focusing the heading would otherwise pull back to the top.
  void nextTick(() => heading.value?.focus({ preventScroll: true }))

  const allPanels = panels()

  // Nothing may stay hidden behind an enhancement that cannot run: the page
  // simply never arms, and every section is shown as it stands.
  if (!revealArmed || allPanels.length !== SECTIONS.length) {
    showEverything()
    return
  }

  try {
    targets = revealTargets()
    if (targets.length !== REVEAL_SECTIONS.length) {
      targets = []
      showEverything()
    } else {
      // The first pass is synchronous, so the opening paint is already correct:
      // the hero is untouched, a group still below the fold starts at 0, and a
      // group that a deep link or a restored scroll position has brought into
      // view is painted from where it actually is before anything is drawn.
      paintReveal()
      window.addEventListener('scroll', scheduleReveal, { passive: true })
      window.addEventListener('resize', scheduleReveal, { passive: true })
      // Tab can reach a link inside a group the reader has not scrolled to, and
      // the repaint after focus leaves hands the value back to the scroll.
      document.addEventListener('focusin', onFocusIn)
      document.addEventListener('focusout', onFocusOut)
      startDebug()
    }

    // Which panel the reader is in, for the navigation: only the band across the
    // middle of the viewport counts, so whichever panel crosses it is the visible
    // one, whatever heights the panels have at this width. This is a scroll spy
    // only - it neither hides nor reveals anything.
    if (typeof IntersectionObserver !== 'undefined') {
      sectionObserver = new IntersectionObserver(
        (entries) => {
          for (const entry of entries) {
            if (!entry.isIntersecting) continue
            activeSection.value = entry.target.id as SectionId
          }
        },
        { rootMargin: '-45% 0px -45% 0px', threshold: 0 },
      )
      for (const panel of allPanels) sectionObserver.observe(panel)
    }
  } catch {
    // Whatever went wrong, a section waiting on the scroll must never stay
    // hidden: drop the enhancement and show the whole page as it stands.
    stopReveal()
    targets = []
    showEverything()
  }
})

onBeforeUnmount(() => {
  sectionObserver?.disconnect()
  sectionObserver = null
  stopReveal()
  targets = []
})
</script>

<template>
  <div
    class="landing"
    :class="{ 'landing--armed': revealArmed, 'is-leaving': launching }"
  >
    <!-- The floating panel is the whole header: a quiet wordmark, the three
         section links and the landing page's own light/dark control. -->
    <header class="landing__header">
      <div class="landing__nav">
        <a class="landing__mark" href="#eqalb" @click="goToSection($event, 'eqalb')">
          OpenHealth
        </a>

        <nav aria-label="Page sections">
          <ul class="landing__links">
            <li v-for="section in SECTIONS" :key="section.id">
              <a
                class="landing__link"
                :class="{ 'is-active': activeSection === section.id }"
                :href="`#${section.id}`"
                :aria-current="activeSection === section.id ? 'true' : undefined"
                @click="goToSection($event, section.id)"
                >{{ section.label }}</a
              >
            </li>
          </ul>
        </nav>

        <button
          type="button"
          class="landing__theme"
          :title="
            isDark ? 'Switch this page to the light theme' : 'Switch this page to the dark theme'
          "
          aria-label="Dark theme"
          :aria-pressed="isDark"
          @click="toggleTheme()"
        >
          <span aria-hidden="true">{{ isDark ? '☀' : '☾' }}</span>
        </button>
      </div>
    </header>

    <main>
      <!-- 1. eQalb, the doorway: the title, one line of description, one action,
           and one quiet line saying what the model actually is. It carries no
           reveal: the hero is fully visible from the first paint, so the app is
           never behind a scroll. -->
      <section id="eqalb" class="landing__panel" aria-labelledby="eqalb-title">
        <div class="landing__inner landing__hero">
          <p class="landing__label">01 / eQalb</p>
          <h1 id="eqalb-title" ref="heading" class="landing__title" tabindex="-1">eQalb</h1>
          <p class="landing__lede">An interactive introduction to health-economic modelling.</p>
          <a class="landing__cta" :href="pagePath('home')" @click="openApp($event)">
            Open the app
            <span aria-hidden="true">↗</span>
          </a>
        </div>

        <a
          class="landing__scroll"
          href="#openhealth"
          aria-label="Scroll to the OpenHealth section"
          @click="goToSection($event, 'openhealth')"
        >
          <span>Scroll</span>
          <span class="landing__scroll-arrow" aria-hidden="true">↓</span>
        </a>
      </section>

      <!-- 2. OpenHealth: what the project is, in a few lines and without
           presenting it as an organisation. The wrapper is the stable geometry
           the reveal measures; the inner element is what fades. -->
      <section id="openhealth" class="landing__panel" aria-labelledby="openhealth-title">
        <div class="landing__reveal">
          <div class="landing__reveal-inner landing__inner landing__inner--prose">
            <p class="landing__label">02 / OpenHealth</p>
            <h2 id="openhealth-title" class="landing__heading">
              <span class="landing__heading-line">Practical learning.</span>
              <span class="landing__heading-line">Fewer barriers.</span>
            </h2>
            <p class="landing__body">
              OpenHealth is a personal project about making the healthcare field easier to access
              for people from all walks of life. It explores how interactive tools can turn dense
              material into something a learner can change, run, and question.
            </p>
            <p class="landing__body">
              eQalb is its first step. The longer-term aim is a small set of accessible learning
              resources for people working and studying across healthcare.
            </p>
            <p class="landing__body">
              OpenHealth as a project does not plan to stop there. Our future aspirations extend to
              being a platform for people in healthcare to collaborate and open the floor to
              discussion on various health-related topics.
            </p>
          </div>
        </div>
      </section>

      <!-- 3. About me: the person behind the project, and how to reach him. The
           portrait sits under the name in the narrow column, so it is beside the
           prose on desktop and stacks above it below 900px; the page's own
           footer closes the panel. -->
      <section id="about-me" class="landing__panel" aria-label="About me">
        <div class="landing__reveal">
          <div class="landing__reveal-inner landing__inner landing__about">
            <div>
              <p class="landing__label">03 / About me</p>
              <h2 class="landing__name">Mahmood Alawi</h2>
              <!-- The intrinsic size is in the attributes, so the browser reserves
                   the box from the markup and the prose beside it never shifts as
                   the image arrives. -->
              <img
                class="landing__portrait"
                :src="portrait"
                alt="Portrait of Mahmood Alawi"
                width="640"
                height="591"
                loading="lazy"
                decoding="async"
              />
            </div>

            <div>
              <p class="landing__body">
                I'm a health economics graduate, and this is a personal project rather than a
                product. I built eQalb to explore health-economic modelling in a form you can
                actually handle: change an assumption, watch the result move, and see where the
                uncertainty sits.
              </p>
              <p class="landing__body">
                My inspiration for OpenHealth as a platform is all the open-source learning
                platforms I grew up using. Open access to education is a principle I have always
                pushed, whether at university or at work. Here, I plan to take it to the next
                level.
              </p>

              <ul class="landing__contact">
                <li>
                  <a
                    class="landing__contact-link"
                    :href="`mailto:${EMAIL}`"
                    :aria-label="`Email Mahmood Alawi at ${EMAIL}`"
                    >Email</a
                  >
                </li>
                <li>
                  <a
                    class="landing__contact-link"
                    :href="GITHUB_URL"
                    target="_blank"
                    rel="noopener noreferrer"
                    aria-label="Open the eQalb repository on GitHub"
                    >GitHub <span aria-hidden="true">↗</span></a
                  >
                </li>
                <li>
                  <a
                    class="landing__contact-link"
                    :href="LINKEDIN_URL"
                    target="_blank"
                    rel="noopener noreferrer"
                    aria-label="Open Mahmood Alawi's LinkedIn profile"
                    >LinkedIn <span aria-hidden="true">↗</span></a
                  >
                </li>
              </ul>
            </div>
          </div>
        </div>

        <footer class="landing__footer">
          <p class="landing__footer-note">OpenHealth — a personal learning project.</p>
          <ul class="landing__footer-links">
            <li>
              <a
                class="landing__footer-link"
                :href="pagePath('blog')"
                @click="followLink($event, 'blog')"
                >Blog</a
              >
            </li>
            <li>
              <a class="landing__footer-link" href="#eqalb" @click="goToSection($event, 'eqalb')">
                Back to top
              </a>
            </li>
          </ul>
        </footer>
      </section>
    </main>

    <!-- Development-only diagnostic, shown only for `/?debugReveal=1` on the dev
         server. It reads the reveal's own values; it changes nothing. The import
         is dynamic and sits behind `import.meta.env.DEV`, so a production build
         emits no chunk for it and none of its markup or wording ships. -->
    <RevealDiagnostic v-if="RevealDiagnostic && debugState" :state="debugState" />
  </div>
</template>
