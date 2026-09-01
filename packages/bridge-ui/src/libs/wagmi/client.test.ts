import { http } from '@wagmi/core';
import type { Chain } from 'viem';

// The manual mock at __mocks__/@wagmi/core.ts stubs http/createConfig/reconnect, so importing
// client.ts does not build a real wagmi config or attempt a wallet reconnect.
vi.mock('@wagmi/core');
vi.mock('@wagmi/connectors', () => ({ injected: vi.fn(), walletConnect: vi.fn() }));
vi.mock('$libs/chain', () => ({ chains: [{ id: 1 }, { id: 167000 }] }));

import { createTransports, RPC_BATCH_CONFIG } from './client';

describe('createTransports', () => {
  it('batches RPC reads for every configured chain', () => {
    // Given: the module-scope config already called http() at import time
    vi.mocked(http).mockClear();

    // When
    const transports = createTransports([{ id: 1 }, { id: 167000 }] as unknown as readonly Chain[]);

    // Then: one transport per chain, each carrying the batch config. Without it, a 300-transaction
    // history is 600 separate HTTP requests and the RPC gateway rate-limits the page.
    expect(Object.keys(transports).sort()).toEqual(['1', '167000']);
    expect(http).toHaveBeenCalledTimes(2);
    for (const call of vi.mocked(http).mock.calls) {
      expect(call[1]).toEqual({ batch: RPC_BATCH_CONFIG });
    }
  });

  it('keeps the batch size bounded so one rate-limited request cannot drop a whole page', () => {
    expect(RPC_BATCH_CONFIG.batchSize).toBe(50);
    // wait must be non-zero: the second read wave resolves on later ticks and would not group.
    expect(RPC_BATCH_CONFIG.wait).toBeGreaterThan(0);
  });
});
