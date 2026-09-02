/**
 * The details dialog renders an ERC20 amount in the token's own decimals. It used to go
 * through formatEther, which showed 100 USDC as 0.0000000001 - and reverting to that left
 * the whole suite green, because nothing mounted the dialog with a token that is not 18
 * decimals.
 */
import { tick } from 'svelte';
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
vi.mock('$components/ExplorerLink/ExplorerLink.svelte', async () => ({
  default: (await import('../../../tests/StubComponent.svelte')).default,
}));

import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { TokenType } from '$libs/token';
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

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

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
});
