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

import { computed } from 'vue'
import type { ReadinessChoiceSet, ReadinessParameterSpec } from '../api/types'
import { NOT_INTERPRETABLE, formatCount, formatNumber, isNum } from '../format'
import { useModel } from '../composables/useModel'
import InfoTip from './InfoTip.vue'
import StaleNotice from './StaleNotice.vue'

const model = useModel()

const result = computed(() => model.readiness)

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
        <h2>DHT readiness and implementation</h2>
        <p class="muted">
          An illustrative readiness and implementation assessment of the digital therapeutic under
          the current assumptions. The assessment runs in R when you ask for it, using the seven
          domains, thresholds and wording of the Shiny model.
        </p>
      </div>
      <div class="panel__actions">
        <button
          type="button"
          class="btn btn--primary"
          :disabled="model.busy.readiness"
          @click="model.runReadiness()"
        >
          {{ model.busy.readiness ? 'Assessing…' : 'Assess readiness' }}
        </button>
        <button
          type="button"
          class="btn btn--ghost"
          title="Restore the seven readiness inputs — access, suitability, review minutes, languages, accessibility, interoperability and algorithm governance — to their defaults. The shared population and engagement values are global assumptions and are not changed. This clears the readiness assessment only."
          @click="model.resetReadinessInputs()"
        >
          Reset values
        </button>
      </div>
    </header>

    <p v-if="model.errors.readiness" class="alert alert--danger">{{ model.errors.readiness }}</p>

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

    <p v-if="!result && !model.busy.readiness" class="hint">
      The assessment is a snapshot: edit the inputs, then use “Assess readiness” to replace it. The
      simulated quantitative outputs and the domain ratings always describe the assessment shown
      below.
    </p>

    <template v-if="result">
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
    </template>
  </section>
</template>
