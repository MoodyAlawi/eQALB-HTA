/**
 * The quiet notice shown after an export has been prepared.
 *
 * Two things are deliberate. It reports that the download was *prepared* and handed
 * to the browser, not that a file was saved — an interface that starts a download
 * cannot know what the browser or the user did with it. And it is only shown where
 * nothing else already says so: the Download results view has its own status line
 * on the page, so the per-tab CSV exports are the ones that use this.
 *
 * The state is one module-level notice, because there is one notice on screen: a
 * second export replaces the first rather than stacking a queue of them. A prepared
 * download dismisses itself after a few seconds; a failure does not, because it is
 * something the reader has to act on, so it stays until it is dismissed. The timer
 * belongs to the notice and is cleared whenever the notice changes or goes, so
 * nothing is left running behind a message that is no longer there.
 */

import { ref, type Ref } from 'vue'
import { downloadText } from '../export/csv'

export interface DownloadNotice {
  tone: 'ok' | 'error'
  /** The one-line statement, in the interface's own voice. */
  title: string
  /** The filename, or what went wrong. */
  detail: string
}

/** How long a prepared download stays on screen before dismissing itself. */
const AUTO_DISMISS_MS = 7000

const notice = ref<DownloadNotice | null>(null)
let timer: ReturnType<typeof setTimeout> | null = null

function clearTimer(): void {
  if (timer !== null) clearTimeout(timer)
  timer = null
}

/** Takes the notice away, and clears the timer that was waiting to do it. */
export function dismissDownloadNotice(): void {
  clearTimer()
  notice.value = null
}

function show(next: DownloadNotice, autoDismiss: boolean): void {
  clearTimer()
  notice.value = next
  if (!autoDismiss) return
  timer = setTimeout(() => {
    timer = null
    notice.value = null
  }, AUTO_DISMISS_MS)
}

/** Reports a prepared download, naming the file that was handed to the browser. */
export function announceDownloadPrepared(
  filename: string,
  kind: 'file' | 'package' = 'file',
): void {
  show(
    {
      tone: 'ok',
      title: kind === 'package' ? 'Results package prepared.' : 'Download prepared.',
      detail: filename,
    },
    true,
  )
}

/**
 * Reports a download that could not be prepared. The message is the browser's own
 * description of what failed — never a joke, and never worded as a success — and it
 * stays until it is dismissed.
 */
export function announceDownloadFailure(detail: string): void {
  show({ tone: 'error', title: 'The download could not be prepared.', detail }, false)
}

/**
 * Prepares one export: the existing write is run unchanged, and the notice reports
 * whichever of the two outcomes actually happened. A failure shows the failure
 * only, so a download can never be reported as prepared when it was not.
 */
export function prepareDownload(
  filename: string,
  write: () => void,
  kind: 'file' | 'package' = 'file',
): void {
  try {
    write()
  } catch (error) {
    announceDownloadFailure(error instanceof Error ? error.message : String(error))
    return
  }
  announceDownloadPrepared(filename, kind)
}

/** One CSV export, written and reported. */
export function prepareCsvDownload(text: string, filename: string): void {
  prepareDownload(filename, () => downloadText(text, filename))
}

export function useDownloadNotice(): { notice: Ref<DownloadNotice | null> } {
  return { notice }
}
