import { readFileSync } from 'node:fs';

import { describe, expect, it, vi } from 'vitest';

import { getOathWallets } from './oathWallet';

const { createModal } = vi.hoisted(() => ({ createModal: vi.fn() }));
vi.mock('@web3modal/wagmi', () => ({ createWeb3Modal: createModal }));
vi.mock('$libs/chain', () => ({ getChainImages: () => ({ 167000: '/taiko.svg' }) }));
vi.mock('$libs/wagmi', () => ({ config: { test: 'existing-config' } }));

import './web3modal';

describe('Oath Wallet listing', () => {
  it.each(['Macintosh', 'Windows NT', 'iPhone OS 18_2', 'iPad', ''])('provides one native row for %s', (userAgent) => {
    expect(getOathWallets(userAgent)).toHaveLength(1);
    expect(getOathWallets(userAgent)[0]).toMatchObject({ id: 'oath-wallet', name: 'Oath Wallet' });
  });
  it('does not offer an unsupported Android handoff', () => {
    expect(getOathWallets('Mozilla/5.0 (Linux; Android 15)')).toEqual([]);
  });
  it('uses the app scheme base expected by Web3Modal, with no extension or Android links', () => {
    const wallet = getOathWallets('iPhone')[0];
    expect(wallet.mobile_link).toBe('oathwallet://');
    expect(wallet.app_store).toBe('https://apps.apple.com/app/id6780187283');
    expect(wallet.desktop_link).toBeUndefined();
    expect(wallet.webapp_link).toBeUndefined();
    expect(wallet.play_store).toBeUndefined();
  });
  it('registers in the actual modal without replacing its config or existing wallet controls', () => {
    expect(createModal).toHaveBeenCalledOnce();
    expect(createModal.mock.calls[0][0]).toMatchObject({
      wagmiConfig: { test: 'existing-config' },
      customWallets: getOathWallets(),
      featuredWalletIds: [],
      excludeWalletIds: [],
      allowUnsupportedChain: true,
      chainImages: { 167000: '/taiko.svg' },
    });
  });
  it('ships a rounded local SVG without remote dependencies or active content', () => {
    const svg = readFileSync('static/oath-wallet.svg', 'utf8');
    expect(svg).toMatch(/rx="\d+"/);
    expect(svg).not.toMatch(/<script|(?:href|src)=["']https?:\/\//);
  });
});
