import { readContract } from '@wagmi/core';
import { type Address, bytesToBigInt, type Hex, hexToSignature, type WalletClient } from 'viem';

import { config } from '$libs/wagmi';

import { erc20PermitAbi } from './abi';
import type { PermitDomain } from './capabilities';
import { PERMIT_SIGNATURE_TTL_SECONDS } from './constants';

/** The EIP-2612 `Permit` message */
export const PERMIT_TYPES = {
  Permit: [
    { name: 'owner', type: 'address' },
    { name: 'spender', type: 'address' },
    { name: 'value', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ],
} as const;

/**
 * Permit2's `PermitTransferFrom` message. `spender` is the contract that will call
 * `permitTransferFrom`, the vault here; it is bound into the signature although the vault's
 * entrypoint never takes it as an argument.
 */
export const PERMIT2_TYPES = {
  PermitTransferFrom: [
    { name: 'permitted', type: 'TokenPermissions' },
    { name: 'spender', type: 'address' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ],
  TokenPermissions: [
    { name: 'token', type: 'address' },
    { name: 'amount', type: 'uint256' },
  ],
} as const;

/**
 * @dev When a signature made now stops being valid, as the unix timestamp the contracts compare
 * @param now The current time in milliseconds
 * @return deadline_ The deadline in seconds
 */
export const permitDeadline = (now = Date.now()) => BigInt(Math.floor(now / 1000) + PERMIT_SIGNATURE_TTL_SECONDS);

export type SignedPermit = { deadline: bigint; v: number; r: Hex; s: Hex };

export type SignPermitArgs = {
  wallet: WalletClient;
  domain: PermitDomain;
  token: Address;
  spender: Address;
  amount: bigint;
};

/**
 * @dev Signs an EIP-2612 permit for the vault to consume in `sendTokenWithPermit`.
 * @param args The wallet that owns the tokens, the token's domain, the vault and the amount
 * @return permit_ The deadline and the split signature the vault's entrypoint takes
 */
export async function signPermit({ wallet, domain, token, spender, amount }: SignPermitArgs): Promise<SignedPermit> {
  if (!wallet.account) throw new Error('Wallet is not connected');
  const owner = wallet.account.address;

  // Read at signing time, not when the plan was made: a nonce is spent by any permit in between
  const nonce = await readContract(config, {
    abi: erc20PermitAbi,
    address: token,
    chainId: domain.chainId,
    functionName: 'nonces',
    args: [owner],
  });
  const deadline = permitDeadline();

  const signature = await wallet.signTypedData({
    account: wallet.account,
    domain,
    types: PERMIT_TYPES,
    primaryType: 'Permit',
    message: { owner, spender, value: amount, nonce, deadline },
  });

  const { r, s, v, yParity } = hexToSignature(signature);
  // A wallet may return the recovery id as a parity bit; `permit` takes 27 or 28
  return { deadline, v: Number(v ?? BigInt(27 + yParity)), r, s };
}

export type SignedPermit2Transfer = { nonce: bigint; deadline: bigint; signature: Hex };

export type SignPermit2TransferArgs = {
  wallet: WalletClient;
  chainId: number;
  permit2: Address;
  token: Address;
  spender: Address;
  amount: bigint;
};

/**
 * @dev Signs a Permit2 `SignatureTransfer` of exactly the amount, to the vault, for
 *      `sendTokenWithPermit2`.
 * @param args The wallet that owns the tokens, the chain, Permit2, the token, the vault and the amount
 * @return transfer_ The nonce, deadline and signature the vault's entrypoint takes
 */
export async function signPermit2Transfer({
  wallet,
  chainId,
  permit2,
  token,
  spender,
  amount,
}: SignPermit2TransferArgs): Promise<SignedPermit2Transfer> {
  if (!wallet.account) throw new Error('Wallet is not connected');

  // SignatureTransfer nonces are unordered: any unused uint256 works, and a random one does
  // not collide with anything this or another app has had the wallet sign
  const nonce = bytesToBigInt(crypto.getRandomValues(new Uint8Array(32)));
  const deadline = permitDeadline();

  const signature = await wallet.signTypedData({
    account: wallet.account,
    domain: { name: 'Permit2', chainId, verifyingContract: permit2 },
    types: PERMIT2_TYPES,
    primaryType: 'PermitTransferFrom',
    message: { permitted: { token, amount }, spender, nonce, deadline },
  });

  return { nonce, deadline, signature };
}
