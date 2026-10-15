<script setup lang="ts">
/**
 * The small notice that confirms an export has been prepared.
 *
 * It is one card in the corner of the window, away from the analysis controls, and
 * it appears with a short fade and a few pixels of movement. It is a polite live
 * region, so it is announced once rather than watched for, and it never takes the
 * keyboard: nothing here moves focus, and the dismiss button is only there for
 * someone who wants the card gone — a prepared download also dismisses itself after
 * a few seconds, and a failure waits to be dismissed because it is the one the
 * reader has to act on.
 *
 * The wording distinguishes the two states honestly: a prepared download is not
 * reported as a saved file, and a failure is reported as a failure.
 */

import { dismissDownloadNotice, useDownloadNotice } from '../composables/useDownloadNotice'

const { notice } = useDownloadNotice()
</script>

<template>
  <Transition name="notice">
    <div
      v-if="notice"
      class="download-notice"
      :class="{ 'is-error': notice.tone === 'error' }"
      :role="notice.tone === 'error' ? 'alert' : 'status'"
    >
      <p class="download-notice__title">{{ notice.title }}</p>
      <p class="download-notice__detail">{{ notice.detail }}</p>
      <button
        type="button"
        class="btn btn--ghost download-notice__dismiss"
        @click="dismissDownloadNotice()"
      >
        Dismiss
      </button>
    </div>
  </Transition>
</template>
