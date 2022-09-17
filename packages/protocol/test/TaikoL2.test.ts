import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("V1TaikoL2", function () {
    let v1TaikoL2: any
    let addressManager: any
    let signers: any

    function randomBytes32() {
        return ethers.utils.hexlify(ethers.utils.randomBytes(32))
    }

    before(async function () {
        const { chainId } = await hre.ethers.provider.getNetwork()

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

        signers = await ethers.getSigners()
        await addressManager.setAddress(
            `${chainId}.eth_depositor`,
            await signers[0].getAddress()
        )
    })

    describe("anchor()", async function () {
        it("should revert since ancestor hashes not written", async function () {
            const randomHash = randomBytes32()
            await expect(v1TaikoL2.anchor(10, randomHash)).to.be.revertedWith(
                "L2:anchored"
            )
        })
    })
})
