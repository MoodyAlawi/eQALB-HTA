<script setup lang="ts">
/**
 * Part 2, section 2: the value-for-money exercise.
 *
 * One control — the negotiated annual price — and R's answer to it. The task
 * statement, the lever hint, the three state messages, the nudge, the highest
 * acceptable price, the current-price detail and the whole curve (with R's
 * pass/fail classification, colours, threshold line and marker) come from R. This
 * component never decides whether a price passes, where the crossing is, where the
 * marker sits or which series a point belongs to.
 *
 * The slider reports as it moves and the session coalesces the reports, so the
 * lever feels immediate while each evaluation stays one model run: the case's
 * curve is posted back for R to re-classify.
 */

import { computed } from 'vue'
import type { Part2Contract, Part2EvaluateResponse } from '../../api/types'
import { formatEuro } from '../../format'
import InfoTip from '../InfoTip.vue'
import Part2PriceCurve from './Part2PriceCurve.vue'

const props = defineProps<{
  contract: Part2Contract
  evaluation: Part2EvaluateResponse
  price: number
  busy: boolean
}>()

const emit = defineEmits<{ 'update:price': [number]; back: [] }>()

const control = computed(() => props.contract.price_control)

/** R's state for the current price decides the card's tone. */
const toneClass = computed(() => {
  if (props.evaluation.price.at_max) return 'status-card status-card--good'
  return 'status-card status-card--warning'
})

const decimals = computed(() => (control.value.step < 1 ? 2 : 0))

/**
 * The lever's explanation and this case's own lever hint, in the one popover the
 * control already carries. Both are R's text; merging them is presentation only
 * and keeps the second explanation out of the visible column.
 */
const leverInfo = computed(() => `${control.value.info} ${props.evaluation.strings.lever_hint}`)
</script>

<template>
  <section class="tutorial__step" aria-labelledby="part2-value-title">
    <h3 id="part2-value-title" class="tutorial__step-title" tabindex="-1">
      {{ contract.value.heading }}
    </h3>
    <p class="part2__task">
      {{ evaluation.strings.task }}
      <InfoTip :text="evaluation.strings.note" topic="this test" />
    </p>

    <div class="controls controls--stacked tutorial__controls">
      <div class="field">
        <label for="part2-price">{{ control.label }}</label>
        <InfoTip :text="leverInfo" :topic="control.info_topic" />
        <div class="field__control">
          <input
            id="part2-price"
            type="range"
            :min="control.min"
            :max="control.max"
            :step="control.step"
            :value="price"
            :aria-valuetext="`${formatEuro(price, decimals)} ${control.unit}`"
            @input="emit('update:price', Number(($event.target as HTMLInputElement).value))"
          />
          <output for="part2-price" class="field__value">{{ formatEuro(price, decimals) }}</output>
          <span class="field__unit">{{ control.unit }}</span>
        </div>
      </div>
    </div>

    <h4 class="tutorial__heading">{{ contract.value.result_heading }}</h4>

    <article :class="toneClass" :data-part2-price-state="evaluation.price.state">
      <h4 class="status-card__title">
        {{ evaluation.price.state_message }}
        <span class="badge">{{ evaluation.price.price_display }}</span>
      </h4>
      <p class="status-card__values">{{ evaluation.price.detail }}</p>
      <p v-if="evaluation.price.state_hint" class="field__hint">
        {{ evaluation.price.state_hint }}
      </p>
    </article>

    <p class="tutorial__live muted" aria-live="polite">
      {{ busy ? 'Updating the value-for-money result…' : 'Result updated.' }}
    </p>

    <Part2PriceCurve
      :curve="evaluation.curve"
      :chart="evaluation.chart"
      :marker="evaluation.marker"
      :note="evaluation.strings.method_note"
    />
  </section>
</template>
