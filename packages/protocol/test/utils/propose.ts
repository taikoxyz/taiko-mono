import { BigNumber, ethers } from "ethers";
import RLP from "rlp";
import { TaikoL1 } from "../../typechain";
import { BlockMetadata } from "./block_metadata";
import { encodeBlockMetadata } from "./encoding";

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
    id: number,
    gasLimit: BigNumber
) => {
    const meta: BlockMetadata = {
        id: id,
        l1Height: 0,
        l1Hash: ethers.constants.HashZero,
        beneficiary: block.miner,
        txListHash: txListHash,
        mixHash: ethers.constants.HashZero,
        extraData: block.extraData,
        gasLimit: gasLimit,
        timestamp: 0,
        commitSlot: 1,
        commitHeight: commitHeight,
    };

    const inputs = buildProposeBlockInputs(block, meta);

    const tx = await taikoL1.proposeBlock(inputs);
    const receipt = await tx.wait();
    return receipt;
};
export { buildProposeBlockInputs, proposeBlock };
