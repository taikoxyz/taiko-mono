import type { GuardianProverIdsMap, SignedBlock, SignedBlocks } from "$lib/types";

export const getGuardianProverIdsPerBlockNumber = (blocks: SignedBlocks): GuardianProverIdsMap => {
    const result: GuardianProverIdsMap = {};

    for (const blockNumber in blocks) {
        result[blockNumber] = blocks[blockNumber].map((block: SignedBlock) => block.guardianProverID);
    }

    return result;
};