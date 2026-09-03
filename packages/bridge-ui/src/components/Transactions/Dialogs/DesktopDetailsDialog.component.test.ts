/**
 * The details dialog renders an ERC20 amount in the token's own decimals. It used to go
 * through formatEther, which showed 100 USDC as 0.0000000001 - and reverting to that left
 * the whole suite green, because nothing mounted the dialog with a token that is not 18
 * decimals.
 *
 * It also names the user's addresses as sender and recipient. A token transfer is a message
 * from vault to vault, so reading the envelope showed two bridge contracts instead - and
 * classified the recipient's own claim as a relayer's, since the recipient is not the vault.
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
vi.mock('$libs/util/getBlockFromTxHash', () => ({ getBlockFromTxHash: vi.fn().mockResolvedValue(1n) }));
vi.mock('$libs/util/getBlockTimestamp', () => ({ geBlockTimestamp: vi.fn().mockResolvedValue(1_700_000_000n) }));
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
import { ALICE, BOB, L1_ADDRESSES, L2_A_ADDRESSES } from '$mocks';
import { account } from '$stores/account';

import DesktopDetailsDialog from './DesktopDetailsDialog.svelte';
import MobileDetailsDialog from './MobileDetailsDialog.svelte';

const ADDRESS = '0x1111111111111111111111111111111111111111';

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
});
