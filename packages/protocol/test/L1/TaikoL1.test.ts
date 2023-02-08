import { expect } from "chai";
import { ethers } from "hardhat";
import { TaikoL1 } from "../../typechain";
import deployAddressManager from "../utils/addressManager";
import { randomBytes32 } from "../utils/bytes";
import { deployTaikoL1 } from "../utils/taikoL1";

describe("TaikoL1", function () {
    let taikoL1: TaikoL1;
    let genesisHash: string;

    beforeEach(async function () {
        const l1Signer = (await ethers.getSigners())[0];
        const addressManager = await deployAddressManager(l1Signer);
        genesisHash = randomBytes32();
        taikoL1 = await deployTaikoL1(addressManager, genesisHash, false);
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
                "L1:number"
            );
        });

        it("should return appropraite hash for header", async function () {
            const hash = await taikoL1.getSyncedHeader(0);
            expect(hash).to.be.eq(genesisHash);
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
            const initialUncleDelay = 1;
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
