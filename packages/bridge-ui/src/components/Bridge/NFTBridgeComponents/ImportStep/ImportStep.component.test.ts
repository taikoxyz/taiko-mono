/**
 * Loading another page of scanned NFTs must not drop the selection.
 *
 * `nextPage` and a fresh scan shared one code path that cleared `$selectedNFTs` up front,
 * so selecting an NFT and then loading more pages silently deselected it - and so did a
 * page fetch that failed, which deliberately keeps the pages already on screen.
 */
import { tick } from 'svelte';
import { get } from 'svelte/store';
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

// Chrome only, and it needs a populated chainConfig the test environment does not generate
vi.mock('$components/ChainSelectors', async () => ({
  ChainSelector: (await import('../../../../tests/StubComponent.svelte')).default,
  ChainSelectorType: { COMBINED: 'COMBINED' },
}));

const fetchNFTs = vi.fn();
vi.mock('$libs/bridge/fetchNFTs', () => ({
  fetchNFTs: (...args: unknown[]) => fetchNFTs(...args),
}));

import { destNetwork as destChain, selectedNFTs } from '$components/Bridge/state';
import { ImportMethod } from '$components/Bridge/types';
import { account } from '$stores/account';
import { connectedSourceChain as srcChain } from '$stores/network';

import ImportStep from './ImportStep.svelte';
import { foundNFTs, selectedImportMethod } from './state';

const NFT_A = { tokenId: 1, name: 'A', addresses: {} } as never;
const NFT_B = { tokenId: 2, name: 'B', addresses: {} } as never;

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
};

const buttonWith = (text: string) =>
  Array.from(target.querySelectorAll('button')).find((b) => b.textContent?.includes(text));

beforeEach(() => {
  fetchNFTs.mockReset();
  selectedNFTs.set([]);
  // Module-level stores now hold the scan results, so they outlive a test unless reset
  foundNFTs.set([]);
  selectedImportMethod.set(ImportMethod.NONE);
  account.set({ address: '0xaaaa', isConnected: true } as never);
  srcChain.set({ id: 1 } as never);
  destChain.set({ id: 2 } as never);
  target = document.createElement('div');
  document.body.appendChild(target);
  component = new ImportStep({ target, props: {} });
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

/** Runs the initial scan so the scanned view, and its "load more" button, are on screen */
const scan = async (nfts: unknown[]) => {
  fetchNFTs.mockResolvedValue({ nfts, error: null });
  buttonWith('bridge.actions.nft_scan')?.click();
  await flush();
  await flush();
};

describe('scanned NFT pagination', () => {
  it('keeps the selection when another page loads', async () => {
    await scan([NFT_A]);
    // The selection is made on the page already on screen
    selectedNFTs.set([NFT_A]);

    fetchNFTs.mockResolvedValue({ nfts: [NFT_A, NFT_B], error: null });
    const more = buttonWith('paginator.more');
    expect(more).toBeTruthy();
    more?.click();
    await flush();
    await flush();

    // Clearing here deselected an NFT that is still on screen and still selectable
    expect(get(selectedNFTs)).toEqual([NFT_A]);
  });

  it('keeps the selection when a page fetch fails', async () => {
    await scan([NFT_A]);
    selectedNFTs.set([NFT_A]);

    fetchNFTs.mockResolvedValue({ nfts: [], error: new Error('relayer down') });
    buttonWith('paginator.more')?.click();
    await flush();
    await flush();

    // The earlier pages are deliberately kept on screen, so their selection stays valid
    expect(get(selectedNFTs)).toEqual([NFT_A]);
  });

  // Guards, not regression tests: both pass against the previous code too. Svelte queues
  // the parent's flush when foundNFTs is assigned, which is before scanForNFTs returns, so
  // the child's prop was in fact updated by the time the await in handleNextPage resumed.
  // These pin the behaviour to what nextPage reports rather than to that ordering holding.
  it('keeps "load more" usable when a page actually arrived', async () => {
    await scan([NFT_A]);

    fetchNFTs.mockResolvedValue({ nfts: [NFT_A, NFT_B], error: null });
    buttonWith('paginator.more')?.click();
    await flush();
    await flush();

    // ScannedImport decides this from what nextPage reports, not from its own bound copy
    // of foundNFTs - retiring the button here would end pagination for good
    expect(buttonWith('paginator.more')).toBeTruthy();
  });

  it('retires "load more" once a page brings nothing new', async () => {
    await scan([NFT_A]);

    fetchNFTs.mockResolvedValue({ nfts: [NFT_A], error: null });
    buttonWith('paginator.more')?.click();
    await flush();
    await flush();

    expect(buttonWith('paginator.more')).toBeFalsy();
    expect(buttonWith('paginator.everything_loaded')).toBeTruthy();
  });

  it('keeps "load more" usable when the scan could not run at all', async () => {
    await scan([NFT_A]);

    // The destination chain goes away while the scanned view stays mounted, so
    // scanForNFTs returns without fetching. Nothing arrived, but nothing was asked for
    // either. (Losing the account instead resets the whole view via OnAccount.)
    destChain.set(undefined as never);
    await tick();

    fetchNFTs.mockClear();
    buttonWith('paginator.more')?.click();
    await flush();
    await flush();

    expect(fetchNFTs).not.toHaveBeenCalled();
    expect(buttonWith('paginator.more')).toBeTruthy();
  });

  it('keeps the scan results when the step is remounted', async () => {
    await scan([NFT_A, NFT_B]);
    selectedNFTs.set([NFT_A]);
    expect(get(foundNFTs)).toHaveLength(2);

    // Back-navigation destroys and recreates ImportStep. A mount reset here dumped the
    // user on the initial scan chooser with their results and selection gone
    component?.$destroy();
    target.remove();
    target = document.createElement('div');
    document.body.appendChild(target);
    component = new ImportStep({ target, props: {} });
    await flush();

    expect(get(foundNFTs)).toHaveLength(2);
    expect(get(selectedNFTs)).toEqual([NFT_A]);
    expect(get(selectedImportMethod)).toBe(ImportMethod.SCAN);
  });

  it('discards the scan when the source chain changes', async () => {
    await scan([NFT_A, NFT_B]);
    selectedNFTs.set([NFT_A]);

    // The list describes what the wallet holds on chain 1. Kept across a chain switch it
    // offers NFTs the user does not own on chain 3, and the scanned view stays mounted
    // through the switch so nothing else was clearing it
    srcChain.set({ id: 3 } as never);
    await flush();

    expect(get(foundNFTs)).toEqual([]);
    expect(get(selectedNFTs)).toEqual([]);
    expect(get(selectedImportMethod)).toBe(ImportMethod.NONE);
  });

  it('keeps the scan when the source chain has not actually changed', async () => {
    await scan([NFT_A, NFT_B]);

    srcChain.set({ id: 1 } as never);
    await flush();

    expect(get(foundNFTs)).toHaveLength(2);
  });

  it('does not publish a scan that resolves after the wallet changed', async () => {
    // Wallet A's scan is slow; the user switches to wallet B, which resets the step. The
    // scan then landed anyway and showed B wallet A's NFTs, selectable and bridgeable
    let resolveScan!: (result: unknown) => void;
    fetchNFTs.mockReturnValueOnce(new Promise((resolve) => (resolveScan = resolve)));
    buttonWith('bridge.actions.nft_scan')?.click();
    await flush();

    account.set({ address: '0xbbbb', isConnected: true } as never);
    await flush();

    resolveScan({ nfts: [NFT_A], error: null });
    await flush();
    await flush();

    expect(get(foundNFTs)).toEqual([]);
    expect(get(selectedImportMethod)).toBe(ImportMethod.NONE);
  });

  it('does not put the scanned view back over a manual import the user opened', async () => {
    await scan([NFT_A]);
    let resolvePage!: (result: unknown) => void;
    fetchNFTs.mockReturnValueOnce(new Promise((resolve) => (resolvePage = resolve)));
    buttonWith('paginator.more')?.click();
    await flush();

    // The user opens the manual form while the page is still loading
    selectedImportMethod.set(ImportMethod.MANUAL);
    await flush();

    resolvePage({ nfts: [NFT_A, NFT_B], error: null });
    await flush();
    await flush();

    expect(get(selectedImportMethod)).toBe(ImportMethod.MANUAL);
  });

  it('still clears the selection on a fresh scan', async () => {
    await scan([NFT_A]);
    selectedNFTs.set([NFT_A]);

    // A rescan replaces the list, so a selection from the old one has nothing behind it.
    // The refresh control is the scanned header's icon-only circular button
    const refresh = target.querySelector('button.btn-circle') as HTMLButtonElement | null;
    expect(refresh).toBeTruthy();
    refresh?.click();
    await flush();
    await flush();

    expect(get(selectedNFTs)).toEqual([]);
  });
});
