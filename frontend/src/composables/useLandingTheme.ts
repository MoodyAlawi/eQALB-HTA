/**
 * The landing page's own light/dark theme, and the blog's.
 *
 * The eQalb application already owns a light/dark preference: `useTheme()` keeps
 * it in `eqalb.theme`, publishes it as `<html data-theme>` and every app token,
 * chart palette and control reads it. The landing page - and the blog, which is
 * a second page of the same public surface - has to be able to switch without
 * disturbing any of that, so this composable is deliberately not a second caller
 * of `useTheme()`: it stores the landing choice under its own key and publishes
 * it as a separate `<html data-landing-theme>` attribute, which only
 * `landing.css` and `blog.css` key on. Neither `eqalb.theme` nor `data-theme` is
 * read or written here, so whatever a visitor chooses on the landing page or in
 * the blog, the application keeps the theme it had.
 *
 * The attribute is set while a landing-themed page is mounted and removed when
 * the last one unmounts, so no landing or blog rule can outlive those pages and
 * reach the app. For the landing addresses only, `index.html` sets the same
 * attribute from the same stored key before the first paint, so a stored landing
 * theme does not flash the other one while the application starts.
 *
 * Following the app's own convention, the default is the stored choice, then the
 * system preference, then light - and the choice is remembered across visits.
 * The landing page and the blog therefore share one preference, which is what
 * makes a theme chosen in one of them the theme of the other.
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

/**
 * How many landing-themed pages are mounted right now.
 *
 * The landing page and the blog both read this theme, and one replaces the other
 * inside a single render - where the arriving page's setup runs before the
 * departing page's unmounted hook, because Vue defers that hook to the end of
 * the flush. Removing the attribute from every departing page would therefore
 * take it off the page that has just arrived and leave it in the application's
 * palette. Counting instead means the attribute goes when the last of them goes,
 * which is also exactly what keeps it off every eQalb screen.
 */
let mountedPages = 0

export function useLandingTheme() {
  mountedPages += 1

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
    mountedPages -= 1
    // The page is gone, but another landing-themed page may already be mounted
    // in its place: then the theme stays, and it is the arriving page's own call
    // that has just written it.
    if (mountedPages > 0) return
    // The last one is gone, so its palette and its page-level rules go with it:
    // the shell behind it is the application, which has its own theme.
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
