import { expect } from "chai"
import hre, { ethers } from "hardhat"
import { Message } from "../../utils/message"
import { AddressManager, Bridge } from "../../../typechain"
import { getSlot } from "../../../tasks/utils"
import * as fs from "fs"
import * as path from "path"
const helpers = require("@nomicfoundation/hardhat-network-helpers")

describe("LibBridgeProcess", function () {
    function getStateSlot() {
        const buildInfoDir = path.join(
            __dirname,
            "../../../artifacts/build-info"
        )
        const contractPath =
            "contracts/test/bridge/libs/TestLibBridgeProcess.sol"
        const contractName = "TestLibBridgeProcess"

        for (const buildInfoJson of fs.readdirSync(buildInfoDir)) {
            const { output } = require(path.join(buildInfoDir, buildInfoJson))

            if (!output.contracts[contractPath]) continue

            const slotInfo = output.contracts[contractPath][
                contractName
            ].storageLayout.storage.find(({ label }: any) => label === "state")

            if (slotInfo) return Number(slotInfo.slot)
        }

        throw new Error("TestLibBridgeProcess.state slot number not found")
    }

    async function deployLibBridgeProcessFixture() {
        const [owner, nonOwner, etherVaultOwner] = await ethers.getSigners()

        // slot number of IBridge.State for TestLibBridgeProcess.
        // mapping destChains is at position 0
        // mapping messageStatus is at position 1
        // nextMessageId is at position 2
        // Context takes up 3 slots, starts at position 3
        const stateSlot = getStateSlot()

        const srcChainId = 1

        const messageOwner = ethers.Wallet.createRandom()

        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const etherVault = await (await ethers.getContractFactory("EtherVault"))
            .connect(etherVaultOwner)
            .deploy()

        await etherVault.deployed()

        await etherVault.init(addressManager.address)

        await etherVault.connect(etherVaultOwner).authorize(owner.address, true)
        const blockChainId = hre.network.config.chainId ?? 0
        await addressManager.setAddress(
            `${blockChainId}.ether_vault`,
            etherVault.address
        )
        // Sends initial value of 10 ether to EtherVault for receiveEther calls
        await owner.sendTransaction({
            to: etherVault.address,
            value: ethers.utils.parseEther("10.0"),
        })

        const libTrieLink = await (
            await ethers.getContractFactory("LibTrieProof")
        )
            .connect(owner)
            .deploy()
        await libTrieLink.deployed()

        const libProcessLink = await (
            await ethers.getContractFactory("LibBridgeProcess", {
                libraries: {
                    LibTrieProof: libTrieLink.address,
                },
            })
        )
            .connect(owner)
            .deploy()
        await libProcessLink.deployed()

        const libProcess = await (
            await ethers.getContractFactory("TestLibBridgeProcess", {
                libraries: {
                    LibBridgeProcess: libProcessLink.address,
                },
            })
        )
            .connect(owner)
            .deploy()

        await libProcess.init(addressManager.address)

        const testLibData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy()

        await etherVault
            .connect(etherVaultOwner)
            .authorize(libProcess.address, true)

        const MessageStatus = {
            NEW: 0,
            RETRIABLE: 1,
            DONE: 2,
        }

        return {
            owner,
            srcChainId,
            messageOwner,
            libProcess,
            MessageStatus,
            stateSlot,
            blockChainId,
            nonOwner,
            testLibData,
            addressManager,
        }
    }
    async function deployBridgeFixture() {
        const [owner, etherVault] = await ethers.getSigners()

        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const chainId = hre.network.config.chainId ?? 0

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

        const headerSync = await (
            await ethers.getContractFactory("TestHeaderSync")
        ).deploy()

        await addressManager.setAddress(`${chainId}.taiko`, headerSync.address)

        return {
            bridge,
            headerSync,
        }
    }

    describe("processMessage()", async function () {
        it("should throw if gaslimit == 0 & msg.sender != message.owner", async function () {
            const { owner, srcChainId, nonOwner, libProcess, blockChainId } =
                await deployLibBridgeProcessFixture()
            const message: Message = {
                id: 1,
                sender: nonOwner.address,
                srcChainId: srcChainId,
                destChainId: blockChainId,
                owner: nonOwner.address,
                to: owner.address,
                refundAddress: nonOwner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 0,
                data: ethers.constants.HashZero,
                memo: "",
            }
            await expect(
                libProcess.processMessage(message, ethers.constants.HashZero)
            ).to.be.revertedWith("B:forbidden")
        })

        it("should throw if message.destChain != block.chainId", async function () {
            const { owner, srcChainId, nonOwner, libProcess, blockChainId } =
                await deployLibBridgeProcessFixture()
            const badBlockChainId = blockChainId + 1
            const message: Message = {
                id: 1,
                sender: nonOwner.address,
                srcChainId: srcChainId,
                destChainId: badBlockChainId,
                owner: nonOwner.address,
                to: owner.address,
                refundAddress: nonOwner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100000000,
                data: ethers.constants.HashZero,
                memo: "",
            }
            await expect(
                libProcess.processMessage(message, ethers.constants.HashZero)
            ).to.be.revertedWith("B:destChainId")
        })

        it("should throw if message's status is not NEW", async function () {
            const {
                owner,
                srcChainId,
                nonOwner,
                libProcess,
                testLibData,
                blockChainId,
                MessageStatus,
                stateSlot,
            } = await deployLibBridgeProcessFixture()

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
                gasLimit: 100000000,
                data: ethers.constants.HashZero,
                memo: "",
            }

            const signal = await testLibData.hashMessage(message)

            await helpers.setStorageAt(
                libProcess.address,
                await getSlot(hre, signal, stateSlot + 1),
                MessageStatus.RETRIABLE
            )

            await expect(
                libProcess.processMessage(message, ethers.constants.HashZero)
            ).to.be.revertedWith("B:status")
        })

        it("should throw if signal has not been received", async function () {
            const {
                owner,
                srcChainId,
                nonOwner,
                libProcess,
                blockChainId,
                addressManager,
            } = await deployLibBridgeProcessFixture()
            const { bridge } = await deployBridgeFixture()

            await addressManager.setAddress(
                `${srcChainId}.bridge`,
                bridge.address
            )

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
                gasLimit: 100000000,
                data: ethers.constants.HashZero,
                memo: "",
            }
            await expect(
                libProcess.processMessage(message, ethers.constants.HashZero)
            ).to.be.reverted

            // Reverts because there is no HeaderSync, can't test without
        })

        it("if message fails, refund should go to the intended account and amount", async function () {
            await deployLibBridgeProcessFixture()
        })

        it("should pass properly, message should be processed and marked DONE", async function () {
            await deployLibBridgeProcessFixture()
        })
    })
})
