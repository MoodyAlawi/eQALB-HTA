<script setup lang="ts">
/**
 * Global assumptions: the 16 model inputs plus the reference willingness-to-pay
 * threshold. Values, ranges and steps all come from /api/defaults, which reads
 * them from eqalb_markov.R, so the form cannot drift from the R base case.
 *
 * Percentages are stored as fractions in the model but shown as percentages
 * here; that conversion is the only arithmetic in this component.
 */

import { computed, ref } from 'vue'
import type { ParameterSpec } from '../api/types'
import { formatEuro } from '../format'
import { useModel } from '../composables/useModel'
import InfoTip from './InfoTip.vue'

const model = useModel()

/** The explanation /api/defaults carries for one model parameter, or "". */
function specInfo(spec: ParameterSpec): string {
  return spec.info ?? ''
}

/**
 * The two explanations that belong to controls rather than to a model parameter
 * row: the global threshold field and the readiness clinician-review input. Both
 * come from the same dictionary, keyed as the Shiny labels are.
 */
const referenceWtpInfo = computed(() => model.defaults?.info_text?.reference_wtp ?? '')

/**
 * Explanations for the three assumption groups R publishes no wording for:
 * CC_INFO_TEXT defines individual parameters, not group headings. Like the
 * readiness tab's algorithm-governance button, these sentences are written for
 * the interface and describe what each group is and why it matters; they state
 * no value, range or model rule.
 */
const GROUP_INFO: Record<string, string> = {
  'Event costs':
    'Event costs are the costs associated with clinical events, such as hospitalisation, treatment, or follow-up care. They affect the total cost of each strategy.',
  Discounting:
    'Discounting reduces the value placed on costs and outcomes that occur in the future, reflecting that value today is generally considered more important than value later.',
  'Time horizon':
    'The time horizon is how far into the future the model follows patients. A longer horizon captures more long-term costs and outcomes.',
}

/** The group heading's explanation, or "" for a group R's dictionary covers. */
function groupInfo(heading: string): string {
  return GROUP_INFO[heading] ?? ''
}

/** Ids of fields whose typed value had to be pulled back into the allowed range. */
const clamped = ref<Set<string>>(new Set())

function displayValue(spec: ParameterSpec): string {
  const current = model.inputs[spec.id as keyof typeof model.inputs]
  const resolved = typeof current === 'number' && Number.isFinite(current) ? current : spec.default
  const shown = spec.percent ? resolved * 100 : resolved
  // Trim float noise (0.30000000000000004 -> 0.3) without changing the value.
  return String(Number(shown.toFixed(6)))
}

function scale(spec: ParameterSpec, value: number): number {
  return Number((spec.percent ? value * 100 : value).toFixed(6))
}

/** Compact suffix for the input; the full unit text stays in the tooltip. */
function unitBadge(spec: ParameterSpec): string {
  if (spec.percent) return '%'
  if (spec.unit.startsWith('EUR')) return '€'
  if (spec.unit === 'years') return 'years'
  if (spec.unit.startsWith('utility')) return '0-1'
  return ''
}

function isClamped(id: string): boolean {
  return clamped.value.has(id)
}

function syncField(spec: ParameterSpec, event: Event): void {
  ;(event.target as HTMLInputElement).value = displayValue(spec)
}

function commit(spec: ParameterSpec, event: Event): void {
  const element = event.target as HTMLInputElement
  const parsed = Number.parseFloat(element.value)
  if (!Number.isFinite(parsed)) {
    syncField(spec, event)
    return
  }

  const modelValue = spec.percent ? parsed / 100 : parsed
  const bounded = Math.min(Math.max(modelValue, spec.min), spec.max)
  const next = new Set(clamped.value)
  if (Math.abs(bounded - modelValue) > 1e-12) next.add(spec.id)
  else next.delete(spec.id)
  clamped.value = next

  model.setInput(spec.id, bounded)
  syncField(spec, event)
}

/** A string-backed model so an emptied field cannot write NaN into the request. */
const wtpInput = computed({
  get: () => String(model.wtp),
  set: (raw: string) => {
    const parsed = Number.parseFloat(raw)
    if (!Number.isFinite(parsed) || parsed < 0) return
    model.wtp = Math.min(parsed, 10_000_000)
  },
})

const changedCount = computed(() => model.changedParameters.length)
const wtpChanged = computed(() => Math.abs(model.wtp - model.referenceWtp) > 1e-9)

/** Inline confirmation for the separate destructive action. */
const confirmingClear = ref(false)

function clearAllResults(): void {
  model.clearResults()
  confirmingClear.value = false
}
</script>

<template>
  <section class="assumptions" aria-label="Model assumptions">
    <header class="assumptions__header">
      <div>
        <h2>Assumptions</h2>
        <p class="muted">
          Base case from the model's reference assumptions.
          <span v-if="changedCount > 0" class="badge badge--warning">{{ changedCount }} changed</span>
        </p>
      </div>
      <button
        type="button"
        class="btn btn--ghost"
        :disabled="!model.modelInputsChanged"
        title="Restore the 16 model assumptions and the reference WTP threshold to the R base case. Analysis settings — PSA, Kaplan-Meier, budget impact, readiness and the target population — and every completed result are kept."
        @click="model.resetModelInputs()"
      >
        Reset model inputs
      </button>
    </header>

    <p class="hint">
      Reset restores the 16 model assumptions and the threshold only; every completed result is
      kept.
    </p>

    <div class="field field--threshold">
      <label for="wtp-input">Reference WTP threshold</label>
      <InfoTip :text="referenceWtpInfo" topic="the reference WTP threshold" />
      <div class="field__control">
        <input
          id="wtp-input"
          v-model="wtpInput"
          type="number"
          min="0"
          step="5000"
          inputmode="decimal"
        />
        <span class="field__unit">€/QALY</span>
        <button
          v-if="wtpChanged"
          type="button"
          class="btn btn--ghost btn--tiny"
          title="Back to the model's reference threshold"
          @click="model.wtp = model.referenceWtp"
        >
          ↺
        </button>
      </div>
      <p class="field__hint">
        Drives net monetary benefit, the probability of cost-effectiveness and the decision labels.
        Model reference: {{ formatEuro(model.referenceWtp) }}/QALY.
      </p>
    </div>

    <details v-for="group in model.parameterGroups" :key="group.group" class="group" open>
      <summary>
        {{ group.group }}
        <InfoTip v-if="groupInfo(group.group)" :text="groupInfo(group.group)" :topic="group.group" />
      </summary>
      <div
        v-for="spec in group.parameters"
        :key="spec.id"
        class="field"
        :class="{ 'field--clamped': isClamped(spec.id) }"
      >
        <label :for="`input-${spec.id}`" :title="spec.unit">{{ spec.label }}</label>
        <InfoTip :text="specInfo(spec)" :topic="spec.label" />
        <div class="field__control">
          <input
            :id="`input-${spec.id}`"
            type="number"
            :value="displayValue(spec)"
            :min="scale(spec, spec.min)"
            :max="scale(spec, spec.max)"
            :step="scale(spec, spec.step)"
            inputmode="decimal"
            :title="
              isClamped(spec.id)
                ? `Adjusted to the allowed range ${scale(spec, spec.min)}-${scale(spec, spec.max)} ${unitBadge(spec)}`
                : spec.unit
            "
            @change="commit(spec, $event)"
            @blur="commit(spec, $event)"
          />
          <span v-if="unitBadge(spec)" class="field__unit">{{ unitBadge(spec) }}</span>
        </div>
        <p v-if="isClamped(spec.id)" class="field__hint field__hint--warning">
          Adjusted to {{ scale(spec, spec.min) }}–{{ scale(spec, spec.max) }} {{ unitBadge(spec) }}.
        </p>
      </div>
    </details>

    <div class="assumptions__danger">
      <button
        type="button"
        class="btn btn--ghost btn--danger"
        :disabled="model.resultCount === 0"
        :title="
          model.resultCount === 0
            ? 'No results are stored in this session'
            : 'Remove every stored result without changing any input'
        "
        @click="confirmingClear = true"
      >
        Clear all results
      </button>
      <p class="muted">
        {{ model.resultCount }} of {{ model.analysisCount }} analyses stored.
      </p>

      <div
        v-if="confirmingClear"
        class="alert alert--warning"
        role="alertdialog"
        aria-label="Confirm clearing all results"
      >
        <p>
          This removes every stored result in this session — base case, PSA, sensitivity analysis,
          budget impact, survival, value of information, readiness and the HTA decision summary. No
          input is changed, and you can run any analysis again at any time.
        </p>
        <div class="controls">
          <button type="button" class="btn btn--primary" @click="clearAllResults()">
            Yes, clear all results
          </button>
          <button type="button" class="btn btn--ghost" @click="confirmingClear = false">
            Cancel
          </button>
        </div>
      </div>
    </div>
  </section>
</template>
