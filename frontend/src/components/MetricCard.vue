<script setup lang="ts">
/**
 * One headline figure with an optional plain-language caption.
 *
 * The `hint` is an explanation from the API (CC_INFO_TEXT), shown through the
 * same accessible InfoTip control the input labels use, so it is reachable by
 * keyboard and screen reader rather than only by hovering a title attribute.
 */

import type { Tone } from '../format'
import InfoTip from './InfoTip.vue'

withDefaults(
  defineProps<{
    label: string
    value: string
    sub?: string
    tone?: Tone | null
    hint?: string
  }>(),
  { sub: undefined, tone: null, hint: undefined },
)
</script>

<template>
  <div class="metric" :class="tone ? `metric--${tone}` : undefined">
    <p class="metric__label">
      {{ label }}
      <InfoTip :text="hint" :topic="label" />
    </p>
    <p class="metric__value">{{ value }}</p>
    <p v-if="sub" class="metric__sub">{{ sub }}</p>
  </div>
</template>
