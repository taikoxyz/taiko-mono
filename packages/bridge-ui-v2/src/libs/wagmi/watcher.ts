import { watchAccount, watchNetwork } from '@wagmi/core'

import { account } from '../../stores/account'
import { network } from '../../stores/network'
import { getLogger } from '../logger'

const log = getLogger('wagmi/watcher')

let isWatching = false
let unWatchNetwork: () => void
let unWatchAccount: () => void

export function startWatching() {
  if (!isWatching) {
    // Action for subscribing to network changes.
    // See https://wagmi.sh/core/actions/watchNetwork
    unWatchNetwork = watchNetwork((data) => {
      log('Network changed', data)
      network.set(data)
    })

    // Action for subscribing to account changes.
    // See https://wagmi.sh/core/actions/watchAccount
    unWatchAccount = watchAccount((data) => {
      log('Account changed', data)
      account.set(data)
    })

    isWatching = true
  }
}

export function stopWatching() {
  unWatchNetwork()
  unWatchAccount()
  isWatching = false
}
