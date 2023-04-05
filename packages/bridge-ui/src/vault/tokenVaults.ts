import type { Address, ChainID } from '../domain/chain';
import {
  L1_CHAIN_ID,
  L1_TOKEN_VAULT_ADDRESS,
  L2_CHAIN_ID,
  L2_TOKEN_VAULT_ADDRESS,
} from '../constants/envVars';

export const tokenVaults: Record<ChainID, Address> = {
  [L1_CHAIN_ID]: L1_TOKEN_VAULT_ADDRESS,
  [L2_CHAIN_ID]: L2_TOKEN_VAULT_ADDRESS,
};
