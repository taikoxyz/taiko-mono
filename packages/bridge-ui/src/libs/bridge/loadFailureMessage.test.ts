import { RelayerHistoryTruncatedError } from '$libs/error';

import { loadFailureMessageKey } from './loadFailureMessage';

describe('loadFailureMessageKey', () => {
  it('does not blame the relayer for a history that is merely long', () => {
    // Every page asked for came back; the cap is what stopped the walk
    expect(loadFailureMessageKey(new RelayerHistoryTruncatedError('truncated at 10 pages'))).toBe(
      'transactions.errors.history_truncated',
    );
  });

  it('reports a relayer that did not answer as offline', () => {
    expect(loadFailureMessageKey(new Error('fetch failed'))).toBe('transactions.errors.relayer_offline');
  });
});
