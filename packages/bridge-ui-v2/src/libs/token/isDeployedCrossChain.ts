import { zeroAddress } from 'viem';

import type { Token } from '$libs/token';

import { getCrossChainInfoForToken } from './getCrossChainInfoForToken';

type IsDeployedCrossChainArgs = {
  token: Token;
  srcChainId: number;
  destChainId: number;
};

export async function isDeployedCrossChain({ token, srcChainId, destChainId }: IsDeployedCrossChainArgs) {
  const destTokenAddressOnDestChain = token.addresses[destChainId];

  if (!destTokenAddressOnDestChain || destTokenAddressOnDestChain === zeroAddress) {
    const crossChainInfo = await getCrossChainInfoForToken({ token, srcChainId, destChainId });
    if (!crossChainInfo) return false;
    const { address } = crossChainInfo;
    // Check if token is already deployed as BridgedERC20 on destination chain
    const bridgedTokenAddress = address;

    return bridgedTokenAddress ? bridgedTokenAddress !== zeroAddress : false;
  }

  return true;
}
