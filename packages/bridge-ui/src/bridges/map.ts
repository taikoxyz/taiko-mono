import ERC20Bridge from '../erc20/bridge';
import ETHBridge from '../eth/bridge';
import { ProofService } from '../proof/service';
import type { Prover } from '../domain/proof';
import { providersMap } from '../providers/map';
import { type Bridge, BridgeType } from '../domain/bridge';

const prover: Prover = new ProofService(providersMap);
const ethBridge = new ETHBridge(prover);
const erc20Bridge = new ERC20Bridge(prover);

export const bridgesMap = new Map<BridgeType, Bridge>([
  [BridgeType.ETH, ethBridge],
  [BridgeType.ERC20, erc20Bridge],
]);
