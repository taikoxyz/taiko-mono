import type { Hash } from 'viem';

import { chains } from '$libs/chain';

export async function fetchTransactionReceipt(transactionHash: Hash, chainId: number) {
  try {
    const nodeUrl = chains.find((c) => c.id === chainId)?.rpcUrls?.default?.http[0];
    if (!nodeUrl) {
      throw new Error('Node URL not found');
    }

    const response = await fetch(nodeUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'eth_getTransactionReceipt',
        params: [transactionHash],
        id: 1,
      }),
    });

    const data = await response.json();
    return data.result;
  } catch (error) {
    console.error('Error fetching transaction receipt:', error);
    throw error;
  }
}
