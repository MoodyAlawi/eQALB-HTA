/**
 * Validates every TeX expression the method notes carry.
 *
 * The mathematics lives in R (`MODULE_METHOD_NOTES` in `eqalb_ui_copy.R`) and reaches
 * the interface as strings: one display equation per module and inline `$…$` spans
 * inside the prose and the symbol tables. A malformed expression would otherwise ship
 * silently — the panel would show its plain fallback and nobody would notice until a
 * learner did — so every expression is typeset here, headlessly, before it can be
 * released.
 *
 * It reads the dictionary the way the API serialises it (R writes the JSON, this script
 * reads it), typesets each expression with the same renderer and the same options the
 * component uses, and exits non-zero listing anything that throws.
 *
 * Usage, from `frontend/`:
 *
 *   node scripts/check-math.mjs path/to/methodnotes.json
 *
 * The JSON is produced by R, so the check runs against the authored source rather than
 * a copy of it.
 */

import { readFileSync } from 'node:fs'
import katex from 'katex'

/** The delimiters the component pairs, and the options it renders with. */
const INLINE = /\$([^$]+)\$/g
const OPTIONS = { output: 'htmlAndMathml', trust: false, throwOnError: true, strict: false }

const path = process.argv[2]
if (!path) {
  console.error('usage: node scripts/check-math.mjs <methodnotes.json>')
  process.exit(2)
}

const notes = JSON.parse(readFileSync(path, 'utf8'))
let checked = 0
const failures = []

function check(where, tex, displayMode) {
  checked += 1
  try {
    katex.renderToString(tex, { ...OPTIONS, displayMode })
  } catch (error) {
    failures.push({ where, tex, message: String(error?.message ?? error).split('\n')[0] })
  }
}

/** Every `$…$` span inside one prose string. */
function checkInline(where, value) {
  if (typeof value !== 'string') return
  for (const match of value.matchAll(INLINE)) check(where, match[1], false)
  // An unpaired delimiter would silently render as a literal dollar sign.
  if ((value.match(/\$/g) ?? []).length % 2 !== 0) {
    failures.push({ where, tex: value, message: 'unpaired "$" delimiter' })
  }
}

for (const [id, note] of Object.entries(notes)) {
  if (note.formula) check(`${id}.formula`, note.formula, true)
  for (const field of ['summary', 'interpretation']) checkInline(`${id}.${field}`, note[field])
  for (const [index, step] of (note.steps ?? []).entries()) checkInline(`${id}.steps[${index}]`, step)
  for (const [index, line] of (note.assumptions ?? []).entries()) {
    checkInline(`${id}.assumptions[${index}]`, line)
  }
  for (const [index, row] of (note.definitions ?? []).entries()) {
    checkInline(`${id}.definitions[${index}].symbol`, row.symbol)
    checkInline(`${id}.definitions[${index}].meaning`, row.meaning)
  }
  for (const [index, row] of (note.table ?? []).entries()) {
    checkInline(`${id}.table[${index}].label`, row.label)
    checkInline(`${id}.table[${index}].value`, row.value)
  }
}

if (failures.length > 0) {
  console.error(`math check FAILED: ${failures.length} of ${checked} expression(s)`)
  for (const failure of failures) {
    console.error(`  ${failure.where}: ${failure.message}\n    ${failure.tex}`)
  }
  process.exit(1)
}

console.log(`math check passed: ${checked} expression(s) across ${Object.keys(notes).length} note(s)`)
