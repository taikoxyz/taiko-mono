import type { Address, Hash } from 'viem';

import { getLogger } from '$libs/util/logger';

import { relayerApiServices } from './initRelayers';

const log = getLogger('relayer:findClaimTxHash');

/**
 * @dev The claim transaction of a claimed message, asked of every configured relayer in turn.
 *
 *      Each relayer files its status rows under the message's sender, so the lookup is made
 *      with that address rather than with the account whose history is on screen: a transfer
 *      someone else sent to this account has its rows under the sender's name.
 *
 * @param srcOwner The message's sender
 * @param msgHash The message
 * @return claimTxHash_ The first answer, or undefined when no relayer has one
 */
export async function findClaimTxHash(srcOwner: Address, msgHash: Hash): Promise<Hash | undefined> {
  for (const relayer of relayerApiServices) {
    try {
      const claimTxHash = await relayer.getClaimTxHash(srcOwner, msgHash);
      if (claimTxHash) return claimTxHash;
    } catch (error) {
      // The next relayer may still know; the dialog shows "-" if none does
      log('Could not read the claim transaction from a relayer', error);
    }
  }
  return undefined;
}
