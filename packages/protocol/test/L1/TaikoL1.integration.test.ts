import { expect } from "chai";
import { BigNumber, ethers as ethersLib } from "ethers";
import { ethers } from "hardhat";
import { TaikoL1, TaikoL2 } from "../../typechain";
import deployAddressManager from "../utils/addressManager";
import { BlockMetadata } from "../utils/block_metadata";
import {
    commitAndProposeLatestBlock,
    commitBlock,
    generateCommitHash,
} from "../utils/commit";
import { buildProposeBlockInputs } from "../utils/propose";
import { proveBlock } from "../utils/prove";
import {
    getDefaultL2Signer,
    getL1Provider,
    getL2Provider,
} from "../utils/provider";
import { sendTinyEtherToZeroAddress } from "../utils/seed";
import { defaultFeeBase, deployTaikoL1 } from "../utils/taikoL1";
import { deployTaikoL2 } from "../utils/taikoL2";
import { SimpleChannel } from "channel-ts";
import { sleepUntilBlockIsVerifiable, verifyBlocks } from "../utils/verify";

describe("integration:TaikoL1", function () {
    let taikoL1: TaikoL1;
    let taikoL2: TaikoL2;
    let l2Provider: ethersLib.providers.JsonRpcProvider;
    let l2Signer: any;
    let l1Signer: any;

    beforeEach(async function () {
        l2Provider = getL2Provider();

        l2Signer = await getDefaultL2Signer();

        const l2AddressManager = await deployAddressManager(l2Signer);
        taikoL2 = await deployTaikoL2(l2Signer, l2AddressManager);

        const genesisHash = taikoL2.deployTransaction.blockHash as string;

        const l1Provider = getL1Provider();

        l1Provider.pollingInterval = 100;

        const signers = await ethers.getSigners();
        l1Signer = signers[0];

        const l1AddressManager = await deployAddressManager(l1Signer);

        taikoL1 = await deployTaikoL1(
            l1AddressManager,
            genesisHash,
            false,
            defaultFeeBase
        );

        const { chainId: l2ChainId } = await l2Provider.getNetwork();

        await l1AddressManager.setAddress(
            `${l2ChainId}.taiko`,
            taikoL2.address
        );

        const { chainId } = await l1Provider.getNetwork();

        await (
            await l1AddressManager.setAddress(
                `${chainId}.proof_verifier`,
                taikoL1.address
            )
        ).wait(1);
    });

    describe("getLatestSyncedHeader", function () {
        it.only("iterates through a round of blockHashHistory and is still able to get latestSyncedHeader", async function () {
            const { blockHashHistory, maxNumBlocks } =
                await taikoL1.getConfig();
            const chan = new SimpleChannel<number>();

            let numBlocksVerified: number = 0;
            let blocks: number = 0;
            /* eslint-disable-next-line */
            l2Provider.on("block", function (blockNumber: number) {
                if (blocks >= maxNumBlocks.toNumber()) {
                    chan.close();
                    l2Provider.off("block");
                    return;
                }
                blocks++;
                chan.send(blockNumber);
            });

            /* eslint-disable-next-line */
            for await (const blockNumber of chan) {
                if (numBlocksVerified > blockHashHistory.toNumber() + 1) {
                    return;
                }
                const { proposedEvent } = await commitAndProposeLatestBlock(
                    taikoL1,
                    l1Signer,
                    l2Provider,
                    0
                );

                const provenEvent = await proveBlock(
                    taikoL1,
                    l2Provider,
                    await l1Signer.getAddress(),
                    proposedEvent.args.id.toNumber(),
                    blockNumber,
                    proposedEvent.args.meta as any as BlockMetadata
                );

                await sleepUntilBlockIsVerifiable(
                    taikoL1,
                    proposedEvent.args.id.toNumber(),
                    provenEvent.args.provenAt.toNumber()
                );

                const verifiedEvent = await verifyBlocks(taikoL1, 1);
                expect(verifiedEvent).not.to.be.undefined;

                const latestSyncedHeader =
                    await taikoL1.getLatestSyncedHeader();
                expect(latestSyncedHeader).not.to.be.eq(
                    ethers.constants.HashZero
                );
                numBlocksVerified++;
            }
        });
    });

    describe("isCommitValid()", async function () {
        it("should not be valid if it has not been committed", async function () {
            const block = await l2Provider.getBlock("latest");
            const commit = generateCommitHash(block);

            const isCommitValid = await taikoL1.isCommitValid(
                1,
                1,
                commit.hash
            );

            expect(isCommitValid).to.be.eq(false);
        });

        it("should be valid if it has been committed", async function () {
            const { commitConfirmations } = await taikoL1.getConfig();
            const block = await l2Provider.getBlock("latest");
            const commitSlot = 0;
            const { commit, blockCommittedEvent } = await commitBlock(
                taikoL1,
                block,
                commitSlot
            );
            expect(blockCommittedEvent).not.to.be.undefined;

            for (let i = 0; i < commitConfirmations.toNumber(); i++) {
                await sendTinyEtherToZeroAddress(l1Signer);
            }

            const isCommitValid = await taikoL1.isCommitValid(
                commitSlot,
                blockCommittedEvent!.blockNumber,
                commit.hash
            );

            expect(isCommitValid).to.be.eq(true);
        });
    });

    describe("getProposedBlock()", function () {
        it("should revert if block is out of range and not a valid proposed block", async function () {
            await expect(taikoL1.getProposedBlock(123)).to.be.revertedWith(
                "L1:id"
            );
        });

        it("should return valid block if it's been commmited and proposed", async function () {
            const commitSlot = 0;
            const { proposedEvent } = await commitAndProposeLatestBlock(
                taikoL1,
                l1Signer,
                l2Provider,
                commitSlot
            );
            expect(proposedEvent).not.to.be.undefined;
            expect(proposedEvent.args.meta.commitSlot).to.be.eq(commitSlot);

            const proposedBlock = await taikoL1.getProposedBlock(
                proposedEvent.args.meta.id
            );
            expect(proposedBlock).not.to.be.undefined;
            expect(proposedBlock.proposer).to.be.eq(
                await l1Signer.getAddress()
            );
        });
    });

    describe("getForkChoice", function () {
        it("returns no empty fork choice for un-proposed, un-proven and un-verified block", async function () {
            const forkChoice = await taikoL1.getForkChoice(
                1,
                ethers.constants.HashZero
            );
            expect(forkChoice.blockHash).to.be.eq(ethers.constants.HashZero);
            expect(forkChoice.provenAt).to.be.eq(0);
        });

        it("returns populated data for submitted fork choice", async function () {
            const { proposedEvent, block } = await commitAndProposeLatestBlock(
                taikoL1,
                l1Signer,
                l2Provider,
                0
            );

            expect(proposedEvent).not.to.be.undefined;
            const proveEvent = await proveBlock(
                taikoL1,
                l2Provider,
                await l1Signer.getAddress(),
                proposedEvent.args.id.toNumber(),
                block.number,
                proposedEvent.args.meta as any as BlockMetadata
            );
            expect(proveEvent).not.to.be.undefined;

            const forkChoice = await taikoL1.getForkChoice(
                proposedEvent.args.id.toNumber(),
                block.parentHash
            );
            expect(forkChoice.blockHash).to.be.eq(block.hash);
            expect(forkChoice.provers[0]).to.be.eq(await l1Signer.getAddress());
        });
    });
    describe("commitBlock() -> proposeBlock() integration", async function () {
        it("should fail if a proposed block's placeholder field values are not default", async function () {
            const block = await l2Provider.getBlock("latest");
            const commitSlot = 0;
            const { tx, commit } = await commitBlock(
                taikoL1,
                block,
                commitSlot
            );

            const receipt = await tx.wait(1);

            const meta: BlockMetadata = {
                id: 1,
                l1Height: 0,
                l1Hash: ethers.constants.HashZero,
                beneficiary: block.miner,
                txListHash: commit.txListHash,
                mixHash: ethers.constants.HashZero,
                extraData: block.extraData,
                gasLimit: block.gasLimit,
                timestamp: 0,
                commitSlot: commitSlot,
                commitHeight: receipt.blockNumber as number,
            };

            const inputs = buildProposeBlockInputs(block, meta);

            await expect(taikoL1.proposeBlock(inputs)).to.be.revertedWith(
                "L1:placeholder"
            );
        });

        it("should revert with invalid gasLimit", async function () {
            const block = await l2Provider.getBlock("latest");
            const config = await taikoL1.getConfig();
            const gasLimit = config.blockMaxGasLimit;

            const { tx, commit } = await commitBlock(taikoL1, block);

            const receipt = await tx.wait(1);
            const meta: BlockMetadata = {
                id: 0,
                l1Height: 0,
                l1Hash: ethers.constants.HashZero,
                beneficiary: block.miner,
                txListHash: commit.txListHash,
                mixHash: ethers.constants.HashZero,
                extraData: block.extraData,
                gasLimit: gasLimit.add(1),
                timestamp: 0,
                commitSlot: 0,
                commitHeight: receipt.blockNumber as number,
            };

            const inputs = buildProposeBlockInputs(block, meta);

            await expect(taikoL1.proposeBlock(inputs)).to.be.revertedWith(
                "L1:gasLimit"
            );
        });

        it("should revert with invalid extraData", async function () {
            const block = await l2Provider.getBlock("latest");
            const { tx, commit } = await commitBlock(taikoL1, block);

            const meta: BlockMetadata = {
                id: 0,
                l1Height: 0,
                l1Hash: ethers.constants.HashZero,
                beneficiary: block.miner,
                txListHash: commit.txListHash,
                mixHash: ethers.constants.HashZero,
                extraData: ethers.utils.hexlify(ethers.utils.randomBytes(33)), // invalid extradata
                gasLimit: block.gasLimit,
                timestamp: 0,
                commitSlot: 0,
                commitHeight: tx.blockNumber as number,
            };

            const inputs = buildProposeBlockInputs(block, meta);

            await expect(taikoL1.proposeBlock(inputs)).to.be.revertedWith(
                "L1:extraData"
            );
        });

        it("should commit and be able to propose", async function () {
            await commitAndProposeLatestBlock(taikoL1, l1Signer, l2Provider, 0);

            const stateVariables = await taikoL1.getStateVariables();
            const nextBlockId = stateVariables[4];
            const proposedBlock = await taikoL1.getProposedBlock(
                nextBlockId.sub(1)
            );

            expect(proposedBlock.metaHash).not.to.be.eq(
                ethers.constants.HashZero
            );
            expect(proposedBlock.proposer).not.to.be.eq(
                ethers.constants.AddressZero
            );
            expect(proposedBlock.proposedAt).not.to.be.eq(BigNumber.from(0));
        });

        it("should commit and be able to propose for all available slots, then revert when all slots are taken", async function () {
            const { maxNumBlocks } = await taikoL1.getConfig();
            // propose blocks and fill up maxNumBlocks number of slots,
            // expect each one to be successful.
            for (let i = 0; i < maxNumBlocks.toNumber() - 1; i++) {
                await commitAndProposeLatestBlock(
                    taikoL1,
                    l1Signer,
                    l2Provider,
                    0
                );

                const stateVariables = await taikoL1.getStateVariables();
                const nextBlockId = stateVariables[4];
                const proposedBlock = await taikoL1.getProposedBlock(
                    nextBlockId.sub(1)
                );

                expect(proposedBlock.metaHash).not.to.be.eq(
                    ethers.constants.HashZero
                );
                expect(proposedBlock.proposer).not.to.be.eq(
                    ethers.constants.AddressZero
                );
                expect(proposedBlock.proposedAt).not.to.be.eq(
                    BigNumber.from(0)
                );
            }

            // now expect another proposed block to be invalid since all slots are full and none have
            // been proven.
            await expect(
                commitAndProposeLatestBlock(taikoL1, l1Signer, l2Provider)
            ).to.be.revertedWith("L1:tooMany");
        });
    });
});
