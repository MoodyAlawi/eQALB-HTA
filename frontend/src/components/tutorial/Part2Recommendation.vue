<script setup lang="ts">
/**
 * Part 2, section 5: the recommendation.
 *
 * Everything substantive here is R's: the outcome's headline and message, the
 * four criteria's verdicts, each readiness domain's status, the deliverability
 * verdict and the follow-up engagement restatement. This component decides
 * nothing — it never re-runs a criterion, never orders the outcomes and never
 * infers completion, because R returns the outcome and its own `complete` flag.
 *
 * The readiness traffic lights belong here rather than in the readiness
 * exercise, exactly as the reference tutorial has them: the exercise asks the
 * four questions, this section reports what they led to.
 *
 * "Retry Part 2 with different assumptions" is presentation, not a verdict: it
 * is offered whenever this screen is reached, because working another case does
 * not depend on R's `complete` flag. The completion card still appears only when
 * R reports completion.
 */

import type { Part2EvaluateResponse, Part2Recommendation } from '../../api/types'
import { formatEuro } from '../../format'
import { statusBadgeClass, statusCardClass } from './status'
import TutorialStatusCard from './TutorialStatusCard.vue'
import InfoTip from '../InfoTip.vue'

const props = defineProps<{
  recommendation: Part2Recommendation
  evaluation: Part2EvaluateResponse
  /**
   * R's own threshold and budget ceiling as numbers. R also publishes display
   * strings for them; these are formatted here with the app's currency formatter
   * so the two labels always read as plain money ("€100,000", "€3,000,000").
   */
  threshold: number
  ceiling: number
}>()

const emit = defineEmits<{ openFull: []; retry: [] }>()

/**
 * Where the outcome comes from, behind the task's information control. It is the
 * client's own presentation copy that used to sit under the heading, so the
 * section leads with the outcome itself.
 */
const recommendationIntro =
  "The commissioning outcome below is R's, read from the value-for-money, budget-impact and " +
  'readiness results you have reached. Change the negotiated price, the coverage cap or a ' +
  'readiness answer and it is recalculated with them.'

/**
 * The four criteria. Each verdict is R's: the first three are the booleans R
 * returned, and the fourth is R's own outcome — the coverage test holds exactly
 * when R chose the conditional-adoption outcome, so nothing is composed here.
 * Every verdict is still spelled out beside its colour, so none is carried by
 * colour alone.
 */
function checks() {
  const { evaluation, recommendation } = props
  return [
    {
      key: 'value',
      label: `Value for money at ${formatEuro(props.threshold)}/QALY`,
      passed: evaluation.price.passed,
    },
    {
      key: 'affordability',
      label: `Five-year budget impact within ${formatEuro(props.ceiling)}`,
      passed: evaluation.budget.affordable,
    },
    {
      key: 'deliverability',
      label: 'No DHT readiness domain is Red',
      passed: evaluation.readiness.deliverability.passed,
    },
    {
      key: 'coverage',
      label: 'Coverage maximised within the budget',
      passed: recommendation.status === 'conditional_adoption',
    },
  ]
}
</script>

<template>
  <section class="tutorial__step" aria-labelledby="part2-recommend-title">
    <h3 id="part2-recommend-title" class="tutorial__step-title" tabindex="-1">
      Recommendation
    </h3>
    <p class="part2__task">
      Bring the evidence together and recommend a funding position.
      <InfoTip :text="recommendationIntro" topic="this outcome" />
    </p>

    <article
      :class="recommendation.complete ? 'status-card status-card--good' : 'status-card status-card--warning'"
      data-part2-recommendation
      :data-part2-recommendation-status="recommendation.status"
    >
      <h4 class="status-card__title" data-part2-recommendation-headline>
        {{ recommendation.headline }}
      </h4>
      <p class="status-card__values" data-part2-recommendation-message>
        {{ recommendation.message }}
      </p>
    </article>

    <p class="part2__lever-line" data-part2-case-settings>
      {{ evaluation.budget.lever_sentence }}
    </p>

    <h4 class="tutorial__heading">Commissioning checklist</h4>
    <ul class="part2__checks" data-part2-checklist>
      <li v-for="check in checks()" :key="check.key" class="part2__check">
        <span>{{ check.label }}</span>
        <span :class="statusBadgeClass(check.passed ? 'Green' : 'Amber')">
          {{ check.passed ? 'Pass' : 'Not yet achieved' }}
        </span>
      </li>
    </ul>

    <h4 class="tutorial__heading">Readiness with the selected DHT settings</h4>
    <div class="status-cards" data-part2-readiness-cards>
      <TutorialStatusCard
        v-for="domain in evaluation.readiness.domains"
        :key="domain.domain"
        :title="domain.domain"
        :status="domain.status"
        measure-label=""
      />
    </div>
    <article
      :class="statusCardClass(evaluation.readiness.deliverability.passed ? 'Green' : 'Amber')"
      data-part2-deliverability
    >
      <h4 class="status-card__title">
        Deliverability
        <span class="badge">{{ evaluation.readiness.deliverability.label }}</span>
      </h4>
      <p class="status-card__text">
        The programme is deliverable when no readiness domain is Red. These statuses come
        from the readiness assessment at this case's own facts and your four answers.
      </p>
    </article>
    <p class="field__hint" data-part2-engagement-note>
      {{ evaluation.readiness.engagement_note }}
    </p>

    <!-- Shown only when R's outcome completes the case. -->
    <article
      v-if="recommendation.complete"
      class="part2__complete"
      data-part2-completion
    >
      <h4 class="status-card__title">{{ recommendation.headline }}</h4>
      <p class="status-card__values">{{ recommendation.message }}</p>
      <button type="button" class="btn btn--ghost" @click="emit('retry')">
        Retry Part 2 with different assumptions
      </button>
      <button type="button" class="btn btn--primary" @click="emit('openFull')">
        Open full analysis
      </button>
    </article>

    <!-- The same Retry action, for a case R does not report as complete. Reaching
         this screen is enough to work another case, so the action is always
         available: the completion card above carries it when R's outcome
         completes the case, and this row carries it otherwise. Nothing about
         R's outcome changes — the card's own actions are untouched. -->
    <div v-else class="tutorial__nav" data-part2-retry-row>
      <button type="button" class="btn btn--ghost" @click="emit('retry')">
        Retry Part 2 with different assumptions
      </button>
    </div>
  </section>
</template>
