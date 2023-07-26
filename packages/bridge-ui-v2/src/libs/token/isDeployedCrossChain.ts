import { zeroAddress } from 'viem';

import type { Token } from '$libs/token';

import { getCrossChainAddress } from './getCrossChainAddress';

type IsDeployedCrossChainArgs = {
  token: Token;
  srcChainId: number;
  destChainId: number;
};

export async function isDeployedCrossChain({ token, srcChainId, destChainId }: IsDeployedCrossChainArgs) {
  const destTokenAddressOnDestChain = token.addresses[destChainId];

  if (!destTokenAddressOnDestChain || destTokenAddressOnDestChain === zeroAddress) {
    // Check if token is already deployed as BridgedERC20 on destination chain
    const bridgedTokenAddress = await getCrossChainAddress({ token, srcChainId, destChainId });

    return bridgedTokenAddress ? bridgedTokenAddress !== zeroAddress : false;
  }

  return true;
}
