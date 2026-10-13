<script setup lang="ts">
/**
 * The Part 2 shell: the active-case banner, the five-section progress control, the
 * read-only Case facts overlay and the section itself.
 *
 * All five sections are implemented: the case brief, the value-for-money
 * exercise, the budget-impact exercise, the DHT readiness exercise and the
 * recommendation. Each section carries only what the reference tutorial puts in
 * it — the readiness traffic lights and the deliverability verdict live in the
 * recommendation, not in the exercise that asks the questions.
 *
 * Focus: entering the shell and switching sections moves focus to that section's
 * heading, so a keyboard or screen-reader user is told where they are. The case
 * facts overlay is a modal dialog: it traps nothing, closes on Escape or its
 * button and returns focus to the trigger that opened it.
 */

import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useAppView } from '../../composables/useAppView'
import { useTheme } from '../../composables/useTheme'
import { useTutorialSession } from '../../composables/useTutorialSession'
import Part2Brief from './Part2Brief.vue'
import Part2Value from './Part2Value.vue'
import Part2Budget from './Part2Budget.vue'
import Part2Readiness from './Part2Readiness.vue'
import Part2Recommendation from './Part2Recommendation.vue'

const { show } = useAppView()
const { theme, toggle } = useTheme()
const session = useTutorialSession()

const factsOpen = ref(false)
const factsTrigger = ref<HTMLButtonElement | null>(null)
const body = ref<HTMLElement | null>(null)

/**
 * The congratulation. It waits until the learner has genuinely worked through
 * the three exercises before the recommendation — value for money, budget impact
 * and DHT readiness, each having produced a result from the learner's own input
 * — and it is shown once per session, when the recommendation is opened. It
 * reports the state of the exercises, not the recommendation outcome: R's own
 * outcome and its completion flag are untouched.
 *
 * The popup complements the completion card rather than replacing it: it carries
 * the one new action (leaving for the full analysis), and "Back to the
 * recommendation" puts it away so the card underneath — with R's outcome and its
 * own "Retry Part 2 with different assumptions" action — is what the learner
 * works with. Escape and the backdrop do the same thing.
 */
const congratulationsOpen = ref(false)
const congratulationsOpenAnalysis = ref<HTMLButtonElement | null>(null)

watch(
  [() => session.part2Section, () => session.part2ExercisesDone],
  ([section, exercisesDone]) => {
    if (section !== 'recommend' || !exercisesDone || session.part2Congratulated) return
    session.part2Congratulated = true
    congratulationsOpen.value = true
    void nextTick(() => congratulationsOpenAnalysis.value?.focus())
  },
  { immediate: true },
)

/** Acknowledging moves the learner straight into the full analysis. */
function finishTutorial(): void {
  congratulationsOpen.value = false
  show('dashboard')
}

function dismissCongratulations(): void {
  // Escape, the backdrop and "Back to the recommendation" all close the popup
  // without navigating, so the completion card underneath — and its Retry action
  // — is exactly where the learner left it. It cannot reappear, because the
  // session has already been congratulated.
  congratulationsOpen.value = false
}

/**
 * Escape closes the popup from anywhere in the page, not only while its own
 * button has focus: the panel is an overlay, and a keyboard user must be able to
 * leave it whatever currently holds focus. stopPropagation keeps the close from
 * also reaching a disclosure's own Escape handling.
 */
function onCongratulationsKeydown(event: KeyboardEvent): void {
  if (!congratulationsOpen.value || event.key !== 'Escape' || event.defaultPrevented) return
  event.stopPropagation()
  dismissCongratulations()
}

onMounted(() => document.addEventListener('keydown', onCongratulationsKeydown))
onBeforeUnmount(() => document.removeEventListener('keydown', onCongratulationsKeydown))

onMounted(() => {
  void session.startPart2()
})

/** R's overlay title, from R's own template. */
const factsTitle = computed(() => {
  const template = session.part2Contract?.case_facts.title_template ?? ''
  const heading = session.part2CaseHeading
  const [label, title] = heading.split(' — ')
  return template
    .replace('{label}', label ?? '')
    .replace('{title}', title ?? '')
})

/**
 * The overlay's own labels. They are read once here with a fallback, so the
 * overlay cannot depend on a narrowing the template cannot express.
 */
const factsLabels = computed(() => ({
  headings: session.part2Contract?.case_facts.table_headings ?? {
    group: '',
    fact: '',
    value: '',
  },
  hint: session.part2Contract?.case_facts.hint ?? '',
  close: session.part2Contract?.case_facts.close_label ?? 'Close',
}))

const caseFacts = computed(() => ({
  rows: session.part2Facts,
}))

function openFacts(): void {
  factsOpen.value = true
  void nextTick(() => {
    document.querySelector<HTMLElement>('[data-part2-facts-close]')?.focus()
  })
}

function closeFacts(): void {
  factsOpen.value = false
  factsTrigger.value?.focus()
}

function onOverlayKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape') {
    event.stopPropagation()
    closeFacts()
  }
}

onBeforeUnmount(() => {
  factsOpen.value = false
})

// Moving to another section moves focus to its heading — unless the
// congratulation has just opened, which takes the focus itself.
watch(
  () => session.part2Section,
  async () => {
    await nextTick()
    if (congratulationsOpen.value) return
    body.value?.querySelector<HTMLElement>('.tutorial__step-title')?.focus()
  },
)

function exit(): void {
  show('home')
}
</script>

<template>
  <section class="tutorial" aria-labelledby="part2-title">
    <main v-if="session.part2ContractBusy && !session.part2Contract" class="state">
      <p>Loading the commissioning exercise…</p>
    </main>

    <main v-else-if="session.part2ContractError && !session.part2Contract" class="state">
      <h2 id="part2-title">The commissioning exercise is not reachable</h2>
      <p class="alert alert--danger">{{ session.part2ContractError }}</p>
      <button type="button" class="btn btn--primary" @click="session.loadPart2Contract()">
        Retry
      </button>
      <button type="button" class="btn btn--ghost" @click="exit()">Back to start</button>
    </main>

    <div v-else-if="session.part2Contract" ref="body" class="tutorial__body">
      <header class="tutorial__header">
        <div>
          <h1 id="part2-title" class="page__title">{{ session.part2Contract.title }}</h1>
          <p class="page__subtitle">{{ session.part2Contract.kicker }}</p>
        </div>
        <div class="tutorial__header-actions">
          <button
            ref="factsTrigger"
            type="button"
            class="btn btn--ghost"
            :disabled="!session.part2Case"
            @click="openFacts()"
          >
            {{ session.part2Contract.case_facts.button_label }}
          </button>
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
            {{ session.part2Contract.navigation.exit }}
          </button>
        </div>
      </header>

      <p v-if="session.part2Banner" class="part2__banner" data-part2-banner>
        <strong>{{ session.part2Banner }}</strong>
      </p>

      <nav class="stepper" aria-label="Commissioning sections">
        <p class="stepper__progress" aria-live="polite">{{ session.part2ProgressText }}</p>
        <ol class="stepper__list">
          <li
            v-for="(section, index) in session.part2Contract.sections"
            :key="section.key"
            class="stepper__item"
          >
            <button
              type="button"
              class="stepper__button"
              :class="{
                'is-active': section.key === session.part2Section,
                'is-done':
                  section.available &&
                  index <
                    session.part2Contract.sections.findIndex(
                      (entry) => entry.key === session.part2Section,
                    ),
                'is-locked': !section.available,
              }"
              :disabled="!section.available"
              :aria-current="section.key === session.part2Section ? 'step' : undefined"
              :title="section.available ? section.name : session.part2Contract.coming_next_label"
              @click="session.goToPart2Section(section.key)"
            >
              <span class="stepper__index" aria-hidden="true">{{ index + 1 }}</span>
              <span class="stepper__label">{{ section.name }}</span>
              <span v-if="!section.available" class="stepper__tag">
                {{ session.part2Contract.coming_next_label }}
              </span>
            </button>
          </li>
        </ol>
      </nav>

      <p v-if="session.part2Error" class="alert alert--danger">{{ session.part2Error }}</p>

      <p v-if="session.part2Busy && !session.part2Case" class="hint">
        {{ session.part2Contract.entry_busy_label }}
      </p>

      <template v-if="session.part2Case">
        <Part2Brief
          v-if="session.part2Section === 'brief'"
          :contract="session.part2Contract"
          :case-title="session.part2Case.case.title"
          :facts="session.part2Facts"
          @start="session.goToPart2Section('value')"
        />

        <template v-else-if="session.part2Section === 'value'">
          <p v-if="!session.part2Evaluation" class="hint">
            Evaluating the negotiated price…
          </p>
          <Part2Value
            v-else
            :contract="session.part2Contract"
            :evaluation="session.part2Evaluation"
            :price="session.part2Price ?? session.part2Contract.price_control.default"
            :busy="session.part2Busy"
            @update:price="session.setPart2Price"
          />
        </template>

        <template v-else-if="session.part2Section === 'budget'">
          <p v-if="!session.part2Evaluation" class="hint">
            Evaluating the coverage cap…
          </p>
          <Part2Budget
            v-else
            :contract="session.part2Contract"
            :budget="session.part2Evaluation.budget"
            :coverage="
              session.part2Coverage ?? session.part2Contract.budget.coverage_control.default
            "
            @update:coverage="session.setPart2Coverage"
            @change-price="session.goToPart2Section('value')"
          />
        </template>

        <template v-else-if="session.part2Section === 'readiness'">
          <p v-if="!session.part2Evaluation" class="hint">
            Evaluating the readiness answers…
          </p>
          <Part2Readiness
            v-else
            :readiness="session.part2Evaluation.readiness"
            :choices="session.part2Readiness"
            :busy="session.part2Busy"
            @change="session.setPart2Readiness"
          />
        </template>

        <template v-else-if="session.part2Section === 'recommend'">
          <p v-if="!session.part2Evaluation" class="hint">
            Working out the recommendation…
          </p>
          <Part2Recommendation
            v-else
            :recommendation="session.part2Evaluation.recommendation"
            :evaluation="session.part2Evaluation"
            :threshold="session.part2Contract.fixed.threshold"
            :ceiling="session.part2Contract.fixed.budget_ceiling"
            @open-full="show('dashboard')"
            @retry="session.retryPart2()"
          />
        </template>

        <nav class="tutorial__nav" aria-label="Commissioning navigation">
          <button
            v-if="session.part2BackTarget"
            type="button"
            class="btn btn--ghost"
            @click="session.goToPart2Section(session.part2BackTarget.key)"
          >
            {{ session.part2Contract.navigation.back }}
          </button>
          <button
            v-if="session.part2ForwardTarget"
            type="button"
            class="btn btn--primary"
            @click="session.goToPart2Section(session.part2ForwardTarget.key)"
          >
            {{ session.part2Contract.navigation.forward }}
          </button>
          <button type="button" class="btn btn--ghost" @click="session.leavePart2()">
            Back to the tutorial summary
          </button>
        </nav>
      </template>
    </div>

    <!-- The read-only case facts. Every row is R's; nothing is computed. -->
    <div
      v-if="factsOpen"
      class="modal"
      role="dialog"
      aria-modal="true"
      :aria-label="factsTitle"
      @keydown="onOverlayKeydown"
    >
      <div class="modal__backdrop" @click="closeFacts()"></div>
      <div class="modal__panel">
        <h2 class="modal__title">{{ factsTitle }}</h2>
        <div class="table-scroll">
          <table class="table table--wrap" :aria-label="factsTitle">
            <thead>
              <tr>
                <th scope="col">{{ factsLabels.headings.group }}</th>
                <th scope="col">{{ factsLabels.headings.fact }}</th>
                <th scope="col">{{ factsLabels.headings.value }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in caseFacts.rows" :key="`${row.group}-${row.fact}`">
                <th scope="row">{{ row.group }}</th>
                <td>{{ row.fact }}</td>
                <td>{{ row.value }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="field__hint">{{ factsLabels.hint }}</p>
        <div class="tutorial__nav">
          <button
            type="button"
            class="btn btn--primary"
            data-part2-facts-close
            @click="closeFacts()"
          >
            {{ factsLabels.close }}
          </button>
        </div>
      </div>
    </div>
    <!-- The congratulation, once the three exercises before the recommendation
         have been worked through. It reuses the app's modal pattern and closes
         on Escape, on the backdrop or through its own action. -->
    <div
      v-if="congratulationsOpen"
      class="modal"
      role="dialog"
      aria-modal="true"
      aria-labelledby="part2-congratulations-title"
      @keydown="onCongratulationsKeydown"
    >
      <div class="modal__backdrop" @click="dismissCongratulations()"></div>
      <div class="modal__panel modal__panel--welcome">
        <h2 id="part2-congratulations-title" class="modal__title">
          Congratulations — you've finished the tutorial
        </h2>
        <p class="page__prose">
          You've completed the guided introduction to health technology assessment. Major
          expansions are planned for the tutorial section — stay tuned for the next blog post!
        </p>
        <div class="tutorial__nav">
          <button
            ref="congratulationsOpenAnalysis"
            type="button"
            class="btn btn--primary"
            @click="finishTutorial()"
          >
            Open analysis
          </button>
          <button type="button" class="btn btn--ghost" @click="dismissCongratulations()">
            Back to the recommendation
          </button>
        </div>
      </div>
    </div>
  </section>
</template>
