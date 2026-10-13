<script setup lang="ts">
/**
 * Step 3: DHT readiness.
 *
 * The status of every domain, R's Engagement wording for this step, the reach and
 * workload figures and the sentence naming the two domains the yes/no answers set
 * all come from R's readiness assessment, so the traffic light the learner sees
 * here is the same rule the full readiness assessment uses. The engagement
 * assumptions are the Step-1 values — the deliberate carry-over the reference
 * tutorial makes — and R's own note says so.
 */

import { computed } from 'vue'
import type { Column } from '../table'
import type {
  TutorialContract,
  TutorialPart1Response,
  TutorialReadinessNumber,
  TutorialStepCopy,
} from '../../api/types'
import DataTable from '../DataTable.vue'
import InfoTip from '../InfoTip.vue'
import TutorialControl from './TutorialControl.vue'
import TutorialStatusCard from './TutorialStatusCard.vue'

const props = defineProps<{
  copy: TutorialStepCopy
  contract: TutorialContract
  controls: TutorialContract['controls']
  result: TutorialPart1Response
  values: Record<string, number | boolean | undefined>
}>()

const emit = defineEmits<{ change: [id: string, value: number | boolean] }>()

const numberColumns = computed<Column<TutorialReadinessNumber>[]>(() => [
  {
    key: 'measure',
    label: props.contract.table_headings.measure,
    value: (row) => row.measure,
  },
  {
    key: 'value',
    label: props.contract.table_headings.value,
    value: (row) => row.value,
    align: 'right',
  },
  {
    key: 'basis',
    label: props.contract.table_headings.basis,
    value: (row) => row.basis,
  },
])

const headingInfo = computed(
  () =>
    (props.copy.heading_info_key && props.contract.headings[props.copy.heading_info_key]) || '',
)
</script>

<template>
  <section class="tutorial__step" aria-labelledby="tutorial-step-title">
    <h3 id="tutorial-step-title" class="tutorial__step-title" tabindex="-1">
      {{ copy.title }}
      <InfoTip
        v-if="headingInfo"
        :text="headingInfo"
        :topic="copy.heading_info_topic ?? 'this step'"
      />
    </h3>
    <p class="tutorial__intro">{{ copy.intro }}</p>

    <h4 class="tutorial__heading">{{ copy.domains_heading }}</h4>
    <div class="status-cards">
      <TutorialStatusCard
        v-for="card in result.readiness.cards"
        :key="card.domain"
        :title="card.domain"
        :status="card.status"
        :measure-label="contract.table_headings.current_values"
        :text="card.explanation"
      />
    </div>
    <p class="field__hint">{{ copy.engagement_note }}</p>

    <div class="controls controls--stacked tutorial__controls">
      <TutorialControl
        v-for="control in controls"
        :key="control.id"
        :control="control"
        :value="values[control.id]"
        @update:value="(value) => emit('change', control.id, value)"
      />
    </div>

    <h4 class="tutorial__heading">{{ copy.conditions_heading }}</h4>
    <p v-if="result.readiness.checks_sentence" class="field__hint">
      <strong>{{ contract.labels.readiness_checks }}</strong>{{ result.readiness.checks_sentence }}
    </p>
    <p class="field__hint">{{ copy.conditions_note }}</p>

    <details class="details">
      <summary>{{ copy.disclosure_label }}</summary>
      <DataTable
        :columns="numberColumns"
        :rows="result.readiness.numbers"
        :label="`${copy.domains_heading} — ${copy.disclosure_label}`"
      />
    </details>
  </section>
</template>
