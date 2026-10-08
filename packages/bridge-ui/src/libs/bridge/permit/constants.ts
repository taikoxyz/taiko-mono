import type { Address } from 'viem';

/**
 * Uniswap's Permit2, deployed at the same address on every chain through the deterministic
 * deployer, and the only spender the unlimited approval is ever made to. `ERC20Vault.PERMIT2`
 * is the same compile-time constant; the vault is asked for it only to learn whether it has the
 * permit entrypoints at all, never to learn whom to approve.
 */
export const PERMIT2_ADDRESS: Address = '0x000000000022D473030F116dDEE9F6B43aC78BA3';

/**
 * How long a permit signature stays valid once signed. Long enough for a wallet prompt and a
 * slow inclusion, short enough that a signature the user abandons cannot be picked up days
 * later: an EIP-2612 permit is replayable by anyone against the token until it expires.
 */
export const PERMIT_SIGNATURE_TTL_SECONDS = 30 * 60;

/**
 * Tokens whose `permit` exists but is not the EIP-2612 one, keyed by chain. `ERC20Vault` calls
 * the standard `permit(owner, spender, value, deadline, v, r, s)`, so on these the call is
 * swallowed and the send reverts with `VAULT_PERMIT_NO_ALLOWANCE`. The runtime probe cannot
 * tell them apart - they expose `nonces()` and `DOMAIN_SEPARATOR()` like any other permit
 * token - so they are named here and go through Permit2 or a plain approval instead.
 */
export const NON_STANDARD_PERMIT_TOKENS_BY_CHAIN: Record<number, Address[]> = {
  // Ethereum mainnet DAI: permit(holder, spender, nonce, expiry, allowed, v, r, s)
  1: ['0x6B175474E89094C44Da98b954EedeAC495271d0F'],
};
