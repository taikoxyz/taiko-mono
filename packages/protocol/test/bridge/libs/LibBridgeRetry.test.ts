// import { expect } from "chai"
import { ethers } from "hardhat"

describe("LibBridgeRetry", function () {
    async function deployLibBridgeRetryFixture() {
        const [owner, nonOwner, etherVault] = await ethers.getSigners()

        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()
        await addressManager.setAddress("ether_vault", etherVault.address)

        const libRetry = await (
            await ethers.getContractFactory("TestLibBridgeRetry")
        )
            .connect(owner)
            .deploy()
        await libRetry.init(addressManager.address)

        return { owner, nonOwner, libRetry }
    }

    describe("retryMessage()", async function () {
        it("should throw if message.gaslimit == 0 && msg.sender != message.owner", async function () {
            await deployLibBridgeRetryFixture()
        })

        it("should throw if lastAttempt == true && msg.sender != message.owner", async function () {
            await deployLibBridgeRetryFixture()
        })

        it("should throw if message status is not RETRIABLE", async function () {
            await deployLibBridgeRetryFixture()
        })

        it("should throw if message.gaslimit == 0 && msg.sender != message.owner", async function () {
            await deployLibBridgeRetryFixture()
        })

        it("should successfully pass (maybe add event for this case)", async function () {
            await deployLibBridgeRetryFixture()
        })
    })
})
