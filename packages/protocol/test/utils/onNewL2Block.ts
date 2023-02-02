import { BigNumber, ethers } from "ethers";
import { TaikoL1, TkoToken } from "../../typechain";
import { BlockProposedEvent } from "../../typechain/LibProposing";
import Proposer from "./proposer";

// onNewL2Block should be called from a tokenomics test case when a new block
// is generated from the l2Provider.
// It will commit then propose the block to the TaikoL1 contract,
// and then return the latest fee information and the proposal event,
// which can then be asserted on depending on your test case.
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

    const { enableTokenomics } = await taikoL1.getConfig();

    const newProofReward = await taikoL1.getProofReward(
        new Date().getMilliseconds(),
        meta.timestamp
    );

    const newProposerTkoBalance = enableTokenomics
        ? await tkoTokenL1.balanceOf(await proposerSigner.getAddress())
        : BigNumber.from(0);

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
