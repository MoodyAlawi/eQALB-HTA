<script setup lang="ts">
/**
 * The stale-result notice every analysis tab shows.
 *
 * A result is a snapshot: it is replaced only by its own action button, so when
 * the inputs a tab would send have changed since the run, the tab says so
 * instead of quietly presenting a result that no longer matches the controls.
 * The wording is deliberately one pattern for all nine tabs; `detail` carries
 * the one tab-specific fact that does not generalise — the threshold a run was
 * made at, or the ranked outcome a table used — and it always reports a value R
 * returned rather than making a model statement.
 *
 * The sentence is assembled as a single string, so the space before the detail is
 * part of the text rather than template whitespace, which Vue condenses.
 *
 * A tab whose result goes out of date for a reason the shared sentence does not
 * describe — the HTA summary, which also goes out of date when an analysis it
 * reads is run again — passes its own `message`, which replaces the sentence
 * whole. Without it the notice is exactly the shared pattern above.
 */

import { computed } from 'vue'

const props = defineProps<{
  /** The action button that replaces the stored result, exactly as labelled. */
  action: string
  /** One short sentence naming what the stored result was made with. */
  detail?: string
  /** The complete notice, for a tab the shared sentence does not fit. */
  message?: string
}>()

const text = computed(() =>
  props.message
    ? props.message
    : `This result was computed from earlier inputs. It is not recalculated automatically: ` +
      `use “${props.action}” to replace it with the current values.` +
      (props.detail ? ` ${props.detail}` : ''),
)
</script>

<template>
  <p class="alert alert--warning">{{ text }}</p>
</template>
