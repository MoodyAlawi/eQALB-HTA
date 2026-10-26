<script lang="ts">
/**
 * The one opening sequence every overlay box in the app shares.
 *
 * The values live here, next to the geometry they belong to, so no host can give itself
 * a different rhythm: `EcgOverlay` waits `ECG_REVEAL_MS` before it shows the interior,
 * the words and the actions, and the signal's own delays are derived from the same two
 * numbers below.
 */

/** The two origins lighting at the corners. */
export const ECG_SEED_MS = 220

/** When the four traces leave their corners — the seeds are lit first. */
export const ECG_TRACE_START_MS = 180

/** How long one side takes to travel from its corner to the other. */
export const ECG_TRACE_MS = 620

/** The moment the perimeter has closed: the interior, words and actions arrive together. */
export const ECG_REVEAL_MS = ECG_TRACE_START_MS + ECG_TRACE_MS

/** One cycle of the looping signal. */
export const ECG_SIGNAL_MS = 4400

/** The second diagonal pair starts half a cycle later, so the two pairs alternate. */
export const ECG_SIGNAL_HALF_MS = ECG_SIGNAL_MS / 2
</script>

<script setup lang="ts">
/**
 * The ECG perimeter: the trace *is* the box's outline.
 *
 * There is no card border, no corner radius and no second track inside a frame. The
 * four sides of the box are the four sides of one ECG line, and that line is the only
 * thing drawn around the content. The interior is a plain surface underneath, supplied
 * by the host through `EcgOverlay`; it never draws an edge of its own.
 *
 * It opens the way the Home screen's signal behaves rather than the way a border
 * appears. Nothing is drawn first: two luminous origins light at the south-west and
 * north-east corners, and from each origin two traces leave along the adjoining sides
 * until the perimeter closes at the other two corners. Once it has closed, the interior,
 * the words and the actions arrive together and a short illuminated segment keeps
 * passing along the same path, edge by edge, on the Home title's own cycle — a dash that
 * crosses once and then waits off the path. It is the same geometry lit in turn, never a
 * second line and never an enclosing border.
 *
 * The geometry is computed in pixels from the element's measured box, so the trace sits
 * `INSET` px inside the host's border box and reaches at most `INSET + BEAT_DEPTH` px
 * (16px) inward. Each side that has room carries exactly one heartbeat of the same shape
 * and the same size, centred on it, so the box shows four deflections at most — never a
 * repeating comb, and never a small one beside a large one. Every host insets its
 * content by more than 16px, so no word or control is ever touched by the line, and the
 * line itself takes no pointer.
 *
 * Under `prefers-reduced-motion: reduce` the box is simply finished: the outline is
 * complete and still, both origins are lit, and no signal travels. Nothing here holds up
 * the content — `EcgOverlay` drops the reveal entirely in that mode.
 */

import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

/** The gap, in px, between the host's border box and the trace's baseline. */
const INSET = 9

/** The tallest deflection's reach inward from that baseline, in px. */
const BEAT_DEPTH = 7

/** One heartbeat's width along an edge, in px. */
const BEAT_WIDTH = 64

/** How much edge a side needs before it is given a heartbeat of its own. */
const BEAT_ROOM = BEAT_WIDTH + 44

/** The box the perimeter is drawn for, in px. */
const host = ref<SVGSVGElement | null>(null)
const width = ref(0)
const height = ref(0)

let observer: ResizeObserver | null = null

function measure(): void {
  const element = host.value
  if (!element) return
  const rect = element.getBoundingClientRect()
  const nextWidth = Math.round(rect.width)
  const nextHeight = Math.round(rect.height)
  if (nextWidth !== width.value) width.value = nextWidth
  if (nextHeight !== height.value) height.value = nextHeight
}

onMounted(() => {
  measure()
  if (typeof ResizeObserver === 'undefined') return
  observer = new ResizeObserver(measure)
  if (host.value) observer.observe(host.value)
})

onBeforeUnmount(() => {
  observer?.disconnect()
  observer = null
})

/**
 * One heartbeat, as (distance along the edge, inward reach), both in px: the flat
 * baseline, the small P wave, the sharp QRS complex and the T wave. It is the same list
 * for every side, which is what makes the four deflections identical.
 */
const BEAT: ReadonlyArray<readonly [number, number]> = [
  [0, 0],
  [16, 0],
  [20, 2.5],
  [24, 0],
  [30, 0],
  [33, -1.5],
  [37, BEAT_DEPTH],
  [41, -2.5],
  [45, 0],
  [52, 0],
  [58, 4],
  [64, 0],
]

/**
 * The four sides. `axis` is the direction the side travels in from its own origin, which
 * is also the end its path starts at, so the draw-in reads as the trace leaving that
 * corner: the left side and the bottom leave the south-west origin, the top and the
 * right leave the north-east one. Both origins start at the same moment, so the two
 * pairs close the box together.
 *
 * `pair` is the side's place in the loop only: the signal visits one diagonal pair and
 * then the other, half a cycle apart.
 */
const EDGES: ReadonlyArray<{
  key: string
  axis: 'up' | 'right' | 'left' | 'down'
  pair: 0 | 1
}> = [
  { key: 'sw-up', axis: 'up', pair: 0 },
  { key: 'sw-along', axis: 'right', pair: 0 },
  { key: 'ne-along', axis: 'left', pair: 1 },
  { key: 'ne-down', axis: 'down', pair: 1 },
]

function round(value: number): number {
  return Math.round(value * 100) / 100
}

/**
 * One side as a path: the run between the two corners it joins, starting at its own
 * origin, with a single heartbeat centred on it when the side is long enough to hold one.
 */
function edgePath(axis: 'up' | 'right' | 'left' | 'down', w: number, h: number): string {
  const x0 = INSET
  const y0 = INSET
  const x1 = w - INSET
  const y1 = h - INSET
  const run = axis === 'up' || axis === 'down' ? y1 - y0 : x1 - x0
  if (run <= 0) return ''

  const startX = axis === 'right' || axis === 'up' ? x0 : x1
  const startY = axis === 'left' || axis === 'up' ? y1 : y0
  const dirX = axis === 'right' ? 1 : axis === 'left' ? -1 : 0
  const dirY = axis === 'down' ? 1 : axis === 'up' ? -1 : 0
  const inwardX = axis === 'up' ? 1 : axis === 'down' ? -1 : 0
  const inwardY = axis === 'right' ? -1 : axis === 'left' ? 1 : 0

  const commands: string[] = []
  function point(along: number, reach: number): void {
    const x = startX + dirX * along + inwardX * reach
    const y = startY + dirY * along + inwardY * reach
    commands.push(`${commands.length === 0 ? 'M' : 'L'}${round(x)} ${round(y)}`)
  }

  point(0, 0)
  if (run >= BEAT_ROOM) {
    const offset = (run - BEAT_WIDTH) / 2
    for (const [distance, reach] of BEAT) point(offset + distance, reach)
  }
  point(run, 0)

  return commands.join(' ')
}

/** Whether the box is big enough to carry a perimeter at all. */
const ready = computed(() => width.value >= 2 * INSET + 12 && height.value >= 2 * INSET + 12)

const edges = computed(() => {
  if (!ready.value) return []
  return EDGES.map((edge) => ({ ...edge, d: edgePath(edge.axis, width.value, height.value) }))
})

/** The two origins, at the corners the traces grow from. */
const origins = computed(() => {
  if (!ready.value) return []
  return [
    { key: 'sw', cx: INSET, cy: height.value - INSET },
    { key: 'ne', cx: width.value - INSET, cy: INSET },
  ]
})

/**
 * Each side's real length in px, measured from the rendered path.
 *
 * The draw-in and the travelling signal both dash the line, and dashing is only
 * predictable against the path's own length: `pathLength` is not honoured the same way
 * by every engine, and a dash that does not cover the whole side leaves a visibly
 * broken outline. So the length is read from the element itself and handed to the
 * stylesheet as `--ecg-len`, which makes both animations exact whatever the box
 * measures. Until it has been read the trace is not painted at all, so the box never
 * flashes a finished outline before it starts to form — only the origins are visible.
 */
const lengths = ref<Record<string, number>>({})

const measured = computed(() => Object.keys(lengths.value).length === EDGES.length)

function measureLengths(): void {
  const root = host.value
  if (!root) return
  const next: Record<string, number> = {}
  for (const path of Array.from(root.querySelectorAll<SVGPathElement>('[data-edge]'))) {
    const key = path.dataset.edge
    if (!key) continue
    const length = path.getTotalLength()
    if (Number.isFinite(length) && length > 0) next[key] = Math.round(length * 100) / 100
  }
  lengths.value = next
}

watch(edges, measureLengths, { flush: 'post' })

/** One side's own timing, and the length its dashes are measured against. */
function edgeStyle(edge: { key: string; pair: 0 | 1 }, signal = false): Record<string, string> {
  const style: Record<string, string> = {
    animationDelay: signal
      ? `${ECG_REVEAL_MS + edge.pair * ECG_SIGNAL_HALF_MS}ms`
      : `${ECG_TRACE_START_MS}ms`,
  }
  const length = lengths.value[edge.key]
  if (length !== undefined) style['--ecg-len'] = `${length}px`
  return style
}
</script>

<template>
  <svg
    ref="host"
    class="ecg-frame"
    :class="{ 'is-measured': measured }"
    :viewBox="`0 0 ${width} ${height}`"
    aria-hidden="true"
    focusable="false"
  >
    <!-- The box's outline: four sides, each drawn once from its own origin. -->
    <path
      v-for="edge in edges"
      :key="edge.key"
      class="ecg-frame__line"
      :data-edge="edge.key"
      :d="edge.d"
      :style="edgeStyle(edge)"
    />

    <!-- The signal: the same four paths, lit in turn, for as long as the box is open. -->
    <path
      v-for="edge in edges"
      :key="`pulse-${edge.key}`"
      class="ecg-frame__pulse"
      :d="edge.d"
      :style="edgeStyle(edge, true)"
    />

    <!-- The two origins, lit before the traces leave them. -->
    <circle
      v-for="origin in origins"
      :key="origin.key"
      class="ecg-frame__origin"
      :cx="origin.cx"
      :cy="origin.cy"
      r="2.4"
      :style="{ animationDuration: `${ECG_SEED_MS}ms` }"
    />
  </svg>
</template>
