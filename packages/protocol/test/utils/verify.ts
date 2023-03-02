import { expect } from "chai";
import { BigNumber, ethers as ethersLib } from "ethers";
import { ethers } from "hardhat";
import { TaikoL1, TaikoToken } from "../../typechain";
import { BlockVerifiedEvent } from "../../typechain/LibVerifying";
import { BlockInfo, BlockMetadata } from "./block_metadata";
import { onNewL2Block } from "./onNewL2Block";
import Proposer from "./proposer";
import Prover from "./prover";
import { getDefaultL1Signer } from "./provider";
import { sendTinyEtherToZeroAddress } from "./seed";

async function verifyBlocks(taikoL1: TaikoL1, maxBlocks: number) {
    // Since we are connecting to a geth node with clique consensus (auto mine), we
    // need to manually mine a new block here to ensure the latest block.timestamp increased as expected when
    // calling eth_estimateGas.
    await sendTinyEtherToZeroAddress(await getDefaultL1Signer());

    const verifyTx = await taikoL1.verifyBlocks(maxBlocks, {
        gasLimit: 1000000,
    });

    const verifyReceipt = await verifyTx.wait(1);
    const verifiedEvent: BlockVerifiedEvent = (
        verifyReceipt.events as any[]
    ).find((e) => e.event === "BlockVerified");
    return verifiedEvent;
}

async function verifyBlockAndAssert(
    taikoL1: TaikoL1,
    taikoTokenL1: TaikoToken,
    block: BlockInfo,
    lastProofReward: BigNumber
): Promise<{ newProofReward: BigNumber }> {
    const prover = block.forkChoice.provers[0];

    const proverBalanceBeforeVerification = await taikoTokenL1.balanceOf(
        prover
    );

    const proposerBalanceBeforeVerification = await taikoTokenL1.balanceOf(
        block.proposer
    );

    expect(proposerBalanceBeforeVerification.gt(0)).to.be.true;
    const verifiedEvent = await verifyBlocks(taikoL1, 1);
    expect(verifiedEvent).to.be.not.undefined;

    expect(verifiedEvent.args.blockHash).to.be.eq(block.blockHash);
    expect(verifiedEvent.args.id.eq(block.id)).to.be.true;

    const proverBalanceAfterVerification = await taikoTokenL1.balanceOf(prover);

    // prover should have increased in balance as he received the proof reward.
    expect(proverBalanceAfterVerification.gt(proverBalanceBeforeVerification))
        .to.be.true;

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

async function proposeProveAndVerify(
    taikoL1: TaikoL1,
    l2Provider: ethersLib.providers.JsonRpcProvider,
    blockNumber: number,
    proposer: Proposer,
    taikoTokenL1: TaikoToken,
    prover: Prover
) {
    console.log("proposing", blockNumber);
    const { proposedEvent } = await onNewL2Block(
        l2Provider,
        blockNumber,
        proposer,
        taikoL1,
        proposer.getSigner(),
        taikoTokenL1
    );
    expect(proposedEvent).not.to.be.undefined;

    console.log("proving", blockNumber);
    const provedEvent = await prover.prove(
        proposedEvent.args.id.toNumber(),
        blockNumber,
        proposedEvent.args.meta as any as BlockMetadata
    );

    const { args } = provedEvent;
    const { blockHash, id: blockId, parentHash } = args;

    const proposedBlock = await taikoL1.getProposedBlock(
        proposedEvent.args.id.toNumber()
    );

    const forkChoice = await taikoL1.getForkChoice(
        blockId.toNumber(),
        parentHash
    );

    expect(forkChoice.blockHash).to.be.eq(blockHash);

    expect(forkChoice.prover).to.be.eq(await prover.getSigner().getAddress());

    console.log("verifying", blockNumber);
    const verifyEvent = await verifyBlocks(taikoL1, 1);
    expect(verifyEvent).not.to.be.eq(undefined);
    console.log("verified", blockNumber);

    return { verifyEvent, proposedEvent, provedEvent, proposedBlock };
}

export { verifyBlocks, verifyBlockAndAssert, proposeProveAndVerify };
