/**
 * Light/dark theme plus the chart palette.
 *
 * The colours reproduce the palette of the Shiny reference application
 * (app.R) so the two presentation layers look like one project: teal primary
 * #176b73 on #f4f7f9 in light mode, #7fd1d8 on #101a1f in dark mode. Charts read
 * their colours from `useChartPalette()` instead of hard-coding hex values, so
 * a theme change reaches every chart without touching the chart options.
 */

import { computed, ref, watchEffect } from 'vue'

export type ThemeName = 'light' | 'dark'

const STORAGE_KEY = 'eqalb.theme'

/**
 * The app is dark unless the visitor has explicitly chosen a theme. A valid saved
 * choice - light or dark - always wins; the operating system's preference is not
 * consulted, and a browser that refuses storage is dark for the visit. The
 * pre-paint script in index.html applies the same rule before Vue mounts.
 */
function storedTheme(): ThemeName | null {
  try {
    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored === 'light' || stored === 'dark') return stored
  } catch {
    // No readable preference: the default applies.
  }
  return null
}

/**
 * Only an explicit selection is saved, so the default is never written down as if
 * it had been chosen. Saving is best-effort: when storage is unavailable the
 * button still switches the theme for the current visit.
 */
function saveTheme(value: ThemeName): void {
  try {
    localStorage.setItem(STORAGE_KEY, value)
  } catch {
    /* the current visit still switches */
  }
}

const theme = ref<ThemeName>(storedTheme() ?? 'dark')

watchEffect(() => {
  if (typeof document === 'undefined') return
  document.documentElement.dataset.theme = theme.value
})

export interface ChartPalette {
  isDark: boolean
  /** Chart background: the panel colour, so masked areas blend in. */
  panel: string
  text: string
  muted: string
  border: string
  grid: string
  accent: string
  /** Usual-care arm in survival and contrast charts. */
  control: string
  /** eQalb arm. */
  intervention: string
  positive: string
  negative: string
  neutral: string
  /** Confidence-band fill for survival curves. */
  band: string
  tooltipBg: string
  tooltipText: string
  series: string[]
}

const LIGHT: ChartPalette = {
  isDark: false,
  panel: '#ffffff',
  text: '#1f2d3d',
  muted: '#546e7a',
  border: '#cbd5e1',
  grid: '#e2e8f0',
  accent: '#176b73',
  control: '#546e7a',
  intervention: '#176b73',
  positive: '#2e7d4f',
  negative: '#b3261e',
  neutral: '#94a3b8',
  band: 'rgba(23, 107, 115, 0.16)',
  tooltipBg: 'rgba(255, 255, 255, 0.97)',
  tooltipText: '#1f2d3d',
  series: ['#176b73', '#b26a00', '#2e7d4f', '#7b5ea7', '#b3261e', '#546e7a'],
}

const DARK: ChartPalette = {
  isDark: true,
  panel: '#16242c',
  text: '#e6edf1',
  muted: '#9fb3bd',
  border: '#37505c',
  grid: '#2b3d47',
  accent: '#7fd1d8',
  control: '#9fb3bd',
  intervention: '#7fd1d8',
  positive: '#4caf7d',
  negative: '#e57373',
  neutral: '#64748b',
  band: 'rgba(127, 209, 216, 0.18)',
  tooltipBg: 'rgba(22, 36, 44, 0.97)',
  tooltipText: '#e6edf1',
  series: ['#7fd1d8', '#e0a44a', '#4caf7d', '#a98ede', '#e57373', '#9fb3bd'],
}

export function useTheme() {
  return {
    theme,
    isDark: computed(() => theme.value === 'dark'),
    toggle: () => {
      theme.value = theme.value === 'dark' ? 'light' : 'dark'
      saveTheme(theme.value)
    },
    set: (value: ThemeName) => {
      theme.value = value
      saveTheme(value)
    },
  }
}

export function useChartPalette() {
  return computed(() => (theme.value === 'dark' ? DARK : LIGHT))
}

/** Shared ECharts scaffolding (axis, text, tooltip) for one palette. */
export function chartBase(palette: ChartPalette) {
  return {
    backgroundColor: 'transparent',
    textStyle: { color: palette.text, fontFamily: 'inherit' },
    tooltip: {
      backgroundColor: palette.tooltipBg,
      borderColor: palette.border,
      textStyle: { color: palette.tooltipText },
    },
    axisStyle: {
      axisLine: { lineStyle: { color: palette.border } },
      axisLabel: { color: palette.muted },
      splitLine: { lineStyle: { color: palette.grid, type: 'dashed' as const } },
      nameTextStyle: { color: palette.muted },
    },
  }
}
