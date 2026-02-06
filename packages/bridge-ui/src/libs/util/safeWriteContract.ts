import { writeContract, type WriteContractParameters } from '@wagmi/core';

import { config } from '$libs/wagmi';

// Wallets are better positioned to set current fee fields at signing time.
// We remove simulated fee fields to avoid submitting stale underpriced txs.
const feeKeys = ['maxFeePerGas', 'maxPriorityFeePerGas', 'gasPrice', 'type'] as const;

export async function safeWriteContract(params: WriteContractParameters) {
  const next = { ...params } as Record<string, unknown>;
  for (const key of feeKeys) {
    if (key in next) delete next[key];
  }

  return await writeContract(config, next as unknown as WriteContractParameters);
}
