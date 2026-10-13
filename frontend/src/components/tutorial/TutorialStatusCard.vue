<script setup lang="ts">
/**
 * One tutorial status card: a domain, the status R assessed for it, R's
 * "current values" line and R's interpretation of that status.
 *
 * Nothing is derived here — the status word, the values line and the sentence
 * are all R's — and the status is always written out beside its colour.
 */

import type { TutorialStatus } from '../../api/types'
import { statusBadgeClass, statusCardClass } from './status'

defineProps<{
  title: string
  status: TutorialStatus
  /** R's label for the values line, e.g. "Current values: ". */
  measureLabel: string
  measure?: string
  text?: string
}>()
</script>

<template>
  <article :class="statusCardClass(status)">
    <h4 class="status-card__title">
      {{ title }}
      <span :class="statusBadgeClass(status)">{{ status }}</span>
    </h4>
    <p v-if="measure" class="status-card__values">
      <strong>{{ measureLabel }}</strong>{{ measure }}
    </p>
    <p v-if="text" class="status-card__text">{{ text }}</p>
  </article>
</template>
