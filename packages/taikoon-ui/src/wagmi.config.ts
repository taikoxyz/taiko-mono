import { injected, walletConnect } from '@wagmi/connectors'
import { createConfig, http, reconnect } from '@wagmi/core'
import { hardhat, holesky } from '@wagmi/core/chains'

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public'

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID

const baseConfig = {
    chains: [hardhat, holesky],
    projectId,
    metadata: {},
    batch: {
        multicall: false,
    },
    transports: {
        [hardhat.id]: http('http://localhost:8545'),
        //[holesky.id]: http('https://1rpc.io/holesky'),
        [holesky.id]: http('https://ethereum-holesky.blockpi.network/v1/rpc/public'),
        //[holesky.id]: http('https://l1rpc.hekla.taiko.xyz/'),
    },
} as const

export const config = createConfig({
    ...baseConfig,
    connectors: [walletConnect({ projectId, showQrModal: false }), injected()],
})

export const publicConfig = createConfig(baseConfig)

reconnect(config)
