import type { TokenType } from '$libs/token';

import { ERC20Bridge } from './ERC20Bridge';
import { ERC721Bridge } from './ERC721Bridge';
import { ERC1155Bridge } from './ERC1155Bridge';
import { ETHBridge } from './ETHBridge';
import type { Bridge } from './types';

export const bridges: Record<TokenType, Bridge> = {
  ETH: new ETHBridge(),
  ERC20: new ERC20Bridge(),
  ERC721: new ERC721Bridge(),
  ERC1155: new ERC1155Bridge(),
};
