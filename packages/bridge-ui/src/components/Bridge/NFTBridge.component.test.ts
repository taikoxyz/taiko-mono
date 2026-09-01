/**
 * The scanned NFT list lives in a store so it survives back-navigation. That also means it
 * survives a wallet or network change, and ImportStep - which is what clears it - is
 * unmounted on every step past IMPORT, so its own reset never runs. The flow came back to
 * the import step showing the previous account's NFTs, selectable and bridgeable.
 */
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
vi.mock('$libs/util/checkForPausedContracts', () => ({ isBridgePaused: vi.fn().mockResolvedValue(false) }));
vi.mock('$libs/bridge/bridges', () => ({ hasBridge: () => true }));

// The steps themselves are not under test here, and each drags in chain config the test
// environment does not generate
vi.mock('./NFTBridgeComponents', async () => {
  const Stub = (await import('../../tests/StubComponent.svelte')).default;
  // ImportStep needs the methods the parent calls on its binding
  const ImportStepStub = (await import('../../tests/ImportStepStub.svelte')).default;
  return { ImportStep: ImportStepStub, ReviewStep: Stub, StepNavigation: Stub };
});
vi.mock('./SharedBridgeComponents', async () => {
  const Stub = (await import('../../tests/StubComponent.svelte')).default;
  return { ConfirmationStep: Stub, RecipientStep: Stub };
});

import { ImportMethod } from '$components/Bridge/types';
import { account } from '$stores/account';
import { connectedSourceChain } from '$stores/network';

import NFTBridge from './NFTBridge.svelte';
import { foundNFTs, selectedImportMethod } from './NFTBridgeComponents/ImportStep/state';
import { destNetwork, destOwnerAddress, recipientAddress, selectedNFTs } from './state';

const NFT_A = { tokenId: 1, name: 'A', addresses: {} } as never;

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
};

const mountWithScanResults = async () => {
  target = document.createElement('div');
  document.body.appendChild(target);
  component = new NFTBridge({ target, props: {} });
  await flush();

  // A completed scan, as ImportStep would leave it
  foundNFTs.set([NFT_A]);
  selectedNFTs.set([NFT_A]);
  selectedImportMethod.set(ImportMethod.SCAN);
};

beforeEach(() => {
  account.set({ address: '0xaaaa', isConnected: true } as never);
  connectedSourceChain.set({ id: 1 } as never);
  destNetwork.set({ id: 2 } as never);
  foundNFTs.set([]);
  selectedNFTs.set([]);
  selectedImportMethod.set(ImportMethod.NONE);
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target?.remove();
});

describe('NFTBridge state on a wallet change', () => {
  it("discards the previous account's scan results", async () => {
    await mountWithScanResults();

    account.set({ address: '0xbbbb', isConnected: true } as never);
    await flush();

    expect(get(foundNFTs)).toEqual([]);
    expect(get(selectedNFTs)).toEqual([]);
    expect(get(selectedImportMethod)).toBe(ImportMethod.NONE);
  });

  it('re-seeds the recipient defaults for a manual import, not just a scan', async () => {
    await mountWithScanResults();
    // A manual import: the branch that revalidates the inputs rather than resetting the form
    selectedImportMethod.set(ImportMethod.MANUAL);
    recipientAddress.set('0xaaaa' as never);
    destOwnerAddress.set('0xaaaa' as never);
    await flush();

    account.set({ address: '0xbbbb', isConnected: true } as never);
    await flush();

    // Only resetForm used to re-seed these, and the manual branch never reaches it - so
    // Review kept showing the previous account as recipient, tagged "customized" though
    // nothing had been, and would have bridged with it as destination owner
    expect(get(recipientAddress)).toBe('0xbbbb');
    expect(get(destOwnerAddress)).toBe('0xbbbb');
  });

  it('discards the scan results when the network changes', async () => {
    await mountWithScanResults();

    connectedSourceChain.set({ id: 3 } as never);
    await flush();

    expect(get(foundNFTs)).toEqual([]);
    expect(get(selectedImportMethod)).toBe(ImportMethod.NONE);
  });
});
