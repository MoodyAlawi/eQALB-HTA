<script setup lang="ts">
/**
 * The tutorial's four-step progress control.
 *
 * It is a plain ordered list of buttons, so every step is reachable with Tab and
 * activates with Enter or Space without a key handler of its own, and the step
 * the learner is on carries `aria-current="step"`. The visible progress line is
 * R's own sentence (the contract's template with its numbers filled in), so the
 * wording is not written here.
 */

import type { TutorialStepCopy } from '../../api/types'

defineProps<{
  steps: TutorialStepCopy[]
  current: number
  completed: boolean
  progressText: string
}>()

defineEmits<{ select: [number] }>()
</script>

<template>
  <nav class="stepper" aria-label="Tutorial steps">
    <p class="stepper__progress" aria-live="polite">{{ progressText }}</p>
    <ol class="stepper__list">
      <li v-for="step in steps" :key="step.id" class="stepper__item">
        <button
          type="button"
          class="stepper__button"
          :class="{
            'is-active': !completed && Number(step.id) === current,
            'is-done': completed || Number(step.id) < current,
          }"
          :aria-current="!completed && Number(step.id) === current ? 'step' : undefined"
          @click="$emit('select', Number(step.id))"
        >
          <span class="stepper__index" aria-hidden="true">{{ step.id }}</span>
          <span class="stepper__label">{{ step.progress }}</span>
        </button>
      </li>
    </ol>
  </nav>
</template>
