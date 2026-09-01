import type { Address } from 'viem';

import { fetchTransactions } from './fetchTransactions';
import { type BridgeTransaction, MessageStatus } from './types';

vi.mock('$libs/relayer', () => ({
  relayerApiServices: [
    {
      getAllBridgeTransactionByAddress: vi.fn(),
    },
  ],
}));

vi.mock('$libs/storage', () => ({
  bridgeTxService: {
    getAllTxByAddress: vi.fn().mockResolvedValue([]),
  },
}));

import { relayerApiServices } from '$libs/relayer';

const ADDRESS = '0x1111111111111111111111111111111111111111' as Address;

const getAllByAddress = vi.mocked(relayerApiServices[0].getAllBridgeTransactionByAddress);

const tx = (srcTxHash: string, msgStatus?: MessageStatus) => ({ srcTxHash, msgStatus }) as unknown as BridgeTransaction;

const page = (txs: BridgeTransaction[], max_page: number, failedCount = 0) => ({
  txs,
  paginationInfo: { page: 0, size: 500, total: txs.length, total_pages: 1, first: true, last: true, max_page },
  failedCount,
});

describe('fetchTransactions', () => {
  beforeEach(() => {
    getAllByAddress.mockReset();
  });

  it('does not keep reporting an error after the relayer has recovered', async () => {
    // Given: the first fetch fails
    getAllByAddress.mockRejectedValueOnce(new Error('relayer down'));
    const failed = await fetchTransactions(ADDRESS);
    expect(failed.error).toBeInstanceOf(Error);

    // When: the next fetch succeeds
    getAllByAddress.mockResolvedValueOnce(page([tx('0xa')], 0));
    const recovered = await fetchTransactions(ADDRESS);

    // Then: no stale error survives from the earlier failure
    expect(recovered.error).toBeUndefined();
    expect(recovered.mergedTransactions).toHaveLength(1);
  });

  it('fetches all relayer pages and deduplicates transactions across them', async () => {
    getAllByAddress
      .mockResolvedValueOnce(page([tx('0xa'), tx('0xb')], 1))
      .mockResolvedValueOnce(page([tx('0xb'), tx('0xc')], 1));

    const { mergedTransactions } = await fetchTransactions(ADDRESS);

    expect(getAllByAddress).toHaveBeenCalledTimes(2);
    expect(getAllByAddress).toHaveBeenNthCalledWith(1, ADDRESS, { page: 0, size: 500 }, undefined);
    expect(getAllByAddress).toHaveBeenNthCalledWith(2, ADDRESS, { page: 1, size: 500 }, undefined);
    expect(mergedTransactions.map((transaction) => transaction.srcTxHash).sort()).toEqual(['0xa', '0xb', '0xc']);
  });

  it('stops after the first page when the relayer reports no further pages', async () => {
    getAllByAddress.mockResolvedValueOnce(page([tx('0xa')], 0));

    await fetchTransactions(ADDRESS);

    expect(getAllByAddress).toHaveBeenCalledTimes(1);
  });

  it('keeps the pages already fetched when a later page fails', async () => {
    getAllByAddress
      .mockResolvedValueOnce(page([tx('0xa')], 3))
      .mockRejectedValueOnce(new Error('relayer page 2 blew up'));

    const { mergedTransactions, error } = await fetchTransactions(ADDRESS);

    // The first page survives and the fetch is not reported as a total failure
    expect(mergedTransactions.map((transaction) => transaction.srcTxHash)).toEqual(['0xa']);
    expect(error).toBeUndefined();
  });

  it('reports the error when the very first page fails', async () => {
    getAllByAddress.mockRejectedValueOnce(new Error('relayer down'));

    const { mergedTransactions, error } = await fetchTransactions(ADDRESS);

    expect(mergedTransactions).toHaveLength(0);
    expect(error).toBeInstanceOf(Error);
  });

  it('sorts actionable statuses first and keeps RECALLED between FAILED and DONE', async () => {
    getAllByAddress.mockResolvedValueOnce(
      page(
        [
          tx('0xdone', MessageStatus.DONE),
          tx('0xrecalled', MessageStatus.RECALLED),
          tx('0xnew', MessageStatus.NEW),
          tx('0xfailed', MessageStatus.FAILED),
          tx('0xretriable', MessageStatus.RETRIABLE),
        ],
        0,
      ),
    );

    const { mergedTransactions } = await fetchTransactions(ADDRESS);

    expect(mergedTransactions.map((transaction) => transaction.srcTxHash)).toEqual([
      '0xnew',
      '0xretriable',
      '0xfailed',
      '0xrecalled',
      '0xdone',
    ]);
  });

  it('sums transactions that failed to load across every relayer page', async () => {
    // Given: page 0 lost 2 transactions to failed RPC reads, page 1 lost 3
    getAllByAddress.mockResolvedValueOnce(page([tx('0xa')], 1, 2)).mockResolvedValueOnce(page([tx('0xb')], 1, 3));

    // When
    const { failedCount, mergedTransactions } = await fetchTransactions(ADDRESS);

    // Then
    expect(failedCount).toBe(5);
    expect(mergedTransactions).toHaveLength(2);
  });

  it('reports no failures when every page loaded cleanly', async () => {
    getAllByAddress.mockResolvedValueOnce(page([tx('0xa')], 0));

    const { failedCount } = await fetchTransactions(ADDRESS);

    expect(failedCount).toBe(0);
  });

  it('reports no failure count when the relayer itself failed', async () => {
    // Given: the first page throws, so nothing was ever enhanced
    getAllByAddress.mockRejectedValueOnce(new Error('relayer down'));

    // When
    const { error, failedCount } = await fetchTransactions(ADDRESS);

    // Then: the relayer error is the story, not a per-transaction count
    expect(error).toBeInstanceOf(Error);
    expect(failedCount).toBe(0);
  });
});
