/**
 * The landing page's own light/dark theme.
 *
 * The eQalb application already owns a light/dark preference: `useTheme()` keeps
 * it in `eqalb.theme`, publishes it as `<html data-theme>` and every app token,
 * chart palette and control reads it. The landing page has to be able to switch
 * without disturbing any of that, so this composable is deliberately not a second
 * caller of `useTheme()`: it stores the landing choice under its own key and
 * publishes it as a separate `<html data-landing-theme>` attribute, which only
 * `landing.css` keys on. Neither `eqalb.theme` nor `data-theme` is read or
 * written here, so whatever a visitor chooses on the landing page, the
 * application keeps the theme it had.
 *
 * The attribute is set while the landing page is mounted and removed when it
 * unmounts, so no landing rule can outlive the page and reach the app. For the
 * landing addresses only, `index.html` sets the same attribute from the same
 * stored key before the first paint, so a stored landing theme does not flash the
 * other one while the application starts.
 *
 * Following the app's own convention, the default is the stored choice, then the
 * system preference, then light - and the choice is remembered across visits.
 */

import { computed, onUnmounted, ref, watchEffect } from 'vue'

export type LandingTheme = 'light' | 'dark'

const STORAGE_KEY = 'openhealth.landing.theme'
const ATTRIBUTE = 'data-landing-theme'

function storedTheme(): LandingTheme | null {
  try {
    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored === 'light' || stored === 'dark') return stored
  } catch {
    // A browser that refuses storage simply has no remembered choice.
  }
  return null
}

function initialTheme(): LandingTheme {
  const stored = storedTheme()
  if (stored) return stored
  if (typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches) {
    return 'dark'
  }
  return 'light'
}

const theme = ref<LandingTheme>(initialTheme())

export function useLandingTheme() {
  watchEffect(() => {
    if (typeof document === 'undefined') return
    document.documentElement.setAttribute(ATTRIBUTE, theme.value)
    try {
      localStorage.setItem(STORAGE_KEY, theme.value)
    } catch {
      /* the preference is best-effort; the current visit still switches */
    }
  })

  onUnmounted(() => {
    // The page is gone, so its palette and its page-level rules go with it: the
    // shell behind this page is the application, which has its own theme.
    if (typeof document === 'undefined') return
    document.documentElement.removeAttribute(ATTRIBUTE)
  })

  return {
    theme,
    isDark: computed(() => theme.value === 'dark'),
    toggle(): void {
      theme.value = theme.value === 'dark' ? 'light' : 'dark'
    },
  }
}
