import { routingContractsMap } from '$bridgeConfig';
import { TokenType } from '$libs/token';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';

import { bridges } from './bridges';
import { estimateCostOfBridging } from './estimateCostOfBridging';
import type { ETHBridgeArgs, GetMaxToBridgeArgs } from './types';

const log = getLogger('bridge:getMaxAmountToBridge');

export async function getMaxAmountToBridge({ to, token, balance, fee, srcChainId, destChainId }: GetMaxToBridgeArgs) {
  // For ERC20 tokens, we can bridge the whole balance
  let maxAmount = balance;
  log('Max amount to bridge', maxAmount, 'with balance', balance, 'for token', token);
  if (token.type === TokenType.ETH) {
    // We cannot really compute the cost of bridging ETH without
    if (!to || !srcChainId || !destChainId) {
      throw Error('missing required arguments to compute cost');
    }

    const wallet = await getConnectedWallet();
    const { bridgeAddress } = routingContractsMap[srcChainId][destChainId];

    // We need to estimate the cost of bridging
    const bridgeArgs = {
      to,
      amount: 1n, // any amount will do
      wallet,
      srcChainId,
      destChainId,
      bridgeAddress,
      fee,
    } as ETHBridgeArgs;

    const estimatedCost = await estimateCostOfBridging(bridges.ETH, bridgeArgs);

    log('Estimated cost of bridging', estimatedCost, 'with argument', bridgeArgs);

    // We also need to take into account the processing fee if any
    maxAmount = balance - estimatedCost - (fee ?? BigInt(0));
  }
  return maxAmount;
}
