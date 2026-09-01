export type LoadWarning = {
  key: string;
  values?: Record<string, number>;
};

/**
 * @dev Decides which warning, if any, the transactions page should raise after a fetch.
 *      Extracted from Transactions.svelte so the decision is testable without mounting the
 *      component and its 30 dependencies.
 * @param result The relevant part of a fetchTransactions result
 * @return warning_ The warning to show, or null when the history loaded cleanly
 */
export function getLoadWarning(result: { error?: Error; failedCount: number }): LoadWarning | null {
  if (result.error) return { key: 'transactions.errors.relayer_offline' };
  if (result.failedCount > 0) {
    return { key: 'transactions.errors.partial_load', values: { count: result.failedCount } };
  }
  return null;
}
