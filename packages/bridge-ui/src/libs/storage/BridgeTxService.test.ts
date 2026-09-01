/**
 * Stored transactions must come back with the types they were declared with.
 *
 * addTxByAddress stringifies every bigint on the way in and JSON.parse has no reviver on
 * the way out, so `processingFee` returned as the string "0" and
 * `shouldShowManualClaimEntry`'s `processingFee === 0n` could never match - the manual
 * claim entry never appeared for exactly the zero-fee transactions it was added for.
 */
import type { Address } from 'viem';
import { vi } from 'vitest';

vi.mock('@wagmi/core');
vi.mock('$bridgeConfig');

import { type BridgeTransaction, MessageStatus } from '$libs/bridge/types';
import { TokenType } from '$libs/token/types';

import { BridgeTxService } from './BridgeTxService';

const ADDRESS = '0x1111111111111111111111111111111111111111' as Address;

/** A minimal in-memory Storage, so the round trip through JSON is the real one */
const createStorage = (): Storage => {
  const map = new Map<string, string>();
  return {
    getItem: (key: string) => map.get(key) ?? null,
    setItem: (key: string, value: string) => void map.set(key, value),
    removeItem: (key: string) => void map.delete(key),
    clear: () => map.clear(),
    key: (index: number) => Array.from(map.keys())[index] ?? null,
    get length() {
      return map.size;
    },
  } as Storage;
};

const tx = (srcTxHash: string, overrides: Partial<BridgeTransaction> = {}): BridgeTransaction =>
  ({
    srcTxHash,
    msgHash: `${srcTxHash}-msg`,
    from: ADDRESS,
    amount: BigInt('1000000000000000000'),
    symbol: 'ETH',
    decimals: 18,
    srcChainId: BigInt(1),
    destChainId: BigInt(167000),
    tokenType: TokenType.ETH,
    processingFee: BigInt(0),
    status: MessageStatus.NEW,
    ...overrides,
  }) as BridgeTransaction;

let service: BridgeTxService;

beforeEach(() => {
  service = new BridgeTxService(createStorage());
});

describe('BridgeTxService storage round trip', () => {
  it('returns bigint fields as bigints, not as the strings JSON stored', async () => {
    service.addTxByAddress(ADDRESS, tx('0xa'));

    const [stored] = await service.getAllTxByAddress(ADDRESS);

    expect(typeof stored.processingFee).toBe('bigint');
    expect(stored.processingFee).toBe(BigInt(0));
    expect(stored.amount).toBe(BigInt('1000000000000000000'));
    expect(stored.srcChainId).toBe(BigInt(1));
    expect(stored.destChainId).toBe(BigInt(167000));
  });

  it('keeps a zero processing fee strictly equal to 0n', async () => {
    // shouldShowManualClaimEntry gates the manual "try claim" entry on exactly this
    service.addTxByAddress(ADDRESS, tx('0xa', { processingFee: BigInt(0) }));

    const [stored] = await service.getAllTxByAddress(ADDRESS);

    expect(stored.processingFee === BigInt(0)).toBe(true);
  });

  it('preserves a non-zero fee through the round trip', async () => {
    service.addTxByAddress(ADDRESS, tx('0xa', { processingFee: BigInt('130220640000000') }));

    const [stored] = await service.getAllTxByAddress(ADDRESS);

    expect(stored.processingFee).toBe(BigInt('130220640000000'));
  });

  it('can remove a stored transaction after reading it back', () => {
    // removeTransactions writes what it read, and a bare JSON.stringify throws on a
    // bigint - so restoring the types on read has to be matched on the write side
    service.addTxByAddress(ADDRESS, tx('0xa'));
    service.addTxByAddress(ADDRESS, tx('0xb'));

    expect(() => service.removeTransactions(ADDRESS, [tx('0xa')])).not.toThrow();
    expect(service.transactionIsStoredLocally(ADDRESS, tx('0xa'))).toBe(false);
    expect(service.transactionIsStoredLocally(ADDRESS, tx('0xb'))).toBe(true);
  });
});
