<script setup lang="ts">
/**
 * Part 2, section 4: the DHT readiness exercise.
 *
 * The four questions and their answer wording are presentation copy and live
 * here; the level ids the answers are sent as, and the reach and workload line
 * under them, come from R. The component never maps an answer onto a readiness
 * input and never grades a domain — it renders R's readiness result for the
 * answers it sent.
 *
 * This section deliberately reports no traffic light. The readiness statuses and
 * the deliverability verdict are R's, they are still returned by the evaluation
 * and kept in the session, and they belong to the Recommendation section that
 * follows — the reference tutorial shows them there, not here.
 *
 * Choosing an answer re-evaluates through the same coalesced Part 2 request the
 * price and coverage levers use, so all four sections always describe one case
 * at one set of answers. The reach and workload figures sit in one closed
 * disclosure, which opens by mouse, Enter or Space and closes with Escape (the
 * app-wide disclosure behaviour).
 */

import type { Column } from '../table'
import type {
  Part2ReadinessChoices,
  Part2ReadinessField,
  Part2ReadinessNumber,
  Part2ReadinessResult,
} from '../../api/types'
import DataTable from '../DataTable.vue'
import InfoTip from '../InfoTip.vue'

interface ReadinessOption {
  value: string
  label: string
}

interface ReadinessQuestion {
  field: Part2ReadinessField
  legend: string
  options: ReadinessOption[]
}

/**
 * The four questions, in the reference tutorial's own order and with its own
 * answer wording. The strongest answer deliberately sits in a different position
 * in each question, so the exercise cannot be completed by always picking the
 * same place. The values are the level ids R validates and maps onto the
 * readiness inputs it uses.
 */
const QUESTIONS: ReadinessQuestion[] = [
  {
    field: 'interoperability',
    legend: 'How would this programme exchange information with existing clinical systems?',
    options: [
      {
        value: 'basic',
        label:
          'Limited connection: data can be exchanged in some situations, but staff still use manual workarounds.',
      },
      {
        value: 'strong',
        label:
          'Standards-based connection: structured data exchange with the relevant systems and minimal manual re-entry.',
      },
      {
        value: 'no',
        label: 'No connection: staff manually re-enter programme information.',
      },
    ],
  },
  {
    field: 'governance',
    legend: 'How is the algorithm governed after implementation?',
    options: [
      {
        value: 'strong',
        label:
          'Ongoing governance: documented validation, named accountability, monitoring for drift and bias, human oversight, and a process for responding to problems.',
      },
      {
        value: 'weak',
        label: 'No formal oversight: no documented validation, monitoring, or named owner.',
      },
      {
        value: 'partial',
        label:
          'Initial review only: the algorithm is documented and reviewed at launch, but there is no regular monitoring plan.',
      },
    ],
  },
  {
    field: 'clinical_workflow',
    legend: 'How would the programme fit into routine clinical work?',
    options: [
      {
        value: 'high',
        label:
          'High burden: substantial extra review, duplicate documentation, or major workflow disruption.',
      },
      {
        value: 'moderate',
        label: 'Moderate burden: some additional review, training, or workflow adjustment.',
      },
      {
        value: 'low',
        label: 'Low burden: limited additional work and a good fit with existing workflows.',
      },
    ],
  },
  {
    field: 'patient_engagement',
    legend: 'What level of follow-up engagement should this case assume?',
    options: [
      { value: 'low', label: 'Low engagement: 30% remain engaged at follow-up.' },
      {
        value: 'moderate',
        label: 'Moderate engagement: 60% remain engaged at follow-up.',
      },
      { value: 'high', label: 'High engagement: 90% remain engaged at follow-up.' },
    ],
  },
]

defineProps<{
  readiness: Part2ReadinessResult
  choices: Part2ReadinessChoices
  busy: boolean
}>()

const emit = defineEmits<{ change: [field: Part2ReadinessField, value: string] }>()

/**
 * How the exercise behaves, behind the task's information control: the paragraph
 * that used to sit under the heading, plus the note about engagement. Both are
 * the client's own presentation copy, so no R wording moves.
 */
const readinessIntro =
  'Answer the four questions for this setting. These choices change the readiness ' +
  'assessment only: the negotiated price, the price curve and the budget impact stay as ' +
  'you left them. Engagement is included for learning and is not fully controllable by ' +
  'the commissioning team.'

const numberColumns: Column<Part2ReadinessNumber>[] = [
  { key: 'measure', label: 'Measure', value: (row) => row.measure },
  { key: 'value', label: 'Value', value: (row) => row.value, align: 'right' },
]
</script>

<template>
  <section class="tutorial__step" aria-labelledby="part2-readiness-title">
    <h3 id="part2-readiness-title" class="tutorial__step-title" tabindex="-1">
      DHT readiness
    </h3>
    <p class="part2__task">
      Choose the implementation approach you would recommend, then consider its delivery
      consequences.
      <InfoTip :text="readinessIntro" topic="the readiness questions" />
    </p>

    <div class="part2__questions">
      <fieldset
        v-for="(question, index) in QUESTIONS"
        :key="question.field"
        class="part2__question"
        :data-part2-question="question.field"
      >
        <legend class="part2__question-legend">
          {{ index + 1 }}. {{ question.legend }}
        </legend>
        <label
          v-for="option in question.options"
          :key="option.value"
          class="part2__option"
        >
          <input
            type="radio"
            :name="question.field"
            :value="option.value"
            :checked="choices[question.field] === option.value"
            @change="emit('change', question.field, option.value)"
          />
          <span>{{ option.label }}</span>
        </label>
      </fieldset>
    </div>

    <p class="field__hint" data-part2-readiness-note>{{ readiness.note }}</p>

    <p class="tutorial__live muted" aria-live="polite">
      {{ busy ? 'Updating the readiness result…' : 'Result updated.' }}
    </p>

    <details class="details">
      <summary>View readiness calculations</summary>
      <DataTable
        :columns="numberColumns"
        :rows="readiness.numbers"
        label="Reach and workload figures from the readiness assessment"
      />
      <p class="field__hint">
        Readiness inputs used: interoperability {{ readiness.inputs.interoperability }};
        governance {{ readiness.inputs.algorithm_governance }}; review
        {{ readiness.inputs.review_minutes }} minutes per patient per month; follow-up
        engagement {{ readiness.inputs.followup_engagement_pct }}%.
      </p>
    </details>
  </section>
</template>
