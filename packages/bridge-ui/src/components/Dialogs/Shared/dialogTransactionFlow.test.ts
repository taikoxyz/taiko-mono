import { FailedTransactionError, TransactionTimeoutError } from '$libs/error';

const add = vi.fn();
vi.mock('$stores/pendingTransactions', () => ({
  pendingTransactions: { add: (...args: unknown[]) => add(...args) },
}));

const errorToast = vi.fn();
const successToast = vi.fn();
const warningToast = vi.fn();
const infoToast = vi.fn();
vi.mock('$components/NotificationToast', () => ({
  errorToast: (...args: unknown[]) => errorToast(...args),
  successToast: (...args: unknown[]) => successToast(...args),
  warningToast: (...args: unknown[]) => warningToast(...args),
}));
vi.mock('$components/NotificationToast/NotificationToast.svelte', () => ({
  infoToast: (...args: unknown[]) => infoToast(...args),
}));

vi.mock('$chainConfig', () => ({
  chainConfig: { 1: { blockExplorers: { default: { url: 'https://explorer.test' } } } },
}));

import { reportDialogTransaction } from './dialogTransactionFlow';

const t = (id: string, options?: { values?: Record<string, string> }) =>
  options?.values ? `${id}|${JSON.stringify(options.values)}` : id;

const run = () =>
  reportDialogTransaction({
    txHash: '0xabc',
    chainId: 1,
    t,
    failureTitleKey: 'bridge.errors.retry_error',
  });

describe('reportDialogTransaction', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('announces the transaction with an explorer link before waiting', async () => {
    add.mockResolvedValue({});

    await run();

    expect(infoToast).toHaveBeenCalledWith({
      title: 'transactions.actions.claim.tx.title',
      message: 'transactions.actions.claim.tx.message|{"url":"https://explorer.test/tx/0xabc"}',
    });
  });

  it('waits on the chain it was given', async () => {
    add.mockResolvedValue({});

    await run();

    expect(add).toHaveBeenCalledWith('0xabc', 1);
  });

  it('reports a mined transaction as completed, not as still in progress', async () => {
    // The retry dialog announced a *completed* retry with the "track the progress"
    // message, because it carried its own copy of this and the copy had drifted
    add.mockResolvedValue({});

    expect(await run()).toBe('confirmed');
    expect(successToast).toHaveBeenCalledWith({
      title: 'transactions.actions.claim.success.title',
      message: 'transactions.actions.claim.success.message|{"url":"https://explorer.test/tx/0xabc"}',
    });
    expect(errorToast).not.toHaveBeenCalled();
    expect(warningToast).not.toHaveBeenCalled();
  });

  it('warns rather than errors when only the wait gave up', async () => {
    add.mockRejectedValue(new TransactionTimeoutError('timed out'));

    expect(await run()).toBe('pending');
    expect(warningToast).toHaveBeenCalledWith({
      title: 'bridge.actions.bridge.timeout.title',
      message: 'bridge.actions.bridge.timeout.message|{"url":"https://explorer.test/tx/0xabc"}',
    });
    expect(errorToast).not.toHaveBeenCalled();
    expect(successToast).not.toHaveBeenCalled();
  });

  it('reports a revert with the failure title the caller chose', async () => {
    add.mockRejectedValue(new FailedTransactionError('reverted'));

    expect(await run()).toBe('failed');
    expect(errorToast).toHaveBeenCalledWith({ title: 'bridge.errors.retry_error' });
    expect(successToast).not.toHaveBeenCalled();
  });
});
