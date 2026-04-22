import { get } from 'svelte/store';
import { type Abi, type Address, getContract, zeroAddress } from 'viem';

import { erc20VaultAbi, erc721VaultAbi, erc1155VaultAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { NoCanonicalInfoFoundError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';
import { isCanonicalAddress, tokenInfoStore } from '$stores/tokenInfo';

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

      // check store first to save some time
      if (isCanonicalAddress(address)) {
        log('found canonical info in store');

        const tokenInfo = get(tokenInfoStore)[address];
        const canonicalChain = tokenInfo.canonical?.chainId;
        const canonicalAddress = tokenInfo.canonical?.address;

        log('canonical info', canonicalChain, canonicalAddress);
        if (canonicalChain && canonicalAddress) {
          return { chainId: canonicalChain, address: canonicalAddress };
        }
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
        return { chainId: canonicalChain, address: canonicalTokenAddress };
      }
    }
  } else {
    const srcChainTokenAddress = Object.values(token.addresses)[0];
    const srcChainTokenChainId = parseInt(Object.keys(token.addresses)[0]);

    const destinationId = srcChainTokenChainId === srcChainId ? destChainId : srcChainTokenChainId;

    // check store first to save some time
    if (isCanonicalAddress(srcChainTokenAddress)) {
      log('found canonical info in store');

      const tokenInfo = get(tokenInfoStore)[srcChainTokenAddress];
      const canonicalChain = tokenInfo.canonical?.chainId;
      const canonicalAddress = tokenInfo.canonical?.address;

      log('canonical info', canonicalChain, canonicalAddress);
      if (canonicalChain && canonicalAddress) {
        return { chainId: canonicalChain, address: canonicalAddress };
      }
    }
    log('fetching new canonical info');

    return await getCanonicalInfoForAddress({
      address: srcChainTokenAddress,
      srcChainId,
      destChainId: destinationId,
      type: token.type,
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
  try {
    if (!type) type = await detectContractType(address, srcChainId);
  } catch {
    type = await detectContractType(address, destChainId);
  }

  const { canonicalTokenAddress, canonicalChain } = await _getStatus({
    address,
    srcChainId,
    destChainId,
    type: type,
  });

  if (canonicalTokenAddress && canonicalChain) {
    log(`Found canonical address ${canonicalTokenAddress} on chain ${canonicalChain}`);
    return { chainId: canonicalChain, address: canonicalTokenAddress };
  } else {
    log('No canonical info found for address', address, srcChainId, destChainId);
    throw new NoCanonicalInfoFoundError('No canonical info found for address');
  }
};

const _getStatus = async ({ address, srcChainId, destChainId, type }: CheckCanonicalStatusArgs) => {
  const srcChainTokenAddress = address;

  const vaultABI =
    type === TokenType.ERC721 ? erc721VaultAbi : type === TokenType.ERC1155 ? erc1155VaultAbi : erc20VaultAbi;

  const vaultAddressKey =
    type === TokenType.ERC721
      ? 'erc721VaultAddress'
      : type === TokenType.ERC1155
        ? 'erc1155VaultAddress'
        : 'erc20VaultAddress';

  const srcClient = await publicClient(srcChainId);
  const destClient = await publicClient(destChainId);
  if (!srcClient || !destClient) throw new Error('Could not get public client');

  const srcTokenVaultContract = getContract({
    abi: vaultABI as Abi,
    client: srcClient,
    address: routingContractsMap[srcChainId][destChainId][vaultAddressKey],
  });

  const destTokenVaultContract = getContract({
    abi: vaultABI as Abi,
    client: destClient,
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
    // But either chain passed could be the canonical chain, so we need to check which one by checking for valid contract types
    try {
      await detectContractType(srcChainTokenAddress, srcChainId);
      canonicalChain = srcChainId;
      log('canonical chain is src', srcChainId);
    } catch {
      canonicalChain = destChainId;
      log('canonical chain is dest', destChainId);
    }
  } else if (destCanonicalCheck !== zeroAddress) {
    // if the destination is not zero, we found a canonical address there
    canonicalTokenAddress = destCanonicalCheck;
    canonicalChain = srcChainId;
    log('canonical info1', canonicalTokenAddress, canonicalChain);
  } else {
    // if the source is not zero, we found a canonical address there
    canonicalTokenAddress = srcCanonicalCheck;
    canonicalChain = destChainId;
    log('canonical info2', canonicalTokenAddress, canonicalChain);
  }
  log('canonical info', canonicalTokenAddress, canonicalChain);
  return { canonicalTokenAddress, canonicalChain };
};
