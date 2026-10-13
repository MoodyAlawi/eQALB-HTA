<script setup lang="ts" generic="T">
/**
 * Presentational table. All formatting is done by the caller through the
 * `value` accessor, so this component never interprets a model number.
 *
 * The table carries an accessible name: `label` when the caller has one that is
 * not rendered visibly (a table inside a <details>, for example), otherwise the
 * `caption` that is already shown above it. The name is set with `aria-label`
 * rather than a <caption>, so nothing moves on screen and the existing
 * responsive wrapper is untouched.
 */

import { computed } from 'vue'
import type { Column } from './table'

const props = defineProps<{
  columns: Column<T>[]
  rows: T[]
  /** Optional caption rendered above the table. */
  caption?: string
  /** Optional accessible name when there is no visible caption. */
  label?: string
}>()

const tableLabel = computed(() => props.label ?? props.caption)
</script>

<template>
  <figure class="table-figure">
    <figcaption v-if="caption" class="table-figure__caption">{{ caption }}</figcaption>
    <div class="table-scroll">
      <table class="table" :aria-label="tableLabel ?? undefined">
        <thead>
          <tr>
            <th
              v-for="column in columns"
              :key="column.key"
              :class="column.align === 'right' ? 'is-right' : undefined"
              scope="col"
            >
              {{ column.label }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(row, index) in rows" :key="index">
            <td
              v-for="column in columns"
              :key="column.key"
              :class="[
                column.align === 'right' ? 'is-right' : undefined,
                column.tone?.(row) ? `tone-${column.tone(row)}` : undefined,
              ]"
              :title="column.title?.(row)"
            >
              {{ column.value(row) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </figure>
</template>
