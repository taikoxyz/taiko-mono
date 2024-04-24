import { routingContractsMap } from '$bridgeConfig';
import { BridgeProver } from '$libs/proof';
import type { TokenType } from '$libs/token';

import type { Bridge } from './Bridge';
import { ERC20Bridge } from './ERC20Bridge';
import { ERC721Bridge } from './ERC721Bridge';
import { ERC1155Bridge } from './ERC1155Bridge';
import { ETHBridge } from './ETHBridge';

let proverInstance: BridgeProver | null = null;

function getProverInstance(): BridgeProver {
  if (!proverInstance) {
    proverInstance = new BridgeProver();
  }
  return proverInstance;
}

export const bridges: Record<TokenType, Bridge> = {
  get ETH() {
    return new ETHBridge(getProverInstance());
  },
  get ERC20() {
    return new ERC20Bridge(getProverInstance());
  },
  get ERC721() {
    return new ERC721Bridge(getProverInstance());
  },
  get ERC1155() {
    return new ERC1155Bridge(getProverInstance());
  },
};

export const hasBridge = (srcChainId: number, destChainId: number): boolean => {
  return !!routingContractsMap[srcChainId] && !!routingContractsMap[srcChainId][destChainId];
};

export const getValidBridges = (chainId: number): number[] | undefined => {
  const validBridges: number[] = [];

  const bridgeMap = routingContractsMap[chainId];
  if (bridgeMap) {
    for (const key in bridgeMap) {
      if (key !== chainId.toString()) {
        validBridges.push(Number(key));
      }
    }
  }

  return validBridges.length > 0 ? validBridges : undefined;
};
