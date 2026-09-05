/**
 * A transaction row must not leave listeners on the shared per-hash poller.
 *
 * onMount awaits an RPC before it starts polling. If the row is unmounted during that
 * await, onDestroy runs while `polling` is still undefined and therefore cleans up
 * nothing; the suspended callback then resumes, attaches handlers, and nobody ever
 * removes them - so the emitter keeps a subscriber and polling never stops.
 */
import { tick } from 'svelte';
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

const isTransactionProcessable = vi.fn();
vi.mock('$libs/bridge/isTransactionProcessable', () => ({
  isTransactionProcessable: (...args: unknown[]) => isTransactionProcessable(...args),
}));

const startPolling = vi.fn();
vi.mock('$libs/polling/messageStatusPoller', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/polling/messageStatusPoller')>()),
  startPolling: (...args: unknown[]) => startPolling(...args),
}));

import { account } from '$stores/account';

import Status from './Status.svelte';

const bridgeTx = { msgStatus: 0, srcTxHash: '0x1', msgHash: '0x2' } as never;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

/** A stand-in for the shared per-hash poller, tracking what is attached to it */
const makePoller = () => {
  const listeners: Record<string, unknown[]> = {};
  const emitter = {
    on: (event: string, handler: unknown) => {
      (listeners[event] ??= []).push(handler);
    },
  };
  return {
    listeners,
    handle: {
      emitter,
      destroy: (handlers: Record<string, unknown>) => {
        for (const [event, handler] of Object.entries(handlers)) {
          listeners[event] = (listeners[event] ?? []).filter((h) => h !== handler);
        }
      },
    },
    attachedCount: () => Object.values(listeners).reduce((total, l) => total + l.length, 0),
  };
};

let target: HTMLElement;

beforeEach(() => {
  isTransactionProcessable.mockReset();
  startPolling.mockReset();
  account.set({ address: '0xaaaa', isConnected: true } as never);
  target = document.createElement('div');
  document.body.appendChild(target);
});

afterEach(() => target.remove());

describe('Status row polling lifecycle', () => {
  it('detaches its listeners on a normal unmount', async () => {
    const poller = makePoller();
    startPolling.mockReturnValue(poller.handle);
    isTransactionProcessable.mockResolvedValue(true);

    const component = new Status({ target, props: { bridgeTx, bridgeTxStatus: null } });
    await flush();
    expect(poller.attachedCount()).toBe(2);

    component.$destroy();
    expect(poller.attachedCount()).toBe(0);
  });

  it('does not attach listeners when unmounted during the initial processability read', async () => {
    const poller = makePoller();
    startPolling.mockReturnValue(poller.handle);

    let resolveRead!: (value: boolean) => void;
    isTransactionProcessable.mockReturnValue(new Promise<boolean>((resolve) => (resolveRead = resolve)));

    const component = new Status({ target, props: { bridgeTx, bridgeTxStatus: null } });
    await tick();

    // Unmounted while the read is still pending: onDestroy sees no poller yet
    component.$destroy();

    resolveRead(true);
    await flush();

    // Nothing may be left subscribed to the shared emitter
    expect(poller.attachedCount()).toBe(0);
  });

  it('does not even join the poller after teardown', async () => {
    const poller = makePoller();
    startPolling.mockReturnValue(poller.handle);

    let resolveRead!: (value: boolean) => void;
    isTransactionProcessable.mockReturnValue(new Promise<boolean>((resolve) => (resolveRead = resolve)));

    const component = new Status({ target, props: { bridgeTx, bridgeTxStatus: null } });
    await tick();
    component.$destroy();

    resolveRead(true);
    await flush();

    // Joining would restart the interval for a row nobody is looking at
    expect(startPolling).not.toHaveBeenCalled();
  });
});

/**
 * The manual claim entry exists for zero-fee messages, which no relayer will ever pick up. It must
 * not replace the pending status while the destination chain is merely known not to have synced
 * the message yet - that claim fails, and the next checkpoint fixes it without the user acting.
 */
describe('Status row manual claim entry', () => {
  const zeroFeeTx = { msgStatus: 0, srcTxHash: '0x1', msgHash: '0x2', processingFee: 0n } as never;

  const render = async (processable: boolean | null) => {
    startPolling.mockReturnValue(makePoller().handle);
    isTransactionProcessable.mockResolvedValue(processable);

    const component = new Status({ target, props: { bridgeTx: zeroFeeTx, bridgeTxStatus: null } });
    await flush();
    return component;
  };

  it('shows the pending status while the message is known not to be synced yet', async () => {
    await render(false);

    expect(target.textContent).toContain('transactions.status.processing.name');
    expect(target.textContent).not.toContain('transactions.button.try_claim');
  });

  it('offers the manual claim once processability could not be determined', async () => {
    await render(null);

    expect(target.textContent).toContain('transactions.button.try_claim');
  });

  it('offers the ordinary claim once the message is processable', async () => {
    await render(true);

    expect(target.textContent).toContain('transactions.button.claim');
    expect(target.textContent).not.toContain('transactions.button.try_claim');
  });
});
