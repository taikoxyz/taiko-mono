/**
 * A failed NFT page must not look like exhaustion.
 *
 * The repository used to swallow page failures and return the accumulated list unchanged,
 * which reaches ScannedImport as "the length did not grow" - indistinguishable from
 * "there are no more NFTs" - and permanently retired the Load more button even though the
 * cursor was still valid.
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

import type { NFT } from '$libs/token';

import ScannedImport from './ScannedImport.svelte';

const nft = (tokenId: number): NFT => ({ tokenId, addresses: { 1: '0xabc' } }) as unknown as NFT;

/** The paginator button stays mounted and toggles `disabled`, it is never removed */
const loadMoreButton = (target: HTMLElement) =>
  Array.from(target.querySelectorAll('button')).find((b) => b.textContent?.includes('paginator.')) as HTMLButtonElement;

/** The refresh control is the icon-only button at the top of the panel */
const refreshButton = (target: HTMLElement) => target.querySelector('button') as HTMLButtonElement;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

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

describe('ScannedImport load more', () => {
  it('keeps Load more available when a page fetch fails', async () => {
    const nextPage = vi.fn().mockRejectedValue(new Error('rate limited'));
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => undefined);

    component = new ScannedImport({
      target,
      props: { refresh: vi.fn().mockResolvedValue(undefined), nextPage, foundNFTs: [nft(1)] },
    });

    expect(loadMoreButton(target).disabled).toBe(false);

    loadMoreButton(target).click();
    await flush();

    expect(nextPage).toHaveBeenCalledTimes(1);
    // Still enabled, so the user can retry the page the cursor still points at
    expect(loadMoreButton(target).disabled).toBe(false);
    expect(loadMoreButton(target).textContent).toContain('paginator.more');

    // And a retry actually reaches the fetch again
    loadMoreButton(target).click();
    await flush();
    expect(nextPage).toHaveBeenCalledTimes(2);

    consoleError.mockRestore();
  });

  it('retires Load more only when a successful page adds nothing', async () => {
    const nextPage = vi.fn().mockResolvedValue(undefined);

    component = new ScannedImport({
      target,
      props: { refresh: vi.fn().mockResolvedValue(undefined), nextPage, foundNFTs: [nft(1)] },
    });

    loadMoreButton(target).click();
    await flush();

    // The fetch succeeded and the list did not grow: genuinely exhausted
    expect(loadMoreButton(target).disabled).toBe(true);
    expect(loadMoreButton(target).textContent).toContain('paginator.everything_loaded');
  });

  it('surfaces a refresh failure instead of leaving an unhandled rejection', async () => {
    const refresh = vi.fn().mockRejectedValue(new Error('rate limited'));
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => undefined);

    component = new ScannedImport({
      target,
      props: { refresh, nextPage: vi.fn().mockResolvedValue(undefined), foundNFTs: [nft(1)] },
    });

    refreshButton(target).click();
    await flush();

    expect(refresh).toHaveBeenCalled();
    expect(errorToast).toHaveBeenCalled();
    consoleError.mockRestore();
  });
});
