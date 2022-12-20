import { expect } from "chai"
import { BigNumber, Signer } from "ethers"
import { ethers } from "hardhat"
import {
    AddressManager,
    Bridge,
    EtherVault,
    LibTrieProof,
} from "../../typechain"
import { Message } from "../utils/message"

export async function deployBridge(
    signer: Signer,
    addressManager: AddressManager,
    destChain: number,
    srcChain: number
): Promise<{ bridge: Bridge; etherVault: EtherVault }> {
    const libTrieProof: LibTrieProof = await (
        await ethers.getContractFactory("LibTrieProof")
    )
        .connect(signer)
        .deploy()

    const libBridgeProcess = await (
        await ethers.getContractFactory("LibBridgeProcess", {
            libraries: {
                LibTrieProof: libTrieProof.address,
            },
        })
    )
        .connect(signer)
        .deploy()

    const libBridgeRetry = await (
        await ethers.getContractFactory("LibBridgeRetry")
    )
        .connect(signer)
        .deploy()

    const BridgeFactory = await ethers.getContractFactory("Bridge", {
        libraries: {
            LibBridgeProcess: libBridgeProcess.address,
            LibBridgeRetry: libBridgeRetry.address,
            LibTrieProof: libTrieProof.address,
        },
    })

    const bridge: Bridge = await BridgeFactory.connect(signer).deploy()

    await bridge.connect(signer).init(addressManager.address)

    await bridge.connect(signer).enableDestChain(destChain, true)

    const etherVault: EtherVault = await (
        await ethers.getContractFactory("EtherVault")
    )
        .connect(signer)
        .deploy()

    await etherVault.connect(signer).init(addressManager.address)

    await etherVault.connect(signer).authorize(bridge.address, true)

    await etherVault.connect(signer).authorize(await signer.getAddress(), true)

    await addressManager.setAddress(
        `${srcChain}.ether_vault`,
        etherVault.address
    )

    await signer.sendTransaction({
        to: etherVault.address,
        value: BigNumber.from(100000000),
        gasLimit: 1000000,
    })

    return { bridge, etherVault }
}
describe("Bridge", function () {
    async function deployBridgeFixture() {
        const [owner, nonOwner] = await ethers.getSigners()

        const { chainId } = await ethers.provider.getNetwork()

        const srcChainId = chainId

        const enabledDestChainId = srcChainId + 1

        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const { bridge: l1Bridge, etherVault: l1EtherVault } =
            await deployBridge(
                owner,
                addressManager,
                enabledDestChainId,
                srcChainId
            )

        // deploy protocol contract
        return {
            owner,
            nonOwner,
            l1Bridge,
            addressManager,
            enabledDestChainId,
            l1EtherVault,
            srcChainId,
        }
    }

    describe("sendMessage()", function () {
        it("throws when owner is the zero address", async () => {
            const { owner, nonOwner, l1Bridge } = await deployBridgeFixture()

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

            await expect(l1Bridge.sendMessage(message)).to.be.revertedWith(
                "B:owner"
            )
        })

        it("throws when dest chain id is same as block.chainid", async () => {
            const { owner, nonOwner, l1Bridge } = await deployBridgeFixture()

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

            await expect(l1Bridge.sendMessage(message)).to.be.revertedWith(
                "B:destChainId"
            )
        })

        it("throws when dest chain id is not enabled", async () => {
            const { owner, nonOwner, l1Bridge } = await deployBridgeFixture()

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

            await expect(l1Bridge.sendMessage(message)).to.be.revertedWith(
                "B:destChainId"
            )
        })

        it("throws when msg.value is not the same as expected amount", async () => {
            const { owner, nonOwner, l1Bridge, enabledDestChainId } =
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

            await expect(l1Bridge.sendMessage(message)).to.be.revertedWith(
                "B:value"
            )
        })

        it("emits event and is successful when message is valid, ether_vault receives the expectedAmount", async () => {
            const {
                owner,
                nonOwner,
                l1EtherVault,
                l1Bridge,
                enabledDestChainId,
            } = await deployBridgeFixture()

            const etherVaultOriginalBalance = await ethers.provider.getBalance(
                l1EtherVault.address
            )

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
                l1Bridge.sendMessage(message, {
                    value: expectedAmount,
                })
            ).to.emit(l1Bridge, "MessageSent")

            const etherVaultUpdatedBalance = await ethers.provider.getBalance(
                l1EtherVault.address
            )

            expect(etherVaultUpdatedBalance).to.be.eq(
                etherVaultOriginalBalance.add(expectedAmount)
            )
        })
    })

    describe("sendSignal()", async function () {
        it("throws when signal is empty", async function () {
            const { owner, l1Bridge } = await deployBridgeFixture()

            await expect(
                l1Bridge.connect(owner).sendSignal(ethers.constants.HashZero)
            ).to.be.revertedWith("B:signal")
        })

        it("sends signal, confirms it was sent", async function () {
            const { owner, l1Bridge } = await deployBridgeFixture()

            const hash =
                "0xf2e08f6b93d8cf4f37a3b38f91a8c37198095dde8697463ca3789e25218a8e9d"
            await expect(l1Bridge.connect(owner).sendSignal(hash))
                .to.emit(l1Bridge, "SignalSent")
                .withArgs(owner.address, hash)

            const isSignalSent = await l1Bridge.isSignalSent(
                owner.address,
                hash
            )
            expect(isSignalSent).to.be.eq(true)
        })
    })

    describe("isDestChainEnabled()", function () {
        it("is disabled for unabled chainIds", async () => {
            const { l1Bridge } = await deployBridgeFixture()

            const enabled = await l1Bridge.isDestChainEnabled(68)
            expect(enabled).to.be.eq(false)
        })

        it("is enabled for enabled chainId", async () => {
            const { l1Bridge, enabledDestChainId } = await deployBridgeFixture()

            const enabled = await l1Bridge.isDestChainEnabled(
                enabledDestChainId
            )
            expect(enabled).to.be.eq(true)
        })
    })

    describe("context()", function () {
        it("returns unitialized context", async () => {
            const { l1Bridge } = await deployBridgeFixture()

            const ctx = await l1Bridge.context()
            expect(ctx[0]).to.be.eq(ethers.constants.HashZero)
            expect(ctx[1]).to.be.eq(ethers.constants.AddressZero)
            expect(ctx[2]).to.be.eq(BigNumber.from(0))
        })
    })

    describe("getMessageStatus()", function () {
        it("returns new for uninitialized signal", async () => {
            const { l1Bridge } = await deployBridgeFixture()

            const messageStatus = await l1Bridge.getMessageStatus(
                ethers.constants.HashZero
            )

            expect(messageStatus).to.be.eq(0)
        })

        it("returns for initiaized signal", async () => {
            const { owner, nonOwner, enabledDestChainId, l1Bridge } =
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

            const tx = await l1Bridge.sendMessage(message, {
                value: expectedAmount,
            })

            const receipt = await tx.wait()

            const [messageSentEvent] = receipt.events as any as Event[]

            const { signal } = (messageSentEvent as any).args

            expect(signal).not.to.be.eq(ethers.constants.HashZero)

            const messageStatus = await l1Bridge.getMessageStatus(signal)

            expect(messageStatus).to.be.eq(0)
        })
    })

    describe("processMessage()", async function () {
        it("throws when message.gasLimit is 0 and msg.sender is not the message.owner", async () => {
            const { owner, nonOwner, l1Bridge, enabledDestChainId } =
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
                l1Bridge.processMessage(message, proof)
            ).to.be.revertedWith("B:forbidden")
        })

        it("throws message.destChainId is not block.chainId", async () => {
            const { owner, nonOwner, l1Bridge } = await deployBridgeFixture()

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
                l1Bridge.processMessage(message, proof)
            ).to.be.revertedWith("B:destChainId")
        })
    })
})
