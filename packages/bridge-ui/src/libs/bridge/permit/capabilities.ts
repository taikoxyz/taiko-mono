import { getBytecode, readContract } from '@wagmi/core';
import {
  type Address,
  BaseError,
  ContractFunctionRevertedError,
  ContractFunctionZeroDataError,
  domainSeparator,
  ExecutionRevertedError,
  type Hex,
  zeroAddress,
} from 'viem';

import { erc20VaultAbi } from '$abi';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { erc20PermitAbi } from './abi';
import { NON_STANDARD_PERMIT_TOKENS_BY_CHAIN } from './constants';

const log = getLogger('bridge:permit:capabilities');

/** The EIP-712 domain a token's `permit` verifies against */
export type PermitDomain = {
  name: string;
  version: string;
  chainId: number;
  verifyingContract: Address;
};

/** The two signature flows `ERC20Vault` offers */
export type PermitMethod = 'permit' | 'permit2';

/**
 * Everything here is a property of a deployment, not of a session, so each answer is kept
 * for as long as the page lives. A negative answer from the contract itself is kept too: a
 * vault that has no `PERMIT2()` today does not grow one until its proxy is upgraded, and
 * the user reloads long before that. A transport failure is not an answer and is not kept.
 */
const vaultPermit2ByChain = new Map<string, Address | null>();
const permit2DeployedByChain = new Map<string, boolean>();
const permitDomainByToken = new Map<string, PermitDomain | null>();
/** Flows a wallet failed on-chain for a token this session, so the plan stops offering them */
const unusableByWallet = new Set<string>();

const keyOf = (chainId: number, address: Address) => `${chainId}:${address.toLowerCase()}`;

/**
 * @dev Whether a failed read is the contract's answer rather than the transport's. viem wraps
 *      every readContract failure in a ContractFunctionExecutionError, so the distinction is
 *      in the cause: a revert, with data or without, or a call that returned no data at all.
 *      An RPC that could not be reached or rate-limited the call is none of these.
 * @param error What readContract rejected with
 * @return answered_ Whether the contract itself refused the call
 */
const contractAnswered = (error: unknown) =>
  error instanceof BaseError &&
  error.walk(
    (cause) =>
      cause instanceof ContractFunctionRevertedError ||
      cause instanceof ContractFunctionZeroDataError ||
      cause instanceof ExecutionRevertedError,
  ) !== null;

/**
 * @dev Whether the vault on this chain has the permit entrypoints, and which Permit2 it pulls
 *      through. Only the upgraded implementation answers `PERMIT2()`: today's proxies revert,
 *      which is what keeps the UI on the plain approve/sendToken path until the upgrade
 *      lands, with no configuration to flip on either side.
 * @param chainId The source chain
 * @param vault The ERC20 vault on it
 * @return permit2_ The Permit2 address the vault uses, or null when the vault has no permit support
 */
export async function getVaultPermit2(chainId: number, vault: Address): Promise<Address | null> {
  const key = keyOf(chainId, vault);
  const known = vaultPermit2ByChain.get(key);
  if (known !== undefined) return known;

  try {
    const answer = await readContract(config, {
      abi: erc20VaultAbi,
      address: vault,
      chainId,
      functionName: 'PERMIT2',
    });
    // A vault that names no Permit2 has no Permit2 flow, whatever else it answers
    const permit2 = answer === zeroAddress ? null : answer;
    vaultPermit2ByChain.set(key, permit2);
    return permit2;
  } catch (error) {
    // The contract answered, with a revert: the implementation predates the permit
    // entrypoints. An RPC that could not be reached says nothing, so it is asked again
    if (contractAnswered(error)) vaultPermit2ByChain.set(key, null);
    log(`vault ${vault} on chain ${chainId} has no permit support`, error);
    return null;
  }
}

/**
 * @dev Whether Permit2 has code on this chain. It is deployed at the same address everywhere
 *      through the deterministic deployer, but not necessarily yet: the vault's
 *      `sendTokenWithPermit2` reverts on a chain without it, so that path is not offered there.
 * @param chainId The source chain
 * @param permit2 The Permit2 address the vault reported
 * @return deployed_ Whether there is code at the address
 */
export async function isPermit2Deployed(chainId: number, permit2: Address): Promise<boolean> {
  const key = keyOf(chainId, permit2);
  const known = permit2DeployedByChain.get(key);
  if (known !== undefined) return known;

  try {
    const code = await getBytecode(config, { address: permit2, chainId });
    const deployed = code !== undefined && code !== '0x';
    permit2DeployedByChain.set(key, deployed);
    return deployed;
  } catch (error) {
    log(`could not read Permit2 code on chain ${chainId}`, error);
    return false;
  }
}

/**
 * @dev Whether a token is one whose `permit` looks like EIP-2612 but is not.
 * @param chainId The chain the token lives on
 * @param token The token
 * @return nonStandard_ Whether the token is on the denylist
 */
export function isNonStandardPermitToken(chainId: number, token: Address): boolean {
  const denied = NON_STANDARD_PERMIT_TOKENS_BY_CHAIN[chainId] ?? [];
  return denied.some((address) => address.toLowerCase() === token.toLowerCase());
}

/**
 * @dev The EIP-712 domain a token's EIP-2612 `permit` verifies against, found by probing the
 *      token rather than from a list, so imported tokens and every bridged token qualify.
 *
 *      A token that lacks `nonces()` or `DOMAIN_SEPARATOR()` has no permit. One that has
 *      them states its domain through ERC-5267 when it can; otherwise its `name()` is tried
 *      with the versions in circulation. Either way the candidate domain is accepted only if
 *      it hashes to the separator the token reports: a signature over any other domain is
 *      one the token rejects, and the vault would then revert with VAULT_PERMIT_NO_ALLOWANCE
 *      after the user has already signed.
 *
 *      Only the token's own answer is kept; a read the RPC failed is rethrown, so nothing
 *      is decided, or remembered, from it.
 *
 * @param chainId The chain the token lives on
 * @param token The token
 * @param owner An address to read a nonce for; the value is irrelevant, the read must exist
 * @return domain_ The domain to sign over, or null when the token has no usable permit
 */
export async function getPermitDomain(chainId: number, token: Address, owner: Address): Promise<PermitDomain | null> {
  if (isNonStandardPermitToken(chainId, token)) return null;

  const key = keyOf(chainId, token);
  const known = permitDomainByToken.get(key);
  if (known !== undefined) return known;

  // Kept only when it is the token's answer: the probe rethrows a transport failure, and
  // nothing about the token is known then. A `null` remembered from one would send an
  // EIP-2612 token down the Permit2 path, and its user into an approval, for the session.
  // The failure propagates rather than passing for "no permit" for the same reason - the
  // vault and Permit2 probes may degrade to the plain vault approval, this one may not.
  const domain = await probePermitDomain(chainId, token, owner);
  permitDomainByToken.set(key, domain);
  return domain;
}

async function probePermitDomain(chainId: number, token: Address, owner: Address): Promise<PermitDomain | null> {
  const contract = { abi: erc20PermitAbi, address: token, chainId } as const;

  let separator: Hex;
  try {
    // Both must exist for the vault's `permit` call to have anything to work with
    [separator] = await Promise.all([
      readContract(config, { ...contract, functionName: 'DOMAIN_SEPARATOR' }),
      readContract(config, { ...contract, functionName: 'nonces', args: [owner] }),
    ]);
  } catch (error) {
    // A transport failure says nothing about the token and is left to the caller
    if (!contractAnswered(error)) throw error;
    log(`token ${token} on chain ${chainId} has no EIP-2612 permit`, error);
    return null;
  }

  const verified = (name: string, version: string): PermitDomain | null => {
    const domain = { name, version, chainId, verifyingContract: token };
    return domainSeparator({ domain }) === separator ? domain : null;
  };

  // ERC-5267 first: the token's own statement of its domain
  try {
    const [, name, version] = await readContract(config, { ...contract, functionName: 'eip712Domain' });
    const domain = verified(name, version);
    if (domain) return domain;
  } catch (error) {
    if (!contractAnswered(error)) throw error;
    // Not ERC-5267; the name is guessed below
  }

  try {
    const name = await readContract(config, { ...contract, functionName: 'name' });
    for (const version of ['1', '2']) {
      const domain = verified(name, version);
      if (domain) return domain;
    }
  } catch (error) {
    if (!contractAnswered(error)) throw error;
    log(`could not read the name of token ${token} on chain ${chainId}`, error);
  }

  log(`token ${token} on chain ${chainId} has a DOMAIN_SEPARATOR that matches no domain this UI can sign over`);
  return null;
}

/**
 * @dev Rules a signature flow out for a wallet and a token for the rest of the session, after
 *      the chain rejected it. The probes above say what a token offers, not whether it works:
 *      a token whose `permit` verifies something other than the standard message passes them
 *      and reverts in the vault, and a wallet that cannot sign typed data fails every token.
 *      Keyed by wallet as well, so a capable wallet connected later gets its own try. From
 *      here on the plan falls through to the next flow, and the Approve button is back.
 * @param chainId The chain the token lives on
 * @param token The token
 * @param owner The wallet that signed
 * @param method The flow that failed
 */
export function markPermitUnusable(chainId: number, token: Address, owner: Address, method: PermitMethod) {
  unusableByWallet.add(`${keyOf(chainId, token)}:${owner.toLowerCase()}:${method}`);
}

/**
 * @dev Whether a signature flow has been ruled out for a wallet and a token this session.
 * @param chainId The chain the token lives on
 * @param token The token
 * @param owner The wallet that would sign
 * @param method The flow to ask about
 * @return unusable_ Whether markPermitUnusable was called for it
 */
export function isPermitUnusable(chainId: number, token: Address, owner: Address, method: PermitMethod): boolean {
  return unusableByWallet.has(`${keyOf(chainId, token)}:${owner.toLowerCase()}:${method}`);
}

/** @dev Forgets every cached answer. For tests, which otherwise share them across cases. */
export function resetPermitCapabilities() {
  vaultPermit2ByChain.clear();
  permit2DeployedByChain.clear();
  permitDomainByToken.clear();
  unusableByWallet.clear();
}
