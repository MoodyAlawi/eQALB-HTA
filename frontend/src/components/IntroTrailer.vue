<script setup lang="ts">
/**
 * The first-visit intro overlay: the eQalb trailer, shown once per browser profile
 * on the first entry into /app. See `useIntro.ts` for when it is due and how it hands
 * over to the app's own launch animation; this component is the overlay itself.
 *
 * Entrance:
 *  - from the landing page's "Open the app": the page stays visible while the
 *    button's pulse runs (landing.css), then a dark stage sweeps in from the left
 *    behind a soft teal band (220-640 ms). The video's first frame is that same
 *    dark background, and its own ECG line then draws in from the left;
 *  - on a direct /app load: the overlay starts as the plain app background and the
 *    stage's vignette fades in (300 ms).
 * Playback is attempted when the entrance's animation ends, never before.
 *
 * Nobody can be trapped: Skip is visible and focusable from the first frame,
 * Escape skips, a rejected play(), a media error, no playback within 1.5 s of the
 * attempt, no progress for 4 s once playing, or an absolute 45 s cap all fall
 * through into the app through the same guarded `finish()`.
 *
 * The video source is attached only here, so a visitor who bypasses the intro never
 * downloads it. Everything is cleaned up when the overlay unmounts.
 */

import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useAppView } from '../composables/useAppView'
import { useIntro } from '../composables/useIntro'
import { useModalFocus } from '../composables/useModalFocus'

/** Playback must have started this long after it was attempted. */
const STARTUP_MS = 1500
/** Once playing, the video must keep advancing at least this often. */
const STALL_MS = 4000
/** Absolute cap from the attempt: the 30 s video plus generous loading time. */
const CAP_MS = 45000
/** If the entrance animation never reports its end, playback is attempted anyway. */
const ENTRANCE_SAFETY_MS = 1200

const SRC = `${import.meta.env.BASE_URL}media/eqalb-intro.mp4`

const { origin, finish, cancelIntro, handedOff } = useIntro()
const { page } = useAppView()

const root = ref<HTMLElement | null>(null)
const video = ref<HTMLVideoElement | null>(null)
const skipButton = ref<HTMLButtonElement | null>(null)
const focusOpen = ref(false)

let attempted = false
let lastTime = 0
let startupTimer: ReturnType<typeof setTimeout> | undefined
let stallTimer: ReturnType<typeof setTimeout> | undefined
let capTimer: ReturnType<typeof setTimeout> | undefined
let entranceTimer: ReturnType<typeof setTimeout> | undefined

function clearTimers(): void {
  clearTimeout(startupTimer)
  clearTimeout(stallTimer)
  clearTimeout(capTimer)
  clearTimeout(entranceTimer)
  startupTimer = stallTimer = capTimer = entranceTimer = undefined
}

/** Every way out: stop the clocks, hold the current frame, hand over once. */
function done(): void {
  clearTimers()
  video.value?.pause()
  finish()
}

function startPlayback(): void {
  if (attempted) return
  attempted = true
  clearTimeout(entranceTimer)
  const element = video.value
  if (!element) {
    done()
    return
  }
  startupTimer = setTimeout(done, STARTUP_MS)
  capTimer = setTimeout(done, CAP_MS)
  element.muted = true
  try {
    const playing = element.play()
    if (playing) playing.catch(done)
  } catch {
    done()
  }
}

function onEntranceEnd(event: AnimationEvent): void {
  if (event.animationName === 'intro-sweep' || event.animationName === 'intro-settle') {
    startPlayback()
  }
}

/** The stall watchdog runs only while the page is visible and the video should advance. */
function armStallWatch(): void {
  clearTimeout(stallTimer)
  stallTimer = undefined
  const element = video.value
  if (!element || element.ended || document.hidden) return
  stallTimer = setTimeout(done, STALL_MS)
}

function onPlaying(): void {
  clearTimeout(startupTimer)
  startupTimer = undefined
  armStallWatch()
}

/** Real progress resets the watchdog; a frozen clock lets it run out. */
function onTimeUpdate(): void {
  const element = video.value
  if (!element || element.currentTime <= lastTime) return
  lastTime = element.currentTime
  armStallWatch()
}

function onVisibility(): void {
  if (document.hidden) {
    clearTimeout(stallTimer)
    stallTimer = undefined
  } else if (startupTimer === undefined && attempted) {
    armStallWatch()
  }
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Escape') return
  event.preventDefault()
  event.stopPropagation()
  done()
}

/**
 * The intro belongs to the page it was opened on. If the visitor is taken anywhere
 * else before it hands over (Back, a link), it goes without being recorded.
 */
watch(page, (next) => {
  if (handedOff.value) return
  const expected = origin.value === 'landing' ? 'openhealth' : 'home'
  if (next !== expected) {
    clearTimers()
    cancelIntro()
  }
})

/**
 * Keyboard containment comes from the app's modal pattern: the focus starts on
 * Skip and the page behind is inert. The overlay is removed by unmounting, which
 * releases the page without sending the focus back to the landing page's button;
 * `useIntro` moves it to Home once Home exists.
 */
useModalFocus(focusOpen, root, { initialFocus: () => skipButton.value })

onMounted(() => {
  focusOpen.value = true
  document.addEventListener('keydown', onKeydown, true)
  document.addEventListener('visibilitychange', onVisibility)
  entranceTimer = setTimeout(startPlayback, ENTRANCE_SAFETY_MS)
})

onBeforeUnmount(() => {
  clearTimers()
  document.removeEventListener('keydown', onKeydown, true)
  document.removeEventListener('visibilitychange', onVisibility)
  const element = video.value
  if (element) {
    element.pause()
    element.removeAttribute('src')
    element.load()
  }
})
</script>

<template>
  <div
    ref="root"
    class="intro"
    :class="`intro--${origin}`"
    role="dialog"
    aria-modal="true"
    aria-label="eQalb introduction video"
  >
    <div class="intro__stage" @animationend.self="onEntranceEnd">
      <div class="intro__frame">
        <video
          ref="video"
          class="intro__video"
          :src="SRC"
          muted
          playsinline
          preload="auto"
          disablepictureinpicture
          disableremoteplayback
          aria-hidden="true"
          tabindex="-1"
          @playing="onPlaying"
          @timeupdate="onTimeUpdate"
          @ended="done"
          @error="done"
        ></video>
      </div>
    </div>
    <span v-if="origin === 'landing'" class="intro__edge" aria-hidden="true"></span>
    <button ref="skipButton" type="button" class="intro__skip" @click="done">Skip intro</button>
  </div>
</template>
