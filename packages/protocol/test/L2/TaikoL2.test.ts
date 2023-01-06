import { expect } from "chai";
import { ethers } from "hardhat";
import { TaikoL2 } from "../../typechain";
import { randomBytes32 } from "../utils/bytes";

describe("TaikoL2", function () {
    let taikoL2: TaikoL2;

    beforeEach(async function () {
        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy();
        await addressManager.init();

        // Deploying TaikoL2 Contract linked with LibTxDecoder (throws error otherwise)
        const libTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        ).deploy();

        taikoL2 = await (
            await ethers.getContractFactory("TaikoL2", {
                libraries: {
                    LibTxDecoder: libTxDecoder.address,
                },
            })
        ).deploy(addressManager.address);
    });

    describe("anchor()", async function () {
        it("should revert since ancestor hashes not written", async function () {
            await expect(
                taikoL2.anchor(Math.ceil(Math.random() * 1024), randomBytes32())
            ).to.be.revertedWith("L2:publicInputHash");
        });
    });

    describe("getLatestSyncedHeader()", async function () {
        it("should be 0 because no headers have been synced", async function () {
            const hash = await taikoL2.getLatestSyncedHeader();
            expect(hash).to.be.eq(ethers.constants.HashZero);
        });
    });

    describe("getSyncedHeader()", async function () {
        it("should be 0 because header number has not been synced", async function () {
            const hash = await taikoL2.getSyncedHeader(1);
            expect(hash).to.be.eq(ethers.constants.HashZero);
        });
    });
});
