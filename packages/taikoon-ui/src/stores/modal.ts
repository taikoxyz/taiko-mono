import { writable } from 'svelte/store';

// We make this global because we need to be able to
// open and close the modal from anywhere in the app
export const switchChainModal = writable<boolean>(false);

export const bridgePausedModal = writable<boolean>(false);
