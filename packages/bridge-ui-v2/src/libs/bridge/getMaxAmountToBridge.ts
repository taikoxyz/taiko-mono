import type { Address } from 'viem';

import { chainContractsMap } from '$libs/chain';
import { type Token, TokenType } from '$libs/token';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';

import { bridges } from './bridges';
import { estimateCostOfBridging } from './estimateCostOfBridging';
import type { ETHBridgeArgs } from './types';

type GetMaxToBridgeArgs = {
  to: Address;
  token: Token;
  balance: bigint;
  amount?: bigint;
  srcChainId?: number;
  destChainId?: number;
  processingFee?: bigint;
};

const log = getLogger('bridge:getMaxAmountToBridge');

export async function getMaxAmountToBridge({
  to,
  token,
  amount,
  balance,
  srcChainId,
  destChainId,
  processingFee,
}: GetMaxToBridgeArgs) {
  // For ERC20 tokens, we can bridge the whole balance
  let maxAmount = balance;

  if (token.type === TokenType.ETH) {
    // We cannot really compute the cost of bridging ETH without
    if (!to || !srcChainId || !destChainId) {
      throw Error('missing required arguments to compute cost');
    }

    const wallet = await getConnectedWallet();
    const { bridgeAddress } = chainContractsMap[srcChainId];

    const bridgeArgs = {
      to,
      amount,
      wallet,
      srcChainId,
      destChainId,
      bridgeAddress,
      processingFee,
    } as ETHBridgeArgs;

    const estimatedCost = await estimateCostOfBridging(bridges.ETH, bridgeArgs);

    log('Estimated cost of bridging', estimatedCost, 'with argument', bridgeArgs);

    // We also need to take into account the processing fee if any
    maxAmount = balance - estimatedCost - (processingFee ?? BigInt(0));
  }

  return maxAmount;
}
