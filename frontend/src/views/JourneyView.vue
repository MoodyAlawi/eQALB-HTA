<script setup lang="ts">
/**
 * The Guided Tutorial journey's screen.
 *
 * The shell owns the header, the one illustrative-data notice and the chapter
 * navigation; the chapter itself is rendered on TutorialStepStage, which owns the
 * move between two chapters and the focus hand-over. Only the chapters R sends are
 * listed, so no unbuilt chapter is ever advertised.
 *
 * The same screen also shows one chapter on its own: a standalone explainer, opened
 * from the dashboard module it explains (`?journey=1&explain=<chapterId>`). The
 * lesson, its copy and its request are the journey's; only the navigation around it
 * differs — R's orientation line instead of the chapter list, and a return to the
 * module instead of a bridge into the next chapter.
 *
 * Nothing here touches the current tutorial's session or the analysis dashboard:
 * the journey has its own composable, its own case and its own one lever.
 */

import { onMounted, onBeforeUnmount, computed, watch } from 'vue'
import { useAppView, type DashboardTabId } from '../composables/useAppView'
import { useTheme } from '../composables/useTheme'
import { useTutorialJourney } from '../composables/useTutorialJourney'
import TutorialStepStage from '../components/tutorial/TutorialStepStage.vue'
import JourneyCaseBrief from '../components/journey/JourneyCaseBrief.vue'
import JourneyChapter from '../components/journey/JourneyChapter.vue'

/**
 * The dashboard tab each chapter explains. A tab id is an interface name R does not
 * publish, so the small mapping lives here; the chapter ids are R's.
 */
const MODULE_TABS: Record<string, DashboardTabId> = {
  readiness: 'readiness',
  budget: 'budget',
  survival: 'survival',
}

const { show, showJourney, explainerChapter, setDashboardTab } = useAppView()
const { theme, toggle } = useTheme()

const {
  contract,
  contractBusy,
  contractError,
  chapterId,
  chapterStep,
  chapterIds,
  progressText,
  stageIndex,
  canAdvance,
  previousChapterId,
  isExplainer,
  moduleIdentity,
  loadContract,
  goToChapter,
  previousStage,
  restart,
  enterExplainer,
  leaveExplainer,
} = useTutorialJourney()

onMounted(() => {
  // The contract is fetched here; the model is not run until the learner asks
  // for the base case.
  void loadContract()
})

/**
 * An explainer address whose chapter the contract cannot open.
 *
 * A lesson is only standalone when R publishes a `module` block for it. If the address
 * asks for one and this build cannot supply it, the screen says so and offers the way
 * back rather than quietly showing the whole journey: a learner who asked to read one
 * lesson must not be dropped into a different screen, and nothing here starts a
 * calculation or moves the journey's state.
 */
const explainerUnavailable = computed(
  () => contract.value !== null && explainerChapter.value !== null && !isExplainer.value,
)

/**
 * An explainer address opens its chapter once the contract has arrived, because R
 * validates the chapter id. It asks R for nothing: opening a lesson never runs the
 * analysis it explains, so the learner's first advance is what calls the endpoint.
 */
watch(
  contract,
  (value) => {
    if (!value) return
    const id = explainerChapter.value
    if (id) enterExplainer(id)
  },
  { immediate: true },
)

// Leaving the screen — by the return control, the header, or any other route out —
// puts the journey's own position back, so a refresher can never move it.
onBeforeUnmount(() => {
  leaveExplainer()
})

const inChapter = computed(() => chapterId.value !== chapterIds.value[0])
/**
 * Whether the quiet Back is offered. In the journey it appears wherever there is an
 * earlier state or an earlier chapter. A standalone lesson has no earlier chapter — its
 * backward move stops at its own first state — so Back appears once the learner has
 * moved on within it, and revisiting never leaves the lesson.
 */
const showBack = computed(() => {
  if (isExplainer.value) return stageIndex.value > 0
  return inChapter.value && (stageIndex.value > 0 || previousChapterId.value !== null)
})

/**
 * The only move that plays the step transition is the brief giving way to the first
 * chapter, which are two different components. Every later move is between states of
 * one persistent panel, so the panel is carried across instead of fading.
 *
 * The brief is the list's first entry and the first chapter its second, so the
 * transition belongs to the first two steps of R's list and to nothing after them.
 * `chapterStep` counts from one, hence the `+ 1`.
 */
const BRIEF_AND_FIRST_CHAPTER = 2
const animateStep = computed(() => chapterStep.value <= BRIEF_AND_FIRST_CHAPTER)

function startChapter(): void {
  const first = chapterIds.value[1]
  if (first) goToChapter(first)
}

function exit(): void {
  leaveExplainer()
  show('home')
}

/**
 * Leaves an explainer address this build cannot open, for the module it names. It is
 * the same return as a lesson's own, minus the lesson: the tab is selected, the
 * address is cleared and nothing else changes, so no journey position, answer or
 * calculation is touched.
 */
function backFromUnavailable(): void {
  const id = explainerChapter.value
  const tab = id ? MODULE_TABS[id] : undefined
  if (tab) setDashboardTab(tab)
  show('dashboard')
}

/**
 * Leaves the lesson for the whole journey.
 *
 * Explainer mode is put down first, so the journey's own saved chapter, stage, answers
 * and cached results come back exactly as they were before the lesson was opened. Then
 * the journey is opened through the navigation store's own whole-journey entry, which
 * clears the lesson from the address as well as showing the screen: without that, the
 * address would keep `explain=<chapterId>` and the journey screen would read it as a
 * lesson it cannot open. Nothing is copied from the lesson into the journey, no progress
 * is reset, and no valid cached result is discarded.
 */
function openWholeJourney(): void {
  leaveExplainer()
  showJourney()
}

/**
 * Returns from a standalone lesson to the module it explains.
 *
 * Only the selected tab is set, and only because the reader may have arrived by a
 * direct link that never had a dashboard behind it: the tab is where the lesson
 * belongs, not a claim to restore a session that did not exist. The dashboard's own
 * inputs and results are untouched — the journey composable never writes them — so
 * they are exactly as the learner left them, while the journey's chapter, stage and
 * answers are put back by `leaveExplainer`.
 */
function backToAnalysis(): void {
  const tab = MODULE_TABS[chapterId.value]
  leaveExplainer()
  if (tab) setDashboardTab(tab)
  show('dashboard')
}
</script>

<template>
  <section class="tutorial" aria-labelledby="journey-title">
    <main v-if="contractBusy && !contract" class="state">
      <p>Loading the tutorial…</p>
    </main>

    <main v-else-if="contractError && !contract" class="state">
      <h2 id="journey-title">The tutorial is not reachable</h2>
      <p class="alert alert--danger">{{ contractError }}</p>
      <p class="muted">
        The tutorial is generated by the model service, so it needs that service to be running.
        Start it, then try again.
      </p>
      <button type="button" class="btn btn--primary" @click="loadContract()">Retry</button>
      <button type="button" class="btn btn--ghost" @click="exit()">Back to start</button>
    </main>

    <!-- An explainer address this build cannot open: say so and offer the way back. No
         calculation runs, and the journey's own position is not touched. -->
    <main v-else-if="explainerUnavailable" class="state">
      <h2 id="journey-title">This explainer is not available</h2>
      <p class="muted">
        The tutorial build this page is connected to does not publish a standalone lesson
        for that module yet. Your analysis settings and results are unchanged.
      </p>
      <button type="button" class="btn btn--primary" @click="backFromUnavailable()">
        Back to analysis
      </button>
    </main>

    <div v-else-if="contract" class="tutorial__body">
      <header class="tutorial__header">
        <div>
          <h1 id="journey-title" class="page__title">{{ contract.journey.title }}</h1>
          <p class="page__subtitle">{{ contract.journey.kicker }}</p>
        </div>
        <div class="tutorial__header-actions">
          <button
            type="button"
            class="btn btn--icon"
            :title="theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'"
            :aria-label="theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'"
            @click="toggle()"
          >
            <span aria-hidden="true">{{ theme === 'dark' ? '☀' : '☾' }}</span>
          </button>
          <button
            v-if="!isExplainer"
            type="button"
            class="btn btn--ghost"
            @click="restart()"
          >
            {{ contract.journey.navigation.restart }}
          </button>
          <button type="button" class="btn btn--ghost" @click="exit()">
            {{ contract.journey.navigation.exit }}
          </button>
        </div>
      </header>

      <!-- The one place the journey says its data are illustrative. -->
      <p class="alert alert--info">{{ contract.notice }}</p>

      <!-- A standalone lesson says which case it uses and where it came from: R's one
           orientation sentence, and the return to the module it explains. -->
      <div v-if="isExplainer && moduleIdentity" class="journey__orientation">
        <div>
          <p class="journey__orientation-label">{{ moduleIdentity.label }}</p>
          <p class="journey__orientation-text">{{ moduleIdentity.orientation }}</p>
        </div>
        <div class="journey__orientation-actions">
          <button type="button" class="btn btn--ghost" @click="openWholeJourney()">
            Read the whole journey
          </button>
          <button type="button" class="btn btn--ghost" @click="backToAnalysis()">
            {{ moduleIdentity.return_label }}
          </button>
        </div>
      </div>

      <nav v-if="!isExplainer" class="stepper" aria-label="Tutorial chapters">
        <p class="stepper__progress" aria-live="polite">{{ progressText }}</p>
        <ol class="stepper__list">
          <li
            v-for="(chapter, index) in contract.journey.chapters"
            :key="chapter.id"
            class="stepper__item"
          >
            <button
              type="button"
              class="stepper__button"
              :class="{ 'is-active': chapter.id === chapterId }"
              :aria-current="chapter.id === chapterId ? 'step' : undefined"
              @click="goToChapter(chapter.id)"
            >
              <span class="stepper__index" aria-hidden="true">{{ index + 1 }}</span>
              <span class="stepper__label">{{ chapter.progress }}</span>
            </button>
          </li>
        </ol>
      </nav>

      <TutorialStepStage :step="chapterStep" :animate="animateStep">
        <template #default="{ shown }">
          <JourneyCaseBrief
            v-if="shown === 1"
            :case-node="contract.case"
            @start="startChapter"
          />
          <!-- One component for every chapter, so moving from the first to the
               second changes its values rather than replacing it: the panel and the
               chart inside it are carried across. -->
          <JourneyChapter v-else />
        </template>
      </TutorialStepStage>

      <!-- One quiet control, and only backwards: the chapter moves forward by the
           learner activating the chart, so there is no forward button and no
           Continue in the flow. Back only lowers what is on show. -->
      <nav v-if="showBack" class="tutorial__nav" aria-label="Chapter navigation">
        <button type="button" class="btn btn--ghost btn--tiny" @click="previousStage()">
          {{ contract.journey.navigation.back }}
        </button>
      </nav>

      <!-- The standalone lesson's own ending: the way back to the module, in the
           place the journey would put its arrow. It is not the journey's completion
           card, and a refresher never shows that card. -->
      <nav
        v-if="isExplainer && moduleIdentity && !canAdvance"
        class="tutorial__nav journey__explainer-end"
        aria-label="Return to analysis"
      >
        <button type="button" class="btn btn--primary" @click="backToAnalysis()">
          {{ moduleIdentity.return_label }}
        </button>
      </nav>
    </div>
  </section>
</template>
