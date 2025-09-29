import { getGasPrice } from '@wagmi/core';
import { parseGwei } from 'viem';

import getConfig from '$lib/wagmi/getConfig';

export default async function calculateGasPrice(): Promise<bigint> {
  const config = getConfig();
  const currentGasPrice = await getGasPrice(config);
  const minGasPrice = parseGwei('0.01');
  
  // Use BigInt comparison instead of parseInt to avoid precision loss
  return currentGasPrice > minGasPrice ? currentGasPrice : minGasPrice;
}
