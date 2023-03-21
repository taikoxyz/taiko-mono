import {
  L1_CHAIN_ID,
  L1_TOKEN_VAULT_ADDRESS,
  L2_CHAIN_ID,
  L2_TOKEN_VAULT_ADDRESS,
} from '../constants/envVars';

// TODO: does it need to be a map?
export const tokenVaultsMap = new Map([
  [L1_CHAIN_ID, L1_TOKEN_VAULT_ADDRESS],
  [L2_CHAIN_ID, L2_TOKEN_VAULT_ADDRESS],
]);
