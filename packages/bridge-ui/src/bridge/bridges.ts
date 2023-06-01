import { type Bridge, BridgeType } from '../domain/bridge';
import type { Prover } from '../domain/proof';
import { ProofService } from '../proof/ProofService';
import { providers } from '../provider/providers';
import { ERC20Bridge } from './ERC20Bridge';
import { ETHBridge } from './ETHBridge';

const prover: Prover = new ProofService(providers);

const ethBridge = new ETHBridge(prover);
const erc20Bridge = new ERC20Bridge(prover);

export const bridges: Record<BridgeType, Bridge> = {
  [BridgeType.ETH]: ethBridge,
  [BridgeType.ERC20]: erc20Bridge,

  // TODO
  [BridgeType.ERC721]: null,
  [BridgeType.ERC1155]: null,
};
