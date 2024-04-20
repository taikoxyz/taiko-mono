import type { GuardianProverIdsMap, SignedBlocks } from '$lib/types';

export const getGuardianProverIdsPerBlockNumber = (blocks: SignedBlocks): GuardianProverIdsMap => {
	const blockNumbers = Object.keys(blocks);
	return blockNumbers.reduce((prev, blockNumber) => {
		return {
			...prev,
			[blockNumber]: blocks[blockNumber].map((block) => block.guardianProverID)
		};
	}, {});
};
