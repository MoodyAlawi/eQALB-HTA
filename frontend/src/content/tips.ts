/**
 * The educational tips shown under four analysis tabs.
 *
 * They are general teaching points about HTA methods, written as supplied and kept
 * verbatim: this file is the one place to edit them. They are not model output, so
 * they are shown only in the dashboard panel itself — never in presentation mode, a
 * CSV, a chart image or the results package.
 */

export type TipTopic = 'baseCase' | 'voi' | 'survival' | 'readiness'

export const TIPS: Readonly<Record<TipTopic, readonly string[]>> = {
  baseCase: [
    'The Markov "memoryless" assumption means everyone in the "Post-MI" state has the exact same risk going forward, regardless of whether they arrived there in Year 1 or Year 9.',
    'Discounting both costs and QALYs at 3% per year is why prevention programs—which pay upfront today to prevent strokes ten years from now—always fight an uphill battle in HTA.',
  ],
  voi: [
    "If your probability of cost-effectiveness is 99%, your EVPI will be near zero. Certainty means you don't need to fund another clinical trial.",
    'Even if a parameter has wide uncertainty on the tornado diagram, its EVPPI is zero if varying it never actually flips the final reimbursement decision.',
    'Per-patient EVPI looks small on its own. Multiply it by the eligible patient population over 5 years to find the maximum sensible budget for future research.',
  ],
  survival: [
    'In a Kaplan–Meier risk table, a drop in the "at-risk" count doesn\'t mean everyone had an event—many were simply censored because follow-up ended.',
  ],
  readiness: [
    'Unlike a pill, a digital therapeutic only works while patients actually open the app. Model follow-up engagement drop-off early, or your 10-year QALY projection is pure fiction.',
    'If your digital tool saves €20 in medication costs but takes a cardiologist 15 minutes per patient to review the dashboard, your hidden workflow burden will sink implementation.',
    'High digital health efficacy in a clinical trial rarely survives contact with an unintegrated hospital IT system. Check interoperability before celebrating the ICER.',
    'Digital exclusion is an HTA variable too. If 30% of your target demographic lacks smartphone literacy, your real-world population reach shrinks before day one.',
  ],
}
