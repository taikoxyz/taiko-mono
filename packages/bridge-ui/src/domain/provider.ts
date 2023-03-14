import { ethers } from 'ethers';
import { CHAIN_ID_MAINNET, CHAIN_ID_TAIKO, L1_RPC, L2_RPC } from './chain';

// Will help us to map from chain id to RPC provider
export const providers = new Map<number, ethers.providers.JsonRpcProvider>();

providers.set(CHAIN_ID_MAINNET, new ethers.providers.JsonRpcProvider(L1_RPC));
providers.set(CHAIN_ID_TAIKO, new ethers.providers.JsonRpcProvider(L2_RPC));
