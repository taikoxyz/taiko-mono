/**
 * The manual-claim search has to say when a relayer failed.
 *
 * fetchTransactions reports a relayer failure by returning an `error` rather than
 * throwing, so the component's catch never sees it. Reading only `mergedTransactions`
 * left a failed search looking exactly like an address with no transactions.
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
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});
vi.mock('@wagmi/core');

const warningToast = vi.fn();
vi.mock('$components/NotificationToast', () => ({
  warningToast: (...args: unknown[]) => warningToast(...args),
  errorToast: vi.fn(),
  successToast: vi.fn(),
  infoToast: vi.fn(),
}));

// The rows are not under test here and need chain config the environment does not generate
vi.mock('$components/Transactions/Rows', async () => {
  const Stub = (await import('../../tests/StubComponent.svelte')).default;
  return { FungibleTransactionRow: Stub, NftTransactionRow: Stub };
});

const fetchTransactions = vi.fn();
vi.mock('$libs/bridge', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/bridge')>()),
  fetchTransactions: (...args: unknown[]) => fetchTransactions(...args),
}));

import { account } from '$stores/account';

import Relayer from './Relayer.svelte';

const ADDRESS = '0x1111111111111111111111111111111111111111';

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

/** Types a full address into the search field and runs the search */
const search = async () => {
  const input = target.querySelector('input') as HTMLInputElement;
  input.value = ADDRESS;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await flush();

  const button = Array.from(target.querySelectorAll('button')).find((b) =>
    b.textContent?.includes('Search transactions'),
  ) as HTMLButtonElement;
  expect(button).toBeTruthy();
  expect(button.disabled).toBe(false);
  button.click();
  await flush();
};

beforeEach(() => {
  warningToast.mockReset();
  fetchTransactions.mockReset();
  account.set({ address: ADDRESS, isConnected: true } as never);
  target = document.createElement('div');
  document.body.appendChild(target);
  component = new Relayer({ target, props: {} });
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('manual claim search', () => {
  it('warns when a relayer failed, even though results came back', async () => {
    fetchTransactions.mockResolvedValue({
      mergedTransactions: [],
      outdatedLocalTransactions: [],
      error: new Error('relayer down'),
    });

    await search();

    // Silence here reads as "this address has no transactions", which is a different
    // answer from "one of the relayers could not be reached"
    expect(warningToast).toHaveBeenCalledWith({ title: 'transactions.errors.relayer_offline' });
  });

  it('stays quiet when every relayer answered', async () => {
    fetchTransactions.mockResolvedValue({
      mergedTransactions: [],
      outdatedLocalTransactions: [],
      error: undefined,
    });

    await search();

    expect(warningToast).not.toHaveBeenCalled();
  });

  it('still warns when the fetch throws outright', async () => {
    fetchTransactions.mockRejectedValue(new Error('boom'));

    await search();

    expect(warningToast).toHaveBeenCalledWith({ title: 'transactions.errors.relayer_offline' });
  });
});

describe('the results table', () => {
  const row = (srcTxHash: string, msgHash: string) => ({
    srcTxHash,
    msgHash,
    status: 0, // MessageStatus.NEW
    msgStatus: 0,
    tokenType: 'ETH',
    message: { to: ADDRESS, destOwner: ADDRESS, gasLimit: 100000 },
  });

  it('does not repopulate the table from a search the user cleared', async () => {
    // The rows are cleared when the field empties, but the fetch for the address that was
    // just erased is still in flight; without invalidating it, its response lands anyway
    let resolveSearch: (value: unknown) => void = () => undefined;
    fetchTransactions.mockReturnValue(new Promise((resolve) => (resolveSearch = resolve)));

    await search();

    const input = target.querySelector('input') as HTMLInputElement;
    input.value = '';
    input.dispatchEvent(new Event('input', { bubbles: true }));
    await flush();

    resolveSearch({ mergedTransactions: [row('0xtx', '0xmsgA')], error: undefined });
    await flush();

    expect(target.querySelectorAll('[data-testid="stub"]')).toHaveLength(0);
    expect(target.textContent).toContain('relayer_component.no_tx_found');
    // Superseding the fetch orphans the `finally` that would have lowered `fetching`, so
    // the field has to be re-enabled here or the user can never search again
    expect((target.querySelector('input') as HTMLInputElement).disabled).toBe(false);
  });

  it('renders both messages a single transaction emitted', async () => {
    // Keyed by transaction, Svelte throws on the duplicate key and the table never
    // renders. This block was missed when the identity fix landed on the other one
    fetchTransactions.mockResolvedValue({
      mergedTransactions: [row('0xtx', '0xmsgA'), row('0xtx', '0xmsgB')],
      error: undefined,
    });

    await search();

    expect(target.textContent).not.toContain('relayer_component.no_tx_found');
    expect(target.querySelectorAll('[data-testid="stub"]')).toHaveLength(2);
  });
});
