<script setup lang="ts">
/**
 * Step 1: base cost-effectiveness.
 *
 * The teaching text, the five control labels and ranges, the fixed post-event
 * utilities (R's own tutorial constants, not the dashboard's utility fields), the
 * result table and the plane's points and titles all come from R. The two status
 * words a client could otherwise invent — an uninterpretable ICER and the fixed
 * utilities block — are rendered exactly as R sent them.
 */

import { computed } from 'vue'
import type { Column } from '../table'
import type {
  TutorialContract,
  TutorialPart1Response,
  TutorialStepCopy,
} from '../../api/types'
import DataTable from '../DataTable.vue'
import TutorialCePlane from './TutorialCePlane.vue'
import TutorialControl from './TutorialControl.vue'

const props = defineProps<{
  copy: TutorialStepCopy
  contract: TutorialContract
  controls: TutorialContract['controls']
  result: TutorialPart1Response
  values: Record<string, number | boolean | undefined>
}>()

const emit = defineEmits<{ change: [id: string, value: number | boolean] }>()

const columns = computed<Column<TutorialPart1Response['ce']['table'][number]>[]>(() => [
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
])
</script>

<template>
  <section class="tutorial__step" aria-labelledby="tutorial-step-title">
    <h3 id="tutorial-step-title" class="tutorial__step-title" tabindex="-1">{{ copy.title }}</h3>
    <p class="tutorial__intro">{{ copy.intro }}</p>
    <ul v-if="copy.explain.length" class="list tutorial__explain">
      <li v-for="line in copy.explain" :key="line">{{ line }}</li>
    </ul>

    <h4 class="tutorial__heading">{{ copy.controls_heading }}</h4>
    <div class="controls controls--stacked tutorial__controls">
      <TutorialControl
        v-for="control in controls"
        :key="control.id"
        :control="control"
        :value="values[control.id]"
        @update:value="(value) => emit('change', control.id, value)"
      />
    </div>

    <div class="tutorial__fixed">
      <p class="tutorial__fixed-title">{{ contract.fixed.post_event_utilities.title }}</p>
      <ul class="list">
        <li
          v-for="item in contract.fixed.post_event_utilities.items"
          :key="item"
        >
          {{ item }}
        </li>
      </ul>
      <p class="field__hint">{{ contract.fixed.post_event_utilities.hint }}</p>
    </div>

    <h4 class="tutorial__heading">{{ copy.result_heading }}</h4>
    <DataTable
      :columns="columns"
      :rows="result.ce.table"
      :label="copy.result_heading"
    />
    <TutorialCePlane :chart="result.ce.chart" />
  </section>
</template>
