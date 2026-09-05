import { writable } from 'svelte/store';

import { ImportMethod } from '$components/Bridge/types';
import type { NFT } from '$libs/token';

export const selectedImportMethod = writable<ImportMethod>(ImportMethod.NONE);

/**
 * The scanned NFTs. A store rather than ImportStep-local state because ImportStep
 * remounts on every return to the IMPORT step, and back-navigation from Review used to
 * dump the user on the initial scan chooser with their results gone.
 */
export const foundNFTs = writable<NFT[]>([]);
