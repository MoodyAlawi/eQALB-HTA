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

import { computed, ref, shallowRef } from 'vue'
import type {
  KmInterpretationCounts,
  KmRiskRow,
  KmStatus,
  KmStep,
  KmSummaryRow,
  SurvivalResponse,
} from '../api/types'
import { formatCount, formatNumber, formatPercent, isNum, type Tone } from '../format'
import { useModel } from '../composables/useModel'
import { useAppView } from '../composables/useAppView'
import { useResultEntrance } from '../composables/useResultEntrance'
import { prepareCsvDownload } from '../composables/useDownloadNotice'
import { EXPORT_FILENAMES, kmSummaryCsv } from '../export/tabExports'
import SurvivalCurveChart from './charts/SurvivalCurveChart.vue'
import ButtonLabel from './ButtonLabel.vue'
import ChartDownload from './ChartDownload.vue'
import DataTable from './DataTable.vue'
import InfoTip from './InfoTip.vue'
import MethodInfo from './MethodInfo.vue'
import MetricCard from './MetricCard.vue'
import ResultTrace from './ResultTrace.vue'
import StaleNotice from './StaleNotice.vue'
import PresentationOverlay from './presentation/PresentationOverlay.vue'
import TipLine from './TipLine.vue'
import PresentationSettings, {
  type PresentationSetting,
} from './presentation/PresentationSettings.vue'
import { movedSentence, supersededSentence, settingRow } from './presentation/settings'
import type { Column } from './table'

const model = useModel()
// The entrance this tab's result plays when it is committed; see the composable.
const { revealClass } = useResultEntrance('survival')

const { showJourneyExplainer } = useAppView()

/**
 * Opens this module's lesson from the Guided tutorial as a standalone explainer.
 *
 * The tutorial's own worked example is what the lesson draws: 1,000 simulated people per
 * arm at the case's effect assumptions, read from the tutorial's contract rather than
 * from this panel's seed, sample size or follow-up. Nothing here runs, moves or clears
 * the simulated curves behind this panel, and the journey screen decides whether the
 * chapter can be opened this way at all.
 */
function openExplainer(): void {
  showJourneyExplainer('survival')
}

const result = computed(() => model.survival)
const steps = computed<KmStep[]>(() => result.value?.steps ?? [])

/**
 * The one line the result area carries while there is no result yet: the wait,
 * while the request is in flight, and the guidance to start otherwise. The
 * guidance's second half — that the same inputs always reproduce the same
 * curves — belongs to the guidance, so the wait does not repeat it.
 */
const stateLine = computed(() =>
  model.busy.survival
    ? 'Simulating survival with these inputs.'
    : 'Start with the default seed and sample size, then select Run survival simulation; the same inputs always reproduce the same curves.',
)

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
  prepareCsvDownload(kmSummaryCsv(current), EXPORT_FILENAMES.km)
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

// --- Presentation mode -------------------------------------------------------

/**
 * The simulation being presented, held as the response itself: the curves, the
 * risk table, the arm summary, the checks and R's traffic-light interpretation all
 * travel in it, and its seed and sample size are the run's own.
 */
const presented = shallowRef<SurvivalResponse | null>(null)
const presentButton = ref<HTMLButtonElement | null>(null)
const presentedSteps = computed<KmStep[]>(() => presented.value?.steps ?? [])

/** The revision of this tab's stored result when the overlay was opened. */
const presentedRevision = ref(0)

function openPresentation(): void {
  presented.value = result.value
  presentedRevision.value = model.resultRevisions.survival
}

/** The line shown when a later run has replaced this result while it is open. */
const presentedSuperseded = computed(() =>
  presented.value !== null && model.resultRevisions.survival !== presentedRevision.value
    ? supersededSentence()
    : '',
)

function closePresentation(): void {
  presented.value = null
}

/** The risk table pivoted exactly as the panel pivots it, from the run's own rows. */
const presentedRisk = computed(() => {
  const rows: KmRiskRow[] = presented.value?.risk_table ?? []
  const years = [...new Set(rows.map((row) => row.year))].sort((a, b) => a - b)
  const grouped = new Map<string, { treatment: string; atRisk: Record<number, number | null> }>()
  for (const row of rows) {
    let entry = grouped.get(row.treatment)
    if (!entry) {
      entry = { treatment: row.treatment, atRisk: {} }
      grouped.set(row.treatment, entry)
    }
    entry.atRisk[row.year] = row.at_risk
  }
  const columns: Column<{ treatment: string; atRisk: Record<number, number | null> }>[] = [
    { key: 'treatment', label: 'Arm', value: (row) => row.treatment },
    ...years.map((year) => ({
      key: `year-${year}`,
      label: `Year ${year}`,
      align: 'right' as const,
      value: (row: { atRisk: Record<number, number | null> }) => formatCount(row.atRisk[year] ?? null),
    })),
  ]
  return { rows: [...grouped.values()], columns }
})

/** The run's own settings: the seed and sample size it was simulated with. */
const presentedSettings = computed<PresentationSetting[]>(() => {
  const run = presented.value
  if (!run) return []
  return [
    settingRow('patients', 'Patients per arm', formatCount(run.n_per_arm), 'patients'),
    settingRow('followup', 'Follow-up', String(run.followup_years), 'years'),
    settingRow('seed', 'Random seed', String(run.seed), ''),
    settingRow(
      'rrr',
      'Relative risk reduction (run)',
      isNum(run.rrr) ? formatPercent(run.rrr) : '—',
      '%',
    ),
  ]
})

const presentedStale = computed(() =>
  presented.value && model.survivalStale
    ? movedSentence(['the simulation inputs or the shared assumptions'])
    : '',
)
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <div class="panel__title-row">
          <h2>Simulated Kaplan-Meier analysis</h2>
          <MethodInfo module="survival" />
        </div>
        <ResultTrace :reveal-class="revealClass" />
        <p class="muted">How might event-free survival compare between the arms?</p>
      </div>
      <div class="panel__actions">
        <button
          type="button"
          class="btn btn--primary"
          :disabled="model.busy.survival"
          @click="model.runSurvival()"
        >
        <ButtonLabel :busy="model.busy.survival" idle="Run survival simulation" pending="Simulating survival…" />
        </button>
        <button
          type="button"
          class="btn btn--ghost"
          title="Read this module's lesson on its own, in the Guided tutorial. It uses the tutorial's own worked example — 1,000 simulated people per arm at the case's effect assumptions — not your analysis settings, and returns here when you are done."
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

    <p v-if="model.errors.survival" class="alert alert--danger" role="alert">
      {{ model.errors.survival }}
    </p>

    <StaleNotice v-if="result && model.survivalStale" action="Run survival simulation" />

    <p v-if="result" class="hint">
      The simulated patient-level dataset is not available here yet, so the download offers the
      summary tables instead.
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

    <p v-if="!result" class="hint" role="status">
      {{ stateLine }}
    </p>

    <div v-if="result" class="result-reveal" :class="revealClass">
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
        <ChartDownload
          filename="survival-event-free-survival.png"
          name="event-free survival"
        />
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
    </div>

    <!-- Presentation mode: the run's own curves, risk table and interpretation. -->
    <!-- A teaching tip, below the results and the actions. It is outside the
         presentation overlay, so presentation mode and the exports never carry it. -->
    <TipLine topic="survival" />

    <PresentationOverlay
      v-if="presented"
      title="Simulated Kaplan-Meier analysis"
      :notice="presented.notice"
      :stale="presentedStale"
      :superseded="presentedSuperseded"
      :fallback-focus="() => presentButton"
      @close="closePresentation()"
    >
      <div class="metrics present__metrics">
        <MetricCard
          label="Patients per arm"
          :value="formatCount(presented.n_per_arm)"
          :sub="`follow-up ${presented.followup_years} years, seed ${presented.seed}`"
        />
        <MetricCard
          label="Events, usual care"
          :value="formatCount(presented.summary[0]?.events ?? null)"
          sub="first MI or stroke"
        />
        <MetricCard
          label="Events, eQalb"
          :value="formatCount(presented.summary[1]?.events ?? null)"
          sub="first MI or stroke"
        />
        <MetricCard
          label="Hazard ratio (eQalb vs usual care)"
          :value="presented.interpretation.display.hazard_ratio"
          sub="eQalb versus usual care"
        />
      </div>

      <figure class="chart-figure present__chart">
        <figcaption>Event-free survival, simulated</figcaption>
        <SurvivalCurveChart :steps="presentedSteps" :followup-years="presented.followup_years" />
      </figure>

      <p class="present__interpretation">
        Simulated illustrative data: individual patients are drawn from the annual event risks and
        the engagement-adjusted treatment effect of this run, not observed trial data.
      </p>

      <DataTable
        :columns="presentedRisk.columns"
        :rows="presentedRisk.rows"
        caption="Number at risk by year"
      />
      <DataTable :columns="summaryColumns" :rows="presented.summary" caption="Arm summary" />

      <details class="details">
        <summary>Definitions and diagnostics from this run</summary>
        <ul class="list">
          <li v-for="check in presented.arm_contrast.checks" :key="check.Check">
            <strong>{{ check.Check }}</strong> — {{ check.Finding }}
          </li>
        </ul>
        <p class="hint">{{ presented.event_note }}</p>
        <p class="hint">{{ presented.logrank_note }}</p>
      </details>

      <p class="alert alert--info">{{ presented.interpretation.interpretation }}</p>

      <template #settings>
        <PresentationSettings :rows="presentedSettings" />
      </template>
    </PresentationOverlay>
  </section>
</template>
