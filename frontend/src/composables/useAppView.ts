/**
 * Which page the shell is showing: the public OpenHealth pages, or an eQalb
 * screen (eQalb's own Home screen and its subviews, or the analysis dashboard).
 *
 * This is deliberately a single shared ref rather than a router: the project has
 * no routing dependency, and the browser's History API covers the three public
 * URLs this shell publishes. Nothing here touches model state, so switching
 * pages never changes an input or a result.
 *
 * Addresses:
 *   /       the OpenHealth landing page - one scrolling page whose three
 *           panels (eQalb, OpenHealth, About me) are reached through its own
 *           navigation; the landing page carries its own theme, separate from
 *           the app's (see useLandingTheme.ts)
 *   /app    eQalb - its own Home screen, the tutorial, the project description,
 *           the download view and the analysis dashboard all live here, so one
 *           Back or Forward step moves between the public pages instead of
 *           unwinding a dashboard session screen by screen
 *   /about  About OpenHealth
 *
 * The pathname is resolved once on load, so a direct load of any of the three
 * opens that page; an address that is not one of them opens the landing page and
 * is rewritten to "/" so the URL matches what is on screen. The document title is
 * kept with the page, so a tab or a bookmark names where it points.
 */

import { ref } from 'vue'
import { installDisclosureEscape } from './useDisclosure'

export type AppPage =
  | 'openhealth'
  | 'about'
  | 'home'
  | 'tutorial'
  | 'description'
  | 'export'
  | 'dashboard'

const LANDING_PATH = '/'
const APP_PATH = '/app'
const ABOUT_PATH = '/about'

/** Every eQalb screen shares /app; only the public pages have an address of their own. */
const PAGE_PATHS: Record<AppPage, string> = {
  openhealth: LANDING_PATH,
  about: ABOUT_PATH,
  home: APP_PATH,
  tutorial: APP_PATH,
  description: APP_PATH,
  export: APP_PATH,
  dashboard: APP_PATH,
}

const PAGE_TITLES: Record<string, string> = {
  [LANDING_PATH]: 'eQalb — an interactive introduction to health-economic modelling',
  [APP_PATH]: 'eQalb — illustrative HTA model',
  [ABOUT_PATH]: 'About OpenHealth',
}

const PUBLIC_PATHS = [LANDING_PATH, APP_PATH, ABOUT_PATH]

/** The address a page is shown at, for the links that point at it. */
export function pagePath(next: AppPage): string {
  return PAGE_PATHS[next]
}

/** A trailing slash is the same address, so "/app/" is the application, not a miss. */
function normalise(pathname: string): string {
  if (pathname.length <= 1) return pathname
  return pathname.replace(/\/+$/, '') || LANDING_PATH
}

function pageForPath(pathname: string): AppPage {
  const path = normalise(pathname)
  if (path === ABOUT_PATH) return 'about'
  if (path === APP_PATH) return 'home'
  return 'openhealth'
}

const page = ref<AppPage>(
  typeof window === 'undefined' ? 'openhealth' : pageForPath(window.location.pathname),
)

function setTitle(path: string): void {
  if (typeof document === 'undefined') return
  const title = PAGE_TITLES[path]
  if (title) document.title = title
}

/**
 * Writes the address for a page and keeps the title with it. Moves inside eQalb
 * share /app, so they change nothing here: the single eQalb history entry the
 * visitor arrived through is the one Back leaves eQalb by.
 */
function syncAddress(next: AppPage): void {
  if (typeof window === 'undefined') return
  const path = PAGE_PATHS[next]
  setTitle(path)
  if (normalise(window.location.pathname) === path) return
  window.history.pushState({ page: next }, '', path)
}

let installed = false

/** Installs the history listener once per document, so repeated calls are harmless. */
function installHistory(): void {
  if (installed || typeof window === 'undefined') return
  installed = true

  // An unrecognised address has no page of its own: the landing page is shown,
  // and the address is rewritten so it names the page that is actually there.
  if (!PUBLIC_PATHS.includes(normalise(window.location.pathname))) {
    window.history.replaceState({ page: 'openhealth' }, '', LANDING_PATH)
  }
  setTitle(PAGE_PATHS[page.value])

  window.addEventListener('popstate', () => {
    const path = normalise(window.location.pathname)
    page.value = pageForPath(path)
    setTitle(path)
  })
}

function show(next: AppPage): void {
  page.value = next
  syncAddress(next)
}

/**
 * Anchor behaviour for a public link. A plain left click goes through the store,
 * so the page changes in place, while modified and middle clicks (new tab, new
 * window, "copy link address") are left to the browser - which is why the links
 * carry a real href instead of being buttons.
 */
export function followLink(event: MouseEvent, next: AppPage): void {
  if (event.defaultPrevented || event.button !== 0) return
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
  event.preventDefault()
  show(next)
}

export function useAppView() {
  // Every screen calls this composable, so it is where the app-wide disclosure
  // keyboard behaviour and the history listener are installed (see
  // useDisclosure.ts for why).
  installDisclosureEscape()
  installHistory()

  return {
    page,
    show,
    goHome(): void {
      show('home')
    },
  }
}
