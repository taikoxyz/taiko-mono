import { BigNumber, ethers } from "ethers";
import { TaikoL1, TaikoToken } from "../../typechain";
import Proposer from "./proposer";
import sleep from "./sleep";

// onNewL2Block should be called from a tokenomics test case when a new block
// is generated from the l2Provider.
// It will propose the block to the TaikoL1 contract,
// and then return the latest fee information and the proposal event,
// which can then be asserted on depending on your test case.
async function onNewL2Block(
    l2Provider: ethers.providers.JsonRpcProvider,
    blockNumber: number,
    proposer: Proposer,
    taikoL1: TaikoL1,
    proposerSigner: any,
    taikoTokenL1: TaikoToken
) {
    const config = await taikoL1.getConfig();

    const block = await l2Provider.getBlock(blockNumber);
    const { proposedEvent } = await proposer.proposeBlock(block);
    const { id, meta } = proposedEvent.args;

    const { enableTokenomics } = await taikoL1.getConfig();

    const newProofReward = await taikoL1.getProofReward(
        new Date().getMilliseconds(),
        meta.timestamp,
        id
    );

    const newProposerBalance = enableTokenomics
        ? await taikoTokenL1.balanceOf(await proposerSigner.getAddress())
        : BigNumber.from(0);

    await sleep(1000 * config.bootstrapDiscountHalvingPeriod.toNumber());
    const newBlockFee = await taikoL1.getBlockFee();

    console.log("-------------------proposed----------", id);

    return {
        proposedEvent,
        newProposerBalance,
        newBlockFee,
        newProofReward,
    };
}

export { onNewL2Block };
