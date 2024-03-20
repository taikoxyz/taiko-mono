import { readContract } from '@wagmi/core';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

// returns [bigint, bigint] e.g. [300,384]
// First is preferred claimer, second the fallback

//TODO: cache this
const log = getLogger('getInvocationDelaysForDestBridge');
export const getInvocationDelaysForDestBridge = async ({
  srcChainId,
  destChainId,
}: {
  srcChainId: bigint;
  destChainId: bigint;
}) => {
  log('getting invocation delays for dest bridge', srcChainId, '->', destChainId);
  const destBridgeAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].bridgeAddress;
  const delay = await readContract(config, {
    abi: bridgeAbi,
    address: destBridgeAddress,
    functionName: 'getInvocationDelays',
    chainId: Number(destChainId),
  });
  log('invocation delay', delay);
  return delay;
};
