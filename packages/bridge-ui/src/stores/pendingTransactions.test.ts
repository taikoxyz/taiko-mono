import { get } from 'svelte/store';
import { WaitForTransactionReceiptTimeoutError } from 'viem';

import { FailedTransactionError, ReceiptUnavailableError, TransactionTimeoutError } from '$libs/error';

const waitForTransactionReceipt = vi.fn();
const getPublicClient = vi.fn();
vi.mock('@wagmi/core', () => ({
  getPublicClient: (...args: unknown[]) => getPublicClient(...args),
  // What @wagmi/core 2.9.1 does with a reverted receipt: it re-simulates the transaction and
  // throws a plain Error, so a store waiting through it never sees `status: 'reverted'`
  waitForTransactionReceipt: async (...args: unknown[]) => {
    const receipt = await waitForTransactionReceipt(...args);
    if (receipt.status === 'reverted') throw new Error('unknown reason');
    return receipt;
  },
}));
vi.mock('$libs/util/balance', () => ({ refreshUserBalance: vi.fn() }));
vi.mock('$libs/wagmi', () => ({ config: { chains: [] } }));

import { pendingTransaction } from '$config';

import { pendingTransactions } from './pendingTransactions';

const HASH = '0xabc' as const;

// viem's error takes constructor options this test does not need to reproduce
const timeoutError = Object.create(WaitForTransactionReceiptTimeoutError.prototype);

describe('pendingTransactions.add', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    getPublicClient.mockReturnValue({
      waitForTransactionReceipt: (...args: unknown[]) => waitForTransactionReceipt(...args),
    });
    pendingTransactions.set([]);
  });

  it('resolves and drops the hash once the transaction succeeds', async () => {
    waitForTransactionReceipt.mockResolvedValue({ status: 'success' });

    await expect(pendingTransactions.add(HASH, 1)).resolves.toEqual({ status: 'success' });
    expect(get(pendingTransactions)).toEqual([]);
  });

  it("waits on the client of the transaction's chain, with the configured timeout", async () => {
    waitForTransactionReceipt.mockResolvedValue({ status: 'success' });

    await pendingTransactions.add(HASH, 5);

    expect(getPublicClient).toHaveBeenCalledWith(expect.anything(), { chainId: 5 });
    expect(waitForTransactionReceipt).toHaveBeenCalledWith(
      expect.objectContaining({ hash: HASH, timeout: pendingTransaction.waitTimeout }),
    );
  });

  it('rejects with FailedTransactionError when the receipt reverted', async () => {
    // The one outcome that means the transaction itself failed. Waiting through the wagmi
    // wrapper turned this into a thrown Error and, from there, into "the receipt could not
    // be read" - which the dialogs and the confirmation step both treat as a transaction
    // that may still confirm: the claim button stayed disabled, the reverted bridge
    // transaction was recorded into the local history, and the failure toast never showed
    waitForTransactionReceipt.mockResolvedValue({ status: 'reverted' });

    await expect(pendingTransactions.add(HASH, 1)).rejects.toBeInstanceOf(FailedTransactionError);
    expect(get(pendingTransactions)).toEqual([]);
  });

  it('rejects with TransactionTimeoutError when the wait times out', async () => {
    // Dialogs branch on this to tell "still in the mempool" from "reverted"; a plain
    // FailedTransactionError here re-enables their action button for a live transaction
    waitForTransactionReceipt.mockRejectedValue(timeoutError);

    await expect(pendingTransactions.add(HASH, 1)).rejects.toBeInstanceOf(TransactionTimeoutError);
  });

  it('rejects with ReceiptUnavailableError when the wait itself failed', async () => {
    // Not a FailedTransactionError: an RPC that dropped the connection says nothing about
    // a transaction that may still be in the mempool, and callers branch on the difference
    waitForTransactionReceipt.mockRejectedValue(new Error('rpc down'));

    await expect(pendingTransactions.add(HASH, 1)).rejects.toBeInstanceOf(ReceiptUnavailableError);
  });

  describe('a transaction the wallet replaced under the same nonce', () => {
    // viem resolves with the replacement's receipt and reports why through onReplaced
    const replacedWith = (reason: string) =>
      waitForTransactionReceipt.mockImplementation(async ({ onReplaced }: { onReplaced: (r: unknown) => void }) => {
        onReplaced({ reason, transaction: { hash: '0xdef' } });
        return { status: 'success', transactionHash: '0xdef' };
      });

    it('rejects a cancelled transaction as failed rather than completed', async () => {
      // A MetaMask "cancel" is a successful 0-value self-transfer: as a receipt it looks
      // like success, and the bridge transaction was recorded and toasted as completed
      replacedWith('cancelled');

      await expect(pendingTransactions.add(HASH, 1)).rejects.toBeInstanceOf(FailedTransactionError);
    });

    it('rejects a transaction replaced by a different one', async () => {
      replacedWith('replaced');

      await expect(pendingTransactions.add(HASH, 1)).rejects.toBeInstanceOf(FailedTransactionError);
    });

    it('resolves a repriced transaction with the receipt that mined', async () => {
      // Same call, higher fee, new hash: the bridge happened, under the replacement's hash
      replacedWith('repriced');

      await expect(pendingTransactions.add(HASH, 1)).resolves.toEqual({ status: 'success', transactionHash: '0xdef' });
    });
  });

  it('rejects with ReceiptUnavailableError when the chain has no client', async () => {
    // Nothing was read, so nothing is known about the transaction
    getPublicClient.mockReturnValue(undefined);

    await expect(pendingTransactions.add(HASH, 1)).rejects.toBeInstanceOf(ReceiptUnavailableError);
  });
});
