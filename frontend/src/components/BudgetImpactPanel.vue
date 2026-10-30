<script setup lang="ts">
/**
 * Five-year deterministic budget impact from the payer's point of view.
 *
 * The engagement assumption for follow-up years is not editable here: the model
 * takes it from the scenario engagement input in the assumptions panel, the same
 * way the Shiny app reads it from Global Settings, so there is one engagement
 * control in the app.
 */

import { computed, ref, shallowRef } from 'vue'
import type { BudgetImpactResponse, BudgetImpactRow } from '../api/types'
import { formatCount, formatEuro, formatPercent } from '../format'
import { useModel } from '../composables/useModel'
import { useAppView } from '../composables/useAppView'
import { useResultEntrance } from '../composables/useResultEntrance'
import InfoTip from './InfoTip.vue'
import MethodInfo from './MethodInfo.vue'
import ButtonLabel from './ButtonLabel.vue'
import ChartDownload from './ChartDownload.vue'
import BudgetImpactChart from './charts/BudgetImpactChart.vue'
import DataTable from './DataTable.vue'
import MetricCard from './MetricCard.vue'
import ResultTrace from './ResultTrace.vue'
import StaleNotice from './StaleNotice.vue'
import PresentationOverlay from './presentation/PresentationOverlay.vue'
import PresentationSettings, {
  type PresentationSetting,
} from './presentation/PresentationSettings.vue'
import { movedSentence, supersededSentence, settingRow } from './presentation/settings'
import type { Column } from './table'

const model = useModel()

const { showJourneyExplainer } = useAppView()

/**
 * Opens this module's lesson from the Guided tutorial as a standalone explainer.
 *
 * The lesson charges the tutorial's own fixed price and reads none of the settings on
 * this panel, so the stored budget result behind this panel is untouched when the
 * learner comes back. The chapter id is R's, and the journey screen decides what it
 * can open.
 */
function openExplainer(): void {
  showJourneyExplainer('budget')
}

// The entrance this tab's result plays when it is committed; see the composable.
const { revealClass } = useResultEntrance('budget')

const result = computed(() => model.budget)
const rows = computed<BudgetImpactRow[]>(() => result.value?.table ?? [])

/**
 * The one line the result area carries while there is no result yet: the wait,
 * while the request is in flight, and the guidance to start otherwise.
 */
const stateLine = computed(() =>
  model.busy.budget
    ? 'Running the budget impact with these inputs.'
    : 'Start with the default inputs, then select Run budget impact.',
)

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
const uptakeInfo = computed(() => model.defaults?.info_text?.uptake ?? '')

// --- Presentation mode -------------------------------------------------------

/**
 * The budget-impact run being presented, held as the response itself. The horizon,
 * the population, the five settings R was sent and the whole yearly table are in
 * that response, so the overlay stays a view of the run whatever the panel's
 * controls do afterwards.
 */
const presented = shallowRef<BudgetImpactResponse | null>(null)
const presentButton = ref<HTMLButtonElement | null>(null)
const presentedRows = computed<BudgetImpactRow[]>(() => presented.value?.table ?? [])

/** The revision of this tab's stored result when the overlay was opened. */
const presentedRevision = ref(0)

function openPresentation(): void {
  presented.value = result.value
  presentedRevision.value = model.resultRevisions.budget
}

/** The line shown when a later run has replaced this result while it is open. */
const presentedSuperseded = computed(() =>
  presented.value !== null && model.resultRevisions.budget !== presentedRevision.value
    ? supersededSentence()
    : '',
)

function closePresentation(): void {
  presented.value = null
}

/**
 * The run's settings. Population and horizon are the response's own; the five
 * input values are the ones R reports for the run; the year-1 uptake is the first
 * row of the table it returned. The annual increase and the avoided-event saving
 * are not in the response, so they are listed only while the tab's own comparison
 * says the stored run still matches the controls, and named as a limitation when
 * it does not.
 */
const presentedSettings = computed<PresentationSetting[]>(() => {
  const run = presented.value
  if (!run) return []
  const first = run.table[0]
  const rows: PresentationSetting[] = [
    settingRow('population', 'Clinical target population', formatCount(run.population), 'people'),
    settingRow('horizon', 'Horizon', String(run.horizon_years), 'years'),
    settingRow('year1', 'Year-1 uptake', formatPercent((first?.uptake_pct ?? 0) / 100), '%'),
    settingRow(
      'price',
      'Annual intervention price',
      formatEuro(run.inputs.intervention_price, 2),
      '€',
    ),
    settingRow(
      'implementation',
      'Implementation cost (one-off)',
      formatEuro(run.inputs.implementation_cost_per_new_user, 2),
      '€',
    ),
    settingRow(
      'savings',
      'Annual healthcare-use savings',
      formatEuro(run.inputs.healthcare_savings_per_active_user, 2),
      '€',
    ),
    settingRow(
      'avoided',
      'Avoided-event savings per active user',
      formatEuro(run.inputs.avoided_event_savings_per_active_user, 2),
      '€',
    ),
    settingRow(
      'engagement',
      'Follow-up engagement',
      formatPercent((run.inputs.followup_engagement_pct ?? 0) / 100),
      '%',
    ),
  ]
  if (!model.budgetStale) {
    rows.splice(
      3,
      0,
      settingRow('increase', 'Annual increase', String(model.budgetInputs.annualUptakeIncreasePp), 'pp'),
    )
  }
  return rows
})

const presentedStale = computed(() =>
  presented.value && model.budgetStale
    ? movedSentence(['the budget inputs or the shared assumptions'])
    : '',
)

const settingsNote = computed(() =>
  model.budgetStale
    ? 'Only what this run returned is listed: the inputs that produced it have been changed since, so the panel’s controls are not shown as the run’s.'
    : 'Every figure here is this run’s own, from its response; the annual increase is listed because the panel’s inputs still match the ones this run was sent with.',
)
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <div class="panel__title-row">
          <h2>Budget impact</h2>
          <MethodInfo module="budget" />
        </div>
        <ResultTrace :reveal-class="revealClass" />
        <p class="muted">
          What could implementation mean for the budget — deterministic, undiscounted, per year?
        </p>
      </div>
      <div class="panel__actions">
        <button
          type="button"
          class="btn btn--primary"
          :disabled="model.busy.budget"
          @click="model.runBudget()"
        >
          <ButtonLabel :busy="model.busy.budget" idle="Run budget impact" pending="Running the budget impact…" />
        </button>
        <button
          type="button"
          class="btn btn--ghost"
          title="Read this module's lesson on its own, in The Journey. It uses The Journey's own worked example at the case's fixed price, not your analysis settings, and returns here when you are done."
          @click="openExplainer()"
        >
          Explain this
        </button>
        <button
          v-if="result"
          ref="presentButton"
          type="button"
          class="btn btn--ghost"
          title="Show this result full screen, for a screen share or discussion"
          @click="openPresentation()"
        >
          Present
        </button>
      </div>
    </header>

    <p v-if="model.errors.budget" class="alert alert--danger" role="alert">
      {{ model.errors.budget }}
    </p>

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

    <p v-if="!result" class="hint" role="status">
      {{ stateLine }}
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
        <ChartDownload filename="budget-impact-net-and-cumulative.png" name="budget impact" />
      </figure>

      <DataTable :columns="columns" :rows="rows" caption="Budget impact by year (EUR)" />
    </div>

    <!-- Presentation mode: the run's own horizon, population and yearly table. -->
    <PresentationOverlay
      v-if="presented"
      title="Budget impact"
      :notice="presented.notice"
      :stale="presentedStale"
      :settings-note="settingsNote"
      :superseded="presentedSuperseded"
      :fallback-focus="() => presentButton"
      @close="closePresentation()"
    >
      <div class="metrics present__metrics">
        <MetricCard
          label="Cumulative net budget impact"
          :value="formatEuro(presented.cumulative_net_budget_impact)"
          :tone="
            presented.cumulative_net_budget_impact !== null &&
            presented.cumulative_net_budget_impact <= 0
              ? 'good'
              : 'bad'
          "
          :sub="`over ${presented.horizon_years} years`"
        />
        <MetricCard
          label="Intervention cost"
          :value="formatEuro(presented.total_intervention_cost)"
          sub="gross, all years"
        />
        <MetricCard
          label="Implementation cost"
          :value="formatEuro(presented.total_implementation_cost)"
          sub="one-off per new user"
        />
        <MetricCard
          label="Healthcare savings"
          :value="formatEuro(presented.total_healthcare_savings)"
          sub="offsetting the intervention"
        />
      </div>

      <figure class="chart-figure present__chart">
        <figcaption>Net and cumulative budget impact</figcaption>
        <BudgetImpactChart :rows="presentedRows" />
      </figure>

      <p class="present__interpretation">
        Deterministic, undiscounted, per year. Uptake starts at the year-1 percentage and grows by
        the annual increment; engagement decides how many users are active.
      </p>

      <details class="details">
        <summary>Budget impact by year ({{ presented.table.length }} rows)</summary>
        <DataTable
          :columns="columns"
          :rows="presentedRows"
          caption="Budget impact by year (EUR)"
        />
      </details>

      <template #settings>
        <PresentationSettings :rows="presentedSettings" />
      </template>
    </PresentationOverlay>
  </section>
</template>
