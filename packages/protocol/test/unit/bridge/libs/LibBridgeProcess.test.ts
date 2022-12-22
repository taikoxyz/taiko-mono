import * as helpers from "@nomicfoundation/hardhat-network-helpers"
import { expect } from "chai"
import hre, { ethers } from "hardhat"
import * as fs from "fs"
import * as path from "path"
import { getSlot, MessageStatus } from "../../../../tasks/utils"
import { Message } from "../../utils/message"
import {
    AddressManager,
    EtherVault,
    TestLibBridgeData,
    TestLibBridgeProcess,
} from "../../../typechain"

describe("LibBridgeProcess", async function () {
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

    let owner: any
    let nonOwner: any
    let etherVaultOwner: any
    let addressManager: AddressManager
    let etherVault: EtherVault
    let libTrieLink
    let libProcessLink
    let libProcess: TestLibBridgeProcess
    let testLibData: TestLibBridgeData
    const stateSlot = getStateSlot()
    const srcChainId = 1
    const blockChainId = hre.network.config.chainId ?? 0

    before(async function () {
        ;[owner, nonOwner, etherVaultOwner] = await ethers.getSigners()
    })

    beforeEach(async function () {
        addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        etherVault = await (await ethers.getContractFactory("EtherVault"))
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

        libTrieLink = await (await ethers.getContractFactory("LibTrieProof"))
            .connect(owner)
            .deploy()
        await libTrieLink.deployed()

        libProcessLink = await (
            await ethers.getContractFactory("LibBridgeProcess", {
                libraries: {
                    LibTrieProof: libTrieLink.address,
                },
            })
        )
            .connect(owner)
            .deploy()
        await libProcessLink.deployed()

        libProcess = await (
            await ethers.getContractFactory("TestLibBridgeProcess", {
                libraries: {
                    LibBridgeProcess: libProcessLink.address,
                },
            })
        )
            .connect(owner)
            .deploy()

        await libProcess.init(addressManager.address)

        testLibData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy()

        await etherVault
            .connect(etherVaultOwner)
            .authorize(libProcess.address, true)
    })

    describe("processMessage()", async function () {
        it("should throw if gaslimit == 0 & msg.sender != message.owner", async function () {
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
    })
})
