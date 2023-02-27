import { expect } from "chai";
import { SimpleChannel } from "channel-ts";
import { ethers } from "ethers";
import { TaikoL1 } from "../../typechain";
import { TestTaikoToken } from "../../typechain/TestTaikoToken";
import { pickRandomElement } from "../utils/array";
import blockListener from "../utils/blockListener";
// import { BlockMetadata } from "../utils/block_metadata";
import { initIntegrationFixture } from "../utils/fixture";
import Proposer from "../utils/proposer";
import Prover from "../utils/prover";
import { createAndSeedWallets, seedTko } from "../utils/seed";
import {
    commitProposeProveAndVerify,
    // sleepUntilBlockIsVerifiable,
    // verifyBlocks,
} from "../utils/verify";

describe("tokenomics: proofReward", function () {
    let taikoL1: TaikoL1;
    let l2Provider: ethers.providers.JsonRpcProvider;
    let l1Signer: any;
    let proverSigner: any;
    let genesisHeight: number;
    let taikoTokenL1: TestTaikoToken;
    let interval: any;
    let chan: SimpleChannel<number>;
    let proposer: Proposer;
    let prover: Prover;

    /* eslint-disable-next-line */
    let config: Awaited<ReturnType<TaikoL1["getConfig"]>>;

    beforeEach(async () => {
        ({
            taikoL1,
            l2Provider,
            l1Signer,
            proverSigner,
            genesisHeight,
            taikoTokenL1,
            interval,
            chan,
            config,
            proposer,
            prover,
        } = await initIntegrationFixture(true, true));
    });

    afterEach(() => {
        clearInterval(interval);
        l2Provider.off("block");
        chan.close();
    });

    it(`proofReward is 1 wei if the prover does not hold any taikoTokens on L1`, async function () {
        let proposed: boolean = false;
        l2Provider.on("block", function () {
            if (proposed) {
                chan.close();
                l2Provider.off("block");
                return;
            }
            proposed = true;

            chan.send(genesisHeight + 1);
        });

        /* eslint-disable-next-line */
        for await (const blockNumber of chan) {
            const proverTkoBalanceBeforeVerification =
                await taikoTokenL1.balanceOf(await prover.getSigner().address);

            await commitProposeProveAndVerify(
                taikoL1,
                l2Provider,
                blockNumber,
                proposer,
                taikoTokenL1,
                prover
            );

            const proverTkoBalanceAfterVerification =
                await taikoTokenL1.balanceOf(await prover.getSigner().address);

            // prover should have given 1 TKO token, since they
            // held no TKO balance.
            expect(proverTkoBalanceAfterVerification.sub(1)).to.be.eq(
                proverTkoBalanceBeforeVerification
            );
        }
    });

    it(`single prover, single proposer.
    propose blocks, wait til maxNumBlocks is filled.
    proverReward should decline should increase as blocks are proved then verified.
    the provers TKO balance should increase as the blocks are verified and
    they receive the proofReward.
    the proposer should receive a refund on his deposit because he holds a tkoBalance > 0 at time of verification.`, async function () {
        // prover needs TKO or their reward will be cut down to 1 wei.

        await seedTko([prover], taikoTokenL1.connect(l1Signer));

        l2Provider.on("block", blockListener(chan, genesisHeight));

        /* eslint-disable-next-line */
        for await (const blockNumber of chan) {
            if (
                blockNumber >
                genesisHeight + (config.maxNumBlocks.toNumber() - 1)
            ) {
                break;
            }
            const proverTkoBalanceBeforeVerification =
                await taikoTokenL1.balanceOf(await prover.getSigner().address);

            await commitProposeProveAndVerify(
                taikoL1,
                l2Provider,
                blockNumber,
                proposer,
                taikoTokenL1,
                prover
            );

            const proverTkoBalanceAfterVerification =
                await taikoTokenL1.balanceOf(await prover.getSigner().address);

            expect(
                proverTkoBalanceAfterVerification.gt(
                    proverTkoBalanceBeforeVerification
                )
            ).to.be.eq(true);
        }
    });

    it(`multiple provers, multiple proposers.
    propose blocks, wait til maxNumBlocks is filled.
    proverReward should decline should increase as blocks are proved then verified.
    the provers TKO balance should increase as the blocks are verified and
    they receive the proofReward.
    the proposer should receive a refund on his deposit because he holds a tkoBalance > 0 at time of verification.`, async function () {
        const proposers = (await createAndSeedWallets(3, l1Signer)).map(
            (p: ethers.Wallet) =>
                new Proposer(
                    taikoL1.connect(p),
                    l2Provider,
                    config.commitConfirmations.toNumber(),
                    config.maxNumBlocks.toNumber(),
                    0,
                    p
                )
        );

        const provers = (await createAndSeedWallets(3, l1Signer)).map(
            (p: ethers.Wallet) => new Prover(taikoL1, l2Provider, p)
        );

        await seedTko(provers, taikoTokenL1.connect(l1Signer));

        await seedTko(proposers, taikoTokenL1.connect(l1Signer));

        // prover needs TKO or their reward will be cut down to 1 wei.
        await (
            await taikoTokenL1
                .connect(l1Signer)
                .mintAnyone(
                    await proverSigner.getAddress(),
                    ethers.utils.parseEther("100")
                )
        ).wait(1);

        l2Provider.on("block", blockListener(chan, genesisHeight));

        /* eslint-disable-next-line */
        for await (const blockNumber of chan) {
            if (
                blockNumber >
                genesisHeight + (config.maxNumBlocks.toNumber() - 1)
            ) {
                break;
            }
            const prover = pickRandomElement<Prover>(provers);
            const proposer = pickRandomElement<Proposer>(proposers);
            const proverTkoBalanceBefore = await taikoTokenL1.balanceOf(
                await prover.getSigner().getAddress()
            );

            const proposerTkoBalanceBefore = await taikoTokenL1.balanceOf(
                await proposer.getSigner().getAddress()
            );

            await commitProposeProveAndVerify(
                taikoL1,
                l2Provider,
                blockNumber,
                proposer,
                taikoTokenL1,
                prover
            );

            const proverTkoBalanceAfter = await taikoTokenL1.balanceOf(
                await prover.getSigner().getAddress()
            );

            const proposerTkoBalanceAfter = await taikoTokenL1.balanceOf(
                await proposer.getSigner().getAddress()
            );

            expect(proposerTkoBalanceAfter.lt(proposerTkoBalanceBefore));

            expect(proverTkoBalanceAfter.gt(proverTkoBalanceBefore)).to.be.eq(
                true
            );
        }
    });

    // it(`asserts that with N provers, where N is config.maxProofsPerForkChoice all provers who submit proofs are paid with decreasing weight from the first prover to the Nth`, async function () {
    //     const provers = (
    //         await createAndSeedWallets(
    //             config.maxProofsPerForkChoice.toNumber(),
    //             l1Signer
    //         )
    //     ).map((p: ethers.Wallet) => new Prover(taikoL1, l2Provider, p));

    //     await seedTko(provers, taikoTokenL1.connect(l1Signer));

    //     const blockNumber = genesisHeight + 1;

    //     const block = await l2Provider.getBlock(blockNumber);

    //     // commit and propose block, so our provers can prove it.
    //     const { proposedEvent } = await proposer.commitThenProposeBlock(block);

    //     // submit a proof for each prover
    //     for (const prover of provers) {
    //         await prover.prove(
    //             proposedEvent.args.id.toNumber(),
    //             blockNumber,
    //             proposedEvent.args.meta as any as BlockMetadata
    //         );
    //     }

    //     const forkChoice = await taikoL1.getForkChoice(
    //         proposedEvent.args.id.toNumber(),
    //         block.parentHash
    //     );
    //     expect(forkChoice).not.to.be.undefined;
    //     expect(forkChoice.provers.length).to.be.eq(
    //         config.maxProofsPerForkChoice.toNumber()
    //     );

    //     await sleepUntilBlockIsVerifiable(
    //         taikoL1,
    //         proposedEvent.args.id.toNumber(),
    //         0
    //     );
    //     await verifyBlocks(taikoL1, 1);

    //     // all provers had same initial TKO balance.
    //     // each prover in order should have less balance than the previous.
    //     for (let i = 0; i < forkChoice.provers.length; i++) {
    //         if (i !== 0) {
    //             const proverBalance = await taikoTokenL1.balanceOf(
    //                 forkChoice.provers[i]
    //             );
    //             const previousProverBalance = await taikoTokenL1.balanceOf(
    //                 forkChoice.provers[i - 1]
    //             );

    //             expect(previousProverBalance.gt(proverBalance)).to.be.eq(true);
    //         }
    //     }
    // });
});
