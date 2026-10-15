<script setup lang="ts">
/**
 * Value-based price.
 *
 * Every figure on this tab — the maximum acceptable annual price, the headroom
 * against the current price, the relative risk reduction the current price would
 * need, the 3 x 3 scan, the status bands, the axis labels, the reasons and every
 * sentence — is computed by calculate_value_based_price() in eqalb_price.R and
 * returned by POST /api/value-based-price. This component only presents that
 * response: it never solves for a price, compares a price with a threshold,
 * infers a missing value, colours a scan cell by anything other than the status R
 * supplies for that cell, or rewords R's text.
 *
 * The tab is laid out as decision support rather than as a description of the
 * implementation. The order is the order a reader needs: the price R identified
 * and the current price beside it, the comparison chart, R's plain-language
 * summary of that comparison, the required effectiveness at the current price,
 * and then the detail. The two disclosures hold what a reader only needs
 * sometimes — what qualifies the figures, and the scenario scan. R's
 * engineering provenance (`method`, `method_note`) is deliberately not rendered
 * here at all: it stays in the API and the exported package for anyone auditing
 * how a number was produced.
 *
 * The analysis is deterministic but costs about 40 model runs, so it follows the
 * established tab pattern: it runs only from its own button, a stored result stays
 * on screen while the assumptions change, and a result computed from earlier
 * inputs is marked as such rather than recalculated or removed.
 */

import { computed } from 'vue'
import type { PriceScanCell, PriceScanLevel } from '../api/types'
import type { Tone } from '../format'
import { formatEuro, formatNumber, formatPercent, formatThreshold, isNum } from '../format'
import DataTable from './DataTable.vue'
import ButtonLabel from './ButtonLabel.vue'
import InfoTip from './InfoTip.vue'
import MetricCard from './MetricCard.vue'
import ResultTrace from './ResultTrace.vue'
import StaleNotice from './StaleNotice.vue'
import ValueBasedPriceComparison from './charts/ValueBasedPriceComparison.vue'
import type { Column } from './table'
import { useModel } from '../composables/useModel'
import { useResultEntrance } from '../composables/useResultEntrance'

const model = useModel()
// The entrance this tab's result plays when it is committed; see the composable.
const { revealClass } = useResultEntrance('valueBasedPrice')

const result = computed(() => model.valueBasedPrice)
const headline = computed(() => result.value?.headline ?? null)
const required = computed(() => result.value?.required_effect ?? null)
const grid = computed(() => result.value?.grid ?? null)
const availability = computed(() => result.value?.availability ?? null)

/** Request-level notes R returns with the response (currently a price override). */
const warnings = computed(() => result.value?.warnings ?? [])

/** The scan rows in the order R supplied them: one row per assumption pair. */
const cells = computed(() => grid.value?.cells ?? [])

/**
 * The cell for one assumption pair. Both sides come from the same response, so a
 * missing pair would mean the grid is not the full cross product; the lookup
 * returns null rather than inventing a value and the table shows a dash.
 */
function cellFor(row: PriceScanLevel, column: PriceScanLevel): PriceScanCell | null {
  return (
    cells.value.find(
      (cell) =>
        Math.abs(cell.row_value - row.value) < 1e-9 &&
        Math.abs(cell.column_value - column.value) < 1e-9,
    ) ?? null
  )
}

/** One scan cell's price, with R's "Not available" wording when it has none. */
function cellPrice(row: PriceScanLevel, column: PriceScanLevel): string {
  const cell = cellFor(row, column)
  return cell ? priceText(cell.max_acceptable_price) : '—'
}

/** One scan cell's status band, straight from R; "" when the pair is absent. */
function cellStatus(row: PriceScanLevel, column: PriceScanLevel): string {
  return cellFor(row, column)?.status ?? ''
}

/**
 * R's status band, styled with the tone the rest of the app uses for traffic
 * lights. "Not available" is R's own wording and deliberately gets no colour, so
 * a missing result never looks like a decision.
 */
function statusClass(status: string): string {
  if (status === 'Green') return 'badge badge--good'
  if (status === 'Red') return 'badge badge--danger'
  return 'badge'
}

function statusTone(status: string): Tone {
  if (status === 'Green') return 'good'
  if (status === 'Red') return 'bad'
  return 'neutral'
}

/**
 * A price R could not identify is shown with R's own "Not available" wording,
 * never as a zero or a dash that could be read as a number.
 */
function priceText(value: number | null): string {
  return isNum(value) ? formatEuro(value, 2) : 'Not available'
}

/** R reports headroom as a percentage number; the app's formatter takes fractions. */
function headroomPercentText(value: number | null): string {
  return isNum(value) ? formatPercent(value / 100, 1) : '—'
}

const headroomSub = computed(() => {
  const metrics = headline.value
  if (!metrics) return ''
  const current = formatEuro(result.value?.current_price ?? null, 2)
  const percent = isNum(metrics.headroom_pct)
    ? ` (${formatPercent(metrics.headroom_pct / 100, 1)} of the current price)`
    : ''
  return `the gap between the current price of ${current} and the maximum acceptable price${percent}`
})

/**
 * The comparison chart's own note, relocated from beneath the chart into the
 * information button beside its header. It states R's headroom exactly as the
 * chart stated it, and R's own no-comparison wording when no maximum price was
 * identified, so the button and the bars cannot disagree.
 */
const priceChartInfo = computed(() => {
  const metrics = headline.value
  const current = result.value?.current_price ?? null
  if (!metrics || !metrics.available || !isNum(current) || !isNum(metrics.max_acceptable_price)) {
    return 'No maximum acceptable price was identified for this analysis, so there is no comparison to draw.'
  }
  if (!isNum(metrics.headroom_eur)) return 'No headroom was identified for this analysis.'
  const percent = isNum(metrics.headroom_pct)
    ? ` (${formatPercent(metrics.headroom_pct / 100, 1)} of the current price)`
    : ''
  return `Headroom between the current price and the maximum acceptable price: ${formatEuro(metrics.headroom_eur, 2)}${percent}.`
})

/**
 * R's scenario block. Only the assumptions and the model results a reader needs
 * to see what the price rests on: the engineering quantities R also returns
 * (the cost response to the price, the cost at a price of zero and the price
 * contribution) are left out of the interface.
 */
const scenarioRows = computed(() => {
  const scenario = result.value?.scenario
  if (!scenario) return []
  return [
    { measure: 'Relative risk reduction among engaged users', value: formatPercent(scenario.rrr) },
    { measure: 'Year-1 engagement', value: formatPercent(scenario.engagement_year1) },
    { measure: 'Follow-up engagement', value: formatPercent(scenario.engagement_followup) },
    { measure: 'Incremental cost (EUR)', value: formatEuro(scenario.incremental_cost, 2) },
    { measure: 'Incremental QALYs', value: formatNumber(scenario.incremental_qalys, 6) },
    { measure: 'ICER (EUR per QALY)', value: formatEuro(scenario.icer, 2) },
    {
      measure: 'Incremental net monetary benefit (EUR)',
      value: formatEuro(scenario.incremental_nmb, 2),
    },
  ]
})

const scenarioColumns: Column<{ measure: string; value: string }>[] = [
  { key: 'measure', label: 'Measure', value: (row) => row.measure },
  { key: 'value', label: 'Value', align: 'right', value: (row) => row.value },
]

/**
 * The scan detail. Each row is one assumption pair as R returned it: the model
 * results for it, R's price, R's headroom, R's status band and R's note when the
 * pair could not be identified. The raw solved price and the availability flag
 * are engineering values and are not shown.
 */
const cellColumns: Column<PriceScanCell>[] = [
  { key: 'row_label', label: 'Risk reduction level', value: (row) => row.row_label },
  { key: 'column_label', label: 'Year-1 engagement level', value: (row) => row.column_label },
  {
    key: 'incremental_cost',
    label: 'Incremental cost (EUR)',
    align: 'right',
    value: (row) => formatEuro(row.incremental_cost, 2),
  },
  {
    key: 'incremental_qalys',
    label: 'Incremental QALYs',
    align: 'right',
    value: (row) => formatNumber(row.incremental_qalys, 6),
  },
  {
    key: 'max_acceptable_price',
    label: 'Maximum acceptable price (EUR)',
    align: 'right',
    value: (row) => priceText(row.max_acceptable_price),
  },
  {
    key: 'headroom_eur',
    label: 'Headroom (EUR)',
    align: 'right',
    value: (row) => formatEuro(row.headroom_eur, 2),
  },
  {
    key: 'headroom_pct',
    label: 'Headroom (% of current price)',
    align: 'right',
    value: (row) => headroomPercentText(row.headroom_pct),
  },
  { key: 'status', label: 'Status', value: (row) => row.status },
  { key: 'warning', label: 'Note', value: (row) => row.warning || '—' },
]

/**
 * R's reasons for any result it could not identify. Empty when everything was
 * identified, in which case the disclosure shows no availability list at all.
 */
const availabilityReasons = computed(() => {
  const reasons = availability.value?.reasons
  if (!reasons) return []
  return [
    { label: 'Maximum acceptable price', reason: reasons.max_acceptable_price },
    { label: 'Required relative risk reduction', reason: reasons.required_effect },
    { label: 'Scan', reason: reasons.grid },
  ].filter((entry) => entry.reason !== '')
})
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <h2>Value-based price</h2>
        <ResultTrace :reveal-class="revealClass" />
        <p class="muted">
          The highest annual price the model supports at the reference threshold, and how the
          current price compares with it.
        </p>
      </div>
      <div class="panel__actions">
        <button
          type="button"
          class="btn btn--primary"
          :disabled="model.busy.valueBasedPrice"
          @click="model.runValueBasedPrice()"
        >
          <ButtonLabel :busy="model.busy.valueBasedPrice" idle="Calculate value-based price" pending="Calculating…" />
        </button>
      </div>
    </header>

    <p v-if="model.errors.valueBasedPrice" class="alert alert--danger">
      {{ model.errors.valueBasedPrice }}
    </p>

    <StaleNotice
      v-if="result && model.valueBasedPriceStale"
      action="Calculate value-based price"
      :detail="`The stored result used a threshold of ${formatThreshold(result.wtp)}.`"
    />

    <p v-if="!result && !model.busy.valueBasedPrice" class="hint">
      The analysis runs the model about 40 times, so it takes a few seconds, and it runs only when
      you use “Calculate value-based price”. A result stays on screen while the assumptions change,
      and is marked as computed from earlier inputs rather than recalculated or removed.
    </p>
    <div v-if="result && headline" class="result-reveal" :class="revealClass">
      <p v-for="warning in warnings" :key="warning" class="alert alert--warning">
        {{ warning }}
      </p>

      <div class="metrics">
        <MetricCard
          label="Maximum acceptable annual price"
          :value="priceText(headline.max_acceptable_price)"
          :tone="statusTone(result.status)"
          :sub="`Status: ${result.status} · reference threshold ${formatEuro(result.wtp, 0)}/QALY`"
        />
        <MetricCard
          label="Current annual price"
          :value="formatEuro(result.current_price, 2)"
          sub="the price the analysis ran at and compared against"
        />
        <MetricCard
          label="Price headroom"
          :value="formatEuro(headline.headroom_eur, 2)"
          :tone="statusTone(result.status)"
          :sub="headroomSub"
        />
      </div>

      <figure class="chart-figure">
        <figcaption>
          Current annual price against the maximum acceptable price
          <InfoTip :text="priceChartInfo" topic="the price comparison chart" />
        </figcaption>
        <ValueBasedPriceComparison
          :current-price="result.current_price"
          :max-acceptable-price="headline.max_acceptable_price"
          :status="result.status"
        />
      </figure>

      <p :class="headline.available ? 'alert alert--info' : 'alert alert--warning'">
        <span v-if="!headline.available" :class="statusClass(headline.status)">{{ headline.status }}</span>
        {{ headline.interpretation }}
      </p>

      <div v-if="required" class="callout">
        <p class="callout__title">
          <span>Required effectiveness at the current price</span>
          <span class="badge">{{ required.verdict_label }}</span>
        </p>
        <p class="callout__text">{{ required.interpretation }}</p>
      </div>

      <details class="details">
        <summary>What this price means</summary>
        <p class="hint">{{ result.limitation }}</p>
        <p class="muted">
          Reference threshold: {{ formatEuro(result.wtp, 0) }}/QALY. Current annual price:
          {{ formatEuro(result.current_price, 2) }}.
        </p>
        <template v-if="availabilityReasons.length">
          <ul class="list">
            <li v-for="entry in availabilityReasons" :key="entry.label">
              <strong>{{ entry.label }}:</strong> {{ entry.reason }}
            </li>
          </ul>
        </template>
        <DataTable
          :columns="scenarioColumns"
          :rows="scenarioRows"
          caption="The assumptions and model results this price rests on, illustrative"
        />
      </details>

      <details v-if="grid" class="details">
        <summary>Explore price scenarios</summary>
        <figure class="table-figure">
          <figcaption class="table-figure__caption">
            Maximum acceptable annual price by assumption, illustrative
            <span class="muted">
              (rows: {{ grid.row_axis.parameter }}; columns: {{ grid.column_axis.parameter }})
            </span>
          </figcaption>
          <div class="table-scroll">
            <table
              class="table table--wrap"
              aria-label="Maximum acceptable annual price by assumption, illustrative"
            >
              <thead>
                <tr>
                  <th scope="col">
                    {{ grid.row_axis.parameter }} / {{ grid.column_axis.parameter }}
                  </th>
                  <th
                    v-for="level in grid.column_axis.levels"
                    :key="level.value"
                    scope="col"
                    class="is-right"
                  >
                    {{ level.label }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in grid.row_axis.levels" :key="row.value">
                  <th scope="row">{{ row.label }}</th>
                  <td
                    v-for="column in grid.column_axis.levels"
                    :key="column.value"
                    class="is-right"
                  >
                    {{ cellPrice(row, column) }}
                    <span v-if="cellStatus(row, column)" :class="statusClass(cellStatus(row, column))">
                      {{ cellStatus(row, column) }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </figure>

        <p class="alert alert--info">{{ grid.summary }}</p>
        <p class="hint">{{ grid.note }}</p>

        <p v-if="grid.cells_available < grid.cells_total" class="muted">
          Combinations R identified: {{ grid.cells_available }} of {{ grid.cells_total }}.
        </p>
        <p
          v-if="isNum(grid.best.max_acceptable_price) && isNum(grid.worst.max_acceptable_price)"
          class="muted"
        >
          Best and worst identified combination: best
          {{ priceText(grid.best.max_acceptable_price) }} ({{ grid.best.row_label }},
          {{ grid.best.column_label }}), worst
          {{ priceText(grid.worst.max_acceptable_price) }} ({{ grid.worst.row_label }},
          {{ grid.worst.column_label }}).
        </p>

        <DataTable
          :columns="cellColumns"
          :rows="cells"
          caption="Scan detail per assumption combination, illustrative"
        />
      </details>
    </div>
  </section>
</template>
