import type { Address } from 'viem';

import { chainContractsMap, chains } from '$libs/chain';
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

const log = getLogger('getMaxToBridge');

export async function getMaxToBridge({
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
      srcChainId,
      bridgeAddress,
      processingFee,

      // If no amount passed in, use whatever just to get an estimation
      amount: amount ?? BigInt(1),

      // If no destination chain is selected, find another chain to estimate
      // TODO: we might want to really find a compatible chain to bridge to
      //       if we have multiple layers
      destChainId: destChainId ?? chains.find((chain) => chain.id !== srcChainId)?.id,
    } as ETHBridgeArgs;

    const estimatedCost = await estimateCostOfBridging(bridges.ETH, bridgeArgs);

    log('Estimated cost of bridging', estimatedCost, 'with argument', bridgeArgs);

    return balance - processingFee - estimatedCost;
  }

  // For ERC20 tokens, we can bridge the whole balance
  return balance;
}
