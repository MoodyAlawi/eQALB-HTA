<script setup lang="ts">
/**
 * The tutorial completion card.
 *
 * Its heading, its paragraph and its two button labels are R's, and the card
 * offers exactly the routes the contract defines: open the full analysis, or
 * restart the tutorial from R's own defaults. Restarting is the tutorial's own
 * reset — it restores R's defaults and returns to Step 1 — and it never touches
 * the analysis session.
 *
 * The optional Part 2 entry is the one integration point with the commissioning
 * exercise. Its label and its sentence come from the Part 2 contract, so Part 1's
 * own response is unchanged, and entering Part 2 leaves every Part 1 value and
 * result exactly as it was.
 */

import type { Part2Contract, TutorialContract } from '../../api/types'

const props = withDefaults(
  defineProps<{
    completion: TutorialContract['completion']
    /** Present once the Part 2 contract has loaded; absent hides the entry. */
    part2?: Part2Contract | null
    part2Busy?: boolean
  }>(),
  { part2: null, part2Busy: false },
)

const emit = defineEmits<{ openFull: []; restart: []; startPart2: [] }>()

const showPart2 = () => props.part2 !== null
</script>

<template>
  <section class="tutorial__step tutorial__complete" aria-labelledby="tutorial-complete-title">
    <h3 id="tutorial-complete-title" class="tutorial__step-title" tabindex="-1">
      {{ completion.title }}
    </h3>
    <p class="tutorial__intro">{{ completion.body }}</p>
    <div class="tutorial__nav">
      <button type="button" class="btn btn--primary" @click="emit('openFull')">
        {{ completion.open_full_label }}
      </button>
      <button type="button" class="btn btn--ghost" @click="emit('restart')">
        {{ completion.restart_label }}
      </button>
    </div>

    <template v-if="showPart2 && part2">
      <hr />
      <p class="tutorial__intro">{{ part2.entry_note }}</p>
      <div class="tutorial__nav">
        <button
          type="button"
          class="btn btn--success"
          :disabled="part2Busy"
          @click="emit('startPart2')"
        >
          {{ part2Busy ? part2.entry_busy_label : part2.entry_label }}
        </button>
      </div>
    </template>
  </section>
</template>
