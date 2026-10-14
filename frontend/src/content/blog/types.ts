/**
 * What a blog post is made of.
 *
 * The blog deliberately holds no Markdown parser and no HTML: a post is typed
 * data, and the views render it element by element, so there is nothing to
 * sanitise and nothing to license. That is why the shape below is a small,
 * closed set of content blocks rather than a string of markup - a paragraph, a
 * heading, a list and a quote are everything a post in this blog has needed, and
 * each one is a plain string as written.
 *
 * Emphasis is deliberately absent. If a post ever needs a word emphasised, the
 * right answer is a sentence that says it, not another syntax to learn.
 *
 * Writing a post is documented in ./README.md; the posts are registered in
 * ./posts.ts, which is the only file the application imports from this
 * directory.
 */

/**
 * One piece of a paragraph: plain text, or a link with its own label. A
 * paragraph's `text` is either a single string or an array of these, read and
 * rendered in order - so a sentence with a link in it is a list of segments, and
 * nothing has to be parsed out of anything.
 *
 * An `href` that begins with http:// or https:// is an external link and is
 * opened in a new tab; anything else (for example "/app" or "/blog") is an
 * ordinary link followed in the same tab, which is a full page load of that
 * address - the shell resolves it on load exactly as a typed address would.
 */
export type BlogInline = string | { readonly text: string; readonly href: string }

export interface BlogParagraph {
  readonly kind: 'paragraph'
  readonly text: string | readonly BlogInline[]
}

export interface BlogHeading {
  readonly kind: 'heading'
  readonly text: string
}

export interface BlogList {
  readonly kind: 'list'
  readonly items: readonly string[]
}

export interface BlogQuote {
  readonly kind: 'quote'
  readonly text: string
  /** Who or what the quoted words are from, when it is worth naming. */
  readonly source?: string
}

/** Everything a post's body can contain, in the order it is written. */
export type BlogBlock = BlogParagraph | BlogHeading | BlogList | BlogQuote

export interface BlogPost {
  /** The address segment after /blog/, unique across the posts. */
  readonly slug: string
  readonly title: string
  /** Publication date as "YYYY-MM-DD"; this is also the order the index uses. */
  readonly date: string
  /** One or two lines for the index; optional. */
  readonly summary?: string
  readonly body: readonly BlogBlock[]
}
