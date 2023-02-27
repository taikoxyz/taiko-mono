import { expect } from "chai";
import { SimpleChannel } from "channel-ts";
import { ethers } from "ethers";
import { TaikoL1 } from "../../typechain";
import { TestTaikoToken } from "../../typechain/TestTaikoToken";
import { pickRandomElement } from "../utils/array";
import blockListener from "../utils/blockListener";
import { initIntegrationFixture } from "../utils/fixture";
import Proposer from "../utils/proposer";
import Prover from "../utils/prover";
import { createAndSeedWallets, seedTko } from "../utils/seed";
import { commitProposeProveAndVerify } from "../utils/verify";

describe("tokenomic----s: proofReward", function () {
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
            const balanceBefore = await taikoTokenL1.balanceOf(
                await prover.getSigner().address
            );

            await commitProposeProveAndVerify(
                taikoL1,
                l2Provider,
                blockNumber,
                proposer,
                taikoTokenL1,
                prover
            );

            let balanceAfter = await taikoTokenL1.balanceOf(
                await prover.getSigner().address
            );

            expect(balanceAfter).to.be.eq(balanceBefore);

            const tx = await taikoL1
                .connect(prover.getSigner())
                .withdrawBalance();
            await tx.wait();

            balanceAfter = await taikoTokenL1.balanceOf(
                await prover.getSigner().address
            );

            expect(balanceAfter).to.be.gt(balanceBefore);
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
            const proverBalanceBefore = await taikoTokenL1.balanceOf(
                await prover.getSigner().getAddress()
            );

            const proposerBalanceBefore = await taikoTokenL1.balanceOf(
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

            const proposerBalanceAfter = await taikoTokenL1.balanceOf(
                await proposer.getSigner().getAddress()
            );

            expect(proposerBalanceAfter).to.be.lt(proposerBalanceBefore);

            let proverBalanceAfter = await taikoTokenL1.balanceOf(
                await prover.getSigner().getAddress()
            );
            expect(proverBalanceAfter).to.be.eq(proverBalanceBefore);

            const tx = await taikoL1
                .connect(prover.getSigner())
                .withdrawBalance();
            await tx.wait();

            proverBalanceAfter = await taikoTokenL1.balanceOf(
                await prover.getSigner().getAddress()
            );
            expect(proverBalanceAfter).to.be.gt(proverBalanceBefore);
        }
    });
});
