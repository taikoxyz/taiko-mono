import { get } from 'svelte/store';
import { WaitForTransactionReceiptTimeoutError } from 'viem';

import { FailedTransactionError, TransactionTimeoutError } from '$libs/error';

const waitForTransactionReceipt = vi.fn();
vi.mock('@wagmi/core', () => ({
  waitForTransactionReceipt: (...args: unknown[]) => waitForTransactionReceipt(...args),
}));
vi.mock('$libs/util/balance', () => ({ refreshUserBalance: vi.fn() }));
vi.mock('$libs/wagmi', () => ({ config: {} }));

import { pendingTransactions } from './pendingTransactions';

const HASH = '0xabc' as const;

// viem's error takes constructor options this test does not need to reproduce
const timeoutError = Object.create(WaitForTransactionReceiptTimeoutError.prototype);

describe('pendingTransactions.add', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    pendingTransactions.set([]);
  });

  it('resolves and drops the hash once the transaction succeeds', async () => {
    waitForTransactionReceipt.mockResolvedValue({ status: 'success' });

    await expect(pendingTransactions.add(HASH, 1)).resolves.toEqual({ status: 'success' });
    expect(get(pendingTransactions)).toEqual([]);
  });

  it('rejects with FailedTransactionError when the receipt reverted', async () => {
    waitForTransactionReceipt.mockResolvedValue({ status: 'reverted' });

    await expect(pendingTransactions.add(HASH, 1)).rejects.toBeInstanceOf(FailedTransactionError);
  });

  it('rejects with TransactionTimeoutError when the wait times out', async () => {
    // Dialogs branch on this to tell "still in the mempool" from "reverted"; a plain
    // FailedTransactionError here re-enables their action button for a live transaction
    waitForTransactionReceipt.mockRejectedValue(timeoutError);

    await expect(pendingTransactions.add(HASH, 1)).rejects.toBeInstanceOf(TransactionTimeoutError);
  });

  it('rejects with FailedTransactionError for any other wait failure', async () => {
    waitForTransactionReceipt.mockRejectedValue(new Error('rpc down'));

    await expect(pendingTransactions.add(HASH, 1)).rejects.toBeInstanceOf(FailedTransactionError);
  });
});
