import { getPublicClient } from '@wagmi/core';

import type { Bridge } from './Bridge';
import type { BridgeArgs } from './types';

export async function estimateCostOfBridging(bridge: Bridge, bridgeArgs: BridgeArgs) {
  const publicClient = getPublicClient();

  // Calculate the estimated cost of bridging
  const estimatedGas = await bridge.estimateGas(bridgeArgs);
  const gasPrice = await publicClient.getGasPrice();
  return estimatedGas * gasPrice;
}
