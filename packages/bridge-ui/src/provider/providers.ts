import { ethers } from 'ethers';
import type { ChainID } from '../domain/chain';
import { L1_CHAIN_ID, L1_RPC, L2_CHAIN_ID, L2_RPC } from '../constants/envVars';

export const providers: Record<
  ChainID,
  ethers.providers.StaticJsonRpcProvider
> = {
  [L1_CHAIN_ID]: new ethers.providers.StaticJsonRpcProvider(L1_RPC),
  [L2_CHAIN_ID]: new ethers.providers.StaticJsonRpcProvider(L2_RPC),
};
