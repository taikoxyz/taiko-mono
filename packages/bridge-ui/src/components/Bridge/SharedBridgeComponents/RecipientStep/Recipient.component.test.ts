/**
 * Component-level coverage for the recipient dialog.
 *
 * The pure `canConfirmRecipient` predicate cannot exercise the sequences that actually
 * produce the hazard: two-way bindings that change without dispatching an event, an RPC
 * resolving after the draft moved on, and Cancel restoring a discarded edit. These tests
 * mount the real component and drive its inputs.
 */
import { tick } from 'svelte';
import { get } from 'svelte/store';
import { vi } from 'vitest';

const WALLET = '0x1111111111111111111111111111111111111111';
const CONTRACT = '0x2222222222222222222222222222222222222222';
const DEST_OWNER = '0x3333333333333333333333333333333333333333';
const DEST_CHAIN = 167000;
const OTHER_CHAIN = 1;

const isSmartContract = vi.fn();

vi.mock('$libs/util/isSmartContract', () => ({
  isSmartContract: (...args: unknown[]) => isSmartContract(...args),
}));

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

import { destNetwork, destOwnerAddress, recipientAddress } from '$components/Bridge/state';
import { account } from '$stores/account';

import Recipient from './Recipient.svelte';

/** Resolves on the next macrotask, after any awaited promise chain has settled */
const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

type Mounted = {
  target: HTMLElement;
  component: { $destroy: () => void };
  confirmButton: HTMLButtonElement;
  inputs: () => HTMLInputElement[];
  recipientInput: () => HTMLInputElement;
  destOwnerInput: () => HTMLInputElement | undefined;
  type: (input: HTMLInputElement, value: string) => Promise<void>;
};

let mounted: Mounted | null = null;

const mount = (): Mounted => {
  const target = document.createElement('div');
  document.body.appendChild(target);
  const component = new Recipient({ target, props: { small: false, disabled: false } });

  const buttons = () => Array.from(target.querySelectorAll('button'));
  const confirmButton = buttons().find((b) => b.textContent?.includes('common.confirm')) as HTMLButtonElement;
  const inputs = () => Array.from(target.querySelectorAll('input')) as HTMLInputElement[];

  const type = async (input: HTMLInputElement, value: string) => {
    input.value = value;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    await tick();
  };

  mounted = {
    target,
    component,
    confirmButton,
    inputs,
    recipientInput: () => inputs()[0],
    destOwnerInput: () => inputs()[1],
    type,
  };
  return mounted;
};

/** Drives the dialog to a classified smart-contract recipient */
const withContractRecipient = async () => {
  isSmartContract.mockResolvedValue(true);
  const m = mount();
  await m.type(m.recipientInput(), CONTRACT);
  await flush();
  return m;
};

beforeEach(() => {
  isSmartContract.mockReset();
  recipientAddress.set(null);
  destOwnerAddress.set(null);
  destNetwork.set({ id: DEST_CHAIN } as never);
  account.set({ address: WALLET, isConnected: true } as never);
});

afterEach(() => {
  mounted?.component.$destroy();
  mounted?.target.remove();
  mounted = null;
});

describe('Recipient dialog', () => {
  it('enables Confirm for a classified wallet recipient', async () => {
    isSmartContract.mockResolvedValue(false);
    const m = mount();

    await m.type(m.recipientInput(), WALLET);
    await flush();

    expect(m.confirmButton.disabled).toBe(false);
    expect(get(recipientAddress)).toBe(WALLET);
  });

  it('blocks Confirm while the classification is still in flight', async () => {
    let resolveLookup!: (value: boolean) => void;
    isSmartContract.mockReturnValue(new Promise<boolean>((resolve) => (resolveLookup = resolve)));
    const m = mount();

    await m.type(m.recipientInput(), WALLET);
    await tick();
    expect(m.confirmButton.disabled).toBe(true);

    resolveLookup(false);
    await flush();
    expect(m.confirmButton.disabled).toBe(false);
  });

  it('shows the destination owner input for a contract recipient and blocks Confirm until it is set', async () => {
    const m = await withContractRecipient();

    expect(m.destOwnerInput()).toBeDefined();
    expect(m.confirmButton.disabled).toBe(true);
  });

  it('does not enable Confirm for a destination owner that never dispatched validation', async () => {
    // The reported hole: AddressInput returns without dispatching for text that has no
    // `0x` prefix, so the draft becomes truthy while $destOwnerAddress stays null. The
    // bridges would then fall back to `destOwner = to`, the contract that cannot claim.
    const m = await withContractRecipient();

    await m.type(m.destOwnerInput() as HTMLInputElement, 'abc');
    await flush();

    expect(m.confirmButton.disabled).toBe(true);
    expect(get(destOwnerAddress)).toBeNull();
  });

  it('enables Confirm once the destination owner passes validation', async () => {
    const m = await withContractRecipient();

    await m.type(m.destOwnerInput() as HTMLInputElement, DEST_OWNER);
    await flush();

    expect(m.confirmButton.disabled).toBe(false);
    expect(get(destOwnerAddress)).toBe(DEST_OWNER);
  });

  it('blocks Confirm again when the destination owner draft is edited after validating', async () => {
    const m = await withContractRecipient();
    await m.type(m.destOwnerInput() as HTMLInputElement, DEST_OWNER);
    await flush();
    expect(m.confirmButton.disabled).toBe(false);

    // Clearing dispatches nothing at all, so the draft is the only signal
    await m.type(m.destOwnerInput() as HTMLInputElement, '');
    await flush();

    expect(m.confirmButton.disabled).toBe(true);
  });

  it('discards a classification whose address was cleared while the lookup was pending', async () => {
    let resolveLookup!: (value: boolean) => void;
    isSmartContract.mockReturnValue(new Promise<boolean>((resolve) => (resolveLookup = resolve)));
    const m = mount();

    await m.type(m.recipientInput(), CONTRACT);
    await tick();

    // Clearing the field dispatches no event; only the draft change reveals it
    await m.type(m.recipientInput(), '');
    resolveLookup(true);
    await flush();

    expect(m.confirmButton.disabled).toBe(true);
    // The superseded lookup must not write its address back into the store or the input
    expect(get(recipientAddress)).toBeNull();
    expect(m.recipientInput().value).toBe('');
  });

  it('discards a classification made for a destination chain that has since changed', async () => {
    let resolveLookup!: (value: boolean) => void;
    isSmartContract.mockReturnValue(new Promise<boolean>((resolve) => (resolveLookup = resolve)));
    const m = mount();

    await m.type(m.recipientInput(), WALLET);
    await tick();

    destNetwork.set({ id: OTHER_CHAIN } as never);
    await tick();
    resolveLookup(false);
    await flush();

    expect(m.confirmButton.disabled).toBe(true);
  });

  it('invalidates a completed classification when the destination chain changes afterwards', async () => {
    isSmartContract.mockResolvedValue(false);
    const m = mount();
    await m.type(m.recipientInput(), WALLET);
    await flush();
    expect(m.confirmButton.disabled).toBe(false);

    destNetwork.set({ id: OTHER_CHAIN } as never);
    await tick();

    // The same address can be a contract on one chain and an EOA on another
    expect(m.confirmButton.disabled).toBe(true);
  });

  it('keeps Confirm blocked when the classification lookup fails', async () => {
    isSmartContract.mockRejectedValue(new Error('rpc down'));
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const m = mount();

    await m.type(m.recipientInput(), WALLET);
    await flush();

    expect(m.confirmButton.disabled).toBe(true);
    consoleError.mockRestore();
  });

  describe('Cancel', () => {
    /** Opens the dialog on an already confirmed recipient */
    const withConfirmedRecipient = async () => {
      isSmartContract.mockResolvedValue(false);
      const m = mount();
      await m.type(m.recipientInput(), WALLET);
      await flush();

      const editButton = Array.from(m.target.querySelectorAll('button')).find((b) =>
        b.textContent?.includes('common.edit'),
      ) as HTMLButtonElement;
      editButton.click();
      await flush();
      return m;
    };

    const pressEscape = async () => {
      window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
      await flush();
    };

    it('restores the draft after an edit that never dispatched validation', async () => {
      const m = await withConfirmedRecipient();

      // Text without a `0x` prefix dispatches nothing, so nothing else can notice it
      await m.type(m.recipientInput(), 'abc');
      await pressEscape();

      expect(get(recipientAddress)).toBe(WALLET);
      expect(m.recipientInput().value).toBe(WALLET);
      expect(m.confirmButton.disabled).toBe(false);
    });

    it('restores the draft after the field was cleared', async () => {
      const m = await withConfirmedRecipient();

      await m.type(m.recipientInput(), '');
      await pressEscape();

      expect(get(recipientAddress)).toBe(WALLET);
      expect(m.recipientInput().value).toBe(WALLET);
    });

    it('discards a classification still in flight when the edit is cancelled', async () => {
      const m = await withConfirmedRecipient();

      let resolveLookup!: (value: boolean) => void;
      isSmartContract.mockReturnValue(new Promise<boolean>((resolve) => (resolveLookup = resolve)));
      await m.type(m.recipientInput(), CONTRACT);
      await tick();

      await pressEscape();
      resolveLookup(true);
      await flush();

      // The cancelled lookup must not resurrect the address it was classifying
      expect(get(recipientAddress)).toBe(WALLET);
    });
  });

  describe('state carried in the stores', () => {
    it('accepts a destination owner that was already validated before a remount', async () => {
      // Navigating Review -> Recipient destroys and recreates the component. The stores
      // keep the contract recipient and its owner; the local validation record does not.
      recipientAddress.set(CONTRACT as never);
      destOwnerAddress.set(DEST_OWNER as never);
      isSmartContract.mockResolvedValue(true);

      const m = mount();
      const editButton = Array.from(m.target.querySelectorAll('button')).find((b) =>
        b.textContent?.includes('common.edit'),
      ) as HTMLButtonElement;
      editButton.click();
      await flush();

      // $destOwnerAddress only ever holds an address that passed validation, so the
      // prefilled owner must not require a pointless re-edit
      expect(m.confirmButton.disabled).toBe(false);
    });

    it('accepts an owner validated in the separate DestOwner editor while Recipient stays mounted', async () => {
      // RecipientStep mounts Recipient and DestOwner side by side against the same
      // $destOwnerAddress store, so the other editor can commit a new owner without
      // Recipient reclassifying anything.
      const m = await withContractRecipient();
      await m.type(m.destOwnerInput() as HTMLInputElement, DEST_OWNER);
      await flush();
      expect(m.confirmButton.disabled).toBe(false);

      // The separate editor validates a different owner and commits it
      const OTHER_OWNER = '0x4444444444444444444444444444444444444444';
      destOwnerAddress.set(OTHER_OWNER as never);
      await flush();

      const editButton = Array.from(m.target.querySelectorAll('button')).find((b) =>
        b.textContent?.includes('common.edit'),
      ) as HTMLButtonElement;
      editButton.click();
      await flush();

      // The recipient classification is still current, so nothing reclassifies; the
      // committed owner must carry its own provenance
      expect((m.destOwnerInput() as HTMLInputElement).value).toBe(OTHER_OWNER);
      expect(m.confirmButton.disabled).toBe(false);
    });

    it('accepts the reset-to-wallet owner committed by the separate editor', async () => {
      const m = await withContractRecipient();
      await m.type(m.destOwnerInput() as HTMLInputElement, DEST_OWNER);
      await flush();

      // DestOwner's reset path writes the connected wallet into the shared store
      destOwnerAddress.set(WALLET as never);
      await flush();

      expect(m.confirmButton.disabled).toBe(false);
    });

    it('still refuses an unvalidated draft after a committed owner was hydrated', async () => {
      const m = await withContractRecipient();
      destOwnerAddress.set(DEST_OWNER as never);
      await flush();
      expect(m.confirmButton.disabled).toBe(false);

      // Hydrating from the store must not let the local input promote itself
      await m.type(m.destOwnerInput() as HTMLInputElement, 'abc');
      await flush();

      expect(m.confirmButton.disabled).toBe(true);
    });

    it('does not treat a chain-A classification as current after the chain changed', async () => {
      isSmartContract.mockResolvedValue(false);
      const m = mount();
      await m.type(m.recipientInput(), WALLET);
      await flush();

      const editButton = Array.from(m.target.querySelectorAll('button')).find((b) =>
        b.textContent?.includes('common.edit'),
      ) as HTMLButtonElement;
      editButton.click();
      await flush();

      // Switch the destination while the dialog is open, then cancel the edit
      destNetwork.set({ id: OTHER_CHAIN } as never);
      await tick();
      window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
      await flush();

      // Reopening must reclassify for the new chain rather than restore the old record
      // and then sit blocked on a mismatch nothing can clear
      isSmartContract.mockClear();
      editButton.click();
      await flush();

      expect(isSmartContract).toHaveBeenCalledWith(WALLET, OTHER_CHAIN);
      expect(m.confirmButton.disabled).toBe(false);
    });
  });

  it('does not commit a pending classification after the component is destroyed', async () => {
    let resolveLookup!: (value: boolean) => void;
    isSmartContract.mockReturnValue(new Promise<boolean>((resolve) => (resolveLookup = resolve)));
    const m = mount();

    await m.type(m.recipientInput(), CONTRACT);
    await tick();

    m.component.$destroy();
    mounted = null;
    resolveLookup(true);
    await flush();

    // The stores outlive the dialog, so a late answer would corrupt a fresh one
    expect(get(recipientAddress)).toBeNull();
  });
});
