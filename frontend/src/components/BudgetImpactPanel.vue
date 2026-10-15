<script setup lang="ts">
/**
 * Five-year deterministic budget impact from the payer's point of view.
 *
 * The engagement assumption for follow-up years is not editable here: the model
 * takes it from the scenario engagement input in the assumptions panel, the same
 * way the Shiny app reads it from Global Settings, so there is one engagement
 * control in the app.
 */

import { computed } from 'vue'
import type { BudgetImpactRow } from '../api/types'
import { formatCount, formatEuro, formatPercent } from '../format'
import { useModel } from '../composables/useModel'
import { useResultEntrance } from '../composables/useResultEntrance'
import InfoTip from './InfoTip.vue'
import ButtonLabel from './ButtonLabel.vue'
import BudgetImpactChart from './charts/BudgetImpactChart.vue'
import DataTable from './DataTable.vue'
import MetricCard from './MetricCard.vue'
import ResultTrace from './ResultTrace.vue'
import StaleNotice from './StaleNotice.vue'
import type { Column } from './table'

const model = useModel()
// The entrance this tab's result plays when it is committed; see the composable.
const { revealClass } = useResultEntrance('budget')

const result = computed(() => model.budget)
const rows = computed<BudgetImpactRow[]>(() => result.value?.table ?? [])

const columns: Column<BudgetImpactRow>[] = [
  { key: 'year', label: 'Year', value: (row) => String(row.year) },
  {
    key: 'uptake',
    label: 'Uptake',
    align: 'right',
    value: (row) => formatPercent((row.uptake_pct ?? 0) / 100),
  },
  {
    key: 'new_users',
    label: 'New users',
    align: 'right',
    value: (row) => formatCount(row.new_users),
  },
  {
    key: 'active_users',
    label: 'Active users',
    align: 'right',
    value: (row) => formatCount(row.active_users),
  },
  {
    key: 'intervention',
    label: 'Intervention cost',
    align: 'right',
    value: (row) => formatEuro(row.gross_intervention_cost),
  },
  {
    key: 'implementation',
    label: 'Implementation',
    align: 'right',
    value: (row) => formatEuro(row.implementation_cost),
  },
  {
    key: 'savings',
    label: 'Healthcare savings',
    align: 'right',
    value: (row) => formatEuro(row.healthcare_savings),
    tone: () => 'good',
  },
  {
    key: 'avoided',
    label: 'Avoided-event savings',
    align: 'right',
    value: (row) => formatEuro(row.avoided_event_savings),
    tone: () => 'good',
  },
  {
    key: 'net',
    label: 'Net impact',
    align: 'right',
    value: (row) => formatEuro(row.net_budget_impact),
    tone: (row) => (row.net_budget_impact !== null && row.net_budget_impact <= 0 ? 'good' : 'bad'),
  },
  {
    key: 'cumulative',
    label: 'Cumulative',
    align: 'right',
    value: (row) => formatEuro(row.cumulative_budget_impact),
  },
]

/** The explanations for the two controls that are not model parameters. */
const populationInfo = computed(() => model.defaults?.info_text?.population_size ?? '')
const uptakeInfo = computed(() => model.defaults?.info_text?.uptake ?? '')</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <h2>Budget impact</h2>
        <ResultTrace :reveal-class="revealClass" />
        <p class="muted">
          Deterministic, undiscounted, per year. Uptake starts at the year-1 percentage and grows by
          the annual increment; engagement decides how many users are active.
        </p>
      </div>
      <button
        type="button"
        class="btn btn--primary"
        :disabled="model.busy.budget"
        @click="model.runBudget()"
      >
        <ButtonLabel :busy="model.busy.budget" idle="Run budget impact" pending="Running…" />
      </button>
    </header>

    <p v-if="model.errors.budget" class="alert alert--danger">{{ model.errors.budget }}</p>

    <StaleNotice v-if="result && model.budgetStale" action="Run budget impact" />

    <div class="controls controls--stacked">
      <div class="field">
        <label for="bia-population">Clinical target population</label>
        <InfoTip :text="populationInfo" topic="the clinical target population" />
        <div class="field__control">
          <input id="bia-population" v-model.number="model.targetPopulation" type="number" min="0" step="1000" />
        </div>
        <p class="field__hint">Shared with DHT readiness.</p>
      </div>

      <div class="field">
        <label for="bia-year1-uptake">Year-1 uptake</label>
        <InfoTip :text="uptakeInfo" topic="year-1 uptake" />
        <div class="field__control">
          <input
            id="bia-year1-uptake"
            v-model.number="model.budgetInputs.year1UptakePct"
            type="number"
            min="0"
            max="100"
            step="1"
          />
          <span class="field__unit">%</span>
        </div>
      </div>

      <div class="field">
        <label for="bia-annual-increase">Annual increase</label>
        <InfoTip
          text="Percentage points added to uptake each year, up to a maximum of 100%."
          topic="the annual uptake increase"
        />
        <div class="field__control">
          <input
            id="bia-annual-increase"
            v-model.number="model.budgetInputs.annualUptakeIncreasePp"
            type="number"
            min="0"
            max="100"
            step="1"
          />
          <span class="field__unit">pp</span>
        </div>
      </div>

      <div class="field">
        <label for="bia-horizon">Horizon</label>
        <div class="field__control">
          <input id="bia-horizon" v-model.number="model.budgetInputs.horizonYears" type="number" min="1" max="40" step="1" />
          <span class="field__unit">years</span>
        </div>
      </div>

      <div class="field">
        <label for="bia-avoided-event-savings">Avoided-event savings per active user</label>
        <InfoTip
          text="Left at 0, the budget impact reflects the intervention cost and healthcare savings only."
          topic="the avoided-event savings per active user"
        />
        <div class="field__control">
          <input
            id="bia-avoided-event-savings"
            v-model.number="model.budgetInputs.avoidedEventSavingsPerActiveUser"
            type="number"
            min="0"
            step="10"
          />
          <span class="field__unit">€</span>
        </div>
      </div>
    </div>

    <p v-if="!result && !model.busy.budget" class="hint">
      Use the run button after editing the inputs; the chart and the table always show the run that
      matches these inputs.
    </p>

    <div v-if="result" class="result-reveal" :class="revealClass">
      <div class="metrics">
        <MetricCard
          label="Cumulative net budget impact"
          :value="formatEuro(result.cumulative_net_budget_impact)"
          :tone="
            result.cumulative_net_budget_impact !== null && result.cumulative_net_budget_impact <= 0
              ? 'good'
              : 'bad'
          "
          :sub="`over ${result.horizon_years} years`"
        />
        <MetricCard
          label="Intervention cost"
          :value="formatEuro(result.total_intervention_cost)"
          sub="gross, all years"
        />
        <MetricCard
          label="Implementation cost"
          :value="formatEuro(result.total_implementation_cost)"
          sub="one-off per new user"
        />
        <MetricCard
          label="Healthcare savings"
          :value="formatEuro(result.total_healthcare_savings)"
          sub="offsetting the intervention"
        />
      </div>

      <figure class="chart-figure">
        <figcaption>Net and cumulative budget impact</figcaption>
        <BudgetImpactChart :rows="rows" />
      </figure>

      <DataTable :columns="columns" :rows="rows" caption="Budget impact by year (EUR)" />
    </div>
  </section>
</template>
