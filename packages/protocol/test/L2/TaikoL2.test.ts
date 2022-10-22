import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("V1TaikoL2", function () {
    let v1TaikoL2: any
    let addressManager: any

    before(async function () {
        // Deploying addressManager Contract
        addressManager = await (
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
        v1TaikoL2 = await v1TaikoL2Factory.deploy(addressManager.address)
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
})

function randomBytes32() {
    return ethers.utils.hexlify(ethers.utils.randomBytes(32))
}
