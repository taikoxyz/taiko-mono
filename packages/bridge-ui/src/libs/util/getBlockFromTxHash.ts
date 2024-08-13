import { getTransaction, type GetTransactionReturnType } from '@wagmi/core';
import type { Hash } from 'viem';

import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

const log = getLogger('getBlockFromTxHash');

export const getBlockFromTxHash = async (txHash: Hash, chainId: bigint) => {
  if (!txHash || !chainId) {
    console.error('Missing txHash or chainId', txHash, chainId);
    throw new Error('Missing txHash or chainId');
  }

  log('Getting block from tx hash', txHash, chainId);
  const transactionData: GetTransactionReturnType = await getTransaction(config, {
    hash: txHash,
    chainId: Number(chainId),
  });
  log('Transaction data', transactionData);
  const { blockNumber } = transactionData;
  return blockNumber;
};
