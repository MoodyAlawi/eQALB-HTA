<script setup lang="ts">
/**
 * OpenHealth landing page: the public front door, shown at "/".
 *
 * It is presentation only. Every action is a link to one of the three public
 * addresses - the eQalb application at /app, the About page at /about, or this
 * page itself - so no input, result or API call is involved and arriving here or
 * leaving again never disturbs a run. eQalb stays one click away from every
 * section.
 *
 * The copy is deliberately honest about what exists: an early-stage,
 * education-first project and one interactive learning tool (eQalb), whose data
 * and outputs are illustrative and simulated for teaching. Nothing here claims a
 * blog, a community, partners, funding, users, or any clinical or professional
 * service, and no contact address is invented - the two external links are the
 * ones already used elsewhere in the interface.
 *
 * The theme control is the same icon button the eQalb Home screen carries, in the
 * same pinned top-right position, and the heading is focused after navigation
 * like the other standalone views, so a keyboard or screen-reader user is placed
 * on the page they asked for.
 */

import { onMounted, ref } from 'vue'
import { followLink, pagePath, useAppView } from '../composables/useAppView'
import { useTheme } from '../composables/useTheme'

// Installs the app-wide disclosure behaviour and the history listener; this page
// navigates with the anchor links below, so it needs nothing else from the store.
useAppView()
const { theme, toggle } = useTheme()

const heading = ref<HTMLHeadingElement | null>(null)

onMounted(() => heading.value?.focus())

const LINKEDIN_URL = 'https://www.linkedin.com/in/mahmoodalawi'
const GITHUB_URL = 'https://github.com/MoodyAlawi/eQALB-HTA'

/** The concepts eQalb lets a learner explore; named, not explained here. */
const FLAGSHIP_TOPICS = [
  'Incremental costs and incremental QALYs',
  'The incremental cost-effectiveness ratio (ICER)',
  'Uncertainty, probabilistic sensitivity analysis and acceptability curves',
  'Budget impact over a time horizon',
  'Value of information (EVPI and EVPPI)',
  'Implementation readiness for a digital health technology',
]

/** The fields OpenHealth wants to learn from, and to grow with. */
const FIELDS = [
  'clinical practice',
  'nursing',
  'administration',
  'research',
  'policy',
  'health economics',
  'implementation',
  'data',
]
</script>

<template>
  <section class="oh" aria-labelledby="oh-title">
    <div class="oh__topbar">
      <button
        type="button"
        class="btn btn--icon"
        :title="theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'"
        :aria-label="theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'"
        @click="toggle()"
      >
        <span aria-hidden="true">{{ theme === 'dark' ? '☀' : '☾' }}</span>
      </button>
    </div>

    <header class="oh__hero">
      <p class="oh__eyebrow">Independent · education-first</p>
      <h1 id="oh-title" ref="heading" class="oh__name" tabindex="-1">OpenHealth</h1>
      <p class="oh__lede">
        Healthcare knowledge should not be locked behind jargon, paywalls or closed doors.
        OpenHealth is a personal project that makes clinical, economic, policy, research and
        implementation learning easier to reach — for students and practitioners wherever they are
        starting from.
      </p>

      <div class="oh__actions">
        <a
          class="btn btn--primary btn--lg"
          :href="pagePath('home')"
          @click="followLink($event, 'home')"
        >
          Explore eQalb
        </a>
        <a class="btn btn--ghost" :href="pagePath('about')" @click="followLink($event, 'about')">
          Our mission
        </a>
      </div>
    </header>

    <section class="oh__section" aria-labelledby="oh-mission">
      <h2 id="oh-mission" class="oh__section-title">Why OpenHealth exists</h2>
      <p class="oh__prose">
        Health education should be clearer, more practical, and easier to reach. The subjects that
        shape real decisions — how evidence is weighed, how costs and outcomes are compared, how
        policy and implementation work — are often taught in ways that assume a reader already
        knows how to read them.
      </p>
      <p class="oh__prose oh__prose--last">
        OpenHealth works on the opposite idea: explain these subjects plainly, show them in
        practice, and let more people take part. It complements formal education and professional
        judgement rather than replacing either — it is a place to learn and to try things, not a
        source of advice.
      </p>
    </section>

    <section class="oh__section" aria-labelledby="oh-flagship">
      <h2 id="oh-flagship" class="oh__section-title">eQalb, the first flagship tool</h2>
      <p class="oh__prose">
        eQalb is OpenHealth's first flagship learning tool: an interactive health technology
        assessment (HTA) simulator built around a fictional digital therapeutic for hypertension.
        It is a model of a model — a complete, walkable assessment that a learner can take apart,
        re-parameterise, and question.
      </p>
      <p class="oh__prose">It is built to let a learner explore, for example:</p>
      <ul class="list oh__list">
        <li v-for="topic in FLAGSHIP_TOPICS" :key="topic">{{ topic }}</li>
      </ul>
      <p class="oh__notice">
        eQalb's data, evidence and outputs are illustrative and simulated for teaching. They are
        not clinical advice, not real-world evidence, and not a basis for live healthcare,
        funding or policy decisions.
      </p>
      <div class="oh__actions oh__actions--left">
        <a
          class="btn btn--primary"
          :href="pagePath('home')"
          @click="followLink($event, 'home')"
        >
          Open eQalb
        </a>
      </div>
    </section>

    <section class="oh__section" aria-labelledby="oh-future">
      <h2 id="oh-future" class="oh__section-title">Where this is going</h2>
      <p class="oh__prose oh__prose--last">
        OpenHealth is early-stage, and it says so. What exists today is eQalb. Planned next are
        plain-language explainers, shared learning resources and further interactive tools in the
        same spirit. There is no blog, community, partner programme or funding to report yet, and
        nothing beyond this application has been released.
      </p>
    </section>

    <section class="oh__section" aria-labelledby="oh-collaborate">
      <h2 id="oh-collaborate" class="oh__section-title">Build it together</h2>
      <p class="oh__prose oh__prose--last">
        OpenHealth is meant to grow through collaboration rather than one person's view. Ideas,
        educational resources, corrections, feedback and potential contributions are welcome from
        across
        <template v-for="(field, index) in FIELDS" :key="field">{{ index > 0 ? ', ' : ' ' }}{{ field }}</template>
        and related healthcare fields. Reach out on
        <a
          class="oh__link"
          :href="LINKEDIN_URL"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Open Mahmood Alawi's LinkedIn profile"
          >LinkedIn</a
        >, or read and comment on the source on
        <a
          class="oh__link"
          :href="GITHUB_URL"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="View the eQalb HTA source repository on GitHub"
          >GitHub</a
        >.
      </p>
    </section>

    <footer class="oh__footer">
      <a class="oh__link" :href="pagePath('openhealth')" @click="followLink($event, 'openhealth')">
        Home
      </a>
      <span class="oh__separator" aria-hidden="true">·</span>
      <a class="oh__link" :href="pagePath('home')" @click="followLink($event, 'home')">eQalb</a>
      <span class="oh__separator" aria-hidden="true">·</span>
      <a class="oh__link" :href="pagePath('about')" @click="followLink($event, 'about')">About</a>
      <span class="oh__separator" aria-hidden="true">·</span>
      <a
        class="oh__link"
        :href="LINKEDIN_URL"
        target="_blank"
        rel="noopener noreferrer"
        aria-label="Open Mahmood Alawi's LinkedIn profile"
        >LinkedIn</a
      >
      <span class="oh__separator" aria-hidden="true">·</span>
      <a
        class="oh__link"
        :href="GITHUB_URL"
        target="_blank"
        rel="noopener noreferrer"
        aria-label="View the eQalb HTA source repository on GitHub"
        >GitHub</a
      >
    </footer>
  </section>
</template>
