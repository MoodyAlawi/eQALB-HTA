<script setup lang="ts">
/**
 * One quiet educational tip at the foot of an analysis panel.
 *
 * It is secondary by design: small muted type below the panel's results and actions,
 * never over a chart, and nothing in it runs, changes or waits for anything. A topic
 * with more than one tip offers a small control to show the next one; which tip is
 * shown first varies between visits so a returning learner sees something new.
 *
 * The panels place it outside their presentation overlay, so presentation mode never
 * shows it, and no export reads it.
 */

import { computed, ref } from 'vue'
import { TIPS, type TipTopic } from '../content/tips'

const props = defineProps<{ topic: TipTopic }>()

const tips = computed(() => TIPS[props.topic])
const index = ref(Math.floor(Math.random() * TIPS[props.topic].length))
const tip = computed(() => tips.value[index.value % tips.value.length])

function next(): void {
  index.value = (index.value + 1) % tips.value.length
}
</script>

<template>
  <aside class="tipline" aria-label="Tip">
    <span class="tipline__label" aria-hidden="true">Tip</span>
    <p class="tipline__text" aria-live="polite">{{ tip }}</p>
    <button
      v-if="tips.length > 1"
      type="button"
      class="tipline__next"
      title="Show another tip"
      aria-label="Show another tip"
      @click="next()"
    >
      <span aria-hidden="true">↻</span>
    </button>
  </aside>
</template>
