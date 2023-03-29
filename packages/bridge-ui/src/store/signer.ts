import { writable } from 'svelte/store';
import type { Signer } from 'ethers';
import { subscribeToSigner } from '../signer/subscriber';

export const signer = writable<Signer>();

signer.subscribe(subscribeToSigner);
