import { getBlock, readContract } from '@wagmi/core';
import {
  type Address,
  bytesToBigInt,
  compactSignatureToSignature,
  type Hex,
  hexToCompactSignature,
  hexToSignature,
  type WalletClient,
} from 'viem';

import { config } from '$libs/wagmi';

import { erc20PermitAbi } from './abi';
import type { PermitDomain } from './capabilities';
import { PERMIT_SIGNATURE_TTL_SECONDS } from './constants';

/**
 * A typed-data signature the wallet did not produce - declined, or not supported at all - with
 * the wallet's own error as the cause. It marks where in a send the failure happened: a
 * provider's "no such method" answer means something only when it is this call that got it.
 * A plain Error rather than viem's, so that nothing importing this module depends on viem's
 * classes at load time; the wallet's wording is kept in the message, since a declined prompt
 * is recognised by it where a wallet does not report the refusal as viem's own error.
 */
export class TypedDataSigningError extends Error {
  override name = 'TypedDataSigningError';

  constructor(cause: unknown) {
    super(`The wallet did not sign the typed data: ${cause instanceof Error ? cause.message : String(cause)}`, {
      cause,
    });
  }
}

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

/**
 * @dev The deadline for a signature made now, from the chain's own clock. A wallet's machine
 *      can be well off, and a deadline the chain sees as already past does not fail loudly: the
 *      permit flow is ruled out with the blame on the token, and the Permit2 flow retries into
 *      the same expiry. The latest block is asked first; the local clock stands in when it
 *      cannot be read, since a blip there is no reason not to sign.
 * @param chainId The chain the signature is for
 * @return deadline_ The deadline in seconds
 */
export async function signingDeadline(chainId: number): Promise<bigint> {
  try {
    const { timestamp } = await getBlock(config, { chainId });
    return timestamp + BigInt(PERMIT_SIGNATURE_TTL_SECONDS);
  } catch {
    return permitDeadline();
  }
}

/**
 * @dev A 65-byte signature with `v` as 27 or 28. Permit2 hands `v` straight to `ecrecover`, so a
 *      signer that reports it as a parity bit is refused with InvalidSignature - and that would
 *      be read as a verdict on the token. A 64-byte (EIP-2098) signature is left to Permit2,
 *      which handles it itself.
 * @param signature What the wallet returned
 * @return signature_ The same signature, with `v` in the form `ecrecover` takes
 */
export const withRecoveryId = (signature: Hex): Hex => {
  if (signature.length !== 132) return signature;
  const v = Number.parseInt(signature.slice(130), 16);
  return v < 27 ? (`${signature.slice(0, 130)}${(v + 27).toString(16).padStart(2, '0')}` as Hex) : signature;
};

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
  const deadline = await signingDeadline(domain.chainId);

  const signature = await wallet
    .signTypedData({
      account: wallet.account,
      domain,
      types: PERMIT_TYPES,
      primaryType: 'Permit',
      message: { owner, spender, value: amount, nonce, deadline },
    })
    .catch((error) => {
      throw new TypedDataSigningError(error);
    });

  // `permit` takes the split form. A 64-byte EIP-2098 signature carries the parity bit in `s`
  // and is expanded first; a wallet may also report the recovery id as a parity bit, where
  // `permit` takes 27 or 28
  const parsed =
    signature.length === 130
      ? compactSignatureToSignature(hexToCompactSignature(signature))
      : hexToSignature(signature);
  const v = parsed.v ?? BigInt(27 + (parsed.yParity ?? 0));
  return { deadline, v: Number(v), r: parsed.r, s: parsed.s };
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
  const nonce = bytesToBigInt(globalThis.crypto.getRandomValues(new Uint8Array(32)));
  const deadline = await signingDeadline(chainId);

  const signature = await wallet
    .signTypedData({
      account: wallet.account,
      domain: { name: 'Permit2', chainId, verifyingContract: permit2 },
      types: PERMIT2_TYPES,
      primaryType: 'PermitTransferFrom',
      message: { permitted: { token, amount }, spender, nonce, deadline },
    })
    .catch((error) => {
      throw new TypedDataSigningError(error);
    });

  return { nonce, deadline, signature: withRecoveryId(signature) };
}
