import { watchAccount, watchNetwork } from '@wagmi/core'

let isWatching = false
let unWatchNetwork: () => void
let unWatchAccount: () => void

export function startWatching() {
  if (!isWatching) {
    // Action for subscribing to network changes.
    // See https://wagmi.sh/core/actions/watchNetwork
    unWatchNetwork = watchNetwork((data) => {
      console.log('watchNetwork', data)
    })

    // Action for subscribing to account changes.
    // See https://wagmi.sh/core/actions/watchAccount
    unWatchAccount = watchAccount((data) => {
      console.log('watchAccount', data)
    })

    isWatching = true
  }
}

export function stopWatching() {
  unWatchNetwork()
  unWatchAccount()
  isWatching = false
}
