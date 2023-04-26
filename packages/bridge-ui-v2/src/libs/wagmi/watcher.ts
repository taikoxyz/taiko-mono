import { watchAccount, watchNetwork } from '@wagmi/core'

import { emitter } from '../emitter'
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
      log('Network', data)
      emitter.emit('networkChanged', data)
    })

    // Action for subscribing to account changes.
    // See https://wagmi.sh/core/actions/watchAccount
    unWatchAccount = watchAccount((data) => {
      log('Account', data)
      emitter.emit('accountChanged', data)
    })

    isWatching = true

    emitter.emit('nowWatching')
  }
}

export function stopWatching() {
  unWatchNetwork()
  unWatchAccount()
  isWatching = false

  emitter.emit('noLongerWatching')
}
