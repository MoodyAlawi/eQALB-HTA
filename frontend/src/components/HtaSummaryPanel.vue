<script setup lang="ts">
/**
 * HTA decision summary and evidence priorities.
 *
 * The dashboard and the evidence-priority table are produced by
 * assess_hta_decision_summary() and build_hta_evidence_priorities() in
 * eqalb_markov.R and reached through POST /api/hta-summary. This component only
 * presents that response: it never scores a domain, applies a threshold, infers
 * a missing value or rewords R's interpretation. An analysis that has not been
 * run is not sent, so R itself reports the not-yet-available wording — including
 * "Not available" domains, the "Not yet assessable" position and "Not yet
 * available" priorities — and nothing here turns those into a number.
 *
 * The availability block is shown as it comes back: R's own domain names, the
 * request fields that were missing, and which upstream analyses were included.
 */

import { computed, ref, shallowRef } from 'vue'
import type { HtaSummaryResponse, HtaSummaryStatus } from '../api/types'
import type { Tone } from '../format'
import MetricCard from './MetricCard.vue'
import ButtonLabel from './ButtonLabel.vue'
import ResultTrace from './ResultTrace.vue'
import StaleNotice from './StaleNotice.vue'
import PresentationOverlay from './presentation/PresentationOverlay.vue'
import PresentationSettings, {
  type PresentationSetting,
} from './presentation/PresentationSettings.vue'
import { movedSentence, supersededSentence, availabilityFieldLabel, settingRow } from './presentation/settings'
import { useModel } from '../composables/useModel'
import { useResultEntrance } from '../composables/useResultEntrance'
import { formatEuro, isNum } from '../format'

const model = useModel()
// The entrance this tab's result plays when it is committed; see the composable.
const { revealClass } = useResultEntrance('htaSummary')

const result = computed(() => model.htaSummary)
const summary = computed(() => result.value?.summary ?? null)

/**
 * The one line the result area carries while there is no result yet: the wait,
 * while the request is in flight, and the guidance to start otherwise. The
 * guidance lists what can be included, so it is the one the tab keeps; the wait
 * only needs to say what it is reading.
 */
const stateLine = computed(() =>
  model.busy.htaSummary
    ? 'Assessing the HTA summary from the analyses run so far.'
    : 'Run the base case, the PSA, the value of information, the budget impact and the DHT readiness analyses you want included, then select Assess HTA summary.',
)
const priorities = computed(() => result.value?.evidence_priorities.table ?? [])
const availability = computed(() => result.value?.availability ?? null)

/**
 * This is the final integrated decision tab. Its top accent follows R's overall
 * status once the summary has been assessed and stays neutral before that; the
 * status itself is R's and is never derived, scored or reworded here.
 */
const overallAccent = computed(() => {
  const status = summary.value?.overall_status
  if (status === 'Green') return 'is-good'
  if (status === 'Amber') return 'is-warning'
  if (status === 'Red') return 'is-bad'
  return null
})

/**
 * The rules and notes R publishes with the summary (eqalb_ui_copy.R). They are
 * rendered exactly as returned: the seven rule sentences the Shiny dashboard puts
 * in its popover, the note under the evidence-priority table, and the
 * single-paragraph rule summary.
 */
const rules = computed(() => result.value?.rules ?? [])
const evidenceNote = computed(() => result.value?.evidence_note ?? '')
const ruleNote = computed(() => result.value?.rule_note ?? '')

/**
 * Escape closes the rules disclosure through the app-wide disclosure behaviour in
 * useDisclosure.ts, which every screen installs, so this tab needs no handler of
 * its own.
 */

/**
 * R reports the two lists in the availability block as character vectors, and a
 * vector of exactly one entry arrives from plumber as a bare JSON string
 * (`auto_unbox`), not a one-element list — so a single missing field or a single
 * not-assessable domain would make `.join` below throw and take the whole tab
 * down with it. Both shapes are normalised to a list here, at the boundary; the
 * values themselves are untouched.
 */
function asList(value: unknown): string[] {
  if (Array.isArray(value)) return value as string[]
  return typeof value === 'string' && value !== '' ? [value] : []
}

const missingInputs = computed(() => asList(availability.value?.missing_inputs))
const notAssessableDomains = computed(() => asList(availability.value?.not_assessable_domains))

/** Labels for the availability flags the endpoint reports. */
const ANALYSIS_FLAGS = [
  { key: 'base_case', label: 'Base case' },
  { key: 'psa', label: 'PSA' },
  { key: 'value_of_information', label: 'Value of information' },
  { key: 'budget_impact', label: 'Budget impact' },
  { key: 'readiness', label: 'DHT readiness' },
] as const

const includedAnalyses = computed(() => {
  const flags = availability.value
  if (!flags) return []
  return ANALYSIS_FLAGS.filter((entry) => flags[entry.key]).map((entry) => entry.label)
})

const missingAnalyses = computed(() => {
  const flags = availability.value
  if (!flags) return []
  return ANALYSIS_FLAGS.filter((entry) => !flags[entry.key]).map((entry) => entry.label)
})

/** "Not available" keeps R's wording and gets no traffic-light colour. */
function statusClass(status: HtaSummaryStatus): string {
  if (status === 'Green') return 'badge badge--good'
  if (status === 'Amber') return 'badge badge--warning'
  if (status === 'Red') return 'badge badge--danger'
  return 'badge'
}

/** The badge tone for the same status, for the overall-status metric accent. */
function statusTone(status: HtaSummaryStatus): Tone {
  if (status === 'Green') return 'good'
  if (status === 'Red') return 'bad'
  return 'neutral'
}

/** R's own priority words; "Not yet available" is not a rating. */
function priorityClass(priority: string): string {
  if (priority === 'High') return 'badge badge--danger'
  if (priority === 'Medium') return 'badge badge--warning'
  if (priority === 'Low') return 'badge badge--good'
  return 'badge'
}

/**
 * The optional value-based price insight.
 *
 * It reads the Value-based Price tab's own stored result from the shared store
 * and returns null when there is none, so nothing is requested, gated or
 * recalculated: the HTA summary endpoint neither accepts nor requires these
 * fields. Every value shown is R's, formatted with the same helpers the
 * Value-based Price tab uses, and `headline.interpretation` is R's own sentence.
 */
const priceInsight = computed(() => {
  const price = model.valueBasedPrice
  if (!price) return null
  const headline = price.headline
  return {
    maximum: isNum(headline.max_acceptable_price)
      ? formatEuro(headline.max_acceptable_price, 2)
      : 'Not available',
    current: formatEuro(price.current_price, 2),
    headroom: isNum(headline.headroom_eur)
      ? formatEuro(headline.headroom_eur, 2)
      : 'not identified by R',
    interpretation: headline.interpretation,
  }
})

// --- Presentation mode -------------------------------------------------------

/**
 * The summary being presented, held as the response itself: R's overall position,
 * the domain statuses, the evidence-priority table and the availability block all
 * travel in it, so what was included and what was missing stays exactly as it was
 * when the summary was assessed — including the older result of an analysis the
 * panel has since re-run.
 */
const presented = shallowRef<HtaSummaryResponse | null>(null)
const presentButton = ref<HTMLButtonElement | null>(null)

/** The revision of this tab's stored result when the overlay was opened. */
const presentedRevision = ref(0)

function openPresentation(): void {
  presented.value = result.value
  presentedRevision.value = model.resultRevisions.htaSummary
}

/** The line shown when a later run has replaced this result while it is open. */
const presentedSuperseded = computed(() =>
  presented.value !== null && model.resultRevisions.htaSummary !== presentedRevision.value
    ? supersededSentence()
    : '',
)

function closePresentation(): void {
  presented.value = null
}

/**
 * The settings this summary was assessed from. They are the availability flags R
 * itself reports — which upstream analyses were included and which request fields
 * were missing — rather than the store's current results, so a re-run behind the
 * overlay cannot make the summary claim to include it.
 */
const presentedSettings = computed<PresentationSetting[]>(() => {
  const run = presented.value
  if (!run) return []
  const flags = run.availability
  const rows: PresentationSetting[] = [
    settingRow('threshold', 'Reference WTP threshold', formatEuro(run.wtp), '€/QALY'),
    settingRow(
      'domains',
      'Domains assessed',
      `${flags.assessed_domains} of ${run.summary.domains.length}`,
      '',
    ),
    ...(ANALYSIS_FLAGS.map((entry) =>
      settingRow(
        entry.key,
        entry.label,
        flags[entry.key] ? 'Included' : 'Not yet available',
        '',
      ),
    )),
  ]
  const missing = asList(flags.missing_inputs)
  if (missing.length > 0) {
    // The endpoint's own field names are identifiers; the overlay names each one
    // as the workspace names that value, so a reader sees what was not available
    // rather than what the request body called it.
    rows.push(
      settingRow('missing', 'Values not supplied', missing.map(availabilityFieldLabel).join(', '), ''),
    )
  }
  const notAssessable = asList(flags.not_assessable_domains)
  if (notAssessable.length > 0) {
    rows.push(settingRow('notassessable', 'Not assessable', notAssessable.join(', '), ''))
  }
  return rows
})

const presentedStale = computed(() =>
  presented.value && model.htaSummaryStale
    ? movedSentence(['the analyses this summary was assessed with'])
    : '',
)

/** The upstream analyses the presented summary reports as not yet included. */
const presentedMissing = computed(() => {
  const run = presented.value
  if (!run) return []
  return ANALYSIS_FLAGS.filter((entry) => !run.availability[entry.key]).map(
    (entry) => entry.label,
  )
})

const settingsNote = computed(() =>
  model.htaSummaryStale
    ? 'What this summary included is listed as it was assessed. An analysis has been re-run since, so the panel’s current results are not shown as the summary’s: its position describes the analyses that existed when it ran.'
    : 'What this summary included is listed as R reported it for this assessment; the panel’s stored analyses still match it.',
)
</script>

<template>
  <section class="panel panel--decision" :class="overallAccent">
    <header class="panel__header">
      <div>
        <h2>HTA decision summary</h2>
        <ResultTrace :reveal-class="revealClass" />
        <p class="muted">What do the analyses run so far add up to?</p>
      </div>
      <div class="panel__actions">
        <button
          type="button"
          class="btn btn--primary"
          :disabled="model.busy.htaSummary"
          @click="model.runHtaSummary()"
        >
          <ButtonLabel :busy="model.busy.htaSummary" idle="Assess HTA summary" pending="Assessing the HTA summary…" />
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

    <p v-if="model.errors.htaSummary" class="alert alert--danger" role="alert">
      {{ model.errors.htaSummary }}
    </p>

    <StaleNotice v-if="result && model.htaSummaryStale" action="Assess HTA summary" />

    <p v-if="!result" class="hint" role="status">
      {{ stateLine }}
    </p>

    <div v-if="result && summary" class="result-reveal" :class="revealClass">
      <div class="metrics">
        <MetricCard
          label="Overall HTA decision position"
          :value="summary.position"
          :tone="statusTone(summary.overall_status)"
          :sub="
            summary.overall_status === 'Not available'
              ? `${result.availability.assessed_domains} of ${summary.domains.length} domains assessed`
              : `${summary.overall_status} · ${result.availability.assessed_domains} of ${summary.domains.length} domains assessed`
          "
        />
      </div>

      <p class="alert alert--info">{{ summary.interpretation }}</p>

      <p v-if="missingAnalyses.length" class="alert alert--warning">
        Not yet included: {{ missingAnalyses.join(', ') }}.
        <template v-if="notAssessableDomains.length">
          R reports these domains as not assessable: {{ notAssessableDomains.join(', ') }}.
        </template>
      </p>

      <!-- The value-based price insight is read from the session's own stored
           result. It is not part of the HTA summary request and does not gate it;
           when no result is stored the section is simply absent. -->
      <section v-if="priceInsight" class="insight">
        <h3 class="insight__heading">Value-based price, from this session</h3>
        <p class="insight__line">
          R's maximum acceptable annual price is
          <strong>{{ priceInsight.maximum }}</strong>, against a current annual price of
          {{ priceInsight.current }}; R reports headroom of {{ priceInsight.headroom }}.
        </p>
        <p class="muted insight__note">{{ priceInsight.interpretation }}</p>
        <p class="muted insight__note">
          Read from the Value-based Price tab's own result. It is not an input to this summary and
          does not change the position above.
        </p>
      </section>

      <details class="details">
        <summary>Decision dashboard ({{ summary.domains.length }} domains)</summary>
        <figure class="table-figure">
          <figcaption class="table-figure__caption">Decision dashboard, illustrative</figcaption>
          <div class="table-scroll">
            <table class="table table--wrap" aria-label="Decision dashboard, illustrative">
              <thead>
                <tr>
                  <th scope="col">Domain</th>
                  <th scope="col">Status</th>
                  <th scope="col">Current values</th>
                  <th scope="col">Plain-language interpretation</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="domain in summary.domains" :key="domain.Domain">
                  <td>{{ domain.Domain }}</td>
                  <td>
                    <span :class="statusClass(domain.Status)">{{ domain.Status }}</span>
                  </td>
                  <td>{{ domain.Measure }}</td>
                  <td>{{ domain.Interpretation }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </figure>
      </details>

      <details class="details">
        <summary>Evidence priorities ({{ priorities.length }})</summary>
        <p class="alert alert--info">{{ result.evidence_priorities.summary }}</p>

        <figure class="table-figure">
          <figcaption class="table-figure__caption">Evidence priorities, illustrative</figcaption>
          <div class="table-scroll">
            <table class="table table--wrap" aria-label="Evidence priorities, illustrative">
              <thead>
                <tr>
                  <th scope="col">Priority</th>
                  <th scope="col">Evidence gap</th>
                  <th scope="col">Evidence needed</th>
                  <th scope="col">Current status</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in priorities" :key="row['Evidence gap']">
                  <td>
                    <span :class="priorityClass(row.Priority)">{{ row.Priority }}</span>
                  </td>
                  <td>{{ row['Evidence gap'] }}</td>
                  <td>{{ row['Evidence needed'] }}</td>
                  <td>{{ row['Current status'] }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </figure>

        <p v-if="evidenceNote" class="hint">{{ evidenceNote }}</p>

        <div v-for="row in priorities" :key="row['Evidence gap']">
          <p>
            <strong>{{ row['Evidence gap'] }}</strong>
            <span :class="priorityClass(row.Priority)">{{ row.Priority }}</span>
          </p>
          <ul class="list">
            <li><strong>Current model signal:</strong> {{ row['Current model signal'] }}</li>
            <li><strong>Why it matters:</strong> {{ row['Why it matters'] }}</li>
            <li>
              <strong>Suggested study or data source:</strong>
              {{ row['Suggested study or data source'] }}
            </li>
            <li><strong>Dashboard domain affected:</strong> {{ row['Dashboard domain affected'] }}</li>
          </ul>
        </div>
      </details>

      <details v-if="rules.length > 0" class="details">
        <summary>Traffic-light rules used</summary>
        <ul class="list">
          <li v-for="rule in rules" :key="rule">{{ rule }}</li>
        </ul>
        <p v-if="ruleNote" class="muted">{{ ruleNote }}</p>
      </details>

      <details v-if="availability" class="details">
        <summary>Availability of the upstream analyses</summary>
        <p class="muted">
          Included in this summary: {{ includedAnalyses.join(', ') || 'none' }}.
          <template v-if="missingAnalyses.length">
            Not yet included: {{ missingAnalyses.join(', ') }}.
          </template>
        </p>
        <ul class="list">
          <li v-for="entry in ANALYSIS_FLAGS" :key="entry.key">
            <strong>{{ entry.label }}:</strong>
            {{ availability[entry.key] ? 'included' : 'not included' }}
          </li>
        </ul>
        <template v-if="notAssessableDomains.length">
          <p class="muted">
            Domains R reports as not assessable:
            {{ notAssessableDomains.join(', ') }}.
          </p>
        </template>
        <template v-if="missingInputs.length">
          <p class="muted">
            Request fields not supplied:
            <code>{{ missingInputs.join(', ') }}</code>
          </p>
        </template>
      </details>
    </div>

    <!-- Presentation mode: R's own position, domains, availability and evidence
         priorities, as they were when this summary was assessed. -->
    <PresentationOverlay
      v-if="presented && presented.summary"
      title="HTA decision summary"
      :notice="presented.notice"
      :stale="presentedStale"
      settings-label="What this summary included"
      :settings-note="settingsNote"
      :superseded="presentedSuperseded"
      :fallback-focus="() => presentButton"
      @close="closePresentation()"
    >
      <div class="metrics present__metrics">
        <MetricCard
          label="Overall HTA decision position"
          :value="presented.summary.position"
          :tone="statusTone(presented.summary.overall_status)"
          :sub="
            presented.summary.overall_status === 'Not available'
              ? `${presented.availability.assessed_domains} of ${presented.summary.domains.length} domains assessed`
              : `${presented.summary.overall_status} · ${presented.availability.assessed_domains} of ${presented.summary.domains.length} domains assessed`
          "
        />
      </div>

      <p class="alert alert--info">{{ presented.summary.interpretation }}</p>

      <figure class="table-figure">
        <figcaption class="table-figure__caption">
          Decision dashboard, illustrative ({{ presented.summary.domains.length }} domains)
        </figcaption>
        <div class="table-scroll">
          <table class="table table--wrap" aria-label="Decision dashboard, illustrative">
            <thead>
              <tr>
                <th scope="col">Domain</th>
                <th scope="col">Status</th>
                <th scope="col">Current values</th>
                <th scope="col">Plain-language interpretation</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="domain in presented.summary.domains" :key="domain.Domain">
                <td>{{ domain.Domain }}</td>
                <td><span :class="statusClass(domain.Status)">{{ domain.Status }}</span></td>
                <td>{{ domain.Measure }}</td>
                <td>{{ domain.Interpretation }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </figure>

      <p v-if="presentedMissing.length" class="alert alert--warning">
        Not yet included: {{ presentedMissing.join(', ') }}.
      </p>

      <details class="details">
        <summary>
          Evidence priorities ({{ presented.evidence_priorities.table.length }})
        </summary>
        <p class="alert alert--info">{{ presented.evidence_priorities.summary }}</p>
        <div class="table-scroll">
          <table class="table table--wrap" aria-label="Evidence priorities, illustrative">
            <thead>
              <tr>
                <th scope="col">Priority</th>
                <th scope="col">Evidence gap</th>
                <th scope="col">Evidence needed</th>
                <th scope="col">Current status</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in presented.evidence_priorities.table"
                :key="row['Evidence gap']"
              >
                <td>
                  <span :class="priorityClass(row.Priority)">{{ row.Priority }}</span>
                </td>
                <td>{{ row['Evidence gap'] }}</td>
                <td>{{ row['Evidence needed'] }}</td>
                <td>{{ row['Current status'] }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-if="presented.evidence_note" class="hint">{{ presented.evidence_note }}</p>
      </details>

      <details v-if="presented.rules.length > 0" class="details">
        <summary>Traffic-light rules used</summary>
        <ul class="list">
          <li v-for="rule in presented.rules" :key="rule">{{ rule }}</li>
        </ul>
        <p v-if="presented.rule_note" class="muted">{{ presented.rule_note }}</p>
      </details>

      <template #settings>
        <PresentationSettings :rows="presentedSettings" />
      </template>
    </PresentationOverlay>
  </section>
</template>
