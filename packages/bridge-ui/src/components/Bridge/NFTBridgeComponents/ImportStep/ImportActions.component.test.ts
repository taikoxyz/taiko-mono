/**
 * A scan that failed is not a scan that found nothing.
 *
 * `firstScan` gates the initial call-to-action against the "no NFTs found" warning, so
 * clearing it in a `finally` reported an RPC failure to the user as an empty wallet.
 */
import { tick } from 'svelte';
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

const errorToast = vi.fn();
vi.mock('$components/NotificationToast', () => ({
  errorToast: (...args: unknown[]) => errorToast(...args),
  warningToast: vi.fn(),
  successToast: vi.fn(),
  infoToast: vi.fn(),
}));

import ImportActions from './ImportActions.svelte';

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

const text = () => target.textContent ?? '';

beforeEach(() => {
  errorToast.mockReset();
  target = document.createElement('div');
  document.body.appendChild(target);
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('initial NFT scan', () => {
  it('reports an empty wallet only after a scan that completed', async () => {
    const scanForNFTs = vi.fn().mockResolvedValue(true);
    component = new ImportActions({ target, props: { canImport: true, scanning: false, scanForNFTs } });
    await tick();

    (target.querySelector('button') as HTMLButtonElement).click();
    await flush();

    expect(text()).toContain('bridge.nft.step.import.no_nft_found');
  });

  it('keeps the initial scan action when the scan never ran', async () => {
    // Missing account or chain resolves false: nothing failed, but nothing was scanned
    // either, so claiming the wallet is empty would be a lie
    const scanForNFTs = vi.fn().mockResolvedValue(false);
    component = new ImportActions({ target, props: { canImport: true, scanning: false, scanForNFTs } });
    await tick();

    (target.querySelector('button') as HTMLButtonElement).click();
    await flush();

    expect(text()).not.toContain('bridge.nft.step.import.no_nft_found');
    expect(text()).toContain('bridge.actions.nft_scan');
    expect(errorToast).not.toHaveBeenCalled();
  });

  it('keeps the initial scan action after a failed scan', async () => {
    const scanForNFTs = vi.fn().mockRejectedValue(new Error('rate limited'));
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => undefined);
    component = new ImportActions({ target, props: { canImport: true, scanning: false, scanForNFTs } });
    await tick();

    (target.querySelector('button') as HTMLButtonElement).click();
    await flush();

    // The failure is surfaced, not silently rendered as an empty wallet
    expect(errorToast).toHaveBeenCalled();
    expect(text()).not.toContain('bridge.nft.step.import.no_nft_found');
    expect(text()).toContain('bridge.actions.nft_scan');

    // And a retry still reaches the scan
    (target.querySelector('button') as HTMLButtonElement).click();
    await flush();
    expect(scanForNFTs).toHaveBeenCalledTimes(2);

    consoleError.mockRestore();
  });
});
