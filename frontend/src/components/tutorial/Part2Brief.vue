<script setup lang="ts">
/**
 * Part 2, section 1: the case brief.
 *
 * The scenario copy is presentation copy and lives here, with every number read
 * from R's own fields (the price control's default, the threshold and the budget
 * ceiling) and R's own case identity (the label and title) selecting the neutral
 * case-difference line below. The fourteen fact rows, their values, the group
 * names, the column headings, the facts heading and the start-button label are
 * all R's. This component groups R's rows by R's own group label — the only thing
 * it does with them — so no case value is written here.
 *
 * The case-difference line is Vue's, keyed by R's own case title, and deliberately
 * replaces R's `case.summary` sentence: two of R's three summaries end by saying
 * how many prices or how much coverage pass, which would tell the learner the
 * answer the exercise is asking them to find. The replacement says only what the
 * case is (size, evidence, engagement, languages) and never what it implies for
 * the tests. An unrecognised title falls back to a sentence that states nothing
 * about the case at all, so a future R case can never leak an outcome through
 * this line.
 *
 * The manufacturer's price is framed as a starting proposal for negotiation, not
 * as a floor or a target: €150 appears only where it already belongs to R, as the
 * case-facts row R labels "Manufacturer's reference price". The baseline
 * clinical description is likewise deliberately generic and leaves every
 * case-specific fact to this line and to R's table.
 */

import { computed } from 'vue'
import type { Part2CaseFact, Part2Contract } from '../../api/types'
import { formatEuro } from '../../format'

const props = defineProps<{
  contract: Part2Contract
  /** R's own identity for the active case; its title selects the case line below. */
  caseTitle: string
  facts: Part2CaseFact[]
}>()

const emit = defineEmits<{ start: [] }>()

/** R's rows, grouped by R's group label, in R's order. */
const groups = computed(() => {
  const collected: { name: string; rows: Part2CaseFact[] }[] = []
  for (const row of props.facts) {
    const last = collected[collected.length - 1]
    if (last && last.name === row.group) {
      last.rows.push(row)
    } else {
      collected.push({ name: row.group, rows: [row] })
    }
  }
  return collected
})

const headings = computed(() => props.contract.case_facts.table_headings)

/**
 * The neutral case-difference line, one entry per case title R publishes. Each
 * sentence states only what the case is; none says or hints how many prices or
 * how much coverage would pass, which is the answer the exercise asks for. The
 * fallback is used for an unrecognised title and describes nothing.
 */
const CASE_LINES: Record<string, string> = {
  'Regional roll-out':
    'A broad regional roll-out covering 100,000 potentially eligible people, with moderate ' +
    'supporting evidence and standards-based interoperability.',
  'Integrated pilot':
    'This is a smaller, more integrated pilot with stronger supporting evidence and better ' +
    'expected follow-up engagement than the regional roll-out.',
  'Fragmented deployment':
    'This is a wider deployment with weaker supporting evidence and fewer supported languages ' +
    'than the regional roll-out.',
}

const caseLine = computed(
  () => CASE_LINES[props.caseTitle] ?? 'The fixed facts of this case are listed below.',
)

/** R's own numbers, rendered with the app's currency formatter. */
const manufacturerPrice = computed(() => formatEuro(props.contract.price_control.default))
const threshold = computed(() => formatEuro(props.contract.fixed.threshold))
const budgetCeiling = computed(() => formatEuro(props.contract.fixed.budget_ceiling))
</script>

<template>
  <section class="tutorial__step" aria-labelledby="part2-brief-title">
    <h3 id="part2-brief-title" class="tutorial__step-title" tabindex="-1">
      {{ contract.brief.heading }}
    </h3>

    <p class="part2__task">What funding position will you recommend?</p>

    <h4 class="tutorial__heading">What this case is about</h4>
    <p class="page__prose">
      A health service is considering whether to fund eQalb, a digital therapeutic that supports
      adults after a heart attack or stroke. The programme uses an app to help people manage
      their recovery and reduce the chance of further cardiovascular events.
    </p>
    <p class="page__prose" data-part2-case-summary>{{ caseLine }}</p>

    <h4 class="tutorial__heading">What the manufacturer proposes</h4>
    <p class="page__prose">
      The manufacturer has proposed a starting price of {{ manufacturerPrice }} per active user
      per year — each person actively using the programme. Your task is to negotiate a price
      that the health service could responsibly fund.
    </p>

    <h4 class="tutorial__heading">What the health service must decide</h4>
    <p class="page__prose">
      The health service must decide whether to fund the programme, how much it is willing to
      pay, and how many people to include at first. It has three conditions: the extra health
      must be worth the extra cost at its value-for-money threshold of {{ threshold }} per QALY
      (a standard measure of health gain that combines extra years of life with health-related
      quality of life); total spending over five years must stay within {{ budgetCeiling }}; and
      the programme must not have any Red readiness barrier.
    </p>

    <h4 class="tutorial__heading">What you will choose</h4>
    <ul class="list page__list">
      <li>The yearly price agreed with the manufacturer for each active user.</li>
      <li>
        The share of eligible people the programme covers at first — the coverage cap.
      </li>
    </ul>
    <p class="page__prose">
      You cannot change the clinical evidence or the local facts of this case to make the result
      look better.
    </p>

    <h4 class="tutorial__heading">What happens next</h4>
    <p class="page__prose">
      In the following sections you will test whether the programme is worth the money, whether
      it fits the available budget, whether it could be delivered in practice, and what the
      decision should be.
    </p>

    <!-- The fixed facts, collapsed by default: the brief leads with the task and
         the scenario, and the table is opened when the learner wants it. R's own
         controls heading is the summary, and the glossary sits inside the same
         disclosure so the brief itself carries no reference subtext. -->
    <details class="details">
      <summary>{{ contract.brief.controls_heading }}</summary>
      <div class="table-scroll">
        <table class="table table--wrap" :aria-label="contract.brief.controls_heading">
          <thead>
            <tr>
              <th scope="col">{{ headings.group }}</th>
              <th scope="col">{{ headings.fact }}</th>
              <th scope="col">{{ headings.value }}</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="group in groups" :key="group.name">
              <tr
                v-for="row in group.rows"
                :key="`${group.name}-${row.fact}`"
                :data-fact="row.fact"
              >
                <th scope="row">{{ row.group }}</th>
                <td>{{ row.fact }}</td>
                <td>{{ row.value }}</td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
      <p class="field__hint">
        A few terms in the table: a utility is a measure of health-related quality of life, from 0
        (as bad as death) to 1 (full health). The willingness-to-pay threshold is the most the
        health service will pay for one additional QALY. A readiness domain is one area of the
        readiness check, graded Green (no concern), Amber (needs attention), or Red (a barrier).
      </p>
    </details>

    <div class="tutorial__nav">
      <button type="button" class="btn btn--primary" @click="emit('start')">
        {{ contract.brief.start_label }}
      </button>
    </div>
  </section>
</template>
