import type { Hex } from 'viem';

import { chainConfig } from '$chainConfig';
import { errorToast, successToast, warningToast } from '$components/NotificationToast';
import { infoToast } from '$components/NotificationToast/NotificationToast.svelte';

import { awaitDialogTransaction, type DialogTransactionOutcome } from './awaitDialogTransaction';

/**
 * The shape of svelte-i18n's `$t`. Declared here rather than imported because the package
 * does not export MessageFormatter; the value shape is what matters, and a mismatch would
 * fail at the call site in the dialogs.
 */
type Translate = (id: string, options?: { values?: Record<string, string> }) => string;

type DialogTransactionArgs = {
  txHash: Hex;
  /**
   * The chain the transaction was sent on. Not always the destination: a release recalls
   * the message on the source chain, so its explorer link and its receipt live there.
   */
  chainId: number;
  t: Translate;
  /** i18n key for the title of the toast shown when the transaction reverts */
  failureTitleKey: string;
};

/**
 * @dev Runs the part of a dialog's transaction that claim, retry and release all share:
 *      announce it, wait for it, and report how it settled.
 *
 *      All three showed the same "transaction sent" toast, waited the same way, and had to
 *      tell a revert from a receipt wait that merely timed out - and each had its own copy,
 *      which is how the retry dialog ended up announcing a *completed* retry with the
 *      "track the progress" message.
 *
 *      The dialog's own state stays with the dialog: only it knows which flags to lower,
 *      and on a timeout it must lower none of them, because the transaction is still live.
 *
 * @param args The transaction, its chain, the translator and the failure title
 * @return outcome_ Whether the transaction confirmed, timed out, or failed
 */
export const reportDialogTransaction = async ({
  txHash,
  chainId,
  t,
  failureTitleKey,
}: DialogTransactionArgs): Promise<DialogTransactionOutcome> => {
  const explorer = chainConfig[chainId]?.blockExplorers?.default.url;
  const url = `${explorer}/tx/${txHash}`;

  infoToast({
    title: t('transactions.actions.claim.tx.title'),
    message: t('transactions.actions.claim.tx.message', { values: { url } }),
  });

  const outcome = await awaitDialogTransaction(txHash, chainId);

  if (outcome === 'timed_out') {
    // Only the wait gave up. The transaction is still live and may yet do what the user
    // asked, so this is a warning about the wait rather than a report of a failure
    warningToast({
      title: t('bridge.actions.bridge.timeout.title'),
      message: t('bridge.actions.bridge.timeout.message', { values: { url } }),
    });
    return outcome;
  }

  if (outcome === 'failed') {
    errorToast({ title: t(failureTitleKey) });
    return outcome;
  }

  successToast({
    title: t('transactions.actions.claim.success.title'),
    message: t('transactions.actions.claim.success.message', { values: { url } }),
  });
  return outcome;
};
