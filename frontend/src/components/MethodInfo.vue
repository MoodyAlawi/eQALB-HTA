<script setup lang="ts">
/**
 * The "How this is calculated" control and the method panel behind it.
 *
 * It sits beside a module's own section title, as a small muted button — not the
 * cyan accent the app uses for navigation and primary actions, so a reader never
 * mistakes the method note for the way forward, and not the accent outline the
 * interactive-lesson control uses ("Explain this"), so the documentation and the
 * lesson stay visibly different actions.
 *
 * The panel opens **in place**, under the section title, in the module's own
 * column: it is reading material about the thing on screen, so it belongs beside
 * it rather than in an overlay that covers it. Nothing is fetched — the text is
 * R's and arrived with the contract — so opening it runs nothing, changes no
 * input, and leaves every result as it was. The state is local to this control:
 * one panel per module, closed until asked for.
 *
 * The panel's blocks are the mathematics, in a stable order so a reader who has seen
 * one note can find the same thing in the next: the lead sentence, the formula, the
 * steps, what the symbols mean, how to read the result, the assumptions that matter
 * and — where it adds something the steps do not — a compact breakdown. R's note only
 * carries the blocks that add information, so a module with no equation, no symbols
 * or no breakdown shows none of them rather than an empty heading, and nothing is
 * repeated from one block in another.
 *
 * The trigger is beside the title rather than inside the heading, so the heading
 * keeps its own reading order and the button keeps a real accessible name of its
 * own. The panel is a labelled region and the button reports its state, so
 * assistive technology follows the disclosure without a focus trap.
 */

import { computed, ref, useId } from 'vue'
import { useMethodNote } from '../composables/useMethodNotes'
import MathText from './MathText.vue'

const props = defineProps<{
  /** The module id R keys the note by, e.g. `base_case` or `survival`. */
  module: string
}>()

const note = useMethodNote(() => props.module)
const open = ref(false)
const panelId = `method-${useId()}`

/**
 * One list from R.
 *
 * The JSON serialiser writes a one-element vector as a bare string rather than an
 * array, so a note whose only assumption — or only step, or only symbol — happened to
 * be one item would otherwise render its characters instead of its contents. Reading
 * every list through here keeps the template showing a note's text whatever its
 * length, and costs nothing when the payload is already a list.
 */
function listOf(value: string[] | string | undefined): string[] {
  if (Array.isArray(value)) return value
  return typeof value === 'string' && value.length > 0 ? [value] : []
}

/** The same, for a note's `{symbol, meaning}` and `{label, value}` rows. */
function rowsOf<T>(value: T[] | T | undefined): T[] {
  if (Array.isArray(value)) return value
  return value ? [value] : []
}

/** R's note, with every optional block resolved to a value the template can read. */
const view = computed(() => {
  const entry = note.value
  if (!entry) return null
  return {
    ...entry,
    summary: entry.summary ?? '',
    steps: listOf(entry.steps),
    definitions: rowsOf(entry.definitions),
    assumptions: listOf(entry.assumptions),
    table: rowsOf(entry.table),
  }
})

/** R's own label for the control, or the calculator's wording as a fallback. */
const label = computed(() => view.value?.label ?? 'How this is calculated')

const hasContent = computed(() => {
  const entry = view.value
  if (!entry) return false
  return (
    entry.summary.trim().length > 0 ||
    entry.steps.length > 0 ||
    entry.definitions.length > 0 ||
    entry.assumptions.length > 0
  )
})

function toggle(): void {
  open.value = !open.value
}
</script>

<template>
  <span v-if="view && hasContent" class="methodinfo">
    <button
      type="button"
      class="methodinfo__trigger"
      :class="{ 'is-open': open }"
      :aria-expanded="open"
      :aria-controls="panelId"
      @click.stop="toggle()"
    >
      {{ label }}
    </button>

    <section
      v-if="open"
      :id="panelId"
      class="methodinfo__panel"
      :aria-label="label"
    >
      <p class="methodinfo__summary"><MathText :text="view.summary" /></p>

      <div v-if="view.formula" class="methodinfo__block">
        <p class="methodinfo__heading">The relation</p>
        <div class="methodinfo__formula"><MathText :text="view.formula" display /></div>
      </div>

      <div v-if="view.steps.length > 0" class="methodinfo__block">
        <p class="methodinfo__heading">How it is computed</p>
        <ol class="methodinfo__list">
          <li v-for="(line, index) in view.steps" :key="index"><MathText :text="line" /></li>
        </ol>
      </div>

      <div v-if="view.definitions.length > 0" class="methodinfo__block">
        <p class="methodinfo__heading">
          {{ view.definitions_title ?? 'What the symbols mean' }}
        </p>
        <dl class="methodinfo__rows methodinfo__symbols">
          <template v-for="row in view.definitions" :key="row.symbol">
            <dt><MathText :text="row.symbol" /></dt>
            <dd><MathText :text="row.meaning" /></dd>
          </template>
        </dl>
      </div>

      <div v-if="view.interpretation" class="methodinfo__block">
        <p class="methodinfo__heading">Reading the result</p>
        <p class="methodinfo__prose"><MathText :text="view.interpretation" /></p>
      </div>

      <div v-if="view.assumptions.length > 0" class="methodinfo__block">
        <p class="methodinfo__heading">Assumptions that change how it reads</p>
        <ul class="methodinfo__list">
          <li v-for="(line, index) in view.assumptions" :key="index"><MathText :text="line" /></li>
        </ul>
      </div>

      <div v-if="view.table_title && view.table.length > 0" class="methodinfo__block">
        <p class="methodinfo__heading">{{ view.table_title }}</p>
        <dl class="methodinfo__rows">
          <template v-for="row in view.table" :key="row.label">
            <dt><MathText :text="row.label" /></dt>
            <dd><MathText :text="row.value" /></dd>
          </template>
        </dl>
      </div>
    </section>
  </span>
</template>
