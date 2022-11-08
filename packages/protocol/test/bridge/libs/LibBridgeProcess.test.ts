// import { expect } from "chai"
import hre, { ethers } from "hardhat"
// import { getSlot, decode } from "../../../tasks/utils"
// ethers.provider.getBalance(address)

describe("LibBridgeProcess", function () {
    async function deployLibBridgeProcessFixture() {
        const [owner, etherVaultOwner] = await ethers.getSigners()

        // slot number of IBridge.State for TestLibBridgeProcess.
        // mapping destChains is at position 0 (201)
        // mapping messageStatus is at position 1 (202)
        // nextMessageId is at position 2 (203)
        // Context takes up 3 slots, starts at position 3 (204)
        const stateSlot = 201

        const messageOwner = ethers.Wallet.createRandom()

        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const etherVault = await (await ethers.getContractFactory("EtherVault"))
            .connect(etherVaultOwner)
            .deploy()

        await etherVault.deployed()
        await etherVault.connect(etherVaultOwner).authorize(owner.address, true)
        await etherVault.init(addressManager.address)

        // Sends initial value of 10 ether to EtherVault for receiveEther calls
        await owner.sendTransaction({
            to: etherVault.address,
            value: ethers.utils.parseEther("10.0"),
        })

        const blockChainId = hre.network.config.chainId ?? 0
        await addressManager.setAddress(
            `${blockChainId}.ether_vault`,
            etherVault.address
        )

        const libProcess = await (
            await ethers.getContractFactory("TestLibBridgeProcess")
        )
            .connect(owner)
            .deploy()

        await libProcess.init(addressManager.address)

        await etherVault
            .connect(etherVaultOwner)
            .authorize(libProcess.address, true)

        const MessageStatus = {
            NEW: 0,
            RETRIABLE: 1,
            DONE: 2,
        }

        return { owner, messageOwner, libProcess, MessageStatus, stateSlot }
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
