import { expect } from "chai"
import { ENOBUFS } from "constants"
import { BigNumber } from "ethers"
import { ethers } from "hardhat"
import RLP from "rlp"
import { Message } from "../utils/message"
import { EthGetProofResponse } from "../utils/rpc"

describe("integration:LibTrieProof", function () {
    async function deployLibTrieProofFixture() {
        const libTrieProof = await (
            await ethers.getContractFactory("LibTrieProof")
        ).deploy()

        const testLibTreProof = await (
            await ethers.getContractFactory("TestLibTrieProof", {
                libraries: {
                    LibTrieProof: libTrieProof.address,
                },
            })
        ).deploy()

        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const { chainId } = await ethers.provider.getNetwork()

        await addressManager.setAddress(
            `${chainId}.ether_vault`,
            "0xEA3dD11036f668F08940E13e3bcB097C93b09E07"
        )

        const libBridgeRetry = await (
            await ethers.getContractFactory("LibBridgeRetry")
        ).deploy()

        const libBridgeProcess = await (
            await ethers.getContractFactory("LibBridgeProcess", {
                libraries: {
                    LibTrieProof: libTrieProof.address,
                },
            })
        ).deploy()

        const BridgeFactory = await ethers.getContractFactory("Bridge", {
            libraries: {
                LibBridgeProcess: libBridgeProcess.address,
                LibBridgeRetry: libBridgeRetry.address,
                LibTrieProof: libTrieProof.address,
            },
        })

        const bridge = await BridgeFactory.deploy()

        await bridge.init(addressManager.address)

        const [owner] = await ethers.getSigners()

        return { owner, testLibTreProof, bridge }
    }
    describe("verify()", function () {
        it("verifies", async function () {
            const { owner, testLibTreProof, bridge } =
                await deployLibTrieProofFixture()

            const { chainId } = await ethers.provider.getNetwork()
            const srcChainId = chainId
            const destChainId = srcChainId + 1
            await (await bridge.enableDestChain(destChainId, true)).wait()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: srcChainId,
                destChainId: destChainId,
                owner: owner.address,
                to: owner.address,
                refundAddress: owner.address,
                depositValue: 1000,
                callValue: 1000,
                processingFee: 1000,
                gasLimit: 10000,
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

            const sender = bridge.address

            const key = ethers.utils.keccak256(
                ethers.utils.solidityPack(
                    ["address", "bytes32"],
                    [sender, signal]
                )
            )

            // use this instead of ethers.provider.getBlock() beccause it doesnt have stateRoot
            // in the response
            const block: { stateRoot: string; number: string; hash: string } =
                await ethers.provider.send("eth_getBlockByNumber", [
                    "latest",
                    false,
                ])

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                bridge.address,
                key,
                block.number
            )
            // make sure it equals 1 so our proof will pass
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            )
            // rpc call to get the merkle proof what value is at key on the bridge contract
            const proof: EthGetProofResponse = await ethers.provider.send(
                "eth_getProof",
                [bridge.address, [key], block.hash]
            )

            const stateRoot = block.stateRoot

            // RLP encode the proof together for LibTrieProof to decode
            const encodedProof = ethers.utils.defaultAbiCoder.encode(
                ["bytes", "bytes"],
                [
                    RLP.encode(proof.accountProof),
                    RLP.encode(proof.storageProof[0].proof),
                ]
            )
            // proof verifies the storageValue at key is 1
            await testLibTreProof.verify(
                stateRoot,
                bridge.address,
                key,
                "1",
                encodedProof
            )
        })
    })
})
