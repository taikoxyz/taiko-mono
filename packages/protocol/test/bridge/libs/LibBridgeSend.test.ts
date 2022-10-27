import { expect } from "chai"
import hre, { ethers } from "hardhat"
import { Message } from "../../utils/message"

describe("LibBridgeSend", function () {
    async function deployLibBridgeSendFixture() {
        const [owner, nonOwner, etherVault] = await ethers.getSigners()

        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()
        await addressManager.setAddress("ether_vault", etherVault.address)

        const libSend = await (
            await ethers.getContractFactory("TestLibBridgeSend")
        )
            .connect(owner)
            .deploy()

        await libSend.init(addressManager.address)

        return { owner, nonOwner, libSend }
    }
    describe("enableDestChain()", async function () {
        it("should throw when chainId <= 0", async function () {
            const { libSend } = await deployLibBridgeSendFixture()

            await expect(libSend.enableDestChain(0, true)).to.be.revertedWith(
                "B:chainId"
            )
        })

        it("should throw when chainId == block.chainId", async function () {
            const { libSend } = await deployLibBridgeSendFixture()

            const blockChainId = hre.network.config.chainId

            await expect(
                libSend.enableDestChain(blockChainId, true)
            ).to.be.revertedWith("B:chainId")
        })

        it("should emit DestChainEnabled() event", async function () {
            const { libSend } = await deployLibBridgeSendFixture()

            let blockChainId = hre.network.config.chainId ?? 0
            blockChainId += 1

            expect(await libSend.enableDestChain(blockChainId, true)).to.emit(
                libSend,
                "DestChainEnabled"
            )
        })
    })

    describe("sendMessage()", async function () {
        it("should throw when message.owner == address(0)", async function () {
            const { owner, nonOwner, libSend } =
                await deployLibBridgeSendFixture()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: ethers.constants.AddressZero,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100,
                data: ethers.constants.HashZero,
                memo: "",
            }

            await expect(libSend.sendMessage(message)).to.be.revertedWith(
                "B:owner"
            )
        })

        it("should throw when destchainId == block.chainId", async function () {
            const { owner, nonOwner, libSend } =
                await deployLibBridgeSendFixture()

            const blockChainId = hre.network.config.chainId ?? 1

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: blockChainId,
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

            await expect(libSend.sendMessage(message)).to.be.revertedWith(
                "B:destChainId"
            )
        })

        it("should throw when destChainId has not yet been enabled", async function () {
            const { owner, nonOwner, libSend } =
                await deployLibBridgeSendFixture()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 2,
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

            await expect(libSend.sendMessage(message)).to.be.revertedWith(
                "B:destChainId"
            )
        })

        it("should throw when expectedAmount != msg.value", async function () {
            const { owner, nonOwner, libSend } =
                await deployLibBridgeSendFixture()

            await libSend.enableDestChain(2, true)

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 2,
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

            await expect(libSend.sendMessage(message)).to.be.revertedWith(
                "B:value"
            )
        })

        it("should emit MessageSent() event and signal should be hashed correctly", async function () {
            const { owner, nonOwner, libSend } =
                await deployLibBridgeSendFixture()

            await libSend.enableDestChain(100, true)

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 100,
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

            const expectedAmount =
                message.depositValue + message.callValue + message.processingFee

            expect(
                await libSend.sendMessage(message, {
                    value: expectedAmount,
                })
            ).to.emit(libSend, "MessageSent")
        })
    })
})
