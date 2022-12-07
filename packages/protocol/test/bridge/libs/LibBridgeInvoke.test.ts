import { expect } from "chai"
import { ethers } from "hardhat"
import { Message } from "../../utils/message"
import {
    TestLibBridgeData,
    TestLibBridgeInvoke,
    TestReceiver,
} from "../../../typechain"

describe("LibBridgeInvoke", function () {
    async function deployLibBridgeDataFixture() {
        const libData: TestLibBridgeData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy()
        return { libData }
    }

    async function deployLibBridgeInvokeFixture() {
        const [owner, nonOwner] = await ethers.getSigners()

        const libInvoke: TestLibBridgeInvoke = await (
            await ethers.getContractFactory("TestLibBridgeInvoke")
        )
            .connect(owner)
            .deploy()

        return { owner, nonOwner, libInvoke }
    }

    describe("invokeMessageCall()", async function () {
        it("should throw when gasLimit <= 0", async function () {
            const { owner, nonOwner, libInvoke } =
                await deployLibBridgeInvokeFixture()

            const { libData } = await deployLibBridgeDataFixture()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: owner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 0,
                data: ethers.constants.HashZero,
                memo: "",
            }

            const signal = await libData.hashMessage(message)

            await expect(
                libInvoke.invokeMessageCall(message, signal, message.gasLimit)
            ).to.be.revertedWith("B:gasLimit")
        })

        it("should emit event with success false if message does not actually invoke", async function () {
            const { owner, nonOwner, libInvoke } =
                await deployLibBridgeInvokeFixture()

            const { libData } = await deployLibBridgeDataFixture()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: owner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100,
                data: ethers.constants.HashZero,
                memo: "",
            }

            const signal = await libData.hashMessage(message)

            await expect(
                libInvoke.invokeMessageCall(message, signal, message.gasLimit)
            )
                .to.emit(libInvoke, "MessageInvoked")
                .withArgs(signal, false)
        })

        it("should emit event with success true if message invokes successfully", async function () {
            const { owner, libInvoke } = await deployLibBridgeInvokeFixture()

            const { libData } = await deployLibBridgeDataFixture()

            const testReceiver: TestReceiver = await (
                await ethers.getContractFactory("TestReceiver")
            ).deploy()

            await testReceiver.deployed()

            const ABI = ["function receiveTokens(uint256) payable"]
            const iface = new ethers.utils.Interface(ABI)
            const data = iface.encodeFunctionData("receiveTokens", [1])

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: owner.address,
                to: testReceiver.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 300000,
                data: data,
                memo: "",
            }

            const signal = await libData.hashMessage(message)

            await expect(
                libInvoke.invokeMessageCall(message, signal, message.gasLimit, {
                    value: message.callValue,
                })
            )
                .to.emit(libInvoke, "MessageInvoked")
                .withArgs(signal, true)
        })
    })
})
