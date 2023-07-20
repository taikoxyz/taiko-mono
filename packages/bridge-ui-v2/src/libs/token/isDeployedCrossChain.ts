import { zeroAddress } from 'viem';

import type { Token } from '$libs/token';

import { getCrossChainAddress } from './getCrossChainAddress';

export async function isDeployedCrossChain(token: Token, destChainId: number, srcChainId: number) {
  const destTokenAddressOnDestChain = token.addresses[destChainId];

  if (!destTokenAddressOnDestChain || destTokenAddressOnDestChain === zeroAddress) {
    // Check if token is already deployed as BridgedERC20 on destination chain
    const bridgedTokenAddress = await getCrossChainAddress(token, srcChainId, destChainId);

    return bridgedTokenAddress && bridgedTokenAddress !== zeroAddress;
  }

  return true;
}
