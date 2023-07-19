import { getContract } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { tokenVaultABI } from '$abi';
import { chainContractsMap } from '$libs/chain';
import type { Token } from '$libs/token';
import { getLogger } from '$libs/util/logger';

type IsTokenDeployedCrossChainArgs = {
  token: Token;
  srcChainId: number;
  destChainId: number;
};

const log = getLogger('bridge:isTokenDeployedCrossChain');

export async function isTokenDeployedCrossChain({ token, srcChainId, destChainId }: IsTokenDeployedCrossChainArgs) {
  const { tokenVaultAddress } = chainContractsMap[destChainId.toString()];

  const destTokenVaultContract = getContract({
    chainId: destChainId,
    abi: tokenVaultABI,
    address: tokenVaultAddress,
  });

  const destTokenAddressOnDestChain = token.addresses[destChainId];

  if (destTokenAddressOnDestChain === zeroAddress) {
    // Check if token is already deployed as BridgedERC20 on destination chain
    const srcTokenAddressOnSourceChain = token.addresses[srcChainId];

    log('Checking if token', token, 'is deployed as BridgedERC20 on destination chain', destChainId);

    const bridgedTokenAddress = await destTokenVaultContract.read.canonicalToBridged([
      BigInt(srcChainId),
      srcTokenAddressOnSourceChain,
    ]);

    log(`Address of bridged token "${bridgedTokenAddress}"`);

    if (bridgedTokenAddress !== zeroAddress) {
      return true;
    }
  }

  return false;
}
