import { expect } from "chai"
import { ethers } from "hardhat"
import RLP from "rlp"
import { TestLibBridgeSignal } from "../../../typechain"
import { Block, BlockHeader, EthGetProofResponse } from "../../utils/rpc"
// import { TAIKO_BRIDGE_MESSAGE } from "../../constants/messages"

describe("integration:LibBridgeSignal", function () {
    async function deployLibBridgeSignalFixture() {
        const [owner, nonOwner] = await ethers.getSigners()

        const libSignal: TestLibBridgeSignal = await (
            await ethers.getContractFactory("TestLibBridgeSignal")
        ).deploy()

        const testMessage = {
            id: 1,
            sender: owner.address,
            srcChainId: 1,
            destChainId: 2,
            owner: owner.address,
            to: owner.address,
            refundAddress: owner.address,
            depositValue: 0,
            callValue: 0,
            processingFee: 0,
            gasLimit: 0,
            data: ethers.constants.HashZero,
            memo: "",
        }

        return { owner, nonOwner, libSignal, testMessage }
    }
    async function deployLibBridgeDataFixture() {
        const libData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy()
        return { libData }
    }

    describe("sendSignal()", async function () {
        it("throws when sender is zero address", async function () {
            const { libSignal, testMessage } =
                await deployLibBridgeSignalFixture()

            const { libData } = await deployLibBridgeDataFixture()

            const signal = await libData.hashMessage(testMessage)

            await expect(
                libSignal.sendSignal(ethers.constants.AddressZero, signal)
            ).to.revertedWith("B:sender")
        })

        it("throws when signal is zero", async function () {
            const { owner, libSignal } = await deployLibBridgeSignalFixture()

            await expect(
                libSignal.sendSignal(owner.address, ethers.constants.HashZero)
            ).to.be.revertedWith("B:signal")
        })
    })
    describe("isSignalSent()", async function () {
        it("properly sent message should be received", async function () {
            const { owner, libSignal, testMessage } =
                await deployLibBridgeSignalFixture()

            const { libData } = await deployLibBridgeDataFixture()

            const signal = await libData.hashMessage(testMessage)

            await libSignal.sendSignal(owner.address, signal)

            expect(await libSignal.isSignalSent(owner.address, signal)).to.eq(
                true
            )
        })
    })

    describe("decode()", async function () {
        it.only("decodes", async function () {
            const { owner, libSignal } = await deployLibBridgeSignalFixture()

            // use this instead of ethers.provider.getBlock() beccause it doesnt have stateRoot
            // in the response
            const block: Block = await ethers.provider.send(
                "eth_getBlockByNumber",
                ["latest", false]
            )

            const logsBloom = block.logsBloom.toString().substring(2)

            const blockHeader: BlockHeader = {
                parentHash: block.parentHash,
                ommersHash: block.sha3Uncles,
                beneficiary: block.miner,
                stateRoot: block.stateRoot,
                transactionsRoot: block.transactionsRoot,
                receiptsRoot: block.receiptsRoot,
                logsBloom: logsBloom
                    .match(/.{1,64}/g)!
                    .map((s: string) => "0x" + s),
                difficulty: block.difficulty,
                height: block.number,
                gasLimit: block.gasLimit,
                gasUsed: block.gasUsed,
                timestamp: block.timestamp,
                extraData: block.extraData,
                mixHash: block.mixHash,
                nonce: block.nonce,
            }

            // rpc call to get the merkle proof what value is at key on the bridge contract
            const proof: EthGetProofResponse = await ethers.provider.send(
                "eth_getProof",
                [libSignal.address, ["0x1"], "0x1"]
            )

            // RLP encode the proof together for LibTrieProof to decode
            const encodedProof = ethers.utils.defaultAbiCoder.encode(
                ["bytes", "bytes"],
                [
                    RLP.encode(proof.accountProof),
                    RLP.encode(proof.storageProof[0].proof),
                ]
            )
            // encode the SignalProof struct from LibBridgeSignal
            const e = ethers.utils.defaultAbiCoder.encode(
                [
                    "tuple(tuple(bytes32 parentHash, bytes32 ommersHash, address beneficiary, bytes32 stateRoot, bytes32 transactionsRoot, bytes32 receiptsRoot, bytes32[8] logsBloom, uint256 difficulty, uint128 height, uint64 gasLimit, uint64 gasUsed, uint64 timestamp, bytes extraData, bytes32 mixHash, uint64 nonce) header, bytes proof)",
                ],
                [{ header: blockHeader, proof: encodedProof }]
            )

            console.log("SIGNALPROOF")
            console.log(e)

            const mkp = await libSignal.connect(owner).decode(e)

            console.log(mkp)
        })
    })
})
