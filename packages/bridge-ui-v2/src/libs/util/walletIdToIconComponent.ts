import type { ComponentType } from 'svelte'

import { MetaMaskIcon } from '../../components/icons'

export const walletIdToIconComponent: Record<string, ComponentType> = {
  metaMask: MetaMaskIcon,
  // coinbaseWallet: 'CoinbaseWalletIcon',
  // walletConnect: 'WalletConnectIcon',
}
