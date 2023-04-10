import { get } from 'svelte/store';
import type { Signer, Transaction } from 'ethers';
import { pendingTransactions } from './transactions';

jest.mock('../constants/envVars');

// Transaction we're going to add to the store
const tx = { hash: '0x789' } as Transaction;

// These are the pending transactions we'll have initially in the store
const initialTxs = [{ hash: '0x123' }, { hash: '0x456' }] as Transaction[];

describe('transaction stores', () => {
  it('tests pendingTransactions custom store', async () => {
    pendingTransactions.set(initialTxs);

    // Mock the waitForTransaction method
    const waitForTransactionDone = Promise.resolve();
    const waitForTransaction = jest
      .fn()
      .mockImplementation(() => waitForTransactionDone);

    // Mock the signer
    const signer = {
      provider: {
        waitForTransaction,
      },
    } as unknown as Signer;

    await pendingTransactions.add(tx, signer);

    // It should have added the transaction to the store
    expect(get(pendingTransactions)).toStrictEqual([...initialTxs, tx]);

    // It should have called waitForTransaction with the correct parameters
    expect(waitForTransaction).toHaveBeenCalledWith(tx.hash, 1);

    // We need to check if the right things happened after
    // the transaction was mined
    await waitForTransactionDone;

    // The transaction should have been removed from the store
    expect(get(pendingTransactions)).toStrictEqual(initialTxs);
  });
});
