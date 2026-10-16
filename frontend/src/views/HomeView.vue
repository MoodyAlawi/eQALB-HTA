<script setup lang="ts">
/**
 * Home screen: the first thing the app shows.
 *
 * It is presentation only. The four actions switch the shell between this
 * screen, the project description, the download view, the analysis dashboard and
 * the tutorial; no input, result or API call is involved, so arriving here or
 * leaving again never disturbs a run.
 *
 * The layout is deliberately minimal: a title composition, the credit line and
 * subtitle, the four menu buttons and the creator links. The light/dark control
 * is a small icon button in the top-right corner.
 *
 * The menu is four compact one-line buttons, one shape and one size for all of
 * them. The two entry points are marked by an accent outline and a soft accent
 * tint rather than by a heavier block, and neither of them says what it is for on
 * the screen: the two of them open a small explanation of their own
 * (`EXPLANATIONS`), and only that overlay's action navigates. The two secondary
 * destinations, the project description and the download view, do not explain
 * themselves — they are their own page, so a question in front of them would only
 * be in the way.
 *
 * The explanation is the app's own dialog: the shared `.modal` markup, the shared
 * `dialog` transition, and the shared focus containment from `useModalFocus`. It
 * is not a second modal system, one overlay can be open at a time, and opening or
 * closing it runs nothing: no calculation, no reset, no change to the tutorial
 * session, and no navigation until its own action is used.
 *
 * The title is the wordmark flanked by two decorative ECG segments, so the trace
 * enters from the left, the wordmark interrupts it, and it continues to the
 * right: the beats fall before and after the name rather than behind it. The
 * wordmark itself is part of the same signal: each character is a span that the
 * pulse energises in turn, so a travelling wave of light crosses the name and
 * leaves it in the subdued resting tint again as the trailing trace begins. Only
 * CSS drives that, and the letters are aria-hidden with the accessible name on
 * the heading, so assistive technology hears "eQalb" once. With
 * prefers-reduced-motion the trace is drawn complete and every letter shows the
 * full title colour.
 *
 * The heading is deliberately not focusable: it is a title, not a control, and
 * programmatically focusing it on load painted a focus ring around the wordmark.
 * The focus outlines other views give their own headings are unchanged.
 *
 * The project-level simulated-data disclaimer deliberately lives in the Project
 * description view only, not here.
 */

import { computed, ref } from 'vue'
import { useAppView, type AppPage } from '../composables/useAppView'
import { useTheme } from '../composables/useTheme'
import { DIALOG_TRANSITION_NAME, onDialogLeave } from '../composables/useDialogTransition'
import { useModalFocus } from '../composables/useModalFocus'

const { show } = useAppView()
const { theme, toggle } = useTheme()

/**
 * The two menu choices that explain themselves before they navigate, and the
 * words each explanation carries. One short title, one sentence describing what
 * the choice actually opens, and the label of the action that continues to it.
 */
type MenuChoice = 'workspace' | 'tutorial'

interface Explanation {
  title: string
  text: string
  action: string
  page: AppPage
}

const EXPLANATIONS: Record<MenuChoice, Explanation> = {
  workspace: {
    title: 'Explore the model',
    text: 'Adjust assumptions and explore cost-effectiveness, uncertainty, budget impact, and implementation readiness.',
    action: 'Open workspace',
    page: 'dashboard',
  },
  tutorial: {
    title: 'Learn by doing',
    text: 'Work through a guided example, change a few assumptions, and explore how the results respond.',
    action: 'Start tutorial',
    page: 'tutorial',
  },
}

/**
 * The explanation that is open, or null. One ref is the whole of the state, so
 * the two choices cannot stack two overlays, and the buttons that open one only
 * set it — `continueTo` below is the only thing here that navigates.
 */
const active = ref<MenuChoice | null>(null)
const menuOpen = computed(() => active.value !== null)
const explanation = computed(() => (active.value ? EXPLANATIONS[active.value] : null))

const menuModal = ref<HTMLElement | null>(null)
const menuContinue = ref<HTMLButtonElement | null>(null)
const workspaceButton = ref<HTMLButtonElement | null>(null)
const tutorialButton = ref<HTMLButtonElement | null>(null)

useModalFocus(menuOpen, menuModal, {
  initialFocus: () => menuContinue.value,
  // If the menu button that opened the overlay is gone or cannot take the focus,
  // the focus goes to the choice it belongs to — closing never leaves the keyboard
  // on the document.
  fallbackFocus: () =>
    (active.value === 'tutorial' ? tutorialButton.value : workspaceButton.value),
})

function openExplanation(choice: MenuChoice): void {
  active.value = choice
}

function closeExplanation(): void {
  active.value = null
}

/** The overlay's own action: close first, then navigate — once, and at once. */
function continueTo(): void {
  const page = explanation.value?.page
  active.value = null
  if (page) show(page)
}

function onMenuKeydown(event: KeyboardEvent): void {
  // Escape closes the explanation without choosing a destination, exactly as it
  // does for the welcome question.
  if (event.key === 'Escape') {
    event.stopPropagation()
    closeExplanation()
  }
}

/**
 * The wordmark's characters, one span each. The spans carry no accessible text
 * (they are aria-hidden and the heading names itself), and their stagger is set
 * in CSS from their position, so they exist only to let the signal light the
 * letters in sequence.
 */
const LETTERS = ['e', 'Q', 'a', 'l', 'b']

/**
 * The two trace segments that flank the wordmark, in a shared 200 x 100 box with
 * the baseline at y = 64. Both carry the same morphology — a soft P bump, the
 * QRS beat, then a soft T bump — so the two halves read as one trace. The left
 * one leads in from its outer edge and beats just before the name; the right one
 * beats just after it and trails away. Each segment draws a still track and a
 * travelling pulse over the same path.
 */
const TRACE_LEAD = 'M0 64 H70 Q80 48 90 64 L96 74 L106 30 L120 88 L132 64 H146 Q158 38 170 64 H200'
const TRACE_TRAIL = 'M0 64 H20 Q30 48 40 64 L46 74 L56 30 L70 88 L82 64 H96 Q108 38 120 64 H200'
</script>

<template>
  <section class="home" aria-labelledby="home-title">
    <div class="home__topbar">
      <button
        type="button"
        class="btn btn--icon"
        :title="theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'"
        :aria-label="theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'"
        @click="toggle()"
      >
        <span aria-hidden="true">{{ theme === 'dark' ? '☀' : '☾' }}</span>
      </button>
    </div>

    <div class="home__hero">
      <div class="home__title">
        <svg
          class="home__trace home__trace--lead"
          viewBox="0 0 200 100"
          preserveAspectRatio="none"
          aria-hidden="true"
          focusable="false"
        >
          <path class="home__trace-track" :d="TRACE_LEAD" />
          <path class="home__trace-pulse" :d="TRACE_LEAD" pathLength="100" />
        </svg>

        <h1
          id="home-title"
          class="home__wordmark"
          aria-label="eQalb"
        ><span
          v-for="letter in LETTERS"
          :key="letter"
          class="home__letter"
          aria-hidden="true"
        >{{ letter }}</span></h1>

        <svg
          class="home__trace home__trace--trail"
          viewBox="0 0 200 100"
          preserveAspectRatio="none"
          aria-hidden="true"
          focusable="false"
        >
          <path class="home__trace-track" :d="TRACE_TRAIL" />
          <path class="home__trace-pulse" :d="TRACE_TRAIL" pathLength="100" />
        </svg>
      </div>

      <p class="home__credit">By Mahmood Alawi</p>
      <p class="home__subtitle">An educational HTA model</p>

      <div class="home__actions">
        <button
          ref="workspaceButton"
          type="button"
          class="btn home__action home__action--choice"
          @click="openExplanation('workspace')"
        >
          Open analysis workspace
        </button>
        <button
          ref="tutorialButton"
          type="button"
          class="btn home__action home__action--choice"
          @click="openExplanation('tutorial')"
        >
          Guided tutorial
        </button>
        <button type="button" class="btn home__action" @click="show('description')">
          Project description
        </button>
        <button type="button" class="btn home__action" @click="show('export')">
          Download results
        </button>
      </div>

      <p class="home__links">
        <a
          class="home__link"
          href="https://www.linkedin.com/in/mahmoodalawi"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Open Mahmood Alawi's LinkedIn profile"
        >
          LinkedIn
        </a>
        <span class="home__separator" aria-hidden="true">·</span>
        <a
          class="home__link"
          href="https://github.com/MoodyAlawi/eQALB-HTA"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="View the eQalb HTA source repository on GitHub"
        >
          View source on GitHub
        </a>
      </p>
    </div>

    <!-- The menu's explanation: the app's own dialog, opened by the two choices
         above so each can say what it opens before it opens it. The menu stays
         behind it, dimmed and unreachable, and the two ways back are the Close
         control, Escape and the backdrop. It is deliberately outside the hero:
         the hero carries the title's own entrance, and anything below full
         opacity becomes the containing block for a fixed descendant. -->
    <Transition :name="DIALOG_TRANSITION_NAME" @leave="onDialogLeave">
      <div
        v-if="explanation"
        ref="menuModal"
        class="modal modal--menu"
        role="dialog"
        aria-modal="true"
        aria-labelledby="menu-explanation-title"
        aria-describedby="menu-explanation-text"
        @keydown="onMenuKeydown"
      >
        <div class="modal__backdrop" @click="closeExplanation()"></div>
        <div class="modal__panel modal__panel--welcome">
          <h2 id="menu-explanation-title" class="modal__title">{{ explanation.title }}</h2>
          <p id="menu-explanation-text" class="page__prose">{{ explanation.text }}</p>
          <div class="tutorial__nav">
            <button
              ref="menuContinue"
              type="button"
              class="btn btn--primary"
              @click="continueTo()"
            >
              {{ explanation.action }}
            </button>
            <button type="button" class="btn btn--ghost" @click="closeExplanation()">Close</button>
          </div>
        </div>
      </div>
    </Transition>
  </section>
</template>
