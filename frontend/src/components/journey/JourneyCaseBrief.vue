<script setup lang="ts">
/**
 * The journey's opening: the case as one illustrated scene.
 *
 * The scene answers four questions in the order a learner asks them, and each
 * answer is a picture before it is a sentence. A payer covers care for a
 * population. Those adults face one of two options, not both. The two options
 * begin with the same usual care; only one gains the eQalb app beside it. That
 * app carries a price. The pairing is then named once, under both columns.
 *
 * There are no cards inside the card: the step panel is the only surface, and
 * every border the earlier diagram drew around a node is gone. The two paths sit
 * side by side rather than stacked, because a stack reads as "first this, then
 * that" — the opposite of a choice between two alternatives — and that pairing
 * survives at a phone's width.
 *
 * Usual care is drawn as the person receiving it, not as a medicine: the case
 * does not say which treatment usual care is, so the drawing must not invent one.
 * The same mark, at the same size, opens both columns.
 *
 * Every label and every number is R's, including both money strings. The one
 * illustrative-data notice is not here: the journey shell prints it once above
 * the chapter, and the entrance animation lives entirely in the stylesheet behind
 * `prefers-reduced-motion: no-preference`, so the Start control and the
 * assumptions disclosure are usable from the first frame.
 */

import { computed } from 'vue'
import type { JourneyCase } from '../../api/types'

const props = defineProps<{ caseNode: JourneyCase }>()

defineEmits<{ start: [] }>()

/**
 * The two paths, read by id so the drawing cannot depend on the order R happens
 * to publish them in. Both are always present; `null` only keeps the template
 * honest about what it is given.
 */
const usual = computed(
  () => props.caseNode.option_labels.find((option) => option.id === 'usual_care') ?? null,
)
const intervention = computed(
  () => props.caseNode.option_labels.find((option) => option.id === 'eqalb') ?? null,
)
</script>

<template>
  <section class="tutorial__step" aria-labelledby="journey-chapter-title">
    <h3 id="journey-chapter-title" class="tutorial__step-title" tabindex="-1">
      {{ caseNode.title }}
    </h3>

    <p class="scene__intro">{{ caseNode.intro }}</p>

    <!-- The scene. Reading order is the order the eye travels: payer, population,
         the fork, the two paths, the pairing. -->
    <div class="scene">
      <div class="scene__context">
        <figure class="scene__payer">
          <svg
            class="scene__payer-art"
            viewBox="0 0 96 80"
            aria-hidden="true"
            focusable="false"
          >
            <path
              d="M8 30 48 10l40 20"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
            <path
              d="M14 34h68"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
            />
            <path
              d="M22 40v22M37 40v22M59 40v22M74 40v22"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
            />
            <path
              d="M12 66h72M8 72h80"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
            />
            <path
              d="M42 66V52a6 6 0 0 1 12 0v14"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
          <figcaption class="scene__caption">{{ caseNode.payer_label }}</figcaption>
        </figure>

        <div class="scene__flow">
          <span class="scene__flow-text">{{ caseNode.funds_label }}</span>
          <span class="scene__flow-rule" aria-hidden="true">
            <span class="scene__pulse"></span>
          </span>
        </div>

        <figure class="scene__population">
          <!-- Decoration, not a count and not a scale: the number of dots is
               arbitrary, and the label below carries the actual figure. -->
          <svg
            class="scene__population-art"
            viewBox="0 0 168 96"
            aria-hidden="true"
            focusable="false"
          >
            <circle cx="10" cy="11" r="2.4" fill="currentColor" opacity="0.3" />
            <circle cx="27" cy="11" r="1.8" fill="currentColor" opacity="0.48" />
            <circle cx="43" cy="11" r="2.8" fill="currentColor" opacity="0.22" />
            <circle cx="60" cy="11" r="2.1" fill="currentColor" opacity="0.38" />
            <circle cx="76" cy="11" r="1.6" fill="currentColor" opacity="0.54" />
            <circle cx="93" cy="11" r="2.5" fill="currentColor" opacity="0.27" />
            <circle cx="109" cy="11" r="2.4" fill="currentColor" opacity="0.3" />
            <circle cx="126" cy="11" r="1.8" fill="currentColor" opacity="0.48" />
            <circle cx="143" cy="11" r="2.8" fill="currentColor" opacity="0.22" />
            <circle cx="158" cy="11" r="2.1" fill="currentColor" opacity="0.38" />
            <circle cx="17" cy="26" r="1.6" fill="currentColor" opacity="0.54" />
            <circle cx="34" cy="26" r="2.5" fill="currentColor" opacity="0.27" />
            <circle cx="50" cy="26" r="2.4" fill="currentColor" opacity="0.3" />
            <circle cx="67" cy="26" r="1.8" fill="currentColor" opacity="0.48" />
            <circle cx="83" cy="26" r="2.8" fill="currentColor" opacity="0.22" />
            <circle cx="100" cy="26" r="2.1" fill="currentColor" opacity="0.38" />
            <circle cx="116" cy="26" r="1.6" fill="currentColor" opacity="0.54" />
            <circle cx="133" cy="26" r="2.5" fill="currentColor" opacity="0.27" />
            <circle cx="150" cy="26" r="2.4" fill="currentColor" opacity="0.3" />
            <circle cx="8" cy="41" r="1.8" fill="currentColor" opacity="0.48" />
            <circle cx="25" cy="41" r="2.8" fill="currentColor" opacity="0.22" />
            <circle cx="41" cy="41" r="2.1" fill="currentColor" opacity="0.38" />
            <circle cx="58" cy="41" r="1.6" fill="currentColor" opacity="0.54" />
            <circle cx="74" cy="41" r="2.5" fill="currentColor" opacity="0.27" />
            <circle cx="91" cy="41" r="2.4" fill="currentColor" opacity="0.3" />
            <circle cx="107" cy="41" r="1.8" fill="currentColor" opacity="0.48" />
            <circle cx="124" cy="41" r="2.8" fill="currentColor" opacity="0.22" />
            <circle cx="141" cy="41" r="2.1" fill="currentColor" opacity="0.38" />
            <circle cx="157" cy="41" r="1.6" fill="currentColor" opacity="0.54" />
            <circle cx="15" cy="56" r="2.5" fill="currentColor" opacity="0.27" />
            <circle cx="32" cy="56" r="2.4" fill="currentColor" opacity="0.3" />
            <circle cx="48" cy="56" r="1.8" fill="currentColor" opacity="0.48" />
            <circle cx="65" cy="56" r="2.8" fill="currentColor" opacity="0.22" />
            <circle cx="81" cy="56" r="2.1" fill="currentColor" opacity="0.38" />
            <circle cx="98" cy="56" r="1.6" fill="currentColor" opacity="0.54" />
            <circle cx="114" cy="56" r="2.5" fill="currentColor" opacity="0.27" />
            <circle cx="131" cy="56" r="2.4" fill="currentColor" opacity="0.3" />
            <circle cx="148" cy="56" r="1.8" fill="currentColor" opacity="0.48" />
            <circle cx="10" cy="71" r="2.8" fill="currentColor" opacity="0.22" />
            <circle cx="27" cy="71" r="2.1" fill="currentColor" opacity="0.38" />
            <circle cx="43" cy="71" r="1.6" fill="currentColor" opacity="0.54" />
            <circle cx="60" cy="71" r="2.5" fill="currentColor" opacity="0.27" />
            <circle cx="76" cy="71" r="2.4" fill="currentColor" opacity="0.3" />
            <circle cx="93" cy="71" r="1.8" fill="currentColor" opacity="0.48" />
            <circle cx="109" cy="71" r="2.8" fill="currentColor" opacity="0.22" />
            <circle cx="126" cy="71" r="2.1" fill="currentColor" opacity="0.38" />
            <circle cx="143" cy="71" r="1.6" fill="currentColor" opacity="0.54" />
            <circle cx="158" cy="71" r="2.5" fill="currentColor" opacity="0.27" />
            <circle cx="18" cy="86" r="2.4" fill="currentColor" opacity="0.3" />
            <circle cx="35" cy="86" r="1.8" fill="currentColor" opacity="0.48" />
            <circle cx="51" cy="86" r="2.8" fill="currentColor" opacity="0.22" />
            <circle cx="68" cy="86" r="2.1" fill="currentColor" opacity="0.38" />
            <circle cx="84" cy="86" r="1.6" fill="currentColor" opacity="0.54" />
            <circle cx="101" cy="86" r="2.5" fill="currentColor" opacity="0.27" />
            <circle cx="117" cy="86" r="2.4" fill="currentColor" opacity="0.3" />
            <circle cx="134" cy="86" r="1.8" fill="currentColor" opacity="0.48" />
            <circle cx="151" cy="86" r="2.8" fill="currentColor" opacity="0.22" />
          </svg>
          <figcaption class="scene__caption scene__caption--strong">
            {{ caseNode.population_label }}
          </figcaption>
        </figure>
      </div>

      <div class="scene__fork">
        <span class="scene__fork-stem" aria-hidden="true"></span>
        <span class="scene__fork-text">{{ caseNode.population_arrow_label }}</span>
        <span class="scene__fork-stem" aria-hidden="true"></span>
      </div>

      <div v-if="usual && intervention" class="scene__paths">
        <div class="scene__path">
          <div class="scene__art">
            <svg
              class="scene__usual"
              viewBox="0 0 48 52"
              aria-hidden="true"
              focusable="false"
            >
              <circle
                cx="24"
                cy="15"
                r="7.5"
                fill="none"
                stroke="currentColor"
                stroke-width="2.2"
              />
              <path
                d="M8.5 46c0-8.6 7-15.5 15.5-15.5S39.5 37.4 39.5 46"
                fill="none"
                stroke="currentColor"
                stroke-width="2.2"
                stroke-linecap="round"
              />
            </svg>
          </div>
          <p class="scene__option-label">{{ usual.label }}</p>
          <p class="scene__option-role">{{ usual.role }}</p>
        </div>

        <div class="scene__path scene__path--intervention">
          <div class="scene__art">
            <svg
              class="scene__usual"
              viewBox="0 0 48 52"
              aria-hidden="true"
              focusable="false"
            >
              <circle
                cx="24"
                cy="15"
                r="7.5"
                fill="none"
                stroke="currentColor"
                stroke-width="2.2"
              />
              <path
                d="M8.5 46c0-8.6 7-15.5 15.5-15.5S39.5 37.4 39.5 46"
                fill="none"
                stroke="currentColor"
                stroke-width="2.2"
                stroke-linecap="round"
              />
            </svg>
            <span class="scene__plus" aria-hidden="true">+</span>
            <svg
              class="scene__phone"
              viewBox="0 0 56 96"
              aria-hidden="true"
              focusable="false"
            >
              <rect
                x="7"
                y="4"
                width="42"
                height="88"
                rx="9"
                fill="none"
                stroke="currentColor"
                stroke-width="2.2"
              />
              <path
                d="M22 13h12"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              />
              <path
                d="M14 52h6l3.5-7 4 14 3.5-7h11"
                fill="none"
                stroke="currentColor"
                stroke-width="2.2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <circle cx="42" cy="52" r="2.4" fill="currentColor" />
              <path
                d="M24 85h8"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              />
            </svg>
          </div>
          <p class="scene__option-label">{{ intervention.label }}</p>
          <p class="scene__option-role">{{ intervention.role }}</p>
          <p class="scene__price">
            <span class="scene__price-lead">{{ caseNode.price_lead }}</span>
            <span class="scene__price-amount">{{ caseNode.price_amount }}</span>
            <span class="scene__price-unit">{{ caseNode.price_unit }}</span>
          </p>
        </div>
      </div>

      <div class="scene__compare">
        <span class="scene__compare-rule" aria-hidden="true"></span>
        <p class="scene__compare-text">{{ caseNode.comparison_label }}</p>
      </div>
    </div>

    <!-- The details a learner asks for after they understand the decision. -->
    <details class="details scene__assumptions">
      <summary>{{ caseNode.assumptions.title }}</summary>
      <p v-for="(line, index) in caseNode.assumptions.lines" :key="index">{{ line }}</p>
    </details>

    <button type="button" class="btn btn--primary" @click="$emit('start')">
      {{ caseNode.start_label }}
    </button>
  </section>
</template>
