<script setup lang="ts">
/**
 * Value of information: EVPI per patient, and regression-based EVPPI per patient
 * for the sampled PSA parameters.
 *
 * The API takes the draws already held in the browser, so this tab never re-runs
 * the PSA. EVPPI needs at least 100 successful iterations; below that the R layer
 * returns an explanation instead of a table, which is shown as-is.
 */

import { computed, ref, shallowRef } from 'vue'
import type { EvppiRow, VoiResponse } from '../api/types'
import { formatEuro, formatNumber, formatQaly, formatThreshold } from '../format'
import { useModel } from '../composables/useModel'
import { useResultEntrance } from '../composables/useResultEntrance'
import InfoTip from './InfoTip.vue'
import MethodInfo from './MethodInfo.vue'
import ButtonLabel from './ButtonLabel.vue'
import ChartDownload from './ChartDownload.vue'
import DataTable from './DataTable.vue'
import MetricCard from './MetricCard.vue'
import ResultTrace from './ResultTrace.vue'
import StaleNotice from './StaleNotice.vue'
import VoiEvpiChart from './charts/VoiEvpiChart.vue'
import EvppiChart from './charts/EvppiChart.vue'
import PresentationOverlay from './presentation/PresentationOverlay.vue'
import TipLine from './TipLine.vue'
import PresentationSettings, {
  type PresentationSetting,
} from './presentation/PresentationSettings.vue'
import { movedSentence, supersededSentence, settingRow } from './presentation/settings'
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
 * The one line the result area carries while there is no result yet: the wait,
 * while the request is in flight, and what the calculation would read otherwise.
 * The wait names the draw set rather than its size, so re-running the PSA while
 * this waits cannot relabel the run that is going; the read-out below it names
 * the count, and it is withheld for the length of the wait for that reason.
 */
const stateLine = computed(() =>
  model.busy.voi
    ? 'Calculating the value of information from the draw set held in this browser.'
    : `Ready to calculate from the ${formatNumber(drawCount.value)} draws held in this browser, registered with seed ${model.psa?.seed}.`,
)

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

// --- Presentation mode -------------------------------------------------------

/**
 * The value-of-information run being presented, held as the response itself. The
 * run's draw count, threshold, EVPI and EVPPI table all travel in it, so the
 * overlay shows that run and not the panel's current state.
 */
const presented = shallowRef<VoiResponse | null>(null)
const presentButton = ref<HTMLButtonElement | null>(null)

/** The revision of this tab's stored result when the overlay was opened. */
const presentedRevision = ref(0)

function openPresentation(): void {
  presented.value = result.value
  presentedRevision.value = model.resultRevisions.voi
}

/** The line shown when a later run has replaced this result while it is open. */
const presentedSuperseded = computed(() =>
  presented.value !== null && model.resultRevisions.voi !== presentedRevision.value
    ? supersededSentence()
    : '',
)

function closePresentation(): void {
  presented.value = null
}

const presentedEvppiTable = computed<EvppiRow[]>(() => {
  const evppi = presented.value?.evppi
  return evppi && evppi.available === true ? evppi.table : []
})

const presentedEvppiUnavailable = computed(() => {
  const evppi = presented.value?.evppi
  return evppi && evppi.available === false ? evppi.reason : null
})

/**
 * The columns the presentation's EVPPI table uses: the workspace's own three
 * reader-facing measures, without the model-argument column. That column's values
 * are the R call's argument names (`scenario_rrr`, `scenario_engagement_year1`, …),
 * which a presentation's reader has not seen, and the parameter column already names
 * every row in words — so the overlay leaves the identifier out rather than showing
 * it as a raw name. The workspace's own table keeps all four columns unchanged.
 */
const presentedColumns: Column<EvppiRow>[] = columns.filter((column) => column.key !== 'argument')

/** The run's own settings: the draws it reused and the threshold it read them at. */
const presentedSettings = computed<PresentationSetting[]>(() => {
  const run = presented.value
  if (!run) return []
  return [
    settingRow('draws', 'Draws reused from the PSA', formatNumber(run.n), 'draws'),
    settingRow('threshold', 'Reference WTP threshold', formatThreshold(run.wtp), '€/QALY'),
    settingRow('units', 'Unit of analysis', 'per patient', ''),
    settingRow('method', 'EVPPI method', 'Regression estimate on the same draws', ''),
  ]
})

const presentedStale = computed(() =>
  presented.value && model.voiStale
    ? movedSentence(['the PSA draws it reused or the threshold'])
    : '',
)

const settingsNote = computed(() =>
  model.voiStale
    ? 'The PSA draws or the threshold this run reused have been replaced since, so the panel’s current PSA is not shown as the run’s: only what this response reports is listed.'
    : 'This run’s own response: the draws it reused are still the ones the panel holds.',
)
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <div class="panel__title-row">
          <h2>Value of information</h2>
          <MethodInfo module="voi" />
        </div>
        <ResultTrace :reveal-class="revealClass" />
        <p class="muted">How much could resolving uncertainty be worth?</p>
      </div>
      <div class="panel__actions">
        <button
          type="button"
          class="btn btn--primary"
          :disabled="model.busy.voi || !model.psa"
          @click="model.runVoi()"
        >
          <ButtonLabel :busy="model.busy.voi" idle="Calculate value of information" pending="Calculating the value of information…" />
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

    <p v-if="model.errors.voi" class="alert alert--danger" role="alert">{{ model.errors.voi }}</p>

    <p v-if="!model.psa" class="hint">
      Run PSA first to use this analysis; it reuses those draws, so the simulation is not repeated.
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

      <p v-if="!result" class="hint" role="status">
        {{ stateLine }}
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
            <ChartDownload
              filename="value-of-information-evpi.png"
              name="expected net monetary benefit"
            />
          </figure>
          <figure v-if="evppiTable.length > 0" class="chart-figure">
            <figcaption>
              Expected value of partial perfect information by parameter
              <InfoTip :text="evppiChartInfo" topic="the EVPPI chart" />
            </figcaption>
            <EvppiChart :rows="evppiTable" :evpi="result.evpi.evpi" />
            <ChartDownload filename="value-of-information-evppi.png" name="EVPPI" />
          </figure>
        </details>
      </div>
    </template>

    <!-- Presentation mode: the run's own EVPI and EVPPI, per patient, at the
         threshold it read the draws at. -->
    <!-- A teaching tip, below the results and the actions. It is outside the
         presentation overlay, so presentation mode and the exports never carry it. -->
    <TipLine topic="voi" />

    <PresentationOverlay
      v-if="presented"
      title="Value of information"
      :notice="presented.notice"
      :stale="presentedStale"
      :settings-note="settingsNote"
      :superseded="presentedSuperseded"
      :fallback-focus="() => presentButton"
      @close="closePresentation()"
    >
      <div class="metrics present__metrics">
        <MetricCard
          label="EVPI per patient"
          :value="formatEuro(presented.evpi.evpi, 2)"
          :sub="`at ${formatThreshold(presented.wtp)}`"
        />
        <MetricCard
          label="Mean incremental cost"
          :value="formatEuro(presented.evpi.mean_incremental_cost)"
          sub="expected value"
        />
        <MetricCard
          label="Mean incremental QALYs"
          :value="formatQaly(presented.evpi.mean_incremental_qalys)"
          sub="expected value"
        />
        <MetricCard
          label="Iterations used"
          :value="formatNumber(presented.n)"
          sub="draws reused from the PSA"
        />
      </div>

      <p v-if="presentedEvppiUnavailable" class="alert alert--info">
        {{ presentedEvppiUnavailable }}
      </p>

      <div class="grid grid--2">
        <figure class="chart-figure present__chart">
          <figcaption>Expected net monetary benefit: current evidence and perfect information</figcaption>
          <VoiEvpiChart
            :expected-current="presented.evpi.expected_nmb_current"
            :expected-perfect="presented.evpi.expected_nmb_perfect"
            :evpi="presented.evpi.evpi"
            :mean-nmb="presented.evpi.mean_nmb"
            :wtp="presented.wtp"
          />
        </figure>

        <figure v-if="presentedEvppiTable.length > 0" class="chart-figure present__chart">
          <figcaption>Expected value of partial perfect information by parameter</figcaption>
          <EvppiChart :rows="presentedEvppiTable" :evpi="presented.evpi.evpi" />
        </figure>
      </div>

      <p class="present__interpretation">
        EVPI is the expected value of removing all parameter uncertainty; EVPPI attributes it to one
        parameter at a time. Both are per patient and depend on the threshold. The EVPPI ranking is
        the model’s regression estimate on the same draws: it is an approximation, not a full
        Bayesian value-of-information analysis. It is the value of resolving uncertainty in this
        illustrative model, not a population value or a research recommendation.
      </p>

      <figure v-if="presentedEvppiTable.length > 0" class="table-figure">
        <figcaption class="table-figure__caption">
          Expected value of partial perfect information by parameter
        </figcaption>
        <DataTable
          :columns="presentedColumns"
          :rows="presentedEvppiTable"
          label="Expected value of partial perfect information by parameter"
        />
      </figure>

      <template #settings>
        <PresentationSettings :rows="presentedSettings" />
      </template>
    </PresentationOverlay>
  </section>
</template>
