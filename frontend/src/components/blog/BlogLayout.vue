<script setup lang="ts">
/**
 * The blog's shell: the header and footer the index and every post share.
 *
 * It owns the blog's theme for the same reason the landing page owns its own.
 * `useLandingTheme` publishes the choice as `<html data-landing-theme>` while it
 * is mounted and removes the attribute when it unmounts, so the blog reads the
 * landing page's palette, typography and stored preference and never touches the
 * application's `eqalb.theme`. The attribute is set once while a page is
 * mounted, so exactly one component may call the composable at a time - which is
 * why the header lives here rather than in each of the two views. `index.html`
 * sets the same attribute before the first paint on these addresses, so a direct
 * load of /blog or of a post does not flash the other theme.
 *
 * Navigation is deliberately small: the wordmark returns to the landing page -
 * at its top, because the landing page keeps whatever position it is left in, so
 * a followed link asks for the top itself - "Blog" is the index, and the
 * light/dark control is the same one the landing page carries, over the same
 * preference. Both links are real hrefs handed to the view store, so a modified
 * or middle click opens a new tab and the address always names the page on
 * screen.
 */

import { onMounted } from 'vue'
import {
  cameFromHistory,
  followLandingLink,
  followLink,
  pagePath,
  useAppView,
} from '../../composables/useAppView'
import { useLandingTheme } from '../../composables/useLandingTheme'

const { page, postSlug } = useAppView()
const { isDark, toggle } = useLandingTheme()

/**
 * A screen reached by following a link starts at its top: the address changes
 * inside one document, so the browser does not move the reader there itself, and
 * a position carried over from a longer page would open the new one part-read.
 *
 * A page reached by Back or Forward is left where it is, because there the
 * browser restores the reading position its own history entry recorded and
 * scrolling here would throw that away.
 *
 * The jump is explicitly instant rather than a smooth scroll: a page should
 * arrive where it starts, whatever `scroll-behavior` the landing palette sets on
 * the document.
 *
 * That reset covers the blog's own pages. The landing page has none of its own,
 * so the wordmark that leaves the blog for it asks the view store for the same
 * thing at the link instead (see `followLandingLink`).
 */
onMounted(() => {
  if (cameFromHistory()) return
  window.scrollTo({ top: 0, left: 0, behavior: 'instant' })
})
</script>

<template>
  <div class="blog">
    <header class="blog__header">
      <nav class="blog__nav" aria-label="Blog navigation">
        <a
          class="blog__mark"
          :href="pagePath('openhealth')"
          @click="followLandingLink($event)"
          >OpenHealth</a
        >
        <ul class="blog__nav-links">
          <li>
            <a
              class="blog__nav-link"
              :href="pagePath('blog')"
              :aria-current="page === 'blog' && !postSlug ? 'page' : undefined"
              @click="followLink($event, 'blog')"
              >Blog</a
            >
          </li>
        </ul>
      </nav>

      <button
        type="button"
        class="blog__theme"
        :title="
          isDark ? 'Switch this page to the light theme' : 'Switch this page to the dark theme'
        "
        aria-label="Dark theme"
        :aria-pressed="isDark"
        @click="toggle()"
      >
        <span aria-hidden="true">{{ isDark ? '☀' : '☾' }}</span>
      </button>
    </header>

    <main class="blog__main">
      <slot />
    </main>

    <footer class="blog__footer">
      <p class="blog__footer-note">OpenHealth — a personal learning project.</p>
    </footer>
  </div>
</template>
