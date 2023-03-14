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
                "L1_BLOCK_NUMBER()"
            );
        });

        it("should return appropriate hash for header", async function () {
            const hash = await taikoL1.getSyncedHeader(0);
            expect(hash).to.be.eq(genesisHash);
        });
    });

    describe("proposeBlock()", async function () {
        it("should revert when size of inputs is les than 2", async function () {
            await expect(
                taikoL1.proposeBlock([randomBytes32()])
            ).to.be.revertedWith("L1_INPUT_SIZE()");
        });
    });

    describe("commitBlock()", async function () {
        it("should revert when size of inputs is les than 2", async function () {
            await expect(
                taikoL1.proposeBlock([randomBytes32()])
            ).to.be.revertedWith("L1_INPUT_SIZE()");
        });
    });
});
