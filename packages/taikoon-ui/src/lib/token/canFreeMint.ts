import { getAccount, readContract } from '@wagmi/core'

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi'
import getConfig from '../../lib/wagmi/getConfig'
import type { IAddress } from '../../types'
import { freeMintsLeft } from './mintsLeft'

export async function canFreeMint(): Promise<boolean> {
    const { config, chainId } = getConfig()

    const account = getAccount(config)
    if (!account.address) return false
    const accountAddress = account.address as IAddress

    const freeMintCount = await freeMintsLeft()

    const result = await readContract(config, {
        abi: taikoonTokenAbi,
        address: taikoonTokenAddress[chainId],
        functionName: 'canFreeMint',
        args: [accountAddress, BigInt(freeMintCount)],
        chainId,
    })
    return result as boolean
}
