import { getContract } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { tokenVaultABI } from '$abi';
import { chainContractsMap } from '$libs/chain';
import type { Token } from '$libs/token';
import { getLogger } from '$libs/util/logger';

type IsTokenDeployedCrossChainArgs = {
  token: Token;
  destChainId: number;
  srcChainId: number;
};

const log = getLogger('token:isDeployedCrossChain');

export async function isDeployedCrossChain({ token, destChainId, srcChainId }: IsTokenDeployedCrossChainArgs) {
  const destTokenAddressOnDestChain = token.addresses[destChainId];

  if (destTokenAddressOnDestChain === zeroAddress) {
    const { tokenVaultAddress } = chainContractsMap[destChainId];

    const destTokenVaultContract = getContract({
      abi: tokenVaultABI,
      chainId: destChainId,
      address: tokenVaultAddress,
    });

    // Check if token is already deployed as BridgedERC20 on destination chain
    const srcTokenAddressOnSourceChain = token.addresses[srcChainId];

    log(`Checking if token ${token.symbol} is deployed as BridgedERC20 on destination chain ${destChainId}`);

    try {
      const bridgedTokenAddress = await destTokenVaultContract.read.canonicalToBridged([
        BigInt(srcChainId),
        srcTokenAddressOnSourceChain,
      ]);

      log(`Address of bridged token "${bridgedTokenAddress}"`);

      return bridgedTokenAddress !== zeroAddress;
    } catch (err) {
      console.error(err);
      return false;
    }
  }

  return true;
}
