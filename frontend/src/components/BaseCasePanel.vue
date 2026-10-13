<script setup lang="ts">
/**
 * Deterministic base case: the incremental cost, incremental QALYs, ICER and the
 * deterministic cost-effectiveness plane, with the cost and QALY decompositions
 * available on demand instead of filling the panel. Every figure is what the R
 * model returned; the disclosure tables are the model's own value variables,
 * which R reconciles against the incremental totals before answering.
 */

import { computed } from 'vue'
import type { CostComponents, Num, QalyComponents } from '../api/types'
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
import { downloadText } from '../export/csv'
import { EXPORT_FILENAMES, baseCaseCsv } from '../export/tabExports'
import DataTable from './DataTable.vue'
import InfoTip from './InfoTip.vue'
import MetricCard from './MetricCard.vue'
import StaleNotice from './StaleNotice.vue'
import BaseCasePlane from './charts/BaseCasePlane.vue'
import type { Column } from './table'

const model = useModel()

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
  downloadText(baseCaseCsv(current), EXPORT_FILENAMES.baseCase)
}
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <h2>Base-case cost-effectiveness</h2>
        <p class="muted">
          The deterministic base case at the current assumptions: incremental cost, incremental
          QALYs and the ICER.
        </p>
      </div>
      <div class="panel__actions">
        <button
          type="button"
          class="btn btn--primary"
          :disabled="model.busy.baseCase"
          @click="model.runBaseCase()"
        >
          {{ model.busy.baseCase ? 'Running…' : 'Run base case' }}
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
      </div>
    </header>

    <p v-if="model.errors.baseCase" class="alert alert--danger">{{ model.errors.baseCase }}</p>

    <StaleNotice
      v-if="result && model.baseCaseStale"
      action="Run base case"
      :detail="`The stored result used a threshold of ${formatThreshold(result.wtp)}.`"
    />

    <p v-if="!result && !model.busy.baseCase" class="hint">
      Run the base case to see the incremental cost, the incremental QALYs and the ICER. Changing an
      assumption does not re-run the model by itself, so a result always matches the assumptions
      that produced it.
    </p>

    <template v-if="result">
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
    </template>
  </section>
</template>
