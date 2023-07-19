import { getPublicClient } from '@wagmi/core';

import { getConnectedWallet } from '$libs/util/getWallet';

import { estimateCostOfBridging } from './estimateCostOfBridging';
import { ETHBridge } from './ETHBridge';
import type { Bridge, BridgeArgs } from './types';

export async function hasEnoughBalanceToBridge(bridge: Bridge, bridgeArgs: BridgeArgs) {
  const walletClient = await getConnectedWallet();

  const estimatedCost = await estimateCostOfBridging(bridge, bridgeArgs);

  const publicClient = getPublicClient();
  const userAddress = walletClient.account.address;
  const userBalance = await publicClient.getBalance({ address: userAddress });

  let balanceAvailable = userBalance;

  if (bridge instanceof ETHBridge) {
    // If dealing with ETH, we need to subtract the amount we're trying to bridge
    balanceAvailable = userBalance - bridgeArgs.amount;
  }

  return balanceAvailable > estimatedCost;
}
