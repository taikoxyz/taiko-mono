import { expect } from "chai"
import { ethers } from "hardhat"

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

        const v1Utils = await (
            await ethers.getContractFactory("V1Utils")
        ).deploy()

        const v1Proposing = await (
            await ethers.getContractFactory("V1Proposing", {
                libraries: {
                    V1Utils: v1Utils.address,
                },
            })
        ).deploy()

        const v1Proving = await (
            await ethers.getContractFactory("V1Proving", {
                libraries: {
                    LibReceiptDecoder: libReceiptDecoder.address,
                    LibTxDecoder: libTxDecoder.address,
                    LibZKP: libZKP.address,
                    V1Utils: v1Utils.address,
                },
            })
        ).deploy()

        const v1Finalizing = await (
            await ethers.getContractFactory("V1Finalizing", {
                libraries: {
                    V1Utils: v1Utils.address,
                },
            })
        ).deploy()

        const TaikoL1Factory = await ethers.getContractFactory("TaikoL1", {
            libraries: {
                V1Finalizing: v1Finalizing.address,
                V1Proposing: v1Proposing.address,
                V1Proving: v1Proving.address,
                V1Utils: v1Utils.address,
            },
        })

        const genesisHash = randomBytes32()
        const taikoL1 = await TaikoL1Factory.deploy()
        await taikoL1.init(addressManager.address, genesisHash)

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
