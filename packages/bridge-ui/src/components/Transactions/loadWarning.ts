export type LoadWarning = {
  key: string;
  values?: Record<string, number>;
};

/**
 * Decides which warning, if any, the transactions page should raise after a fetch. Returns null
 * when the history loaded cleanly.
 *
 * A truncated history is reported on its own: the relayer is healthy, so it must not borrow the
 * relayer's wording, and it is the weakest of the three signals - a per-message loss is the more
 * actionable thing to say when both apply.
 *
 * The two failures are independent and routinely coincide: one relayer can die while another
 * answers and loses transactions to failed on-chain reads. Reporting only the relayer would hide
 * a count the user has no other way to learn, so that case gets its own combined message rather
 * than a second toast stacked on the first.
 *
 * Lives outside Transactions.svelte so the decision is testable without mounting that component
 * and its 30 dependencies.
 */
export function getLoadWarning(result: { error?: Error; failedCount: number }): LoadWarning | null {
  // A history cut off at the page backstop is not a relayer failure - the relayer answered every
  // page it was asked for. Saying "did not respond" there would be the same misattribution this
  // whole change exists to remove, aimed at a different cause.
  const historyTruncated = result.error?.name === 'RelayerHistoryTruncatedError';
  const relayerFailed = Boolean(result.error) && !historyTruncated;
  const someFailedToLoad = result.failedCount > 0;
  const values = { count: result.failedCount };

  if (relayerFailed && someFailedToLoad) {
    return { key: 'transactions.errors.relayer_offline_and_partial_load', values };
  }
  if (relayerFailed) return { key: 'transactions.errors.relayer_offline' };
  if (someFailedToLoad) return { key: 'transactions.errors.partial_load', values };
  if (historyTruncated) return { key: 'transactions.errors.history_truncated' };
  return null;
}
