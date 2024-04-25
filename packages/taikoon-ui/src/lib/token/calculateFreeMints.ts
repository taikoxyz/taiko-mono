import { getAccount, readContract } from '@wagmi/core'

import getProof from '$lib/whitelist/getProof'

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi'
import type { IAddress } from '../../types'
import getConfig from '../wagmi/getConfig'
import { balanceOf } from './balanceOf'
import { freeMintsLeft } from './mintsLeft'

export async function calculateFreeMints(): Promise<number> {
    const { config, chainId } = getConfig()

    const account = getAccount(config)
    if (!account.address) return 0
    const accountAddress = account.address as IAddress

    const freeMintCount = await freeMintsLeft()
    const balance = await balanceOf(accountAddress)

    const mintCount = freeMintCount - balance

    if (mintCount <= 0) {
        return 0
    }
    const proof = getProof(accountAddress)

    if (proof.length === 0) {
        return 0
    }

    const result = await readContract(config, {
        abi: taikoonTokenAbi,
        address: taikoonTokenAddress[chainId],
        functionName: 'calculateFreeMints',
        args: [accountAddress, proof, BigInt(100)],
        chainId,
    })

    return parseInt(result.toString())
}
