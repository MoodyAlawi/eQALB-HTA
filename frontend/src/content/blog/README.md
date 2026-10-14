# Blog content

Everything the OpenHealth blog publishes lives in this directory. There is no
CMS, no database and no build step of its own: a post is a TypeScript module in
this folder, and it appears on the site when it is listed in
[`posts.ts`](./posts.ts), which is the only file the application imports from
here.

Nothing in this directory is published except what `posts.ts` lists. One post is
published today — [`release-of-eqalb-and-openhealth.ts`](./release-of-eqalb-and-openhealth.ts),
the release of eQalb and the introduction of OpenHealth (14 October 2026) — and
`/blog` shows a restrained empty state whenever the list is empty rather than a
placeholder article.

## Why not Markdown

The frontend has no Markdown renderer, and the blog was not allowed to add one
without approval, so a post is written as typed data instead of Markdown. The
shape is deliberately small — a paragraph, a heading, a list, a quote — and each
piece of text is a plain string, so nothing is parsed, no HTML is rendered and
nothing has to be sanitised. If Markdown is wanted later it needs one small
renderer dependency and its approval; the content model in
[`types.ts`](./types.ts) is where that decision would land.

## A post

| Field | Required | What it is |
|---|---|---|
| `slug` | yes | The address segment after `/blog/`. Unique across the posts, lowercase, words joined with `-`. |
| `date` | yes | Publication date as `YYYY-MM-DD`. This is also the order the index sorts by, newest first. |
| `title` | yes | The post's title, shown on the index and as the article's heading. |
| `summary` | no | One or two lines for the index, under the date. Omit it and the entry is title and date only. |
| `body` | yes | The post itself: an ordered list of blocks (below). |

Every block in `body` is one of four things:

| Block | What it renders as |
|---|---|
| `{ kind: 'paragraph', text: '…' }` | A paragraph. |
| `{ kind: 'heading', text: '…' }` | A section heading (`h2`) inside the article. |
| `{ kind: 'list', items: ['…', '…'] }` | A bulleted list. |
| `{ kind: 'quote', text: '…', source: '…' }` | A quotation; `source` is optional. |

A paragraph's `text` may be a single string, or an array of strings and links
read in order:

```ts
{
  kind: 'paragraph',
  text: [
    'The model is described in the ',
    { text: 'project description', href: '/app' },
    ', and the source is on ',
    { text: 'GitHub', href: 'https://github.com/MoodyAlawi/eQALB-HTA' },
    '.',
  ],
}
```

An `href` starting with `http://` or `https://` opens in a new tab; anything else
(for example `/app` or `/blog`) is followed in the same tab, as a full page load
of that address.

There is no emphasis, no images, no footnotes and no raw HTML: if a sentence needs
emphasis, write a better sentence. Adding a block type means editing
[`types.ts`](./types.ts) and the article template in
`../../views/BlogPostView.vue` together.

## Example — not published

This is what a post looks like. It is documentation, not content: do not copy it
in as-is, and do not publish an article that has not been written and approved.

```ts
// src/content/blog/why-an-illustrative-model.ts
import type { BlogPost } from './types'

const post: BlogPost = {
  slug: 'why-an-illustrative-model',
  title: 'Why an illustrative model',
  date: '2026-11-02',
  summary: 'One or two lines for the index.',
  body: [
    { kind: 'paragraph', text: 'The opening paragraph, in plain prose.' },
    { kind: 'heading', text: 'A section heading' },
    {
      kind: 'paragraph',
      text: [
        'A sentence with ',
        { text: 'a link', href: 'https://example.org' },
        ' inside it.',
      ],
    },
    { kind: 'list', items: ['The first point.', 'The second point.'] },
    { kind: 'quote', text: 'A quoted sentence.', source: 'Who said it' },
  ],
}

export default post
```

## Add a post

Two edits, in this order:

1. Create `src/content/blog/<slug>.ts` with one `BlogPost` as above (the file name
   does not have to match the slug, but matching it is easier to keep straight).
2. Import it at the top of [`posts.ts`](./posts.ts) and add it to the `POSTS`
   array. That line is what publishes it; without it the file is a draft.

A draft is still type-checked, linted and built with the rest of the sources, but
no address shows it, the index does not mention it and nothing links to it.
Removing the line from `POSTS` is the whole of "unpublish".

## Preview it

From `frontend/`:

```powershell
npm run dev
```

Then open <http://127.0.0.1:5173/blog> for the index and
<http://127.0.0.1:5173/blog/<slug> for the post. The dev server resolves both
addresses from the same `index.html`, so either can be typed, reloaded or opened
in a new tab.

The usual checks are worth running before publishing, because none of them is
automatic yet:

```powershell
npm run typecheck
npm run lint
npm run build
```

A post's date is rendered from its own parts in UTC, so the day shown is the day
written whichever time zone the reader is in. An address that names no post shows
the blog's own "Post not found" page rather than a redirect or a blank screen.

## Publish it

The blog is part of the frontend bundle, so publishing a post is publishing the
frontend — there is no separate content pipeline and no server-side change:

1. The post file and its `POSTS` entry are committed with the rest of the change.
2. `main` is pushed, which triggers
   [`.github/workflows/deploy-frontend.yml`](../../../../.github/workflows/deploy-frontend.yml)
   (type check, lint, build, package, publish behind the `dist` symlink). The
   workflow also requires the `production` environment's approval before it
   publishes.
3. The deployed shell serves `/blog` and `/blog/<slug>` directly, because Caddy
   already falls back to `index.html` for an address that is not a file
   (`try_files {path} /index.html` in `deploy/Caddyfile`) — no server change is
   needed for a new post, or for the blog itself.

**Deployment paths filter:** the workflow's `on.push.paths` already lists
`frontend/**`, which contains this directory, so a change to a post file is
already inside the deployed path filter. No workflow change is needed and none was
made.
