export type LoadWarning = {
  key: string;
  values?: Record<string, number>;
};

/**
 * Decides which warning, if any, the transactions page should raise after a fetch. Returns null
 * when the history loaded cleanly. A dead relayer takes precedence over a per-transaction count:
 * it already explains the missing rows, so a second toast would only be noise.
 *
 * Lives outside Transactions.svelte so the decision is testable without mounting that component
 * and its 30 dependencies.
 */
export function getLoadWarning(result: { error?: Error; failedCount: number }): LoadWarning | null {
  if (result.error) return { key: 'transactions.errors.relayer_offline' };
  if (result.failedCount > 0) {
    return { key: 'transactions.errors.partial_load', values: { count: result.failedCount } };
  }
  return null;
}
