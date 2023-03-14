import { ethers } from 'ethers';
import {
  CHAIN_ID_MAINNET,
  CHAIN_ID_TAIKO,
  L1_RPC,
  L2_RPC,
} from '../domain/chain';

export const providersMap = new Map([
  [CHAIN_ID_MAINNET, new ethers.providers.JsonRpcProvider(L1_RPC)],
  [CHAIN_ID_TAIKO, new ethers.providers.JsonRpcProvider(L2_RPC)],
]);
