import { CHAIN_MAINNET, CHAIN_TKO } from "../domain/chain";
import { writable } from "svelte/store";
import type { Chain } from "../domain/chain";

export const fromChain = writable<Chain>(CHAIN_MAINNET);
export const toChain = writable<Chain>(CHAIN_TKO);
