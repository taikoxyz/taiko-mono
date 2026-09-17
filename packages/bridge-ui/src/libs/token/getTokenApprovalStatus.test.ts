/**
 * The NFT branch answers one question for both standards. What it must never do is leave
 * the previous token's answer standing: Actions.svelte gates the Bridge button on
 * `allApproved`, so a stale `true` offers a bridge for a token nothing was read for.
 */
import { get } from 'svelte/store';

vi.mock('$bridgeConfig');
vi.mock('@wagmi/core');

const requiresApproval = vi.fn();
vi.mock('$libs/bridge', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/bridge')>()),
  bridges: {
    ERC721: { requiresApproval: (...args: unknown[]) => requiresApproval(...args) },
    ERC1155: { requiresApproval: (...args: unknown[]) => requiresApproval(...args) },
  },
}));
// The ERC20 branch is driven off the send plan; what the plan decides is pinned in its own
// tests. The rest of the module stays real: the bridge classes import it too
const planErc20Send = vi.fn();
vi.mock('$libs/bridge/permit', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/bridge/permit')>()),
  planErc20Send: (...args: unknown[]) => planErc20Send(...args),
}));

const checkOwnershipOfNFT = vi.fn();
vi.mock('./checkOwnership', () => ({
  checkOwnershipOfNFT: (...args: unknown[]) => checkOwnershipOfNFT(...args),
}));

vi.mock('$libs/util/getConnectedWallet', () => ({
  getConnectedWallet: () => Promise.resolve({ account: { address: '0xaaaa' }, chain: { id: 1 } }),
}));

vi.mock('$libs/bridge/getContractAddressByType', () => ({
  getContractAddressByType: () => '0x0000000000000000000000000000000000000456',
}));

import {
  allApproved,
  destNetwork,
  erc20SendPlan,
  insufficientAllowance,
  needsApprovalReset,
  selectedToken,
} from '$components/Bridge/state';
import type { ERC20SendPlan } from '$libs/bridge/permit';
import { account, connectedSourceChain } from '$stores';

import { ApprovalStatus, getTokenApprovalStatus } from './getTokenApprovalStatus';
import { type NFT, type Token, TokenType } from './types';

const VAULT = '0x0000000000000000000000000000000000000456';
const PERMIT2 = '0x000000000022D473030F116dDEE9F6B43aC78BA3';
const approveVault: ERC20SendPlan = {
  method: 'approve',
  spender: VAULT,
  amount: 100n,
  currentAllowance: 0n,
  target: 'vault',
};
const approvePermit2: ERC20SendPlan = {
  method: 'approve',
  spender: PERMIT2,
  amount: 2n ** 256n - 1n,
  currentAllowance: 0n,
  target: 'permit2',
};

const nft: NFT = {
  type: TokenType.ERC721,
  symbol: 'NFT',
  name: 'NFT',
  tokenId: 1,
  addresses: { 1: '0x0000000000000000000000000000000000000abc' },
} as unknown as NFT;

beforeEach(() => {
  vi.clearAllMocks();
  account.set({ address: '0xaaaa', isConnected: true } as never);
  connectedSourceChain.set({ id: 1 } as never);
  destNetwork.set({ id: 2 } as never);
  checkOwnershipOfNFT.mockResolvedValue([{ isOwner: true }]);
  // The function reads the token address off the selected-token store, not its argument
  selectedToken.set(nft);
  // A previously selected token left this standing
  allApproved.set(true);
});

describe('getTokenApprovalStatus for NFTs', () => {
  it('reports no approval required when the vault already has it', async () => {
    requiresApproval.mockResolvedValue(false);

    expect(await getTokenApprovalStatus(nft)).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(true);
  });

  it('reports approval required and clears the flag', async () => {
    requiresApproval.mockResolvedValue(true);

    expect(await getTokenApprovalStatus(nft)).toBe(ApprovalStatus.APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(false);
  });

  it('clears the flag when the approval cannot be read at all', async () => {
    // The ERC20 branch already did this. Left set, the previous token's `true` keeps the
    // Bridge button enabled for a token whose approval state is unknown
    requiresApproval.mockRejectedValue(new Error('rpc down'));

    expect(await getTokenApprovalStatus(nft)).toBe(ApprovalStatus.APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(false);
  });

  it('clears the flag when the user does not own the token', async () => {
    checkOwnershipOfNFT.mockResolvedValue([{ isOwner: false }]);

    expect(await getTokenApprovalStatus(nft)).toBe(ApprovalStatus.APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(false);
    expect(requiresApproval).not.toHaveBeenCalled();
  });

  it('leaves no ERC20 plan behind for an NFT or for ETH', async () => {
    // Nothing reads the plan for either, and nothing should find one
    erc20SendPlan.set(approvePermit2);
    requiresApproval.mockResolvedValue(false);
    await getTokenApprovalStatus(nft);
    expect(get(erc20SendPlan)).toBeNull();

    erc20SendPlan.set(approvePermit2);
    const eth = { type: TokenType.ETH, symbol: 'ETH', name: 'Ether', decimals: 18, addresses: {} } as Token;
    selectedToken.set(eth);
    expect(await getTokenApprovalStatus(eth)).toBe(ApprovalStatus.ETH_NO_APPROVAL_REQUIRED);
    expect(get(erc20SendPlan)).toBeNull();
  });

  it('asks the ERC1155 bridge the same question', async () => {
    requiresApproval.mockResolvedValue(true);

    expect(await getTokenApprovalStatus({ ...nft, type: TokenType.ERC1155 } as NFT)).toBe(
      ApprovalStatus.APPROVAL_REQUIRED,
    );
    expect(requiresApproval).toHaveBeenCalledOnce();
  });

  it('clears a stale approval when the NFT ownership read fails', async () => {
    // The not-owner branch already clears it for the same reason: a previously selected
    // token's allApproved=true must not survive, or Bridge stays enabled for an NFT whose
    // approval state could not be read at all
    allApproved.set(true);
    checkOwnershipOfNFT.mockRejectedValue(new Error('rpc down'));

    await expect(getTokenApprovalStatus(nft)).rejects.toThrow('rpc down');

    expect(get(allApproved)).toBe(false);
  });
});

describe('getTokenApprovalStatus answers for the token it was given', () => {
  const otherNft: NFT = {
    ...nft,
    tokenId: 2,
    addresses: { 1: '0x0000000000000000000000000000000000000def' },
  } as unknown as NFT;

  it('reads the allowance of the token it was given, not of the selected one', async () => {
    // The read is polled for seconds after an approval, and the user can switch tokens in
    // that window. The ERC20 branch took its token address off the store, so it answered
    // the new token's question with the old token's name on it. (The NFT branch always read
    // its argument, which is why this is pinned on ERC20.)
    const erc20 = {
      type: TokenType.ERC20,
      symbol: 'TKN',
      name: 'Token',
      decimals: 18,
      addresses: { 1: '0x0000000000000000000000000000000000000aaa' },
    } as unknown as Token;
    const otherErc20 = {
      ...erc20,
      symbol: 'OTHER',
      addresses: { 1: '0x0000000000000000000000000000000000000bbb' },
    } as unknown as Token;
    selectedToken.set(otherErc20);
    planErc20Send.mockResolvedValue(approveVault);

    await getTokenApprovalStatus(erc20);

    expect(planErc20Send).toHaveBeenCalledWith(expect.objectContaining({ token: erc20.addresses[1] }));
  });

  it('does not publish a late answer for a token that is no longer selected', async () => {
    // A store write describes "the selected token"; a stale answer landing in it hands the
    // new token an approval nothing read for it
    selectedToken.set(otherNft);
    allApproved.set(false);
    requiresApproval.mockResolvedValue(false); // the previous token happens to be approved

    expect(await getTokenApprovalStatus(nft)).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);

    expect(get(allApproved)).toBe(false);
  });

  it('still publishes for the same token behind a fresh object', async () => {
    // Token lists are rebuilt on every refresh, so identity is by deployment, not by reference
    selectedToken.set({ ...nft });
    allApproved.set(false);
    requiresApproval.mockResolvedValue(false);

    await getTokenApprovalStatus(nft);

    expect(get(allApproved)).toBe(true);
  });

  it("keeps a late ERC20 allowance answer out of the current token's stores", async () => {
    const erc20 = {
      type: TokenType.ERC20,
      symbol: 'TKN',
      name: 'Token',
      decimals: 18,
      addresses: { 1: '0x0000000000000000000000000000000000000aaa' },
    } as unknown as Token;
    const otherErc20 = {
      ...erc20,
      symbol: 'OTHER',
      addresses: { 1: '0x0000000000000000000000000000000000000bbb' },
    } as unknown as Token;
    selectedToken.set(otherErc20);
    allApproved.set(false);
    insufficientAllowance.set(true);
    planErc20Send.mockResolvedValue({ method: 'sendToken' }); // the previous token has allowance

    expect(await getTokenApprovalStatus(erc20)).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);

    expect(get(allApproved)).toBe(false);
    expect(get(insufficientAllowance)).toBe(true);
    expect(get(erc20SendPlan)).toBeNull();
  });
});

describe('getTokenApprovalStatus for ERC20', () => {
  const erc20 = {
    type: TokenType.ERC20,
    symbol: 'TKN',
    name: 'Token',
    decimals: 18,
    addresses: { 1: '0x0000000000000000000000000000000000000aaa' },
  } as unknown as Token;

  beforeEach(() => {
    selectedToken.set(erc20);
    allApproved.set(false);
    insufficientAllowance.set(false);
    needsApprovalReset.set(false);
    erc20SendPlan.set(null);
  });

  it('needs no approval for a plan that spends a standing allowance', async () => {
    planErc20Send.mockResolvedValue({ method: 'sendToken' });

    expect(await getTokenApprovalStatus(erc20)).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(true);
    expect(get(insufficientAllowance)).toBe(false);
  });

  it('needs no approval for a plan that signs instead, and publishes the plan for the buttons', async () => {
    const plan = {
      method: 'permit',
      domain: { name: 'Token', version: '1', chainId: 1, verifyingContract: erc20.addresses[1] },
    };
    planErc20Send.mockResolvedValue(plan);

    expect(await getTokenApprovalStatus(erc20)).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(true);
    expect(get(erc20SendPlan)).toEqual(plan);
  });

  it('needs an approval when the plan asks for one, and publishes what it approves', async () => {
    planErc20Send.mockResolvedValue(approvePermit2);

    expect(await getTokenApprovalStatus(erc20)).toBe(ApprovalStatus.APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(false);
    expect(get(insufficientAllowance)).toBe(true);
    expect(get(erc20SendPlan)).toEqual(approvePermit2);
    expect(get(needsApprovalReset)).toBe(false);
  });

  it('needs a reset first for a USDT-style token whose spender holds a partial allowance', async () => {
    // Whichever spender the plan approves: a non-zero USDT allowance to Permit2 cannot be raised either
    const usdt = { ...erc20, symbol: 'tUSDT' } as Token;
    selectedToken.set(usdt);
    planErc20Send.mockResolvedValue({ ...approvePermit2, currentAllowance: 5n });

    expect(await getTokenApprovalStatus(usdt)).toBe(ApprovalStatus.RESET_REQUIRED);
    expect(get(needsApprovalReset)).toBe(true);
    expect(get(allApproved)).toBe(false);
  });

  it("does not blank the current token's plan on a late poll for a token the user has left", async () => {
    // waitForApprovalStatus is still retrying token A when the user reaches the confirm step
    // for token B, whose read has already published its plan
    const tokenB = { ...erc20, symbol: 'B', addresses: { 1: '0x0000000000000000000000000000000000000bbb' } } as Token;
    selectedToken.set(tokenB);
    erc20SendPlan.set(approvePermit2);
    needsApprovalReset.set(true);
    let answer!: (plan: unknown) => void;
    planErc20Send.mockReturnValue(new Promise((resolve) => (answer = resolve)));

    const latePoll = getTokenApprovalStatus(erc20);
    expect(get(erc20SendPlan)).toEqual(approvePermit2);
    expect(get(needsApprovalReset)).toBe(true);

    answer({ method: 'sendToken' });
    expect(await latePoll).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);
    expect(get(erc20SendPlan)).toEqual(approvePermit2);
  });

  it("clears the previous token's plan before the read answers", async () => {
    erc20SendPlan.set(approvePermit2);
    let answer!: (plan: unknown) => void;
    planErc20Send.mockReturnValue(new Promise((resolve) => (answer = resolve)));

    const pending = getTokenApprovalStatus(erc20);
    expect(get(erc20SendPlan)).toBeNull();

    answer({ method: 'sendToken' });
    await pending;
  });

  it('clears the flag when no plan can be made', async () => {
    allApproved.set(true);
    planErc20Send.mockRejectedValue(new Error('rpc down'));

    expect(await getTokenApprovalStatus(erc20)).toBe(ApprovalStatus.APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(false);
  });
});
