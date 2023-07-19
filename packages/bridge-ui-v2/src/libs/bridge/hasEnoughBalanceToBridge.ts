import { getPublicClient, getWalletClient } from '@wagmi/core';

import { ETHBridge } from './ETHBridge';
import type { Bridge, BridgeArgs } from './types';

export async function hasEnoughBalanceToBridge(bridge: Bridge, bridgeArgs: BridgeArgs) {
  const walletClient = await getWalletClient();
  if (!walletClient) {
    throw Error('wallet is not connected');
  }

  const userAddress = walletClient.account.address;
  const publicClient = getPublicClient();

  // Calculate the estimated cost of bridging
  const estimatedGas = await bridge.estimateGas(bridgeArgs);
  const gasPrice = await publicClient.getGasPrice();
  const estimatedCost = estimatedGas * gasPrice;

  const userBalance = await publicClient.getBalance({ address: userAddress });

  let balanceAvailable = userBalance;

  if (bridge instanceof ETHBridge) {
    // If it's ETH, we need to subtract the amount we're trying to bridge
    balanceAvailable = userBalance - bridgeArgs.amount;
  }

  return balanceAvailable > estimatedCost;
}
