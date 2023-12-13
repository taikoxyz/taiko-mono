import { getContract } from '@wagmi/core';
import type { Abi, Address } from 'viem';

import { erc20VaultABI, erc721VaultABI, erc1155VaultABI } from '$abi';
import { ContractType } from '$libs/bridge';
import { getContractAddressByType } from '$libs/bridge/getContractAddressByType';
// import { checkForAdblocker } from '$libs/util/checkForAdblock';
import { extractIPFSCidFromUrl } from '$libs/util/extractIPFSCidFromUrl';
import { fetchNFTMetadata } from '$libs/util/fetchNFTMetadata';
import { getFileExtension } from '$libs/util/getFileExtension';
import { getLogger } from '$libs/util/logger';
import { safeParseUrl } from '$libs/util/safeParseUrl';

import { getCrossChainAddress } from './getCrossChainAddress';
import { getTokenWithInfoFromAddress } from './getTokenWithInfoFromAddress';
import { type NFT, TokenType } from './types';

const log = getLogger('libs:token:fetchNFTImageUrl');

const useGateway = (url: string, tokenId: number): string | null => {
  const { cid } = extractIPFSCidFromUrl(url);
  const extension = getFileExtension(url);
  if (tokenId !== undefined && tokenId !== null && cid) {
    return `https://ipfs.io/ipfs/${cid}/${tokenId}.${extension}`;
  } else {
    log(`No valid CID found in ${url}`);
    return null;
  }
};

const fetchImageUrl = async (url: string, tokenId: number): Promise<string> => {
  const imageLoaded = await testImageLoad(url);

  if (imageLoaded) {
    return url;
  } else {
    log('fetchImageUrl failed to load image');
    const newUrl = useGateway(url, tokenId);
    if (newUrl) {
      const gatewayImageLoaded = await testImageLoad(newUrl);
      if (gatewayImageLoaded) {
        return newUrl;
      }
    }
  }
  throw new Error(`No image found for ${url}`);
};

const testImageLoad = (url: string): Promise<boolean> => {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(true);
    img.onerror = () => resolve(false);
    img.src = url;
  });
};

export const fetchNFTImageUrl = async (token: NFT, srcChainId: number, destChainId: number): Promise<NFT> => {
  try {
    let tokenWithMetadata: NFT | null = token;

    if (!tokenWithMetadata.metadata) {
      tokenWithMetadata = await crossChainFetchNFTMetadata(token, srcChainId, destChainId);
      if (!tokenWithMetadata) throw new Error('No cross chain data found');
    }

    if (!tokenWithMetadata.metadata?.image) throw new Error('No image found');

    const url = safeParseUrl(tokenWithMetadata.metadata.image);
    if (!url) throw new Error(`Invalid image URL: ${tokenWithMetadata.metadata.image}`);

    const imageUrl = await fetchImageUrl(url, token.tokenId);

    token.name = tokenWithMetadata.name; // TODO: discuss if we want to overwrite the name with the canonical one
    token.metadata = {
      ...tokenWithMetadata.metadata,
      image: imageUrl,
    };

    return token;
  } catch (error) {
    log(`Error fetching image for ${token.name} id: ${token.tokenId}`, error);
    return token;
  }
};

const crossChainFetchNFTMetadata = async (token: NFT, srcChainId: number, destChainId: number): Promise<NFT | null> => {
  let canonicalAddress = null;
  try {
    return await fetchNFTMetadata(token);
  } catch (error) {
    log(`Error fetching metadata for ${token.name} id: ${token.tokenId}`, error);

    const vaultAddress = getContractAddressByType({
      srcChainId,
      destChainId,
      tokenType: token.type,
      contractType: ContractType.VAULT,
    });

    const vaultABI =
      token.type === TokenType.ERC721
        ? erc721VaultABI
        : token.type === TokenType.ERC1155
        ? erc1155VaultABI
        : erc20VaultABI;

    const srcChainTokenVault = getContract({
      abi: vaultABI as Abi,
      chainId: srcChainId,
      address: vaultAddress,
    });

    const isBridgedToken = await srcChainTokenVault.read.isBridgedToken([token.addresses[srcChainId]]);
    // if the token has no metadata but is also not bridged, we do not need to continue searching
    if (!isBridgedToken) throw new Error('Token is not bridged');

    canonicalAddress = await findCanonicalTokenAddress(token, srcChainId, destChainId);
    if (!canonicalAddress) return null;
    const cToken = (await getTokenWithInfoFromAddress({
      contractAddress: canonicalAddress,
      srcChainId: destChainId,
      tokenId: token.tokenId,
      type: token.type,
    })) as NFT;
    cToken.addresses = { ...token.addresses, [destChainId]: canonicalAddress };

    return await fetchNFTMetadata(cToken);
  }
};

async function findCanonicalTokenAddress(token: NFT, srcChainId: number, destChainId: number): Promise<Address | null> {
  // If we have a crosschain address, odds are high it is the canonical address
  const crossChainAddress = await getCrossChainAddress({ token, srcChainId, destChainId });
  if (crossChainAddress) return crossChainAddress;
  // TODO: go deeper
  return null;
}
