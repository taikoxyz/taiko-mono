import { getPublicClient } from '@wagmi/core';

import { ClientError } from '$libs/error';
import { config } from '$libs/wagmi';

export const geBlockTimestamp = async (srcChainId: bigint, blockNumber: bigint) => {
  const client = getPublicClient(config, { chainId: Number(srcChainId) });
  if (!client) throw new ClientError('Client not found');
  const block = await client.getBlock({
    blockNumber,
  });
  return block.timestamp;
};
