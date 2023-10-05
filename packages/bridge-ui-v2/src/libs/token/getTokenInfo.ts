import { erc721ABI, fetchToken, readContract } from '@wagmi/core';
import type { Address } from 'viem';

import { getLogger } from '$libs/util/logger';

import { detectContractType } from './detectContractType';
import { type TokenDetails, TokenType } from './types';

const log = getLogger('libs:token:getTokenInfo');

export const getTokenInfoFromAddress = async (address: Address, type?: TokenType) => {
  try {
    const tokenType: TokenType = type ?? (await detectContractType(address));
    const details: TokenDetails = {} as TokenDetails;
    if (tokenType === TokenType.ERC20) {
      const token = await fetchToken({
        address,
      });
      details.type = tokenType;
      details.address = address;
      details.name = token.name;
      details.symbol = token.symbol;
      details.decimals = token.decimals;
    } else if (tokenType === TokenType.ERC1155) {
      // todo: via URI?
      details.type = tokenType;
      return details;
    } else if (tokenType === TokenType.ERC721) {
      const name = await readContract({
        address,
        abi: erc721ABI,
        functionName: 'name',
      });

      const symbol = await readContract({
        address,
        abi: erc721ABI,
        functionName: 'symbol',
      });

      details.type = tokenType;
      details.address = address;
      details.name = name;
      details.symbol = symbol;
      details.decimals = 0;
    } else {
      throw new Error('Unsupported token type');
    }
    return details;
  } catch (err) {
    log('Error getting token info', err);
    throw new Error('Error getting token info');
  }
};
