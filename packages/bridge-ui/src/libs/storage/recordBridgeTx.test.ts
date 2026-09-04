/**
 * Recording a bridge transaction locally must never decide how the bridge is reported.
 *
 * The write used to sit inside the try block that tells a reverted transaction from a
 * receipt wait that gave up, so a storage quota error reached that catch looking exactly
 * like a revert: an error toast for a transaction that had confirmed on chain.
 */
import type { Address } from 'viem';
import { vi } from 'vitest';

vi.mock('./index', () => ({ bridgeTxService: { addTxByAddress: vi.fn() } }));

import type { BridgeTransaction } from '$libs/bridge/types';

import { bridgeTxService } from './index';
import { recordBridgeTx } from './recordBridgeTx';

const ADDRESS = '0x1111111111111111111111111111111111111111' as Address;
const tx = { srcTxHash: '0xa' } as unknown as BridgeTransaction;

const addTxByAddress = vi.mocked(bridgeTxService.addTxByAddress);

describe('recordBridgeTx', () => {
  beforeEach(() => {
    addTxByAddress.mockReset();
    vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('records the transaction and reports that it did', () => {
    expect(recordBridgeTx(ADDRESS, tx)).toBe(true);
    expect(addTxByAddress).toHaveBeenCalledWith(ADDRESS, tx);
  });

  it('does not throw when storage refuses the write', () => {
    // What localStorage raises once the origin's quota is full
    addTxByAddress.mockImplementation(() => {
      throw new DOMException('exceeded the quota', 'QuotaExceededError');
    });

    // The caller must be free to report the bridge on its own terms
    expect(() => recordBridgeTx(ADDRESS, tx)).not.toThrow();
    expect(recordBridgeTx(ADDRESS, tx)).toBe(false);
  });
});
