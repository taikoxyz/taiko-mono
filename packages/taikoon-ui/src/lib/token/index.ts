import { taikoonTokenAddress } from '../../generated/abi'
import { web3modal } from '../../lib/connect'
import type { IChainId } from '../../types'
import { balanceOf } from './balanceOf'
import { calculateFreeMints } from './calculateFreeMints'
import { canFreeMint } from './canFreeMint'
import { estimateMintGasCost } from './estimateMintGasCost'
import { maxSupply } from './maxSupply'
import { mint } from './mint'
import { minter } from './minter'
import { name } from './name'
import { ownerOf } from './ownerOf'
import { symbol } from './symbol'
import { tokenOfOwner } from './tokenOfOwner'
import { tokenURI } from './tokenURI'
import { totalSupply } from './totalSupply'
function address(): string {
    const { selectedNetworkId } = web3modal.getState()
    if (!selectedNetworkId) return ''

    const chainId = selectedNetworkId as IChainId
    return taikoonTokenAddress[chainId]
}

const Token = {
    symbol,
    name,
    totalSupply,
    minter,
    tokenURI,
    address,
    ownerOf,
    balanceOf,
    canFreeMint,
    calculateFreeMints,
    maxSupply,
    mint,
    tokenOfOwner,
    estimateMintGasCost,
}

export default Token
