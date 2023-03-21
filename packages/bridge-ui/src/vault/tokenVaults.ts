import {
  L1_CHAIN_ID,
  L1_TOKEN_VAULT_ADDRESS,
  L2_CHAIN_ID,
  L2_TOKEN_VAULT_ADDRESS,
} from '../constants/envVars';

/**
 * Maps chain ID => TokenVault contract address
 */
export const tokenVaults = {
  [L1_CHAIN_ID]: L1_TOKEN_VAULT_ADDRESS,
  [L2_CHAIN_ID]: L2_TOKEN_VAULT_ADDRESS,
};
