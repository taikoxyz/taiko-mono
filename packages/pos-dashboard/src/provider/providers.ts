import { ethers } from 'ethers';

import { L1_CHAIN_ID, L1_RPC } from '../constants/envVars';
import type { ChainID } from '../domain/chain';

export const providers: Record<
  ChainID,
  ethers.providers.StaticJsonRpcProvider
> = {
  [L1_CHAIN_ID]: new ethers.providers.StaticJsonRpcProvider(
    L1_RPC,
    L1_CHAIN_ID,
  ),
};
