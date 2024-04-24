import { encodeAbiParameters, encodeFunctionData, type Hex, zeroAddress } from 'viem';

import { erc20VaultAbi, erc721VaultAbi, erc1155VaultAbi } from '$abi';
import { type NFT, type Token, TokenType } from '$libs/token';
import { getLogger } from '$libs/util/logger';

type CanonicalERC20 = {
  chainId: number;
  addr: string;
  decimals: number;
  symbol: string;
  name: string;
};

type CanonicalNFT = {
  chainId: number;
  addr: string;
  symbol: string;
  name: string;
};

const log = getLogger('calculateMessageDataSize');

export async function calculateMessageDataSize({
  token,
  chainId,
  tokenIds,
  amounts,
}: {
  token: Token | NFT | NFT[];
  chainId: number;
  tokenIds?: number[];
  amounts?: number[];
}): Promise<{ size: number }> {
  if (Array.isArray(token)) {
    let totalSize = 0;
    for (const nft of token) {
      const encodedData = await encodeData(nft, chainId);

      const tmpBuffer = Buffer.from(encodedData.substring(2), 'hex');

      const buffer = Buffer.alloc(tmpBuffer.length + 32);

      tmpBuffer.copy(buffer);

      totalSize += buffer.length;
    }
    return { size: totalSize };
  } else {
    if (token.type === TokenType.ETH) {
      return { size: 0 };
    }

    const encodedData = await encodeData(token, chainId, tokenIds, amounts);

    const tmpBuffer = Buffer.from(encodedData.substring(2), 'hex');

    const buffer = Buffer.alloc(tmpBuffer.length + 32);

    tmpBuffer.copy(buffer);

    return { size: buffer.length };
  }
}

async function encodeData(token: Token, chainId: number, tokenIds?: number[], amounts?: number[]): Promise<Hex> {
  if (token.type === TokenType.ERC20) {
    const cToken = {
      chainId, // technically should be the canonical chain but as we just are just calculating the data size it doesn't matter
      addr: token.addresses[chainId], // same as above
      decimals: token.decimals,
      symbol: token.symbol,
      name: token.name,
    } satisfies CanonicalERC20;

    const params = [
      {
        type: 'tuple',
        name: 'ctoken',
        components: [
          { type: 'uint64', name: 'chainId' },
          { type: 'address', name: 'addr' },
          { type: 'uint8', name: 'decimals' },
          { type: 'string', name: 'symbol' },
          { type: 'string', name: 'name' },
        ],
      },
      {
        type: 'address',
        name: 'user',
      },
      {
        type: 'address',
        name: 'to',
      },
      {
        type: 'uint256',
        name: 'balanceChange',
      },
    ];

    const values = [
      // cToken tuple
      [cToken.chainId, cToken.addr, cToken.decimals, cToken.symbol, cToken.name],
      zeroAddress, // user address
      zeroAddress, // to address
      0, // balanceChange
    ];

    const callData = encodeAbiParameters(params, values);
    log('callData', callData);

    const encodedData = encodeFunctionData({
      abi: erc20VaultAbi,
      functionName: 'onMessageInvocation',
      args: [callData],
    });

    log('encodedData', encodedData);
    return encodedData;
  }
  if (token.type === TokenType.ERC1155) {
    const cNFT = {
      chainId, // technically should be the canonical chain but as we just are just calculating the data size it doesn't matter
      addr: token.addresses[chainId], // same as above
      symbol: token.symbol,
      name: token.name,
    } satisfies CanonicalNFT;

    const params = [
      {
        type: 'tuple',
        name: 'cNFT',
        components: [
          { type: 'uint64', name: 'chainId' },
          { type: 'address', name: 'addr' },
          { type: 'string', name: 'symbol' },
          { type: 'string', name: 'name' },
        ],
      },
      {
        type: 'address',
        name: 'user',
      },
      {
        type: 'address',
        name: 'to',
      },
      {
        type: 'uint[]',
        name: 'tokenIds',
      },
      {
        type: 'uint[]',
        name: 'amounts',
      },
    ];

    const values = [[cNFT.chainId, cNFT.addr, cNFT.symbol, cNFT.name], zeroAddress, zeroAddress, tokenIds, amounts];

    const callData = encodeAbiParameters(params, values);
    log('callData', callData);

    const encodedData = encodeFunctionData({
      abi: erc1155VaultAbi,
      functionName: 'onMessageInvocation',
      args: [callData],
    });
    log('encodedData', encodedData);
    return encodedData;
  } else if (token.type === TokenType.ERC721) {
    const cNFT = {
      chainId, // technically should be the canonical chain but as we just are just calculating the data size it doesn't matter
      addr: token.addresses[chainId], // same as above
      symbol: token.symbol,
      name: token.name,
    } satisfies CanonicalNFT;

    const params = [
      {
        type: 'tuple',
        name: 'cNFT',
        components: [
          { type: 'uint64', name: 'chainId' },
          { type: 'address', name: 'addr' },
          { type: 'string', name: 'symbol' },
          { type: 'string', name: 'name' },
        ],
      },
      {
        type: 'address',
        name: 'user',
      },
      {
        type: 'address',
        name: 'to',
      },
      {
        type: 'uint[]',
        name: 'tokenIds',
      },
    ];

    const values = [[cNFT.chainId, cNFT.addr, cNFT.symbol, cNFT.name], zeroAddress, zeroAddress, tokenIds?.map(BigInt)];

    const callData = encodeAbiParameters(params, values);
    log('callData', callData);

    const encodedData = encodeFunctionData({
      abi: erc721VaultAbi,
      functionName: 'onMessageInvocation',
      args: [callData],
    });

    log('encodedData', encodedData);
    return encodedData;
  } else {
    throw new Error('Unsupported token type');
  }
}
