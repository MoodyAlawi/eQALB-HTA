/**
 * One resolver for the "How this is calculated" notes.
 *
 * The notes are R's (`MODULE_METHOD_NOTES` in eqalb_ui_copy.R) and are published
 * twice: with /api/defaults for the analysis app, and with the journey contract
 * for the Guided tutorial's chapters. Both are the same dictionary, so a module
 * and its chapter cannot describe a method differently.
 *
 * A caller asks by module id and gets whatever the loaded contract carries. A
 * module the running stack publishes nothing for resolves to null, and the
 * control is not rendered at all: a guessed note would be worse than no note.
 */

import { computed } from 'vue'
import type { ModuleMethodNote } from '../api/types'
import { useModel } from './useModel'
import { useTutorialJourney } from './useTutorialJourney'

/**
 * The module note for one id, from whichever contract is loaded.
 *
 * The analysis app's own dictionary is preferred because that is where the
 * modules live; the journey's copy is the fallback, which is what makes the
 * control work in a standalone explainer opened by a direct link that never
 * loaded /api/defaults.
 */
export function useMethodNote(moduleId: () => string) {
  const model = useModel()
  const journey = useTutorialJourney()

  return computed<ModuleMethodNote | null>(() => {
    const id = moduleId()
    const fromDefaults = model.defaults?.module_methods?.[id]
    if (fromDefaults) return fromDefaults
    return journey.contract.value?.journey.methods?.[id] ?? null
  })
}
