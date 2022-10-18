import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("Test Bridge Libs", function () {
    let signers: any
    let addressManager: any
    let bridge: any
    let testMessage: any
    let libData: any
    let testTypes: any
    let testVar: any

    before(async function () {
        signers = await ethers.getSigners()

        // deploy addressManager
        addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        // deploy Libraries needed to link to Bridge
        const libTrie = await (
            await ethers.getContractFactory("LibTrieProof")
        ).deploy()

        const libProcess = await (
            await ethers.getContractFactory("LibBridgeProcess", {
                libraries: {
                    LibTrieProof: libTrie.address,
                },
            })
        ).deploy()

        const libRetry = await (
            await ethers.getContractFactory("LibBridgeRetry")
        ).deploy()

        // deploying Bridge
        bridge = await (
            await ethers.getContractFactory("Bridge", {
                libraries: {
                    LibBridgeProcess: libProcess.address,
                    LibBridgeRetry: libRetry.address,
                    LibTrieProof: libTrie.address,
                },
            })
        ).deploy()
        await bridge.init(addressManager.address)

        // dummy struct to test with
        testMessage = {
            id: 1,
            sender: signers[0].address,
            srcChainId: 1,
            destChainId: 2,
            owner: signers[0].address,
            to: signers[1].address,
            refundAddress: signers[0].address,
            depositValue: 0,
            callValue: 0,
            processingFee: 0,
            gasLimit: 0,
            data: ethers.constants.HashZero,
            memo: "",
        }

        testTypes = [
            "string",
            "tuple(uint256 id, address sender, uint256 srcChainId, uint256 destChainId, address owner, address to, address refundAddress, uint256 depositValue, uint256 callValue, uint256 processingFee, uint256 gasLimit, bytes data, string memo)",
        ]

        testVar = ["TAIKO_BRIDGE_MESSAGE", testMessage]
    })

    describe("LibBridgeData", async function () {
        before(async function () {
            libData = await (
                await ethers.getContractFactory("TestLibBridgeData")
            ).deploy()
        })

        it.only("should return properly hashed message", async function () {
            const hashed = await libData.hashMessage(testMessage)
            const expectedEncoded = await ethers.utils.defaultAbiCoder.encode(
                testTypes,
                testVar
            )

            const expectedHash = await ethers.utils.keccak256(expectedEncoded)

            expect(expectedHash).to.be.eq(hashed)
        })
    })

    describe("LibBridgeSend", async function () {
        // describe("sendSignal()", async function () {
        //     it.only("throws when sender is zero address", async function () {
        //         const { owner, nonOwner, bridge, enabledDestChainId } =
        //             await deployBridgeFixture()
        //         const message: Message = {
        //             id: 1,
        //             sender: owner.address,
        //             srcChainId: 1,
        //             destChainId: enabledDestChainId,
        //             owner: owner.address,
        //             to: nonOwner.address,
        //             refundAddress: owner.address,
        //             depositValue: 1,
        //             callValue: 1,
        //             processingFee: 1,
        //             gasLimit: 100,
        //             data: ethers.constants.HashZero,
        //             memo: "",
        //         }
        //         const expectedAmount =
        //             message.depositValue + message.callValue + message.processingFee
        //         const signal = await bridge.sendMessage(message, {
        //             value: expectedAmount,
        //         })
        //         await signal.wait()
        //         expect(
        //             await bridge
        //                 .connect(ethers.constants.AddressZero)
        //                 .sendSignal(signal)
        //         ).to.be.revertedWith("B:sender")
        //     })
        // })
    })
})
