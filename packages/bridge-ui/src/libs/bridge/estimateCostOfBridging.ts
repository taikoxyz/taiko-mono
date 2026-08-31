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

  // Calculate the estimated cost of bridging. Reserve using the EIP-1559 max fee the wallet
  // will actually lock up, not the legacy gas price, which under-reserves and can make a
  // MAX-amount transaction fail with insufficient funds
  const estimatedGas = await bridge.estimateGas(bridgeArgs);
  const { maxFeePerGas } = await publicClient.estimateFeesPerGas();
  const feePerGas = maxFeePerGas ?? (await publicClient.getGasPrice());
  return estimatedGas * feePerGas;
}
