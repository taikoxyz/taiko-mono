import { expect } from "chai"
import { AddressManager, Bridge } from "../../typechain"
import { ethers } from "hardhat"

type Message = {
    id: number
    sender: string
    srcChainId: number
    destChainId: number
    owner: string
    to: string
    refundAddress: string
    depositValue: number
    callValue: number
    processingFee: number
    gasLimit: number
    data: string
    memo: string
}
describe("Bridge", function () {
    async function deployBridgeFixture() {
        const [owner, nonOwner, etherVault] = await ethers.getSigners()

        // Deploying addressManager Contract
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

        // const libBridgeData = await (
        //     await ethers.getContractFactory("LibBridgeData")
        // ).deploy()

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

        // const libBridgeSend = await (
        //     await ethers.getContractFactory("LibBridgeSend")
        // ).deploy()

        // const libBridgeSignal = await (
        //     await ethers.getContractFactory("LibBridgeSignal")
        // ).deploy()

        const BridgeFactory = await ethers.getContractFactory("Bridge", {
            libraries: {
                LibBridgeProcess: libBridgeProcess.address,
                LibBridgeRetry: libBridgeRetry.address,
                // LibBridgeSend: libBridgeSend.address,
                // LibBridgeSignal: libBridgeSignal.address,
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
})
