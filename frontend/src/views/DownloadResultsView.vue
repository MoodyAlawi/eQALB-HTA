<script setup lang="ts">
/**
 * Download results subview.
 *
 * It mirrors the Shiny export: one ZIP containing the results that already exist
 * in this session, with everything that has not been run listed rather than
 * guessed at. The package is assembled in the browser from the API responses the
 * tabs are showing, so no analysis is rerun and nothing new is computed.
 *
 * The one thing the browser cannot produce is the rendered chart images the
 * Shiny package carries; the precise remaining backend work is stated on the
 * page instead of being quietly dropped.
 */

import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useAppView } from '../composables/useAppView'
import { buildZip, downloadBytes } from '../export/zip'
import {
  analysisAvailability,
  backendGap,
  buildResultsPackage,
  packageFilename,
} from '../export/resultsPackage'

const { goHome } = useAppView()
const heading = ref<HTMLHeadingElement | null>(null)
/**
 * The page's own report of the last export. It is a polite live region, so the
 * outcome is announced once, and it is the only place this page reports a
 * download — the app-wide notice is not used here, so no action is reported twice.
 */
const status = ref<{ tone: 'ok' | 'error'; text: string } | null>(null)

// Read straight off the store, so the list always matches what the tabs show.
const availability = computed(() => analysisAvailability())
const included = computed(() => availability.value.filter((entry) => entry.included))
const pending = computed(() => availability.value.filter((entry) => !entry.included))

function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape') goHome()
}

onMounted(() => {
  heading.value?.focus()
  window.addEventListener('keydown', onKeydown)
})
onUnmounted(() => window.removeEventListener('keydown', onKeydown))

function download(): void {
  const now = new Date()
  // Preparation is what this page can report on: it builds the package and hands
  // it to the browser. Whether the browser saved it is not something the interface
  // is told, so the wording below says exactly what happened. A package that could
  // not be built says so and never reports a download.
  try {
    const results = buildResultsPackage(now)
    const archive = buildZip(
      results.files.map((file) => ({ name: file.name, text: file.text })),
      now,
    )
    const filename = packageFilename(now)
    downloadBytes(archive, filename, 'application/zip')
    status.value = {
      tone: 'ok',
      text: `Results package prepared: ${filename}, with ${results.files.length} file${
        results.files.length === 1 ? '' : 's'
      }.`,
    }
  } catch (error) {
    status.value = {
      tone: 'error',
      text: `The results package could not be prepared in this browser: ${
        error instanceof Error ? error.message : String(error)
      }`,
    }
  }
}

const gap = backendGap()
</script>

<template>
  <section class="page" aria-labelledby="export-title">
    <div class="page__inner">
      <h1 id="export-title" ref="heading" class="page__title" tabindex="-1">Download results</h1>

      <p class="page__prose">
        Downloads a ZIP package containing the results currently available in this session.
        Analyses that have not been run are listed in the package README rather than estimated.
      </p>

      <h2 class="page__subtitle">Available now</h2>
      <ul class="list page__list">
        <li v-for="entry in included" :key="entry.label">
          <span class="badge badge--good">included</span>
          {{ entry.label }}
        </li>
        <li v-if="included.length === 0" class="muted">
          Nothing has been run yet, so the package would contain only the README that lists what is
          missing.
        </li>
      </ul>

      <h2 class="page__subtitle">Not yet run</h2>
      <ul class="list page__list">
        <li v-for="entry in pending" :key="entry.label">
          <span class="badge">not included</span>
          {{ entry.label }} — {{ entry.hint }}.
        </li>
        <li v-if="pending.length === 0" class="muted">
          Every analysis is available and will be included.
        </li>
      </ul>

      <div class="page__actions">
        <button type="button" class="btn btn--primary" @click="download()">
          Download results package
        </button>
        <button type="button" class="btn btn--ghost" @click="goHome()">Back</button>
      </div>

      <p
        v-if="status"
        class="alert"
        :class="status.tone === 'error' ? 'alert--danger' : 'alert--info'"
        :role="status.tone === 'error' ? 'alert' : 'status'"
      >
        {{ status.text }}
      </p>

      <details class="details">
        <summary>What the package contains, and what it does not</summary>
        <p class="muted">
          The package contains the numeric tables and text summaries the analyses produced
          (model assumptions, cost-effectiveness summary, PSA summary and probabilities,
          sensitivity-analysis table, budget-impact table, survival summary, value of information
          with its EVPPI table, readiness results, the HTA decision summary with its
          evidence-priority table, and the value-based price with its 3 × 3 scan), plus a README
          that repeats
          this list and the simulated-data disclaimer.
        </p>
        <p class="muted">{{ gap }}</p>
      </details>
    </div>
  </section>
</template>
