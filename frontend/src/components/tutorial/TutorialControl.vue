<script setup lang="ts">
/**
 * One tutorial control.
 *
 * The label, unit, valid range, step and explanation all arrive with R's
 * contract, so this component renders a control rather than defining one: there
 * is no default, bound or help text in it that R did not publish. The
 * explanation sits beside the label as a real disclosure button, matching the
 * assumption inputs, rather than inside the label where it would make the label
 * click open the explanation.
 *
 * A range input reports its value on every movement, which is what the reference
 * tutorial's sliders did; the session coalesces those reports into one request.
 */

import { computed } from 'vue'
import type { ControlDescriptor } from '../../api/types'
import { formatNumber } from '../../format'
import InfoTip from '../InfoTip.vue'

const props = defineProps<{
  control: ControlDescriptor
  value: number | boolean | undefined
}>()

const emit = defineEmits<{ 'update:value': [number | boolean] }>()

const inputId = computed(() => `tutorial-input-${props.control.id}`)

const numericValue = computed(() =>
  typeof props.value === 'number' ? props.value : Number(props.control.default),
)
const flagValue = computed(() => props.value === true)

/** Decimal places for the readout, from the control's own step. */
function decimalsFor(step: number | undefined): number {
  if (typeof step !== 'number' || !Number.isFinite(step) || step <= 0) return 0
  return step < 1 ? 2 : 0
}

const display = computed(() => formatNumber(numericValue.value, decimalsFor(props.control.step)))
const valueText = computed(() =>
  props.control.unit ? `${display.value} ${props.control.unit}` : display.value,
)

function onRange(event: Event): void {
  emit('update:value', Number((event.target as HTMLInputElement).value))
}

function onCheckbox(event: Event): void {
  emit('update:value', (event.target as HTMLInputElement).checked)
}
</script>

<template>
  <div class="field">
    <template v-if="control.type === 'checkbox'">
      <div class="field__control">
        <input
          :id="inputId"
          type="checkbox"
          :checked="flagValue"
          @change="onCheckbox"
        />
        <label :for="inputId">{{ control.label }}</label>
        <InfoTip :text="control.info" :topic="control.info_topic" />
      </div>
    </template>
    <template v-else>
      <label :for="inputId">{{ control.label }}</label>
      <InfoTip :text="control.info" :topic="control.info_topic" />
      <div class="field__control">
        <input
          :id="inputId"
          type="range"
          :min="control.min"
          :max="control.max"
          :step="control.step"
          :value="numericValue"
          :aria-valuetext="valueText"
          @input="onRange"
        />
        <output :for="inputId" class="field__value">{{ display }}</output>
        <span v-if="control.unit" class="field__unit">{{ control.unit }}</span>
      </div>
    </template>
  </div>
</template>
