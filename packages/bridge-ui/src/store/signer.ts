import type { Signer } from 'ethers';
import { writable } from 'svelte/store';

export const signer = writable<Signer>();
