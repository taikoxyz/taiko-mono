import type { ethers } from "ethers";
import { writable } from "svelte/store";

export const providers = writable<
  Map<number, ethers.providers.JsonRpcProvider>
>(new Map<number, ethers.providers.JsonRpcProvider>());
