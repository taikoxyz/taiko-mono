import { getPublicClient } from '@wagmi/core';

import { config } from '$libs/wagmi';

import type { Bridge } from './Bridge';
import type { BridgeArgs, ERC20BridgeArgs, ERC721BridgeArgs, ERC1155BridgeArgs } from './types';

export async function estimateCostOfBridging(
  bridge: Bridge,
  bridgeArgs: BridgeArgs | ERC1155BridgeArgs | ERC20BridgeArgs | ERC721BridgeArgs,
) {
  const publicClient = getPublicClient(config);
  if (!publicClient) throw new Error('No public client found');

  // Calculate the estimated cost of bridging
  const estimatedGas = await bridge.estimateGas(bridgeArgs);
  const gasPrice = await publicClient.getGasPrice();
  return estimatedGas * gasPrice;
}
