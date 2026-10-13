<script setup lang="ts">
/**
 * Simulated Kaplan-Meier analysis: the two curves with their confidence bands,
 * the number at risk by year, the arm summary, the diagnostics, the plain
 * language arm contrast and the traffic-light interpretation.
 *
 * The interpretation is produced by assess_km_interpretation() in
 * eqalb_km_interpretation.R (the function the Shiny Kaplan-Meier tab calls) and
 * arrives with the simulation response, so this component never assigns a
 * status, applies a threshold or rewords an explanation. Even the three
 * formatted statistics it prints come from R's km_number()/km_p_value().
 *
 * The seed is exposed because the simulation is reproducible by design: the same
 * seed and sample size always give the same curves.
 */

import { computed } from 'vue'
import type { KmInterpretationCounts, KmRiskRow, KmStatus, KmStep, KmSummaryRow } from '../api/types'
import { formatCount, formatNumber, formatPercent, isNum, type Tone } from '../format'
import { useModel } from '../composables/useModel'
import { downloadText } from '../export/csv'
import { EXPORT_FILENAMES, kmSummaryCsv } from '../export/tabExports'
import SurvivalCurveChart from './charts/SurvivalCurveChart.vue'
import DataTable from './DataTable.vue'
import InfoTip from './InfoTip.vue'
import MetricCard from './MetricCard.vue'
import StaleNotice from './StaleNotice.vue'
import type { Column } from './table'

const model = useModel()

const result = computed(() => model.survival)
const steps = computed<KmStep[]>(() => result.value?.steps ?? [])

const summaryColumns: Column<KmSummaryRow>[] = [
  { key: 'treatment', label: 'Arm', value: (row) => row.treatment },
  { key: 'enrolled', label: 'Enrolled', align: 'right', value: (row) => formatCount(row.patients_enrolled) },
  { key: 'events', label: 'Events', align: 'right', value: (row) => formatCount(row.events) },
  { key: 'censored', label: 'Censored', align: 'right', value: (row) => formatCount(row.censored) },
  {
    key: 'median',
    label: 'Median event-free (years)',
    align: 'right',
    value: (row) => (isNum(row.median_event_free_survival_years) ? formatNumber(row.median_event_free_survival_years, 2) : 'not reached'),
  },
  {
    key: 'y1',
    label: 'Event-free 1 year',
    align: 'right',
    value: (row) => formatPercent(row.event_free_at_1_year),
  },
  {
    key: 'y5',
    label: 'Event-free 5 years',
    align: 'right',
    value: (row) => formatPercent(row.event_free_at_5_years),
  },
  {
    key: 'y10',
    label: 'Event-free 10 years',
    align: 'right',
    value: (row) => formatPercent(row.event_free_at_10_years),
  },
]

/** Number at risk pivoted so each year is a column, as in a trial report. */
const riskYears = computed(() => {
  const rows = result.value?.risk_table ?? []
  const years = new Set<number>()
  for (const row of rows) years.add(row.year)
  return [...years].sort((a, b) => a - b)
})

interface RiskRow {
  treatment: string
  atRisk: Record<number, number | null>
}

const riskRows = computed<RiskRow[]>(() => {
  const rows: KmRiskRow[] = result.value?.risk_table ?? []
  const grouped = new Map<string, RiskRow>()
  for (const row of rows) {
    let entry = grouped.get(row.treatment)
    if (!entry) {
      entry = { treatment: row.treatment, atRisk: {} }
      grouped.set(row.treatment, entry)
    }
    entry.atRisk[row.year] = row.at_risk
  }
  return [...grouped.values()]
})

const riskColumns = computed<Column<RiskRow>[]>(() => [
  { key: 'treatment', label: 'Arm', value: (row) => row.treatment },
  ...riskYears.value.map((year) => ({
    key: `year-${year}`,
    label: `Year ${year}`,
    align: 'right' as const,
    value: (row: RiskRow) => formatCount(row.atRisk[year] ?? null),
  })),
])

const contrast = computed(() => result.value?.arm_contrast ?? null)
const expectedEvents = computed(() => Object.entries(result.value?.expected_events ?? {}))

/**
 * The summary tables this tab displays — arm summary, number at risk, the
 * interpretation checks and the modelled expectation. It is deliberately not
 * Shiny's Kaplan-Meier export: that file is the simulated patient-level dataset,
 * which no endpoint returns yet.
 */
function downloadCsv(): void {
  const current = result.value
  if (!current) return
  downloadText(kmSummaryCsv(current), EXPORT_FILENAMES.km)
}

/** R's interpretation object, shown as returned. */
const interpretation = computed(() => result.value?.interpretation ?? null)

/** The band explanation, relocated to the chart header's information button. */
const bandInfo =
  'Bands are 95% Greenwood confidence intervals from the same estimator the summary uses.'

/**
 * R's log-rank line. The response repeats the simulated-data disclaimer at the
 * end of it; that disclaimer is no longer shown anywhere, so the line is
 * rendered up to its first occurrence. The disclaimer is taken from the
 * response's own notice field, so no wording is written here, and R's sentence
 * is otherwise untouched.
 */
const logrankNote = computed(() => {
  const current = result.value
  if (!current) return ''
  const disclaimer = current.notice
  const at = disclaimer ? current.logrank_note.indexOf(disclaimer) : -1
  return at > 0 ? current.logrank_note.slice(0, at).trim() : current.logrank_note
})

/** R's status name selects a colour token; no status is derived here. */
function statusTone(status: KmStatus): Tone {
  if (status === 'Green') return 'good'
  if (status === 'Red') return 'bad'
  return 'neutral'
}

function statusCardClass(status: KmStatus): string {
  if (status === 'Green') return 'status-card--good'
  if (status === 'Amber') return 'status-card--warning'
  return 'status-card--bad'
}

function statusBadgeClass(status: KmStatus): string {
  if (status === 'Green') return 'badge badge--good'
  if (status === 'Amber') return 'badge badge--warning'
  return 'badge badge--danger'
}

/** The counts R reports, labelled as the Shiny panel labels them. */
interface CountRow {
  measure: string
  eqalb: KmInterpretationCounts['cc_events']
  usualCare: KmInterpretationCounts['uc_events']
}

const countRows = computed<CountRow[]>(() => {
  const counts = interpretation.value?.counts
  if (!counts) return []
  return [
    { measure: 'Composite cardiovascular events', eqalb: counts.cc_events, usualCare: counts.uc_events },
    { measure: 'Total censoring', eqalb: counts.cc_censored, usualCare: counts.uc_censored },
    { measure: 'Competing other-cause deaths', eqalb: counts.cc_deaths, usualCare: counts.uc_deaths },
    {
      measure: 'Administrative end-of-follow-up censoring',
      eqalb: counts.cc_admin,
      usualCare: counts.uc_admin,
    },
  ]
})

const countColumns: Column<CountRow>[] = [
  { key: 'measure', label: 'Simulated statistic', value: (row) => row.measure },
  { key: 'eqalb', label: 'eQalb', align: 'right', value: (row) => formatCount(row.eqalb) },
  { key: 'usual', label: 'Usual care', align: 'right', value: (row) => formatCount(row.usualCare) },
]

const eventRateDifference = computed(() => {
  const summary = result.value?.summary ?? []
  if (summary.length < 2) return null
  const [first, second] = summary
  if (!isNum(first.events) || !isNum(second.events)) return null
  return { first: first.events, second: second.events, difference: second.events - first.events }
})
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <h2>Simulated Kaplan-Meier analysis</h2>
        <p class="muted">
          Individual patients are simulated from the annual event risks and the engagement-adjusted
          treatment effect of the current scenario. The curves are the model's, drawn from the same
          estimator as the number-at-risk table.
        </p>
      </div>
      <div class="panel__actions">
        <button
          type="button"
          class="btn btn--primary"
          :disabled="model.busy.survival"
          @click="model.runSurvival()"
        >
          {{ model.busy.survival ? 'Simulating…' : 'Run survival simulation' }}
        </button>
        <button
          type="button"
          class="btn btn--ghost"
          :disabled="!result"
          title="Download the summary tables shown on this tab — arm summary, number at risk, interpretation checks and modelled expectation — as CSV"
          @click="downloadCsv()"
        >
          Download summary tables (CSV)
        </button>
      </div>
    </header>

    <p v-if="model.errors.survival" class="alert alert--danger">{{ model.errors.survival }}</p>

    <StaleNotice v-if="result && model.survivalStale" action="Run survival simulation" />

    <p v-if="result" class="hint">
      This export holds the summary tables above. The Shiny tab additionally downloads the simulated
      patient-level dataset; the API does not return that dataset yet, so it is not offered here
      rather than reconstructed with a different method.
    </p>

    <div class="controls">
      <label class="field field--inline">
        <span>Patients per arm</span>
        <input v-model.number="model.survivalInputs.nPerArm" type="number" min="10" max="20000" step="100" />
      </label>
      <label class="field field--inline">
        <span>Follow-up</span>
        <input v-model.number="model.survivalInputs.followupYears" type="number" min="1" max="40" step="1" />
        <span class="field__unit">years</span>
      </label>
      <label class="field field--inline">
        <span>Random seed</span>
        <input v-model.number="model.survivalInputs.seed" type="number" min="0" step="1" />
      </label>
    </div>

    <p v-if="!result && !model.busy.survival" class="hint">
      The same seed and sample size always reproduce the same curves, so you can change one input at
      a time and compare.
    </p>

    <template v-if="result">
      <p v-if="eventRateDifference && contrast" class="alert alert--info">
        {{ contrast.verdict }}
      </p>

      <div class="metrics">
        <MetricCard
          label="Patients per arm"
          :value="formatCount(result.n_per_arm)"
          :sub="`follow-up ${result.followup_years} years, seed ${result.seed}`"
        />
        <MetricCard
          label="Events, usual care"
          :value="formatCount(result.summary[0]?.events ?? null)"
          sub="first MI or stroke"
        />
        <MetricCard
          label="Events, eQalb"
          :value="formatCount(result.summary[1]?.events ?? null)"
          sub="first MI or stroke"
        />
        <MetricCard
          label="Hazard ratio (eQalb vs usual care)"
          :value="interpretation ? interpretation.display.hazard_ratio : '—'"
          sub="eQalb versus usual care"
        />
      </div>

      <figure class="chart-figure">
        <figcaption>
          Event-free survival, simulated
          <InfoTip :text="bandInfo" topic="the confidence bands" />
        </figcaption>
        <SurvivalCurveChart :steps="steps" :followup-years="result.followup_years" />
      </figure>

      <DataTable :columns="riskColumns" :rows="riskRows" caption="Number at risk by year" />
      <DataTable :columns="summaryColumns" :rows="result.summary" caption="Arm summary" />

      <details class="details">
        <summary>Diagnostics and interpretation checks</summary>
        <ul class="list">
          <li v-for="check in contrast?.checks ?? []" :key="check.Check">
            <strong>{{ check.Check }}</strong> — {{ check.Finding }}
          </li>
        </ul>
        <ul class="list">
          <li v-for="[arm, expected] in expectedEvents" :key="arm">
            Modelled expectation, {{ arm }}: {{ formatNumber(expected, 1) }} events (the simulation
            draws {{ formatNumber(result.summary.find((row) => row.treatment === arm)?.events ?? null) }}).
          </li>
        </ul>
        <p class="hint">{{ result.event_note }}</p>
      </details>

      <section
        v-if="interpretation"
        class="interpretation"
        aria-labelledby="km-interpretation-title"
      >
        <h3 id="km-interpretation-title" class="interpretation__title">
          Traffic-light interpretation
        </h3>

        <div class="metrics">
          <MetricCard
            label="Overall status"
            :value="interpretation.overall_status"
            :tone="statusTone(interpretation.overall_status)"
            :sub="`${interpretation.domains.length} domains below`"
          />
        </div>

        <p class="alert alert--info">{{ interpretation.interpretation }}</p>

        <DataTable
          :columns="countColumns"
          :rows="countRows"
          caption="Simulated statistics behind the domains"
        />

        <ul class="list">
          <li>Hazard ratio (eQalb vs usual care): {{ interpretation.display.hazard_ratio }}</li>
          <li>Log-rank p-value: {{ interpretation.display.logrank_p }}</li>
        </ul>
        <p v-if="logrankNote" class="hint">{{ logrankNote }}</p>

        <div class="status-cards">
          <div
            v-for="domain in interpretation.domains"
            :key="domain.Domain"
            class="status-card"
            :class="statusCardClass(domain.Status)"
          >
            <h4 class="status-card__title">
              {{ domain.Domain }}
              <span :class="statusBadgeClass(domain.Status)">{{ domain.Status }}</span>
            </h4>
            <p class="status-card__text">{{ domain.Explanation }}</p>
          </div>
        </div>

        <details class="details">
          <summary>Traffic-light rules used</summary>
          <ul class="list">
            <li v-for="rule in interpretation.rules" :key="rule">{{ rule }}</li>
          </ul>
        </details>
      </section>
    </template>
  </section>
</template>
