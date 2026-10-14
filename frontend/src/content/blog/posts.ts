/**
 * The blog's content directory: the posts that are published, and the only
 * place a post is looked up.
 *
 * A post is a module of its own in this directory (see ./README.md for how one
 * is written, and ./types.ts for the blocks it is built from), and it goes on
 * the site once - and only once - it is imported and listed in POSTS below. A
 * post file that is not listed is a draft: it is still type-checked, linted and
 * built with the rest of the sources, but no address shows it and the index does
 * not mention it. Removing the line is the whole of "unpublish".
 *
 * The list holds the first published post. Nothing here invents content, and the
 * index carries a restrained empty state whenever the list is empty rather than a
 * placeholder article.
 *
 * This module imports the posts; nothing else in the application does. The views
 * read `publishedPosts()` and `findPost()`, so there is one ordered list, one
 * date format and one lookup.
 */

import type { BlogPost } from './types'
import releaseOfEqalb from './release-of-eqalb-and-openhealth'

/**
 * Every published post.
 *
 * `date` is "YYYY-MM-DD" and fixes the order: the index is newest first, which
 * for that format is a plain reverse sort. Two posts on the same date keep the
 * order they are listed in here.
 */
const POSTS: readonly BlogPost[] = [releaseOfEqalb]

/** Every published post, newest first. */
export function publishedPosts(): readonly BlogPost[] {
  return [...POSTS].sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0))
}

/** The published post with this slug, or null when no published post carries it. */
export function findPost(slug: string): BlogPost | null {
  return POSTS.find((post) => post.slug === slug) ?? null
}
