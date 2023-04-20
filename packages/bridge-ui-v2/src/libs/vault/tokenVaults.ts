import {
  PUBLIC_L1_CHAIN_ID,
  PUBLIC_L1_TOKEN_VAULT_ADDRESS,
  PUBLIC_L2_CHAIN_ID,
  PUBLIC_L2_TOKEN_VAULT_ADDRESS,
} from '$env/static/public'

import type { TokenVaultsRecord } from './types'

export const tokenVaults: TokenVaultsRecord = {
  [PUBLIC_L1_CHAIN_ID]: PUBLIC_L1_TOKEN_VAULT_ADDRESS,
  [PUBLIC_L2_CHAIN_ID]: PUBLIC_L2_TOKEN_VAULT_ADDRESS,
}
