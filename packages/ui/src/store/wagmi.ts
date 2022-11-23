import { writable } from "svelte/store";
import type { Client } from "@wagmi/core";
export const wagmiClient = writable<Client>();
