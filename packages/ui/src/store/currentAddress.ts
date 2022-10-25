import { writable } from "svelte/store";

const currentAddress = writable<string>();

export { currentAddress };
