/**
 * Entry point
 */

import { startWatching } from '../libs/wagmi'

// Setting this to false turns your app into an SPA
// See https://kit.svelte.dev/docs/page-options#ssr
export const ssr = false

// Start watching for network and account changes
startWatching()
