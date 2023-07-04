import type { ethers, Signer, Transaction } from 'ethers';
import { get } from 'svelte/store';

import type { TransactionReceipt } from '../domain/transaction';
import { pendingTransactions } from './transaction';

jest.mock('../constants/envVars');

// Transaction we're going to add to the store
const tx = { hash: '0x789' } as Transaction;

// These are the pending transactions we'll have initially in the store
const initialTxs = [{ hash: '0x123' }, { hash: '0x456' }] as Transaction[];

const mockSigner = (
  receipt: TransactionReceipt | null,
  failWithCode?: string,
) => {
  const waitForTransaction = jest.fn().mockImplementation(() => {
    if (failWithCode) {
      return Promise.reject({ code: failWithCode });
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
    const txTeceipt = { status: 1 } as TransactionReceipt;
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

  it('tests timeout while waiting for transaction', () => {
    const signer = mockSigner(null, 'TIMEOUT');

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

  it('tests unknown error while waiting for transaction', () => {
    const signer = mockSigner(null, 'UNKNOWN');

    pendingTransactions
      .add(tx, signer)
      .then(() => {
        throw new Error('should have thrown');
      })
      .catch((error) => {
        expect(error).toHaveProperty('message', 'transaction failed');
      });
  });
});
