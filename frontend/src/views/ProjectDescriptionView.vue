<script setup lang="ts">
/**
 * Project description subview.
 *
 * The wording is the Shiny Project description page (app.R, nav_page
 * "description"), kept as it stands, plus a list of the analyses this interface
 * provides and the same contact and repository links.
 */

import { onMounted, onUnmounted, ref } from 'vue'
import { useAppView } from '../composables/useAppView'

const { goHome } = useAppView()
const heading = ref<HTMLHeadingElement | null>(null)

/** Escape returns to the Home screen, as the Back button does. */
function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape') goHome()
}

onMounted(() => {
  heading.value?.focus()
  window.addEventListener('keydown', onKeydown)
})
onUnmounted(() => window.removeEventListener('keydown', onKeydown))

const ANALYSES = [
  'Cost-effectiveness: the shared assumptions, the base case (incremental cost, incremental QALYs and the ICER) and the cost-effectiveness plane.',
  'Probabilistic sensitivity analysis: the simulation cloud and the cost-effectiveness acceptability curve.',
  'Deterministic one-way sensitivity analysis: the tornado diagram with editable ranges.',
  'Budget impact: per-year costs, savings and the cumulative net budget impact over the horizon.',
  'Simulated survival: illustrative Kaplan-Meier curves with a risk table and diagnostics.',
  'Value of information: EVPI and EVPPI per patient from the PSA draws.',
  'DHT readiness and implementation: reach, clinician workload and a seven-domain readiness assessment.',
  'HTA decision summary: a five-domain traffic-light dashboard with the evidence-generation plan.',
]
</script>

<template>
  <section class="page page--centered" aria-labelledby="description-title">
    <div class="page__inner">
      <h1 id="description-title" ref="heading" class="page__title" tabindex="-1">
        Project description
      </h1>

      <div class="page__prose">
        <p>
          eQalb is a fictional digital health intervention designed to support hypertension
          management. In this project, eQalb is assessed as a supplementary intervention alongside
          usual care. It is not presented as a real product or validated clinical technology.
        </p>
        <p>
          This application simulates a simplified health technology assessment of eQalb. It brings
          together cost-effectiveness analysis, deterministic and probabilistic sensitivity
          analysis, value-of-information analysis, budget impact, illustrative clinical-outcome
          simulation, implementation readiness, and evidence-generation priorities.
        </p>
        <p>
          The application is designed as a practical learning and exploration tool. It demonstrates
          how different types of evidence can contribute to an HTA decision, how assumptions affect
          costs and health outcomes, and how uncertainty may influence the need for further
          evidence.
        </p>
        <p>
          All clinical outcomes, economic results, parameter values, and decision rules are
          illustrative or simulated for educational purposes. The application is not a validated
          HTA, clinical prediction tool, regulatory assessment, reimbursement submission, or
          official recommendation. The traffic-light classifications are presentation rules created
          for this teaching application and should not be interpreted as official NICE, payer, or
          policy criteria.
        </p>
        <p>
          The model is intended to support learning about economic evaluation and HTA rather than to
          guide real-world clinical, funding, or policy decisions.
        </p>
      </div>

      <h2 class="page__subtitle">Analyses included</h2>
      <ul class="list page__list">
        <li v-for="analysis in ANALYSES" :key="analysis">{{ analysis }}</li>
      </ul>

      <h2 class="page__subtitle">How it is built</h2>
      <p class="page__prose">
        Every economic, readiness and decision result is computed by the R model and returned
        through the model service. This interface presents those results; it does not calculate,
        adjust or reinterpret them. The Shiny application remains the reference implementation of
        the same model, and a guided tutorial is available from the Home screen.
      </p>

      <h2 class="page__subtitle">Feedback and contact</h2>
      <p class="page__prose">
        I welcome feedback on the model, its educational usefulness, and possible improvements. You
        can contact me at <a href="mailto:smalawi2018@gmail.com">smalawi2018@gmail.com</a> or
        connect with me on
        <a
          href="https://www.linkedin.com/in/mahmoodalawi"
          target="_blank"
          rel="noopener noreferrer"
          >LinkedIn</a
        >.
      </p>
      <p class="page__prose">
        Source code:
        <a
          href="https://github.com/MoodyAlawi/eQALB-HTA"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="View the eQalb HTA source repository on GitHub"
          >github.com/MoodyAlawi/eQALB-HTA</a
        >.
      </p>

      <div class="page__actions">
        <button type="button" class="btn btn--ghost" @click="goHome()">Back</button>
      </div>
    </div>
  </section>
</template>
