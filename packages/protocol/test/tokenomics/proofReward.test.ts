import { expect } from "chai";
import { BigNumber, ethers } from "ethers";
import { TaikoL1 } from "../../typechain";
import { BlockProposedEvent } from "../../typechain/LibProposing";
import { BlockProvenEvent } from "../../typechain/LibProving";
import { TestTkoToken } from "../../typechain/TestTkoToken";
import { BlockMetadata } from "../utils/block_metadata";
import Proposer from "../utils/proposer";
import Prover from "../utils/prover";
import createAndSeedWallets from "../utils/seed";
import sleep from "../utils/sleep";
import verifyBlocks from "../utils/verify";
import {
    BlockInfo,
    initTokenomicsFixture,
    onNewL2Block,
    randEle,
    sleepUntilBlockIsVerifiable,
    verifyBlockAndAssert,
} from "./utils";

describe("tokenomics: proofReward", function () {
    let taikoL1: TaikoL1;
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
            0,
            proposerSigner
        );

        const prover = new Prover(taikoL1, l2Provider, proverSigner);

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
                        deposit: proposedBlock.deposit,
                        proposer: proposedBlock.proposer,
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

    it(`single prover, single proposer.
    propose blocks, wait til maxNumBlocks is filled.
    proverReward should decline should increase as blocks are proved then verified.
    the provers TKO balance should increase as the blocks are verified and
    they receive the proofReward.
    the proposer should receive a refund on his deposit because he holds a tkoBalance > 0 at time of verification.`, async function () {
        const { maxNumBlocks, commitConfirmations } = await taikoL1.getConfig();
        const blockIdsToNumber: any = {};

        const proposer = new Proposer(
            taikoL1.connect(proposerSigner),
            l2Provider,
            commitConfirmations.toNumber(),
            maxNumBlocks.toNumber(),
            0,
            proposerSigner
        );

        const prover = new Prover(taikoL1, l2Provider, proverSigner);

        // prover needs TKO or their reward will be cut down to 1 wei.
        await (
            await tkoTokenL1
                .connect(l1Signer)
                .mintAnyone(
                    await proverSigner.getAddress(),
                    ethers.utils.parseEther("100")
                )
        ).wait(1);

        let hasFailedAssertions: boolean = false;
        const blocksProposed: BlockProposedEvent[] = [];

        const listener = async (blockNumber: number) => {
            if (blockNumber <= genesisHeight) return;
            // fill up all slots.
            if (blocksProposed.length === maxNumBlocks.toNumber() - 1) {
                l2Provider.off("block", listener);
                return;
            }

            try {
                const { proposedEvent } = await onNewL2Block(
                    l2Provider,
                    blockNumber,
                    proposer,
                    blockIdsToNumber,
                    taikoL1,
                    proposerSigner,
                    tkoTokenL1
                );
                expect(proposedEvent).not.to.be.undefined;
                blocksProposed.push(proposedEvent);

                console.log("proposed", proposedEvent.args.id);
            } catch (e) {
                hasFailedAssertions = true;
                l2Provider.off("block", listener);
                console.error(e);
                throw e;
            }
        };

        l2Provider.on("block", listener);

        while (blocksProposed.length < maxNumBlocks.toNumber() - 1) {
            await sleep(3 * 1000);
        }

        expect(hasFailedAssertions).to.be.eq(false);

        const provedBlocks: BlockInfo[] = [];

        await Promise.all(
            blocksProposed.map(async (block) => {
                const proverAddress = await proverSigner.getAddress();
                const { args } = await prover.prove(
                    await proverSigner.getAddress(),
                    block.args.id.toNumber(),
                    blockIdsToNumber[block.args.id.toString()],
                    block.args.meta as any as BlockMetadata
                );
                const { blockHash, id: blockId, parentHash, provenAt } = args;

                const proposedBlock = await taikoL1.getProposedBlock(
                    block.args.id.toNumber()
                );

                console.log("proposed block", proposedBlock);

                const forkChoice = await taikoL1.getForkChoice(
                    blockId.toNumber(),
                    parentHash
                );

                expect(forkChoice.blockHash).to.be.eq(blockHash);

                expect(forkChoice.provers[0]).to.be.eq(proverAddress);

                provedBlocks.push({
                    proposedAt: proposedBlock.proposedAt.toNumber(),
                    provenAt: provenAt.toNumber(),
                    id: block.args.id.toNumber(),
                    parentHash: parentHash,
                    blockHash: blockHash,
                    forkChoice: forkChoice,
                    deposit: proposedBlock.deposit,
                    proposer: proposedBlock.proposer,
                });
            })
        );

        // wait for all blocks to be proven
        /* eslint-disable-next-line */
        while (provedBlocks.length < maxNumBlocks.toNumber() - 1) {
            await sleep(3 * 1000);
        }

        let lastProofReward: BigNumber = BigNumber.from(0);

        // now try to verify the blocks and make sure the proof reward shrinks as slots
        // free up
        for (let i = 0; i < provedBlocks.length; i++) {
            const block = provedBlocks[i];
            expect(block).not.to.be.undefined;
            console.log("verifying blocks", block);

            const { newProofReward } = await verifyBlockAndAssert(
                taikoL1,
                tkoTokenL1,
                block,
                lastProofReward,
                i > 0
            );
            lastProofReward = newProofReward;
        }
    });

    it(`multiple provers, multiple proposers.
    propose blocks, wait til maxNumBlocks is filled.
    proverReward should decline should increase as blocks are proved then verified.
    the provers TKO balance should increase as the blocks are verified and
    they receive the proofReward.
    the proposer should receive a refund on his deposit because he holds a tkoBalance > 0 at time of verification.`, async function () {
        const { maxNumBlocks, commitConfirmations } = await taikoL1.getConfig();
        const blockIdsToNumber: any = {};

        const proposers = (await createAndSeedWallets(3, l1Signer)).map(
            (p: ethers.Wallet) =>
                new Proposer(
                    taikoL1.connect(p),
                    l2Provider,
                    commitConfirmations.toNumber(),
                    maxNumBlocks.toNumber(),
                    0,
                    p
                )
        );

        const provers = (await createAndSeedWallets(3, l1Signer)).map(
            (p: ethers.Wallet) => new Prover(taikoL1, l2Provider, p)
        );

        for (const prover of provers) {
            await (
                await tkoTokenL1
                    .connect(l1Signer)
                    .mintAnyone(
                        await prover.getSigner().getAddress(),
                        ethers.utils.parseEther("10000")
                    )
            ).wait(1);
        }
        for (const proposer of proposers) {
            await (
                await tkoTokenL1
                    .connect(l1Signer)
                    .mintAnyone(
                        await proposer.getSigner().getAddress(),
                        ethers.utils.parseEther("10000")
                    )
            ).wait(1);
        }
        let hasFailedAssertions: boolean = false;
        const blocksProposed: BlockProposedEvent[] = [];

        const listener = async (blockNumber: number) => {
            if (blockNumber <= genesisHeight) return;
            // fill up all slots.
            if (blocksProposed.length === maxNumBlocks.toNumber() - 1) {
                l2Provider.off("block", listener);
                return;
            }

            try {
                const { proposedEvent } = await onNewL2Block(
                    l2Provider,
                    blockNumber,
                    randEle<Proposer>(proposers),
                    blockIdsToNumber,
                    taikoL1,
                    proposerSigner,
                    tkoTokenL1
                );
                expect(proposedEvent).not.to.be.undefined;
                blocksProposed.push(proposedEvent);

                console.log("proposed", proposedEvent.args.id);
            } catch (e) {
                hasFailedAssertions = true;
                l2Provider.off("block", listener);
                console.error(e);
                throw e;
            }
        };

        l2Provider.on("block", listener);

        while (blocksProposed.length < maxNumBlocks.toNumber() - 1) {
            await sleep(3 * 1000);
        }

        expect(hasFailedAssertions).to.be.eq(false);

        const provedBlocks: BlockInfo[] = [];

        for (const block of blocksProposed) {
            const proverAddress = await proverSigner.getAddress();
            const { args } = await randEle<Prover>(provers).prove(
                await proverSigner.getAddress(),
                block.args.id.toNumber(),
                blockIdsToNumber[block.args.id.toString()],
                block.args.meta as any as BlockMetadata
            );
            const { blockHash, id: blockId, parentHash, provenAt } = args;

            const proposedBlock = await taikoL1.getProposedBlock(
                block.args.id.toNumber()
            );

            console.log("proposed block", proposedBlock);

            const forkChoice = await taikoL1.getForkChoice(
                blockId.toNumber(),
                parentHash
            );

            expect(forkChoice.blockHash).to.be.eq(blockHash);

            expect(forkChoice.provers[0]).to.be.eq(proverAddress);

            provedBlocks.push({
                proposedAt: proposedBlock.proposedAt.toNumber(),
                provenAt: provenAt.toNumber(),
                id: block.args.id.toNumber(),
                parentHash: parentHash,
                blockHash: blockHash,
                forkChoice: forkChoice,
                deposit: proposedBlock.deposit,
                proposer: proposedBlock.proposer,
            });
        }

        // wait for all blocks to be proven
        /* eslint-disable-next-line */
        while (provedBlocks.length < maxNumBlocks.toNumber() - 1) {
            await sleep(3 * 1000);
        }

        let lastProofReward: BigNumber = BigNumber.from(0);

        // now try to verify the blocks and make sure the proof reward shrinks as slots
        // free up
        for (let i = 0; i < provedBlocks.length; i++) {
            const block = provedBlocks[i];
            console.log("proving block", block);
            expect(block).not.to.be.undefined;

            const { newProofReward } = await verifyBlockAndAssert(
                taikoL1,
                tkoTokenL1,
                block,
                lastProofReward,
                i > 0
            );
            lastProofReward = newProofReward;
        }
    });
});
