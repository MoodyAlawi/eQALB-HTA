<script setup lang="ts">
/**
 * Probabilistic sensitivity analysis: the interactive cost-effectiveness plane,
 * the PSA summary and the cost-effectiveness acceptability curve.
 *
 * A PSA run takes minutes at Shiny's 1,000 draws, so it stays behind the run
 * button, which is disabled while the request is in flight, and a run of 1,000
 * draws or more is confirmed first. The confirmation only gates the button: the
 * request, the draws and the iteration handling itself are unchanged. The plane
 * and the CEAC read the same single PSA response.
 */

import { computed, ref, shallowRef } from 'vue'
import { formatEuro, formatNumber, formatPercent, formatQaly, formatThreshold, isNum } from '../format'
import type { PsaResponse } from '../api/types'
import { useModel } from '../composables/useModel'
import { useResultEntrance } from '../composables/useResultEntrance'
import { useModalFocus } from '../composables/useModalFocus'
import { DIALOG_TRANSITION_NAME, onDialogLeave } from '../composables/useDialogTransition'
import ButtonLabel from './ButtonLabel.vue'
import ChartDownload from './ChartDownload.vue'
import InfoTip from './InfoTip.vue'
import CostEffectivenessPlane from './charts/CostEffectivenessPlane.vue'
import CeacChart from './charts/CeacChart.vue'
import { probabilityAtThreshold } from './charts/ceac'
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
// The entrance this tab's result plays when it is committed; see the composable.
const { revealClass } = useResultEntrance('psa')

interface ThresholdRow {
  threshold: number
  probability: number | null
  isReference: boolean
}

const result = computed(() => model.psa)

/**
 * The plane's explanation, relocated from beneath the chart into the information
 * button beside its header.
 */
const planeInfo =
  'Points above the dashed line cost more than the threshold allows. Run the base case on the base-case tab to show the deterministic point as well.'

/**
 * The acceptability curve's own readout, relocated into the header's information
 * button. It reads the same threshold probability the curve's marker does, so
 * the two cannot disagree.
 */
const ceacInfo = computed(() => {
  const psa = result.value
  if (!psa) return ''
  const probability = probabilityAtThreshold(psa.ceac, model.wtp)
  return `At ${formatEuro(model.wtp)}/QALY the model reports ${formatPercent(probability)} of iterations cost-effective.`
})

/**
 * The iteration count at and above which the run is confirmed first. It only
 * gates the button: the request, the draws and the iteration handling itself are
 * untouched.
 */
const PSA_CONFIRM_MIN = 1000

const confirmingPsa = ref(false)
const psaModal = ref<HTMLElement | null>(null)
const psaContinue = ref<HTMLButtonElement | null>(null)

/**
 * The confirmation is a real modal dialog: the focus moves to Continue, Tab stays
 * inside it, and the dashboard behind it — the iteration field, the tab strip, the
 * app header — cannot be reached until it is answered. Cancel puts the focus back
 * on the run button; Continue hands it back to the button it disables, which is
 * running by then, so the focus simply stays where the dialog left it.
 */
useModalFocus(confirmingPsa, psaModal, {
  initialFocus: () => psaContinue.value,
})

/**
 * The iterations the run in flight was asked for, or — while none is running —
 * the field's own value, so the button is already as wide as its pending state
 * will be. The capture is what makes the in-flight wording describe the run
 * rather than whatever the field says while it waits.
 */
const psaRunningSims = computed(() => model.psaInFlight ?? model.psaSims)

/**
 * The button's label while a run is in flight. It states the operation and the
 * number of iterations the run is actually using — both facts, neither a
 * percentage: how far through a PSA is is something this interface is not told.
 */
const psaPendingLabel = computed(() => `Running ${formatNumber(psaRunningSims.value)} iterations…`)

/**
 * The in-flight line's second sentence. A run at or above the size the
 * confirmation dialog warns about is the one that takes minutes, so only that
 * size keeps the minutes warning; a smaller run is described as the same wait
 * without it.
 */
const psaWaitNote = computed(() =>
  psaRunningSims.value >= PSA_CONFIRM_MIN
    ? 'A run this large takes minutes; keep this tab open until it finishes.'
    : 'Keep this tab open until it finishes.',
)

function requestPsa(): void {
  if (model.psaSims >= PSA_CONFIRM_MIN) {
    confirmingPsa.value = true
    return
  }
  model.runPsa()
}

/** Cancel leaves the iteration field as it is, so it can be adjusted. */
function cancelPsa(): void {
  confirmingPsa.value = false
}

function continuePsa(): void {
  confirmingPsa.value = false
  model.runPsa()
}

function onPsaKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape') {
    event.stopPropagation()
    cancelPsa()
  }
}

const thresholdRows = computed<ThresholdRow[]>(() => {
  const psa = result.value
  if (!psa) return []
  const values = Object.values(psa.probability_cost_effective ?? {})
  return (psa.wtp_thresholds ?? []).map((threshold, index) => ({
    threshold,
    probability: values[index] ?? null,
    isReference: Math.abs(threshold - psa.wtp) < 1e-9,
  }))
})

const thresholdColumns: Column<ThresholdRow>[] = [
  {
    key: 'threshold',
    label: 'WTP threshold',
    value: (row) => `${formatEuro(row.threshold)}/QALY${row.isReference ? ' (reference)' : ''}`,
  },
  {
    key: 'probability',
    label: 'Cost-effective',
    align: 'right',
    value: (row) => formatPercent(row.probability),
  },
]

const costComponents = computed(() => {
  const components = result.value?.mean_components
  if (!components) return []
  const labels: [string, string][] = [
    ['cost_intervention', 'eQalb intervention cost'],
    ['cost_implementation', 'One-off implementation cost'],
    ['cost_savings', 'Healthcare-use savings'],
    ['cost_post_mi', 'Post-MI state cost'],
    ['cost_post_stroke', 'Post-stroke state cost'],
  ]
  return labels.map(([key, label]) => ({ component: label, value: components[key] ?? null }))
})

const componentColumns: Column<{ component: string; value: number | null }>[] = [
  { key: 'component', label: 'Mean cost component', value: (row) => row.component },
  {
    key: 'value',
    label: 'EUR',
    align: 'right',
    value: (row) => formatEuro(row.value, 2),
    tone: (row) => (row.value !== null && row.value < 0 ? 'good' : null),
  },
]

/** The explanations from CC_INFO_TEXT for this panel's controls and metrics. */
const info = computed(() => model.defaults?.info_text ?? {})
const simulationsInfo = computed(() => info.value.psa_simulations ?? '')
const seedInfo = computed(() => info.value.random_seed ?? '')
const meanCostInfo = computed(() => info.value.psa_mean_cost ?? '')
const meanQalysInfo = computed(() => info.value.psa_mean_qalys ?? '')

// --- Presentation mode -------------------------------------------------------

/**
 * The PSA run being presented. It holds the response itself, so the overlay shows
 * the run that was on screen when Present was used; a run that lands afterwards
 * replaces the panel's result without touching this reference.
 */
const presented = shallowRef<PsaResponse | null>(null)
const presentButton = ref<HTMLButtonElement | null>(null)

/** The revision of this tab's stored result when the overlay was opened. */
const presentedRevision = ref(0)

function openPresentation(): void {
  presented.value = result.value
  presentedRevision.value = model.resultRevisions.psa
}

/** The line shown when a later run has replaced this result while it is open. */
const presentedSuperseded = computed(() =>
  presented.value !== null && model.resultRevisions.psa !== presentedRevision.value
    ? supersededSentence()
    : '',
)

function closePresentation(): void {
  presented.value = null
}

/**
 * The probability the presented run reported at its own threshold, read from that
 * run's table by the same helper the curve's marker uses. Nothing is recomputed:
 * a threshold the run did not report has no value.
 */
const presentedProbability = computed(() =>
  presented.value ? probabilityAtThreshold(presented.value.ceac, presented.value.wtp) : null,
)

/** The run's own settings, all of them reported by the response. */
const presentedSettings = computed<PresentationSetting[]>(() => {
  const run = presented.value
  if (!run) return []
  return [
    settingRow('iterations', 'Iterations requested', formatNumber(run.n_requested), 'draws'),
    settingRow('successful', 'Iterations used', formatNumber(run.n_successful), 'draws'),
    settingRow('seed', 'Random seed', String(run.seed), ''),
    settingRow('threshold', 'Reference WTP threshold', formatThreshold(run.wtp), '€/QALY'),
  ]
})

/** The threshold is the one control this tab's own stale notice compares. */
const presentedStale = computed(() =>
  presented.value && model.psaStale
    ? movedSentence([`the threshold (${formatThreshold(presented.value.wtp)})`])
    : '',
)
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <h2>Cost-effectiveness plane and PSA</h2>
        <ResultTrace :reveal-class="revealClass" />
        <p class="muted">How much does the answer change when the assumptions are uncertain?</p>
      </div>
      <div class="panel__actions">
        <button type="button" class="btn btn--primary" :disabled="model.busy.psa" @click="requestPsa()">
          <ButtonLabel :busy="model.busy.psa" idle="Run PSA" :pending="psaPendingLabel" />
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

    <p v-if="model.errors.psa" class="alert alert--danger" role="alert">{{ model.errors.psa }}</p>

    <p v-if="model.busy.psa" class="alert alert--info" role="status">
      Running {{ formatNumber(psaRunningSims) }} iterations. {{ psaWaitNote }}
    </p>

    <StaleNotice
      v-if="result && model.psaStale"
      action="Run PSA"
      :detail="`The stored result used a threshold of ${formatThreshold(result.wtp)}.`"
    />

    <p v-if="result && result.n_failed > 0" class="alert alert--warning">
      {{ formatNumber(result.n_failed) }} of {{ formatNumber(result.n_requested) }} iterations could
      not be evaluated and are excluded from the summary.
    </p>

    <p v-if="!result && !model.busy.psa" class="hint">
      Run the PSA to fill the plane, the summary and the acceptability curve.
    </p>

    <div class="controls">
      <label class="field field--inline">
        <span>Iterations</span>
        <input
          v-model.number="model.psaSims"
          type="number"
          :min="model.psaBounds.min"
          :max="model.psaBounds.max"
          :step="model.psaBounds.step"
        />
      </label>
      <InfoTip :text="simulationsInfo" topic="the number of PSA simulations" />
      <label class="field field--inline">
        <span>Random seed</span>
        <input
          v-model.number="model.psaSeed"
          type="number"
          :min="model.psaBounds.seedMin"
          step="1"
        />
      </label>
      <InfoTip :text="seedInfo" topic="the random seed" />
    </div>

    <div v-if="result" class="result-reveal" :class="revealClass">
      <div class="metrics">
        <MetricCard
          label="Mean incremental cost"
          :value="formatEuro(result.mean_incremental_cost)"
          sub="average across iterations"
          :hint="meanCostInfo"
        />
        <MetricCard
          label="Mean incremental QALYs"
          :value="formatQaly(result.mean_incremental_qalys)"
          sub="average across iterations"
          :hint="meanQalysInfo"
        />
        <MetricCard
          label="Median ICER"
          :value="isNum(result.median_icer) ? formatEuro(result.median_icer) : 'Not interpretable'"
          sub="median of the iteration ratios"
        />
        <MetricCard
          label="Probability cost-effective"
          :value="formatPercent(model.probabilityCostEffective)"
          :sub="`at ${formatThreshold(result.wtp)}`"
        />
      </div>

      <div class="grid grid--2">
        <figure class="chart-figure">
          <figcaption>
            Cost-effectiveness plane
            <InfoTip :text="planeInfo" topic="the cost-effectiveness plane" />
          </figcaption>
          <CostEffectivenessPlane
            :cloud="result.cloud"
            :wtp="model.wtp"
            :mean="{
              cost: result.mean_incremental_cost,
              qalys: result.mean_incremental_qalys,
            }"
            :base-case="
              model.baseCase
                ? { cost: model.baseCase.incremental_cost, qalys: model.baseCase.incremental_qalys }
                : null
            "
          />
          <ChartDownload
            filename="psa-cost-effectiveness-plane.png"
            name="cost-effectiveness plane"
          />
        </figure>

        <figure class="chart-figure">
          <figcaption>
            Cost-effectiveness acceptability curve
            <InfoTip :text="ceacInfo" topic="the acceptability curve" />
          </figcaption>
          <CeacChart :ceac="result.ceac" :wtp="model.wtp" />
          <ChartDownload
            filename="psa-acceptability-curve.png"
            name="cost-effectiveness acceptability curve"
          />
        </figure>
      </div>

      <div class="grid grid--2">
        <DataTable
          :columns="thresholdColumns"
          :rows="thresholdRows"
          caption="Probability of cost-effectiveness by threshold"
        />
        <DataTable
          :columns="componentColumns"
          :rows="costComponents"
          caption="Mean cost components across iterations"
        />
      </div>

      <p class="hint">
        The iteration cloud is the raw output, not a confidence region: with
        {{ formatNumber(result.n_successful) }} successful iterations it shows how parameter
        uncertainty propagates, and the acceptability curve is the share of iterations that fall
        below the threshold at each willingness to pay.
      </p>
    </div>

    <!-- A run at 1,000 draws or more takes minutes, so it is confirmed first.
         The prompt only gates the button; the request and the iteration handling
         are unchanged. Cancel leaves the field as it is so the count can be
         adjusted, and Escape and the backdrop both cancel. It arrives and leaves
         through the shared dialog transition. -->
    <Transition :name="DIALOG_TRANSITION_NAME" @leave="onDialogLeave">
      <div
        v-if="confirmingPsa"
        ref="psaModal"
        class="modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="psa-confirm-title"
        @keydown="onPsaKeydown"
      >
        <div class="modal__backdrop" @click="cancelPsa()"></div>
        <div class="modal__panel modal__panel--welcome">
          <h2 id="psa-confirm-title" class="modal__title">
            Run the PSA with {{ formatNumber(model.psaSims) }} iterations?
          </h2>
          <p class="page__prose">
            Running 1,000 or more iterations may take a few minutes. If you want a quick PSA, change
            the number of iterations to 100.
          </p>
          <div class="tutorial__nav">
            <button ref="psaContinue" type="button" class="btn btn--primary" @click="continuePsa()">
              Continue
            </button>
            <button type="button" class="btn btn--ghost" @click="cancelPsa()">Cancel</button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- Presentation mode: this tab's run in the shared overlay. It reads only
         the presented response, so the panel's controls can move behind it
         without changing what is shown. -->
    <PresentationOverlay
      v-if="presented"
      title="Cost-effectiveness plane and PSA"
      :notice="presented.notice"
      :stale="presentedStale"
      :superseded="presentedSuperseded"
      :fallback-focus="() => presentButton"
      @close="closePresentation()"
    >
      <div class="metrics present__metrics">
        <MetricCard
          label="Mean incremental cost"
          :value="formatEuro(presented.mean_incremental_cost)"
          sub="average across iterations"
        />
        <MetricCard
          label="Mean incremental QALYs"
          :value="formatQaly(presented.mean_incremental_qalys)"
          sub="average across iterations"
        />
        <MetricCard
          label="Median ICER"
          :value="isNum(presented.median_icer) ? formatEuro(presented.median_icer) : 'Not interpretable'"
          sub="median of the iteration ratios"
        />
        <MetricCard
          label="Probability cost-effective"
          :value="formatPercent(presentedProbability)"
          :sub="`at ${formatThreshold(presented.wtp)}`"
        />
      </div>

      <div class="grid grid--2">
        <figure class="chart-figure present__chart">
          <figcaption>Cost-effectiveness plane</figcaption>
          <CostEffectivenessPlane
            :cloud="presented.cloud"
            :wtp="presented.wtp"
            :mean="{ cost: presented.mean_incremental_cost, qalys: presented.mean_incremental_qalys }"
            :base-case="
              model.baseCase
                ? { cost: model.baseCase.incremental_cost, qalys: model.baseCase.incremental_qalys }
                : null
            "
          />
        </figure>

        <figure class="chart-figure present__chart">
          <figcaption>Cost-effectiveness acceptability curve</figcaption>
          <CeacChart :ceac="presented.ceac" :wtp="presented.wtp" />
        </figure>
      </div>

      <p v-if="presented.n_failed > 0" class="alert alert--warning">
        {{ formatNumber(presented.n_failed) }} of {{ formatNumber(presented.n_requested) }} iterations
        could not be evaluated and are excluded from the summary.
      </p>

      <p class="present__interpretation">
        The iteration cloud is the raw output, not a confidence region: with
        {{ formatNumber(presented.n_successful) }} successful iterations it shows how parameter
        uncertainty propagates, and the acceptability curve is the share of iterations that fall
        below the threshold at each willingness to pay.
      </p>

      <template #settings>
        <PresentationSettings :rows="presentedSettings" />
      </template>
    </PresentationOverlay>
  </section>
</template>
