import { expect } from "chai";
import { BigNumber, ethers as ethersLib } from "ethers";
import { ethers } from "hardhat";
import { TaikoL1, TaikoL2 } from "../../typechain";
import { BlockMetadata } from "../utils/block_metadata";
import { commitBlock, generateCommitHash } from "../utils/commit";
import { buildProposeBlockInputs, proposeBlock } from "../utils/propose";
import { deployTaikoL1 } from "../utils/taikoL1";
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

        l2Signer = await l2Provider.getSigner(
            (
                await l2Provider.listAccounts()
            )[0]
        );

        taikoL2 = await deployTaikoL2(l2Signer);

        const genesisHash = taikoL2.deployTransaction.blockHash as string;

        taikoL1 = await deployTaikoL1(genesisHash);
    });

    describe("isCommitValid()", async function () {
        it("should not be valid", async function () {
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
        it("proposed block does not exist", async function () {
            const block = await taikoL1.getProposedBlock(123);
            expect(block[0]).to.be.eq(ethers.constants.HashZero);
            expect(block[1]).to.be.eq(ethers.constants.AddressZero);
            expect(block[2]).to.be.eq(BigNumber.from(0));
        });
    });
    describe("commitBlock() -> proposeBlock() integration", async function () {
        it("should revert with invalid meta", async function () {
            const block = await l2Provider.getBlock("latest");
            const { tx, commit } = await commitBlock(taikoL1, block);

            await expect(
                proposeBlock(
                    taikoL1,
                    block,
                    commit.txListHash,
                    tx.blockNumber as number,
                    1,
                    block.gasLimit
                )
            ).to.be.revertedWith("L1:placeholder");
        });

        it("should revert with invalid gasLimit", async function () {
            const block = await l2Provider.getBlock("latest");
            const { tx, commit } = await commitBlock(taikoL1, block);

            // blockMetadata is inputs[0], txListBytes = inputs[1]
            const config = await taikoL1.getConfig();
            const gasLimit = config[7];
            await proposeBlock(
                taikoL1,
                block,
                commit.txListHash,
                tx.blockNumber as number,
                0,
                block.gasLimit
            );

            await expect(
                proposeBlock(
                    taikoL1,
                    block,
                    commit.txListHash,
                    tx.blockNumber as number,
                    0,
                    gasLimit.add(1)
                )
            ).to.be.revertedWith("L1:gasLimit");
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
                commitSlot: 1,
                commitHeight: tx.blockNumber as number,
            };

            const inputs = buildProposeBlockInputs(block, meta);

            await expect(taikoL1.proposeBlock(inputs)).to.be.revertedWith(
                "L1:extraData"
            );
        });

        it("should commit and be able to propose", async function () {
            const block = await l2Provider.getBlock("latest");
            const { tx, commit } = await commitBlock(taikoL1, block);

            await proposeBlock(
                taikoL1,
                block,
                commit.txListHash,
                tx.blockNumber as number,
                0,
                block.gasLimit
            );

            const stateVariables = await taikoL1.getStateVariables();
            const nextBlockId = stateVariables[4];
            const proposedBlock = await taikoL1.getProposedBlock(
                nextBlockId.sub(1)
            );

            expect(proposedBlock[0]).not.to.be.eq(ethers.constants.HashZero);
            expect(proposedBlock[2]).not.to.be.eq(ethers.constants.AddressZero);
            expect(proposedBlock[3]).not.to.be.eq(BigNumber.from(0));

            const isCommitValid = await taikoL1.isCommitValid(
                1,
                tx.blockNumber as number,
                commit.hash
            );

            expect(isCommitValid).to.be.eq(true);
        });
    });
});
