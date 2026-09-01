/**
 * Component-level coverage for the destination-owner dialog.
 *
 * The destination owner is the one address that can process a `gasLimit: 0` message or drive
 * a last-attempt retry, so committing one the user did not confirm is value-bearing. This
 * dialog is the twin of the recipient dialog and used to have none of its guards: it wrote
 * the store the moment an address validated, Escape closed without cancelling, the async
 * contract check had no generation guard, and Confirm keyed on a flag rather than on what
 * the box actually held.
 */
import { tick } from 'svelte';
import { get } from 'svelte/store';
import { vi } from 'vitest';

const WALLET = '0x1111111111111111111111111111111111111111';
const OWNER_A = '0x2222222222222222222222222222222222222222';
const OWNER_B = '0x3333333333333333333333333333333333333333';
const DEST_CHAIN = 167000;

const isSmartContract = vi.fn();

vi.mock('$libs/util/isSmartContract', () => ({
  isSmartContract: (...args: unknown[]) => isSmartContract(...args),
}));

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

import { destNetwork, destOwnerAddress } from '$components/Bridge/state';
import { account } from '$stores/account';

import DestOwner from './DestOwner.svelte';

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

const buttons = () => Array.from(target.querySelectorAll('button'));
const confirmButton = () => buttons().find((b) => b.textContent?.includes('common.confirm')) as HTMLButtonElement;
const input = () => target.querySelector('input') as HTMLInputElement;

const type = async (value: string) => {
  const el = input();
  el.value = value;
  el.dispatchEvent(new Event('input', { bubbles: true }));
  await tick();
};

const pressEscape = async () => {
  window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
  await tick();
};

/** Opens the dialog the way the trigger does */
const openDialog = async () => {
  const edit = buttons().find((b) => b.textContent?.includes('common.edit')) as HTMLButtonElement;
  edit.click();
  await tick();
};

beforeEach(() => {
  isSmartContract.mockReset();
  destOwnerAddress.set(null);
  destNetwork.set({ id: DEST_CHAIN } as never);
  account.set({ address: WALLET, isConnected: true } as never);
  target = document.createElement('div');
  document.body.appendChild(target);
  component = new DestOwner({ target, props: { small: false, disabled: false } }) as never;
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('DestOwner dialog', () => {
  it('does not commit a validated address until Confirm', async () => {
    isSmartContract.mockResolvedValue(false);
    await openDialog();

    await type(OWNER_A);
    await flush();

    // The address validated, but nothing has been confirmed yet
    expect(get(destOwnerAddress)).toBeNull();
    expect(confirmButton().disabled).toBe(false);

    confirmButton().click();
    await tick();
    expect(get(destOwnerAddress)).toBe(OWNER_A);
  });

  it('cancels on Escape instead of keeping the typed address', async () => {
    isSmartContract.mockResolvedValue(false);
    await openDialog();

    await type(OWNER_A);
    await flush();

    await pressEscape();

    // Escape aborts the edit; the store keeps what it had
    expect(get(destOwnerAddress)).toBeNull();
  });

  it('does not let an older contract check decide the state of a newer address', async () => {
    // A is a wallet answering slowly, B is a contract answering fast. If A's late answer
    // wins, the warning clears and Confirm offers an address the box no longer shows.
    let resolveA!: (value: boolean) => void;
    isSmartContract
      .mockReturnValueOnce(new Promise<boolean>((resolve) => (resolveA = resolve)))
      .mockResolvedValueOnce(true);

    await openDialog();
    await type(OWNER_A);
    await tick();

    await type(OWNER_B);
    await flush();

    resolveA(false);
    await flush();

    // B is a contract, so Confirm stays disabled and nothing was committed
    expect(confirmButton().disabled).toBe(true);
    expect(get(destOwnerAddress)).toBeNull();
  });

  it('disables Confirm when a validated address is replaced with text that never validates', async () => {
    isSmartContract.mockResolvedValue(false);
    await openDialog();

    await type(OWNER_A);
    await flush();
    expect(confirmButton().disabled).toBe(false);

    // AddressInput dispatches nothing for text without a 0x prefix
    await type('bob.eth');
    await flush();

    expect(confirmButton().disabled).toBe(true);
  });

  it('disables Confirm when the field is cleared after validating', async () => {
    isSmartContract.mockResolvedValue(false);
    await openDialog();

    await type(OWNER_A);
    await flush();

    await type('');
    await flush();

    expect(confirmButton().disabled).toBe(true);
    expect(get(destOwnerAddress)).toBeNull();
  });

  it('opens on an owner committed elsewhere without needing it retyped', async () => {
    // Recipient.svelte and NFTBridge.resetForm both write this store, so the dialog can be
    // opened on an owner its own input never saw. That was cosmetic until Confirm began
    // requiring a validation matching the draft - after that the box opened empty and
    // Confirm was dead until the same address was retyped.
    isSmartContract.mockResolvedValue(false);
    destOwnerAddress.set(OWNER_A as never);
    await tick();

    await openDialog();
    await flush();

    expect(input().value).toBe(OWNER_A);
    expect(confirmButton().disabled).toBe(false);
  });

  it('re-checks the owner against a new destination chain', async () => {
    isSmartContract.mockResolvedValue(false);
    await openDialog();
    await type(OWNER_A);
    await flush();
    expect(confirmButton().disabled).toBe(false);

    // The same address can be a contract on the new chain, so the old answer cannot stand.
    // Without a re-check Confirm just goes dead with nothing explaining why.
    isSmartContract.mockClear();
    destNetwork.set({ id: 1 } as never);
    await flush();

    expect(isSmartContract).toHaveBeenCalledWith(OWNER_A, 1);
    expect(confirmButton().disabled).toBe(false);
  });

  it('restores the committed address when the edit is cancelled', async () => {
    isSmartContract.mockResolvedValue(false);
    await openDialog();
    await type(OWNER_A);
    await flush();
    confirmButton().click();
    await tick();
    expect(get(destOwnerAddress)).toBe(OWNER_A);

    // Reopen, type a different owner, then abort
    await openDialog();
    await type(OWNER_B);
    await flush();
    await pressEscape();

    expect(get(destOwnerAddress)).toBe(OWNER_A);
  });
});
