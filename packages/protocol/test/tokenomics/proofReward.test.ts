import { expect } from "chai";
import { BigNumber, ethers } from "ethers";
import { TaikoL1, TaikoL2 } from "../../typechain";
import { BlockProvenEvent } from "../../typechain/LibProving";
import { TestTkoToken } from "../../typechain/TestTkoToken";
import { BlockMetadata } from "../utils/block_metadata";
import Proposer from "../utils/proposer";
import Prover from "../utils/prover";
// import Prover from "../utils/prover";

import sleep from "../utils/sleep";
import verifyBlocks from "../utils/verify";
import {
    BlockInfo,
    initTokenomicsFixture,
    onNewL2Block,
    sleepUntilBlockIsVerifiable,
} from "./utils";

describe("tokenomics: proofReward", function () {
    let taikoL1: TaikoL1;
    let taikoL2: TaikoL2;
    let l1Provider: ethers.providers.JsonRpcProvider;
    let l2Provider: ethers.providers.JsonRpcProvider;
    let l1Signer: any;
    let proposerSigner: any;
    let proverSigner: any;
    let genesisHeight: number;
    let tkoTokenL1: TestTkoToken;
    let interval: any;

    beforeEach(async () => {
        ({
            taikoL1,
            taikoL2,
            l1Provider,
            l2Provider,
            l1Signer,
            proposerSigner,
            proverSigner,
            genesisHeight,
            tkoTokenL1,
            interval,
        } = await initTokenomicsFixture());
    });

    afterEach(() => clearInterval(interval));

    it(`proofReward is 1 wei if the prover does not hold any tkoTokens on L1`, async function () {
        const { maxNumBlocks, commitConfirmations } = await taikoL1.getConfig();
        const blockIdsToNumber: any = {};

        const proposer = new Proposer(
            taikoL1.connect(proposerSigner),
            l2Provider,
            commitConfirmations.toNumber(),
            maxNumBlocks.toNumber(),
            0
        );

        const prover = new Prover(
            taikoL1,
            taikoL2,
            l1Provider,
            l2Provider,
            proverSigner
        );

        let hasFailedAssertions: boolean = false;
        let blocksProposed: number = 0;

        const listener = async (blockNumber: number) => {
            if (blockNumber <= genesisHeight) return;
            if (blocksProposed === 1) {
                l2Provider.off("block", listener);
                return;
            }

            try {
                await expect(
                    onNewL2Block(
                        l2Provider,
                        blockNumber,
                        proposer,
                        blockIdsToNumber,
                        taikoL1,
                        proposerSigner,
                        tkoTokenL1
                    )
                ).not.to.throw;
                blocksProposed++;
            } catch (e) {
                hasFailedAssertions = true;
                l2Provider.off("block", listener);
                console.error(e);
                throw e;
            }
        };

        l2Provider.on("block", listener);

        let blockInfo!: BlockInfo;

        taikoL1.on(
            "BlockProposed",
            async (id: BigNumber, meta: BlockMetadata) => {
                /* eslint-disable-next-line */
                while (blocksProposed < 1) {
                    await sleep(3 * 1000);
                }
                try {
                    const event: BlockProvenEvent = await prover.prove(
                        await proverSigner.getAddress(),
                        id.toNumber(),
                        blockIdsToNumber[id.toString()],
                        meta
                    );

                    const proposedBlock = await taikoL1.getProposedBlock(id);

                    const forkChoice = await taikoL1.getForkChoice(
                        id.toNumber(),
                        event.args.parentHash
                    );

                    blockInfo = {
                        proposedAt: proposedBlock.proposedAt.toNumber(),
                        provenAt: event.args.provenAt.toNumber(),
                        id: event.args.id.toNumber(),
                        parentHash: event.args.parentHash,
                        blockHash: event.args.blockHash,
                        forkChoice: forkChoice,
                    };
                } catch (e) {
                    hasFailedAssertions = true;
                    console.error("proving error", e);
                    throw e;
                }
            }
        );

        expect(hasFailedAssertions).to.be.eq(false);

        // wait for block to be proven asynchronously.

        /* eslint-disable-next-line */
        while (!blockInfo) {
            await sleep(1 * 1000);
        }

        // make sure block is verifiable before we processe
        await sleepUntilBlockIsVerifiable(
            taikoL1,
            blockInfo.id,
            blockInfo.provenAt
        );

        const isVerifiable = await taikoL1.isBlockVerifiable(
            blockInfo.id,
            blockInfo.parentHash
        );
        expect(isVerifiable).to.be.eq(true);
        const proverTkoBalanceBeforeVerification = await tkoTokenL1.balanceOf(
            blockInfo.forkChoice.provers[0]
        );
        expect(proverTkoBalanceBeforeVerification.eq(0)).to.be.eq(true);
        await verifyBlocks(taikoL1, 1);

        const proverTkoBalanceAfterVerification = await tkoTokenL1.balanceOf(
            blockInfo.forkChoice.provers[0]
        );

        // prover should have given given 1 TKO token, since they
        // held no TKO balance.
        expect(proverTkoBalanceAfterVerification.eq(1)).to.be.eq(true);
    });

    it(`propose blocks, wait til maxNumBlocks is filled.
    proverReward should decline should increase as blocks are proved then verified.
    the provers TKO balance should increase as the blocks are verified and
    they receive the proofReward.`, async function () {
        const { maxNumBlocks, commitConfirmations } = await taikoL1.getConfig();
        const blockIdsToNumber: any = {};

        const proposer = new Proposer(
            taikoL1.connect(proposerSigner),
            l2Provider,
            commitConfirmations.toNumber(),
            maxNumBlocks.toNumber(),
            0
        );

        // prover needs TKO or their reward will be cut down to 1 wei.
        await tkoTokenL1
            .connect(l1Signer)
            .mintAnyone(
                await proverSigner.getAddress(),
                ethers.utils.parseEther("100")
            );

        const prover = new Prover(
            taikoL1,
            taikoL2,
            l1Provider,
            l2Provider,
            proverSigner
        );

        let hasFailedAssertions: boolean = false;
        let blocksProposed: number = 0;

        const listener = async (blockNumber: number) => {
            if (blockNumber <= genesisHeight) return;
            // fill up all slots.
            if (blocksProposed === maxNumBlocks.toNumber()) {
                l2Provider.off("block", listener);
                return;
            }

            try {
                await expect(
                    onNewL2Block(
                        l2Provider,
                        blockNumber,
                        proposer,
                        blockIdsToNumber,
                        taikoL1,
                        proposerSigner,
                        tkoTokenL1
                    )
                ).not.to.throw;
                blocksProposed++;
            } catch (e) {
                hasFailedAssertions = true;
                l2Provider.off("block", listener);
                console.error(e);
                throw e;
            }
        };

        l2Provider.on("block", listener);

        let blocksProved: number = 0;

        const blockInfo: BlockInfo[] = [];

        taikoL1.on(
            "BlockProposed",
            async (id: BigNumber, meta: BlockMetadata) => {
                // wait until we fill up all slots, so we can
                // then prove blocks in order, and each time a block is proven then verified,
                // we can expect the proofReward to go down as slots become available.

                console.log("p", id.toNumber());
                while (blocksProposed < maxNumBlocks.toNumber()) {
                    await sleep(3 * 1000);
                }

                try {
                    const proverAddress = await proverSigner.getAddress();
                    const { args } = await prover.prove(
                        await proverSigner.getAddress(),
                        id.toNumber(),
                        blockIdsToNumber[id.toString()],
                        meta
                    );
                    const {
                        blockHash,
                        id: blockId,
                        parentHash,
                        provenAt,
                    } = args;

                    const proposedBlock = await taikoL1.getProposedBlock(id);

                    const forkChoice = await taikoL1.getForkChoice(
                        blockId.toNumber(),
                        parentHash
                    );

                    expect(forkChoice.blockHash).to.be.eq(blockHash);

                    expect(forkChoice.provers[0]).to.be.eq(proverAddress);

                    blockInfo.push({
                        proposedAt: proposedBlock.proposedAt.toNumber(),
                        provenAt: provenAt.toNumber(),
                        id: id.toNumber(),
                        parentHash: parentHash,
                        blockHash: blockHash,
                        forkChoice: forkChoice,
                    });
                    blocksProved++;
                } catch (e) {
                    hasFailedAssertions = true;
                    console.error("proving error", e);
                    throw e;
                }
            }
        );

        // wait for all blocks to be proven
        /* eslint-disable-next-line */
        while (blocksProved < maxNumBlocks.toNumber() - 1) {
            await sleep(3 * 1000);
        }

        expect(hasFailedAssertions).to.be.eq(false);

        let lastProofReward: BigNumber = BigNumber.from(0);

        // now try to verify the blocks and make sure the proof reward shrinks as slots
        // free up
        for (let i = 1; i < blockInfo.length + 1; i++) {
            const block = blockInfo.find((b) => b.id === i) as any as BlockInfo;
            expect(block).not.to.be.undefined;

            await sleepUntilBlockIsVerifiable(
                taikoL1,
                block.id,
                block.provenAt
            );

            const isVerifiable = await taikoL1.isBlockVerifiable(
                block.id,
                block.parentHash
            );

            expect(isVerifiable).to.be.eq(true);

            // dont verify first blocks parent hash, because we arent "real L2" in these
            // tests, the parent hash will be wrong.
            if (i > 1) {
                const latestHash = await taikoL1.getLatestSyncedHeader();
                expect(latestHash).to.be.eq(block.parentHash);
            }
            const prover = block.forkChoice.provers[0];

            const proverTkoBalanceBeforeVerification =
                await tkoTokenL1.balanceOf(prover);

            const verifiedEvent = await verifyBlocks(taikoL1, 1);
            expect(verifiedEvent).to.be.not.undefined;

            expect(verifiedEvent.args.blockHash).to.be.eq(block.blockHash);
            expect(verifiedEvent.args.id.eq(block.id)).to.be.eq(true);

            const proverTkoBalanceAfterVerification =
                await tkoTokenL1.balanceOf(prover);

            expect(
                proverTkoBalanceAfterVerification.gt(
                    proverTkoBalanceBeforeVerification
                )
            ).to.be.eq(true);

            const newProofReward = await taikoL1.getProofReward(
                block.proposedAt,
                block.provenAt
            );

            if (lastProofReward.gt(0)) {
                expect(newProofReward).to.be.lt(lastProofReward);
            }
            lastProofReward = newProofReward;

            const latestHash = await taikoL1.getLatestSyncedHeader();
            expect(latestHash).to.be.eq(block.blockHash);
        }
    });
});
