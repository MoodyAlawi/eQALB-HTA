<script setup lang="ts">
/**
 * Application shell: the public OpenHealth pages (the landing page, About, and
 * the blog), then eQalb itself - its Home screen and subviews, and the analysis
 * dashboard with service status, theme switch, the assumptions panel and the
 * analysis tabs.
 *
 * The public addresses (/ , /blog, /blog/<slug>, /app and /about) are resolved by
 * useAppView, which owns the pathname, the history entries and the document
 * title. Every eQalb screen shares /app, so nothing below the dashboard branch is
 * aware of the URL at all.
 *
 * Exactly one page renders at a time, and each one is named by its own v-if /
 * v-else-if: the analysis dashboard is the first branch below, and the public
 * pages and the eQalb subviews (Home, tutorial, project description, download
 * results) follow it. A page must never be the chain's leftover branch - the
 * download view was, and so appeared under the dashboard in every analysis tab.
 * Changing the page is what unmounts a view, so a page that is left takes its
 * controls out of the document rather than hiding them.
 *
 * Tabs are rendered with v-if rather than v-show so each chart is created only
 * when its tab is visible: an ECharts instance initialised inside a hidden
 * container would latch onto a zero-sized canvas.
 *
 * The contract is only fetched when the dashboard is first opened, so the Home
 * screen makes no request at all: nothing is analysed before an analysis action,
 * and no run is started by looking around the app.
 */

import { computed, nextTick, ref, watch } from 'vue'
import { useModel } from './composables/useModel'
import { useTheme } from './composables/useTheme'
import { useAppView } from './composables/useAppView'
import AssumptionsForm from './components/AssumptionsForm.vue'
import BaseCasePanel from './components/BaseCasePanel.vue'
import CostEffectivenessPanel from './components/CostEffectivenessPanel.vue'
import SensitivityPanel from './components/SensitivityPanel.vue'
import BudgetImpactPanel from './components/BudgetImpactPanel.vue'
import SurvivalPanel from './components/SurvivalPanel.vue'
import ValueOfInformationPanel from './components/ValueOfInformationPanel.vue'
import ReadinessPanel from './components/ReadinessPanel.vue'
import HtaSummaryPanel from './components/HtaSummaryPanel.vue'
import ValueBasedPricePanel from './components/ValueBasedPricePanel.vue'
import HomeView from './views/HomeView.vue'
import ProjectDescriptionView from './views/ProjectDescriptionView.vue'
import DownloadResultsView from './views/DownloadResultsView.vue'
import TutorialView from './views/TutorialView.vue'
import OpenHealthHomeView from './views/OpenHealthHomeView.vue'
import AboutView from './views/AboutView.vue'
import BlogIndexView from './views/BlogIndexView.vue'
import BlogPostView from './views/BlogPostView.vue'
import AppLoadingIndicator from './components/AppLoadingIndicator.vue'
import DownloadNotice from './components/DownloadNotice.vue'
import LaunchTransition from './components/LaunchTransition.vue'
import { useTabUnderline } from './composables/useTabUnderline'
import { usePageEntrance } from './composables/usePageEntrance'
import { DIALOG_TRANSITION_NAME, onDialogLeave } from './composables/useDialogTransition'

type TabId =
  | 'baseCase'
  | 'ce'
  | 'sensitivity'
  | 'budget'
  | 'survival'
  | 'voi'
  | 'readiness'
  | 'valueBasedPrice'
  | 'hta'

interface Tab {
  id: TabId
  label: string
  hint: string
}

const TABS: readonly Tab[] = [
  { id: 'baseCase', label: 'Base case', hint: 'Incremental cost, QALYs and ICER' },
  { id: 'ce', label: 'Cost-effectiveness and PSA', hint: 'Plane, iterations and CEAC' },
  { id: 'sensitivity', label: 'Sensitivity analysis', hint: 'Tornado diagram' },
  { id: 'budget', label: 'Budget impact', hint: 'Costs over the horizon' },
  { id: 'survival', label: 'Simulated survival', hint: 'Kaplan-Meier curves' },
  { id: 'voi', label: 'Value of information', hint: 'EVPI and EVPPI' },
  { id: 'readiness', label: 'DHT readiness', hint: 'Implementation domains and statuses' },
  {
    id: 'valueBasedPrice',
    label: 'Value-based Price',
    hint: 'Highest price the model supports, and the assumptions it depends on',
  },
  { id: 'hta', label: 'HTA Decision Summary', hint: 'Decision dashboard and evidence priorities' },
]

const model = useModel()
const { theme, toggle } = useTheme()
const { page, show, postSlug } = useAppView()

/**
 * The welcome overlay.
 *
 * It is asked once per browser session, the first time the analysis dashboard is
 * opened, and it is what the reference Shiny app asks at the same moment ("New to
 * economic evaluation or HTA?"). The session flag is marked when the overlay is
 * shown, as the reference app does, so it cannot come back later in the session
 * — not after either button, not after Escape, and not after entering the
 * tutorial by any other route. It is an overlay, not a gate: the two buttons
 * choose a destination, Escape or the backdrop simply dismisses it, and the
 * dashboard it appears over is already open behind it.
 */
const WELCOME_SESSION_KEY = 'eqalb.welcome'

function welcomeAlreadySeen(): boolean {
  try {
    return sessionStorage.getItem(WELCOME_SESSION_KEY) === '1'
  } catch {
    // A browser that refuses session storage shows the overlay once per load
    // rather than never showing it.
    return false
  }
}

function markWelcomeSeen(): void {
  try {
    sessionStorage.setItem(WELCOME_SESSION_KEY, '1')
  } catch {
    /* the flag is best-effort; the overlay is presentation only */
  }
}

const welcomeOpen = ref(false)
const welcomeTutorial = ref<HTMLButtonElement | null>(null)
/** True once the question has been settled, one way or another, this session. */
let welcomeSettled = welcomeAlreadySeen()

/**
 * The dashboard is what triggers the question, so it is only ever asked on the
 * first transition into that page: never on load, never on the Home screen, and
 * never twice. The flag is written before the overlay opens, so closing the page
 * or reloading while it is up cannot make it ask again.
 */
watch(page, (next) => {
  if (next === 'tutorial') {
    welcomeSettled = true
    markWelcomeSeen()
    return
  }
  if (next !== 'dashboard' || welcomeSettled) return
  welcomeSettled = true
  markWelcomeSeen()
  welcomeOpen.value = true
  void nextTick(() => welcomeTutorial.value?.focus())
})

function dismissWelcome(): void {
  welcomeOpen.value = false
  welcomeSettled = true
  markWelcomeSeen()
}

function welcomeStartTutorial(): void {
  dismissWelcome()
  show('tutorial')
}

function welcomeOpenAnalysis(): void {
  // The dashboard is already open behind the overlay; this only puts it away.
  dismissWelcome()
}

function onWelcomeKeydown(event: KeyboardEvent): void {
  // Escape dismisses the question without choosing a destination.
  if (event.key === 'Escape') {
    event.stopPropagation()
    dismissWelcome()
  }
}

const activeTab = ref<TabId>('baseCase')
const showAssumptions = ref(false)
const activeHint = computed(() => TABS.find((tab) => tab.id === activeTab.value)?.hint ?? '')

/**
 * Tab strip accessibility. Each tab controls the panel with the matching id,
 * only the selected tab is in the tab sequence (so Tab leaves the strip after
 * one stop), and the arrow keys move within it.
 */
const tabButtons = ref<HTMLButtonElement[]>([])

function tabId(id: TabId): string {
  return `tab-${id}`
}

function panelId(id: TabId): string {
  return `panel-${id}`
}

function activateTab(id: TabId): void {
  activeTab.value = id
}

/**
 * The sliding underline under the selected tab. The strip's own layout decides
 * where a tab is — it wraps, and the final tab is pushed to the end of its row — so
 * the indicator is placed from the selected tab's box rather than from a
 * calculation of its own; see the composable for the two rules it follows. It is
 * decoration, and the tab it draws under is selected before it moves, so nothing
 * waits for it.
 */
const tabsNav = ref<HTMLElement | null>(null)
const activeTabIndex = computed(() =>
  Math.max(
    0,
    TABS.findIndex((tab) => tab.id === activeTab.value),
  ),
)
const { position: indicatorPosition, moving: indicatorMoving } = useTabUnderline(
  tabsNav,
  activeTabIndex,
)
const indicatorStyle = computed(() =>
  indicatorPosition.value
    ? {
        left: `${indicatorPosition.value.left}px`,
        top: `${indicatorPosition.value.top}px`,
        width: `${indicatorPosition.value.width}px`,
      }
    : {},
)

/**
 * The page-entry fade.
 *
 * The key is the page, plus the post's slug on the blog, so the index, one post
 * and another post are three separate arrivals and a post-to-post move replays
 * the fade. Nothing else about the shell is in it, so a rerender, an input, a
 * theme change, a loading message, a tutorial step or an analysis-tab switch
 * replays nothing.
 *
 * The Home screen is listed to be skipped: it has its own entrance already (the
 * launch sequence's `home-rise`), and it pins its theme button to the window's
 * corner while the eQalb column is narrower than the window — a fade there would
 * carry that button with it. See the composable for the rest of the rules, which
 * it owns: no fade on a first paint, on Back and Forward, during the landing
 * page's crossing into the app, while a dialog is open, or when the arriving page
 * is one the document is already scrolled into.
 */
const pageEntryKey = computed(() =>
  page.value === 'blog' ? `blog:${postSlug.value ?? ''}` : page.value,
)
const { enterClass: pageEnterClass } = usePageEntrance(pageEntryKey, { skip: ['home'] })

/**
 * Arrow keys move between tabs and select as they go; Home and End jump to the
 * ends. Enter and Space are deliberately not handled: every tab is a real
 * <button>, so the browser activates it natively, exactly as before.
 */
function onTabsKeydown(event: KeyboardEvent): void {
  const count = TABS.length
  const current = Math.max(0, TABS.findIndex((tab) => tab.id === activeTab.value))
  let next: number
  if (event.key === 'ArrowLeft') next = (current - 1 + count) % count
  else if (event.key === 'ArrowRight') next = (current + 1) % count
  else if (event.key === 'Home') next = 0
  else if (event.key === 'End') next = count - 1
  else return
  event.preventDefault()
  activateTab(TABS[next].id)
  tabButtons.value[next]?.focus()
}

const status = computed(() => model.health?.status ?? 'unknown')
const statusLabel = computed(() => {
  if (!model.health) return 'Model service unreachable'
  return status.value === 'ok' ? 'Model service ready' : 'Model service not ready'
})

/**
 * The overall status R reported in the HTA decision summary, once it has been
 * assessed. It only picks the accent colour of the final tab and its panel; no
 * status is derived, recomputed or reworded here.
 */
const htaAccent = computed(() => {
  const status = model.htaSummary?.summary?.overall_status
  if (status === 'Green') return 'is-good'
  if (status === 'Amber') return 'is-warning'
  if (status === 'Red') return 'is-bad'
  return null
})

// The dashboard needs the contract (input defaults, choices, notices); the Home
// screen does not, so the first fetch waits until the dashboard is opened.
let contractRequested = false

watch(page, (next) => {
  if (next !== 'dashboard' || contractRequested) return
  contractRequested = true
  void model.loadService()
})
</script>

<template>
  <!-- The eQalb screens - Home, the tutorial, the project description - are a
       centred column inside the app's own padding. The landing page and the blog
       are full-bleed pages laid out by their own stylesheets, so the shell steps
       aside for both: no column of its own, no padding of its own. -->
  <div
    class="app"
    :class="{
      'app--solo': page !== 'dashboard' && page !== 'openhealth' && page !== 'blog',
      'app--landing': page === 'openhealth' || page === 'blog',
    }"
  >
    <!-- The page content, and the wrapper the page-entry fade is played on. The
         overlays below (the loading indicator, the download notice, the launch
         overlay, the welcome question) are deliberately outside it: they are
         fixed to the window, and anything that is below full opacity becomes the
         containing block for a fixed descendant, so animating a wrapper that held
         them would move them. Only the content fades, and only for a move the
         composable approves. -->
    <div class="page-entry" :class="pageEnterClass">
      <template v-if="page === 'dashboard'">
        <header class="app__header">
          <div class="app__brand">
            <h1>eQalb</h1>
            <p class="muted">
              Illustrative HTA model for a fictional hypertension digital therapeutic.
            </p>
          </div>

          <div class="app__actions">
            <button
              type="button"
              class="btn btn--ghost"
              title="Back to the start screen"
              @click="show('home')"
            >
              Home
            </button>

            <button
              type="button"
              class="btn btn--ghost sidebar-toggle"
              :aria-expanded="showAssumptions"
              @click="showAssumptions = !showAssumptions"
            >
              Assumptions
            </button>

            <button
              type="button"
              class="badge status-chip"
              :class="status === 'ok' ? 'badge--good' : 'badge--warning'"
              title="Check the model service again"
              @click="model.refreshHealth()"
            >
              <span class="dot" :class="status === 'ok' ? 'dot--good' : 'dot--warning'"></span>
              {{ statusLabel }}
            </button>

            <button
              type="button"
              class="btn btn--icon"
              :title="theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'"
              :aria-label="theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'"
              @click="toggle()"
            >
              <span aria-hidden="true">{{ theme === 'dark' ? '☀' : '☾' }}</span>
            </button>
          </div>
        </header>

        <main v-if="model.loading" class="state">
          <p>Loading the model service…</p>
        </main>

        <main v-else-if="model.loadError" class="state">
          <h2>The model service is not reachable</h2>
          <p class="alert alert--danger">{{ model.loadError }}</p>
          <p class="muted">
            The interface presents results computed by the model service, so it needs that service to
            be running. Start it, then try again.
          </p>
          <button type="button" class="btn btn--primary" @click="model.loadService()">Retry</button>
          <button type="button" class="btn btn--ghost" @click="show('home')">Back to start</button>
        </main>

        <div v-else class="app__body">
          <aside class="sidebar" :class="{ 'sidebar--hidden': !showAssumptions }">
            <AssumptionsForm />
          </aside>

          <section class="content">
            <nav
              ref="tabsNav"
              class="tabs"
              role="tablist"
              aria-label="Analysis"
              aria-orientation="horizontal"
              @keydown="onTabsKeydown"
            >
              <button
                v-for="tab in TABS"
                :id="tabId(tab.id)"
                :key="tab.id"
                ref="tabButtons"
                type="button"
                role="tab"
                class="tabs__tab"
                :class="[
                  { 'is-active': activeTab === tab.id, 'tabs__tab--final': tab.id === 'hta' },
                  tab.id === 'hta' ? htaAccent : null,
                ]"
                :title="tab.hint"
                :aria-selected="activeTab === tab.id"
                :aria-current="activeTab === tab.id ? 'true' : undefined"
                :aria-controls="panelId(tab.id)"
                :tabindex="activeTab === tab.id ? 0 : -1"
                @click="activateTab(tab.id)"
              >
                {{ tab.label }}
              </button>

              <!-- The selected tab's underline: one element that slides between
                   tabs, placed on the selected label's own box. Decorative, so it
                   is hidden from assistive technology and takes no pointer events. -->
              <span
                class="tabs__indicator"
                :class="{ 'is-placed': indicatorPosition, 'is-moving': indicatorMoving }"
                :style="indicatorStyle"
                aria-hidden="true"
              ></span>
            </nav>
            <p class="content__hint muted">{{ activeHint }}</p>

            <!-- One panel, named by the tab that controls it. The panels stay behind
                 v-if so a chart is never created inside a hidden container. -->
            <div :id="panelId(activeTab)" role="tabpanel" :aria-labelledby="tabId(activeTab)">
              <BaseCasePanel v-if="activeTab === 'baseCase'" />
              <CostEffectivenessPanel v-else-if="activeTab === 'ce'" />
              <SensitivityPanel v-else-if="activeTab === 'sensitivity'" />
              <BudgetImpactPanel v-else-if="activeTab === 'budget'" />
              <SurvivalPanel v-else-if="activeTab === 'survival'" />
              <ValueOfInformationPanel v-else-if="activeTab === 'voi'" />
              <ReadinessPanel v-else-if="activeTab === 'readiness'" />
              <ValueBasedPricePanel v-else-if="activeTab === 'valueBasedPrice'" />
              <HtaSummaryPanel v-else-if="activeTab === 'hta'" />
            </div>
          </section>
        </div>
      </template>

      <!-- The download view is named, not the leftover branch: as a bare v-else it
           also rendered under the dashboard, so every analysis tab had the panel
           below it and scrolling down reached it. Each page names itself here, and
           leaving one unmounts its view. -->
      <OpenHealthHomeView v-if="page === 'openhealth'" />
      <AboutView v-else-if="page === 'about'" />
      <!-- The blog is one page with two states rather than two pages: the index
           when no post is open, and one post when the address names one. Both
           branches are named, and a post address that names no post is still the
           post's branch, which answers it with its own not-found state. -->
      <BlogIndexView v-else-if="page === 'blog' && !postSlug" />
      <BlogPostView v-else-if="page === 'blog'" />
      <HomeView v-else-if="page === 'home'" />
      <TutorialView v-else-if="page === 'tutorial'" />
      <ProjectDescriptionView v-else-if="page === 'description'" />
      <DownloadResultsView v-else-if="page === 'export'" />
    </div>

    <!-- One app-wide loading indicator, above every page. It shows itself only
         when an operation outlives its grace period; see the component. -->
    <AppLoadingIndicator />

    <!-- One app-wide download notice, above every page: the per-tab CSV exports
         report themselves here, and the Download results view has its own status
         line on its page instead, so no export is reported twice. -->
    <DownloadNotice />

    <!-- The landing page's arrival into the app, above everything while it runs.
         It is decoration only - aria-hidden, nothing focusable, no pointer
         events - so the app it is dissolving over is live underneath it. -->
    <LaunchTransition />

    <!-- The once-per-session welcome question. It reuses the app's existing
         modal pattern, and closing it never blocks the app: the page underneath
         is already the Home screen. It arrives and leaves through the shared
         dialog transition. -->
    <Transition :name="DIALOG_TRANSITION_NAME" @leave="onDialogLeave">
      <div
        v-if="welcomeOpen"
        class="modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="welcome-title"
        @keydown="onWelcomeKeydown"
      >
        <div class="modal__backdrop" @click="dismissWelcome()"></div>
        <div class="modal__panel modal__panel--welcome">
          <h2 id="welcome-title" class="modal__title">New to health economics?</h2>
          <p class="page__prose">
            Take the short guided tutorial to learn the main ideas before using the full
            analysis.
          </p>
          <div class="tutorial__nav">
            <button
              ref="welcomeTutorial"
              type="button"
              class="btn btn--success"
              @click="welcomeStartTutorial()"
            >
              Start tutorial
            </button>
            <button type="button" class="btn btn--primary" @click="welcomeOpenAnalysis()">
              Open analysis
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>
