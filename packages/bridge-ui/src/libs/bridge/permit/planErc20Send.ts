import { readContract } from '@wagmi/core';
import { type Address, maxUint256 } from 'viem';

import { isSmartContract } from '$libs/util/isSmartContract';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { erc20PermitAbi } from './abi';
import {
  getPermitDomain,
  getVaultPermit2,
  isPermit2Deployed,
  isPermitUnusable,
  type PermitDomain,
} from './capabilities';

const log = getLogger('bridge:permit:planErc20Send');

/** How an ERC20 leaves the wallet, decided once per send from what the chain says right now */
export type ERC20SendPlan =
  /** A standing allowance for the vault covers the amount: plain `sendToken`, nothing to sign */
  | { method: 'sendToken' }
  /** The token has EIP-2612: one signature, then `sendTokenWithPermit` */
  | { method: 'permit'; domain: PermitDomain }
  /** Permit2 already holds an allowance: one signature, then `sendTokenWithPermit2` */
  | { method: 'permit2'; permit2: Address }
  /**
   * An approval transaction comes first. To the vault for the exact amount, which is the
   * whole story on a vault without permit support; or, once, to Permit2 for everything, after
   * which every later bridge of the token is a signature away.
   */
  | { method: 'approve'; spender: Address; amount: bigint; currentAllowance: bigint; target: 'vault' | 'permit2' };

export type PlanErc20SendArgs = {
  chainId: number;
  token: Address;
  owner: Address;
  vault: Address;
  amount: bigint;
};

/**
 * @dev Picks the send flow for an ERC20, in the order that costs the user least.
 *
 *      1. A standing vault allowance is spent as before. It is the cheapest path, and the
 *         vault itself prefers it: an EIP-2612 permit *sets* the allowance, so it would
 *         replace a larger standing one with the amount and spend it to zero.
 *      2. A vault without permit support - every deployment until its proxy is upgraded - or
 *         a contract wallet, which cannot produce the ECDSA signature `permit` recovers, gets
 *         the plain approval it always got.
 *      3. EIP-2612 next: no approval of anything, ever, and it covers every bridged token.
 *      4. Permit2 for the rest, against an allowance the user may already hold from another
 *         app; failing that, one unlimited approval of Permit2 so it never comes up again.
 *
 *      Both the buttons and the send itself are driven off this, from the same arguments,
 *      so what the user was shown is what is sent.
 *
 * @param args The token, its owner, the vault and the amount
 * @return plan_ The flow to take
 */
export async function planErc20Send({
  chainId,
  token,
  owner,
  vault,
  amount,
}: PlanErc20SendArgs): Promise<ERC20SendPlan> {
  const allowanceFor = (spender: Address) =>
    readContract(config, {
      abi: erc20PermitAbi,
      address: token,
      chainId,
      functionName: 'allowance',
      args: [owner, spender],
    });

  const vaultAllowance = await allowanceFor(vault);
  if (vaultAllowance >= amount) return { method: 'sendToken' };

  const approveVault: ERC20SendPlan = {
    method: 'approve',
    spender: vault,
    amount,
    currentAllowance: vaultAllowance,
    target: 'vault',
  };

  const permit2 = await getVaultPermit2(chainId, vault);
  if (!permit2) return approveVault;

  if (await isSmartContract(owner, chainId)) {
    log('contract wallet, keeping the approval flow');
    return approveVault;
  }

  if (!isPermitUnusable(chainId, token, 'permit')) {
    const domain = await getPermitDomain(chainId, token, owner);
    if (domain) return { method: 'permit', domain };
  }

  if (!isPermitUnusable(chainId, token, 'permit2') && (await isPermit2Deployed(chainId, permit2))) {
    const permit2Allowance = await allowanceFor(permit2);
    if (permit2Allowance >= amount) return { method: 'permit2', permit2 };
    return {
      method: 'approve',
      spender: permit2,
      amount: maxUint256,
      currentAllowance: permit2Allowance,
      target: 'permit2',
    };
  }

  return approveVault;
}
