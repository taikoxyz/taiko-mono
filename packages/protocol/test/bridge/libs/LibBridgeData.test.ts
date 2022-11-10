import { expect } from "chai"
import { ethers } from "hardhat"
import { K_BRIDGE_MESSAGE } from "../../constants/messages"

describe("LibBridgeData", function () {
    async function deployLibBridgeDataFixture() {
        const [owner, nonOwner] = await ethers.getSigners()

        const libData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy()

        const testMessage = {
            id: 1,
            sender: owner.address,
            srcChainId: 1,
            destChainId: 2,
            owner: owner.address,
            to: nonOwner.address,
            refundAddress: owner.address,
            depositValue: 0,
            callValue: 0,
            processingFee: 0,
            gasLimit: 0,
            data: ethers.constants.HashZero,
            memo: "",
        }

        const testTypes = [
            "string",
            "tuple(uint256 id, address sender, uint256 srcChainId, uint256 destChainId, address owner, address to, address refundAddress, uint256 depositValue, uint256 callValue, uint256 processingFee, uint256 gasLimit, bytes data, string memo)",
        ]

        const testVar = [K_BRIDGE_MESSAGE, testMessage]

        const MessageStatus = {
            NEW: 0,
            RETRIABLE: 1,
            DONE: 2,
        }

        return {
            owner,
            nonOwner,
            libData,
            testMessage,
            testTypes,
            testVar,
            MessageStatus,
        }
    }

    describe("hashMessage()", async function () {
        it("should return properly hashed message", async function () {
            const { libData, testMessage, testTypes } =
                await deployLibBridgeDataFixture()
            // dummy struct to test with

            const testVar = [K_BRIDGE_MESSAGE, testMessage]
            const hashed = await libData.hashMessage(testMessage)
            const expectedEncoded = ethers.utils.defaultAbiCoder.encode(
                testTypes,
                testVar
            )

            const expectedHash = await ethers.utils.keccak256(expectedEncoded)

            expect(expectedHash).to.be.eq(hashed)
        })
    })

    describe("updateMessageStatus()", async function () {
        it("should emit upon successful change, and value should be changed correctly", async function () {
            const { libData, testMessage, MessageStatus } =
                await deployLibBridgeDataFixture()

            const signal = await libData.hashMessage(testMessage)

            expect(
                await libData.updateMessageStatus(signal, MessageStatus.NEW)
            ).to.emit(libData, "MessageStatusChanged")

            const messageStatus = await libData.getMessageStatus(signal)

            expect(messageStatus).to.eq(MessageStatus.NEW)
        })

        it("unchanged MessageStatus should not emit event", async function () {
            const { libData, testMessage, MessageStatus } =
                await deployLibBridgeDataFixture()

            const signal = await libData.hashMessage(testMessage)

            await libData.updateMessageStatus(signal, MessageStatus.NEW)

            expect(
                await libData.updateMessageStatus(signal, MessageStatus.NEW)
            ).to.not.emit(libData, "MessageStatusChanged")

            expect(await libData.getMessageStatus(signal)).to.eq(
                MessageStatus.NEW
            )
        })
    })
})
