<script setup lang="ts">
/**
 * Step 2: budget impact.
 *
 * The step explains its heading through the contract's own explanation string,
 * names the Step-1 price R used, shows R's five-year total sentence and keeps the
 * annual table and its chart in a closed disclosure, as the reference tutorial
 * does. The chart series is the same row shape the budget-impact endpoint
 * returns, so the existing chart component is reused unchanged.
 */

import { computed } from 'vue'
import type { Column } from '../table'
import type {
  TutorialBiaTableRow,
  TutorialContract,
  TutorialPart1Response,
  TutorialStepCopy,
} from '../../api/types'
import BudgetImpactChart from '../charts/BudgetImpactChart.vue'
import DataTable from '../DataTable.vue'
import InfoTip from '../InfoTip.vue'
import TutorialControl from './TutorialControl.vue'

const props = defineProps<{
  copy: TutorialStepCopy
  contract: TutorialContract
  controls: TutorialContract['controls']
  result: TutorialPart1Response
  values: Record<string, number | boolean | undefined>
}>()

const emit = defineEmits<{
  change: [id: string, value: number | boolean]
  adjustPrice: []
}>()

const columns = computed<Column<TutorialBiaTableRow>[]>(() => [
  {
    key: 'year',
    label: props.contract.table_headings.year,
    value: (row) => String(row.year),
  },
  {
    key: 'active_users',
    label: props.contract.table_headings.active_users,
    value: (row) => row.active_users,
    align: 'right',
  },
  {
    key: 'net',
    label: props.contract.table_headings.net_budget_impact,
    value: (row) => row.net_budget_impact,
    align: 'right',
  },
])

const headingInfo = (copy: TutorialStepCopy): string =>
  (copy.heading_info_key && props.contract.headings[copy.heading_info_key]) || ''
</script>

<template>
  <section class="tutorial__step" aria-labelledby="tutorial-step-title">
    <h3 id="tutorial-step-title" class="tutorial__step-title" tabindex="-1">
      {{ copy.title }}
      <InfoTip
        v-if="headingInfo(copy)"
        :text="headingInfo(copy)"
        :topic="copy.heading_info_topic ?? 'this step'"
      />
    </h3>
    <p class="tutorial__intro">{{ copy.intro }}</p>

    <div class="controls controls--stacked tutorial__controls">
      <TutorialControl
        v-for="control in controls"
        :key="control.id"
        :control="control"
        :value="values[control.id]"
        @update:value="(value) => emit('change', control.id, value)"
      />
    </div>

    <p class="tutorial__linked">
      <span>{{ result.bia.linked_price_sentence }}</span>
      <button type="button" class="btn btn--ghost btn--tiny" @click="emit('adjustPrice')">
        {{ copy.linked_price_label }}
      </button>
    </p>

    <h4 class="tutorial__heading">{{ copy.result_heading }}</h4>
    <p class="alert alert--info">{{ result.bia.total_sentence }}</p>

    <details class="details">
      <summary>{{ copy.disclosure_label }}</summary>
      <DataTable
        :columns="columns"
        :rows="result.bia.table"
        :label="`${copy.result_heading} — ${copy.disclosure_label}`"
      />
      <div class="chart">
        <div class="chart__note">{{ result.bia.chart.title }}</div>
        <BudgetImpactChart :rows="result.bia.rows" />
      </div>
    </details>
  </section>
</template>
