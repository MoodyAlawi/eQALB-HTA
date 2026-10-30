<script setup lang="ts">
/**
 * DHT readiness and implementation tab.
 *
 * The assessment is calculated by calculate_readiness() in R (eqalb_readiness.R)
 * and reached through POST /api/readiness; nothing here scores a domain, applies
 * a threshold or interprets a result. Every control, range, unit and level set
 * comes from the readiness block of /api/defaults, so the tab cannot drift from
 * the Shiny version of the same assessment.
 *
 * Two inputs are shared assumptions rather than controls of this tab: the
 * clinical target population (the full-analysis population, also used by budget
 * impact) and year-1 and follow-up engagement (the Global Settings engagement in
 * Shiny, the assumptions panel here). They are shown read-only so the sharing is
 * visible and cannot be overridden in one tab only.
 */

import { computed, ref, shallowRef } from 'vue'
import type {
  ReadinessChoiceSet,
  ReadinessInputs,
  ReadinessParameterSpec,
  ReadinessResponse,
} from '../api/types'
import { NOT_INTERPRETABLE, formatCount, formatNumber, formatPercent, isNum } from '../format'
import { useModel } from '../composables/useModel'
import { useAppView } from '../composables/useAppView'
import { useResultEntrance } from '../composables/useResultEntrance'
import InfoTip from './InfoTip.vue'
import MethodInfo from './MethodInfo.vue'
import ButtonLabel from './ButtonLabel.vue'
import MetricCard from './MetricCard.vue'
import ResultTrace from './ResultTrace.vue'
import StaleNotice from './StaleNotice.vue'
import PresentationOverlay from './presentation/PresentationOverlay.vue'
import TipLine from './TipLine.vue'
import PresentationSettings, {
  type PresentationSetting,
} from './presentation/PresentationSettings.vue'
import { movedSentence, supersededSentence, settingRow } from './presentation/settings'

const model = useModel()
// The entrance this tab's result plays when it is committed; see the composable.
const { revealClass } = useResultEntrance('readiness')

const result = computed(() => model.readiness)

/**
 * The one line the result area carries while there is no result yet: the wait,
 * while the request is in flight, and the guidance to start otherwise.
 */
const stateLine = computed(() =>
  model.busy.readiness
    ? 'Assessing readiness with the values shown above.'
    : 'Start with the default values, then select Assess readiness.',
)

/** The specs the tab renders, in the order the contract lists them. */
const specs = computed(() => model.defaults?.readiness.parameters ?? [])

/**
 * R's own `group` field organises the inputs, and the tab renders them in the
 * contract's order rather than an order of its own. Three specs are shared
 * assumptions rather than controls of this tab — the clinical target population
 * (also used by budget impact) and the two engagement values (the assumptions
 * panel's Global Settings in Shiny) — so they are shown read-only, exactly as
 * before, and cannot be overridden in one tab only.
 */
const READONLY_IDS = new Set([
  'target_population',
  'readiness_year1_engagement',
  'readiness_followup_engagement',
])

/** The read-only value for a shared row. */
function readonlyValue(id: string): string {
  if (id === 'target_population') return formatCount(model.targetPopulation)
  const pct =
    id === 'readiness_year1_engagement'
      ? model.readinessEngagementPct.year1
      : model.readinessEngagementPct.followup
  return engagementLabel(pct)
}

/** The note that says where a shared row's value comes from. */
function readonlyNote(id: string): string {
  return id === 'target_population'
    ? 'Shared with budget impact.'
    : 'Shared from the assumptions panel.'
}

/**
 * The store keys its readiness inputs by name; a spec id is one of them. The
 * cast is a lookup aid only — R's contract decides which ids exist.
 */
type ReadinessInputKey = keyof typeof model.readinessInputs

function readinessKey(id: string): ReadinessInputKey {
  return id as ReadinessInputKey
}

/** The two select-style inputs, each with the heading Shiny gives it. */
const choiceFields = computed(() => {
  const choices = model.defaults?.readiness.choices
  if (!choices) return []
  return [
    { id: 'interoperability', heading: 'Interoperability', set: choices.interoperability },
    { id: 'algorithm_governance', heading: 'Algorithm governance', set: choices.algorithm_governance },
  ] as const
})

interface ReadinessGroup {
  heading: string
  rows: ReadinessParameterSpec[]
  choices: { id: 'interoperability' | 'algorithm_governance'; set: ReadinessChoiceSet }[]
}

/**
 * R's specs under R's group headings, followed by the two choice groups the
 * contract lists separately. A spec whose `group` is empty would go under
 * "Inputs"; the contract always sets one.
 */
const groups = computed<ReadinessGroup[]>(() => {
  const built: ReadinessGroup[] = []
  const groupFor = (heading: string): ReadinessGroup => {
    const found = built.find((entry) => entry.heading === heading)
    if (found) return found
    const created: ReadinessGroup = { heading, rows: [], choices: [] }
    built.push(created)
    return created
  }
  for (const spec of specs.value) groupFor(spec.group || 'Inputs').rows.push(spec)
  for (const field of choiceFields.value) {
    groupFor(field.heading).choices.push({ id: field.id, set: field.set })
  }
  return built
})

/** Engagement is a shared assumption, shown as the percentage the API receives. */
function engagementLabel(pct: number | undefined): string {
  return isNum(pct) ? `${formatNumber(pct, 1)}%` : NOT_INTERPRETABLE
}

const { showJourneyExplainer } = useAppView()

/**
 * Opens this module's lesson from the Guided tutorial as a standalone explainer.
 *
 * The tutorial's own worked example is what the lesson assesses: it reads none of the
 * settings on this panel and changes none of them, so the stored assessment behind
 * this panel is exactly as the learner left it when they come back. The chapter id is
 * R's, and the journey screen decides what it can open.
 */
function openExplainer(): void {
  showJourneyExplainer('readiness')
}

/**
 * The one readiness domain whose control R has no wording for. The
 * algorithm-governance choice set carries an empty `info` field on purpose (the
 * four approach levels carry their own meaning), so this sentence is written for
 * the interface rather than taken from the model. It describes what the domain
 * assesses — how the algorithm's approach to change, from no algorithmic
 * component to continuous learning, is documented, reviewed and re-validated
 * before deployment — which is what the domain's own statuses turn on.
 */
const ALGORITHM_GOVERNANCE_INFO =
  'Algorithm governance covers how the algorithm’s changes are controlled — no algorithmic component, a locked algorithm, periodically reviewed updates or continuous learning — and how those changes are documented, reviewed and validated before deployment.'

/** R returns the status name; the badge and its tone are the only styling added. */
function statusClass(status: string): string {
  if (status === 'Green') return 'badge badge--good'
  if (status === 'Amber') return 'badge badge--warning'
  return 'badge badge--danger'
}

const countsLabel = computed(() => {
  const counts = result.value?.counts
  if (!counts) return ''
  return `${counts.Green} Green · ${counts.Amber} Amber · ${counts.Red} Red`
})

// --- Presentation mode -------------------------------------------------------

/**
 * The assessment being presented, and the request body that produced it. The
 * quantitative numbers, the domain rows with their statuses and R's interpretation
 * travel in the response; the readiness values themselves do not, so the store
 * keeps the request alongside the result and the overlay lists them from that.
 * No overall score is introduced here — R's counts are the only summary shown,
 * exactly as the panel shows them.
 */
const presented = shallowRef<ReadinessResponse | null>(null)
/** The request that produced the presented assessment, captured with it. */
const presentedRequest = shallowRef<ReadinessInputs | null>(null)
const presentButton = ref<HTMLButtonElement | null>(null)

/** The revision of this tab's stored result when the overlay was opened. */
const presentedRevision = ref(0)

function openPresentation(): void {
  presented.value = result.value
  presentedRequest.value = model.readinessRun
  presentedRevision.value = model.resultRevisions.readiness
}

/** The line shown when a later run has replaced this result while it is open. */
const presentedSuperseded = computed(() =>
  presented.value !== null && model.resultRevisions.readiness !== presentedRevision.value
    ? supersededSentence()
    : '',
)

function closePresentation(): void {
  presented.value = null
}

const presentedCountsLabel = computed(() => {
  const counts = presented.value?.counts
  if (!counts) return ''
  return `${counts.Green} Green · ${counts.Amber} Amber · ${counts.Red} Red`
})

/**
 * The run's settings: the reach and workload figures the response reports, and the
 * readiness values from the request the store kept beside that result. Nothing here
 * reads a control, so the list describes the assessment it was opened on however
 * the panel has moved since.
 */
const presentedSettings = computed<PresentationSetting[]>(() => {
  const run = presented.value
  if (!run) return []
  const request = presentedRequest.value
  const rows: PresentationSetting[] = [
    settingRow('population', 'Eligible population', formatCount(run.eligible_population), 'people'),
    settingRow('year1', 'Active users, year 1', formatCount(run.active_users_year1), 'people'),
    settingRow(
      'followup',
      'Active users, follow-up',
      formatCount(run.active_users_followup),
      'people',
    ),
    settingRow(
      'retention',
      'Engagement retention',
      formatPercent((run.engagement_retention_pct ?? 0) / 100),
      '%',
    ),
    settingRow(
      'hours',
      'Clinician time',
      formatNumber(run.annual_clinician_hours, 1),
      'hours per year',
    ),
  ]
  if (!request) return rows
  for (const spec of specs.value) {
    const raw = (request as Record<string, unknown>)[spec.id]
    if (typeof raw === 'boolean') {
      rows.push(settingRow(spec.id, spec.label, raw ? 'Yes' : 'No', ''))
      continue
    }
    if (typeof raw !== 'number' || !Number.isFinite(raw)) continue
    rows.push(
      settingRow(
        spec.id,
        spec.label,
        spec.percent ? String(Number(raw.toFixed(6))) : formatNumber(raw, 2),
        spec.percent ? '%' : spec.unit,
      ),
    )
  }
  for (const choice of [
    { id: 'interoperability', set: model.defaults?.readiness.choices.interoperability },
    { id: 'algorithm_governance', set: model.defaults?.readiness.choices.algorithm_governance },
  ]) {
    const value = (request as Record<string, unknown>)[choice.id]
    if (typeof value !== 'string' || value === '') continue
    rows.push(settingRow(choice.id, choice.set?.label ?? choice.id, value, ''))
  }
  return rows
})

const presentedStale = computed(() =>
  presented.value && model.readinessStale
    ? movedSentence(['the readiness values or the shared assumptions'])
    : '',
)

const settingsNote = computed(() =>
  model.readinessStale
    ? 'Every readiness row is the request this assessment was sent, kept with its result; the panel’s controls have been changed since and are not shown as the assessment’s.'
    : 'Every readiness row is the request this assessment was sent, kept with its result — not the controls as they stand now.',
)

/**
 * The traffic-light rules disclosure. It is a native <details>, so it opens by
 * mouse and keyboard; Escape closes it through the app-wide disclosure behaviour
 * in useDisclosure.ts, which every screen installs. The wording shown inside is
 * copied unchanged from the Shiny readiness tab (DHT_THRESHOLD_NOTE and
 * DHT_TRAFFIC_LEGEND in app.R); no threshold is restated and nothing is added or
 * reworded.
 */
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <div class="panel__title-row">
          <h2>DHT readiness and implementation</h2>
          <MethodInfo module="readiness" />
        </div>
        <ResultTrace :reveal-class="revealClass" />
        <p class="muted">
          An illustrative assessment: could this digital therapeutic be implemented in practice?
        </p>
      </div>
      <div class="panel__actions">
        <button
          type="button"
          class="btn btn--primary"
          :disabled="model.busy.readiness"
          @click="model.runReadiness()"
        >
          <ButtonLabel :busy="model.busy.readiness" idle="Assess readiness" pending="Assessing readiness…" />
        </button>
        <button
          type="button"
          class="btn btn--ghost"
          title="Read this module's lesson on its own, in The Journey. It uses The Journey's own worked example, not your analysis settings, and returns here when you are done."
          @click="openExplainer()"
        >
          Explain this
        </button>
        <button
          type="button"
          class="btn btn--ghost"
          title="Restore the seven readiness inputs — access, suitability, review minutes, languages, accessibility, interoperability and algorithm governance — to their defaults. The shared population and engagement values are global assumptions and are not changed. This clears the readiness assessment only."
          @click="model.resetReadinessInputs()"
        >
          Reset values
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

    <p v-if="model.errors.readiness" class="alert alert--danger" role="alert">
      {{ model.errors.readiness }}
    </p>

    <StaleNotice v-if="result && model.readinessStale" action="Assess readiness" />

    <div class="controls controls--readiness">
      <section v-for="group in groups" :key="group.heading" class="control-group">
        <h3 class="control-group__heading">
          {{ group.heading }}
          <InfoTip
            v-if="group.heading === 'Algorithm governance'"
            :text="ALGORITHM_GOVERNANCE_INFO"
            topic="algorithm governance"
          />
        </h3>

        <div v-for="spec in group.rows" :key="spec.id" class="field">
          <template v-if="READONLY_IDS.has(spec.id)">
            <label :for="`readiness-${spec.id}`">{{ spec.label }}</label>
            <div class="field__control">
              <strong :id="`readiness-${spec.id}`">{{ readonlyValue(spec.id) }}</strong>
              <span v-if="spec.unit === 'people'" class="field__unit">people</span>
            </div>
            <p class="field__hint">{{ readonlyNote(spec.id) }}</p>
          </template>

          <template v-else-if="spec.type === 'boolean'">
            <label :for="`readiness-${spec.id}`">
              <input
                :id="`readiness-${spec.id}`"
                v-model="model.readinessInputs.accessibility_features"
                type="checkbox"
                :title="spec.unit"
              />
              {{ spec.label }}
            </label>
          </template>

          <template v-else>
            <label :for="`readiness-${spec.id}`" :title="spec.unit">{{ spec.label }}</label>
            <InfoTip :text="spec.info" :topic="spec.label" />
            <div class="field__control">
              <input
                :id="`readiness-${spec.id}`"
                v-model.number="model.readinessInputs[readinessKey(spec.id)]"
                type="number"
                :min="spec.min ?? undefined"
                :max="spec.max ?? undefined"
                :step="spec.step"
                inputmode="decimal"
                :title="spec.unit"
              />
              <span v-if="spec.percent" class="field__unit">%</span>
            </div>
          </template>
        </div>

        <div v-for="choice in group.choices" :key="choice.id" class="field">
          <label :for="`readiness-${choice.id}`">{{ choice.set.label }}</label>
          <InfoTip :text="choice.set.info" :topic="choice.set.label" />
          <div class="field__control">
            <select :id="`readiness-${choice.id}`" v-model="model.readinessInputs[choice.id]">
              <option v-for="level in choice.set.levels" :key="level" :value="level">
                {{ level }}
              </option>
            </select>
          </div>
        </div>
      </section>
    </div>

    <p v-if="!result" class="hint" role="status">
      {{ stateLine }}
    </p>

    <div v-if="result" class="result-reveal" :class="revealClass">
      <figure class="table-figure">
        <figcaption class="table-figure__caption">Quantitative outputs, simulated</figcaption>
        <div class="table-scroll">
          <table class="table table--wrap" aria-label="Quantitative outputs, simulated">
            <thead>
              <tr>
                <th scope="col">Measure</th>
                <th scope="col" class="is-right">Value</th>
                <th scope="col">Illustrative basis</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in result.numbers" :key="row.Measure">
                <td>{{ row.Measure }}</td>
                <td class="is-right">{{ row.Value }}</td>
                <td class="muted">{{ row['Illustrative basis'] }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </figure>

      <p class="alert alert--info">{{ result.interpretation }}</p>

      <figure class="table-figure">
        <figcaption class="table-figure__caption">
          Domain assessment, illustrative
          <span class="muted">({{ countsLabel }})</span>
        </figcaption>
        <div class="table-scroll">
          <table class="table table--wrap" aria-label="Domain assessment, illustrative">
            <thead>
              <tr>
                <th scope="col">Domain</th>
                <th scope="col">Status</th>
                <th scope="col">Current input</th>
                <th scope="col">Plain-language interpretation</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="domain in result.domains" :key="domain.Domain">
                <td>{{ domain.Domain }}</td>
                <td>
                  <span :class="statusClass(domain.Status)">{{ domain.Status }}</span>
                </td>
                <td>{{ domain['Current input'] }}</td>
                <td>{{ domain.Interpretation }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </figure>

      <details class="details">
        <summary>Traffic-light rules</summary>
        <p class="muted">The traffic-light thresholds used here are educational illustrative assumptions for the fictional eQalb digital therapeutic. They are not official HTA, DiGA, regulatory, cybersecurity, or reimbursement standards.</p>
        <ul class="list">
          <li>Green = no obvious barrier under the selected assumptions</li>
          <li>Amber = uncertainty or mitigation required</li>
          <li>Red = major barrier needing resolution before broad deployment</li>
        </ul>
      </details>
    </div>

    <!-- Presentation mode: the assessment's own numbers, domains and wording. No
         overall score is introduced; R's counts are the only summary shown. -->
    <!-- A teaching tip, below the results and the actions. It is outside the
         presentation overlay, so presentation mode and the exports never carry it. -->
    <TipLine topic="readiness" />

    <PresentationOverlay
      v-if="presented"
      title="DHT readiness and implementation"
      :notice="presented.notice"
      :stale="presentedStale"
      :settings-note="settingsNote"
      :superseded="presentedSuperseded"
      :fallback-focus="() => presentButton"
      @close="closePresentation()"
    >
      <div class="metrics present__metrics">
        <MetricCard label="Eligible population" :value="formatCount(presented.eligible_population)" />
        <MetricCard label="Active users, year 1" :value="formatCount(presented.active_users_year1)" />
        <MetricCard label="Active users, follow-up" :value="formatCount(presented.active_users_followup)" />
        <MetricCard label="Domain statuses, illustrative" :value="presentedCountsLabel" />
      </div>

      <p class="alert alert--info">{{ presented.interpretation }}</p>

      <figure class="table-figure">
        <figcaption class="table-figure__caption">Domain assessment, illustrative</figcaption>
        <div class="table-scroll">
          <table class="table table--wrap" aria-label="Domain assessment, illustrative">
            <thead>
              <tr>
                <th scope="col">Domain</th>
                <th scope="col">Status</th>
                <th scope="col">Current input</th>
                <th scope="col">Plain-language interpretation</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="domain in presented.domains" :key="domain.Domain">
                <td>{{ domain.Domain }}</td>
                <td><span :class="statusClass(domain.Status)">{{ domain.Status }}</span></td>
                <td class="muted">{{ domain['Current input'] }}</td>
                <td>{{ domain.Interpretation }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </figure>

      <details class="details">
        <summary>Quantitative outputs, simulated ({{ presented.numbers.length }} rows)</summary>
        <div class="table-scroll">
          <table class="table table--wrap" aria-label="Quantitative outputs, simulated">
            <thead>
              <tr>
                <th scope="col">Measure</th>
                <th scope="col" class="is-right">Value</th>
                <th scope="col">Illustrative basis</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in presented.numbers" :key="row.Measure">
                <td>{{ row.Measure }}</td>
                <td class="is-right">{{ row.Value }}</td>
                <td class="muted">{{ row['Illustrative basis'] }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </details>

      <template #settings>
        <PresentationSettings :rows="presentedSettings" />
      </template>
    </PresentationOverlay>
  </section>
</template>
