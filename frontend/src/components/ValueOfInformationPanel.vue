<script setup lang="ts">
/**
 * Value of information: EVPI per patient, and regression-based EVPPI per patient
 * for the sampled PSA parameters.
 *
 * The API takes the draws already held in the browser, so this tab never re-runs
 * the PSA. EVPPI needs at least 100 successful iterations; below that the R layer
 * returns an explanation instead of a table, which is shown as-is.
 */

import { computed } from 'vue'
import type { EvppiRow } from '../api/types'
import { formatEuro, formatNumber, formatQaly, formatThreshold } from '../format'
import { useModel } from '../composables/useModel'
import { useResultEntrance } from '../composables/useResultEntrance'
import InfoTip from './InfoTip.vue'
import ButtonLabel from './ButtonLabel.vue'
import DataTable from './DataTable.vue'
import MetricCard from './MetricCard.vue'
import ResultTrace from './ResultTrace.vue'
import StaleNotice from './StaleNotice.vue'
import VoiEvpiChart from './charts/VoiEvpiChart.vue'
import EvppiChart from './charts/EvppiChart.vue'
import type { Column } from './table'

const model = useModel()
// The entrance this tab's result plays when it is committed; see the composable.
const { revealClass } = useResultEntrance('voi')

/** The EVPI and EVPPI explanations from CC_INFO_TEXT. */
const evpiInfo = computed(() => model.defaults?.info_text?.evpi ?? '')
const evppiInfo = computed(() => model.defaults?.info_text?.evppi ?? '')

const result = computed(() => model.voi)
const evppiUnavailable = computed(() => {
  const evppi = result.value?.evppi
  return evppi && evppi.available === false ? evppi.reason : null
})
const evppiTable = computed<EvppiRow[]>(() => {
  const evppi = result.value?.evppi
  return evppi && evppi.available === true ? evppi.table : []
})

const MIN_EVPPI_DRAWS = 100

const drawCount = computed(() => model.psa?.n_successful ?? 0)
const tooFewDraws = computed(() => drawCount.value > 0 && drawCount.value < MIN_EVPPI_DRAWS)

/**
 * The EVPI chart's own readout, relocated from beneath the chart into the
 * information button beside its header. The value and the threshold are R's, and
 * they are formatted as the chart formatted them.
 */
const evpiChartInfo = computed(() => {
  const evpi = result.value?.evpi
  if (!evpi) return ''
  return `R reports the value of removing all uncertainty — the gap between the two bars — as ${formatEuro(evpi.evpi, 2)} per patient at ${formatThreshold(result.value?.wtp)}.`
})

/** The EVPPI chart's method note, relocated to its header's information button. */
const evppiChartInfo =
  'The ranking here is the model\u2019s regression estimate on the same draws; it is an approximation, not a full Bayesian value-of-information analysis.'

const columns: Column<EvppiRow>[] = [
  { key: 'parameter', label: 'Parameter', value: (row) => row.parameter },
  { key: 'argument', label: 'Model argument', value: (row) => row.model_argument },
  {
    key: 'evppi',
    label: 'EVPPI per patient',
    align: 'right',
    value: (row) => formatEuro(row.evppi, 2),
  },
  {
    key: 'raw',
    label: 'Unclamped estimate',
    align: 'right',
    value: (row) => formatEuro(row.evppi_raw, 2),
    title: (row) => (row.clamped ? 'Negative regression estimate, reported as zero' : undefined),
  },
]
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <h2>Value of information</h2>
        <ResultTrace :reveal-class="revealClass" />
        <p class="muted">
          EVPI is the expected value of removing all parameter uncertainty; EVPPI attributes it to
          one parameter at a time. Both are per patient and depend on the threshold.
        </p>
      </div>
      <button
        type="button"
        class="btn btn--primary"
        :disabled="model.busy.voi || !model.psa"
        @click="model.runVoi()"
      >
        <ButtonLabel :busy="model.busy.voi" idle="Calculate value of information" pending="Calculating…" />
      </button>
    </header>

    <p v-if="model.errors.voi" class="alert alert--danger">{{ model.errors.voi }}</p>

    <p v-if="!model.psa" class="hint">
      Run the PSA on the cost-effectiveness tab first. This calculation reuses those draws, so the
      expensive simulation is never repeated.
    </p>

    <template v-else>
      <p v-if="tooFewDraws" class="alert alert--warning">
        Only {{ formatNumber(drawCount) }} successful iterations are available. The regression-based
        EVPPI needs at least {{ MIN_EVPPI_DRAWS }}, so run a larger PSA for a parameter-level
        decomposition. EVPI is still shown.
      </p>

      <p v-if="model.psaStale" class="alert alert--info">
        The PSA was run at {{ formatThreshold(model.psa.wtp) }}; run the PSA again before re-running
        this calculation to evaluate a different threshold.
      </p>

      <StaleNotice
        v-if="result && model.voiStale"
        action="Calculate value of information"
        :detail="`The stored result used a threshold of ${formatThreshold(result.wtp)}.`"
      />

      <p v-if="!result && !model.busy.voi" class="hint">
        Ready to calculate from the {{ formatNumber(drawCount) }} draws held in this browser,
        registered with seed {{ model.psa.seed }}.
      </p>

      <div v-if="result" class="result-reveal" :class="revealClass">
        <div class="metrics">
          <MetricCard
            label="EVPI per patient"
            :value="formatEuro(result.evpi.evpi, 2)"
            :sub="`at ${formatThreshold(result.wtp)}`"
            :hint="evpiInfo"
          />
          <MetricCard
            label="Mean incremental cost"
            :value="formatEuro(result.evpi.mean_incremental_cost)"
            sub="expected value"
          />
          <MetricCard
            label="Mean incremental QALYs"
            :value="formatQaly(result.evpi.mean_incremental_qalys)"
            sub="expected value"
          />
          <MetricCard
            label="Iterations used"
            :value="formatNumber(result.n)"
            sub="draws reused from the PSA"
          />
        </div>

        <p v-if="evppiUnavailable" class="alert alert--info">
          {{ evppiUnavailable }}
          <InfoTip :text="evppiInfo" topic="EVPPI" />
        </p>

        <template v-if="evppiTable.length > 0">
          <!-- The caption carries EVPPI's own information control, so the
               explanation sits on the heading of the table it describes. -->
          <figure class="table-figure">
            <figcaption class="table-figure__caption">
              Expected value of partial perfect information by parameter
              <InfoTip :text="evppiInfo" topic="EVPPI" />
            </figcaption>
            <DataTable
              :columns="columns"
              :rows="evppiTable"
              label="Expected value of partial perfect information by parameter"
            />
          </figure>
        </template>

        <details class="details">
          <summary>View visual summary</summary>
          <figure class="chart-figure">
            <figcaption>
              Expected net monetary benefit: current evidence and perfect information
              <InfoTip :text="evpiChartInfo" topic="the expected net monetary benefit chart" />
            </figcaption>
            <VoiEvpiChart
              :expected-current="result.evpi.expected_nmb_current"
              :expected-perfect="result.evpi.expected_nmb_perfect"
              :evpi="result.evpi.evpi"
              :mean-nmb="result.evpi.mean_nmb"
              :wtp="result.wtp"
            />
          </figure>
          <figure v-if="evppiTable.length > 0" class="chart-figure">
            <figcaption>
              Expected value of partial perfect information by parameter
              <InfoTip :text="evppiChartInfo" topic="the EVPPI chart" />
            </figcaption>
            <EvppiChart :rows="evppiTable" :evpi="result.evpi.evpi" />
          </figure>
        </details>
      </div>
    </template>
  </section>
</template>
