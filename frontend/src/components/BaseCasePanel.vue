<script setup lang="ts">
/**
 * Deterministic base case: the incremental cost, incremental QALYs, ICER and the
 * deterministic cost-effectiveness plane, with the cost and QALY decompositions
 * available on demand instead of filling the panel. Every figure is what the R
 * model returned; the disclosure tables are the model's own value variables,
 * which R reconciles against the incremental totals before answering.
 *
 * The panel also carries this tab's presentation mode: a viewport-sized overlay
 * for a screen share, showing one already-computed run. It is a view of that
 * result and nothing more — it issues no request, derives no figure, and reads the
 * assumptions it prints from the run's own response (`BaseCaseResponse.inputs`,
 * the scenario R received) rather than from the panel's controls, so a field
 * edited after the run can never be shown as one the run used. Opening it
 * snapshots the result object, so a run that lands while it is open replaces the
 * panel's result without silently replacing the presented one; the overlay says so
 * if the controls have moved since the run.
 */

import { computed, ref, shallowRef } from 'vue'
import {
  SCENARIO_PARAMETER_IDS,
  type BaseCaseResponse,
  type CostComponents,
  type Num,
  type ParameterSpec,
  type QalyComponents,
} from '../api/types'
import {
  costEffectivenessLabel,
  costEffectivenessTone,
  describeIcer,
  formatEuro,
  formatQaly,
  formatThreshold,
  isNum,
} from '../format'
import { useModel } from '../composables/useModel'
import { useResultEntrance } from '../composables/useResultEntrance'
import { prepareCsvDownload } from '../composables/useDownloadNotice'
import { EXPORT_FILENAMES, baseCaseCsv } from '../export/tabExports'
import DataTable from './DataTable.vue'
import ButtonLabel from './ButtonLabel.vue'
import ChartDownload from './ChartDownload.vue'
import InfoTip from './InfoTip.vue'
import MethodInfo from './MethodInfo.vue'
import MetricCard from './MetricCard.vue'
import ResultTrace from './ResultTrace.vue'
import StaleNotice from './StaleNotice.vue'
import BaseCasePlane from './charts/BaseCasePlane.vue'
import PresentationOverlay from './presentation/PresentationOverlay.vue'
import PresentationSettings, { type PresentationSetting } from './presentation/PresentationSettings.vue'
import { movedSentence, supersededSentence, scenarioSettingRows, settingRow } from './presentation/settings'
import type { Column } from './table'

const model = useModel()
// The entrance this tab's result plays when it is committed; see the composable.
const { revealClass } = useResultEntrance('baseCase')

interface ComponentRow {
  component: string
  value: Num
}

const COST_COMPONENTS: readonly (readonly [keyof CostComponents, string])[] = [
  ['intervention', 'eQalb intervention cost'],
  ['implementation', 'One-off implementation cost'],
  ['savings', 'Healthcare-use savings'],
  ['no_event', 'No-event state cost'],
  ['post_mi', 'Post-MI state cost'],
  ['post_stroke', 'Post-stroke state cost'],
]

const QALY_COMPONENTS: readonly (readonly [keyof QalyComponents, string])[] = [
  ['no_event', 'Time without an event'],
  ['post_mi', 'Time after MI'],
  ['post_stroke', 'Time after stroke'],
]

const costColumns: Column<ComponentRow>[] = [
  {
    key: 'component',
    label: 'Cost component (difference vs usual care)',
    value: (row) => row.component,
  },
  {
    key: 'value',
    label: 'EUR',
    align: 'right',
    value: (row) => formatEuro(row.value, 2),
    tone: (row) => (row.value !== null && row.value < 0 ? 'good' : null),
  },
]

const qalyColumns: Column<ComponentRow>[] = [
  {
    key: 'component',
    label: 'QALY component (difference vs usual care)',
    value: (row) => row.component,
  },
  { key: 'value', label: 'QALYs', align: 'right', value: (row) => formatQaly(row.value) },
]

const result = computed(() => model.baseCase)

/**
 * The one line the result area carries while there is no result yet: the wait,
 * while the request is in flight, and the guidance to start otherwise. The wait
 * names this analysis, as the button's pending label and the app-wide loader's
 * sentence do, so the tab describes the one wait the one way wherever it is read.
 */
const stateLine = computed(() =>
  model.busy.baseCase
    ? 'Running the base case with these assumptions.'
    : 'Start with the default assumptions, then select Run base case.',
)

const costRows = computed<ComponentRow[]>(() => {
  const components = result.value?.cost_components
  if (!components) return []
  return COST_COMPONENTS.map(([key, label]) => ({ component: label, value: components[key] }))
})

const qalyRows = computed<ComponentRow[]>(() => {
  const components = result.value?.qaly_components
  if (!components) return []
  return QALY_COMPONENTS.map(([key, label]) => ({ component: label, value: components[key] }))
})

const icerText = computed(() =>
  result.value
    ? describeIcer(result.value.icer, result.value.incremental_cost, result.value.incremental_qalys)
    : '—',
)

/**
 * The plane's own notes, relocated from beneath the chart into the information
 * button beside its header: the ICER annotation the plane carries and what the
 * two sides of the threshold line mean. Both parts are built from the same
 * helpers the chart and the metric cards use, so the three cannot disagree.
 */
const planeInfo = computed(() => {
  const current = result.value
  if (!current) return ''
  const ratio = describeIcer(current.icer, current.incremental_cost, current.incremental_qalys)
  const icerPart = isNum(current.icer) ? `ICER ${ratio} per QALY` : ratio
  const annotation = `${icerPart} · ${costEffectivenessLabel(current.cost_effective, current.wtp)}.`
  const sides = 'Points below the threshold line are cost-effective at the selected threshold.'
  const above =
    current.cost_effective === false ? ' The current eQalb result lies above the line.' : ''
  return `${annotation} ${sides}${above}`
})

/**
 * Shiny's cost-effectiveness CSV (app.R, download_ce_csv): the nine model inputs
 * then the three headline results, so a file from either interface carries the
 * same rows.
 */
function downloadCsv(): void {
  const current = result.value
  if (!current) return
  prepareCsvDownload(baseCaseCsv(current), EXPORT_FILENAMES.baseCase)
}

// --- Presentation mode -------------------------------------------------------

/**
 * The run being presented, or null. It holds the result object itself rather than
 * a copy of its figures, so the overlay shows the very run that was on screen when
 * Present was used, and a run that lands while the overlay is open replaces
 * `model.baseCase` without touching this reference.
 */
const presented = shallowRef<BaseCaseResponse | null>(null)

const presentButton = ref<HTMLButtonElement | null>(null)

/** The revision of this tab's stored result when the overlay was opened. */
const presentedRevision = ref(0)

function openPresentation(): void {
  presented.value = result.value
  presentedRevision.value = model.resultRevisions.baseCase
}

/** The line shown when a later run has replaced this result while it is open. */
const presentedSuperseded = computed(() =>
  presented.value !== null && model.resultRevisions.baseCase !== presentedRevision.value
    ? supersededSentence()
    : '',
)

function closePresentation(): void {
  presented.value = null
}

/** The presented run's ICER sentence, from the helper the metric card uses. */
const presentedIcer = computed(() => {
  const run = presented.value
  return run ? describeIcer(run.icer, run.incremental_cost, run.incremental_qalys) : '—'
})

/**
 * Whether the controls have moved since the presented run — the threshold, which
 * is what the tab's own stale notice checks, and the scenario inputs, which a
 * presentation must not present as current either. It names what moved and says
 * which figures are which; it reports a difference, it never re-labels a value.
 */
const presentedStale = computed(() => {
  const run = presented.value
  if (!run) return ''
  const movedThreshold = Math.abs(run.wtp - model.wtp) > 1e-9
  const movedInputs = SCENARIO_PARAMETER_IDS.filter((id) => {
    const used = run.inputs[`scenario_${id}`]
    const now = model.inputs[id]
    return isNum(used) && isNum(now) && Math.abs(used - now) > 1e-12
  }).length
  return movedSentence([
    movedThreshold ? `the threshold (${formatThreshold(run.wtp)})` : '',
    movedInputs > 0 ? `${movedInputs} assumption${movedInputs === 1 ? '' : 's'}` : '',
  ])
})

/**
 * The assumption values the presented run used, read from the response's own
 * `inputs` — the scenario R received — through the contract's labels, and shown
 * with the form's own conversion. Nothing here reads a control, so the list cannot
 * describe anything other than the run.
 */
const assumptionRows = computed<PresentationSetting[]>(() => {
  const run = presented.value
  const specs: ParameterSpec[] = model.defaults?.parameters ?? []
  if (!run) return []
  return [
    settingRow('wtp', 'Reference WTP threshold', formatThreshold(run.wtp), '€/QALY'),
    ...scenarioSettingRows(run.inputs, specs),
  ]
})
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <div class="panel__title-row">
          <h2>Base-case cost-effectiveness</h2>
          <MethodInfo module="base_case" />
        </div>
        <ResultTrace :reveal-class="revealClass" />
        <p class="muted">Is eQalb cost-effective at these assumptions?</p>
      </div>
      <div class="panel__actions">
        <button
          type="button"
          class="btn btn--primary"
          :disabled="model.busy.baseCase"
          @click="model.runBaseCase()"
        >
        <ButtonLabel :busy="model.busy.baseCase" idle="Run base case" pending="Running the base case…" />
        </button>
        <button
          type="button"
          class="btn btn--ghost"
          :disabled="!result"
          title="Download the model inputs and the three headline results as CSV, in the same layout as the Shiny cost-effectiveness export"
          @click="downloadCsv()"
        >
          Download results (CSV)
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

    <p v-if="model.errors.baseCase" class="alert alert--danger" role="alert">
      {{ model.errors.baseCase }}
    </p>

    <StaleNotice
      v-if="result && model.baseCaseStale"
      action="Run base case"
      :detail="`The stored result used a threshold of ${formatThreshold(result.wtp)}.`"
    />

    <p v-if="!result" class="hint" role="status">
      {{ stateLine }}
    </p>

    <div v-if="result" class="result-reveal" :class="revealClass">
      <div class="metrics">
        <MetricCard
          label="Incremental cost"
          :value="formatEuro(result.incremental_cost)"
          sub="eQalb minus usual care, per person"
        />
        <MetricCard
          label="Incremental QALYs"
          :value="formatQaly(result.incremental_qalys)"
          sub="discounted effects"
        />
        <MetricCard
          label="ICER"
          :value="icerText"
          sub="incremental cost / incremental QALYs"
          hint="Cost per additional QALY. Below the threshold, the strategy is cost-effective."
        />
        <MetricCard
          label="Net monetary benefit"
          :value="formatEuro(result.net_monetary_benefit)"
          :tone="costEffectivenessTone(result.cost_effective)"
          :sub="costEffectivenessLabel(result.cost_effective, result.wtp)"
        />
      </div>

      <figure class="chart-figure">
        <figcaption>
          Deterministic cost-effectiveness plane
          <InfoTip :text="planeInfo" topic="the deterministic cost-effectiveness plane" />
        </figcaption>
        <BaseCasePlane
          :cost="result.incremental_cost"
          :qalys="result.incremental_qalys"
          :icer="result.icer"
          :wtp="result.wtp"
          :cost-effective="result.cost_effective"
        />
        <ChartDownload
          filename="base-case-cost-effectiveness-plane.png"
          name="deterministic cost-effectiveness plane"
        />
      </figure>

      <details class="details">
        <summary>How incremental cost is composed</summary>
        <DataTable
          :columns="costColumns"
          :rows="costRows"
          label="Cost decomposition (EUR, incremental)"
        />
        <div class="totals">
          <p>
            <strong>Cost total</strong>
            {{ formatEuro(result.cost_components.total, 2) }}
            <span class="muted">reconciles with the incremental cost</span>
          </p>
        </div>
        <p class="hint">
          A negative component means eQalb costs less than usual care for that part of the pathway.
          The no-event state cost is zero by construction in this model, so it is shown but never
          contributes.
        </p>
      </details>

      <details class="details">
        <summary>How incremental QALYs are composed</summary>
        <DataTable
          :columns="qalyColumns"
          :rows="qalyRows"
          label="QALY decomposition (incremental)"
        />
        <div class="totals">
          <p>
            <strong>QALY total</strong>
            {{ formatQaly(result.qaly_components.total) }}
            <span class="muted">reconciles with the incremental QALYs</span>
          </p>
        </div>
        <p class="hint">
          A negative component means eQalb gains fewer QALYs from that part of the pathway than
          usual care.
        </p>
      </details>
    </div>

    <!-- Presentation mode: the shared overlay (the app's own dialog, transition
         and focus containment) with this tab's run inside it. It sits outside the
         result reveal: that container plays the result's own entrance, and the
         overlay must not be inside anything that animates. -->
    <PresentationOverlay
      v-if="presented"
      title="Base-case cost-effectiveness"
      :notice="presented.notice"
      :stale="presentedStale"
      :superseded="presentedSuperseded"
      :fallback-focus="() => presentButton"
      @close="closePresentation()"
    >
      <div class="metrics present__metrics">
        <MetricCard
          label="Incremental cost"
          :value="formatEuro(presented.incremental_cost)"
          sub="eQalb minus usual care, per person"
        />
        <MetricCard
          label="Incremental QALYs"
          :value="formatQaly(presented.incremental_qalys)"
          sub="discounted effects"
        />
        <MetricCard
          label="ICER"
          :value="presentedIcer"
          sub="incremental cost / incremental QALYs"
        />
        <MetricCard
          label="Net monetary benefit"
          :value="formatEuro(presented.net_monetary_benefit)"
          :tone="costEffectivenessTone(presented.cost_effective)"
          :sub="costEffectivenessLabel(presented.cost_effective, presented.wtp)"
        />
      </div>

      <p class="present__interpretation">
        Cost per additional QALY. Below the threshold, the strategy is cost-effective.
        <!-- The same sentence the workspace carries on the ICER card, shown here as
             text because a presentation has no hover. -->
      </p>

      <figure class="chart-figure present__chart">
        <figcaption>Deterministic cost-effectiveness plane</figcaption>
        <BaseCasePlane
          :cost="presented.incremental_cost"
          :qalys="presented.incremental_qalys"
          :icer="presented.icer"
          :wtp="presented.wtp"
          :cost-effective="presented.cost_effective"
        />
      </figure>

      <template #settings>
        <PresentationSettings :rows="assumptionRows" />
      </template>
    </PresentationOverlay>
  </section>
</template>
