import { get } from 'svelte/store';
import { signedBlocks } from '$stores';
import type { SortedSignedBlocks } from '$lib/types';

export function signedBlocksPerGuardian(guardianProverId: number): number {
	const allSortedSignedBlocks: SortedSignedBlocks = get(signedBlocks);
	const targetId = Number(guardianProverId);

	return allSortedSignedBlocks.reduce((total, blockGroup) => {
		const matchingBlocks = blockGroup.blocks.filter((block) => block.guardianProverID === targetId);
		return total + matchingBlocks.length;
	}, 0);
}
