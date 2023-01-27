import { expect } from "chai";
import { BigNumber, ethers } from "ethers";
import RLP from "rlp";
import { EventEmitter } from "stream";
import { TaikoL1, TkoToken } from "../../typechain";
import { BlockMetadata } from "./block_metadata";
import { encodeBlockMetadata } from "./encoding";
import { BLOCK_PROPOSED_EVENT } from "./event";
import { onNewL2Block } from "./onNewL2Block";
import Proposer from "./proposer";

const buildProposeBlockInputs = (
    block: ethers.providers.Block,
    meta: BlockMetadata
) => {
    const inputs = [];
    const blockMetadataBytes = encodeBlockMetadata(meta);
    inputs[0] = blockMetadataBytes;
    inputs[1] = RLP.encode(block.transactions);
    return inputs;
};

const proposeBlock = async (
    taikoL1: TaikoL1,
    block: ethers.providers.Block,
    txListHash: string,
    commitHeight: number,
    gasLimit: BigNumber,
    commitSlot: number = 0
) => {
    const meta: BlockMetadata = {
        id: 0,
        l1Height: 0,
        l1Hash: ethers.constants.HashZero,
        beneficiary: block.miner,
        txListHash: txListHash,
        mixHash: ethers.constants.HashZero,
        extraData: block.extraData,
        gasLimit: gasLimit,
        timestamp: 0,
        commitSlot: commitSlot,
        commitHeight: commitHeight,
    };

    const inputs = buildProposeBlockInputs(block, meta);

    const tx = await taikoL1.proposeBlock(inputs);
    const receipt = await tx.wait(1);
    return receipt;
};

function newProposerListener(
    genesisHeight: number,
    eventEmitter: EventEmitter,
    l2Provider: ethers.providers.JsonRpcProvider,
    proposer: Proposer,
    taikoL1: TaikoL1,
    tkoTokenL1: TkoToken
) {
    return async (blockNumber: number) => {
        try {
            if (blockNumber <= genesisHeight) return;

            const { proposedEvent } = await onNewL2Block(
                l2Provider,
                blockNumber,
                proposer,
                taikoL1,
                proposer.getSigner(),
                tkoTokenL1
            );
            expect(proposedEvent).not.to.be.undefined;

            eventEmitter.emit(BLOCK_PROPOSED_EVENT, proposedEvent, blockNumber);
        } catch (e) {
            eventEmitter.emit("error", e);
        }
    };
}

export { buildProposeBlockInputs, proposeBlock, newProposerListener };
