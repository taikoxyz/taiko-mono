import { expect } from "chai";
import { BigNumber, ethers } from "ethers";
import { ethers as hardhatEthers } from "hardhat";
import {
    AddressManager,
    ConfigManager,
    TaikoL1,
    TaikoL2,
} from "../../typechain";
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
import { BlockInfo, onNewL2Block, sendTinyEtherToZeroAddress } from "./utils";

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
    let l1AddressManager: AddressManager;
    let interval: any;

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

        l1AddressManager = await deployAddressManager(l1Signer);
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

        await (
            await l1AddressManager.setAddress(
                `${chainId}.tko_token`,
                tkoTokenL1.address
            )
        ).wait(1);

        const { chainId: l2ChainId } = await l2Provider.getNetwork();

        await (
            await l1AddressManager.setAddress(
                `${l2ChainId}.taiko`,
                taikoL2.address
            )
        ).wait(1);

        await (
            await l1AddressManager.setAddress(
                `${chainId}.proof_verifier`,
                taikoL1.address
            )
        ).wait(1);

        const configManager: ConfigManager = await (
            await hardhatEthers.getContractFactory("ConfigManager")
        )
            .connect(l1Signer)
            .deploy();
        await configManager.deployed();

        await l1AddressManager.setAddress(
            `${chainId}.config_manager`,
            configManager.address
        );

        const mintTx = await tkoTokenL1
            .connect(l1Signer)
            .mintAnyone(
                await proposerSigner.getAddress(),
                ethers.utils.parseEther("100")
            );

        await mintTx.wait(1);

        expect(
            await tkoTokenL1.balanceOf(await proposerSigner.getAddress())
        ).to.be.eq(ethers.utils.parseEther("100"));

        // set up interval mining so we always get new blocks
        await l2Provider.send("evm_setAutomine", [true]);

        // send transactions to L1 so we always get new blocks
        interval = setInterval(
            async () => await sendTinyEtherToZeroAddress(l1Signer),
            1 * 1000
        );

        const tx = await l2Signer.sendTransaction({
            to: proverSigner.address,
            value: ethers.utils.parseUnits("1", "ether"),
        });
        await tx.wait(1);
    });

    afterEach(() => clearInterval(interval));

    it("expects the blockFee to go be 0 when no periods have passed", async function () {
        // deploy a new instance of TaikoL1 so no blocks have passed.
        const tL1 = await deployTaikoL1(l1AddressManager, genesisHash, true);
        const blockFee = await tL1.getBlockFee();
        expect(blockFee.eq(0)).to.be.eq(true);
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
        l2Provider.on("block", async (blockNumber: number) => {
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
        l2Provider.off("block");
        expect(hasFailedAssertions).to.be.eq(false);
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

        l2Provider.on("block", async (blockNumber) => {
            if (blockNumber <= genesisHeight) return;
            // fill up all slots.
            if (blocksProposed === maxNumBlocks.toNumber()) {
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
                l2Provider.off("block");
                console.error(e);
                throw e;
            }
        });

        let blocksProved: number = 0;

        const blockInfo: BlockInfo[] = [];

        taikoL1.on(
            "BlockProposed",
            async (id: BigNumber, meta: BlockMetadata) => {
                // wait until we fill up all slots, so we can
                // then prove blocks in order, and each time a block is proven then verified,
                // we can expect the proofReward to go down as slots become available.
                while (blocksProposed < maxNumBlocks.toNumber()) {
                    await sleep(3 * 1000);
                }

                try {
                    const proverAddress = await proverSigner.getAddress();
                    const blockProvenEvent: BlockProvenEvent =
                        await prover.prove(
                            await proverSigner.getAddress(),
                            id.toNumber(),
                            blockIdsToNumber[id.toString()],
                            meta
                        );

                    const proposedBlock = await taikoL1.getProposedBlock(id);

                    const forkChoice = await taikoL1.getForkChoice(
                        blockProvenEvent.args.id.toNumber(),
                        blockProvenEvent.args.parentHash
                    );

                    expect(forkChoice.blockHash).to.be.eq(
                        blockProvenEvent.args.blockHash
                    );

                    expect(forkChoice.provers[0]).to.be.eq(proverAddress);

                    await sleep(5 * 1000);
                    const isVerifiable = await taikoL1.isBlockVerifiable(
                        blockProvenEvent.args.id.toNumber(),
                        blockProvenEvent.args.parentHash
                    );

                    expect(isVerifiable).to.be.eq(true);
                    blockInfo.push({
                        proposedAt: proposedBlock.proposedAt.toNumber(),
                        provenAt: blockProvenEvent.args.provenAt.toNumber(),
                        id: blockProvenEvent.args.id.toNumber(),
                        parentHash: blockProvenEvent.args.parentHash,
                        blockHash: blockProvenEvent.args.blockHash,
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

        expect(hasFailedAssertions).to.be.eq(false);

        // wait for all blocks to be proven
        /* eslint-disable-next-line */
        while (blocksProved < maxNumBlocks.toNumber() - 1) {
            await sleep(3 * 1000);
        }
        console.log("ready to verify");

        let lastProofReward: BigNumber = BigNumber.from(0);

        // now try to verify the blocks and make sure the proof reward shrinks as slots
        // free up
        for (let i = 1; i < blockInfo.length + 1; i++) {
            const block = blockInfo.find((b) => b.id === i) as any as BlockInfo;
            expect(block).not.to.be.undefined;
            console.log("verifying block", block);

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
            console.log("block ", block.id, "verified!");
        }
    });

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

        l2Provider.on("block", async (blockNumber) => {
            if (blockNumber <= genesisHeight) return;
            if (blocksProposed === 1) {
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
                l2Provider.off("block");
                console.error(e);
                throw e;
            }
        });

        let blockInfo!: BlockInfo;

        taikoL1.on(
            "BlockProposed",
            async (id: BigNumber, meta: BlockMetadata) => {
                if (hasFailedAssertions) return;
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
                        blockInfo.id,
                        blockInfo.parentHash
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
        while (
            !(await taikoL1.isBlockVerifiable(
                blockInfo.id,
                blockInfo.parentHash
            ))
        ) {
            await sleep(2 * 1000);
        }

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
});
