/**
 * The three illustrative scenarios offered under "Reset model inputs".
 *
 * Each one is a starting set of assumptions, not a validated clinical case and not a
 * result: it names only the inputs it moves, in the model's own units (a percentage
 * is a fraction, as R's parameter spec has it). Every other model input takes R's
 * base-case default from the contract, and the willingness-to-pay threshold is R's
 * reference threshold, so nothing here restates a default or invents a threshold.
 * Applying one changes inputs only; the analyses still run on R.
 */

export type PresetId = 'red' | 'yellow' | 'green'

export interface Preset {
  id: PresetId
  /** The number on the button. */
  number: 1 | 2 | 3
  /** What the scenario is meant to illustrate, for the button's accessible name. */
  intent: string
  /** The inputs the scenario moves, by parameter id, in model units. */
  values: Readonly<Record<string, number>>
}

export const PRESETS: readonly Preset[] = [
  {
    id: 'red',
    number: 1,
    intent: 'eQalb clearly not preferred',
    values: {
      intervention_price: 720,
      implementation_cost: 40,
      healthcare_savings: 5,
      rrr: 0.05,
      engagement_year1: 0.5,
      engagement_followup: 0.25,
    },
  },
  {
    id: 'yellow',
    number: 2,
    intent: 'uncertain, borderline case',
    values: {
      intervention_price: 270,
      implementation_cost: 40,
      healthcare_savings: 30,
      rrr: 0.15,
      engagement_year1: 0.75,
      engagement_followup: 0.48,
    },
  },
  {
    id: 'green',
    number: 3,
    intent: 'eQalb clearly preferred',
    values: {
      intervention_price: 180,
      implementation_cost: 40,
      healthcare_savings: 40,
      rrr: 0.2,
      engagement_year1: 0.8,
      engagement_followup: 0.55,
    },
  },
]
