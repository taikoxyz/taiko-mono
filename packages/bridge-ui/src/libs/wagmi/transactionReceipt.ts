import { getTransactionReceipt, waitForTransactionReceipt } from '@wagmi/core';
import type { Hash, TransactionReceipt } from 'viem';

import { config } from './client';

export async function getTransactionReceiptOrNull({
  chainId,
  hash,
  onError,
}: {
  chainId: number;
  hash: Hash;
  onError?: (error: unknown) => void;
}): Promise<TransactionReceipt | null> {
  try {
    return await getTransactionReceipt(config, { chainId, hash });
  } catch (error) {
    onError?.(error);
    return null;
  }
}

export async function waitForTransactionReceiptOrNull({
  chainId,
  hash,
  timeout,
  onError,
}: {
  chainId: number;
  hash: Hash;
  timeout: number;
  onError?: (error: unknown) => void;
}): Promise<TransactionReceipt | null> {
  try {
    return await waitForTransactionReceipt(config, {
      hash,
      chainId: Number(chainId),
      timeout,
    });
  } catch (error) {
    onError?.(error);
    return null;
  }
}
