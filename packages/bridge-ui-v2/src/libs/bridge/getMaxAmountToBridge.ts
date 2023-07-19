import type { Address } from 'viem';

import { chainContractsMap } from '$libs/chain';
import { isETH, type Token } from '$libs/token';
import { getLogger } from '$libs/util/logger';

import { bridges } from './bridges';
import { estimateCostOfBridging } from './estimateCostOfBridging';
import type { ETHBridgeArgs } from './types';

type GetMaxToBridgeArgs = {
  token: Token;
  balance: bigint;
  srcChainId: number;
  userAddress: Address;
  processingFee: bigint;
  destChainId?: number;
  amount?: bigint;
};

const log = getLogger('bridge:getMaxAmountToBridge');

export async function getMaxAmountToBridge({
  token,
  balance,
  srcChainId,
  userAddress,
  processingFee,
  destChainId,
  amount,
}: GetMaxToBridgeArgs) {
  if (isETH(token)) {
    const to = userAddress;
    const { bridgeAddress } = chainContractsMap[srcChainId.toString()];

    const bridgeArgs = {
      to,
      amount,
      srcChainId,
      destChainId,
      bridgeAddress,
      processingFee,
    } as ETHBridgeArgs;

    const estimatedCost = await estimateCostOfBridging(bridges.ETH, bridgeArgs);

    log('Estimated cost of bridging', estimatedCost, 'with argument', bridgeArgs);

    return balance - processingFee - estimatedCost;
  }

  // For ERC20 tokens, we can bridge the whole balance
  return balance;
}
