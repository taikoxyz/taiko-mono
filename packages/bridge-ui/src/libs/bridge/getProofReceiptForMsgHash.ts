import { readContract } from '@wagmi/core';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { config } from '$libs/wagmi';

import type { GetProofReceiptParams, GetProofReceiptResponse } from './types';

export const getProofReceiptForMsgHash = async (args: GetProofReceiptParams): Promise<GetProofReceiptResponse> => {
  const { msgHash, destChainId, srcChainId } = args;
  const destBridgeAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].bridgeAddress;

  const response: GetProofReceiptResponse = await readContract(config, {
    abi: bridgeAbi,
    address: destBridgeAddress,
    functionName: 'proofReceipt',
    args: [msgHash],
    chainId: Number(destChainId),
  });
  return response;
};
