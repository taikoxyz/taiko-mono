import { routingContractsMap } from '$bridgeConfig';
import { BridgeProver } from '$libs/proof';
import type { TokenType } from '$libs/token';

import type { Bridge } from './Bridge';
import { ERC20Bridge } from './ERC20Bridge';
import { ERC721Bridge } from './ERC721Bridge';
import { ERC1155Bridge } from './ERC1155Bridge';
import { ETHBridge } from './ETHBridge';

const prover = new BridgeProver();

export const bridges: Record<TokenType, Bridge> = {
  ETH: new ETHBridge(prover),
  ERC20: new ERC20Bridge(prover),
  ERC721: new ERC721Bridge(prover),
  ERC1155: new ERC1155Bridge(prover),
};

export const hasBridge = (srcChainId: number, destChainId: number): boolean => {
  return !!routingContractsMap[srcChainId] && !!routingContractsMap[srcChainId][destChainId];
};
