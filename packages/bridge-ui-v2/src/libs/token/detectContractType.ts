import { readContract } from '@wagmi/core';

import { erc20ABI, erc721ABI, erc1155ABI } from '$abi';
import { UnknownTokenTypeError } from '$libs/error';
import { getLogger } from '$libs/util/logger';

import { TokenType } from './types';

type Address = `0x${string}`;

const log = getLogger('detectContractType');

async function isERC721(address: Address): Promise<boolean> {
  try {
    await readContract({
      address,
      abi: erc721ABI,
      functionName: 'ownerOf',
      args: [0n],
    });
    return true;
  } catch (err) {
    // we expect this error to be thrown if the token is a ERC721 and the tokenId is invalid
    return (err as Error)?.message?.includes('ERC721: invalid token ID') ?? false;
  }
}
// return err instanceof ContractFunctionExecutionError &&
//   err.cause.message.includes('ERC721: invalid token ID');
async function isERC1155(address: Address): Promise<boolean> {
  try {
    await readContract({
      address,
      abi: erc1155ABI,
      functionName: 'isApprovedForAll',
      args: ['0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000'],
    });
    return true;
  } catch {
    return false;
  }
}

async function isERC20(address: Address): Promise<boolean> {
  try {
    await readContract({
      address,
      abi: erc20ABI,
      functionName: 'balanceOf',
      args: ['0x0000000000000000000000000000000000000000'],
    });
    return true;
  } catch {
    return false;
  }
}

export async function detectContractType(contractAddress: Address): Promise<TokenType> {
  log('detectContractType', { contractAddress });

  if (await isERC721(contractAddress)) {
    log('is ERC721');
    return TokenType.ERC721;
  }

  if (await isERC1155(contractAddress)) {
    log('is ERC1155');
    return TokenType.ERC1155;
  }

  if (await isERC20(contractAddress)) {
    log('is ERC20');
    return TokenType.ERC20;
  }

  log('Unable to determine token type', { contractAddress });
  throw new UnknownTokenTypeError();
}
