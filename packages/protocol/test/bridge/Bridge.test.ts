import { expect } from "chai"
import { AddressManager, Bridge } from "../../typechain"
import { ethers } from "hardhat"
import { BigNumber } from "ethers"
import { Message } from "../utils/message"

describe("Bridge", function () {
    async function deployBridgeFixture() {
        const [owner, nonOwner, etherVault] = await ethers.getSigners()

        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const { chainId } = await ethers.provider.getNetwork()

        await addressManager.setAddress(
            `${chainId}.ether_vault`,
            etherVault.address
        )

        const libTrieProof = await (
            await ethers.getContractFactory("LibTrieProof")
        ).deploy()

        const libBridgeProcess = await (
            await ethers.getContractFactory("LibBridgeProcess", {
                libraries: {
                    LibTrieProof: libTrieProof.address,
                },
            })
        ).deploy()

        const libBridgeRetry = await (
            await ethers.getContractFactory("LibBridgeRetry")
        ).deploy()

        const BridgeFactory = await ethers.getContractFactory("Bridge", {
            libraries: {
                LibBridgeProcess: libBridgeProcess.address,
                LibBridgeRetry: libBridgeRetry.address,
                LibTrieProof: libTrieProof.address,
            },
        })

        const bridge: Bridge = await BridgeFactory.connect(owner).deploy()

        await bridge.init(addressManager.address)

        const enabledDestChainId = 100

        await bridge.enableDestChain(enabledDestChainId, true)

        return {
            owner,
            nonOwner,
            bridge,
            addressManager,
            enabledDestChainId,
            etherVault,
        }
    }

    describe("sendMessage()", function () {
        it("throws when owner is the zero address", async () => {
            const { owner, nonOwner, bridge } = await deployBridgeFixture()

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

            await expect(bridge.sendMessage(message)).to.be.revertedWith(
                "B:owner"
            )
        })

        it("throws when dest chain id is same as block.chainid", async () => {
            const { owner, nonOwner, bridge } = await deployBridgeFixture()

            const network = await ethers.provider.getNetwork()
            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: network.chainId,
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

            await expect(bridge.sendMessage(message)).to.be.revertedWith(
                "B:destChainId"
            )
        })

        it("throws when dest chain id is not enabled", async () => {
            const { owner, nonOwner, bridge } = await deployBridgeFixture()

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

            await expect(bridge.sendMessage(message)).to.be.revertedWith(
                "B:destChainId"
            )
        })

        it("throws when msg.value is not the same as expected amount", async () => {
            const { owner, nonOwner, bridge, enabledDestChainId } =
                await deployBridgeFixture()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
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

            await expect(bridge.sendMessage(message)).to.be.revertedWith(
                "B:value"
            )
        })

        it("emits event and is successful when message is valid, ether_vault receives the expectedAmount", async () => {
            const { owner, nonOwner, etherVault, bridge, enabledDestChainId } =
                await deployBridgeFixture()

            const etherVaultOriginalBalance = await etherVault.getBalance()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
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
            await expect(
                bridge.sendMessage(message, {
                    value: expectedAmount,
                })
            ).to.emit(bridge, "MessageSent")

            const etherVaultUpdatedBalance = await etherVault.getBalance()

            expect(etherVaultUpdatedBalance).to.be.eq(
                etherVaultOriginalBalance.add(expectedAmount)
            )
        })
    })

    describe("sendSignal()", async function () {
        it("throws when signal is empty", async function () {
            const { owner, bridge } = await deployBridgeFixture()

            await expect(
                bridge.connect(owner).sendSignal(ethers.constants.HashZero)
            ).to.be.revertedWith("B:signal")
        })

        it("sends signal, confirms it was sent", async function () {
            const { owner, bridge } = await deployBridgeFixture()

            const hash =
                "0xf2e08f6b93d8cf4f37a3b38f91a8c37198095dde8697463ca3789e25218a8e9d"
            await expect(bridge.connect(owner).sendSignal(hash))
                .to.emit(bridge, "SignalSent")
                .withArgs(owner.address, hash)

            const isSignalSent = await bridge.isSignalSent(owner.address, hash)
            expect(isSignalSent).to.be.eq(true)
        })
    })

    describe("isDestChainEnabled()", function () {
        it("is disabled for unabled chainIds", async () => {
            const { bridge } = await deployBridgeFixture()

            const enabled = await bridge.isDestChainEnabled(68)
            expect(enabled).to.be.eq(false)
        })

        it("is enabled for enabled chainId", async () => {
            const { bridge, enabledDestChainId } = await deployBridgeFixture()

            const enabled = await bridge.isDestChainEnabled(enabledDestChainId)
            expect(enabled).to.be.eq(true)
        })
    })

    describe("context()", function () {
        it("returns unitialized context", async () => {
            const { bridge } = await deployBridgeFixture()

            const ctx = await bridge.context()
            expect(ctx[0]).to.be.eq(ethers.constants.HashZero)
            expect(ctx[1]).to.be.eq(ethers.constants.AddressZero)
            expect(ctx[2]).to.be.eq(BigNumber.from(0))
        })
    })

    describe("getMessageStatus()", function () {
        it("returns new for uninitialized signal", async () => {
            const { bridge } = await deployBridgeFixture()

            const messageStatus = await bridge.getMessageStatus(
                ethers.constants.HashZero
            )

            expect(messageStatus).to.be.eq(0)
        })

        it("returns for initiaized signal", async () => {
            const { owner, nonOwner, enabledDestChainId, bridge } =
                await deployBridgeFixture()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
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

            const tx = await bridge.sendMessage(message, {
                value: expectedAmount,
            })

            const receipt = await tx.wait()

            const [messageSentEvent] = receipt.events as any as Event[]

            const { signal } = (messageSentEvent as any).args

            expect(signal).not.to.be.eq(ethers.constants.HashZero)

            const messageStatus = await bridge.getMessageStatus(signal)

            expect(messageStatus).to.be.eq(0)
        })
    })

    describe("processMessage()", async function () {
        it("throws when message.gasLimit is 0 and msg.sender is not the message.owner", async () => {
            const { owner, nonOwner, bridge, enabledDestChainId } =
                await deployBridgeFixture()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: enabledDestChainId,
                owner: nonOwner.address,
                to: owner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 0,
                data: ethers.constants.HashZero,
                memo: "",
            }

            const proof = ethers.constants.HashZero

            await expect(
                bridge.processMessage(message, proof)
            ).to.be.revertedWith("B:forbidden")
        })

        it("throws message.destChainId is not block.chainId", async () => {
            const { owner, nonOwner, bridge } = await deployBridgeFixture()

            const message: Message = {
                id: 1,
                sender: nonOwner.address,
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

            const proof = ethers.constants.HashZero

            await expect(
                bridge.processMessage(message, proof)
            ).to.be.revertedWith("B:destChainId")
        })
    })
})
