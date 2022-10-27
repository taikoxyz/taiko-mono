// import { expect } from "chai"
import { ethers } from "hardhat"

describe("LibBridgeProcess", function () {
    async function deployLibBridgeProcessFixture() {
        const [owner, nonOwner, etherVault] = await ethers.getSigners()

        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()
        await addressManager.setAddress("ether_vault", etherVault.address)

        const libProcess = await (
            await ethers.getContractFactory("TestLibBridgeProcess")
        )
            .connect(owner)
            .deploy()

        await libProcess.init(addressManager.address)

        return { owner, nonOwner, libProcess }
    }

    describe("stub", async function () {
        it("stub", async function () {
            await deployLibBridgeProcessFixture()
        })
    })
})
