<script setup lang="ts">
/**
 * Chapter 7's figure: the seven readiness areas and how they fall.
 *
 * The figure draws only what the assessment returned. Each chip carries an area's
 * name and R's status word for it, so a status is never carried by colour alone, and
 * the chip the current answer changed is brought forward with the accent while the
 * others stay fully legible: nothing is blurred, dimmed or hidden, because a learner
 * comparing two areas needs to read both.
 *
 * The count bar under the chips is a summary of the seven judgements, not a score.
 * It shows R's own counts as three segments and labels each with the number of areas
 * in it, so it cannot be mistaken for a total, a percentage or a rating.
 *
 * The four questions are not drawn here. Their answers are the chapter's own control,
 * rendered in the panel below the chart, so the figure keeps to what R judged and the
 * choices stay where the learner is already reading.
 */

import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type {
  JourneyFocus,
  JourneyReadinessGraph,
  JourneyReadinessResult,
} from '../../api/types'
import JourneySpotlight from './JourneySpotlight.vue'
const props = defineProps<{
  graph: JourneyReadinessGraph
  /** R's assessment for the answers on screen, or null before it arrives. */
  result: JourneyReadinessResult | null
  /** Whether the figure has reached the chips or is still on its opening state. */
  reveal: 'intro' | 'chips'
  /** Which area, or the counts, this state brings forward. */
  focus: JourneyFocus
  /** Whether the guidance softens everything outside the focused region. */
  dim: boolean
  /** Which chapter's picture these coordinates describe. */
  scope?: string | null
}>()

interface Box {
  left: number
  top: number
  width: number
  height: number
}

const rootEl = ref<HTMLElement | null>(null)
const chipEls = ref<Record<string, HTMLElement | null>>({})
const countsEl = ref<HTMLElement | null>(null)
const rootBox = ref({ width: 0, height: 0 })

const domains = computed(() => props.result?.domains ?? [])
const counts = computed(() => props.result?.counts ?? null)
const showChips = computed(() => props.reveal === 'chips' && domains.value.length > 0)

/** The area the answer on screen changed, if any. */
const changedDomain = computed(() => props.result?.changed?.domain ?? null)

function setChipRef(domain: string, element: Element | null): void {
  chipEls.value[domain] = element instanceof HTMLElement ? element : null
}

function measure(): void {
  const root = rootEl.value
  if (!root) return
  rootBox.value = { width: root.clientWidth, height: root.clientHeight }
}

let observer: ResizeObserver | null = null

onMounted(() => {
  measure()
  observer = new ResizeObserver(measure)
  if (rootEl.value) observer.observe(rootEl.value)
  window.addEventListener('resize', measure, { passive: true })
})

onBeforeUnmount(() => {
  observer?.disconnect()
  observer = null
  window.removeEventListener('resize', measure)
})

/**
 * Re-measure once the DOM for this state has been laid out. A state can change the
 * figure's height — the chips appear, the answer's own sentence is another line — and
 * the browser reports the new size only after it has laid the update out. `flush:
 * 'post'` plus `nextTick` is that moment, not a delay.
 */
watch(
  () => [props.reveal, props.focus, props.scope, props.dim, props.result],
  () => {
    void nextTick(measure)
  },
  { flush: 'post' },
)

/** A box around one element, in the figure's own coordinates, with its own padding. */
function boxOf(element: HTMLElement | null, pad = 5): Box | null {
  const root = rootEl.value
  if (!element || !root) return null
  const own = element.getBoundingClientRect()
  const base = root.getBoundingClientRect()
  return {
    left: Math.max(0, own.left - base.left - pad),
    top: Math.max(0, own.top - base.top - pad),
    width: own.width + pad * 2,
    height: own.height + pad * 2,
  }
}

/**
 * The region a state brings forward.
 *
 * A question state marks that question's chip, and the summary state marks the counts.
 * Both are self-contained: the chip holds its own name and status word, and the counts
 * block holds its own title and labels, so a ring drawn inside either can never cross
 * a label that belongs to something else.
 */
const hole = computed<Box | null>(() => {
  if (!props.dim || props.focus === 'none') return null
  if (props.focus === 'ready_counts') {
    const box = boxOf(countsEl.value, 6)
    return box && box.width > 4 ? box : null
  }
  const domain =
    props.focus === 'ready_interop'
      ? 'Interoperability'
      : props.focus === 'ready_governance'
        ? 'Algorithm governance'
        : props.focus === 'ready_workflow'
          ? 'Workflow burden'
          : props.focus === 'ready_language'
            ? 'Language access'
            : props.focus === 'ready_chips'
              ? changedDomain.value
              : null
  if (!domain) return null
  const box = boxOf(chipEls.value[domain] ?? null)
  return box && box.width > 4 ? box : null
})

function statusClass(status: string): string {
  if (status === 'Green') return 'readyfig__chip--green'
  if (status === 'Amber') return 'readyfig__chip--amber'
  return 'readyfig__chip--red'
}
</script>

<template>
  <div ref="rootEl" class="chart readyfig">
    <!-- The opening state: seven areas are named, and no judgement is shown before the
         learner has met the rules behind them. -->
    <div v-if="!showChips" class="readyfig__intro">
      <p class="readyfig__intro-title">{{ graph.chips_title }}</p>
      <p class="readyfig__intro-note">{{ graph.chips_note }}</p>
    </div>

    <template v-else>
      <p class="readyfig__title">{{ graph.chips_title }}</p>

      <ul class="readyfig__chips" aria-label="Readiness areas">
        <li
          v-for="domain in domains"
          :key="domain.domain"
          :ref="(element) => setChipRef(domain.domain, element as Element | null)"
          class="readyfig__chip"
          :class="[
            statusClass(domain.status),
            { 'is-changed': domain.domain === changedDomain },
          ]"
        >
          <span class="readyfig__chip-name">{{ domain.domain }}</span>
          <span class="readyfig__chip-status">{{ domain.status }}</span>
        </li>
      </ul>

      <!-- The counts, as a summary of the seven judgements rather than a score. Each
           segment is labelled with its own number, and the block says what it is. -->
      <div ref="countsEl" class="readyfig__counts">
        <p class="readyfig__counts-title">{{ graph.counts_title }}</p>
        <div
          v-if="counts"
          class="readyfig__bar"
          role="img"
          :aria-label="`${graph.green_label} ${counts.green}, ${graph.amber_label} ${counts.amber}, ${graph.red_label} ${counts.red}`"
        >
          <span
            v-for="segment in [
              { key: 'green', label: graph.green_label, value: counts.green },
              { key: 'amber', label: graph.amber_label, value: counts.amber },
              { key: 'red', label: graph.red_label, value: counts.red },
            ]"
            :key="segment.key"
            class="readyfig__segment"
            :class="`readyfig__segment--${segment.key}`"
            :style="{ flexGrow: segment.value }"
          >
            <span v-if="segment.value > 0" class="readyfig__segment-value">
              {{ segment.value }}
            </span>
          </span>
        </div>
        <p class="readyfig__counts-note">{{ graph.chips_note }}</p>
      </div>
    </template>

    <JourneySpotlight
      v-if="dim && hole"
      :area="rootBox"
      :hole="hole"
      :scope="scope"
      :text="''"
    />
  </div>
</template>
