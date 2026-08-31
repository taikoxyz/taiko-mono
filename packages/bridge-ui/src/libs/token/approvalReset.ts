import type { NFT, Token } from './types';

// Tokens whose approve() reverts when changing a non-zero allowance to another non-zero value
// (USDT-style), so the allowance must be reset to 0 before it can be raised.
// L1 mainnet USDT
const APPROVAL_RESET_TOKEN_ADDRESSES = ['0xdAC17F958D2ee523a2206206994597C13D831ec7'].map((address) =>
  address.toLowerCase(),
);

// Test tokens with the same behavior, only known by symbol
const APPROVAL_RESET_TOKEN_SYMBOLS = ['tUSDT'];

export function tokenNeedsAllowanceReset(token: Maybe<Token | NFT>, chainId: Maybe<number>): boolean {
  if (!token) return false;

  const address = chainId ? token.addresses?.[chainId] : undefined;
  if (address && APPROVAL_RESET_TOKEN_ADDRESSES.includes(address.toLowerCase())) return true;

  return APPROVAL_RESET_TOKEN_SYMBOLS.includes(token.symbol);
}
