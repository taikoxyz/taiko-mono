import type { TokenType } from '$libs/token';

import { ERC20Bridge } from './ERC20Bridge';
import { ERC721Bridge } from './ERC721Bridge';
import { ERC1155Bridge } from './ERC1155Bridge';
import { ETHBridge } from './ETHBridge';
import { ProofService } from './ProofService';
import type { Bridge } from './types';

const proofService = new ProofService();

export const bridges: Record<TokenType, Bridge> = {
  ETH: new ETHBridge(proofService),
  ERC20: new ERC20Bridge(proofService),
  ERC721: new ERC721Bridge(proofService),
  ERC1155: new ERC1155Bridge(proofService),
};
