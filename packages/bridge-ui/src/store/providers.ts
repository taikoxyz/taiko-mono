import { ethers } from "ethers";
import { CHAIN_ID_MAINNET, CHAIN_ID_TAIKO } from "../domain/chain";
import { writable } from "svelte/store";

export const providers = writable(
  new Map<number, ethers.providers.JsonRpcProvider>()
);

/**
 * Will set the list of custom RPC providers, Mainnet & Taiko
 */
export function setProviders(l1RpcURL: string, l2RpcURL: string) {
  const providerMap = new Map<number, ethers.providers.JsonRpcProvider>();

  providerMap.set(
    CHAIN_ID_MAINNET,
    new ethers.providers.JsonRpcProvider(l1RpcURL)
  );

  providerMap.set(
    CHAIN_ID_TAIKO,
    new ethers.providers.JsonRpcProvider(l2RpcURL)
  );

  providers.set(providerMap);

  return { providerMap, providers };
}
