import { constants } from 'ethers'

import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID, PUBLIC_TEST_ERC20_TOKENS } from '$env/static/public'

import { jsonParseOrEmptyArray } from '../util/jsonParseOrEmptyArray'
import type { Token, TokenEnv } from './types'

export const ETHToken: Token = {
  name: 'Ether',
  addresses: {
    [PUBLIC_L1_CHAIN_ID]: constants.AddressZero,
    [PUBLIC_L2_CHAIN_ID]: constants.AddressZero,
  },
  decimals: 18,
  symbol: 'ETH',
}

export const TKOToken: Token = {
  name: 'Taiko',
  addresses: {
    [PUBLIC_L1_CHAIN_ID]: constants.AddressZero,
    [PUBLIC_L2_CHAIN_ID]: constants.AddressZero,
  },
  decimals: 18,
  symbol: 'TKO',
}

export const testERC20Tokens: Token[] = jsonParseOrEmptyArray<TokenEnv>(PUBLIC_TEST_ERC20_TOKENS).map(
  ({ name, address, symbol }) => ({
    name,
    symbol,
    addresses: {
      [PUBLIC_L1_CHAIN_ID]: address,
      [PUBLIC_L2_CHAIN_ID]: constants.AddressZero,
    },
    decimals: 18,
  }),
)

export const tokens = [ETHToken, ...testERC20Tokens]

export function isEther(token: Token): boolean {
  return token.symbol.toLowerCase() === ETHToken.symbol.toLowerCase()
}

export function isTKO(token: Token): boolean {
  return token.symbol.toLowerCase() === TKOToken.symbol.toLowerCase()
}

export function isERC20(token: Token): boolean {
  return !isEther(token) && !isTKO(token)
}
