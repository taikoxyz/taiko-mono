import { http } from '@wagmi/core';
import type { Chain } from 'viem';

// Shared between the $libs/chain mock and the createTransports() calls below, so the "own URL"
// assertions are checking the exact same chain objects the module under test would receive in
// production. vi.mock(...) factories are hoisted above imports, so this has to go through
// vi.hoisted() rather than a plain top-level const.
const mockChains = vi.hoisted(() => [
  { id: 1, rpcUrls: { default: { http: ['https://l1.example/'] } } },
  { id: 167000, rpcUrls: { default: { http: ['https://l2.example/'] } } },
]);

// The manual mock at __mocks__/@wagmi/core.ts stubs http/createConfig/reconnect, so importing
// client.ts does not build a real wagmi config or attempt a wallet reconnect.
vi.mock('@wagmi/core');
vi.mock('@wagmi/connectors', () => ({ injected: vi.fn(), walletConnect: vi.fn() }));
vi.mock('$libs/chain', () => ({ chains: mockChains }));

import { createTransports, RPC_BATCH_CONFIG } from './client';

describe('createTransports', () => {
  it('batches RPC reads for every configured chain', () => {
    // Given: the module-scope config already called http() at import time
    vi.mocked(http).mockClear();

    // When
    const transports = createTransports(mockChains as unknown as readonly Chain[]);

    // Then: one transport per chain, each carrying the batch config. Without it, a 300-transaction
    // history is 600 separate HTTP requests and the RPC gateway rate-limits the page.
    expect(Object.keys(transports).sort()).toEqual(['1', '167000']);
    expect(http).toHaveBeenCalledTimes(2);
    for (const call of vi.mocked(http).mock.calls) {
      expect(call[1]).toEqual({ batch: RPC_BATCH_CONFIG });
    }
  });

  it("gives each chain its own resolved URL, never undefined or another chain's URL", () => {
    // Regression test for the misrouting bug: viem 2.9.31 keys its batch scheduler on the URL
    // *argument* passed to http() (not the resolved URL) and caches schedulers in a module-level
    // map. Passing `undefined` for every chain gave them all the same scheduler id ("undefined"),
    // so concurrent reads on different chains were merged into one batch and flushed through
    // whichever chain's RPC client triggered it first -- misrouting reads to the wrong chain's
    // endpoint. Each call's first argument must be that chain's own URL.
    vi.mocked(http).mockClear();

    createTransports(mockChains as unknown as readonly Chain[]);

    const urls = vi.mocked(http).mock.calls.map((call) => call[0]);
    expect(urls).toEqual(['https://l1.example/', 'https://l2.example/']);
  });

  it('keeps the batch size bounded so one rate-limited request cannot drop a whole page', () => {
    expect(RPC_BATCH_CONFIG.batchSize).toBe(50);
    // wait must be non-zero: the second read wave resolves on later ticks and would not group.
    // Pinned to the exact value, not just "> 0", so a silent change from 20 to 200 fails the test.
    expect(RPC_BATCH_CONFIG.wait).toBe(20);
  });
});
