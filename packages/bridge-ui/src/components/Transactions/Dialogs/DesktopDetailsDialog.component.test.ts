/**
 * The details dialog renders an ERC20 amount in the token's own decimals. It used to go
 * through formatEther, which showed 100 USDC as 0.0000000001 - and reverting to that left
 * the whole suite green, because nothing mounted the dialog with a token that is not 18
 * decimals.
 *
 * It also names the user's addresses as sender and recipient. A token transfer is a message
 * from vault to vault, so reading the envelope showed two bridge contracts instead - and
 * classified the recipient's own claim as a relayer's, since the recipient is not the vault.
 *
 * And it reads the claimer and the claim time off the claim transaction when the relayer
 * reported neither, which is the case for every message the relayer claimed itself.
 */
import { tick } from 'svelte';
import { encodeAbiParameters, encodeFunctionData } from 'viem';
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});
vi.mock('@wagmi/core');
vi.mock('$libs/bridge/isTransactionProcessable', () => ({ isTransactionProcessable: vi.fn().mockResolvedValue(true) }));
const getClaimDetails = vi.hoisted(() => vi.fn());
vi.mock('$libs/bridge/getClaimDetails', () => ({ getClaimDetails: (...args: unknown[]) => getClaimDetails(...args) }));
// Deliberately not the claim time below: the initiated date renders in the same dialog, and the
// claim-date assertion must not be satisfied by it
vi.mock('$libs/util/getBlockTimestamp', () => ({ geBlockTimestamp: vi.fn().mockResolvedValue(1_600_000_000n) }));
vi.mock('$libs/chain', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/chain')>()),
  getChainName: () => 'Chain',
  // Both read chainConfig, which the test environment does not generate
  isL2Chain: () => false,
}));
// Not under test, and each pulls in chain config the environment does not generate
vi.mock('../Status', async () => {
  const Stub = (await import('../../../tests/StubComponent.svelte')).default;
  return { Status: Stub, StatusInfoDialog: Stub };
});
// The mobile dialog imports the Status component by file rather than through the index
vi.mock('../Status/Status.svelte', async () => ({
  default: (await import('../../../tests/StubComponent.svelte')).default,
}));
vi.mock('../ChainSymbolName.svelte', async () => ({
  default: (await import('../../../tests/StubComponent.svelte')).default,
}));
// Renders its target, so the addresses a row links to can be read back
vi.mock('$components/ExplorerLink/ExplorerLink.svelte', async () => ({
  default: (await import('../../../tests/ExplorerLinkStub.svelte')).default,
}));

import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { erc20InvocationParameters, onMessageInvocationAbi } from '$libs/bridge/vaultInvocation';
import { TokenType } from '$libs/token';
import { formatTimestamp } from '$libs/util/formatTimestamp';
import { ALICE, BOB, L1_ADDRESSES, L2_A_ADDRESSES } from '$mocks';
import { account } from '$stores/account';

import DesktopDetailsDialog from './DesktopDetailsDialog.svelte';
import MobileDetailsDialog from './MobileDetailsDialog.svelte';

const ADDRESS = '0x1111111111111111111111111111111111111111';
const RELAYER = '0x00006ca990540F6e30e3ef05F085a033Ae67F214';
const CLAIMED_AT = 1_700_000_000n;

/** 100 USDC: six decimals, so the raw amount is 100_000_000 */
const usdcTransfer = {
  srcTxHash: '0xaaaa',
  destTxHash: '0xbbbb',
  status: MessageStatus.DONE,
  msgStatus: MessageStatus.DONE,
  msgHash: '0xcccc',
  from: ADDRESS,
  amount: 100_000_000n,
  symbol: 'USDC',
  decimals: 6,
  srcChainId: 1n,
  destChainId: 2n,
  tokenType: TokenType.ERC20,
  blockNumber: '0x1',
  message: {
    srcChainId: 1n,
    destChainId: 2n,
    from: ADDRESS,
    to: ADDRESS,
    srcOwner: ADDRESS,
    destOwner: ADDRESS,
    value: 0n,
    data: '0x',
    fee: 0n,
    gasLimit: 1,
    id: 1n,
  },
} as unknown as BridgeTransaction;

/** ALICE sends 100 USDC to BOB: the message runs vault to vault, the parties ride in the payload */
const usdcToBob = {
  ...usdcTransfer,
  from: ALICE,
  message: {
    ...usdcTransfer.message,
    from: L1_ADDRESSES.erc20VaultAddress,
    to: L2_A_ADDRESSES.erc20VaultAddress,
    srcOwner: ALICE,
    destOwner: ALICE,
    data: encodeFunctionData({
      abi: onMessageInvocationAbi,
      functionName: 'onMessageInvocation',
      args: [
        encodeAbiParameters(erc20InvocationParameters, [
          {
            chainId: 1n,
            addr: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
            decimals: 6,
            symbol: 'USDC',
            name: 'USD Coin',
          },
          ALICE,
          BOB,
          100_000_000n,
        ]),
      ],
    }),
  },
} as unknown as BridgeTransaction;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

const linkedAddresses = () =>
  [...target.querySelectorAll('[data-testid="explorer-link"][data-category="address"]')].map((link) =>
    link.getAttribute('data-param'),
  );

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

beforeEach(() => {
  getClaimDetails.mockReset().mockResolvedValue({ claimedBy: RELAYER, claimedAt: CLAIMED_AT });
  account.set({ address: ADDRESS, isConnected: true } as never);
  target = document.createElement('div');
  document.body.appendChild(target);
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe.each([
  ['desktop', DesktopDetailsDialog],
  ['mobile', MobileDetailsDialog],
])('%s details dialog', (_name, Dialog) => {
  it('formats an ERC20 amount in the token decimals, not in ether', async () => {
    component = new Dialog({
      target,
      props: { detailsOpen: true, bridgeTx: usdcTransfer, token: null, closeDetails: () => undefined },
    });
    await flush();

    const text = target.textContent ?? '';
    expect(text).toContain('100 USDC');
    expect(text).not.toContain('0.0000000001');
  });

  it("names the user's addresses for a token transfer, not the vaults the message runs between", async () => {
    component = new Dialog({
      target,
      props: { detailsOpen: true, bridgeTx: usdcToBob, token: null, closeDetails: () => undefined },
    });
    await flush();

    const linked = linkedAddresses();
    expect(linked).toContain(ALICE);
    expect(linked).toContain(BOB);
    expect(linked).not.toContain(L1_ADDRESSES.erc20VaultAddress);
    expect(linked).not.toContain(L2_A_ADDRESSES.erc20VaultAddress);
  });

  it("does not call the recipient's own claim a relayer's", async () => {
    component = new Dialog({
      target,
      props: {
        detailsOpen: true,
        bridgeTx: { ...usdcToBob, claimedBy: BOB },
        token: null,
        closeDetails: () => undefined,
      },
    });
    await flush();

    expect(target.textContent).not.toContain('common.relayer');
    // The claimer is linked: once as the recipient, once as the claimer
    expect(linkedAddresses().filter((address) => address === BOB)).toHaveLength(2);
  });

  describe('a claim the relayer reported without a claimer', () => {
    // The relayer API leaves claimedBy empty for every message the relayer itself claimed.
    // The claim transaction is known, and it answers both who and when. An ETH transfer, so
    // the recipient is on the envelope and all four addresses render
    const claimedByUnknown = {
      ...usdcTransfer,
      tokenType: TokenType.ETH,
      symbol: 'ETH',
      decimals: 18,
      claimedBy: undefined,
    } as unknown as BridgeTransaction;

    it('reads the claimer and the claim time off the claim transaction', async () => {
      component = new Dialog({
        target,
        props: { detailsOpen: true, bridgeTx: claimedByUnknown, token: null, closeDetails: () => undefined },
      });
      await flush();

      expect(getClaimDetails).toHaveBeenCalledWith(claimedByUnknown.destTxHash, claimedByUnknown.destChainId);
      // Neither the recipient nor the destination owner: a relayer, and said so on evidence
      expect(target.textContent).toContain('common.relayer');
      expect(target.textContent).toContain(formatTimestamp(Number(CLAIMED_AT)));
    });

    it('links a self-claim to the claimer', async () => {
      getClaimDetails.mockResolvedValue({ claimedBy: ADDRESS, claimedAt: CLAIMED_AT });
      component = new Dialog({
        target,
        props: { detailsOpen: true, bridgeTx: claimedByUnknown, token: null, closeDetails: () => undefined },
      });
      await flush();

      expect(target.textContent).not.toContain('common.relayer');
      // Sender, recipient, destination owner and now the claimer
      expect(linkedAddresses().filter((address) => address === ADDRESS)).toHaveLength(4);
    });

    it('shows the claimer of the transaction on screen, not of one it was showing before', async () => {
      // A read still in flight for the previous transaction lands after the switch
      let resolveFirst!: (value: unknown) => void;
      let resolveSecond!: (value: unknown) => void;
      getClaimDetails
        .mockImplementationOnce(() => new Promise((resolve) => (resolveFirst = resolve)))
        .mockImplementationOnce(() => new Promise((resolve) => (resolveSecond = resolve)));
      component = new Dialog({
        target,
        props: { detailsOpen: true, bridgeTx: claimedByUnknown, token: null, closeDetails: () => undefined },
      });
      await flush();

      const other = { ...claimedByUnknown, destTxHash: '0xdddd', msgHash: '0xeeee' } as unknown as BridgeTransaction;
      (component as unknown as { $set: (props: object) => void }).$set({ bridgeTx: other });
      await flush();

      resolveSecond({ claimedBy: ADDRESS, claimedAt: CLAIMED_AT });
      await flush();
      resolveFirst({ claimedBy: RELAYER, claimedAt: CLAIMED_AT });
      await flush();

      expect(target.textContent).not.toContain('common.relayer');
    });

    it('does not read the claim transaction until the dialog is opened', async () => {
      // Every row mounts both dialogs; a read here would be two RPC calls per claimed row
      component = new Dialog({
        target,
        props: { detailsOpen: false, bridgeTx: claimedByUnknown, token: null, closeDetails: () => undefined },
      });
      await flush();
      expect(getClaimDetails).not.toHaveBeenCalled();

      (component as unknown as { $set: (props: object) => void }).$set({ detailsOpen: true });
      await flush();
      expect(getClaimDetails).toHaveBeenCalledTimes(1);
    });
  });
});
