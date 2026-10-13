<script setup lang="ts">
/**
 * Step 4: tutorial decision summary.
 *
 * R owns the four domain rows (status, current values and interpretation), the
 * overall status and its heading, the plain-language interpretation, the
 * simplified traffic-light rules the step explains and the evidence-generation
 * priorities. This component only lays them out, and the overall status keeps a
 * neutral treatment when R reports no status rather than one it did not assess.
 *
 * The rules and the priorities are on-demand disclosures, so the summary itself
 * stays the thing on screen.
 */

import type { TutorialContract, TutorialPart1Response, TutorialStepCopy } from '../../api/types'
import { statusBadgeClass, statusCardClass } from './status'
import TutorialStatusCard from './TutorialStatusCard.vue'

defineProps<{
  copy: TutorialStepCopy
  contract: TutorialContract
  result: TutorialPart1Response
}>()

const emit = defineEmits<{ finish: [] }>()
</script>

<template>
  <section class="tutorial__step" aria-labelledby="tutorial-step-title">
    <h3 id="tutorial-step-title" class="tutorial__step-title" tabindex="-1">{{ copy.title }}</h3>
    <p class="tutorial__intro">{{ copy.intro }}</p>
    <ul v-if="copy.explain.length" class="list tutorial__explain">
      <li v-for="line in copy.explain" :key="line">{{ line }}</li>
    </ul>

    <details class="details">
      <summary>{{ contract.rules.title }}</summary>
      <ul class="list">
        <li v-for="item in contract.rules.items" :key="item">{{ item }}</li>
      </ul>
    </details>

    <h4 class="tutorial__heading">{{ copy.summary_heading }}</h4>
    <article :class="statusCardClass(result.summary.overall_status)">
      <h4 class="status-card__title">
        {{ result.summary.overall_title }}
        <span :class="statusBadgeClass(result.summary.overall_status)">
          {{ result.summary.overall_status }}
        </span>
      </h4>
      <p class="status-card__text">{{ contract.labels.overall_note }}</p>
    </article>

    <div class="tutorial__domains">
      <TutorialStatusCard
        v-for="row in result.summary.rows"
        :key="row.domain"
        :title="row.domain"
        :status="row.status"
        :measure-label="contract.table_headings.current_values"
        :measure="row.measure"
        :text="row.interpretation"
      />
    </div>

    <h4 class="tutorial__heading">{{ copy.interpretation_heading }}</h4>
    <p class="alert alert--info">{{ result.summary.interpretation }}</p>

    <details class="details">
      <summary>{{ copy.evidence_heading }}</summary>
      <ul class="list">
        <li v-for="item in contract.evidence.items" :key="item">{{ item }}</li>
      </ul>
    </details>

    <div class="tutorial__nav">
      <button type="button" class="btn btn--primary" @click="emit('finish')">
        {{ copy.finish_label }}
      </button>
    </div>
  </section>
</template>
