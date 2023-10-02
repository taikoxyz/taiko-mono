import { readContract } from '@wagmi/core';
import { ContractFunctionExecutionError, UnknownTypeError } from 'viem';

import { erc721ABI, erc1155ABI } from '$abi';
import { getLogger } from '$libs/util/logger';

import { TokenType } from './types';

const log = getLogger('detectContractType');

export async function detectContractType(contractAddress: string) {
  log('detectContractType', { contractAddress });

  try {
    await readContract({
      address: contractAddress as `0x${string}`, // TODO: type Address
      abi: erc721ABI,
      functionName: 'ownerOf',
      args: [0n],
    });
    log('is ERC721');
    return TokenType.ERC721;
  } catch (err) {
    if (err instanceof ContractFunctionExecutionError) {
      if (err.cause.message.includes('ERC721: invalid token ID')) {
        // valid erc721 contract, but invalid token id
        log('is ERC721');
        return TokenType.ERC721;
      }
    }

    log('is not ERC721', err);
    try {
      await readContract({
        address: contractAddress as `0x${string}`,
        abi: erc1155ABI,
        functionName: 'isApprovedForAll',
        args: ['0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000'],
      });
      log('is ERC1155');
      return TokenType.ERC1155;
    } catch (err) {
      // eslint-disable-next-line no-console
      console.log(err);
      throw new UnknownTypeError({ type: 'Unknown tokentype' });
    }
  }
}
