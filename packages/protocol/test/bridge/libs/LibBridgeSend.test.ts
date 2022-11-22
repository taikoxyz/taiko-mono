import { expect } from "chai"
import hre, { ethers } from "hardhat"
import {
    AddressManager,
    TestLibBridgeSend,
    EtherVault,
} from "../../../typechain"
import { Message } from "../../utils/message"

describe("LibBridgeSend", function () {
    async function deployLibBridgeSendFixture() {
        const [owner, nonOwner, etherVaultOwner] = await ethers.getSigners()

        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const etherVault: EtherVault = await (
            await ethers.getContractFactory("EtherVault")
        )
            .connect(etherVaultOwner)
            .deploy()

        await etherVault.deployed()
        await etherVault.init(addressManager.address)

        const blockChainId = hre.network.config.chainId ?? 0
        await addressManager.setAddress(
            `${blockChainId}.ether_vault`,
            etherVault.address
        )

        const libSend: TestLibBridgeSend = await (
            await ethers.getContractFactory("TestLibBridgeSend")
        )
            .connect(owner)
            .deploy()

        await libSend.init(addressManager.address)
        await etherVault
            .connect(etherVaultOwner)
            .authorize(libSend.address, true)

        const srcChainId = 1

        const enabledDestChainId = 100

        return { owner, nonOwner, libSend, srcChainId, enabledDestChainId }
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

            const blockChainId = hre.network.config.chainId ?? 0

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
            const { owner, nonOwner, libSend, srcChainId } =
                await deployLibBridgeSendFixture()

            const nonEnabledDestChain = 2

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: srcChainId,
                destChainId: nonEnabledDestChain,
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
            const { owner, nonOwner, libSend, srcChainId } =
                await deployLibBridgeSendFixture()

            const blockChainId = hre.network.config.chainId ?? 1

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: srcChainId,
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
            const { owner, nonOwner, libSend, srcChainId } =
                await deployLibBridgeSendFixture()

            const nonEnabledDestChain = 2

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: srcChainId,
                destChainId: nonEnabledDestChain,
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
            const { owner, nonOwner, libSend, srcChainId, enabledDestChainId } =
                await deployLibBridgeSendFixture()

            await libSend.enableDestChain(enabledDestChainId, true)

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: srcChainId,
                destChainId: enabledDestChainId,
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
            const { owner, nonOwner, libSend, srcChainId, enabledDestChainId } =
                await deployLibBridgeSendFixture()

            await libSend.enableDestChain(enabledDestChainId, true)

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: srcChainId,
                destChainId: enabledDestChainId,
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
