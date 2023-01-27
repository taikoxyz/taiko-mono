import { BigNumber, ethers } from "ethers";
import { TaikoL1, TkoToken } from "../../typechain";
import { BlockProposedEvent } from "../../typechain/LibProposing";
import Proposer from "./proposer";

async function onNewL2Block(
    l2Provider: ethers.providers.JsonRpcProvider,
    blockNumber: number,
    proposer: Proposer,
    taikoL1: TaikoL1,
    proposerSigner: any,
    tkoTokenL1: TkoToken
): Promise<{
    proposedEvent: BlockProposedEvent;
    newProposerTkoBalance: BigNumber;
    newBlockFee: BigNumber;
    newProofReward: BigNumber;
}> {
    const block = await l2Provider.getBlock(blockNumber);
    const receipt = await proposer.commitThenProposeBlock(block);
    const proposedEvent: BlockProposedEvent = (receipt.events as any[]).find(
        (e) => e.event === "BlockProposed"
    );

    const { id, meta } = proposedEvent.args;

    const newProofReward = await taikoL1.getProofReward(
        new Date().getMilliseconds(),
        meta.timestamp
    );

    const newProposerTkoBalance = await tkoTokenL1.balanceOf(
        await proposerSigner.getAddress()
    );

    const newBlockFee = await taikoL1.getBlockFee();

    console.log("-------------------proposed----------", id);

    return {
        proposedEvent,
        newProposerTkoBalance,
        newBlockFee,
        newProofReward,
    };
}

export { onNewL2Block };
