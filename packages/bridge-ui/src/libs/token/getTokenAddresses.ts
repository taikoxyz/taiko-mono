import { getPublicClient } from '@wagmi/core';
import { get } from 'svelte/store';
import { type Abi, type Address, getContract, zeroAddress } from 'viem';

import { erc20VaultAbi, erc721VaultAbi, erc1155VaultAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { NoCanonicalInfoFoundError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';
import { setTokenInfo, type TokenInfo, tokenInfoStore } from '$stores/tokenInfo';

import { getCanonicalInfoForToken } from './getCanonicalInfoForToken';
import { type NFT, type Token, TokenType } from './types';

export type GetTokenInfoArgs = {
  token: Token | NFT;
  srcChainId: number;
  destChainId: number;
};

const log = getLogger('token:getTokenAddresses');

export async function getTokenAddressesForAddress({
  address,
  srcChainId,
  destChainId,
  type,
}: {
  address: Address;
  srcChainId: number;
  destChainId: number;
  type: TokenType;
}): Promise<TokenInfo | null> {
  // Dummy token
  const token = {
    type,
    symbol: 'unknown',
    name: 'unknown',
    decimals: 18,
    addresses: {
      [srcChainId]: address,
      [destChainId]: address,
    },
  };
  return getTokenAddresses({ token, srcChainId, destChainId });
}

export async function getTokenAddresses({
  token,
  srcChainId,
  destChainId,
}: GetTokenInfoArgs): Promise<TokenInfo | null> {
  log('Fetching token info for', token, srcChainId, destChainId);
  if (token.type === TokenType.ETH) return null; // ETH doesn't have an address
  const type = token.type;

  // First let's get the canonical info
  const canonicalInfo = await getCanonicalInfoForToken({ token, srcChainId, destChainId });

  if (!canonicalInfo || !canonicalInfo.address || !canonicalInfo.chainId) {
    throw new NoCanonicalInfoFoundError(`Could not find any canonical info`);
  }

  const canonicalAddress = canonicalInfo.address;
  const canonicalChainId = canonicalInfo.chainId;

  let bridgedChainId: number | null = canonicalChainId === srcChainId ? destChainId : srcChainId;

  const bridgedAddress = canonicalAddress
    ? await _getBridgedAddress({ canonicalAddress, canonicalChainId, bridgedChainId, type })
    : null;

  if (bridgedAddress === zeroAddress || bridgedAddress === null) {
    log('No bridged address found for', token, canonicalAddress, canonicalChainId, bridgedChainId, type);
    bridgedChainId = null;
  }

  const tokenInfo = {
    canonical: {
      chainId: canonicalChainId,
      address: canonicalAddress,
    },
    bridged: bridgedChainId && bridgedAddress ? { chainId: bridgedChainId, address: bridgedAddress } : null,
  };
  setTokenInfo({ canonicalAddress, bridgedAddress, info: tokenInfo });
  return tokenInfo;
}

const _getBridgedAddress = async ({
  canonicalAddress,
  canonicalChainId,
  bridgedChainId,
  type,
}: {
  canonicalAddress: Address;
  canonicalChainId: number;
  bridgedChainId: number;
  type: TokenType;
}) => {
  let bridgedTokenAddress;

  // check the store first to save some time
  const tokenInfo = get(tokenInfoStore)[canonicalAddress];
  bridgedTokenAddress = tokenInfo?.bridged?.address;

  if (bridgedTokenAddress && tokenInfo.bridged?.chainId === bridgedChainId) {
    log('found bridged info in store', bridgedTokenAddress);
    return bridgedTokenAddress;
  }

  const vaultABI =
    type === TokenType.ERC721 ? erc721VaultAbi : type === TokenType.ERC1155 ? erc1155VaultAbi : erc20VaultAbi;

  const vaultAddressKey =
    type === TokenType.ERC721
      ? 'erc721VaultAddress'
      : type === TokenType.ERC1155
        ? 'erc1155VaultAddress'
        : 'erc20VaultAddress';

  log('getting bridged address', canonicalAddress, canonicalChainId, bridgedChainId, type, vaultAddressKey);

  const client = await getPublicClient(config, { chainId: bridgedChainId });
  if (!client) throw new Error('Could not get public client');

  const bridgedVaultContract = getContract({
    abi: vaultABI as Abi,
    client,
    address: routingContractsMap[bridgedChainId][canonicalChainId][vaultAddressKey],
  });

  bridgedTokenAddress = (await bridgedVaultContract.read.canonicalToBridged([
    BigInt(canonicalChainId),
    canonicalAddress,
  ])) as Address;

  return bridgedTokenAddress;
};
