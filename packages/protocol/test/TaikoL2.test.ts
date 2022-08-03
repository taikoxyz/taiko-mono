import { expect } from "chai"
// import * as log from "../tasks/log"
const hre = require("hardhat")
const ethers = hre.ethers
// const EBN = ethers.BigNumber

describe("TaikoL2 tests", function () {
    let taikoL2: any

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
            const randomHash =
                "0xdefceb465d5c59275e3593930c07dafb39932e39973510714e6a6c6e544c014e"

            await expect(taikoL2.anchor(0, randomHash)).to.be.revertedWith(
                "invalid anchor"
            )
        })
        it("should revert since anchorHash == 0x0", async function () {
            const zeroHash =
                "0x0000000000000000000000000000000000000000000000000000000000000000"
            await expect(taikoL2.anchor(10, zeroHash)).to.be.revertedWith(
                "invalid anchor"
            )
        })
        it("should not revert", async function () {
            const randomHash =
                "0xdefceb465d5c59275e3593930c07dafb39932e39973510714e6a6c6e544c014e"
            await expect(taikoL2.anchor(1, randomHash)).to.not.be.reverted
        })
    })
})
