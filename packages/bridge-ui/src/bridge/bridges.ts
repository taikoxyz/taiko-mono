import { ProofService } from '../proof/ProofService';
import type { Prover } from '../domain/proof';
import { providersMap } from '../provider/providers';
import { ETHBridge } from './ETHBridge';
import { ERC20Bridge } from './ERC20Bridge';
import { type Bridge, BridgeType } from '../domain/bridge';

const prover: Prover = new ProofService(providersMap);

const ethBridge = new ETHBridge(prover);
const erc20Bridge = new ERC20Bridge(prover);

export const bridgesMap = new Map<BridgeType, Bridge>([
  [BridgeType.ETH, ethBridge],
  [BridgeType.ERC20, erc20Bridge],
]);
