/**
 * The record of a sent bridge describes what the wallet signed, not what the stores hold
 * when the wallet returns. The prompt can sit open for minutes, and a wallet that switched
 * account or network meanwhile used to file the transaction under the new account or chain:
 * the sender's history lost it, and the receipt wait watched the wrong chain.
 */
import { tick } from 'svelte';
import { vi } from 'vitest';

window.matchMedia = vi.fn().mockReturnValue({
  matches: true,
  addEventListener: vi.fn(),
  removeEventListener: vi.fn(),
}) as never;

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  // Renders the values too: the strings under test are chosen by direction and carry the
  // destination chain, neither of which a key-only formatter can show
  const t = (key: string, options?: { values?: Record<string, unknown> }) =>
    options?.values ? `${key} ${JSON.stringify(options.values)}` : key;
  return { t: readable(t), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});
vi.mock('$chainConfig', () => ({
  chainConfig: {
    // rpcUrls: the wagmi config builds one transport per configured chain at import time
    1: {
      name: 'Ethereum',
      type: 'L1',
      rpcUrls: { default: { http: ['https://l1.rpc'] } },
      blockExplorers: { default: { url: 'https://l1.explorer' } },
    },
    2: {
      name: 'Taiko',
      type: 'L2',
      rpcUrls: { default: { http: ['https://l2.rpc'] } },
      blockExplorers: { default: { url: 'https://l2.explorer' } },
    },
  },
}));
vi.mock('$components/Bridge/SharedBridgeComponents/Actions.svelte', async () => ({
  default: (await import('../../../../tests/ActionsStub.svelte')).default,
}));

// The wallet round trip, scripted per test
const sendBridge = vi.fn();
vi.mock('$libs/bridge/bridges', () => ({
  bridges: { ETH: { bridge: (...args: unknown[]) => sendBridge(...args) } },
  hasBridge: () => true,
}));
vi.mock('$libs/bridge/getBridgeArgs', () => ({
  getBridgeArgs: vi.fn(async (_token: unknown, amount: bigint, commonArgs: object) => ({
    ...commonArgs,
    amount,
    bridgeAddress: '0x1000010000000000000000000000000000000001',
  })),
}));
const recordBridgeTx = vi.fn();
vi.mock('$libs/storage/recordBridgeTx', () => ({ recordBridgeTx: (...args: unknown[]) => recordBridgeTx(...args) }));
const waitForReceipt = vi.fn();
vi.mock('$stores/pendingTransactions', () => ({
  pendingTransactions: { add: (...args: unknown[]) => waitForReceipt(...args) },
}));
vi.mock('$libs/bridge/handleBridgeErrors', () => ({ handleBridgeError: vi.fn() }));
vi.mock('$libs/util/getConnectedWallet', () => ({ getConnectedWallet: vi.fn().mockResolvedValue({}) }));
vi.mock('$libs/util/checkForPausedContracts', () => ({ isBridgePaused: vi.fn().mockResolvedValue(false) }));
vi.mock('$libs/util/balance', () => ({ refreshUserBalance: vi.fn().mockResolvedValue(undefined) }));
vi.mock('$libs/token/waitForApprovalStatus', () => ({ waitForApprovalStatus: vi.fn().mockResolvedValue(undefined) }));
const successToast = vi.fn();
vi.mock('$components/NotificationToast', () => ({ successToast: (...args: unknown[]) => successToast(...args) }));
vi.mock('$components/NotificationToast/NotificationToast.svelte', () => ({
  successToast: (...args: unknown[]) => successToast(...args),
  infoToast: vi.fn(),
  warningToast: vi.fn(),
  errorToast: vi.fn(),
}));

import { destNetwork, enteredAmount, processingFee, recipientAddress, selectedToken } from '$components/Bridge/state';
import { getBridgeArgs } from '$libs/bridge/getBridgeArgs';
import { ETHToken, TokenType } from '$libs/token';
import { ALICE, BOB } from '$mocks';
import { account } from '$stores/account';
import { connectedSourceChain } from '$stores/network';

import ConfirmationStep from './ConfirmationStep.svelte';

const TX_HASH = `0x${'ab'.repeat(32)}`;

/** A token the user could switch to while a prompt is open; its bridge is not the ETH one */
const usdc = { type: TokenType.ERC20, symbol: 'USDC', name: 'USDC', decimals: 6, addresses: {} };

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

const startBridge = async () => {
  (target.querySelector('[data-testid="stub-bridge"]') as HTMLButtonElement).click();
  await flush();
};

beforeEach(() => {
  vi.clearAllMocks();
  waitForReceipt.mockImplementation(async (hash: string) => ({ transactionHash: hash, status: 'success' }));

  // An L2 -> L1 transfer of 5 wei with a 1 wei fee, signed by ALICE
  account.set({ address: ALICE, isConnected: true } as never);
  connectedSourceChain.set({ id: 2, name: 'Taiko' } as never);
  destNetwork.set({ id: 1, name: 'Ethereum' } as never);
  selectedToken.set(ETHToken as never);
  enteredAmount.set(BigInt(5));
  processingFee.set(BigInt(1));
  recipientAddress.set(null);

  target = document.createElement('div');
  document.body.appendChild(target);
  component = new ConfirmationStep({ target, props: {} });
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('the local record of a sent bridge', () => {
  it('describes what the wallet signed, whatever is connected when the wallet returns', async () => {
    let resolveWallet!: (hash: string) => void;
    sendBridge.mockReturnValueOnce(new Promise<string>((resolve) => (resolveWallet = resolve)));
    await startBridge();

    // The prompt is open. The user switches account and network in the wallet, and the
    // stores follow; the token, amount and fee are changed too
    account.set({ address: BOB, isConnected: true } as never);
    connectedSourceChain.set({ id: 1, name: 'Ethereum' } as never);
    destNetwork.set({ id: 2, name: 'Taiko' } as never);
    selectedToken.set(usdc as never);
    enteredAmount.set(BigInt(999));
    processingFee.set(BigInt(7));
    await tick();

    resolveWallet(TX_HASH);
    await flush();

    // The receipt is awaited on the chain the transaction was sent on
    expect(waitForReceipt).toHaveBeenCalledWith(TX_HASH, 2);

    // And the history entry belongs to the account that sent it
    expect(recordBridgeTx).toHaveBeenCalledTimes(1);
    const [owner, record] = recordBridgeTx.mock.calls[0];
    expect(owner).toBe(ALICE);
    expect(record).toMatchObject({
      srcTxHash: TX_HASH,
      from: ALICE,
      amount: BigInt(5),
      processingFee: BigInt(1),
      symbol: 'ETH',
      decimals: 18,
      tokenType: TokenType.ETH,
      srcChainId: BigInt(2),
      destChainId: BigInt(1),
    });
  });

  it('dispatches through the bridge of the token that was signed for, not of one selected meanwhile', async () => {
    // Building the arguments goes over the network too, and the bridge service is derived
    // from the selected token: a switch during that await moved the dispatch to the new
    // token's bridge while the arguments still described the old one
    let resolveArgs!: (value: unknown) => void;
    vi.mocked(getBridgeArgs).mockReturnValueOnce(new Promise((resolve) => (resolveArgs = resolve)) as never);
    sendBridge.mockResolvedValueOnce(TX_HASH);
    await startBridge();

    selectedToken.set(usdc as never);
    await tick();

    resolveArgs({ amount: BigInt(5), bridgeAddress: '0x1000010000000000000000000000000000000001' });
    await flush();

    expect(sendBridge).toHaveBeenCalledTimes(1);
    expect(recordBridgeTx.mock.calls[0][1]).toMatchObject({ symbol: 'ETH', tokenType: TokenType.ETH });
  });
});
