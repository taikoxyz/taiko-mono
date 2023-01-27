import { expect } from "chai";
import { BigNumber, ethers } from "ethers";
import EventEmitter from "events";
import { TaikoL1 } from "../../typechain";
import { TestTkoToken } from "../../typechain/TestTkoToken";
import { randEle } from "../utils/array";
import { BlockInfo } from "../utils/block_metadata";
import { BLOCK_PROPOSED_EVENT, BLOCK_PROVEN_EVENT } from "../utils/event";
import { newProposerListener } from "../utils/propose";
import Proposer from "../utils/proposer";
import { newProverListener } from "../utils/prove";
import Prover from "../utils/prover";
import createAndSeedWallets from "../utils/seed";
import sleep from "../utils/sleep";
import {
    sleepUntilBlockIsVerifiable,
    verifyBlockAndAssert,
    verifyBlocks,
} from "../utils/verify";
import { initTokenomicsFixture } from "./utils";

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

        let failedAssertion: Error | null = null;

        const eventEmitter = new EventEmitter();

        l2Provider.on(
            "block",
            newProposerListener(
                genesisHeight,
                eventEmitter,
                l2Provider,
                proposer,
                taikoL1,
                tkoTokenL1
            )
        );

        eventEmitter.on(
            BLOCK_PROPOSED_EVENT,
            newProverListener(prover, taikoL1, eventEmitter)
        );

        eventEmitter.on("error", (e: Error) => (failedAssertion = e));

        let blocksVerified: number = 0;

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
                blocksVerified++;
            }
        );

        /* eslint-disable-next-line */
        while (blocksVerified < 1) {
            expect(failedAssertion).to.be.null;
            await sleep(3 * 1000);
        }

        expect(failedAssertion).to.be.null;
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

        let failedAssertion: Error | null = null;

        const eventEmitter = new EventEmitter();
        eventEmitter.on("error", (e: Error) => (failedAssertion = e));

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

        l2Provider.on(
            "block",
            newProposerListener(
                genesisHeight,
                eventEmitter,
                l2Provider,
                proposer,
                taikoL1,
                tkoTokenL1
            )
        );

        eventEmitter.on(
            BLOCK_PROPOSED_EVENT,
            newProverListener(prover, taikoL1, eventEmitter)
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
            expect(failedAssertion).to.be.null;
            await sleep(3 * 1000);
        }
        expect(failedAssertion).to.be.null;
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

        const eventEmitter = new EventEmitter();

        let failedAssertion: Error | null = null;
        eventEmitter.on("error", (e: Error) => (failedAssertion = e));
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

        l2Provider.on(
            "block",
            newProposerListener(
                genesisHeight,
                eventEmitter,
                l2Provider,
                randEle<Proposer>(proposers),
                taikoL1,
                tkoTokenL1
            )
        );

        eventEmitter.on(
            BLOCK_PROPOSED_EVENT,
            newProverListener(randEle<Prover>(provers), taikoL1, eventEmitter)
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
            expect(failedAssertion).to.be.null;
            await sleep(2 * 1000);
        }
        expect(failedAssertion).to.be.null;
    });
});
