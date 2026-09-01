export type LoadWarning = {
  key: string;
  values?: Record<string, number>;
};

/**
 * Decides which warning, if any, the transactions page should raise after a fetch. Returns null
 * when the history loaded cleanly.
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
  const relayerFailed = Boolean(result.error);
  const someFailedToLoad = result.failedCount > 0;
  const values = { count: result.failedCount };

  if (relayerFailed && someFailedToLoad) {
    return { key: 'transactions.errors.relayer_offline_and_partial_load', values };
  }
  if (relayerFailed) return { key: 'transactions.errors.relayer_offline' };
  if (someFailedToLoad) return { key: 'transactions.errors.partial_load', values };
  return null;
}
