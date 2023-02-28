import { expect } from "chai";
import { SimpleChannel } from "channel-ts";
import { ethers } from "ethers";
import { TaikoL1 } from "../../typechain";
import { TestTaikoToken } from "../../typechain/TestTaikoToken";
import blockListener from "../utils/blockListener";
import { initIntegrationFixture } from "../utils/fixture";
import Proposer from "../utils/proposer";
import Prover from "../utils/prover";
import { seedTko } from "../utils/seed";
import { commitProposeProveAndVerify } from "../utils/verify";

describe("tokenomics: proofReward", function () {
    let taikoL1: TaikoL1;
    let l2Provider: ethers.providers.JsonRpcProvider;
    let l1Signer: any;
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

            const { provedEvent, proposedBlock, verifyEvent } =
                await commitProposeProveAndVerify(
                    taikoL1,
                    l2Provider,
                    blockNumber,
                    proposer,
                    taikoTokenL1,
                    prover
                );

            expect(verifyEvent).not.to.be.undefined;

            const proofReward = await taikoL1.getProofReward(
                provedEvent.args.provenAt,
                proposedBlock.proposedAt
            );

            // proof reward can be 0. make sure there is a proof reward first
            if (proofReward.gt(0)) {
                const rewardBalance = await taikoL1.getRewardBalance(
                    await prover.getSigner().getAddress()
                );

                expect(rewardBalance.gt(0)).to.be.eq(true);

                // rewardBalance can be 1, and withdrawBalance only withdrawals is balance > 1.
                // make sure we have a valid reward balance waiting to be withdrawn
                // before comparing balances.
                if (rewardBalance.gt(1)) {
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
            }
        }
    });
});
