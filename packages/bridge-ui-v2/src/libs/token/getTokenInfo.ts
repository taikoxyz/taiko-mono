import { erc721ABI, fetchToken, readContract } from '@wagmi/core';
import type { Address } from 'viem';

import { detectContractType } from './detectContractType';
import { type TokenDetails, TokenType } from './types';

export const getTokenInfoFromAddress = async (address: Address) => {
  try {
    const tokenType = await detectContractType(address);
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
      return details;
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
      return details;
    }
    return null;
  } catch (err) {
    return null;
  }
};
