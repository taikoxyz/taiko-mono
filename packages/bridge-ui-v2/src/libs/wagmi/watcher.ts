import { watchAccount, watchNetwork } from '@wagmi/core'
import { getLogger } from '../logger'

const { log, logerr } = getLogger('wagmi/watcher')

let isWatching = false
let unWatchNetwork: () => void
let unWatchAccount: () => void

export function startWatching() {
  if (!isWatching) {
    // Action for subscribing to network changes.
    // See https://wagmi.sh/core/actions/watchNetwork
    unWatchNetwork = watchNetwork((data) => {
      logerr(data)
    })

    // Action for subscribing to account changes.
    // See https://wagmi.sh/core/actions/watchAccount
    unWatchAccount = watchAccount((data) => {
      logerr(data)
    })

    isWatching = true
  }
}

export function stopWatching() {
  unWatchNetwork()
  unWatchAccount()
  isWatching = false
}
