import { getLoadWarning } from './loadWarning';

describe('getLoadWarning', () => {
  it('is silent when everything loaded', () => {
    expect(getLoadWarning({ failedCount: 0 })).toBeNull();
  });

  it('reports the relayer when the relayer itself failed', () => {
    expect(getLoadWarning({ error: new Error('relayer down'), failedCount: 0 })).toEqual({
      key: 'transactions.errors.relayer_offline',
    });
  });

  it('reports the count when individual transactions failed to load', () => {
    expect(getLoadWarning({ failedCount: 3 })).toEqual({
      key: 'transactions.errors.partial_load',
      values: { count: 3 },
    });
  });

  it('blames the relayer first when both are set', () => {
    // A dead relayer explains the missing transactions; two toasts would just be noise.
    expect(getLoadWarning({ error: new Error('relayer down'), failedCount: 3 })).toEqual({
      key: 'transactions.errors.relayer_offline',
    });
  });
});
