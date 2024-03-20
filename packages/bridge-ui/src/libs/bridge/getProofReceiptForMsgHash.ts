import { readContract } from '@wagmi/core';
import { get } from 'svelte/store';
import { zeroAddress } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';
import { proofReceiptForMsgHash } from '$stores/proofReceiptForMsgHash';

import type { GetProofReceiptParams, GetProofReceiptResponse } from './types';

const log = getLogger('getProofReceiptForMsgHash');

export const getProofReceiptForMsgHash = async (args: GetProofReceiptParams): Promise<GetProofReceiptResponse> => {
  const { msgHash, destChainId, srcChainId } = args;
  const destBridgeAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].bridgeAddress;

  log('getting proof receipt for msgHash', srcChainId, '->', destChainId, msgHash);

  // Check store first for cached proof receipts
  const proofReceiptCache = get(proofReceiptForMsgHash);

  if (proofReceiptCache && proofReceiptCache[msgHash]) {
    log('proof receipt found in cache', proofReceiptCache[msgHash]);
    return proofReceiptCache[msgHash];
  }

  const response: GetProofReceiptResponse = await readContract(config, {
    abi: bridgeAbi,
    address: destBridgeAddress,
    functionName: 'proofReceipt',
    args: [msgHash],
    chainId: Number(destChainId),
  });

  if (response[1] !== zeroAddress) {
    log('proof receipt found for message hash, caching', msgHash);
    proofReceiptForMsgHash.updateCache(msgHash, response);
  }
  return response;
};
