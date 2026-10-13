<script setup lang="ts">
/**
 * Part 2, section 3: the budget-impact exercise.
 *
 * One control — the coverage cap — and R's answer to it. The task, the population
 * and covered-population sentences, the four affordability states and their
 * messages, the maximum affordable coverage R found, the five-year summary, the
 * annual rows and the chart series all come from R. This component never measures
 * affordability, never searches for a maximum and never totals a column.
 *
 * The full annual breakdown lives in one closed disclosure, which opens by mouse,
 * Enter or Space and closes with Escape (the app-wide disclosure behaviour), and
 * the table scrolls inside itself at narrow widths.
 */

import { computed } from 'vue'
import type { Column } from '../table'
import type { Part2BudgetResult, Part2BudgetRow, Part2Contract } from '../../api/types'
import InfoTip from '../InfoTip.vue'
import DataTable from '../DataTable.vue'
import Part2BudgetChart from './Part2BudgetChart.vue'

const props = defineProps<{
  contract: Part2Contract
  budget: Part2BudgetResult
  coverage: number
}>()

const emit = defineEmits<{ 'update:coverage': [number]; changePrice: [] }>()

const control = computed(() => props.contract.budget.coverage_control)

/**
 * The coverage lever's explanation, this section's scope note and the sentence
 * about phased adoption, in the one popover the control already carries. All
 * three are R's text; joining them is presentation only, and it keeps the
 * explanation out of the visible column.
 */
const coverageInfo = computed(() =>
  [control.value.info, props.budget.strings.scope_note, props.budget.full_rollout_sentence].join(
    ' ',
  ),
)

/** R's state for the current coverage cap decides the card's tone. */
const toneClass = computed(() => {
  if (props.budget.at_max) return 'status-card status-card--good'
  return 'status-card status-card--warning'
})

const columns = computed<Column<Part2BudgetRow>[]>(() => {
  const headings = props.budget.strings.table.headings
  return [
    { key: 'year', label: headings.year, value: (row) => String(row.year) },
    {
      key: 'active_users',
      label: headings.activated_users,
      value: (row) => row.active_users_display,
      align: 'right',
    },
    {
      key: 'net',
      label: headings.net_budget_impact,
      value: (row) => row.net_budget_impact_display,
      align: 'right',
    },
    {
      key: 'cumulative',
      label: headings.cumulative,
      value: (row) => row.cumulative_display,
      align: 'right',
    },
  ]
})
</script>

<template>
  <section class="tutorial__step" aria-labelledby="part2-budget-title">
    <h3 id="part2-budget-title" class="tutorial__step-title" tabindex="-1">
      {{ contract.budget.heading }}
    </h3>
    <p class="part2__task">
      {{ budget.strings.task }}
      <InfoTip :text="budget.strings.note" topic="this test" />
    </p>

    <p class="part2__population">{{ budget.population_sentence }}</p>

    <div class="controls controls--stacked tutorial__controls">
      <div class="field">
        <label for="part2-coverage">{{ control.label }}</label>
        <InfoTip :text="coverageInfo" :topic="control.info_topic" />
        <div class="field__control">
          <input
            id="part2-coverage"
            type="range"
            :min="control.min"
            :max="control.max"
            :step="control.step"
            :value="coverage"
            :aria-valuetext="`${coverage}${control.unit}`"
            @input="emit('update:coverage', Number(($event.target as HTMLInputElement).value))"
          />
          <output for="part2-coverage" class="field__value">{{ coverage }}</output>
          <span class="field__unit">{{ control.unit }}</span>
        </div>
      </div>
    </div>

    <h4 class="tutorial__heading">{{ contract.budget.result_heading }}</h4>

    <article :class="toneClass" :data-part2-budget-state="budget.state">
      <h4 class="status-card__title">
        {{ budget.state_message }}
        <span class="badge">{{ budget.total_display }}</span>
      </h4>
      <p class="status-card__values">{{ budget.summary }}</p>
      <p class="status-card__values">{{ budget.covered_sentence }}</p>
      <p class="field__hint">{{ budget.state_hint }}</p>
    </article>

    <div class="part2__lever">
      <p class="part2__lever-line">{{ budget.lever_sentence }}</p>
    </div>

    <p v-if="budget.price_shortcut.show" class="part2__shortcut">
      <button type="button" class="btn btn--ghost btn--tiny" @click="emit('changePrice')">
        {{ budget.price_shortcut.label }}
      </button>
      <span class="field__hint">{{ budget.price_shortcut.note }}</span>
    </p>

    <Part2BudgetChart :budget="budget" />

    <details class="details">
      <summary>{{ budget.strings.table.disclosure_label }}</summary>
      <DataTable
        :columns="columns"
        :rows="budget.rows"
        :label="`${contract.budget.heading} — ${budget.strings.table.caption}`"
      />
    </details>
  </section>
</template>
