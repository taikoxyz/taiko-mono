import { expect } from "chai"
import { ethers } from "hardhat"
import RLP from "rlp"
import { Message } from "../utils/message"
import { EthGetProofResponse } from "../utils/rpc"

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

            await testLibTreProof.verify(
                stateRoot,
                bridge.address,
                key,
                "1",
                encodedProof
            )
        })

        it.only("verifies 2", async function () {
            const { testLibTreProof } = await deployLibTrieProofFixture()

            await testLibTreProof.verify2(
                "0x13baa47952b680f975ca07ba1adb1f931d90a16829822071d63df59cee8ee7e9",
                "0xB12d6112D64B213880Fa53F815aF1F29c91CaCe9",
                "0x12cee5c17a30797bfab3c62a1aee9d2c15dded2e2830b6958f994c3761168dc4",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003a07fdff761f7882b20f1cf779d36b85390d6856e349950472da073bac9659b8b0b1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347000000000000000000000000000000000000000000000000000000000000000013baa47952b680f975ca07ba1adb1f931d90a16829822071d63df59cee8ee7e9ee3574abb74981696a6f0d52bbbbc0561cebaf2fc69438ac0bf4f9fd38e5ad0a775663501d391f5a6c74fd3b957e5f92589d37f15696d7babf785e144f35d8f4004000080000000000000000000000000000000000000000000000100000000000000000000000000000000400040000000000000000000100000000002000000080000000000000001000080000002000000000000000000000000000000000000000001000000008000000000804000000000000000000000000100001000040000000000000000000000000000001000000000000000000000000400000004200000000000002000000000000004000000000000000004180000004000000000000028000001000000000000000000000004000001000000000000000000000100000000040000000000000400020000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000006b0000000000000000000000000000000000000000000000000000000000a9623c00000000000000000000000000000000000000000000000000000000000430a3000000000000000000000000000000000000000000000000000000006362144200000000000000000000000000000000000000000000000000000000000002c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000061d883010b00846765746888676f312e31382e37856c696e7578000000000000000bbc413ad1f0ef007e452d046d42ba1be9a6703289b57d2f970fbe122c67b131689d2b98de98cea5ad991b8c9fdae72696bb7d1eb8901c843ddb6aa94bc7f24e010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004c0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000283f90280b90194f90191a06df290b81f3211bb9895503ff6594826aac547504ac91cecfdd01dbb09122b60a0ed6f23e49b710138f5121226288e2234457d2088dde2c8aaa7dc29104724e8858080a02c1e0971068058bd212c3e1f7def5b339ea5a4427d883f1b130681ab9b18bff0a0b9e5b7328855eaba8092e295435990f12a6bf289b2da875dfad1a1e8214934efa07ffab3684a9dbf9086a73ec3d46a9a57084666aadc3260d8333742346f845d13a058cf81fb6e5b144994333e0425787fce1fdc6a5421d709b8749885d897b883bf80a0a440b1d6a11e7b48149843d2ab6954356fe5a6f62182515299bd6eef91c4910680a047f21823fad38ec0831b4bc9cd16a195f322edda06ed87694bf14ab60ac098cda015005513075168a86b8d7de8c8212b34596e557fcccc2a55aea0e099e50935c8a061b752fc9599ce7812d74075e8f7a4da31600d68bc22026cd849e513f2d700fea07b3c580e8b0b52ce45881064c3d5625b8938a18eb691dba5002bc05acf3b2363a00f68a2bbae7b224cedc961564c5d019983273db0eae71146197862e49b9bfa3380b873f8718080a0ad34c9a2526a098200dac9736410197d5db805640ec29fb39a0108e4fbd22051a09fadc8e933d93b558e7509b5cc3e09b5affe6175a989d0127e8ecf673f50de63808080808080a00bc17f40abec1b7d109d8297f49ca0653e31b66a49769e66c2d7d3ad0535ba5b808080808080b872f870a02007649327f6988d577705dafc8f0aec1be762e1dfdee8fcd38a2a6377e95e0fb84df84b0187071afd498d0000a034ceff2d66fa5b246bfb3cc5d8494cdf715275039a4e491f6c883d7f4222dd08a0659823b90ae3f4663eb4d3cab3b1549fddecbc721742b4e163d2ef9cee96a36600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000193f90190b90114f9011180a03ca524e5c6ae89677994f750505f0ba872e039e9a145f9ef715b9f64235c72a9a04fc5f13ab2f9ba0c2da88b0151ab0e7cf4d85d08cca45ccd923c6ab76323eb28a07fcaf739db6a00392cc63e12a27db7928f40148cfa81102cbe53a83dab09776b8080a04f484bbd9f78f07adff99539aa7c5c1d66a53b5b9174128ef89fe12e72791a4680a02fd3025a50442a628dcbbb6b43597d5cb5a885ec43eda9a27b6a52ee2ac7a33780a07a74f7fb076fce3920db31a282161747f8bd6cacce4fe9cd6d9cc8f20e992286a0f4984a11f61a2921456141df88de6e1a710d28681b91af794c5a721e47839cd7808080a0f5ae72cc5e9e74189b3b3f95f09213c8c607021024170c424ce3e4cda3c12e1580b853f8518080808080a07474a0536ebd29f098441a82f46ba80d19334ad69320a1a33c0be232d901f4ba8080808080808080a0a5ca2d8b583c459a466ae978f5a08f2759df4b0b198eecd15380df2fcc6ec71d8080a3e2a020934bf3958f8b9084668e86c438c9b1d6387ce7675d09d53911ce47fb5d03130100000000000000000000000000",
                {
                    id: 3,
                    sender: "0xDA1Ea1362475997419D2055dD43390AEE34c6c37",
                    srcChainId: 31336,
                    destChainId: 167001,
                    owner: "0x513b9B8BfFD6B79056F5250b04b0e863814d6dD6",
                    to: "0x513b9B8BfFD6B79056F5250b04b0e863814d6dD6",
                    refundAddress: "0x513b9B8BfFD6B79056F5250b04b0e863814d6dD6",
                    depositValue: 1000000000000000,
                    callValue: 0,
                    processingFee: 0,
                    gasLimit: 1000000,
                    data: ethers.constants.HashZero,
                    memo: "CronJob SendEthers",
                }
            )
        })
    })
})
