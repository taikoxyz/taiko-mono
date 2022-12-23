import { expect } from "chai"
import { ethers } from "hardhat"
import { BigNumber } from "ethers"

describe("TaikoL1", function () {
    async function deployTaikoL1Fixture() {
        // Deploying addressManager Contract
        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const libReceiptDecoder = await (
            await ethers.getContractFactory("LibReceiptDecoder")
        ).deploy()

        const libTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        ).deploy()

        const libZKP = await (
            await ethers.getContractFactory("LibZKP")
        ).deploy()

        const v1Proposing = await (
            await ethers.getContractFactory("V1Proposing")
        ).deploy()

        const v1Proving = await (
            await ethers.getContractFactory("V1Proving", {
                libraries: {
                    LibReceiptDecoder: libReceiptDecoder.address,
                    LibTxDecoder: libTxDecoder.address,
                    LibZKP: libZKP.address,
                },
            })
        ).deploy()

        const v1Verifying = await (
            await ethers.getContractFactory("V1Verifying")
        ).deploy()

        const TaikoL1Factory = await ethers.getContractFactory("TestTaikoL1", {
            libraries: {
                V1Verifying: v1Verifying.address,
                V1Proposing: v1Proposing.address,
                V1Proving: v1Proving.address,
            },
        })

        const genesisHash = randomBytes32()
        const taikoL1 = await TaikoL1Factory.deploy()
        const feeBase = BigNumber.from(10).pow(18)
        await taikoL1.init(addressManager.address, genesisHash, feeBase)

        return { taikoL1, genesisHash }
    }

    describe("getLatestSyncedHeader()", async function () {
        it("should be genesisHash because no headers have been synced", async function () {
            const { taikoL1, genesisHash } = await deployTaikoL1Fixture()
            const hash = await taikoL1.getLatestSyncedHeader()
            expect(hash).to.be.eq(genesisHash)
        })
    })

    describe("getSyncedHeader()", async function () {
        it("should revert because header number has not been synced", async function () {
            const { taikoL1 } = await deployTaikoL1Fixture()
            await expect(taikoL1.getSyncedHeader(1)).to.be.revertedWith("L1:id")
        })

        it("should return appropraite hash for header", async function () {
            const { taikoL1, genesisHash } = await deployTaikoL1Fixture()
            const hash = await taikoL1.getSyncedHeader(0)
            expect(hash).to.be.eq(genesisHash)
        })
    })

    describe("getBlockProvers()", async function () {
        it("should return empty list when there is no proof for that block", async function () {
            const { taikoL1 } = await deployTaikoL1Fixture()

            const provers = await taikoL1.getBlockProvers(
                Math.ceil(Math.random() * 1024),
                randomBytes32()
            )

            expect(provers).to.be.empty
        })
    })
})

function randomBytes32() {
    return ethers.utils.hexlify(ethers.utils.randomBytes(32))
}
