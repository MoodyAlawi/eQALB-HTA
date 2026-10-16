/**
 * Which page the shell is showing: the public OpenHealth pages, or an eQalb
 * screen (eQalb's own Home screen and its subviews, or the analysis dashboard).
 *
 * This is deliberately a single shared ref rather than a router: the project has
 * no routing dependency, and the browser's History API covers the public URLs
 * this shell publishes. Nothing here touches model state, so switching pages
 * never changes an input or a result.
 *
 * Addresses:
 *   /             the OpenHealth landing page - one scrolling page whose three
 *                 panels (eQalb, OpenHealth, About me) are reached through its
 *                 own navigation; the landing page carries its own theme,
 *                 separate from the app's (see useLandingTheme.ts)
 *   /blog         the OpenHealth blog - its posts, newest first
 *   /blog/<slug>  one post, at an address of its own. The slug is carried here
 *                 in `postSlug` and resolved against the content directory by
 *                 the view, so this store never reads a post - and an address
 *                 naming no post is still a blog address: the view answers it
 *                 with a readable not-found state rather than a redirect
 *   /app          eQalb - its own Home screen, the tutorial, the project
 *                 description, the download view and the analysis dashboard all
 *                 live here, so one Back or Forward step moves between the
 *                 public pages instead of unwinding a dashboard session screen
 *                 by screen
 *   /about        About OpenHealth
 *
 * The pathname is resolved once on load, so a direct load of any of those opens
 * that page; an address that is none of them opens the landing page and is
 * rewritten to "/" so the URL matches what is on screen. The document title is
 * kept with the page, so a tab or a bookmark names where it points - except on a
 * post address, whose title belongs to the post and is written by the post's own
 * view, because this store reads no content.
 */

import { ref } from 'vue'
import { installDisclosureEscape } from './useDisclosure'

export type AppPage =
  | 'openhealth'
  | 'about'
  | 'blog'
  | 'home'
  | 'tutorial'
  | 'description'
  | 'export'
  | 'dashboard'

const LANDING_PATH = '/'
const APP_PATH = '/app'
const ABOUT_PATH = '/about'
const BLOG_PATH = '/blog'

/** Every eQalb screen shares /app; only the public pages have an address of their own. */
const PAGE_PATHS: Record<AppPage, string> = {
  openhealth: LANDING_PATH,
  about: ABOUT_PATH,
  blog: BLOG_PATH,
  home: APP_PATH,
  tutorial: APP_PATH,
  description: APP_PATH,
  export: APP_PATH,
  dashboard: APP_PATH,
}

/**
 * The browser-tab title for each address. The landing page and the eQalb
 * application share the OpenHealth title, so the tab reads the same everywhere a
 * visitor moves inside the product; the two public pages that are their own
 * documents — About and the blog index — keep titles that name them, and an open
 * blog post is titled by the post (see BlogPostView).
 */
const PAGE_TITLES: Record<string, string> = {
  [LANDING_PATH]: 'OpenHealth',
  [APP_PATH]: 'OpenHealth',
  [ABOUT_PATH]: 'About OpenHealth',
  [BLOG_PATH]: 'Blog — OpenHealth',
}

/** The static addresses of the public pages. The blog's post addresses are matched separately. */
const PUBLIC_PATHS = [LANDING_PATH, APP_PATH, ABOUT_PATH]

/** The address a page is shown at, for the links that point at it. */
export function pagePath(next: AppPage): string {
  return PAGE_PATHS[next]
}

/** The address of one post, for the links that point at it. */
export function blogPostPath(slug: string): string {
  return `${BLOG_PATH}/${encodeURIComponent(slug)}`
}

/** A trailing slash is the same address, so "/app/" is the application, not a miss. */
function normalise(pathname: string): string {
  if (pathname.length <= 1) return pathname
  return pathname.replace(/\/+$/, '') || LANDING_PATH
}

/** Whether a normalised path is the blog or a post under it. */
function isBlogPath(path: string): boolean {
  return path === BLOG_PATH || path.startsWith(`${BLOG_PATH}/`)
}

/** Whether a normalised path is one the shell publishes rather than a miss. */
function isPublishedPath(path: string): boolean {
  return PUBLIC_PATHS.includes(path) || isBlogPath(path)
}

function pageForPath(pathname: string): AppPage {
  const path = normalise(pathname)
  if (path === ABOUT_PATH) return 'about'
  if (isBlogPath(path)) return 'blog'
  if (path === APP_PATH) return 'home'
  return 'openhealth'
}

/**
 * The slug in a "/blog/<slug>" address, and null for the blog index and for
 * every address that is not a post. The slug is decoded once here; an escape
 * sequence that cannot be decoded is kept as it stands, because the view turns
 * any slug that names no post into a readable not-found state either way.
 */
function postSlugForPath(pathname: string): string | null {
  const path = normalise(pathname)
  if (!isBlogPath(path) || path === BLOG_PATH) return null
  const slug = path.slice(BLOG_PATH.length + 1)
  if (!slug) return null
  try {
    return decodeURIComponent(slug)
  } catch {
    return slug
  }
}

const initialPath =
  typeof window === 'undefined' ? LANDING_PATH : normalise(window.location.pathname)

const page = ref<AppPage>(typeof window === 'undefined' ? 'openhealth' : pageForPath(initialPath))

/** The post the blog is showing, or null while the blog index is showing. */
const postSlug = ref<string | null>(typeof window === 'undefined' ? null : postSlugForPath(initialPath))

/**
 * Whether the page on screen was reached by Back or Forward rather than by
 * following a link. The blog's shell reads it when it mounts to decide whether
 * to start at the top of the page: a followed link is a new screen and starts at
 * the top, while an entry the browser moved back to keeps the reading position
 * the browser restores. Nothing else reads it.
 */
let restoredByHistory = false

export function cameFromHistory(): boolean {
  return restoredByHistory
}

function setTitle(path: string): void {
  if (typeof document === 'undefined') return
  const title = PAGE_TITLES[path]
  if (title) document.title = title
}

/**
 * The address a page is written to. The blog is the one page whose address
 * depends on more than the page itself: an open post keeps its own
 * "/blog/<slug>" address, and everything else is the index at "/blog".
 */
function addressFor(next: AppPage): string {
  if (next === 'blog' && postSlug.value) return blogPostPath(postSlug.value)
  return PAGE_PATHS[next]
}

/**
 * Writes the address for a page and keeps the title with it. Moves inside eQalb
 * share /app, so they change nothing here: the single eQalb history entry the
 * visitor arrived through is the one Back leaves eQalb by.
 */
function syncAddress(next: AppPage): void {
  restoredByHistory = false
  if (typeof window === 'undefined') return
  const path = addressFor(next)
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
  if (!isPublishedPath(normalise(window.location.pathname))) {
    window.history.replaceState({ page: 'openhealth' }, '', LANDING_PATH)
  }
  setTitle(normalise(window.location.pathname))

  window.addEventListener('popstate', () => {
    const path = normalise(window.location.pathname)
    restoredByHistory = true
    postSlug.value = postSlugForPath(path)
    page.value = pageForPath(path)
    setTitle(path)
  })
}

function show(next: AppPage): void {
  // The blog index and every eQalb screen are addressed without more state than
  // the page itself, so moving to one of them closes whatever post was open.
  // Only `showPost` carries a slug into the address.
  postSlug.value = null
  page.value = next
  syncAddress(next)
}

/**
 * Opens one post at its own address, "/blog/<slug>". The slug is not resolved
 * here - the store reads no content - so an address naming no post is opened the
 * same way and the view answers it with its not-found state.
 */
function showPost(slug: string): void {
  postSlug.value = slug
  page.value = 'blog'
  syncAddress('blog')
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

/**
 * Anchor behaviour for a post link, the same way `followLink` handles a public
 * page. A followed post starts at the top: the address changes inside one
 * document, so the browser does not move the reader there itself, and the
 * position they had in the list is not the position the article is read from.
 */
export function followPostLink(event: MouseEvent, slug: string): void {
  if (event.defaultPrevented || event.button !== 0) return
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
  event.preventDefault()
  showPost(slug)
  if (typeof window === 'undefined') return
  window.scrollTo({ top: 0, left: 0, behavior: 'instant' })
}

/**
 * Anchor behaviour for an explicit link to the landing page from another public
 * page, which today is the blog's wordmark. Following it is a new screen, so the
 * landing page is read from its top: the landing page has no scroll reset of its
 * own - its usual arrival is a fresh document load, which starts at the top by
 * itself - so without this the reader would land part-way down a page they have
 * just asked for.
 *
 * Only a followed link goes through here. Back and Forward never do: the browser
 * restores the position its own history entry recorded, and the store's popstate
 * listener is what answers them. Landing-page section links ("eQalb", "Back to
 * top") are anchors inside that page and stay the page's own business.
 *
 * The scroll is written in the same turn as the address, exactly as
 * `followPostLink` writes its own, and that is deliberate: the landing page is
 * taller than anything the blog shows, so the position the reader arrives at is
 * already the top and the page that replaces the blog keeps it. Deferring the
 * scroll past the turn instead let the browser record the leaving page's own
 * position as the top, so Back from the landing page returned to the blog at its
 * beginning rather than where the reader had been.
 */
export function followLandingLink(event: MouseEvent): void {
  if (event.defaultPrevented || event.button !== 0) return
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
  event.preventDefault()
  show('openhealth')
  if (typeof window === 'undefined') return
  window.scrollTo({ top: 0, left: 0, behavior: 'instant' })
}

export function useAppView() {
  // Every screen calls this composable, so it is where the app-wide disclosure
  // keyboard behaviour and the history listener are installed (see
  // useDisclosure.ts for why).
  installDisclosureEscape()
  installHistory()

  return {
    page,
    postSlug,
    show,
    showPost,
    goHome(): void {
      show('home')
    },
  }
}
