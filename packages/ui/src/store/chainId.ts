import { writable } from "svelte/store";

const chainId = writable<number>();

export { chainId };
