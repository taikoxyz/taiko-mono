import { ethers } from "ethers";
import RLP from "rlp";
import { TaikoL1 } from "../../typechain";

const generateCommitHash = (
    block: ethers.providers.Block
): { hash: string; txListHash: string } => {
    const txListHash = ethers.utils.keccak256(RLP.encode(block.transactions));
    const hash = ethers.utils.keccak256(
        ethers.utils.solidityPack(
            ["address", "bytes32"],
            [block.miner, txListHash]
        )
    );

    return { hash: hash, txListHash: txListHash };
};

const commitBlock = async (
    taikoL1: TaikoL1,
    block: ethers.providers.Block,
    commitSlot: number = 0
): Promise<{
    tx: ethers.ContractTransaction;
    commit: { hash: string; txListHash: string };
}> => {
    const commit = generateCommitHash(block);
    const tx = await taikoL1.commitBlock(commitSlot, commit.hash);
    return { tx, commit };
};

export { generateCommitHash, commitBlock };
