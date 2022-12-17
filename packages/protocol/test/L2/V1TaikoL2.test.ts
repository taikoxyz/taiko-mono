import { expect } from "chai"
import { ethers } from "hardhat"
import { TaikoL2 } from "../../typechain"

describe("TaikoL2", function () {
    let v1TaikoL2: V1TaikoL2

    beforeEach(async function () {
        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        // Deploying V1TaikoL2 Contract linked with LibTxDecoder (throws error otherwise)
        const libTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        ).deploy()

        v1TaikoL2 = await (
            await ethers.getContractFactory("V1TaikoL2", {
                libraries: {
                    LibTxDecoder: libTxDecoder.address,
                },
            })
        ).deploy(addressManager.address)
    })

    describe("anchor()", async function () {
        it("should revert since ancestor hashes not written", async function () {
            await expect(
                v1TaikoL2.anchor(
                    Math.ceil(Math.random() * 1024),
                    randomBytes32()
                )
            ).to.be.revertedWith("L2:publicInputHash")
        })
    })

    describe("getLatestSyncedHeader()", async function () {
        it("should be 0 because no headers have been synced", async function () {
            const hash = await v1TaikoL2.getLatestSyncedHeader()
            expect(hash).to.be.eq(ethers.constants.HashZero)
        })
    })

    describe("getSyncedHeader()", async function () {
        it("should be 0 because header number has not been synced", async function () {
            const hash = await v1TaikoL2.getSyncedHeader(1)
            expect(hash).to.be.eq(ethers.constants.HashZero)
        })
    })
})

function randomBytes32() {
    return ethers.utils.hexlify(ethers.utils.randomBytes(32))
}
