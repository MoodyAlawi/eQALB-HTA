<script setup lang="ts">
/**
 * One post, shown at "/blog/<slug>", in a narrow reading column: a link back to
 * all posts, the title with its date, then the body as it was written -
 * paragraphs, headings, lists, and the occasional quote.
 *
 * The slug comes from the view store rather than from a route parameter, and it
 * is resolved against the content directory here. A slug that names no post is
 * not redirected away: the reader is answered at the address they asked for,
 * with a heading that says so and a way back to the index.
 *
 * The document title is written here rather than in the store, because the store
 * reads no content: the index's title belongs to the store, a post's belongs to
 * the post.
 */

import { computed, onMounted, ref, watchEffect } from 'vue'
import BlogLayout from '../components/blog/BlogLayout.vue'
import { formatPostDate } from '../components/blog/date'
import { followLink, pagePath, useAppView } from '../composables/useAppView'
import { findPost } from '../content/blog/posts'

const { postSlug } = useAppView()

const post = computed(() => (postSlug.value === null ? null : findPost(postSlug.value)))

const heading = ref<HTMLHeadingElement | null>(null)

onMounted(() => heading.value?.focus({ preventScroll: true }))

/**
 * The title of the page the reader is on. When the blog index is showing, the
 * store has already written the index's title and this effect leaves it alone -
 * without that, a Back to the index would overwrite it on the way out, because
 * an effect runs before the component it belongs to is unmounted.
 */
watchEffect(() => {
  const slug = postSlug.value
  if (slug === null || typeof document === 'undefined') return
  const found = findPost(slug)
  document.title = found ? `${found.title} — OpenHealth` : 'Post not found — OpenHealth'
})

/** External links open in a new tab; every other link is one of the site's own addresses. */
function isExternal(href: string): boolean {
  return /^https?:\/\//i.test(href)
}
</script>

<template>
  <BlogLayout>
    <div class="blog__inner blog__inner--article">
      <template v-if="post">
        <p class="blog__back">
          <a :href="pagePath('blog')" @click="followLink($event, 'blog')">← All posts</a>
        </p>

        <article class="blog__article">
          <header class="blog__article-head">
            <h1 ref="heading" class="blog__title" tabindex="-1">{{ post.title }}</h1>
            <p class="blog__date">
              <time :datetime="post.date">{{ formatPostDate(post.date) }}</time>
            </p>
            <p v-if="post.summary" class="blog__summary">{{ post.summary }}</p>
          </header>

          <!-- One block per element, in the order the post was written: nothing
               here renders markup from the content, and no block is optional. -->
          <template v-for="(block, index) in post.body" :key="index">
            <h2 v-if="block.kind === 'heading'" class="blog__heading">{{ block.text }}</h2>

            <ul v-else-if="block.kind === 'list'" class="blog__list">
              <li v-for="(item, itemIndex) in block.items" :key="itemIndex">{{ item }}</li>
            </ul>

            <blockquote v-else-if="block.kind === 'quote'" class="blog__quote">
              <p>{{ block.text }}</p>
              <p v-if="block.source" class="blog__quote-source">{{ block.source }}</p>
            </blockquote>

            <p v-else-if="block.kind === 'paragraph'" class="blog__paragraph">
              <template v-if="typeof block.text === 'string'">{{ block.text }}</template>
              <template v-else>
                <template v-for="(part, partIndex) in block.text" :key="partIndex">
                  <a
                    v-if="typeof part !== 'string'"
                    :href="part.href"
                    :target="isExternal(part.href) ? '_blank' : undefined"
                    :rel="isExternal(part.href) ? 'noopener noreferrer' : undefined"
                    >{{ part.text }}</a
                  >
                  <template v-else>{{ part }}</template>
                </template>
              </template>
            </p>
          </template>
        </article>
      </template>

      <!-- An address that names no post. It is a page of its own rather than a
           redirect: the reader keeps the link they followed, and the way back is
           one line of text and one link. -->
      <template v-else>
        <h1 ref="heading" class="blog__title" tabindex="-1">Post not found</h1>
        <p class="blog__empty">
          There is no post at this address. It may have been renamed, or the link that led here may
          have a typo in it.
        </p>
        <p class="blog__back">
          <a :href="pagePath('blog')" @click="followLink($event, 'blog')">← All posts</a>
        </p>
      </template>
    </div>
  </BlogLayout>
</template>
