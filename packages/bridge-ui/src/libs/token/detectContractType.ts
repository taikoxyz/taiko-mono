import { readContract } from '@wagmi/core';

import { erc20Abi, erc721Abi, erc1155Abi } from '$abi';
import { UnknownTokenTypeError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { TokenType } from './types';

type Address = `0x${string}`;

const log = getLogger('detectContractType');

async function isERC721(address: Address, chainId: number): Promise<boolean> {
  try {
    const isERC721 = await readContract(config, {
      address,
      abi: erc721Abi,
      functionName: 'supportsInterface',
      args: ['0x80ac58cd'], // Identifier for ERC-721
      chainId,
    });

    if (isERC721) {
      return true;
    }
  } catch (err) {
    // we expect this error to be thrown if the token is a ERC721 and the tokenId is invalid
    return (err as Error)?.message?.includes('ERC721: invalid token ID') ?? false;
  }

  return false;
}
// return err instanceof ContractFunctionExecutionError &&
//   err.cause.message.includes('ERC721: invalid token ID');
async function isERC1155(address: Address, chainId: number): Promise<boolean> {
  try {
    const isERC1155 = await readContract(config, {
      address,
      abi: erc1155Abi,
      functionName: 'supportsInterface',
      args: ['0xd9b67a26'], // Identifier for ERC-1155
      chainId,
    });

    if (isERC1155) {
      return true;
    }
  } catch {
    return false;
  }
  return false;
}

async function isERC20(address: Address, chainId: number): Promise<boolean> {
  try {
    await readContract(config, {
      address,
      abi: erc20Abi,
      functionName: 'balanceOf',
      args: ['0x0000000000000000000000000000000000000000'],
      chainId,
    });

    return true;
  } catch {
    return false;
  }
}

export async function detectContractType(contractAddress: Address, chainId: number): Promise<TokenType> {
  log('detectContractType', { contractAddress });

  if (await isERC721(contractAddress, chainId)) {
    log('is ERC721');
    return TokenType.ERC721;
  }

  if (await isERC1155(contractAddress, chainId)) {
    log('is ERC1155');
    return TokenType.ERC1155;
  }

  if (await isERC20(contractAddress, chainId)) {
    log('is ERC20');
    return TokenType.ERC20;
  }

  log('Unable to determine token type', { contractAddress });
  throw new UnknownTokenTypeError();
}
