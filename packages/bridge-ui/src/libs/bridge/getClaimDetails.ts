import { getPublicClient } from '@wagmi/core';
import type { Address, Hash } from 'viem';

import { ClientError } from '$libs/error';
import { config } from '$libs/wagmi';

export type ClaimDetails = {
  claimedBy: Address;
  claimedAt: bigint;
};

/**
 * @dev Who claimed a message and when, read from the claim transaction itself.
 *
 *      The relayer API reports a claimer only for messages the relayer did not claim: its own
 *      claim leaves a status row with nothing but the transaction hash, and the API gives up
 *      on that row. The claim transaction on the destination chain carries both answers - its
 *      sender is the claimer and its block's timestamp the claim time - so they are read from
 *      there, on demand, once the hash is known. A claim routed through a smart account or a
 *      batcher names that contract as its sender, which is the closest answer available.
 *
 * @param destTxHash The claim transaction
 * @param destChainId The chain it was mined on
 * @return details_ The claimer and the claim time
 */
export async function getClaimDetails(destTxHash: Hash, destChainId: bigint): Promise<ClaimDetails> {
  const client = getPublicClient(config, { chainId: Number(destChainId) });
  if (!client) throw new ClientError('Client not found');

  const transaction = await client.getTransaction({ hash: destTxHash });
  // A claimed message has a mined claim; anything else here is the wrong hash
  if (transaction.blockNumber === null) throw new Error(`claim transaction ${destTxHash} is not mined`);

  const block = await client.getBlock({ blockNumber: transaction.blockNumber });
  return { claimedBy: transaction.from, claimedAt: block.timestamp };
}
