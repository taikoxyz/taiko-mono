import { writable } from "svelte/store";
import type { Ethereum } from "@wagmi/core";

export const ethereum = writable<Ethereum>();
