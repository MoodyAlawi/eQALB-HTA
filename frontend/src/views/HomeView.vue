<script setup lang="ts">
/**
 * Home screen: the first thing the app shows.
 *
 * It is presentation only. The three actions switch the shell between this
 * screen, the project description, the download view and the analysis
 * dashboard; no input, result or API call is involved, so arriving here or
 * leaving again never disturbs a run.
 *
 * The layout is deliberately minimal: a title composition, the credit line and
 * subtitle, the primary analysis action and its two secondary destinations, and
 * the creator links. The light/dark control is a small icon button in the
 * top-right corner.
 *
 * The title is the wordmark flanked by two decorative ECG segments, so the trace
 * enters from the left, the wordmark interrupts it, and it continues to the
 * right: the beats fall before and after the name rather than behind it. The
 * wordmark itself is part of the same signal: each character is a span that the
 * pulse energises in turn, so a travelling wave of light crosses the name and
 * leaves it in the subdued resting tint again as the trailing trace begins. Only
 * CSS drives that, and the letters are aria-hidden with the accessible name on
 * the heading, so assistive technology hears "eQalb" once. With
 * prefers-reduced-motion the trace is drawn complete and every letter shows the
 * full title colour.
 *
 * The heading is deliberately not focusable: it is a title, not a control, and
 * programmatically focusing it on load painted a focus ring around the wordmark.
 * The focus outlines other views give their own headings are unchanged.
 *
 * The project-level simulated-data disclaimer deliberately lives in the Project
 * description view only, not here.
 */

import { useAppView } from '../composables/useAppView'
import { useTheme } from '../composables/useTheme'

const { show } = useAppView()
const { theme, toggle } = useTheme()

/**
 * The wordmark's characters, one span each. The spans carry no accessible text
 * (they are aria-hidden and the heading names itself), and their stagger is set
 * in CSS from their position, so they exist only to let the signal light the
 * letters in sequence.
 */
const LETTERS = ['e', 'Q', 'a', 'l', 'b']

/**
 * The two trace segments that flank the wordmark, in a shared 200 x 100 box with
 * the baseline at y = 64. Both carry the same morphology — a soft P bump, the
 * QRS beat, then a soft T bump — so the two halves read as one trace. The left
 * one leads in from its outer edge and beats just before the name; the right one
 * beats just after it and trails away. Each segment draws a still track and a
 * travelling pulse over the same path.
 */
const TRACE_LEAD = 'M0 64 H70 Q80 48 90 64 L96 74 L106 30 L120 88 L132 64 H146 Q158 38 170 64 H200'
const TRACE_TRAIL = 'M0 64 H20 Q30 48 40 64 L46 74 L56 30 L70 88 L82 64 H96 Q108 38 120 64 H200'
</script>

<template>
  <section class="home" aria-labelledby="home-title">
    <div class="home__topbar">
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

    <div class="home__hero">
      <div class="home__title">
        <svg
          class="home__trace home__trace--lead"
          viewBox="0 0 200 100"
          preserveAspectRatio="none"
          aria-hidden="true"
          focusable="false"
        >
          <path class="home__trace-track" :d="TRACE_LEAD" />
          <path class="home__trace-pulse" :d="TRACE_LEAD" pathLength="100" />
        </svg>

        <h1
          id="home-title"
          class="home__wordmark"
          aria-label="eQalb"
        ><span
          v-for="letter in LETTERS"
          :key="letter"
          class="home__letter"
          aria-hidden="true"
        >{{ letter }}</span></h1>

        <svg
          class="home__trace home__trace--trail"
          viewBox="0 0 200 100"
          preserveAspectRatio="none"
          aria-hidden="true"
          focusable="false"
        >
          <path class="home__trace-track" :d="TRACE_TRAIL" />
          <path class="home__trace-pulse" :d="TRACE_TRAIL" pathLength="100" />
        </svg>
      </div>

      <p class="home__credit">By Mahmood Alawi</p>
      <p class="home__subtitle">An educational HTA model</p>

      <div class="home__actions">
        <button type="button" class="btn btn--primary btn--lg" @click="show('dashboard')">
          Start analysis
        </button>
        <button type="button" class="btn btn--ghost" @click="show('tutorial')">
          Guided tutorial
        </button>
        <button type="button" class="btn btn--ghost" @click="show('description')">
          Project description
        </button>
        <button type="button" class="btn btn--ghost" @click="show('export')">
          Download results
        </button>
      </div>

      <p class="home__links">
        <a
          class="home__link"
          href="https://www.linkedin.com/in/mahmoodalawi"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Open Mahmood Alawi's LinkedIn profile"
        >
          LinkedIn
        </a>
        <span class="home__separator" aria-hidden="true">·</span>
        <a
          class="home__link"
          href="https://github.com/MoodyAlawi/eQALB-HTA"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="View the eQalb HTA source repository on GitHub"
        >
          View source on GitHub
        </a>
      </p>
    </div>
  </section>
</template>
