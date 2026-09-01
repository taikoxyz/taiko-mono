import type { Address } from 'viem';

import type { BridgeTransaction } from '$libs/bridge/types';

import { bridgeTxService } from './index';

/**
 * @dev Records a bridge transaction in the local history without letting a storage
 *      failure decide how the bridge itself is reported.
 *
 *      addTxByAddress writes to localStorage, which throws on a full quota and in
 *      browsers that refuse storage outright. That write used to sit inside the try
 *      block that tells a reverted transaction from a receipt wait that gave up, so a
 *      quota error arrived at the catch indistinguishable from a revert: the user was
 *      told their bridge had failed, for a transaction that had confirmed on chain, and
 *      it was left out of the history the write existed to add it to.
 *
 *      The relayer indexes the message either way, so the local copy is a convenience
 *      and its loss is worth a log rather than an error the user has to act on.
 *
 * @param owner The account the transaction belongs to
 * @param tx The transaction to record
 * @return recorded_ Whether the transaction reached storage
 */
export function recordBridgeTx(owner: Address, tx: BridgeTransaction): boolean {
  try {
    bridgeTxService.addTxByAddress(owner, tx);
    return true;
  } catch (error) {
    console.error('Could not record the bridge transaction in the local history', { error, tx });
    return false;
  }
}
