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

  it('reports both when a relayer failed and transactions were also lost', () => {
    // These coincide routinely: one relayer dies while another answers and loses transactions to
    // failed on-chain reads. Reporting only the relayer would swallow a count the user cannot
    // learn any other way.
    expect(getLoadWarning({ error: new Error('relayer down'), failedCount: 3 })).toEqual({
      key: 'transactions.errors.relayer_offline_and_partial_load',
      values: { count: 3 },
    });
  });

  it('does not use the combined message when only the relayer failed', () => {
    expect(getLoadWarning({ error: new Error('relayer down'), failedCount: 0 })).toEqual({
      key: 'transactions.errors.relayer_offline',
    });
  });
});
