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
let storage: Storage;

beforeEach(() => {
  storage = createStorage();
  service = new BridgeTxService(storage);
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

  it('restores the bigints inside a stored message', async () => {
    // Nothing writes a message to storage today, but a message whose id, value and fee
    // came back as strings goes straight to proof generation and the recall path, which
    // encode them as uint256 - a failure nothing else here would report
    const message = {
      id: BigInt(7),
      srcChainId: BigInt(1),
      destChainId: BigInt(167000),
      value: BigInt('2500000000000000000'),
      fee: BigInt('130220640000000'),
      gasLimit: 140000,
      from: ADDRESS,
      srcOwner: ADDRESS,
      destOwner: ADDRESS,
      to: ADDRESS,
      data: '0x' as const,
    };
    service.addTxByAddress(ADDRESS, tx('0xa', { message } as Partial<BridgeTransaction>));

    const [stored] = await service.getAllTxByAddress(ADDRESS);

    expect(stored.message?.id).toBe(BigInt(7));
    expect(stored.message?.value).toBe(BigInt('2500000000000000000'));
    expect(stored.message?.fee).toBe(BigInt('130220640000000'));
    expect(stored.message?.srcChainId).toBe(BigInt(1));
    expect(stored.message?.destChainId).toBe(BigInt(167000));
    expect(stored.message?.gasLimit).toBe(140000);
  });

  it('leaves a transaction without a message alone', async () => {
    service.addTxByAddress(ADDRESS, tx('0xa'));

    const [stored] = await service.getAllTxByAddress(ADDRESS);

    expect(stored.message).toBeUndefined();
  });

  it('skips an entry it cannot restore rather than losing the whole history', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    service.addTxByAddress(ADDRESS, tx('0xa'));
    service.addTxByAddress(ADDRESS, tx('0xb'));

    // A record corrupted the way a partial write or a version skew would leave it. BigInt()
    // throws on this, and restoring the array with map took every other transaction with it
    const key = storage.key(0) as string;
    const raw = JSON.parse(storage.getItem(key) as string) as { srcTxHash: string; amount: unknown }[];
    (raw.find((entry) => entry.srcTxHash === '0xa') as { amount: unknown }).amount = { not: 'a number' };
    storage.setItem(key, JSON.stringify(raw));

    const stored = await service.getAllTxByAddress(ADDRESS);

    expect(stored.map((entry) => entry.srcTxHash)).toEqual(['0xb']);
    vi.restoreAllMocks();
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
