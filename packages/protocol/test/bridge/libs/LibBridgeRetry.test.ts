// import { expect } from "chai"
import { expect } from "chai"
import hre, { ethers } from "hardhat"
import { Message } from "../../utils/message"
const Web3 = require("web3")
const helpers = require("@nomicfoundation/hardhat-network-helpers")

describe("LibBridgeRetry", function () {
    async function deployLibBridgeRetryFixture() {
        const [owner, nonOwner, etherVault] = await ethers.getSigners()

        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()
        const blockChainId = hre.network.config.chainId ?? 0
        await addressManager.setAddress(
            `${blockChainId}.ether_vault`,
            etherVault.address
        )

        const libRetryLink = await (
            await ethers.getContractFactory("LibBridgeRetry")
        ).deploy()
        await libRetryLink.deployed()

        const libRetry = await (
            await ethers.getContractFactory("TestLibBridgeRetry", {
                libraries: {
                    LibBridgeRetry: libRetryLink.address,
                },
            })
        )
            .connect(owner)
            .deploy()
        await libRetry.init(addressManager.address)
        await libRetry.deployed()

        const libData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy()

        const MessageStatus = {
            NEW: 0,
            RETRIABLE: 1,
            DONE: 2,
        }

        return { owner, nonOwner, libRetry, libData, MessageStatus }
    }

    async function getSlot(signal: any, mappingSlot: any) {
        return ethers.utils.solidityKeccak256(
            ["bytes", "uint256"],
            [signal, mappingSlot]
        )
    }

    async function decode(type: string, data: any) {
        const web3 = new Web3("http://localhost:8545")
        return await web3.eth.abi.decodeParameter(type, data)
    }

    describe("retryMessage()", async function () {
        it.skip("testing setStorageAt", async function () {
            const { owner, nonOwner, libRetry, libData } =
                await deployLibBridgeRetryFixture()

            // mapping state.messageStatus is in slot 1 of TestLibBridgeRetry's contract storage
            // messageStatus = mapping(bytes32 => MessageStatus)
            // we are trying to modify data at messageStatus[signal] where signal is bytes32
            // that data is thus theoretically stored at keccak256(signal . 1) where . is concatenation

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

            // console.log(
            //     "buf: ",
            //     await decode(
            //         "uint256",
            //         await ethers.provider.getStorageAt(libRetry.address, 201)
            //     )
            // )
            // console.log(
            //     "buf: ",
            //     await decode(
            //         "uint256",
            //         await ethers.provider.getStorageAt(libRetry.address, 1)
            //     )
            // )
            const signal = await libData.hashMessage(message)
            console.log("signal: ", signal)
            console.log(
                await decode(
                    "uint256",
                    await ethers.provider.getStorageAt(
                        libRetry.address,
                        getSlot(signal, 202)
                    )
                )
            )
            // console.log(
            //     await decode(
            //         "uint256",
            //         await ethers.provider.getStorageAt(
            //             libRetry.address,
            //             getSlot2(signal)
            //         )
            //     )
            // )
            // console.log(await web3.eth.getStorageAt(libRetry.address, 0))
        })

        it("should throw if message.gaslimit == 0 && msg.sender != message.owner", async function () {
            const { owner, nonOwner, libRetry } =
                await deployLibBridgeRetryFixture()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: nonOwner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 0,
                data: ethers.constants.HashZero,
                memo: "",
            }

            await expect(
                libRetry.retryMessage(message, false)
            ).to.be.revertedWith("B:denied")
        })

        it("should throw if lastAttempt == true && msg.sender != message.owner", async function () {
            const { owner, nonOwner, libRetry } =
                await deployLibBridgeRetryFixture()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: nonOwner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 1000000,
                data: ethers.constants.HashZero,
                memo: "",
            }

            await expect(
                libRetry.retryMessage(message, true)
            ).to.be.revertedWith("B:denied")
        })

        it("should throw if message status is not RETRIABLE", async function () {
            const { owner, nonOwner, libRetry } =
                await deployLibBridgeRetryFixture()

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
                gasLimit: 300000,
                data: ethers.constants.HashZero,
                memo: "",
            }

            await expect(
                libRetry.retryMessage(message, false)
            ).to.be.revertedWith("B:notFound")
        })

        it("should fail, but since lastAttempt == true messageStatus should be set to DONE", async function () {
            const { owner, libRetry, libData, MessageStatus } =
                await deployLibBridgeRetryFixture()

            const testReceiver = await (
                await ethers.getContractFactory("TestReceiver")
            ).deploy()

            await testReceiver.deployed()

            const destChainId = 5
            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: destChainId,
                owner: owner.address,
                to: testReceiver.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 300000,
                data: ethers.constants.HashZero,
                memo: "",
            }

            const signal = await libData.hashMessage(message)

            await helpers.setStorageAt(
                libRetry.address,
                await getSlot(signal, 202),
                MessageStatus.RETRIABLE
            )

            await libRetry.retryMessage(message, true)

            // can also check for refund to go to the right place, with right amount
            expect(
                await decode(
                    "uint256",
                    await ethers.provider.getStorageAt(
                        libRetry.address,
                        getSlot(signal, 202)
                    )
                )
            ).to.equal(MessageStatus.DONE)
        })

        it("should successfully pass (maybe add event for this case)", async function () {
            const { owner, libRetry, libData, MessageStatus } =
                await deployLibBridgeRetryFixture()

            const testReceiver = await (
                await ethers.getContractFactory("TestReceiver")
            ).deploy()

            await testReceiver.deployed()

            const ABI = ["function receiveTokens(uint256) payable"]
            const iface = new ethers.utils.Interface(ABI)
            const data = iface.encodeFunctionData("receiveTokens", [1])

            const destChainId = 5
            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: destChainId,
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

            await helpers.setStorageAt(
                libRetry.address,
                await getSlot(signal, 202),
                MessageStatus.RETRIABLE
            )

            await libRetry.retryMessage(message, false)

            await expect(
                await decode(
                    "uint256",
                    await ethers.provider.getStorageAt(
                        libRetry.address,
                        getSlot(signal, 202)
                    )
                )
            ).to.equal(MessageStatus.DONE)
        })
    })
})
