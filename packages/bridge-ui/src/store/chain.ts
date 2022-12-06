import { writable } from "svelte/store";
import type { Chain } from "../domain/chain";

export const fromChain = writable<Chain>();
export const toChain = writable<Chain>();
