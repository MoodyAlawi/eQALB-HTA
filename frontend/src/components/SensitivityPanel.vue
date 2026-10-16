<script setup lang="ts">
/**
 * Deterministic one-way sensitivity analysis: every parameter is varied to its
 * low and high bound with the others held at the scenario values, and the
 * results are ranked by the model's own `impact_range`.
 *
 * The bounds default to eqalb_owsa.R. Editing them (the Shiny app allows it too)
 * only changes the request body; the ranges in force are always echoed back by
 * the API in `bounds`.
 */

import { computed, ref, shallowRef, watch } from 'vue'
import {
  OWSA_OUTCOMES,
  OWSA_OUTCOME_LABELS,
  type OwsaBound,
  type OwsaOutcome,
  type OwsaRangeOverride,
  type OwsaResponse,
  type OwsaRow,
} from '../api/types'
import { formatEuro, formatQaly, isNum } from '../format'
import { useModel, type OwsaRunRequest } from '../composables/useModel'
import { useResultEntrance } from '../composables/useResultEntrance'
import { prepareCsvDownload } from '../composables/useDownloadNotice'
import { EXPORT_FILENAMES, owsaCsv } from '../export/tabExports'
import TornadoChart from './charts/TornadoChart.vue'
import ButtonLabel from './ButtonLabel.vue'
import ChartDownload from './ChartDownload.vue'
import DataTable from './DataTable.vue'
import InfoTip from './InfoTip.vue'
import MetricCard from './MetricCard.vue'
import ResultTrace from './ResultTrace.vue'
import StaleNotice from './StaleNotice.vue'
import PresentationOverlay from './presentation/PresentationOverlay.vue'
import PresentationSettings, {
  type PresentationSetting,
} from './presentation/PresentationSettings.vue'
import { movedSentence, supersededSentence, scenarioSettingRows, settingRow } from './presentation/settings'
import type { Column } from './table'

const model = useModel()
// The entrance this tab's result plays when it is committed; see the composable.
const { revealClass } = useResultEntrance('owsa')

const editingBounds = ref(false)

const OUTCOME_LABELS = OWSA_OUTCOME_LABELS
const OUTCOME_ORDER = OWSA_OUTCOMES

/**
 * One sentence for the selector's information button: what the choice does, in
 * the tab's own terms. The tornado ranks the parameters by the range of the
 * outcome selected here, and the next run uses that outcome.
 */
const rankedOutcomeInfo =
  'Choose which result is ranked to show which assumptions have the greatest effect on that outcome.'

function formatOutcome(value: number | null, outcome: OwsaOutcome): string {
  switch (outcome) {
    case 'incremental_qalys':
      return formatQaly(value)
    case 'incremental_cost':
    case 'icer':
    case 'inmb':
      return formatEuro(value)
    default:
      return '—'
  }
}

const result = computed(() => model.owsa)

/**
 * The one line the result area carries while there is no result yet: the wait,
 * while the request is in flight, and the guidance to start otherwise.
 */
const stateLine = computed(() =>
  model.busy.owsa
    ? 'Running the sensitivity analysis with these assumptions and ranges.'
    : 'Select Run sensitivity analysis; it needs two model runs per parameter, so it takes a few seconds.',
)

/** The ranking the selector is set to, which is what the next run will use. */
const outcome = computed(() => model.owsaOutcome)

/**
 * The outcome the displayed result belongs to.
 *
 * The selector only builds the next request; it never relabels the run on
 * screen. Headers, units and values are all formatted from what R returned for
 * `result.outcome`, so a table cannot name one outcome while showing another's
 * numbers — before the first run there is no result and nothing to label.
 */
const displayedOutcome = computed<OwsaOutcome>(
  () => result.value?.outcome ?? outcome.value,
)

/** R's own label for the run, falling back to this tab's option text. */
const displayedLabel = computed(
  () => result.value?.outcome_label ?? OUTCOME_LABELS[displayedOutcome.value],
)

const format = computed(
  () => (value: number | null) => formatOutcome(value, displayedOutcome.value),
)

const rows = computed(() => result.value?.table ?? [])

/** Rebuilt whenever the displayed result changes, never captured at setup. */
const tornadoColumns = computed<Column<OwsaRow>[]>(() => {
  const label = displayedLabel.value
  return [
    { key: 'parameter', label: 'Parameter', value: (row) => row.parameter },
    {
      key: 'base',
      label: 'Base value',
      align: 'right',
      value: (row) => (isNum(row.base_value) ? String(row.base_value) : '—'),
    },
    {
      key: 'low',
      label: 'Low bound',
      align: 'right',
      value: (row) => (isNum(row.low_value) ? String(row.low_value) : '—'),
    },
    {
      key: 'high',
      label: 'High bound',
      align: 'right',
      value: (row) => (isNum(row.high_value) ? String(row.high_value) : '—'),
    },
    {
      key: 'outcome_low',
      label: `${label} at low`,
      align: 'right',
      value: (row) => formatOutcome(row.selected_outcome_low, displayedOutcome.value),
    },
    {
      key: 'outcome_high',
      label: `${label} at high`,
      align: 'right',
      value: (row) => formatOutcome(row.selected_outcome_high, displayedOutcome.value),
    },
    {
      key: 'range',
      label: 'Range',
      align: 'right',
      value: (row) => formatOutcome(row.impact_range, displayedOutcome.value),
    },
  ]
})

/** True while the selector asks for a ranking the displayed result was not run with. */
const outcomeDiffers = computed(
  () => result.value !== null && result.value.outcome !== outcome.value,
)

/**
 * The ranges the editor shows: R's own derivation for the assumptions currently in
 * the form, and before that answers, the ranges published for R's base case. Both
 * are R's; neither is derived or defaulted here.
 */
const bounds = computed<OwsaBound[]>(
  () => model.owsaDefaultBounds ?? model.defaults?.owsa_parameters ?? [],
)

/** R's sentence about how the ranges are derived. */
const boundsNote = computed(() => model.owsaBoundsNote || model.defaults?.owsa_bounds_note || '')

/**
 * Values typed in this session, kept per parameter so a row can be filled in one
 * side at a time. An edit is only sent to R once both sides are known, because R
 * validates the pair together; until then the row still shows what was typed.
 */
const drafts = ref<Record<string, { low?: number; high?: number }>>({})

interface RangeRow {
  /** R's row, kept whole so an edit names the parameter by its own id. */
  spec: OwsaBound
  id: string
  label: string
  unit: string
  source: string
  rationale: string
  group: string
  baseText: string
  lowText: string
  highText: string
  min: number
  max: number
  integer: boolean
  editable: boolean
  /** R's own verdict label: "Model default" or "Adjusted". */
  state: string
  adjusted: boolean
  /** R's sentence for a range it cannot use, or its observation about one. */
  note: string
}

/** One number as the editor shows it: R's value, rounded for reading only. */
function showValue(value: number | null): string {
  if (!isNum(value)) return '—'
  if (Number.isInteger(value)) return String(value)
  return String(Number.parseFloat(value.toFixed(4)))
}

/**
 * The same value for a number input, which may only be given a number or an empty
 * string: a range R could not derive leaves the field empty and carries R's own
 * sentence underneath, rather than putting text in a numeric control.
 */
function inputValue(value: number | null): string {
  return isNum(value) ? showValue(value) : ''
}

function overrideOf(id: string): OwsaRangeOverride | undefined {
  return (model.owsaBounds ?? []).find((bound) => bound.id === id)
}

/** The range in force for one row: what was typed, else the adjusted value, else R's. */
function activeRange(spec: OwsaBound): { low: number | null; high: number | null } {
  const draft = drafts.value[spec.id]
  const override = overrideOf(spec.id)
  const low = draft?.low ?? override?.low ?? (isNum(spec.low_default) ? spec.low_default : null)
  const high = draft?.high ?? override?.high ?? (isNum(spec.high_default) ? spec.high_default : null)
  return { low, high }
}

const rangeRows = computed<RangeRow[]>(() =>
  bounds.value.map((spec) => {
    const active = activeRange(spec)
    return {
      spec,
      id: spec.id,
      label: spec.parameter,
      unit: spec.unit,
      source: spec.range_source,
      rationale: spec.range_rationale,
      group: spec.group,
      baseText: showValue(spec.base_value),
      lowText: inputValue(active.low),
      highText: inputValue(active.high),
      min: spec.min,
      max: spec.max,
      integer: spec.integer,
      editable: spec.editable,
      state: spec.range_state,
      adjusted: spec.range_state !== 'Model default',
      note: spec.range_note || spec.range_warning,
    }
  }),
)

/** R's own group headings, in the order R lists them. */
const rangeGroups = computed(() => {
  const groups = new Map<string, RangeRow[]>()
  for (const row of rangeRows.value) {
    const list = groups.get(row.group)
    if (list) list.push(row)
    else groups.set(row.group, [row])
  }
  return [...groups.entries()].map(([heading, groupRows]) => ({ heading, rows: groupRows }))
})

/**
 * Sends the rows that have both values to R as this session's adjusted ranges. A
 * row the user typed nothing into is left out, which is how the request asks R for
 * its own range for that parameter. No range is derived, clamped or rebased here:
 * the values are sent as absolute numbers and R decides whether they can be used.
 */
function commitDrafts(): void {
  const next: OwsaRangeOverride[] = []
  for (const spec of bounds.value) {
    if (!drafts.value[spec.id] && !overrideOf(spec.id)) continue
    const { low, high } = activeRange(spec)
    if (low === null || high === null) continue
    const defaultLow = isNum(spec.low_default) ? spec.low_default : null
    const defaultHigh = isNum(spec.high_default) ? spec.high_default : null
    if (low === defaultLow && high === defaultHigh) continue
    next.push({ id: spec.id, low, high })
  }
  model.setOwsaBounds(next.length > 0 ? next : null)
}

function setBound(spec: OwsaBound, key: 'low' | 'high', raw: string): void {
  const parsed = Number.parseFloat(raw)
  const entry = { ...(drafts.value[spec.id] ?? {}) }
  if (Number.isFinite(parsed)) entry[key] = parsed
  else delete entry[key]
  drafts.value = { ...drafts.value, [spec.id]: entry }
  commitDrafts()
}

const boundsEdited = computed(() => model.owsaBounds !== null)

/** R's ranges for the current assumptions, asked for whenever the editor is open. */
watch(
  [editingBounds, () => model.owsaBounds, () => model.scenarioSignature],
  () => {
    if (editingBounds.value) void model.refreshOwsaDefaults()
  },
)

function resetBounds(): void {
  drafts.value = {}
  model.setOwsaBounds(null)
}

/**
 * Shiny's sensitivity-analysis copy, straight from the API: the paragraph above
 * the summary and the narrative R writes for the run (or, before a run, the
 * sentence Shiny shows instead). No sentence is composed or reworded here.
 */
const summaryNote = computed(() => result.value?.summary_note ?? model.defaults?.owsa_summary_note ?? '')
const summaryText = computed(() => result.value?.summary ?? model.defaults?.owsa_prerun_note ?? '')

/** Non-empty warnings from the run, e.g. a bound that makes the ICER undefined. */
const warnings = computed(() => {
  const found: string[] = []
  for (const row of rows.value) {
    for (const [key, label] of [
      ['low_warning', 'low'],
      ['high_warning', 'high'],
    ] as const) {
      const text = row[key]
      if (text) found.push(`${row.parameter} (${label} bound): ${text}`)
    }
  }
  return found
})

/**
 * The ranked table as the API returns it: one row per parameter with its low and
 * high results, which is exactly what the tab renders. Shiny's own OWSA export
 * lists the low and high scenarios as separate rows, so this file is named after
 * its shape rather than reusing Shiny's name.
 */
function downloadCsv(): void {
  const current = result.value
  if (!current) return
  prepareCsvDownload(owsaCsv(current), EXPORT_FILENAMES.owsa)
}

// --- Presentation mode -------------------------------------------------------

/**
 * The one-way run being presented, and the request body that produced it. The
 * ranking outcome is part of the response (`outcome`, `outcome_label`), and the
 * scenario and adjusted ranges come from the stored request, so the overlay shows
 * that run's own settings whether or not the controls have moved since.
 */
const presented = shallowRef<OwsaResponse | null>(null)
/**
 * The request that produced the presented run, captured with it from the store, so
 * the settings it lists are the run's own even after a later run or a control
 * change — and never the panel's controls.
 */
const presentedRequest = shallowRef<OwsaRunRequest | null>(null)
const presentButton = ref<HTMLButtonElement | null>(null)

/** The revision of this tab's stored result when the overlay was opened. */
const presentedRevision = ref(0)

function openPresentation(): void {
  presented.value = result.value
  presentedRequest.value = model.owsaRun
  presentedRevision.value = model.resultRevisions.owsa
}

/** The line shown when a later run has replaced this result while it is open. */
const presentedSuperseded = computed(() =>
  presented.value !== null && model.resultRevisions.owsa !== presentedRevision.value
    ? supersededSentence()
    : '',
)

function closePresentation(): void {
  presented.value = null
}

/**
 * The run's settings: the ranking, threshold and parameter count the response
 * reports, and the scenario and adjusted-range count from the request the store
 * kept beside that result. Nothing here reads a control, so the list describes the
 * run it was opened on however the panel has moved since.
 */
const presentedSettings = computed<PresentationSetting[]>(() => {
  const run = presented.value
  if (!run) return []
  const request = presentedRequest.value
  const rows: PresentationSetting[] = [
    settingRow('outcome', 'Ranked outcome', run.outcome_label, ''),
    settingRow('threshold', 'Reference WTP threshold', formatEuro(run.wtp), '€/QALY'),
    settingRow('parameters', 'Parameters tested', String(run.table.length), ''),
    settingRow(
      'ranges',
      'One-way ranges',
      request && request.bounds && request.bounds.length > 0
        ? `${request.bounds.length} adjusted in this session, the rest R-derived`
        : 'R-derived, as returned with this run',
      '',
    ),
  ]
  rows.push(
    ...scenarioSettingRows(
      (request?.body ?? {}) as Record<string, number | null>,
      model.defaults?.parameters ?? [],
      '',
    ),
  )
  return rows
})

/** What has moved since the run: the scenario, the threshold or the ranges. */
const presentedStale = computed(() =>
  presented.value !== null && model.owsaStale
    ? movedSentence(['the scenario, threshold or ranges'])
    : '',
)

/** The note under the settings rows. */
const settingsNote = computed(() =>
  model.owsaStale
    ? 'Every row is the request this run was sent, kept with its result; the panel’s controls have been changed since and are not shown as the run’s.'
    : 'Every row is the request this run was sent, kept with its result — not the controls as they stand now.',
)
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <h2>Deterministic sensitivity analysis</h2>
        <ResultTrace :reveal-class="revealClass" />
        <p class="muted">Which assumptions influence the result most?</p>
      </div>
      <div class="panel__actions">
        <button
          type="button"
          class="btn btn--primary"
          :disabled="model.busy.owsa"
          @click="model.runOwsa()"
        >
        <ButtonLabel :busy="model.busy.owsa" idle="Run sensitivity analysis" pending="Running the sensitivity analysis…" />
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
          title="Download the ranked sensitivity-analysis table as CSV: one row per parameter, with its base value and its low and high results in columns. Shiny's export lists each scenario as its own row, so the file is named after its shape."
          @click="downloadCsv()"
        >
          Download table (CSV)
        </button>
      </div>
    </header>

    <p v-if="model.errors.owsa" class="alert alert--danger" role="alert">{{ model.errors.owsa }}</p>

    <div class="controls">
      <div class="field field--inline">
        <label for="owsa-outcome">Ranked outcome</label>
        <select id="owsa-outcome" v-model="model.owsaOutcome">
          <option v-for="option in OUTCOME_ORDER" :key="option" :value="option">
            {{ OUTCOME_LABELS[option] }}
          </option>
        </select>
        <InfoTip :text="rankedOutcomeInfo" topic="the ranked outcome" />
      </div>
      <button
        type="button"
        class="btn btn--ghost"
        :aria-expanded="editingBounds"
        @click="editingBounds = !editingBounds"
      >
        {{ editingBounds ? 'Hide parameter ranges' : 'Edit parameter ranges' }}
        <span v-if="boundsEdited" class="badge badge--warning">Adjusted</span>
      </button>
    </div>

    <div v-if="editingBounds" class="bounds">
      <p class="hint">
        These are the ranges a one-way analysis would use now. R derives one for each parameter
        from the value it has in the current assumptions. A range you set here is used exactly as
        you set it, stays in force when the assumptions change, and applies to this browser
        session only; resetting returns every row to R's own range.
      </p>
      <p v-if="boundsNote" class="hint">{{ boundsNote }}</p>

      <p v-if="model.owsaDefaultsError" class="alert alert--warning">
        R's current ranges could not be loaded, so the values below may belong to earlier
        assumptions. {{ model.owsaDefaultsError }}
      </p>

      <div class="controls controls--ranges">
        <section v-for="group in rangeGroups" :key="group.heading" class="control-group">
          <h3 class="control-group__heading">{{ group.heading }}</h3>

          <div v-for="row in group.rows" :key="row.id" class="range">
            <div class="range__head">
              <span class="range__label">{{ row.label }}</span>
              <InfoTip
                v-if="row.rationale"
                :text="row.rationale"
                :title="row.source"
                :topic="`${row.label} range`"
              />
              <span class="range__unit">{{ row.unit }}</span>
              <span class="badge" :class="{ 'badge--warning': row.adjusted }">{{ row.state }}</span>
            </div>

            <div class="range__values">
              <label class="range__field">
                <span class="range__field-label">Low</span>
                <input
                  class="input--cell"
                  type="number"
                  :value="row.lowText"
                  placeholder="—"
                  :min="row.min"
                  :max="row.max"
                  :step="row.integer ? 1 : 'any'"
                  :disabled="!row.editable"
                  @change="setBound(row.spec, 'low', ($event.target as HTMLInputElement).value)"
                />
              </label>
              <div class="range__field range__field--base">
                <span class="range__field-label">Base value</span>
                <span class="range__base">{{ row.baseText }}</span>
              </div>
              <label class="range__field">
                <span class="range__field-label">High</span>
                <input
                  class="input--cell"
                  type="number"
                  :value="row.highText"
                  placeholder="—"
                  :min="row.min"
                  :max="row.max"
                  :step="row.integer ? 1 : 'any'"
                  :disabled="!row.editable"
                  @change="setBound(row.spec, 'high', ($event.target as HTMLInputElement).value)"
                />
              </label>
            </div>

            <p v-if="row.note" class="field__hint field__hint--warning">{{ row.note }}</p>
          </div>
        </section>
      </div>

      <div class="controls">
        <button type="button" class="btn btn--ghost" :disabled="!boundsEdited" @click="resetBounds()">
          Reset to model ranges
        </button>
      </div>
    </div>

    <StaleNotice
      v-if="result && model.owsaStale"
      action="Run sensitivity analysis"
      detail="The stored result was made with the assumptions, threshold and ranges in force then."
    />

    <!-- Changing the ranked outcome selects a different ranking; it does not run
         the analysis, so this notice names the second way the displayed result
         can differ from the current controls. -->
    <StaleNotice
      v-if="outcomeDiffers"
      action="Run sensitivity analysis"
      :detail="`The stored ranking used the “${result?.outcome_label}” outcome.`"
    />

    <!-- Shiny's own copy for this tab, kept out of the way but available: the
         paragraph it shows above the summary, then the interpretation R writes (or
         its sentence for a run that has not happened yet). Both arrive from the API
         and are rendered verbatim, inside a closed disclosure. R's interpretation
         states the base case and its decision reference, the parameters that move
         the displayed outcome most, and whether the conclusion survives the tested
         ranges, so it follows the ranked outcome the result was run with. -->
    <details v-if="summaryText" class="details">
      <summary>How to interpret this result</summary>
      <p v-if="summaryNote" class="muted">{{ summaryNote }}</p>
      <p class="owsa-summary__text">{{ summaryText }}</p>
    </details>

    <p v-if="!result" class="hint" role="status">
      {{ stateLine }}
    </p>

    <div v-if="result" class="result-reveal" :class="revealClass">
      <div class="metrics">
        <MetricCard
          label="Base case outcome"
          :value="format(result.base_outcome)"
          :sub="result.outcome_label"
        />
        <MetricCard
          label="Base incremental cost"
          :value="formatEuro(result.base_incremental_cost)"
          sub="scenario values"
        />
        <MetricCard
          label="Base incremental QALYs"
          :value="formatQaly(result.base_incremental_qalys)"
          sub="scenario values"
        />
        <MetricCard
          label="Net monetary benefit at base"
          :value="formatEuro(result.base_incremental_nmb)"
          :sub="`at ${formatEuro(result.wtp)}/QALY`"
        />
      </div>

      <figure class="chart-figure">
        <figcaption>Tornado diagram — variation of {{ result.outcome_label }}</figcaption>
        <TornadoChart
          :rows="result.table"
          :base-outcome="result.base_outcome"
          :outcome="result.outcome"
          :format="format"
        />
        <ChartDownload filename="sensitivity-tornado-diagram.png" name="tornado diagram" />
      </figure>

      <details class="details">
        <summary>Full one-way sensitivity table ({{ rows.length }} parameters)</summary>
        <DataTable :columns="tornadoColumns" :rows="rows" label="Full one-way sensitivity table" />
        <p class="hint">
          The downloaded CSV holds this table: one row per parameter, with the low and high results
          in separate columns. The Shiny export writes the same results in a long layout instead —
          one row per parameter and scenario — so the two files carry the same numbers in different
          shapes.
        </p>
      </details>

      <details v-if="warnings.length > 0" class="details">
        <summary>{{ warnings.length }} bound warnings from the model</summary>
        <ul class="list">
          <li v-for="(warning, index) in warnings" :key="index">{{ warning }}</li>
        </ul>
      </details>
    </div>

    <!-- Presentation mode: the run's own ranking and ranges, read from the
         presented response rather than from the selector. -->
    <PresentationOverlay
      v-if="presented"
      title="Deterministic sensitivity analysis"
      :notice="presented.notice"
      :stale="presentedStale"
      :settings-note="settingsNote"
      :superseded="presentedSuperseded"
      :fallback-focus="() => presentButton"
      @close="closePresentation()"
    >
      <div class="metrics present__metrics">
        <MetricCard
          label="Base case outcome"
          :value="formatOutcome(presented.base_outcome, presented.outcome)"
          :sub="presented.outcome_label"
        />
        <MetricCard
          label="Base incremental cost"
          :value="formatEuro(presented.base_incremental_cost)"
          sub="scenario values"
        />
        <MetricCard
          label="Base incremental QALYs"
          :value="formatQaly(presented.base_incremental_qalys)"
          sub="scenario values"
        />
        <MetricCard
          label="Net monetary benefit at base"
          :value="formatEuro(presented.base_incremental_nmb)"
          :sub="`at ${formatEuro(presented.wtp)}/QALY`"
        />
      </div>

      <figure class="chart-figure present__chart">
        <figcaption>Tornado diagram — variation of {{ presented.outcome_label }}</figcaption>
        <TornadoChart
          :rows="presented.table"
          :base-outcome="presented.base_outcome"
          :outcome="presented.outcome"
          :format="(value) => formatOutcome(value, presented!.outcome)"
        />
      </figure>

      <details class="details">
        <summary>R’s reading of this run</summary>
        <p class="muted">{{ presented.summary_note }}</p>
        <p class="owsa-summary__text">{{ presented.summary }}</p>
      </details>

      <details class="details">
        <summary>One-way ranges used ({{ presented.bounds.length }} parameters)</summary>
        <p class="muted">{{ presented.bounds_note }}</p>
        <p class="present__interpretation">
          The ranges in force for this run came back with it; the editable table with every low and
          high value, in the panel’s own units, is on the Sensitivity analysis tab.
        </p>
      </details>

      <template #settings>
        <PresentationSettings :rows="presentedSettings" />
      </template>
    </PresentationOverlay>
  </section>
</template>
