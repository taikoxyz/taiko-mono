import { type Address, getPublicClient } from '@wagmi/core';

import { estimateCostOfBridging } from './estimateCostOfBridging';
import { ETHBridge } from './ETHBridge';
import type { Bridge, BridgeArgs } from './types';

export async function hasEnoughBalanceToBridge(bridge: Bridge, bridgeArgs: BridgeArgs, address: Address) {
  const estimatedCost = await estimateCostOfBridging(bridge, bridgeArgs);

  const publicClient = getPublicClient();
  const userBalance = await publicClient.getBalance({ address });

  let balanceAvailable = userBalance;

  if (bridge instanceof ETHBridge) {
    // If dealing with ETH, we need to subtract the amount we're trying to bridge
    balanceAvailable = userBalance - bridgeArgs.amount;
  }

  return balanceAvailable > estimatedCost;
}
