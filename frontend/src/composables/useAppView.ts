/**
 * Which top-level page the shell is showing: the Home screen and its two
 * subviews, or the analysis dashboard.
 *
 * This is deliberately a single shared ref rather than a router: the project has
 * no routing dependency, and one value is all the shell needs. Nothing here
 * touches model state, so switching pages never changes an input or a result.
 */

import { ref } from 'vue'
import { installDisclosureEscape } from './useDisclosure'

export type AppPage = 'home' | 'tutorial' | 'description' | 'export' | 'dashboard'

const page = ref<AppPage>('home')

export function useAppView() {
  // Every screen calls this composable, so it is where the app-wide disclosure
  // keyboard behaviour is installed (see useDisclosure.ts for why).
  installDisclosureEscape()

  return {
    page,
    show(next: AppPage): void {
      page.value = next
    },
    goHome(): void {
      page.value = 'home'
    },
  }
}
