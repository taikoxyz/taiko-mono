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

    describe("sendSignal()", async function () {
        it.only("throws when sender is zero address", async function () {
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

            const expectedAmount =
                message.depositValue + message.callValue + message.processingFee
            const signal = await bridge.sendMessage(message, {
                value: expectedAmount,
            })
            await signal.wait()

            expect(
                await bridge
                    .connect(ethers.constants.AddressZero)
                    .sendSignal(signal)
            ).to.be.revertedWith("B:sender")
        })
    })
})
