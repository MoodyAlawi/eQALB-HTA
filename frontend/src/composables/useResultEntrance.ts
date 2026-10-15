/**
 * The one-shot entrance an analysis result plays when it is committed.
 *
 * A successful run bumps that analysis's revision in the model store (see
 * `resultRevisions` there). This turns that revision into the class the result
 * summary and the ECG trace under its panel heading animate with, and only for a
 * revision that has not been shown yet:
 *
 *  - a failed or cancelled run never bumps a revision, so nothing plays;
 *  - a second successful run plays again, even when its numbers are identical,
 *    because the revision is a count of runs rather than of different values;
 *  - a panel that is mounted again later — the learner leaving the tab and coming
 *    back — does not play, because that revision has already been shown. The
 *    memory of what has been shown lives in this module rather than in the panel,
 *    which is what makes it outlive that panel's unmount.
 *
 * Two identical animations exist because a CSS animation only restarts when its
 * name changes: the pair is alternated per run, so consecutive runs each animate
 * on the same element. The class is left in place between runs; setting the other
 * one is what replays the animation.
 *
 * Under `prefers-reduced-motion: reduce` the stylesheet removes every animation
 * (see styles.css), so the class is inert there: the summary and its heading are
 * simply shown, and no entrance is ever required for the content to be usable.
 */

import { ref, watch, type Ref } from 'vue'
import { useModel, type AnalysisKey } from './useModel'

/**
 * The revision each analysis last played its entrance for. Module scope on
 * purpose: a panel is unmounted whenever the learner leaves its tab, and this
 * memory has to survive that, or every return to the tab would replay the
 * entrance for a result that is not new.
 */
const shown = new Map<AnalysisKey, number>()

/** Whether the next entrance for each analysis uses the first or the second animation. */
const nextUsesFirst = new Map<AnalysisKey, boolean>()

export function useResultEntrance(analysis: AnalysisKey): { revealClass: Ref<string> } {
  const model = useModel()
  const revealClass = ref('')

  watch(
    () => model.resultRevisions[analysis],
    (revision) => {
      if (shown.get(analysis) === revision) return
      shown.set(analysis, revision)
      // Revision 0 is "nothing has been run yet", which is the state every panel
      // mounts in: there is no result to reveal, so no class is set.
      if (revision === 0) return
      const first = nextUsesFirst.get(analysis) ?? true
      nextUsesFirst.set(analysis, !first)
      revealClass.value = first ? 'is-entering-a' : 'is-entering-b'
    },
    { immediate: true },
  )

  return { revealClass }
}
