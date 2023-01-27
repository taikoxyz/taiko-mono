import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { TaikoL1, TkoToken } from "../../typechain";
import { BlockVerifiedEvent } from "../../typechain/LibVerifying";
import { BlockInfo } from "./block_metadata";
import sleep from "./sleep";

async function verifyBlocks(taikoL1: TaikoL1, maxBlocks: number) {
    const verifyTx = await taikoL1.verifyBlocks(maxBlocks);
    const verifyReceipt = await verifyTx.wait(1);
    const verifiedEvent: BlockVerifiedEvent = (
        verifyReceipt.events as any[]
    ).find((e) => e.event === "BlockVerified");
    return verifiedEvent;
}

async function sleepUntilBlockIsVerifiable(
    taikoL1: TaikoL1,
    id: number,
    provenAt: number
) {
    const delay = await taikoL1.getUncleProofDelay(id);
    const delayInMs = delay.mul(1000);
    await sleep(5 * delayInMs.toNumber()); // TODO: use provenAt, calc difference, etc
}

async function verifyBlockAndAssert(
    taikoL1: TaikoL1,
    tkoTokenL1: TkoToken,
    block: BlockInfo,
    lastProofReward: BigNumber,
    compareHeaders: boolean = false
): Promise<{ newProofReward: BigNumber }> {
    await sleepUntilBlockIsVerifiable(taikoL1, block.id, block.provenAt);

    const isVerifiable = await taikoL1.isBlockVerifiable(
        block.id,
        block.parentHash
    );

    expect(isVerifiable).to.be.eq(true);

    // dont verify first blocks parent hash, because we arent "real L2" in these
    // tests, the parent hash will be wrong.
    // if (compareHeaders) {
    //     const latestHash = await taikoL1.getLatestSyncedHeader();
    //     expect(latestHash).to.be.eq(block.parentHash);
    // }
    const prover = block.forkChoice.provers[0];

    const proverTkoBalanceBeforeVerification = await tkoTokenL1.balanceOf(
        prover
    );

    const proposerTkoBalanceBeforeVerification = await tkoTokenL1.balanceOf(
        block.proposer
    );

    expect(proposerTkoBalanceBeforeVerification.gt(0)).to.be.eq(true);
    const verifiedEvent = await verifyBlocks(taikoL1, 1);
    expect(verifiedEvent).to.be.not.undefined;

    expect(verifiedEvent.args.blockHash).to.be.eq(block.blockHash);
    expect(verifiedEvent.args.id.eq(block.id)).to.be.eq(true);

    const proverTkoBalanceAfterVerification = await tkoTokenL1.balanceOf(
        prover
    );

    // prover should have increased in balance as he received the proof reward.
    expect(
        proverTkoBalanceAfterVerification.gt(proverTkoBalanceBeforeVerification)
    ).to.be.eq(true);

    const newProofReward = await taikoL1.getProofReward(
        block.proposedAt,
        block.provenAt
    );

    // last proof reward should be larger than the new proof reward,
    // since we have stopped proposing, and slots are growing as we verify.
    if (lastProofReward.gt(0)) {
        expect(newProofReward).to.be.lt(lastProofReward);
    }

    // latest synced header should be our just-verified block hash.
    const latestHash = await taikoL1.getLatestSyncedHeader();
    expect(latestHash).to.be.eq(block.blockHash);

    // fork choice should be nullified via _cleanUp in LibVerifying
    const forkChoice = await taikoL1.getForkChoice(block.id, block.parentHash);
    expect(forkChoice.provenAt).to.be.eq(BigNumber.from(0));
    expect(forkChoice.provers).to.be.empty;
    expect(forkChoice.blockHash).to.be.eq(ethers.constants.HashZero);

    // proposer should be minted their refund of their deposit back after
    // verification, as long as their balance is > 0;
    return { newProofReward };
}

export { verifyBlocks, verifyBlockAndAssert, sleepUntilBlockIsVerifiable };
