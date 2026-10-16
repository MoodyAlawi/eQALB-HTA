<script setup lang="ts">
/**
 * The run's settings, as rows in a presentation overlay: one label with its value
 * and unit, the figures right-aligned so a column of them lines up.
 *
 * The rows are built by the panel that opened the overlay — from the response the
 * run returned, or from the settings the app actually sent when it is still the
 * run's own — and nothing here derives a value.
 */

export interface PresentationSetting {
  /** Stable key for the list. */
  id: string
  label: string
  value: string
  unit: string
}

defineProps<{
  rows: PresentationSetting[]
  /** A sentence shown under the rows, e.g. a metadata limitation. */
  note?: string
}>()
</script>

<template>
  <div class="present__assumptions">
    <p v-for="row in rows" :key="row.id" class="present__assumption">
      <span class="present__assumption-label">{{ row.label }}</span>
      <span class="present__assumption-value">{{ row.value }}</span>
      <span class="present__assumption-unit">{{ row.unit }}</span>
    </p>
    <p v-if="note" class="present__setting-note">{{ note }}</p>
  </div>
</template>
