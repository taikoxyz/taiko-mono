import type { Address } from 'viem';

import type { FailedBridgeTx } from '$libs/relayer';

import { fetchTransactions } from './fetchTransactions';
import { type BridgeTransaction, MessageStatus } from './types';

// Two relayers, because the interesting case is one of them failing while the other works
vi.mock('$libs/relayer', () => ({
  relayerApiServices: [{ getAllBridgeTransactionByAddress: vi.fn() }, { getAllBridgeTransactionByAddress: vi.fn() }],
}));

vi.mock('$libs/storage', () => ({
  bridgeTxService: {
    getAllTxByAddress: vi.fn().mockResolvedValue([]),
    removeTransactions: vi.fn(),
  },
}));

import { relayerApiServices } from '$libs/relayer';
import { bridgeTxService } from '$libs/storage';

const ADDRESS = '0x1111111111111111111111111111111111111111' as Address;

const getAllByAddress = vi.mocked(relayerApiServices[0].getAllBridgeTransactionByAddress);
const getAllByAddressSecond = vi.mocked(relayerApiServices[1].getAllBridgeTransactionByAddress);
const getLocalTxs = vi.mocked(bridgeTxService.getAllTxByAddress);

const tx = (srcTxHash: string, msgStatus?: MessageStatus) => ({ srcTxHash, msgStatus }) as unknown as BridgeTransaction;

const message = (srcTxHash: string, msgHash: string) => ({ srcTxHash, msgHash }) as unknown as BridgeTransaction;

const page = (txs: BridgeTransaction[], max_page: number, failedTxs: FailedBridgeTx[] = []) => ({
  txs,
  paginationInfo: { page: 0, size: 500, total: txs.length, total_pages: 1, first: true, last: true, max_page },
  failedTxs,
});

/** A relayer row that failed to enhance; it knows its message hash, like the real ones do */
const failedRow = (srcTxHash: string, msgHash: string) => ({ srcTxHash, msgHash }) as unknown as FailedBridgeTx;

describe('fetchTransactions', () => {
  beforeEach(() => {
    getAllByAddress.mockReset();
    // The second relayer stays quiet unless a test says otherwise
    getAllByAddressSecond.mockReset().mockResolvedValue(page([], 0));
    getLocalTxs.mockReset().mockResolvedValue([]);
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

  it('keeps both messages a single transaction emitted', async () => {
    // One transaction, two MessageSent events: two rows, each claimed on its own. Keying
    // the dedupe off the transaction hash dropped the second and the user could not claim it
    getAllByAddress.mockResolvedValueOnce(page([message('0xtx', '0xmsgA'), message('0xtx', '0xmsgB')], 0));

    const { mergedTransactions } = await fetchTransactions(ADDRESS);

    expect(mergedTransactions.map((transaction) => transaction.msgHash).sort()).toEqual(['0xmsgA', '0xmsgB']);
  });

  it('still drops a message two relayers both returned', async () => {
    getAllByAddress.mockResolvedValueOnce(page([message('0xtx', '0xmsg')], 0));
    getAllByAddressSecond.mockResolvedValueOnce(page([message('0xtx', '0xmsg')], 0));

    const { mergedTransactions } = await fetchTransactions(ADDRESS);

    expect(mergedTransactions).toHaveLength(1);
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

  it('sums transactions that failed to load across every relayer page', async () => {
    // Given: page 0 lost 2 transactions to failed RPC reads, page 1 lost 3
    getAllByAddress
      .mockResolvedValueOnce(page([tx('0xa')], 1, [failedRow('0xt1', '0xf1'), failedRow('0xt2', '0xf2')]))
      .mockResolvedValueOnce(
        page([tx('0xb')], 1, [failedRow('0xt3', '0xf3'), failedRow('0xt4', '0xf4'), failedRow('0xt5', '0xf5')]),
      );

    // When
    const { failedCount, mergedTransactions } = await fetchTransactions(ADDRESS);

    // Then
    expect(failedCount).toBe(5);
    expect(mergedTransactions).toHaveLength(2);
  });

  it('counts a transaction that failed on more than one page only once', async () => {
    // Given: the relayer returns the same transaction on both pages and it fails both times.
    // Summing raw per-page tallies would report one lost transaction as two.
    getAllByAddress
      .mockResolvedValueOnce(page([tx('0xa')], 1, [failedRow('0xt1', '0xf1')]))
      .mockResolvedValueOnce(page([tx('0xb')], 1, [failedRow('0xt1', '0xf1')]));

    // When
    const { failedCount } = await fetchTransactions(ADDRESS);

    // Then
    expect(failedCount).toBe(1);
  });

  it('does not count a message that failed once but loaded from elsewhere', async () => {
    // Given: page 0 could not enhance message 0xdupe, page 1 returned it successfully. It is in
    // the list, so reporting it as unloadable would be telling the user about a loss they can
    // see did not happen.
    getAllByAddress
      .mockResolvedValueOnce(page([tx('0xa')], 1, [failedRow('0xtdupe', '0xdupe')]))
      .mockResolvedValueOnce(page([message('0xtdupe', '0xdupe')], 1));

    // When
    const { failedCount, mergedTransactions } = await fetchTransactions(ADDRESS);

    // Then
    expect(mergedTransactions.map((transaction) => transaction.srcTxHash).sort()).toEqual(['0xa', '0xtdupe']);
    expect(failedCount).toBe(0);
  });

  it('lets a local row stand in for one message of its transaction, not every one', async () => {
    // Given: a batching wallet sent one transaction that emitted two messages, and both failed to
    // enhance. The local row carries no message hash, so it cannot say which of the two it is -
    // it stands for one of them. Letting it absorb both would report a complete history while a
    // claimable message is missing from the list.
    getLocalTxs.mockResolvedValue([tx('0xtx')]);
    getAllByAddress.mockResolvedValueOnce(page([], 0, [failedRow('0xtx', '0xmsgA'), failedRow('0xtx', '0xmsgB')]));

    // When
    const { failedCount, mergedTransactions } = await fetchTransactions(ADDRESS);

    // Then: one row on screen, one message still unaccounted for
    expect(mergedTransactions).toHaveLength(1);
    expect(failedCount).toBe(1);
  });

  it('still counts a failed message when a sibling message of the same transaction loaded', async () => {
    // Given: one transaction emitted two messages. 0xmsgB loaded, 0xmsgA did not. They share a
    // transaction hash but are claimed separately, so the one that loaded cannot stand in for
    // the one that did not - keying the reconciliation off srcTxHash would erase this failure.
    getAllByAddress.mockResolvedValueOnce(page([message('0xtx', '0xmsgB')], 0, [failedRow('0xtx', '0xmsgA')]));

    // When
    const { failedCount, mergedTransactions } = await fetchTransactions(ADDRESS);

    // Then
    expect(mergedTransactions).toHaveLength(1);
    expect(failedCount).toBe(1);
  });

  it('does not count a transaction the local history still shows', async () => {
    // Given: the relayer could not enhance 0xlocal, but the user bridged it from this browser so
    // it is in local storage. The merge keeps a local transaction exactly when the relayer set
    // lacks its hash, so the row is on screen - reporting it as unloadable would contradict what
    // the user can see.
    getLocalTxs.mockResolvedValue([tx('0xlocal')]);
    getAllByAddress.mockResolvedValueOnce(page([tx('0xa')], 0, [failedRow('0xlocal', '0xmlocal')]));

    // When
    const { failedCount, mergedTransactions } = await fetchTransactions(ADDRESS);

    // Then
    expect(mergedTransactions.map((transaction) => transaction.srcTxHash).sort()).toEqual(['0xa', '0xlocal']);
    expect(failedCount).toBe(0);
  });

  it('still counts a failed transaction the local history does not have', async () => {
    // The companion case: nothing else brings 0xgone back, so it really is missing
    getLocalTxs.mockResolvedValue([tx('0xunrelated')]);
    getAllByAddress.mockResolvedValueOnce(page([tx('0xa')], 0, [failedRow('0xgone', '0xmgone')]));

    const { failedCount } = await fetchTransactions(ADDRESS);

    expect(failedCount).toBe(1);
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

  it('keeps the count from completed pages when a later page fails', async () => {
    // Given: page 0 answers and loses 2 transactions to failed on-chain reads, then page 1 throws.
    // fetchAllRelayerPages returns early here, so the count it already accumulated has to travel
    // out with the error rather than being discarded with the rest of the history.
    getAllByAddress
      .mockResolvedValueOnce(page([tx('0xa')], 1, [failedRow('0xt1', '0xf1'), failedRow('0xt2', '0xf2')]))
      .mockRejectedValueOnce(new Error('page 1 unavailable'));

    // When
    const { error, failedCount, mergedTransactions } = await fetchTransactions(ADDRESS);

    // Then: both signals survive - the truncated history AND what the fetched part lost
    expect(error).toBeInstanceOf(Error);
    expect(failedCount).toBe(2);
    expect(mergedTransactions).toHaveLength(1);
  });

  it('keeps the count when a completed page produced no surviving rows', async () => {
    // Given: page 0 answers, but every row on it fails to enhance, so it contributes 0
    // transactions and a count of 2. Page 1 then throws. Keying the "nothing was fetched"
    // check on txs.length would rethrow here and discard those 2 - the page did answer.
    getAllByAddress
      .mockResolvedValueOnce(page([], 1, [failedRow('0xt1', '0xf1'), failedRow('0xt2', '0xf2')]))
      .mockRejectedValueOnce(new Error('page 1 unavailable'));

    // When
    const { error, failedCount, mergedTransactions } = await fetchTransactions(ADDRESS);

    // Then
    expect(error).toBeInstanceOf(Error);
    expect(failedCount).toBe(2);
    expect(mergedTransactions).toHaveLength(0);
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

    it('still counts the failed loads reported by the relayers that answered', async () => {
      // A rejected relayer has no count to give; the ones that answered still do, and losing
      // their count because a sibling died would under-report what the user cannot see
      getAllByAddress.mockRejectedValue(new Error('relayer down'));
      getAllByAddressSecond.mockResolvedValueOnce(
        page([tx('0xa')], 0, [
          failedRow('0xt1', '0xf1'),
          failedRow('0xt2', '0xf2'),
          failedRow('0xt3', '0xf3'),
          failedRow('0xt4', '0xf4'),
        ]),
      );

      const { error, failedCount } = await fetchTransactions(ADDRESS);

      expect(error).toBeInstanceOf(Error);
      expect(failedCount).toBe(4);
    });
  });
});
