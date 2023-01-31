import { ethers } from "ethers";
import RLP from "rlp";
import { TaikoL1 } from "../../typechain";
import { BlockProposedEvent } from "../../typechain/LibProposing";
import { BlockCommittedEvent } from "../../typechain/TaikoEvents";
import { proposeBlock } from "./propose";
import { sendTinyEtherToZeroAddress } from "./seed";

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
    blockCommittedEvent: BlockCommittedEvent | undefined;
    receipt: ethers.ContractReceipt;
}> => {
    const commit = generateCommitHash(block);
    const tx = await taikoL1.commitBlock(commitSlot, commit.hash);
    const receipt = await tx.wait(1);
    const blockCommittedEvent = receipt.events!.find(
        (e) => e.event === "BlockCommitted"
    ) as any as BlockCommittedEvent;
    return { tx, commit, blockCommittedEvent, receipt };
};

const commitAndProposeLatestBlock = async (
    taikoL1: TaikoL1,
    l1Signer: any,
    l2Provider: ethers.providers.JsonRpcProvider,
    commitSlot: number = 0
) => {
    const { commitConfirmations } = await taikoL1.getConfig();
    const block = await l2Provider.getBlock("latest");
    const { tx, commit } = await commitBlock(
        taikoL1.connect(l1Signer),
        block,
        commitSlot
    );
    const commitReceipt = await tx.wait(1);

    for (let i = 0; i < commitConfirmations.toNumber(); i++) {
        await sendTinyEtherToZeroAddress(l1Signer);
    }

    const proposeReceipt = await proposeBlock(
        taikoL1.connect(l1Signer),
        block,
        commit.txListHash,
        commitReceipt.blockNumber as number,
        block.gasLimit,
        commitSlot
    );
    const proposedEvent: BlockProposedEvent = (
        proposeReceipt.events as any[]
    ).find((e) => e.event === "BlockProposed");
    return { proposedEvent, proposeReceipt, commitReceipt, commit, block };
};

export { generateCommitHash, commitBlock, commitAndProposeLatestBlock };
