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

import { computed } from 'vue'
import type { HtaSummaryStatus } from '../api/types'
import type { Tone } from '../format'
import MetricCard from './MetricCard.vue'
import StaleNotice from './StaleNotice.vue'
import { useModel } from '../composables/useModel'
import { formatEuro, isNum } from '../format'

const model = useModel()

const result = computed(() => model.htaSummary)
const summary = computed(() => result.value?.summary ?? null)
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
</script>

<template>
  <section class="panel panel--decision" :class="overallAccent">
    <header class="panel__header">
      <div>
        <h2>HTA decision summary</h2>
        <p class="muted">
          Traffic-light decision dashboard and evidence-generation plan, built in R from the
          analyses already run in this session. Nothing is recalculated here, and anything not yet
          run is reported as not yet available rather than estimated.
        </p>
      </div>
      <button
        type="button"
        class="btn btn--primary"
        :disabled="model.busy.htaSummary"
        @click="model.runHtaSummary()"
      >
        {{ model.busy.htaSummary ? 'Assessing…' : 'Assess HTA summary' }}
      </button>
    </header>

    <p v-if="model.errors.htaSummary" class="alert alert--danger">{{ model.errors.htaSummary }}</p>

    <StaleNotice v-if="result && model.htaSummaryStale" action="Assess HTA summary" />

    <p v-if="!result && !model.busy.htaSummary" class="hint">
      The summary collects what the other tabs have produced. Run the base case, the PSA, the
      value-of-information, the budget-impact and the DHT readiness analyses you want included, then
      use “Assess HTA summary”. Each run is a snapshot of the analyses that existed when it ran.
    </p>

    <template v-if="result && summary">
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
        <template v-if="missingInputs.length">
          Request fields not supplied: {{ missingInputs.join(', ') }}.
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
    </template>
  </section>
</template>
