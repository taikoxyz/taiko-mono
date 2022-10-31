// import { expect } from "chai"
import { expect } from "chai"
import { ethers } from "hardhat"
// import RLP from "rlp"
import { Message } from "../utils/message"
// import { EthGetProofResponse } from "../utils/rpc"

// describe("integration:LibTrieProof", function () {
describe("LibTrieProof", function () {
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
        it.only("verifies", async function () {
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
            // const proof: EthGetProofResponse = await ethers.provider.send(
            //     "eth_getProof",
            //     [bridge.address, [key], block.hash]
            // )

            // sconst stateRoot = block.stateRoot

            // RLP encode the proof together for LibTrieProof to decode
            // const encodedProof = ethers.utils.defaultAbiCoder.encode(
            //     ["bytes", "bytes"],
            //     [
            //         RLP.encode(proof.accountProof),
            //         RLP.encode(proof.storageProof[0].proof),
            //     ]
            // )

            await testLibTreProof.verify2(
                "0x263bd678cc93ce329cc2a7a2d03e24eb1eecd632967bad0d61f276ba0040bab6",
                "0xB12d6112D64B213880Fa53F815aF1F29c91CaCe9",
                "0x61f9712a1ed291063c5b60a49f2897447573c1c14413cd20bf6927b568fa0254",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000283f90280b901b4f901b1a06df290b81f3211bb9895503ff6594826aac547504ac91cecfdd01dbb09122b60a0b91242f13755118b8610785df3de942d6bdf3771a5f723172a6783020266f213a004ac837af05e8a3312d06ccb46dbaa5fc43ca448840ef0d02e72f9d34e65709680a02c1e0971068058bd212c3e1f7def5b339ea5a4427d883f1b130681ab9b18bff0a0b9e5b7328855eaba8092e295435990f12a6bf289b2da875dfad1a1e8214934efa07ffab3684a9dbf9086a73ec3d46a9a57084666aadc3260d8333742346f845d13a014bb918dacf676f9bd5744c898e83df4a7ee9642141e655f42ddcefb0cfe92a780a0a440b1d6a11e7b48149843d2ab6954356fe5a6f62182515299bd6eef91c4910680a0fe95046e78caeaa31a6f247bae2a208c5be4e7c3e0c4df663b422dc30d9d7c82a010217af24a293fe495562b526b841c67c71f1b32e78304a20b347f2e4d3e8149a0771fa9cf8f7c1d39de0bb7390833ae03887b158b9f0311b913094b6001d22bb8a073d5cc524c5bbfdcd98aa21dda3e62065692ce4d8bb500d21c1bb8263d153de0a0d4f3e2b61a011a52de4fc8706cff7dda793c068a596a086441117e6befdba37380b853f8518080a029c39e709988ced1402cb151964ca8b0ca4ba3362006dbd80b471d64f3d0eb23a09fadc8e933d93b558e7509b5cc3e09b5affe6175a989d0127e8ecf673f50de6380808080808080808080808080b872f870a02007649327f6988d577705dafc8f0aec1be762e1dfdee8fcd38a2a6377e95e0fb84df84b0187038d7ea4c68000a012be01250afd355dd0b8e1db0f0ded0ed9152ae700f005d2f53a04b0cbde9ab6a0659823b90ae3f4663eb4d3cab3b1549fddecbc721742b4e163d2ef9cee96a3660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013ef9013bb90114f901118080a04fc5f13ab2f9ba0c2da88b0151ab0e7cf4d85d08cca45ccd923c6ab76323eb28a0a7795a557494def6dc9d2f8380e036f8a9b0421099802de92b27ab9e1749624ea0bee52e2794e399ca3dd7a4e8f8dfa3cae0d1f9e4f3105cc63df57911c70be8bf808080a07394a09684ef3b2c87e9e2a753eb4ac78e2047b980e16d2e2133aee78946370d80a0a12cad065eeac014f805012ed7b2df2ab0501d679a43131dc5fffb4a52feabf5a0f4984a11f61a2921456141df88de6e1a710d28681b91af794c5a721e47839cd7a09dbe337aabd86699cd20073eb93e928a87bc1af7814f349aa01d77a91089a5d68080a0f5ae72cc5e9e74189b3b3f95f09213c8c607021024170c424ce3e4cda3c12e1580a3e2a036edb9fccde129b338c6b439e36ea4fd9d9feaa2c24a8b3f97949eafccb74e34010000"
            )
        })
    })
})
