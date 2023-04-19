import { ethers } from 'ethers'

import {
  PUBLIC_L1_CHAIN_ID,
  PUBLIC_L1_RPC,
  PUBLIC_L2_CHAIN_ID,
  PUBLIC_L2_RPC,
} from '$env/static/public'

export const providers: Record<string, ethers.JsonRpcProvider> = {
  [PUBLIC_L1_CHAIN_ID]: new ethers.JsonRpcProvider(PUBLIC_L1_RPC, PUBLIC_L1_CHAIN_ID),
  [PUBLIC_L2_CHAIN_ID]: new ethers.JsonRpcProvider(PUBLIC_L2_RPC, PUBLIC_L2_CHAIN_ID),
}
