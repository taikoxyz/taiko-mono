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

    describe("processMessage()", async function () {
        it("should throw if gaslimit == 0 & msg.sender != message.owner", async function () {
            await deployLibBridgeProcessFixture()
        })

        it("should throw if message.destChain != block.chainId", async function () {
            await deployLibBridgeProcessFixture()
        })

        it("should throw if message's status is not NEW", async function () {
            await deployLibBridgeProcessFixture()
        })

        it("should throw if signal has not been received", async function () {
            await deployLibBridgeProcessFixture()
        })

        it("if message fails, refund should go to the intended account and amount", async function () {
            await deployLibBridgeProcessFixture()
        })

        it("should pass properly, message should be processed and marked DONE", async function () {
            await deployLibBridgeProcessFixture()
        })
    })
})
