<script setup lang="ts">
/**
 * The journey's guidance overlay.
 *
 * It is four dimmed panes *around* a rectangular cut-out, not a ring or an
 * outline. The cut-out is empty, so the graph feature inside it is never tinted,
 * filtered, outlined or covered: nothing is drawn over it at all. The panes and
 * the connector are `pointer-events: none`, so a click or a Tab aimed at the graph
 * reaches the graph.
 *
 * R's one sentence for the state and the control that moves to the next state sit
 * together in one small card beside the cut-out, on the softened side of the
 * plane. The card is measured and placed so it never lands on the feature, on an
 * axis title or on the price control, and the advance control is inside the card
 * rather than floating over the graph. A one-pixel hairline bridges the gap to the
 * cut-out. There is no arrowhead: the only arrow in the chapter is the graph's own
 * dashed lead from usual care to usual care plus eQalb.
 *
 * The accent that marks the cut-out is painted strictly *inward* from the
 * cut-out's own boundary, and nothing is drawn outside it. Each figure chooses a
 * cut-out that holds the focused mark and the labels belonging to it whole, so an
 * accent that stays inside can never put a line or a glow through a category
 * label, a tick, an axis title or a value the state leaves sharp.
 *
 * Motion is a transition of position and opacity only. Under
 * `prefers-reduced-motion` the stylesheet removes it, and the overlay is just as
 * clear: the contrast of the panes against the sharp cut-out carries the guidance,
 * not an animation.
 */

import { computed, onBeforeUnmount, ref, watch } from 'vue'

interface SpotlightBox {
  left: number
  top: number
  width: number
  height: number
}

const props = defineProps<{
  /** The chart's own size in pixels; the overlay covers exactly this box. */
  area: { width: number; height: number }
  /** The cut-out, in pixels from the chart's top-left corner. It must enclose the
   *  focused mark and the labels that belong to it whole, and its edges must fall
   *  between text blocks rather than through them. */
  hole: SpotlightBox | null
  /** The pair of regions R asks the guide to connect, when it asks for one. */
  arrows?: { x1: number; y1: number; x2: number; y2: number }[]
  /** R's one sentence for this state. */
  text: string
  /** R's one-sentence explanation of a measure this state introduces, if any. */
  measure?: string | null
  /**
   * Which set of targets these coordinates belong to — the chapter on screen.
   *
   * A new chapter is a different picture, so a cut-out from one chapter is not a place
   * the next chapter's cut-out should travel from. When this changes the overlay is
   * placed at its new coordinates immediately instead of sliding across the panel
   * between two features that have nothing to do with each other.
   */
  scope?: string | null
}>()

/**
 * When a cut-out counts as a new target rather than a refinement of the same one.
 *
 * Two states of one chapter point at features of the same chart, so the cue travelling
 * between them is the chapter teaching: it shows that something moved. Two states of
 * different chapters, or two cut-outs that share almost no area, are not that
 * relationship, and animating between them would show the ring sliding over a chart it
 * never described.
 */
const MOVE_LIMIT = 0.5

/** Whether the cut-out moved to a different target rather than being nudged. */
function isNewTarget(before: SpotlightBox, after: SpotlightBox): boolean {
  const { width, height } = props.area
  const scaleX = Math.max(width, 1)
  const scaleY = Math.max(height, 1)
  const beforeCX = before.left + before.width / 2
  const beforeCY = before.top + before.height / 2
  const afterCX = after.left + after.width / 2
  const afterCY = after.top + after.height / 2
  return (
    Math.abs(afterCX - beforeCX) / scaleX > MOVE_LIMIT ||
    Math.abs(afterCY - beforeCY) / scaleY > MOVE_LIMIT ||
    Math.abs(after.width - before.width) / scaleX > MOVE_LIMIT ||
    Math.abs(after.height - before.height) / scaleY > MOVE_LIMIT
  )
}

/**
 * Whether the cue may travel to its new place.
 *
 * False for the first placement after the overlay appears and false whenever the
 * target changed rather than merely shifted: in both cases the new geometry is painted
 * where it belongs in one step. Nothing is timed — there is no delay and no frame to
 * wait for, because the stylesheet reads this as a transition duration and Vue applies
 * the new value in the same render the new coordinates arrive. A jump therefore never
 * shows the previous rectangle at all, which is the point: a stale or guessed cut-out
 * is worse than no travel.
 */
const travels = ref(false)
let lastHole: SpotlightBox | null = null
let lastScope: string | null = null

watch(
  () => [props.hole, props.scope ?? null] as const,
  ([hole, scope]) => {
    const before = lastHole
    lastHole = hole
    const scopeChanged = scope !== lastScope
    lastScope = scope
    travels.value =
      before !== null && hole !== null && !scopeChanged && !isNewTarget(before, hole)
  },
  { flush: 'pre' },
)

/** The stylesheet's own durations, off when a placement is a jump. */
const motion = computed(() => ({ '--spot-move': travels.value ? '220ms' : '0ms' }))

/**
 * Whether this width can hold a card over the plane at all. On a phone the plot
 * is narrow enough that the repeats fill it edge to edge, leaving no margin where a
 * sentence could sit without covering the very thing it describes. There the
 * overlay softens the plane and says nothing, and the chapter prints the sentence
 * directly under the chart, inside the same panel.
 */
const canAnchorCard = computed(() => props.area.width >= 520)

const showCard = computed(() => canAnchorCard.value && props.text.length > 0)

/** The narrowest column of softened plane a call-out may sit beside the hole. */
const SIDE_MIN = 150
/** The call-out's own reading width, with room for its control beside the text. */
const SIDE_MAX = 256
/**
 * A call-out spanning the plane reads across the panel's full width. A long
 * sentence is far easier to read as one wide line than as a narrow column, and a
 * wide short card fits the margin the plot leaves at either end.
 */
const BAND_MAX = 1000
/** The narrowest a call-out may be and still read as a sentence. */
const MIN_WIDTH = 132
/** The gap the connector bridges. */
const GAP = 12

/**
 * The card's own size. Its height decides which band can hold it, so it is
 * measured rather than guessed: a sentence that wraps to two lines needs a taller
 * band than one that fits on a line.
 */
const calloutEl = ref<HTMLElement | null>(null)
const calloutSize = ref({ width: 0, height: 0 })
let sizeObserver: ResizeObserver | null = null

/**
 * An estimate of the height the card would have at a given width.
 *
 * The real measurement describes the width the card had in the previous state, so
 * deciding the next width from it would make the placement depend on the order the
 * states were visited in. The estimate is computed from the sentence R sent at the
 * width being considered, which is what the choice needs; the measured height is
 * then used to keep the card inside the panel.
 */
function estimateHeight(width: number): number {
  const characters = Math.max(props.text.length, 1)
  const perLine = Math.max(8, Math.floor(width / 7.2))
  const lines = Math.ceil(characters / perLine)
  const measureLines = props.measure
    ? Math.ceil(props.measure.length / Math.max(8, Math.floor(width / 6.6)))
    : 0
  // The stylesheet's 19px line height plus the card's own padding, plus a smaller
  // second paragraph when the state explains a measure.
  return lines * 19 + measureLines * 17 + 22
}

function measureCallout(): void {
  const element = calloutEl.value
  if (!element) {
    if (sizeObserver) {
      sizeObserver.disconnect()
      sizeObserver = null
    }
    return
  }
  const height = element.offsetHeight
  const width = element.offsetWidth
  if (width !== calloutSize.value.width || height !== calloutSize.value.height) {
    calloutSize.value = { width, height }
  }
  if (!sizeObserver) {
    sizeObserver = new ResizeObserver(measureCallout)
    sizeObserver.observe(element)
  }
}

watch(calloutEl, measureCallout, { flush: 'post' })

onBeforeUnmount(() => {
  sizeObserver?.disconnect()
  sizeObserver = null
})

/**
 * The accent that marks the cut-out, drawn strictly inside it.
 *
 * It used to be drawn outside, which put its hairline and its halo over whatever
 * sat in the softened margin — including the category label of the very bar the
 * state was pointing at. Painting inward from the boundary, and painting only a
 * hairline, means the accent can only ever fall on what the cut-out already holds,
 * so the figures are free to choose a cut-out that encloses a feature together with
 * its labels and the accent follows the same outline. A cut-out too small to hold a
 * ring is left to the panes and to R's arrows rather than given a box it cannot
 * support.
 */
const ring = computed(() => {
  const hole = props.hole
  if (!hole) return null
  const inset = 1
  const width = hole.width - inset * 2
  const height = hole.height - inset * 2
  if (width < 12 || height < 12) return null
  return { left: hole.left + inset, top: hole.top + inset, width, height }
})

const panes = computed(() => {
  const { width, height } = props.area
  const hole = props.hole
  if (!hole || width <= 0 || height <= 0) return []
  const right = hole.left + hole.width
  const bottom = hole.top + hole.height
  return [
    { left: 0, top: 0, width, height: hole.top },
    { left: 0, top: bottom, width, height: Math.max(0, height - bottom) },
    { left: 0, top: hole.top, width: hole.left, height: hole.height },
    {
      left: right,
      top: hole.top,
      width: Math.max(0, width - right),
      height: hole.height,
    },
  ].filter((pane) => pane.width > 0 && pane.height > 0)
})

/**
 * Where the call-out goes and how far it may read across.
 *
 * A side is preferred when there is genuinely room for the card beside the
 * feature. Otherwise the card reads across in a band above or below it, and it
 * takes whichever band can actually hold its measured height, so a long sentence
 * moves rather than growing over an axis. When neither band can hold it — the
 * repeats can make the cut-out almost as tall as the plane — the card goes back
 * beside the feature on the roomier side, and its own edge is clamped inside the
 * panel. Nothing is ever placed on the cut-out itself, and nothing is left to be
 * clipped by the panel.
 */
const callout = computed(() => {
  const hole = props.hole
  const { width, height } = props.area
  if (!hole || width <= 0 || height <= 0) return null

  const right = hole.left + hole.width
  const bottom = hole.top + hole.height
  const roomRight = width - right
  const roomLeft = hole.left
  const roomBelow = height - bottom
  const roomAbove = hole.top
  // Before the first measurement, a one-line card's height is assumed; the
  // measurement then settles the placement in the next render.
  const cardHeight = Math.max(calloutSize.value.height, estimateHeight(MIN_WIDTH))
  const sideWidth = (room: number) =>
    Math.min(SIDE_MAX, Math.max(MIN_WIDTH, room - GAP))
  const bandWidth = Math.min(BAND_MAX, width - GAP * 2)
  const bandHeight = estimateHeight(bandWidth)
  /** Keeps the card's own edge inside the panel whatever it was placed against. */
  const clampTop = (value: number) => Math.max(0, Math.min(value, height - cardHeight))

  const side =
    roomRight >= SIDE_MIN + GAP && estimateHeight(sideWidth(roomRight)) <= roomBelow + cardHeight
      ? 'right'
      : roomAbove >= GAP + bandHeight
        ? 'above'
        : roomBelow >= GAP + bandHeight
          ? 'below'
          : roomLeft >= SIDE_MIN + GAP
            ? 'left'
            : roomLeft >= roomRight
              ? 'left'
              : 'right'

  if (side === 'right') {
    const cardWidth = sideWidth(roomRight)
    // Positioned by its own left edge and clamped, so a narrow right margin can
    // never push the card past the panel's edge.
    const left = Math.max(GAP, Math.min(right + GAP, width - GAP - cardWidth))
    const top = clampTop(hole.top)
    const midY = top + 14
    return {
      side,
      style: {
        left: `${left}px`,
        top: `${top}px`,
        width: `${cardWidth}px`,
      },
      box: { left, top, width: cardWidth, height: cardHeight },
      // The arrow leaves the card's own edge and points back at the feature, so the
      // head sits just outside the cut-out rather than on it.
      segment: { x1: left, y1: midY, x2: right + 2, y2: midY },
    }
  }

  if (side === 'left') {
    const cardWidth = sideWidth(roomLeft)
    const left = Math.max(GAP, hole.left - GAP - cardWidth)
    const top = clampTop(hole.top)
    const midY = top + 14
    return {
      side,
      style: {
        left: `${left}px`,
        top: `${top}px`,
        width: `${cardWidth}px`,
      },
      box: { left, top, width: cardWidth, height: cardHeight },
      segment: { x1: left + cardWidth, y1: midY, x2: hole.left - 2, y2: midY },
    }
  }

  // Above and below read across, so the call-out is centred under the feature and
  // clamped so that it cannot leave the panel. Its vertical position is emitted as
  // a top rather than a bottom, so it is clamped by the same rule as a side card.
  const centred = hole.left + hole.width / 2 - bandWidth / 2
  const left = Math.max(GAP, Math.min(centred, width - GAP - bandWidth))
  const anchor = Math.max(GAP, Math.min(hole.left + hole.width / 2, width - GAP))

  return side === 'below'
    ? {
        side,
        style: { left: `${left}px`, top: `${clampTop(bottom + GAP)}px`, width: `${bandWidth}px` },
        box: {
          left,
          top: clampTop(bottom + GAP),
          width: bandWidth,
          height: bandHeight,
        },
        // The card sits under the feature, so the head points up at it.
        segment: { x1: anchor, y1: clampTop(bottom + GAP), x2: anchor, y2: bottom + 2 },
      }
    : {
        side,
        style: {
          left: `${left}px`,
          top: `${clampTop(hole.top - GAP - cardHeight)}px`,
          width: `${bandWidth}px`,
        },
        box: {
          left,
          top: clampTop(hole.top - GAP - cardHeight),
          width: bandWidth,
          height: bandHeight,
        },
        segment: {
          x1: anchor,
          y1: clampTop(hole.top - GAP - cardHeight) + cardHeight,
          x2: anchor,
          y2: hole.top - 2,
        },
      }
})

/** A segment drawn over the plane, with its head at its end. */
interface Arrow {
  x1: number
  y1: number
  x2: number
  y2: number
}

/** Whether any part of a segment falls inside a rectangle, sampled along it. */
function segmentHitsBox(a: Arrow, box: SpotlightBox): boolean {
  const steps = 40
  for (let i = 0; i <= steps; i++) {
    const t = i / steps
    const x = a.x1 + (a.x2 - a.x1) * t
    const y = a.y1 + (a.y2 - a.y1) * t
    if (x > box.left && x < box.left + box.width && y > box.top && y < box.top + box.height) {
      return true
    }
  }
  return false
}

/**
 * Shortens a lead from its tail until it stops short of the card, keeping the head
 * where it points. A lead that cannot survive the trim — because the card sits over
 * most of it — is dropped instead of being drawn as a stub.
 */
function trimToCard(arrow: Arrow): Arrow | null {
  const box = callout.value?.box
  if (!box) return arrow
  const trimmed = { ...arrow }
  for (let i = 0; i < 24 && segmentHitsBox(trimmed, box); i++) {
    trimmed.x1 += (trimmed.x2 - trimmed.x1) * 0.08
    trimmed.y1 += (trimmed.y2 - trimmed.y1) * 0.08
  }
  if (segmentHitsBox(trimmed, box)) return null
  const length = Math.hypot(trimmed.x2 - trimmed.x1, trimmed.y2 - trimmed.y1)
  return length < 20 ? null : trimmed
}

/**
 * The arrows actually drawn. R's directional leads are the guide, so they are drawn
 * wherever there is a plane to draw them on. The connector only exists to join a
 * card to its feature, so it disappears with the card when the plane is too narrow
 * to hold one.
 *
 * Each lead is also trimmed so that it stops short of the card: an arrow may point
 * past the sentence, but it must not run underneath or across it. A lead that would
 * have to be cut to a stub is dropped rather than drawn as a fragment.
 */
const renderedArrows = computed(() => {
  const leads = (props.arrows ?? [])
    .map((arrow) => trimToCard(arrow))
    .filter((arrow): arrow is Arrow => arrow !== null)
  if (!showCard.value) return leads
  const segment = callout.value?.segment
  return segment ? [...leads, segment] : leads
})
const arrowPath = (arrow: { x1: number; y1: number; x2: number; y2: number }) =>
  `M ${arrow.x1} ${arrow.y1} L ${arrow.x2} ${arrow.y2}`
</script>

<template>
  <div class="spot" :style="motion">
    <span
      v-for="(pane, index) in panes"
      :key="index"
      class="spot__pane"
      aria-hidden="true"
      :style="{
        left: `${pane.left}px`,
        top: `${pane.top}px`,
        width: `${pane.width}px`,
        height: `${pane.height}px`,
      }"
    ></span>

    <!-- The focused feature's own mark: a hairline ring drawn strictly inside the
         cut-out, so it replaces the blur that used to soften the rest of the chart
         without ever putting a line through a label, a tick or an axis title. -->
    <span
      v-if="ring"
      class="spot__ring"
      aria-hidden="true"
      :style="{
        left: `${ring.left}px`,
        top: `${ring.top}px`,
        width: `${ring.width}px`,
        height: `${ring.height}px`,
      }"
    ></span>

    <!-- The guide's own drawing: a slim teal trace from the sentence to the
         feature, and any direction R asked for between two features. Each is a
         hairline with a small head, so it points without covering anything. -->
    <svg
      class="spot__arrows"
      aria-hidden="true"
      :viewBox="`0 0 ${Math.max(1, area.width)} ${Math.max(1, area.height)}`"
      preserveAspectRatio="none"
    >
      <defs>
        <marker
          id="spot-arrow-head"
          viewBox="0 0 8 8"
          refX="6"
          refY="4"
          markerWidth="5"
          markerHeight="5"
          orient="auto-start-reverse"
        >
          <path d="M 0 1 L 6 4 L 0 7" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" />
        </marker>
      </defs>
      <g
        v-for="(arrow, index) in renderedArrows"
        :key="index"
        class="spot__arrow"
        :class="{ 'spot__arrow--lead': index < (props.arrows?.length ?? 0) }"
      >
        <path
          class="spot__arrow-path"
          :d="arrowPath(arrow)"
          fill="none"
          stroke="currentColor"
          stroke-width="1.6"
          stroke-linecap="round"
          pathLength="100"
          marker-end="url(#spot-arrow-head)"
        />
      </g>
    </svg>

    <div v-if="callout && showCard" ref="calloutEl" class="spot__callout" :style="callout.style">
      <div class="spot__callout-body">
        <p class="spot__callout-text" aria-live="polite">{{ text }}</p>
        <p v-if="measure" class="spot__callout-measure" aria-live="polite">{{ measure }}</p>
      </div>
    </div>
  </div>
</template>
