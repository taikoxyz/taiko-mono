// import { expect } from "chai"
import { ethers } from "hardhat"
import { Message } from "../../utils/message"

describe("LibBridgeRetry", function () {
    async function deployLibBridgeRetryFixture() {
        const [owner, nonOwner, etherVault] = await ethers.getSigners()

        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()
        await addressManager.setAddress("ether_vault", etherVault.address)

        const libRetryLink = await (
            await ethers.getContractFactory("LibBridgeRetry")
        ).deploy()

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

        const libData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy()

        return { owner, nonOwner, libRetry, libData }
    }

    async function getSlot(signal: any) {
        return ethers.utils.solidityKeccak256(
            ["bytes32", "uint256"],
            [signal, 1]
        )
    }

    describe("retryMessage()", async function () {
        it.only("testing setStorageAt", async function () {
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

            const signal = await libData.hashMessage(message)
            console.log(signal)
            console.log(
                await ethers.provider.getStorageAt(
                    libRetry.address,
                    getSlot(signal)
                )
            )
            // console.log(await web3.eth.getStorageAt(libRetry.address, 0))
        })

        it("should throw if message.gaslimit == 0 && msg.sender != message.owner", async function () {
            await deployLibBridgeRetryFixture()
        })

        it("should throw if lastAttempt == true && msg.sender != message.owner", async function () {
            await deployLibBridgeRetryFixture()
        })

        it("should throw if message status is not RETRIABLE", async function () {
            await deployLibBridgeRetryFixture()
        })

        it("should throw if message.gaslimit == 0 && msg.sender != message.owner", async function () {
            await deployLibBridgeRetryFixture()
        })

        it("should successfully pass (maybe add event for this case)", async function () {
            await deployLibBridgeRetryFixture()
        })
    })
})
