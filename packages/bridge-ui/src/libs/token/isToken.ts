import type { NFT, Token } from './types';

export const isToken = (token: Maybe<Token | NFT>): token is Token => {
  return (token as Token).decimals !== undefined;
};
