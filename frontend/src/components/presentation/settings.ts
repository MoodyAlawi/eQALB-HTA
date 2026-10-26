/**
 * The two small pieces every presentation overlay builds its wording from: the
 * sentence that names what has moved since the run, and the rows for a scenario
 * the response reports.
 *
 * Nothing here reads a model value or derives a figure. The rows are formatted by
 * the panel, from values the answer already carries, and the sentence only says
 * which of the panel's own settings no longer describe the presented run.
 */

/**
 * "The controls have changed since this run: X and Y. Everything below is what the
 * run used." — or '' when nothing has moved. The caller names the settings in the
 * run's own terms, so the sentence never claims more than was compared.
 */
export function movedSentence(parts: string[]): string {
  const named = parts.filter(Boolean)
  if (named.length === 0) return ''
  const list =
    named.length === 1
      ? named[0]
      : `${named.slice(0, -1).join(', ')} and ${named[named.length - 1]}`
  return `The controls have changed since this run: ${list}. Everything below is what the run used.`
}

/**
 * One row per scenario parameter the response reports, using the contract's own
 * label and unit and the form's own conversion (a fraction prints as a percentage,
 * float noise trimmed). A parameter the run did not report is left out rather than
 * filled in from the panel's controls.
 */
export function scenarioSettingRows(
  runInputs: Record<string, number | null>,
  specs: { id: string; label: string; unit: string; percent: boolean }[],
  prefix = 'scenario_',
): { id: string; label: string; value: string; unit: string }[] {
  const rows: { id: string; label: string; value: string; unit: string }[] = []
  for (const spec of specs) {
    const used = runInputs[`${prefix}${spec.id}`]
    if (typeof used !== 'number' || !Number.isFinite(used)) continue
    rows.push({
      id: spec.id,
      label: spec.label,
      value: String(Number((spec.percent ? used * 100 : used).toFixed(6))),
      unit: spec.percent ? '%' : spec.unit,
    })
  }
  return rows
}

/** One row, for a value the response reports under its own name. */
export function settingRow(
  id: string,
  label: string,
  value: string,
  unit: string,
): { id: string; label: string; value: string; unit: string } {
  return { id, label, value, unit }
}

/**
 * The line a presentation shows when the panel's own result has been replaced by
 * a later run while the overlay is open. Nothing about the presented figures
 * changes — they are the run the overlay was opened on — so the sentence says
 * exactly that rather than suggesting the view is out of date.
 */
export function supersededSentence(): string {
  return 'A later run has replaced this result in the panel. What is shown here is still the run this presentation was opened on.'
}

/**
 * The labels for the request fields the HTA summary can report as not supplied.
 *
 * The endpoint names the fields it can report — the upstream analyses' own values
 * — and a presentation is read by someone who has never seen the contract, so each
 * is named here with the wording the workspace already uses for that value (the
 * metric card's own label). No field is dropped and no value is guessed: a
 * presentation says which information the assessment did not receive, in the
 * reader's terms.
 *
 * `incremental_cost` and `incremental_qalys` are the two the economic rule reads;
 * `icer` is kept for a response from a build that still reported it. A field the
 * contract does not have is written out with its underscores removed rather than
 * left as an identifier, so nothing is ever shown as a raw name even if the
 * endpoint grows another.
 */
const AVAILABILITY_FIELD_LABELS: Record<string, string> = {
  incremental_cost: 'Incremental cost',
  incremental_qalys: 'Incremental QALYs',
  icer: 'ICER',
  probability_cost_effective: 'Probability cost-effective',
  evpi: 'EVPI per patient',
  cumulative_budget_impact: 'Cumulative net budget impact',
  readiness: 'DHT readiness',
}

/** The user-facing name of one not-supplied request field. */
export function availabilityFieldLabel(field: string): string {
  return AVAILABILITY_FIELD_LABELS[field] ?? field.replace(/_/g, ' ')
}
