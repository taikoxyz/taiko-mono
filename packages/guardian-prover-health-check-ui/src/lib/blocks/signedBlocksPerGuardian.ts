import { get } from 'svelte/store';
import { signedBlocks } from '$lib/dataFetcher';
import type { SignedBlock, SortedSignedBlocks } from '$lib/types';

export function signedBlocksPerGuardian(guardianProverId: number): number {
	const allSortedSignedBlocks: SortedSignedBlocks = get(signedBlocks);
	let count = 0;
	allSortedSignedBlocks.forEach((blockGroup) => {
		blockGroup.blocks.forEach((block: SignedBlock) => {
			if (block.guardianProverID === Number(guardianProverId)) {
				count++;
			}
		});
	});

	return count;
}
