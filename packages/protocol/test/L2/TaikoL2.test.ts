import { expect } from "chai"
import { ethers } from "hardhat"

describe("V1TaikoL2", function () {
    async function deployV1TaikoL2Fixture() {
        // Deploying addressManager Contract
        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        // Deploying V1TaikoL2 Contract linked with LibTxDecoder (throws error otherwise)
        const libTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        ).deploy()

        const v1TaikoL2Factory = await ethers.getContractFactory("V1TaikoL2", {
            libraries: {
                LibTxDecoder: libTxDecoder.address,
            },
        })
        const v1TaikoL2 = await v1TaikoL2Factory.deploy(addressManager.address)

        return { v1TaikoL2 }
    }

    describe("anchor()", async function () {
        it("should revert since ancestor hashes not written", async function () {
            const { v1TaikoL2 } = await deployV1TaikoL2Fixture()
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
            const { v1TaikoL2 } = await deployV1TaikoL2Fixture()
            const hash = await v1TaikoL2.getLatestSyncedHeader()
            expect(hash).to.be.eq(ethers.constants.HashZero)
        })
    })

    describe("getSyncedHeader()", async function () {
        it("should be 0 because header number has not been synced", async function () {
            const { v1TaikoL2 } = await deployV1TaikoL2Fixture()
            const hash = await v1TaikoL2.getSyncedHeader(1)
            expect(hash).to.be.eq(ethers.constants.HashZero)
        })
    })
})

function randomBytes32() {
    return ethers.utils.hexlify(ethers.utils.randomBytes(32))
}
