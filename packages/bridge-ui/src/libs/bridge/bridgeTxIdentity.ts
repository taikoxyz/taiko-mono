import type { BridgeTransaction } from './types';

type Identifiable = Pick<BridgeTransaction, 'msgHash' | 'srcTxHash'>;

/**
 * @dev The identity of a bridged message.
 *
 *      A message hash is what actually identifies one: a single transaction can emit more
 *      than one MessageSent - a batching wallet, or a contract that bridges twice - and
 *      each is claimed separately. Keying off the transaction hash collapsed those into
 *      one entry, which dropped a claimable message from the list and gave the keyed
 *      `{#each}` two rows with the same key.
 *
 *      `srcTxHash` remains the fallback for a locally recorded transaction whose message
 *      hash has not been read off the receipt yet.
 *
 * @param tx The transaction to identify
 * @return key_ The message hash if known, the source transaction hash otherwise
 */
export const bridgeTxKey = (tx: Identifiable) => tx.msgHash ?? tx.srcTxHash;

/**
 * @dev Whether two records describe the same bridged message.
 *
 *      Two known message hashes settle it outright. Only when one side has none does this
 *      fall back to the transaction hash, which is the best a record that has not been
 *      enhanced yet can offer.
 *
 * @param a One transaction
 * @param b The other transaction
 * @return same_ Whether both describe the same message
 */
export const isSameBridgeTx = (a: Identifiable, b: Identifiable) => {
  if (a.msgHash && b.msgHash) return a.msgHash === b.msgHash;
  return a.srcTxHash === b.srcTxHash;
};
