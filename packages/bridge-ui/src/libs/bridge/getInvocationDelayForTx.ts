import type { BridgeTransaction } from '$libs/bridge/types';
import { NoDelaysForBridgeError } from '$libs/error';
import { getLatestBlockTimestamp } from '$libs/util/getLatestBlockTimestamp';
import { getLogger } from '$libs/util/logger';

import { getInvocationDelaysForDestBridge } from './getInvocationDelaysForDestBridge';
import { getProofReceiptForMsgHash } from './getProofReceiptForMsgHash';

const log = getLogger('bridge:getInvocationDelayForTx');

export const getInvocationDelayForTx = async (tx: BridgeTransaction) => {
  log('getInvocationDelayForTx', tx);

  const invocationDelays = await getInvocationDelaysForDestBridge({
    srcChainId: tx.srcChainId,
    destChainId: tx.destChainId,
  });

  if (invocationDelays[0] === 0n) {
    throw new NoDelaysForBridgeError('Destination chain does not have delays');
  }

  const proofReciept = await getProofReceiptForMsgHash({
    msgHash: tx.msgHash,
    destChainId: tx.destChainId,
    srcChainId: tx.srcChainId,
  });

  if (proofReciept[0] === 0n) {
    // No proof receipt found, no delay (yet)
    return {
      preferredDelay: 0n,
      notPreferredDelay: 0n,
    };
  }

  const delayForPreferred = invocationDelays[0];
  const delayForNotPreferred = invocationDelays[1];

  log('invocationDelays', invocationDelays);

  const latestBlockTimestamp = await getLatestBlockTimestamp(tx.destChainId);
  log('latestBlockTimestamp', latestBlockTimestamp);

  const provenAt = proofReciept[0];
  // const provenBy = proofReciept[1];

  log('time since last claim', latestBlockTimestamp - provenAt);
  const delays = {
    preferredDelay: delayForPreferred - (latestBlockTimestamp - provenAt),
    notPreferredDelay: delayForNotPreferred - (latestBlockTimestamp - provenAt),
  };
  log('remaining delays', delays);
  return delays;
};
