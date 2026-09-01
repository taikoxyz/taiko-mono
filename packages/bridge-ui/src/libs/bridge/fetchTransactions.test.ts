import type { Address } from 'viem';

import { fetchTransactions } from './fetchTransactions';
import { type BridgeTransaction, MessageStatus } from './types';

// Two relayers, because the interesting case is one of them failing while the other works
vi.mock('$libs/relayer', () => ({
  relayerApiServices: [{ getAllBridgeTransactionByAddress: vi.fn() }, { getAllBridgeTransactionByAddress: vi.fn() }],
}));

vi.mock('$libs/storage', () => ({
  bridgeTxService: {
    getAllTxByAddress: vi.fn().mockResolvedValue([]),
  },
}));

import { relayerApiServices } from '$libs/relayer';

const ADDRESS = '0x1111111111111111111111111111111111111111' as Address;

const getAllByAddress = vi.mocked(relayerApiServices[0].getAllBridgeTransactionByAddress);
const getAllByAddressSecond = vi.mocked(relayerApiServices[1].getAllBridgeTransactionByAddress);

const tx = (srcTxHash: string, msgStatus?: MessageStatus) => ({ srcTxHash, msgStatus }) as unknown as BridgeTransaction;

const page = (txs: BridgeTransaction[], max_page: number) => ({
  txs,
  paginationInfo: { page: 0, size: 500, total: txs.length, total_pages: 1, first: true, last: true, max_page },
});

describe('fetchTransactions', () => {
  beforeEach(() => {
    getAllByAddress.mockReset();
    // The second relayer stays quiet unless a test says otherwise
    getAllByAddressSecond.mockReset().mockResolvedValue(page([], 0));
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

    // The first page survives...
    expect(mergedTransactions.map((transaction) => transaction.srcTxHash)).toEqual(['0xa']);
    // ...and the caller is told the history is partial. Degrading is fine; degrading in
    // silence leaves a partial list looking exactly like a complete one
    expect(error).toBeInstanceOf(Error);
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

  it('reports a history cut off at the page backstop', async () => {
    // Ten pages that all claim more remain: the backstop stops the fetch, and a truncated
    // history that looks complete is the outcome the error channel exists to prevent
    getAllByAddress.mockResolvedValue(page([tx('0xa')], 99));

    const { error } = await fetchTransactions(ADDRESS);

    expect(getAllByAddress).toHaveBeenCalledTimes(10);
    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).toContain('truncated');
  });

  it('reports no error when the history ends before the backstop', async () => {
    getAllByAddress.mockResolvedValueOnce(page([tx('0xa')], 0));

    const { error } = await fetchTransactions(ADDRESS);

    expect(error).toBeUndefined();
  });

  describe('when one relayer fails', () => {
    it('keeps the transactions the other relayers returned', async () => {
      getAllByAddress.mockRejectedValue(new Error('relayer down'));
      getAllByAddressSecond.mockResolvedValueOnce(page([tx('0xa'), tx('0xb')], 0));

      const { mergedTransactions, error } = await fetchTransactions(ADDRESS);

      // Promise.all rejected on the first failure and the catch blanked every result, so
      // one relayer being offline showed an empty list even though the other answered
      expect(mergedTransactions).toHaveLength(2);
      expect(error).toBeInstanceOf(Error);
    });

    it('still reports the failure so the caller can warn', async () => {
      getAllByAddress.mockRejectedValue(new Error('relayer down'));
      getAllByAddressSecond.mockResolvedValueOnce(page([tx('0xa')], 0));

      const { error } = await fetchTransactions(ADDRESS);

      expect(error).toBeInstanceOf(Error);
      expect((error as Error).message).toBe('relayer down');
    });

    it('reports no error when every relayer answers', async () => {
      getAllByAddress.mockResolvedValueOnce(page([tx('0xa')], 0));
      getAllByAddressSecond.mockResolvedValueOnce(page([tx('0xb')], 0));

      const { mergedTransactions, error } = await fetchTransactions(ADDRESS);

      expect(error).toBeUndefined();
      expect(mergedTransactions).toHaveLength(2);
    });
  });
});
