import { getPublicClient } from '@wagmi/core';
import { getContract, type Hash } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { ClientError } from '$libs/error';
import { config } from '$libs/wagmi';

import type { MessageStatus } from '.';

export const getMessageStatusForMsgHash = async ({
  msgHash,
  srcChainId,
  destChainId,
}: {
  msgHash: Hash;
  srcChainId: number;
  destChainId: number;
}): Promise<MessageStatus> => {
  // Gets the status of the message from the destination bridge contract
  const bridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;
  const client = getPublicClient(config, { chainId: destChainId });

  if (!client) throw new ClientError('Could not get public client');
  const bridgeContract = getContract({
    client,
    abi: bridgeAbi,
    address: bridgeAddress,
  });

  return bridgeContract.read.messageStatus([msgHash]) as Promise<MessageStatus>;
};
