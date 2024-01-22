import { getContract } from '@wagmi/core';
import { type Abi, type Address, zeroAddress } from 'viem';

import { erc20VaultABI, erc721VaultABI, erc1155VaultABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { NoCanonicalInfoFoundError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { getCanonicalStatusFromStore, setCanonicalTokenInfoStore } from '$stores/canonical';

import { detectContractType } from './detectContractType';
import { type GetTokenInfo, TokenType } from './types';

const log = getLogger('token:getCanonicalInfoForToken');

type CheckCanonicalStatusArgs = {
  address: Address;
  srcChainId: number;
  destChainId: number;
  type: TokenType;
};

type CanonicalInfo = {
  chainId: number;
  address: Address;
};

const _getStatus = async ({ address, srcChainId, destChainId, type }: CheckCanonicalStatusArgs) => {
  const srcChainTokenAddress = address;

  const vaultABI =
    type === TokenType.ERC721 ? erc721VaultABI : type === TokenType.ERC1155 ? erc1155VaultABI : erc20VaultABI;

  const vaultAddressKey =
    type === TokenType.ERC721
      ? 'erc721VaultAddress'
      : type === TokenType.ERC1155
        ? 'erc1155VaultAddress'
        : 'erc20VaultAddress';

  const srcTokenVaultContract = getContract({
    abi: vaultABI as Abi,
    chainId: srcChainId,
    address: routingContractsMap[srcChainId][destChainId][vaultAddressKey],
  });

  const destTokenVaultContract = getContract({
    abi: vaultABI as Abi,
    chainId: destChainId,
    address: routingContractsMap[destChainId][srcChainId][vaultAddressKey],
  });

  let canonicalTokenAddress: Address;
  let canonicalChain: number;

  log('checking', srcChainTokenAddress, srcChainId, destChainId);

  const srcCanonicalTokenInfo = (await srcTokenVaultContract.read.bridgedToCanonical([
    srcChainTokenAddress,
  ])) as Address;
  const srcCanonicalCheck = srcCanonicalTokenInfo[1] as Address;

  const destCanonicalTokenInfo = (await destTokenVaultContract.read.bridgedToCanonical([
    srcChainTokenAddress,
  ])) as Address;

  const destCanonicalCheck = destCanonicalTokenInfo[1] as Address;

  if (srcCanonicalCheck === zeroAddress && destCanonicalCheck === zeroAddress) {
    // if both are zero we are dealing with a canonical address
    canonicalTokenAddress = srcChainTokenAddress;
    canonicalChain = srcChainId;
  } else if (destCanonicalCheck !== zeroAddress) {
    // if the destination is not zero, we found a canonical address there
    canonicalTokenAddress = destCanonicalCheck;
    canonicalChain = srcChainId;
  } else {
    // if the source is not zero, we found a canonical address there
    canonicalTokenAddress = srcCanonicalCheck;
    canonicalChain = destChainId;
  }
  return { canonicalTokenAddress, canonicalChain };
};

export async function getCanonicalInfoForToken({
  token,
  srcChainId,
  destChainId,
}: GetTokenInfo): Promise<CanonicalInfo | null> {
  if (token.type === TokenType.ETH) return null; // ETH doesn't have an address
  log(
    `Find canonicalInfo for ${token.type} token ${token.symbol} (${token.name}) from chain ${srcChainId} to chain ${destChainId}`,
    token,
  );

  if (token.addresses[srcChainId] && token.addresses[destChainId]) {
    // we already have addresses for both, lets find the canonical one
    log('addresses for both, fetching canonical one');
    for (const [currentSrcChainId, address] of Object.entries(token.addresses)) {
      if (parseInt(currentSrcChainId) === destChainId) continue;

      // check store first
      if (getCanonicalStatusFromStore(address)) {
        log('found canonical address in store', address);
        return { chainId: srcChainId, address };
      }
      log('fetching new canonical info');

      const { canonicalTokenAddress, canonicalChain } = await _getStatus({
        address,
        srcChainId: parseInt(currentSrcChainId),
        destChainId,
        type: token.type,
      });
      if (canonicalTokenAddress && canonicalChain) {
        log(`Found canonical address ${canonicalTokenAddress} on chain ${canonicalChain}`);
        setCanonicalTokenInfoStore(canonicalTokenAddress, true, canonicalChain);
        return { chainId: canonicalChain, address: canonicalTokenAddress };
      }
    }
  } else {
    const srcChainTokenAddress = Object.values(token.addresses)[0];
    const srcChainTokenChainId = Object.keys(token.addresses)[0];
    return await getCanonicalInfoForAddress({
      address: srcChainTokenAddress,
      srcChainId: parseInt(srcChainTokenChainId),
      destChainId,
    });
  }
  log('No canonical info found for token', token, srcChainId, destChainId);
  throw new NoCanonicalInfoFoundError('No canonical info found for token');
}

export const getCanonicalInfoForAddress = async ({
  address,
  srcChainId,
  destChainId,
  type,
}: {
  address: Address;
  srcChainId: number;
  destChainId: number;
  type?: TokenType;
}) => {
  if (getCanonicalStatusFromStore(address)) {
    log('found canonical address in store', address);
    return { chainId: parseInt(address), address };
  }
  log('fetching new canonical info');

  if (!type) type = await detectContractType(address);
  const { canonicalTokenAddress, canonicalChain } = await _getStatus({
    address,
    srcChainId,
    destChainId,
    type: type,
  });

  if (canonicalTokenAddress && canonicalChain) {
    log(`Found canonical address ${canonicalTokenAddress} on chain ${canonicalChain}`);
    setCanonicalTokenInfoStore(canonicalTokenAddress, true, canonicalChain);
    return { chainId: canonicalChain, address: canonicalTokenAddress };
  } else {
    log('No canonical info found for address', address, srcChainId, destChainId);
    throw new NoCanonicalInfoFoundError('No canonical info found for address');
  }
};
