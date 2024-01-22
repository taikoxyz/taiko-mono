import type { SignedBlocks, SortedSignedBlocks } from '$lib/types';

export const sortSignedBlocksDescending = (blocks: SignedBlocks): SortedSignedBlocks => {
	const blockNumbers = Object.keys(blocks)
		.map(Number)
		.sort((a, b) => b - a);

	return blockNumbers.map((blockNumber) => {
		return {
			blockNumber: blockNumber.toString(),
			blocks: blocks[blockNumber.toString()]
		};
	});
};
