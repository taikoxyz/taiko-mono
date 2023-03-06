import { derived, writable } from "svelte/store";
import { BridgeType } from "../domain/bridge";
import type { Bridge } from "../domain/bridge";
import type { ethers } from "ethers";
import type { Prover } from "../domain/proof";
import { ProofService } from "../proof/service";
import ETHBridge from "../eth/bridge";
import ERC20Bridge from "../erc20/bridge";
import { CHAIN_MAINNET, CHAIN_TKO } from "../domain/chain";

export const bridgeType = writable<BridgeType>(BridgeType.ETH);
export const bridges = writable(new Map<BridgeType, Bridge>());
export const chainIdToTokenVaultAddress = writable(new Map<number, string>());

export const activeBridge = derived([bridgeType, bridges], ($values) =>
  $values[1].get($values[0])
);

export function updateBridges(
  providerMap: Map<number, ethers.providers.JsonRpcProvider>,
  mainnetTokenVaultAddress: string,
  taikoTokenVaultAddress: string
) {
  const prover: Prover = new ProofService(providerMap);
  const ethBridge = new ETHBridge(prover);
  const erc20Bridge = new ERC20Bridge(prover);

  bridges.update((store) => {
    store.set(BridgeType.ETH, ethBridge);
    store.set(BridgeType.ERC20, erc20Bridge);
    return store;
  });

  chainIdToTokenVaultAddress.update((store) => {
    store.set(CHAIN_MAINNET.id, mainnetTokenVaultAddress);
    store.set(CHAIN_TKO.id, taikoTokenVaultAddress);

    return store;
  });

  return { bridges, chainIdToTokenVaultAddress };
}
