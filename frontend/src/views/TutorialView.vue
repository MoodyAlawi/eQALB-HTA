<script setup lang="ts">
/**
 * Guided Tutorial Part 1: four teaching steps and a completion card.
 *
 * The whole tutorial is R's: this view renders the contract's step titles,
 * teaching copy, control metadata, rules and table headings, and the results
 * endpoint's values, statuses, interpretations and formatted strings. It holds no
 * tutorial rule of its own and shares no state with the analysis dashboard, so
 * opening the analysis from here cannot change a tutorial value and a tutorial
 * control cannot change a dashboard input.
 *
 * Update rule: the reference tutorial had no run button — a control change
 * re-evaluated its results — so a change here re-requests the Part 1 response,
 * coalesced by the session so one drag is one request. The results live region
 * reports when that request has been applied.
 *
 * Session rule: leaving the tutorial (Home or the full analysis) keeps the
 * session so the learner returns to the same step with the same values, and
 * "Restart tutorial" or a page reload is what resets it to R's defaults.
 *
 * Move rule: the step itself is rendered on TutorialStepStage, which owns the
 * transition between two steps and the hand-over between them. This view only
 * says which step is current — the step number, or one past the last step for the
 * completion card — so a move, however fast it is repeated, always ends on the
 * step the learner is on.
 *
 * Focus: the stage moves focus to the arriving step's heading once that step is
 * on screen, so a keyboard or screen-reader user is told which step they are on.
 * Disclosures close on Escape and return focus to their summary, which the shared
 * disclosure behaviour and the information control already implement.
 */

import { computed, onMounted } from 'vue'
import { useAppView } from '../composables/useAppView'
import { useTheme } from '../composables/useTheme'
import { useTutorialSession } from '../composables/useTutorialSession'
import TutorialStepper from '../components/tutorial/TutorialStepper.vue'
import TutorialStepStage from '../components/tutorial/TutorialStepStage.vue'
import TutorialStep1 from '../components/tutorial/TutorialStep1.vue'
import TutorialStep2 from '../components/tutorial/TutorialStep2.vue'
import TutorialStep3 from '../components/tutorial/TutorialStep3.vue'
import TutorialStep4 from '../components/tutorial/TutorialStep4.vue'
import TutorialCompletion from '../components/tutorial/TutorialCompletion.vue'
import Part2View from '../components/tutorial/Part2View.vue'

const { show } = useAppView()
const { theme, toggle } = useTheme()
const session = useTutorialSession()

onMounted(async () => {
  await session.loadContract()
  if (session.contract && !session.result && !session.resultError) {
    void session.evaluate()
  }
  // The Part 2 contract carries the completion card's Part 2 entry label, so it
  // is loaded with Part 1; a failure simply hides that entry and leaves Part 1
  // exactly as it was.
  void session.loadPart2Contract()
})

/** R's control values, keyed by control id, for binding the rendered controls. */
const values = computed<Record<string, number | boolean | undefined>>(() => {
  const collected: Record<string, number | boolean | undefined> = {}
  for (const control of session.contract?.controls ?? []) {
    collected[control.id] = session.inputValue(control.id)
  }
  return collected
})

const controlsFor = (stepIndex: number) => session.controlsForStep(stepIndex)
const stepCopy = (stepIndex: number) =>
  session.steps.find((step) => Number(step.id) === stepIndex) ?? null

const showBack = computed(() => !session.completed && session.stepNumber > 1)
const showNext = computed(
  () => !session.completed && session.stepNumber < session.stepCount,
)

/**
 * What the results region reports. The two settled sentences are interface
 * feedback about the request, not tutorial content, so they are not R's; every
 * number, status and sentence shown inside the steps is.
 */
const resultsStatus = computed(() => {
  if (session.evaluateBusy) return 'Updating results…'
  if (session.resultError) return 'The tutorial results could not be updated.'
  if (session.result) return 'Results updated.'
  return ''
})

/**
 * The step the stage shows: the current step, or the completion card, which is
 * the step after the last one so that arriving at it and leaving it again read as
 * one more move in the same sequence. The stage keeps the step it is fading out;
 * it is told only where the move ends, and it moves focus to the arriving step's
 * own heading once that step is on screen.
 */
const stageStep = computed(() =>
  session.completed ? session.stepCount + 1 : session.stepNumber,
)

function exit(): void {
  // The tutorial session is kept: returning to the tutorial resumes the same
  // step with the same values, and only Restart (or a reload) resets it.
  show('home')
}

function openFullAnalysis(): void {
  // Nothing is copied into the analysis session: the dashboard keeps its own
  // inputs and results.
  show('dashboard')
}

/**
 * Enters the commissioning exercise. It is a mode of this same tutorial session,
 * so Part 1's step, inputs and results are left exactly as they are and are still
 * there when the learner comes back.
 */
function startPart2(): void {
  void session.startPart2()
}
</script>

<template>
  <Part2View v-if="session.tutorialPart === 'part2'" />

  <section v-else class="tutorial" aria-labelledby="tutorial-title">
    <main v-if="session.contractBusy && !session.contract" class="state">
      <p>Loading the tutorial…</p>
    </main>

    <main v-else-if="session.contractError && !session.contract" class="state">
      <h2 id="tutorial-title">The tutorial is not reachable</h2>
      <p class="alert alert--danger">{{ session.contractError }}</p>
      <p class="muted">
        The tutorial is generated by the model service, so it needs that service to be running.
        Start it, then try again.
      </p>
      <button type="button" class="btn btn--primary" @click="session.loadContract()">Retry</button>
      <button type="button" class="btn btn--ghost" @click="show('home')">Back to start</button>
    </main>

    <div v-else-if="session.contract" class="tutorial__body">
      <header class="tutorial__header">
        <div>
          <h1 id="tutorial-title" class="page__title">{{ session.contract.title }}</h1>
          <p class="page__subtitle">{{ session.contract.kicker }}</p>
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
          <button type="button" class="btn btn--ghost" @click="exit()">
            {{ session.contract.navigation.exit }}
          </button>
        </div>
      </header>

      <p class="alert alert--info">{{ session.contract.disclaimer }}</p>

      <TutorialStepper
        :steps="session.steps"
        :current="session.stepNumber"
        :completed="session.completed"
        :progress-text="session.progressText"
        @select="session.goToStep"
      />

      <p class="tutorial__live muted" aria-live="polite">{{ resultsStatus }}</p>

      <p v-if="session.resultError" class="alert alert--danger">{{ session.resultError }}</p>

      <p v-if="!session.result && !session.resultError" class="hint">
        Loading the tutorial results…
      </p>

      <!-- One step at a time: the stage shows the step it has settled on and
           plays the move when the step changes. Only a step whose copy R sent is
           ever staged, so the fallthrough branch is Step 4 as it always was. -->
      <TutorialStepStage
        v-if="session.result && (session.completed || stepCopy(session.stepNumber))"
        :step="stageStep"
      >
        <template #default="{ shown }">
          <TutorialCompletion
            v-if="shown === session.stepCount + 1"
            :completion="session.contract.completion"
            :part2="session.part2Contract"
            :part2-busy="session.part2Busy"
            @open-full="openFullAnalysis"
            @restart="session.restart()"
            @start-part2="startPart2"
          />
          <TutorialStep1
            v-else-if="shown === 1"
            :copy="stepCopy(1)!"
            :contract="session.contract"
            :controls="controlsFor(1)"
            :result="session.result"
            :values="values"
            @change="session.setInput"
          />
          <TutorialStep2
            v-else-if="shown === 2"
            :copy="stepCopy(2)!"
            :contract="session.contract"
            :controls="controlsFor(2)"
            :result="session.result"
            :values="values"
            @change="session.setInput"
            @adjust-price="session.goToStep(1)"
          />
          <TutorialStep3
            v-else-if="shown === 3"
            :copy="stepCopy(3)!"
            :contract="session.contract"
            :controls="controlsFor(3)"
            :result="session.result"
            :values="values"
            @change="session.setInput"
          />
          <TutorialStep4
            v-else
            :copy="stepCopy(4)!"
            :contract="session.contract"
            :result="session.result"
            @finish="session.finish()"
          />
        </template>
      </TutorialStepStage>

      <nav class="tutorial__nav" aria-label="Tutorial navigation">
        <button v-if="showBack" type="button" class="btn btn--ghost" @click="session.back()">
          {{ session.contract.navigation.back }}
        </button>
        <button
          v-if="showNext"
          type="button"
          class="btn btn--primary"
          @click="session.next()"
        >
          {{ session.contract.navigation.forward }}
        </button>
        <button type="button" class="btn btn--ghost" @click="exit()">
          {{ session.contract.navigation.exit }}
        </button>
      </nav>
    </div>
  </section>
</template>
