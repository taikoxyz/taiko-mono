import {
  PUBLIC_L1_CHAIN_ID,
  PUBLIC_L2_CHAIN_ID,
  PUBLIC_TEST_ERC20_TOKENS,
} from '$env/static/public'

import { jsonParseOrEmptyArray } from '../util/jsonParseOrEmptyArray'
import type { Token, TokenEnv } from './types'

export const ETHToken: Token = {
  name: 'Ether',
  addresses: {
    [PUBLIC_L1_CHAIN_ID]: '0x00',
    [PUBLIC_L2_CHAIN_ID]: '0x00',
  },
  decimals: 18,
  symbol: 'ETH',
}

export const TKOToken: Token = {
  name: 'Taiko',
  addresses: {
    [PUBLIC_L1_CHAIN_ID]: '0x00',
    [PUBLIC_L2_CHAIN_ID]: '0x00',
  },
  decimals: 18,
  symbol: 'TKO',
}

export const testERC20Tokens: Token[] = jsonParseOrEmptyArray<TokenEnv>(
  PUBLIC_TEST_ERC20_TOKENS,
).map(({ name, address, symbol }) => ({
  name,
  symbol,
  addresses: {
    [PUBLIC_L1_CHAIN_ID]: address,
    [PUBLIC_L2_CHAIN_ID]: '0x00',
  },
  decimals: 18,
}))

export const tokens = [ETHToken, ...testERC20Tokens]
