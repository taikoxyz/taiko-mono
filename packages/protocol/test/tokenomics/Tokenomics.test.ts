import { expect } from "chai";
import { BigNumber, ethers } from "ethers";
import { ethers as hardhatEthers } from "hardhat";
import { TaikoL1, TaikoL2 } from "../../typechain";
import { TestTkoToken } from "../../typechain/TestTkoToken";
import deployAddressManager from "../utils/addressManager";
import Proposer from "../utils/proposer";
// import Prover from "../utils/prover";
import {
    getDefaultL2Signer,
    getL1Provider,
    getL2Provider,
} from "../utils/provider";
import createAndSeedWallets from "../utils/seed";
import sleep from "../utils/sleep";
import { defaultFeeBase, deployTaikoL1 } from "../utils/taikoL1";
import { deployTaikoL2 } from "../utils/taikoL2";
import deployTkoToken from "../utils/tkoToken";
import { onNewL2Block, sendTinyEtherToZeroAddress } from "./utils";

describe("tokenomics", function () {
    let taikoL1: TaikoL1;
    let taikoL2: TaikoL2;
    let l1Provider: ethers.providers.JsonRpcProvider;
    let l2Provider: ethers.providers.JsonRpcProvider;
    let l1Signer: any;
    let l2Signer: any;
    let proposerSigner: any;
    let proverSigner: any;
    let genesisHeight: number;
    let genesisHash: string;
    let tkoTokenL1: TestTkoToken;

    beforeEach(async () => {
        l1Provider = getL1Provider();

        l1Provider.pollingInterval = 100;

        const signers = await hardhatEthers.getSigners();
        l1Signer = signers[0];

        l2Provider = getL2Provider();

        l2Signer = await getDefaultL2Signer();

        const l2AddressManager = await deployAddressManager(l2Signer);
        taikoL2 = await deployTaikoL2(l2Signer, l2AddressManager, false);

        genesisHash = taikoL2.deployTransaction.blockHash as string;
        genesisHeight = taikoL2.deployTransaction.blockNumber as number;

        const l1AddressManager = await deployAddressManager(l1Signer);
        taikoL1 = await deployTaikoL1(
            l1AddressManager,
            genesisHash,
            true,
            defaultFeeBase
        );
        const { chainId } = await l1Provider.getNetwork();

        [proposerSigner, proverSigner] = await createAndSeedWallets(
            2,
            l1Signer
        );

        tkoTokenL1 = await deployTkoToken(
            l1Signer,
            l1AddressManager,
            taikoL1.address
        );

        await l1AddressManager.setAddress(
            `${chainId}.tko_token`,
            tkoTokenL1.address
        );

        const { chainId: l2ChainId } = await l2Provider.getNetwork();

        await l1AddressManager.setAddress(
            `${l2ChainId}.taiko`,
            taikoL2.address
        );

        await l1AddressManager.setAddress(
            `${chainId}.proof_verifier`,
            taikoL1.address
        );

        await tkoTokenL1
            .connect(l1Signer)
            .mintAnyone(
                await proposerSigner.getAddress(),
                ethers.utils.parseEther("100")
            );

        expect(
            await tkoTokenL1.balanceOf(await proposerSigner.getAddress())
        ).to.be.eq(ethers.utils.parseEther("100"));

        // set up interval mining so we always get new blocks
        await l2Provider.send("evm_setAutomine", [true]);

        // send transactions to L1 so we always get new blocks
        setInterval(
            async () => await sendTinyEtherToZeroAddress(l1Signer),
            1 * 1000
        );

        const tx = await l2Signer.sendTransaction({
            to: proverSigner.address,
            value: ethers.utils.parseUnits("1", "ether"),
        });
        await tx.wait(1);
    });

    it("proposes blocks on interval, blockFee should increase, proposer's balance for TKOToken should decrease as it pays proposer fee, proofReward should increase since slots are growing and no proofs have been submitted", async function () {
        const { maxNumBlocks, commitConfirmations } = await taikoL1.getConfig();
        // wait for one period of halving to occur, so fee is not 0.
        const blockIdsToNumber: any = {};

        // set up a proposer to continually propose new blocks
        const proposer = new Proposer(
            taikoL1.connect(proposerSigner),
            l2Provider,
            commitConfirmations.toNumber(),
            maxNumBlocks.toNumber(),
            0
        );

        // get the initiaal tkoBalance, which should decrease every block proposal
        let lastProposerTkoBalance = await tkoTokenL1.balanceOf(
            await proposerSigner.getAddress()
        );

        // do the same for the blockFee, which should increase every block proposal
        // with proofs not being submitted.
        let lastBlockFee = await taikoL1.getBlockFee();
        while (lastBlockFee.eq(0)) {
            await sleep(500);
            lastBlockFee = await taikoL1.getBlockFee();
        }

        let lastProofReward = BigNumber.from(0);

        let hasFailedAssertions: boolean = false;
        // every time a l2 block is created, we should try to propose it on L1.
        l2Provider.on("block", async (blockNumber) => {
            if (blockNumber <= genesisHeight) return;
            try {
                const { newProposerTkoBalance, newBlockFee, newProofReward } =
                    await onNewL2Block(
                        l2Provider,
                        blockNumber,
                        proposer,
                        blockIdsToNumber,
                        taikoL1,
                        proposerSigner,
                        tkoTokenL1
                    );

                expect(
                    newProposerTkoBalance.lt(lastProposerTkoBalance)
                ).to.be.eq(true);
                expect(newBlockFee.gt(lastBlockFee)).to.be.eq(true);
                expect(newProofReward.gt(lastProofReward)).to.be.eq(true);

                lastBlockFee = newBlockFee;
                lastProofReward = newProofReward;
                lastProposerTkoBalance = newProposerTkoBalance;
            } catch (e) {
                hasFailedAssertions = true;
                console.error(e);
                throw e;
            }
        });

        await sleep(20 * 1000);
        expect(hasFailedAssertions).to.be.eq(false);
    });

    it("block fee should increase as the halving period passes, while no blocks are proposed", async function () {
        const { bootstrapDiscountHalvingPeriod } = await taikoL1.getConfig();

        const iterations: number = 5;
        const period: number = bootstrapDiscountHalvingPeriod
            .mul(1000)
            .toNumber();

        let lastBlockFee: BigNumber = await taikoL1.getBlockFee();

        for (let i = 0; i < iterations; i++) {
            await sleep(period);
            const blockFee = await taikoL1.getBlockFee();
            expect(blockFee.gt(lastBlockFee)).to.be.eq(true);
            lastBlockFee = blockFee;
        }
    });

    it("expects the blockFee to go be 0 when no periods have passed", async function () {
        const blockFee = await taikoL1.getBlockFee();
        expect(blockFee.eq(0)).to.be.eq(true);
    });

    // it("propose blocks and prove blocks on interval, proverReward should decline and blockFee should increase", async function () {
    //     const { maxNumBlocks, commitConfirmations } = await taikoL1.getConfig();
    //     const blockIdsToNumber: any = {};

    //     const proposer = new Proposer(
    //         taikoL1.connect(proposerSigner),
    //         l2Provider,
    //         commitConfirmations.toNumber(),
    //         maxNumBlocks.toNumber(),
    //         0
    //     );

    //     const prover = new Prover(
    //         taikoL1,
    //         taikoL2,
    //         l1Provider,
    //         l2Provider,
    //         proverSigner
    //     );

    //     let hasFailedAssertions: boolean = false;
    //     l2Provider.on("block", async (blockNumber) => {
    //         if (blockNumber <= genesisHeight) return;
    //         try {
    //             await expect(
    //                 onNewL2Block(
    //                     l2Provider,
    //                     blockNumber,
    //                     proposer,
    //                     blockIdsToNumber,
    //                     taikoL1,
    //                     proposerSigner,
    //                     tkoTokenL1
    //                 )
    //             ).not.to.throw;
    //         } catch (e) {
    //             hasFailedAssertions = true;
    //             console.error(e);
    //             throw e;
    //         }
    //     });

    //     taikoL1.on(
    //         "BlockProposed",
    //         async (id: BigNumber, meta: BlockMetadata) => {
    //             console.log("proving block: id", id.toString());
    //             try {
    //                 await prover.prove(
    //                     await proverSigner.getAddress(),
    //                     id.toNumber(),
    //                     blockIdsToNumber[id.toString()],
    //                     meta
    //                 );
    //             } catch (e) {
    //                 hasFailedAssertions = true;
    //                 console.error(e);
    //                 throw e;
    //             }
    //         }
    //     );

    //     await sleep(20 * 1000);

    //     expect(hasFailedAssertions).to.be.eq(false);
    // });
});
