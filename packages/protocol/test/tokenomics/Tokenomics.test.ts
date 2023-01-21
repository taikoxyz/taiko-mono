import { expect } from "chai";
import { BigNumber, ethers } from "ethers";
import { ethers as hardhatEthers } from "hardhat";
import { ConfigManager, TaikoL1, TaikoL2 } from "../../typechain";
import { BlockProvenEvent } from "../../typechain/LibProving";
import { TestTkoToken } from "../../typechain/TestTkoToken";
import deployAddressManager from "../utils/addressManager";
import { BlockMetadata } from "../utils/block_metadata";
import Proposer from "../utils/proposer";
import Prover from "../utils/prover";
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
import verifyBlocks from "../utils/verify";
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

        const configManager: ConfigManager = await (
            await hardhatEthers.getContractFactory("ConfigManager")
        )
            .connect(l1Signer)
            .deploy();

        await l1AddressManager.setAddress(
            `${chainId}.config_manager`,
            configManager.address
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

    it("expects the blockFee to go be 0 when no periods have passed", async function () {
        const blockFee = await taikoL1.getBlockFee();
        expect(blockFee.eq(0)).to.be.eq(true);
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

    it.only(`propose blocks, wait til maxNumBlocks is filled.
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

        const prover = new Prover(
            taikoL1,
            taikoL2,
            l1Provider,
            l2Provider,
            proverSigner
        );

        let hasFailedAssertions: boolean = false;
        let blocksProposed: number = 0;

        l2Provider.on("block", async (blockNumber) => {
            if (blockNumber <= genesisHeight) return;
            // fill up all slots.
            if (blocksProposed === maxNumBlocks.toNumber()) {
                console.log("max blocks proposed!");
                l2Provider.off("block");
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
                console.error(e);
                throw e;
            }
        });

        let blocksProved: number = 0;

        type BlockInfo = {
            proposedAt: number;
            provenAt: number;
            id: number;
            parentHash: string;
        };

        const blockInfo: BlockInfo[] = [];

        taikoL1.on(
            "BlockProposed",
            async (id: BigNumber, meta: BlockMetadata) => {
                console.log("proving block: id", id.toString());

                // wait until we fill up all slots, so we can
                // then prove blocks in order, and each time a block is proven then verified,
                // we can expect the proofReward to go down as slots become available.
                while (blocksProposed < maxNumBlocks.toNumber()) {
                    await sleep(3 * 1000);
                }
                console.log("ready to prove");
                try {
                    const event: BlockProvenEvent = await prover.prove(
                        await proverSigner.getAddress(),
                        id.toNumber(),
                        blockIdsToNumber[id.toString()],
                        meta
                    );

                    const delay = await taikoL1.getUncleProofDelay(
                        event.args.id
                    );

                    console.log(
                        "block proven",
                        event.args.id,
                        "parent hash",
                        event.args.parentHash,
                        "delay:",
                        delay.toNumber()
                    );

                    const proposedBlock = await taikoL1.getProposedBlock(id);

                    blockInfo.push({
                        proposedAt: proposedBlock.proposedAt.toNumber(),
                        provenAt: event.args.provenAt.toNumber(),
                        id: event.args.id.toNumber(),
                        parentHash: event.args.parentHash,
                    });
                    blocksProved++;
                } catch (e) {
                    hasFailedAssertions = true;
                    console.error("proving error", e);
                    throw e;
                }
            }
        );

        expect(hasFailedAssertions).to.be.eq(false);

        // wait for all blocks to be proven
        /* eslint-disable-next-line */
        while (blocksProved < maxNumBlocks.toNumber() - 1) {
            await sleep(1 * 1000);
        }

        let lastProofReward: BigNumber = BigNumber.from(0);

        // now try to verify the blocks and make sure the proof reward shrinks as slots
        // free up
        for (let i = 1; i < blockInfo.length + 1; i++) {
            await sleep(30 * 1000);
            console.log("verifying block", i);
            const block = blockInfo.find((b) => b.id === i) as any as BlockInfo;
            expect(block).not.to.be.undefined;

            const isVerifiable = await taikoL1.isBlockVerifiable(
                block.id,
                block.parentHash
            );
            console.log("block id ", block.id, "isVerifiable:", isVerifiable);
            expect(isVerifiable).to.be.eq(true);

            // verify blocks 1 by 1
            const latestL2hash = await taikoL1.getLatestSyncedHeader();
            console.log("latest synced header", latestL2hash);

            const forkChoice = await taikoL1.getForkChoice(
                block.id,
                block.parentHash
            );

            const prover = forkChoice.provers[0];

            const proverTkoBalanceBeforeVerification =
                await tkoTokenL1.balanceOf(prover);

            let stateVariables = await taikoL1.getStateVariables();
            console.log(
                "latest verified block id",
                stateVariables[8].toNumber()
            );

            const verifiedEvent = await verifyBlocks(taikoL1, 5);
            expect(verifiedEvent).to.be.not.undefined;

            console.log("block verified", verifiedEvent.args.id);

            stateVariables = await taikoL1.getStateVariables();
            console.log(
                "latest verified block id after verification",
                stateVariables[8].toNumber()
            );

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
        }
    });
});
