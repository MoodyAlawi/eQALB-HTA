<script setup lang="ts">
/**
 * One math renderer for the interface.
 *
 * It renders **designated** math and nothing else: the caller passes the piece of a
 * note that is mathematics, so no part of the page is auto-detected or rewritten. Two
 * modes:
 *
 *  - `display` — the whole `text` is one principal equation, set on its own line.
 *  - `inline` — the `text` is ordinary prose that may carry inline math between `$`
 *    delimiters (`$p_{\mathrm{eff}}$`), which are typeset in place; every other
 *    character is rendered exactly as it arrives.
 *
 * The source of every expression is R's: it travels in the method-note dictionary as
 * TeX inside ordinary strings, so the wording and the mathematics live in one place and
 * cannot drift from a Vue copy. JSON escapes the backslashes and JavaScript receives
 * them intact, so an R string is authored with doubled backslashes and nothing else has
 * to change on the way.
 *
 * KaTeX is configured to emit **both** its HTML and MathML (`htmlAndMathml`), so the
 * equation is announced correctly by assistive technology and still typeset visually,
 * and with `trust: false`, so no authored expression can inject a link, an embed or raw
 * HTML through the renderer. Nothing here is `v-html`'d except KaTeX's own output, and
 * only for the expression the caller designated.
 *
 * A malformed expression must not vanish silently: the renderer throws, this component
 * catches it, and the raw source is shown in a plain fallback so the mathematics is
 * still readable and the mistake is visible. A note whose math cannot be typeset still
 * shows every word.
 *
 * Long equations are handled in the stylesheet, not here: a display equation that
 * cannot fit its column wraps at the break points its author chose (`aligned` rows) and
 * scrolls inside its own box rather than widening the page.
 */

import katex from 'katex'
import 'katex/dist/katex.min.css'
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    /** The source: TeX for a display equation, prose with `$…$` spans otherwise. */
    text?: string | null
    /** Whether the whole text is one principal equation. */
    display?: boolean
  }>(),
  { text: null, display: false },
)

/** The renderer's settings: MathML alongside the HTML, and no trusted input. */
function typeset(source: string, displayMode: boolean): string {
  return katex.renderToString(source, {
    displayMode,
    output: 'htmlAndMathml',
    trust: false,
    throwOnError: true,
    strict: false,
  })
}

/** The inline-math delimiter pair. Ordinary prose has no `$`, so this is unambiguous. */
const INLINE = /\$([^$]+)\$/g

/** One piece of the inline text: a formula where the source carried one. */
interface Piece {
  math: boolean
  value: string
}

const pieces = computed<Piece[] | null>(() => {
  const text = props.text ?? ''
  if (props.display) return null
  const result: Piece[] = []
  let last = 0
  for (const match of text.matchAll(INLINE)) {
    const at = match.index ?? 0
    if (at > last) result.push({ math: false, value: text.slice(last, at) })
    result.push({ math: true, value: match[1] })
    last = at + match[0].length
  }
  if (last < text.length) result.push({ math: false, value: text.slice(last) })
  return result
})

/**
 * Every rendered piece, or null for one that could not be typeset. The fallback is
 * decided per piece, so one bad span cannot take the sentence around it down with it.
 */
const rendered = computed<(string | null)[]>(() => {
  if (props.display) {
    const source = (props.text ?? '').trim()
    if (!source) return [null]
    try {
      return [typeset(source, true)]
    } catch {
      return [null]
    }
  }
  return (pieces.value ?? []).map((piece) => {
    if (!piece.math) return null
    try {
      return typeset(piece.value, false)
    } catch {
      return null
    }
  })
})

/** The raw source of one inline piece, for the fallback. */
function sourceOf(index: number): string {
  return pieces.value?.[index]?.value ?? ''
}

const hasContent = computed(() => (props.text ?? '').trim().length > 0)
</script>

<template>
  <span v-if="hasContent" class="math" :class="{ 'math--display': display }">
    <template v-if="display">
      <span v-if="rendered[0]" class="math__tex" v-html="rendered[0]"></span>
      <code v-else class="math__fallback" :title="text ?? ''">{{ text }}</code>
    </template>

    <template v-else>
      <template v-for="(piece, index) in pieces" :key="index">
        <template v-if="piece.math">
          <span v-if="rendered[index]" class="math__tex" v-html="rendered[index]"></span>
          <code v-else class="math__fallback" :title="sourceOf(index)">{{ sourceOf(index) }}</code>
        </template>
        <template v-else>{{ piece.value }}</template>
      </template>
    </template>
  </span>
</template>

<style scoped>
.math {
  /* Inline math sits on the text's own baseline, so it must not add its own leading. */
  line-height: inherit;
}

.math--display {
  display: block;
  /* A principal equation is its own block: it can be wider than the prose around it and
     is centred, but it never widens the column — it scrolls inside this box instead. */
  max-width: 100%;
  overflow-x: auto;
  overflow-y: hidden;
  padding: 0.15rem 0;
}

.math--display .math__tex {
  display: block;
  text-align: center;
}

/* A fallback is the raw source: monospaced, quiet, and never mistaken for typeset
   mathematics. It is readable rather than styled away. */
.math__fallback {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.78em;
  padding: 0.1em 0.3em;
  border-radius: 3px;
  background: var(--panel-alt);
  color: var(--text);
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
</style>
