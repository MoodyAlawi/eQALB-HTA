<script setup lang="ts">
/**
 * About OpenHealth: who is behind the initiative, why it exists and how to join
 * in, shown at "/about".
 *
 * It is a distinct page rather than the eQalb project description: that page
 * describes the model and its results, while this one introduces the umbrella
 * education initiative and its first tool. It is presentation only, so it holds
 * no state, makes no request, and shares nothing with the analysis.
 *
 * Nothing here offers a service or makes a commercial claim, and no collaborator,
 * partner, funder or achievement is claimed, because none exists yet. The two
 * external links are the ones already used elsewhere in the interface, and no
 * contact address is invented.
 *
 * Escape returns to the OpenHealth landing page, which is this page's parent, the
 * same way the eQalb subviews use Escape as "back".
 */

import { onMounted, onUnmounted, ref } from 'vue'
import { followLink, pagePath, useAppView } from '../composables/useAppView'

const { show } = useAppView()
const heading = ref<HTMLHeadingElement | null>(null)

/** Escape returns to the landing page, as the Back button does. */
function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape') show('openhealth')
}

onMounted(() => {
  heading.value?.focus()
  window.addEventListener('keydown', onKeydown)
})
onUnmounted(() => window.removeEventListener('keydown', onKeydown))

const LINKEDIN_URL = 'https://www.linkedin.com/in/mahmoodalawi'
const GITHUB_URL = 'https://github.com/MoodyAlawi/eQALB-HTA'
</script>

<template>
  <section class="page page--centered" aria-labelledby="about-title">
    <div class="page__inner">
      <h1 id="about-title" ref="heading" class="page__title" tabindex="-1">About OpenHealth</h1>

      <div class="page__prose">
        <p>
          OpenHealth is an independent, education-first initiative founded by Mahmood Alawi, a
          health economist. The aim is not to sell anything: it is to make complex healthcare
          knowledge — clinical, economic, decision-making, policy, research and implementation —
          easier to reach and easier to use.
        </p>
        <p>
          The motivation is straightforward. A great deal of health knowledge is effectively
          gated: it is written for readers who already know the vocabulary, it assumes access to
          journals or expensive courses, or it treats economics, policy and implementation as
          somebody else's subject. That gatekeeping keeps capable people out of conversations they
          should be part of.
        </p>
        <p>
          OpenHealth works on the opposite idea, deliberately crossing disciplines: a nurse, an
          administrator, a researcher, a policy professional, a data specialist and a health
          economist should be able to learn from the same material and from each other. Complex
          topics become learnable when they are explained plainly and can be tried rather than only
          described.
        </p>
      </div>

      <h2 class="page__subtitle">How it is organised</h2>
      <ul class="list page__list">
        <li>
          OpenHealth is the umbrella public education initiative: the home for this work and for
          what comes next.
        </li>
        <li>
          eQalb is its first flagship learning tool — an interactive health technology assessment
          simulator.
        </li>
        <li>
          eQalb is built around a fictional intervention and simulated data. It is educational, not
          clinical: it is not a validated model, not clinical advice, and not a tool for live
          healthcare, funding or policy decisions.
        </li>
        <li>
          OpenHealth welcomes ideas and collaboration from across clinical practice, nursing,
          administration, research, policy, health economics, implementation, data, and related
          healthcare fields.
        </li>
      </ul>

      <h2 class="page__subtitle">Get involved</h2>
      <p class="page__prose">
        If you teach, practise, study or research in any of these areas — or you simply have an
        idea about how this material could be taught better — you are welcome to get in touch.
        Ideas, educational resources, corrections, feedback and potential contributions are all
        useful, and cross-disciplinary collaboration is exactly the point. Connect on
        <a
          :href="LINKEDIN_URL"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Open Mahmood Alawi's LinkedIn profile"
          >LinkedIn</a
        >, or open an issue or a discussion on
        <a
          :href="GITHUB_URL"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="View the eQalb HTA source repository on GitHub"
          >GitHub</a
        >.
      </p>

      <div class="page__actions">
        <a
          class="btn btn--primary"
          :href="pagePath('home')"
          @click="followLink($event, 'home')"
        >
          Explore eQalb
        </a>
        <a class="btn btn--ghost" :href="pagePath('openhealth')" @click="followLink($event, 'openhealth')">
          Back to OpenHealth
        </a>
      </div>
    </div>
  </section>
</template>
