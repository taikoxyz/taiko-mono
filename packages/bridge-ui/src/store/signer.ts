import { writable } from "svelte/store";
import type { Signer } from "ethers";

export const signer = writable<Signer>();
