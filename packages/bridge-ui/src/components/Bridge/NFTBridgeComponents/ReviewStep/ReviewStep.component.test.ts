/**
 * The review step's image lookup must not overwrite a selection made after it started.
 *
 * fetchImage awaits every selected NFT's image (a slow host, an IPFS gateway fallback) and
 * then wrote the result back into the selection stores unconditionally. A user who pressed
 * Back and picked another NFT meanwhile had that choice replaced by the old one - and
 * Continue then bridged the NFT they had deselected.
 */
import { tick } from 'svelte';
import { get } from 'svelte/store';
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});
vi.mock('@wagmi/core');
// Builds transports from the generated chain config at import time
vi.mock('$libs/wagmi', () => ({ config: {} }));
vi.mock('$libs/wagmi/client', () => ({ config: {} }));
vi.mock('$chainConfig', () => ({ chainConfig: { 1: { type: 'L2' }, 2: { type: 'L2' } } }));
// Chrome only, and each pulls in chain config the test environment does not generate
vi.mock('$components/Bridge/SharedBridgeComponents', async () => {
  const Stub = (await import('../../../../tests/StubComponent.svelte')).default;
  return { ProcessingFee: Stub, Recipient: Stub };
});
vi.mock('$components/ChainSelectors', async () => ({
  ChainSelector: (await import('../../../../tests/StubComponent.svelte')).default,
  ChainSelectorDirection: { SOURCE: 'SOURCE', DESTINATION: 'DESTINATION' },
  ChainSelectorType: { SMALL: 'SMALL', COMBINED: 'COMBINED' },
}));
vi.mock('$components/NFTs', async () => ({
  NFTDisplay: (await import('../../../../tests/StubComponent.svelte')).default,
}));

const fetchNFTImageUrl = vi.fn();
vi.mock('$libs/token/fetchNFTImageUrl', () => ({
  fetchNFTImageUrl: (...args: unknown[]) => fetchNFTImageUrl(...args),
}));

import { destNetwork, selectedNFTs, selectedToken } from '$components/Bridge/state';
import { connectedSourceChain } from '$stores/network';

import ReviewStep from './ReviewStep.svelte';

const NFT_X = { tokenId: 1, name: 'X', type: 'ERC721', addresses: {} } as never;
const NFT_Z = { tokenId: 2, name: 'Z', type: 'ERC721', addresses: {} } as never;

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

beforeEach(() => {
  fetchNFTImageUrl.mockReset();
  connectedSourceChain.set({ id: 1 } as never);
  destNetwork.set({ id: 2 } as never);
  selectedNFTs.set([NFT_X]);
  selectedToken.set(NFT_X);
  target = document.createElement('div');
  document.body.appendChild(target);
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('the image lookup of the review step', () => {
  it('does not put back a selection the user has since replaced', async () => {
    let resolveLookup!: (nft: unknown) => void;
    fetchNFTImageUrl.mockReturnValueOnce(new Promise((resolve) => (resolveLookup = resolve)));
    component = new ReviewStep({ target, props: {} });
    await flush();

    // Back, then another NFT picked in the scanned view
    selectedNFTs.set([NFT_Z]);
    selectedToken.set(NFT_Z);

    resolveLookup(NFT_X);
    await flush();

    expect(get(selectedNFTs)).toEqual([NFT_Z]);
    expect(get(selectedToken)).toBe(NFT_Z);
  });

  it('does not write into the stores after it was unmounted', async () => {
    // A wallet change resets the form and unmounts the step while the lookup is out
    let resolveLookup!: (nft: unknown) => void;
    fetchNFTImageUrl.mockReturnValueOnce(new Promise((resolve) => (resolveLookup = resolve)));
    component = new ReviewStep({ target, props: {} });
    await flush();

    component.$destroy();
    component = null;
    selectedNFTs.set([]);
    selectedToken.set(null as never);

    resolveLookup(NFT_X);
    await flush();

    expect(get(selectedNFTs)).toEqual([]);
    expect(get(selectedToken)).toBeNull();
  });

  it('still publishes the lookup for a selection that is current', async () => {
    fetchNFTImageUrl.mockResolvedValueOnce(NFT_X);
    component = new ReviewStep({ target, props: {} });
    await flush();

    expect(fetchNFTImageUrl).toHaveBeenCalledWith(NFT_X);
    expect(get(selectedNFTs)).toEqual([NFT_X]);
    expect(get(selectedToken)).toBe(NFT_X);
  });
});
