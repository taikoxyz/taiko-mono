import { getGasPrice } from '@wagmi/core';
import { parseGwei } from 'viem';

import getConfig from '$lib/wagmi/getConfig';

export default async function calculateGasPrice(): Promise<bigint> {
  const config = getConfig();
  const currentGasPrice = parseInt((await getGasPrice(config)).toString());
  const minGasPrice = parseInt(parseGwei('0.01').toString());
  const out = Math.max(currentGasPrice, minGasPrice);

  return BigInt(out);
}
