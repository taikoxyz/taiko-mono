import type { Address } from 'wagmi';

import {
  L1_CHAIN_ID,
  L1_TOKEN_VAULT_ADDRESS,
  L2_CHAIN_ID,
  L2_TOKEN_VAULT_ADDRESS,
} from '../constants/envVars';
import type { ChainID } from '../domain/chain';

export const tokenVaults: Record<ChainID, Address> = {
  [L1_CHAIN_ID]: L1_TOKEN_VAULT_ADDRESS,
  [L2_CHAIN_ID]: L2_TOKEN_VAULT_ADDRESS,
};
