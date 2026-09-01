import { FailedTransactionError, ReceiptUnavailableError, TransactionTimeoutError } from '$libs/error';

const add = vi.fn();
vi.mock('$stores/pendingTransactions', () => ({
  pendingTransactions: { add: (...args: unknown[]) => add(...args) },
}));

import { awaitDialogTransaction } from './awaitDialogTransaction';

const HASH = '0xabc' as const;

describe('awaitDialogTransaction', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('waits on the given chain', async () => {
    add.mockResolvedValue({});

    await awaitDialogTransaction(HASH, 167000);

    expect(add).toHaveBeenCalledWith(HASH, 167000);
  });

  it('reports a mined transaction as confirmed', async () => {
    add.mockResolvedValue({});

    expect(await awaitDialogTransaction(HASH, 1)).toBe('confirmed');
  });

  it('reports a reverted transaction as failed', async () => {
    add.mockRejectedValue(new FailedTransactionError('reverted'));

    expect(await awaitDialogTransaction(HASH, 1)).toBe('failed');
  });

  it('separates a timed-out wait from a failure', async () => {
    // The transaction is still live: a dialog that cannot tell these apart re-enables its
    // action button for a message whose first attempt may still confirm
    add.mockRejectedValue(new TransactionTimeoutError('timed out'));

    expect(await awaitDialogTransaction(HASH, 1)).toBe('pending');
  });

  it('treats an unreadable receipt as pending, not as a failure', async () => {
    // An RPC that drops the connection says nothing about the transaction
    add.mockRejectedValue(new ReceiptUnavailableError('rpc down'));

    expect(await awaitDialogTransaction(HASH, 1)).toBe('pending');
  });

  it('treats an unrecognised rejection as pending, since it says nothing either', async () => {
    add.mockRejectedValue(new Error('something else'));

    expect(await awaitDialogTransaction(HASH, 1)).toBe('pending');
  });
});
