import { readContract } from '@wagmi/core'

import { config } from '$wagmi-config'

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi/'
import { web3modal } from '../../lib/connect'
import type { IChainId } from '../../types'

export async function minter(): Promise<string> {
    const { selectedNetworkId } = web3modal.getState()
    if (!selectedNetworkId) return ''

    const chainId = selectedNetworkId as IChainId

    const result = await readContract(config, {
        abi: taikoonTokenAbi,
        address: taikoonTokenAddress[chainId],
        functionName: 'minter',
        chainId,
    })

    return result as string
}
