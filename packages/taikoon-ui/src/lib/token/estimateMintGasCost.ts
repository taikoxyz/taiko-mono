import { formatGwei } from 'viem'

import getProof from '$lib/whitelist/getProof'

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi'
import type { IChainId } from '../../types'
import { web3modal } from '../connect'
import estimateContractGas from '../wagmi/estimateContractGas'
import { canFreeMint } from './canFreeMint'
import { freeMintsLeft } from './mintsLeft'

export async function estimateMintGasCost({
    freeMintCount,
}: {
    freeMintCount: number
}): Promise<number> {
    if (freeMintCount === 0) return 0
    const { selectedNetworkId } = web3modal.getState()
    if (!selectedNetworkId) return -1
    const chainId = selectedNetworkId as IChainId

    const freeMintLeft = await freeMintsLeft()

    if (await canFreeMint()) {
        const proof = getProof()

        const gasEstimate = await estimateContractGas({
            abi: taikoonTokenAbi,
            address: taikoonTokenAddress[chainId],
            functionName: 'mint',
            args: [proof, BigInt(freeMintLeft), BigInt(freeMintCount)],
        })
        return parseFloat(formatGwei(gasEstimate))
    }
    return 0
}
