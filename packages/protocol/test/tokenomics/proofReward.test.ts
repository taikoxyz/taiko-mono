import { expect } from "chai";
import { BigNumber, ethers } from "ethers";
import EventEmitter from "events";
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
    BLOCK_PROPOSED_EVENT,
    BLOCK_PROVEN_EVENT,
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

        const proposer = new Proposer(
            taikoL1.connect(proposerSigner),
            l2Provider,
            commitConfirmations.toNumber(),
            maxNumBlocks.toNumber(),
            0,
            proposerSigner
        );

        const prover = new Prover(taikoL1, l2Provider, proverSigner);

        const eventEmitter = new EventEmitter();
        l2Provider.on("block", async (blockNumber: number) => {
            if (blockNumber <= genesisHeight) return;

            const { proposedEvent } = await onNewL2Block(
                l2Provider,
                blockNumber,
                proposer,
                taikoL1,
                proposerSigner,
                tkoTokenL1
            );
            expect(proposedEvent).not.to.be.undefined;

            eventEmitter.emit(BLOCK_PROPOSED_EVENT, proposedEvent, blockNumber);
        });

        eventEmitter.on(
            BLOCK_PROPOSED_EVENT,
            async (
                proposedBlockEvent: BlockProposedEvent,
                blockNumber: number
            ) => {
                const event: BlockProvenEvent = await prover.prove(
                    await proverSigner.getAddress(),
                    proposedBlockEvent.args.id.toNumber(),
                    blockNumber,
                    proposedBlockEvent.args.meta as any
                );

                const proposedBlock = await taikoL1.getProposedBlock(
                    proposedBlockEvent.args.id.toNumber()
                );

                const forkChoice = await taikoL1.getForkChoice(
                    proposedBlockEvent.args.id.toNumber(),
                    event.args.parentHash
                );

                const blockInfo = {
                    proposedAt: proposedBlock.proposedAt.toNumber(),
                    provenAt: event.args.provenAt.toNumber(),
                    id: event.args.id.toNumber(),
                    parentHash: event.args.parentHash,
                    blockHash: event.args.blockHash,
                    forkChoice: forkChoice,
                    deposit: proposedBlock.deposit,
                    proposer: proposedBlock.proposer,
                };

                eventEmitter.emit(BLOCK_PROVEN_EVENT, blockInfo);
            }
        );

        eventEmitter.on(
            BLOCK_PROVEN_EVENT,
            async function (blockInfo: BlockInfo) {
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
                const proverTkoBalanceBeforeVerification =
                    await tkoTokenL1.balanceOf(blockInfo.forkChoice.provers[0]);
                expect(proverTkoBalanceBeforeVerification.eq(0)).to.be.eq(true);

                await verifyBlocks(taikoL1, 1);

                const proverTkoBalanceAfterVerification =
                    await tkoTokenL1.balanceOf(blockInfo.forkChoice.provers[0]);

                // prover should have given given 1 TKO token, since they
                // held no TKO balance.
                expect(proverTkoBalanceAfterVerification.eq(1)).to.be.eq(true);
            }
        );
    });

    it(`single prover, single proposer.
    propose blocks, wait til maxNumBlocks is filled.
    proverReward should decline should increase as blocks are proved then verified.
    the provers TKO balance should increase as the blocks are verified and
    they receive the proofReward.
    the proposer should receive a refund on his deposit because he holds a tkoBalance > 0 at time of verification.`, async function () {
        const { maxNumBlocks, commitConfirmations } = await taikoL1.getConfig();

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

        const eventEmitter = new EventEmitter();
        l2Provider.on("block", async (blockNumber: number) => {
            if (blockNumber <= genesisHeight) return;

            const { proposedEvent } = await onNewL2Block(
                l2Provider,
                blockNumber,
                proposer,
                taikoL1,
                proposerSigner,
                tkoTokenL1
            );
            expect(proposedEvent).not.to.be.undefined;

            console.log("proposed", proposedEvent.args.id);
            eventEmitter.emit(BLOCK_PROPOSED_EVENT, proposedEvent, blockNumber);
        });

        eventEmitter.on(
            BLOCK_PROPOSED_EVENT,
            async function (
                proposedEvent: BlockProposedEvent,
                blockNumber: number
            ) {
                const proverAddress = await proverSigner.getAddress();
                const { args } = await prover.prove(
                    await proverSigner.getAddress(),
                    proposedEvent.args.id.toNumber(),
                    blockNumber,
                    proposedEvent.args.meta as any as BlockMetadata
                );
                const { blockHash, id: blockId, parentHash, provenAt } = args;

                const proposedBlock = await taikoL1.getProposedBlock(
                    proposedEvent.args.id.toNumber()
                );

                console.log("proposed block", proposedBlock);

                const forkChoice = await taikoL1.getForkChoice(
                    blockId.toNumber(),
                    parentHash
                );

                expect(forkChoice.blockHash).to.be.eq(blockHash);

                expect(forkChoice.provers[0]).to.be.eq(proverAddress);

                const provedBlock = {
                    proposedAt: proposedBlock.proposedAt.toNumber(),
                    provenAt: provenAt.toNumber(),
                    id: proposedEvent.args.id.toNumber(),
                    parentHash: parentHash,
                    blockHash: blockHash,
                    forkChoice: forkChoice,
                    deposit: proposedBlock.deposit,
                    proposer: proposedBlock.proposer,
                };

                eventEmitter.emit(BLOCK_PROVEN_EVENT, provedBlock);
            }
        );

        let lastProofReward: BigNumber = BigNumber.from(0);
        let blocksVerified: number = 0;

        eventEmitter.on(BLOCK_PROVEN_EVENT, async function (block: BlockInfo) {
            console.log("verifying blocks", block);

            const { newProofReward } = await verifyBlockAndAssert(
                taikoL1,
                tkoTokenL1,
                block,
                lastProofReward,
                block.id > 1
            );
            lastProofReward = newProofReward;
            blocksVerified++;
        });

        while (blocksVerified < maxNumBlocks.toNumber() - 1) {
            await sleep(3 * 1000);
        }
    });

    it(`multiple provers, multiple proposers.
    propose blocks, wait til maxNumBlocks is filled.
    proverReward should decline should increase as blocks are proved then verified.
    the provers TKO balance should increase as the blocks are verified and
    they receive the proofReward.
    the proposer should receive a refund on his deposit because he holds a tkoBalance > 0 at time of verification.`, async function () {
        const { maxNumBlocks, commitConfirmations } = await taikoL1.getConfig();

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

        const eventEmitter = new EventEmitter();

        l2Provider.on("block", async (blockNumber: number) => {
            if (blockNumber <= genesisHeight) return;

            const { proposedEvent } = await onNewL2Block(
                l2Provider,
                blockNumber,
                randEle<Proposer>(proposers),
                taikoL1,
                proposerSigner,
                tkoTokenL1
            );
            expect(proposedEvent).not.to.be.undefined;

            console.log("proposed", proposedEvent.args.id);
            eventEmitter.emit(BLOCK_PROPOSED_EVENT, proposedEvent, blockNumber);
        });

        eventEmitter.on(
            BLOCK_PROPOSED_EVENT,
            async function (
                proposedEvent: BlockProposedEvent,
                blockNumber: number
            ) {
                const proverAddress = await proverSigner.getAddress();
                const { args } = await randEle<Prover>(provers).prove(
                    await proverSigner.getAddress(),
                    proposedEvent.args.id.toNumber(),
                    blockNumber,
                    proposedEvent.args.meta as any as BlockMetadata
                );
                const { blockHash, id: blockId, parentHash, provenAt } = args;

                const proposedBlock = await taikoL1.getProposedBlock(
                    proposedEvent.args.id.toNumber()
                );

                const forkChoice = await taikoL1.getForkChoice(
                    blockId.toNumber(),
                    parentHash
                );

                expect(forkChoice.blockHash).to.be.eq(blockHash);

                expect(forkChoice.provers[0]).to.be.eq(proverAddress);

                const provedBlock = {
                    proposedAt: proposedBlock.proposedAt.toNumber(),
                    provenAt: provenAt.toNumber(),
                    id: proposedEvent.args.id.toNumber(),
                    parentHash: parentHash,
                    blockHash: blockHash,
                    forkChoice: forkChoice,
                    deposit: proposedBlock.deposit,
                    proposer: proposedBlock.proposer,
                };

                eventEmitter.emit(BLOCK_PROVEN_EVENT, provedBlock);
            }
        );

        let lastProofReward: BigNumber = BigNumber.from(0);

        let blocksVerified: number = 0;
        eventEmitter.on(
            BLOCK_PROVEN_EVENT,
            async function (provedBlock: BlockInfo) {
                console.log("proving block", provedBlock);

                const { newProofReward } = await verifyBlockAndAssert(
                    taikoL1,
                    tkoTokenL1,
                    provedBlock,
                    lastProofReward,
                    provedBlock.id > 1
                );
                lastProofReward = newProofReward;
                blocksVerified++;
            }
        );

        while (blocksVerified < maxNumBlocks.toNumber() - 1) {
            console.log("blocks verified", blocksVerified);
            await sleep(2 * 1000);
        }
    });
});
