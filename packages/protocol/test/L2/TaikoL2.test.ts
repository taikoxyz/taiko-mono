import { expect } from "chai"
import { ethers } from "hardhat"

describe("TaikoL2", function () {
    async function deployTaikoL2Fixture() {
        // Deploying addressManager Contract
        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        // Deploying TaikoL2 Contract linked with LibTxDecoder (throws error otherwise)
        const libTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        ).deploy()

        const taikoL2Factory = await ethers.getContractFactory("TaikoL2", {
            libraries: {
                LibTxDecoder: libTxDecoder.address,
            },
        })
        const taikoL2 = await taikoL2Factory.deploy(addressManager.address)

        return { taikoL2 }
    }

    describe("anchor()", async function () {
        it("should revert since ancestor hashes not written", async function () {
            const { taikoL2 } = await deployTaikoL2Fixture()
            await expect(
                taikoL2.anchor(Math.ceil(Math.random() * 1024), randomBytes32())
            ).to.be.revertedWith("L2:publicInputHash")
        })
    })

    describe("getLatestSyncedHeader()", async function () {
        it("should be 0 because no headers have been synced", async function () {
            const { taikoL2 } = await deployTaikoL2Fixture()
            const hash = await taikoL2.getLatestSyncedHeader()
            expect(hash).to.be.eq(ethers.constants.HashZero)
        })
    })

    describe("getSyncedHeader()", async function () {
        it("should be 0 because header number has not been synced", async function () {
            const { taikoL2 } = await deployTaikoL2Fixture()
            const hash = await taikoL2.getSyncedHeader(1)
            expect(hash).to.be.eq(ethers.constants.HashZero)
        })
    })
})

function randomBytes32() {
    return ethers.utils.hexlify(ethers.utils.randomBytes(32))
}
