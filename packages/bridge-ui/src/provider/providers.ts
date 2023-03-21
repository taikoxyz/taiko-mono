import { ethers } from 'ethers';
import { L1_CHAIN_ID, L1_RPC, L2_CHAIN_ID, L2_RPC } from '../constants/envVars';

/**
 * Maps chain ID => JsonRpcProvider
 */
export const providers = {
  [L1_CHAIN_ID]: new ethers.providers.JsonRpcProvider(L1_RPC),
  [L2_CHAIN_ID]: new ethers.providers.JsonRpcProvider(L2_RPC),
};
