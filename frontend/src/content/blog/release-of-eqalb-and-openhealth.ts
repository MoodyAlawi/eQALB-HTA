/**
 * The first published post: the release of eQalb and the introduction of
 * OpenHealth.
 *
 * The text is the author's own, exactly as written - no wording was edited, and
 * nothing was added to it, including links. The slug is drawn from the title
 * ("release of eQalb & the introduction of OpenHealth" with the punctuation and
 * joiners removed), and the date is written as "YYYY-MM-DD" because that is the
 * form the index sorts by and the article's `<time>` element reads; the author
 * gave it as 14/10/2026.
 */

import type { BlogPost } from './types'

const post: BlogPost = {
  slug: 'release-of-eqalb-and-openhealth',
  title: 'Release of eQalb & The introduction of OpenHealth!',
  date: '2026-10-14',
  body: [
    {
      kind: 'paragraph',
      text: 'Hey everyone, welcome to my project! This has been in the works for a while and has been something I’ve been thinking about for even longer.',
    },
    {
      kind: 'paragraph',
      text: 'I released eQalb around a week ago as an R Shiny application and shared it amongst my network on LinkedIn. But the truth is that it was just a proof of concept and part of a much bigger project: OpenHealth. It’s currently hosting my project and acting sort of like a portfolio, but it is destined for bigger and greater things in the future.',
    },
    {
      kind: 'paragraph',
      text: 'The R Shiny project I released was the only way I could get the project out there, since there was no way I could have hosted my stack for free. I used Cloud Connect to host the Shiny application and get feedback, and the feedback I got was amazing. I went right away to work on changes to the app and implemented an overhaul of it.',
    },
    {
      kind: 'paragraph',
      text: 'You can see all the progress on the GitHub repo, and soon I will be posting a roadmap for changes that I will make down the line, especially with the tutorial section in August. Stay tuned!',
    },
    {
      kind: 'paragraph',
      text: 'Aside from eQalb, I plan a slow build-up for OpenHealth. It is meant to be a platform for the collaboration of open-source health projects and for people to get together for the cause of learning and sharing experiences and information.',
    },
    {
      kind: 'paragraph',
      text: 'I am open to any collaborators and institutions who share this vision or are interested. The project is still in its infancy, but I do have big goals, and I believe that achieving them is possible.',
    },
    {
      kind: 'paragraph',
      text: 'Thanks for reading this, whoever you are, and feel free to reach out to me through my LinkedIn or email for a chat. I am always happy to :)',
    },
    { kind: 'paragraph', text: 'Till next time!' },
    { kind: 'paragraph', text: 'Mahmood' },
  ],
}

export default post
