import type { NFT, Token } from './types';

// Tokens whose approve() reverts when changing a non-zero allowance to another non-zero value
// (USDT-style), so the allowance must be reset to 0 before it can be raised.
// EVM addresses are chain-local, so each entry is scoped to the chain it is deployed on.
const APPROVAL_RESET_TOKENS_BY_CHAIN: Record<number, string[]> = {
  // Ethereum mainnet USDT
  1: ['0xdAC17F958D2ee523a2206206994597C13D831ec7'],
};

// Test tokens with the same behavior, only known by symbol
const APPROVAL_RESET_TOKEN_SYMBOLS = ['tUSDT'];

export function tokenNeedsAllowanceReset(token: Maybe<Token | NFT>, chainId: Maybe<number>): boolean {
  if (!token) return false;

  const address = chainId ? token.addresses?.[chainId] : undefined;
  const chainAddresses = chainId ? APPROVAL_RESET_TOKENS_BY_CHAIN[chainId] : undefined;
  if (address && chainAddresses?.some((resetAddress) => resetAddress.toLowerCase() === address.toLowerCase())) {
    return true;
  }

  return APPROVAL_RESET_TOKEN_SYMBOLS.includes(token.symbol);
}
