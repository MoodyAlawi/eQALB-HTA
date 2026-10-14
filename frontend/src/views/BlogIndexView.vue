<script setup lang="ts">
/**
 * The blog's front page, shown at "/blog": every published post, newest first,
 * as text with a quiet rule between the entries - no cards, no thumbnails, no
 * boxed dates.
 *
 * It is presentation only. The list comes from the content directory, and this
 * view neither resolves a post nor renders one: a post's address is opened by
 * the post's own view. The heading takes focus on arrival, as the About page's
 * does, so a keyboard or screen-reader user is placed on the page they asked
 * for; the shell around it owns the theme and the reading position.
 */

import { onMounted, ref } from 'vue'
import BlogLayout from '../components/blog/BlogLayout.vue'
import { formatPostDate } from '../components/blog/date'
import { blogPostPath, followPostLink } from '../composables/useAppView'
import { publishedPosts } from '../content/blog/posts'

const posts = publishedPosts()
const heading = ref<HTMLHeadingElement | null>(null)

/**
 * True on the dev server only. The note it guards is written for whoever is
 * writing a post and never ships: `import.meta.env.DEV` is replaced at build
 * time, so the production bundle contains neither the note nor the sentence.
 */
const isDev = import.meta.env.DEV

onMounted(() => heading.value?.focus({ preventScroll: true }))
</script>

<template>
  <BlogLayout>
    <div class="blog__inner">
      <h1 id="blog-title" ref="heading" class="blog__title" tabindex="-1">Blog</h1>

      <ul v-if="posts.length" class="blog__posts" aria-labelledby="blog-title">
        <li v-for="post in posts" :key="post.slug" class="blog__post">
          <h2 class="blog__post-title">
            <a
              class="blog__post-link"
              :href="blogPostPath(post.slug)"
              @click="followPostLink($event, post.slug)"
              >{{ post.title }}</a
            >
          </h2>
          <p class="blog__post-date">
            <time :datetime="post.date">{{ formatPostDate(post.date) }}</time>
          </p>
          <p v-if="post.summary" class="blog__post-summary">{{ post.summary }}</p>
        </li>
      </ul>

      <template v-else>
        <p class="blog__empty">
          Nothing has been published here yet. Posts will appear on this page, newest first, as
          they are added.
        </p>
        <p v-if="isDev" class="blog__note">
          Dev note — the content directory is empty. To write the first post, see
          <code>src/content/blog/README.md</code>.
        </p>
      </template>
    </div>
  </BlogLayout>
</template>
