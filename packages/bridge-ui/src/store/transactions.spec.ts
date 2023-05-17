import { get } from 'svelte/store';
import type { Signer, Transaction, ethers } from 'ethers';
import { pendingTransactions } from './transactions';

jest.mock('../constants/envVars');

// Transaction we're going to add to the store
const tx = { hash: '0x789' } as Transaction;

// These are the pending transactions we'll have initially in the store
const initialTxs = [{ hash: '0x123' }, { hash: '0x456' }] as Transaction[];

const mockSigner = (
  receipt: ethers.providers.TransactionReceipt | null,
  timeout = false,
) => {
  const waitForTransaction = jest.fn().mockImplementation(() => {
    if (timeout) {
      return Promise.reject({ code: 'TIMEOUT' });
    } else {
      return Promise.resolve(receipt);
    }
  });

  return {
    provider: { waitForTransaction },
  } as unknown as Signer;
};

describe('transaction stores', () => {
  beforeEach(() => {
    pendingTransactions.set(initialTxs);
  });

  it('tests a successful pendingTransactions', () => {
    const txTeceipt = { status: 1 } as ethers.providers.TransactionReceipt;
    const signer = mockSigner(txTeceipt);

    pendingTransactions
      .add(tx, signer)
      .then((receipt) => {
        // The transaction should have been removed from the store
        expect(get(pendingTransactions)).toStrictEqual(initialTxs);

        expect(receipt).toEqual(txTeceipt);
      })
      .catch(() => {
        throw new Error('should not have thrown');
      });

    // The transaction should have added to the store
    expect(get(pendingTransactions)).toStrictEqual([...initialTxs, tx]);
  });

  it('tests a failed pendingTransactions custom store', () => {
    const txTeceipt = { status: 0 } as ethers.providers.TransactionReceipt;
    const signer = mockSigner(txTeceipt);

    pendingTransactions
      .add(tx, signer)
      .then(() => {
        throw new Error('should have thrown');
      })
      .catch((error) => {
        // The transaction should have been removed from the store
        expect(get(pendingTransactions)).toStrictEqual(initialTxs);

        expect(error).toHaveProperty('cause', txTeceipt);
      });

    // The transaction should have added to the store
    expect(get(pendingTransactions)).toStrictEqual([...initialTxs, tx]);
  });

  it('tests timeout transaction', () => {
    const signer = mockSigner(null, true);

    pendingTransactions
      .add(tx, signer)
      .then(() => {
        throw new Error('should have thrown');
      })
      .catch((error) => {
        expect(error).toHaveProperty(
          'message',
          'timeout while waiting for transaction to be mined',
        );
      });
  });
});
