import { RelayerHistoryTruncatedError } from '$libs/error';

/**
 * @dev Picks the message for a transaction load that did not complete cleanly.
 *
 *      Hitting the page cap is not a failure: every page asked for came back, the history is
 *      simply longer than the cap allows. Both consumers used to render any error from
 *      fetchTransactions with the offline string, so an address with a long history warned
 *      that the relayer had not responded on every single load - and a real outage became
 *      indistinguishable from routine truncation.
 *
 * @param error What the fetch reported
 * @return key_ The i18n key describing it
 */
export const loadFailureMessageKey = (error: unknown): string =>
  error instanceof RelayerHistoryTruncatedError
    ? 'transactions.errors.history_truncated'
    : 'transactions.errors.relayer_offline';
