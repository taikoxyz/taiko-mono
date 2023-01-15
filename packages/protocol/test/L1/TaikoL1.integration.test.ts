import { expect } from "chai";
import { BigNumber, ethers as ethersLib } from "ethers";
import { ethers } from "hardhat";
import { TaikoL1, TaikoL2 } from "../../typechain";
import deployAddressManager from "../utils/addressManager";
import { BlockMetadata } from "../utils/block_metadata";
import { commitBlock, generateCommitHash } from "../utils/commit";
import { buildProposeBlockInputs, proposeBlock } from "../utils/propose";
import { getDefaultL2Signer, getL1Provider } from "../utils/provider";
import { defaultFeeBase, deployTaikoL1 } from "../utils/taikoL1";
import { deployTaikoL2 } from "../utils/taikoL2";

describe("integration:TaikoL1", function () {
    let taikoL1: TaikoL1;
    let taikoL2: TaikoL2;
    let l2Provider: ethersLib.providers.JsonRpcProvider;
    let l2Signer: ethersLib.Signer;

    beforeEach(async function () {
        l2Provider = new ethers.providers.JsonRpcProvider(
            "http://localhost:28545"
        );

        l2Signer = await getDefaultL2Signer();

        const l2AddressManager = await deployAddressManager(l2Signer);
        taikoL2 = await deployTaikoL2(l2Signer, l2AddressManager);

        const genesisHash = taikoL2.deployTransaction.blockHash as string;

        const l1Provider = getL1Provider();

        l1Provider.pollingInterval = 100;

        const signers = await ethers.getSigners();

        const l1AddressManager = await deployAddressManager(signers[0]);

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
    });

    describe("getProposedBlock()", function () {
        it("should revert if block is out of range and not a valid proposed block", async function () {
            await expect(taikoL1.getProposedBlock(123)).to.be.revertedWith(
                "L1:id"
            );
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
            const block = await l2Provider.getBlock("latest");
            const commitSlot = 0;
            const { tx, commit } = await commitBlock(
                taikoL1,
                block,
                commitSlot
            );

            const { commitConfirmations } = await taikoL1.getConfig();

            await tx.wait(commitConfirmations.toNumber());
            const receipt = await proposeBlock(
                taikoL1,
                block,
                commit.txListHash,
                tx.blockNumber as number,
                block.gasLimit,
                commitSlot
            );
            expect(receipt.status).to.be.eq(1);

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
                const block = await l2Provider.getBlock("latest");
                const { tx, commit } = await commitBlock(taikoL1, block, i);

                const receipt = await proposeBlock(
                    taikoL1,
                    block,
                    commit.txListHash,
                    tx.blockNumber as number,
                    block.gasLimit,
                    i
                );

                expect(receipt.status).to.be.eq(1);

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
            const block = await l2Provider.getBlock("latest");
            const { tx, commit } = await commitBlock(taikoL1, block);

            await expect(
                proposeBlock(
                    taikoL1,
                    block,
                    commit.txListHash,
                    tx.blockNumber as number,
                    block.gasLimit
                )
            ).to.be.revertedWith("L1:tooMany");
        });
    });
});
