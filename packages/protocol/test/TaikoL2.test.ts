import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("TaikoL2 tests", function () {
    let taikoL2: any

    function randomBytes32() {
        return ethers.utils.hexlify(ethers.utils.randomBytes(32))
    }

    before(async function () {
        // Deploying TaikoL2 Contract linked with LibTxList (throws error otherwise)
        const txListLib = await (
            await ethers.getContractFactory("LibTxList")
        ).deploy()

        const taikoL2Factory = await ethers.getContractFactory("TaikoL2", {
            libraries: {
                LibTxList: txListLib.address,
            },
        })
        taikoL2 = await taikoL2Factory.deploy()
    })

    describe("Testing anchor() function", async function () {
        it("should revert since anchorHeight == 0", async function () {
            const randomHash = randomBytes32()
            await expect(taikoL2.anchor(0, randomHash)).to.be.revertedWith(
                "invalid anchor"
            )
        })
        it("should revert since anchorHash == 0x0", async function () {
            const zeroHash = ethers.constants.HashZero
            await expect(taikoL2.anchor(10, zeroHash)).to.be.revertedWith(
                "invalid anchor"
            )
        })
        it("should not revert, and should emit an Anchored event", async function () {
            const randomHash = randomBytes32()
            await expect(taikoL2.anchor(1, randomHash)).to.emit(
                taikoL2,
                "Anchored"
            )
        })
    })
})
