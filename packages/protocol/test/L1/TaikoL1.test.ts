import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { TaikoL1 } from "../../typechain";
import { randomBytes32 } from "../utils/bytes";

describe("TaikoL1", function () {
    let taikoL1: TaikoL1;
    let genesisHash: string;

    beforeEach(async function () {
        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy();
        await addressManager.init();

        const libReceiptDecoder = await (
            await ethers.getContractFactory("LibReceiptDecoder")
        ).deploy();

        const libTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        ).deploy();

        const libProposing = await (
            await ethers.getContractFactory("LibProposing")
        ).deploy();

        const libProving = await (
            await ethers.getContractFactory("LibProving", {
                libraries: {
                    LibReceiptDecoder: libReceiptDecoder.address,
                    LibTxDecoder: libTxDecoder.address,
                },
            })
        ).deploy();

        const libVerifying = await (
            await ethers.getContractFactory("LibVerifying")
        ).deploy();

        genesisHash = randomBytes32();
        const feeBase = BigNumber.from(10).pow(18);
        taikoL1 = await (
            await ethers.getContractFactory("TestTaikoL1", {
                libraries: {
                    LibVerifying: libVerifying.address,
                    LibProposing: libProposing.address,
                    LibProving: libProving.address,
                },
            })
        ).deploy();
        await taikoL1.init(addressManager.address, genesisHash, feeBase);
    });

    describe("getLatestSyncedHeader()", async function () {
        it("should be genesisHash because no headers have been synced", async function () {
            const hash = await taikoL1.getLatestSyncedHeader();
            expect(hash).to.be.eq(genesisHash);
        });
    });

    describe("getSyncedHeader()", async function () {
        it("should revert because header number has not been synced", async function () {
            await expect(taikoL1.getSyncedHeader(1)).to.be.revertedWith(
                "L1:id"
            );
        });

        it("should return appropraite hash for header", async function () {
            const hash = await taikoL1.getSyncedHeader(0);
            expect(hash).to.be.eq(genesisHash);
        });
    });

    describe("getBlockProvers()", async function () {
        it("should return empty list when there is no proof for that block", async function () {
            const provers = await taikoL1.getBlockProvers(
                Math.ceil(Math.random() * 1024),
                randomBytes32()
            );

            expect(provers).to.be.empty;
        });
    });

    describe("halt()", async function () {
        it("should revert called by nonOwner", async function () {
            const initiallyHalted = await taikoL1.isHalted();
            expect(initiallyHalted).to.be.eq(false);
            const signers = await ethers.getSigners();
            await expect(
                taikoL1.connect(signers[1]).halt(true)
            ).to.be.revertedWith("Ownable: caller is not the owner");

            const isHalted = await taikoL1.isHalted();
            expect(isHalted).to.be.eq(false);
        });

        it("should not revert when called by owner", async function () {
            const initiallyHalted = await taikoL1.isHalted();
            expect(initiallyHalted).to.be.eq(false);
            await taikoL1.halt(true);
            const isHalted = await taikoL1.isHalted();
            expect(isHalted).to.be.eq(true);
        });
    });

    describe("proposeBlock()", async function () {
        it("should revert when size of inputs is les than 2", async function () {
            await expect(
                taikoL1.proposeBlock([randomBytes32()])
            ).to.be.revertedWith("L1:inputs:size");
        });

        it("should revert when halted", async function () {
            await taikoL1.halt(true);
            await expect(
                taikoL1.proposeBlock([randomBytes32()])
            ).to.be.revertedWith("0x1");
        });
    });

    describe("commitBlock()", async function () {
        it("should revert when size of inputs is les than 2", async function () {
            await expect(
                taikoL1.proposeBlock([randomBytes32()])
            ).to.be.revertedWith("L1:inputs:size");
        });

        it("should revert when halted", async function () {
            await taikoL1.halt(true);
            await expect(
                taikoL1.proposeBlock([randomBytes32()])
            ).to.be.revertedWith("0x1");
        });
    });

    describe("getDelayForBlockId()", async function () {
        it("should return  initial uncle delay for block id <= 2 * K_MAX_NUM_BLOCKS", async function () {
            const constants = await taikoL1.getConfig();
            const maxNumBlocks = constants[1];
            const delay = await taikoL1.getUncleProofDelay(maxNumBlocks.mul(2));
            const initialUncleDelay = 60;
            expect(delay).to.be.eq(initialUncleDelay);
        });

        it("should return avg proof time for block id > 2 * K_MAX_NUM_BLOCKS", async function () {
            const constants = await taikoL1.getConfig();
            const maxNumBlocks = constants[1];
            const delay = await taikoL1.getUncleProofDelay(
                maxNumBlocks.mul(2).add(1)
            );
            const avgProofTime = 0; // no proofs have been generated
            expect(delay).to.be.eq(avgProofTime);
        });
    });
});
