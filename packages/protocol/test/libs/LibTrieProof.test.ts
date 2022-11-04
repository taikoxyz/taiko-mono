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
            // proof verifies the storageValue at key is 1
            await testLibTreProof.verify(
                stateRoot,
                bridge.address,
                key,
                "1",
                encodedProof
            )
        })

        it("verifies 2", async function () {
            const { testLibTreProof } = await deployLibTrieProofFixture()

            await testLibTreProof.verify2(
                "0x68a10652e4fc8882bef0ff34ffad17e881cf5eb373dc216d5764b55880df4372",
                "0xB12d6112D64B213880Fa53F815aF1F29c91CaCe9",
                "0x373d87dd479ff834b963909ec731d795bd440367284be8f5a201e4a82043c8c0",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003a0aafe1871246cecd3ff9b0025f731f227bad9f63525f46e83a6f140b5bd6bca001dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347000000000000000000000000000000000000000000000000000000000000000068a10652e4fc8882bef0ff34ffad17e881cf5eb373dc216d5764b55880df4372916f8cf89455136b6f8d091dc95ecc601b1956a936636aa38ec164a1dad150727c82f5a7cc81af5227f325c42cf4cd742ff27da40109962be91903d70262527300400008000000000000000000000000000000000000000000000010000000000000000000000000000000040000000000000000000000010000000000200100008000000000000000100008002100200000000080200000000400000000000000000000100000000800000000080000000000000000000000000010000104004000000200000000000000000002000000000000000000000000000040000000020000000000000200000000000000000000000000000000418000000000000000000002800000100000000000000000000000400000100000000000000000000010000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000860000000000000000000000000000000000000000000000000000000000ade80c00000000000000000000000000000000000000000000000000000000000430a3000000000000000000000000000000000000000000000000000000006363709100000000000000000000000000000000000000000000000000000000000002c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000061d883010b00846765746888676f312e31382e37856c696e757800000000000000497f0b2bfaa230713df47bc5340b8e325171c8e9d1aeb9b26c930b1ce5013b9955046e7a8af532b38a7344a152c5ac816e115ff8c8d65306cfe784154a221ed6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005a0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000283f90280b901b4f901b1a03a08ccf2108fb7c046e56cd57460853f708ca893207c7fe67d09d28a56701301a0183d180e369ab4d338a4b5c7e1e077647dfa037a7685cc3126c0b17949193526a0466dd0cde3ec41c7ecfd9786ee9e6ff4969786e91268efa17a7e4ee4a3c550cd80a0b9364c7dc5fa6d7ebc1c00fd75ef857dd12300a38d5392650e07e80e836325e5a0dd21845cd551ff176f386fd18022c2af52c7c6930135ea3525d97ad9d19b7925a0c00081cb44beae4dfa83c58407abbc8b709ce8ea9727de06cf80449a106af1d4a0213ac9b5a694da5c36ff56a3c5065b4b25bfd8d19fe77b50f0d4ed354646b33880a0075f0d667c280f2090ea86804ced0ad80721785dc5bd3cf046c3ad320297555980a0d6594a324081155e264ec3f531bf7e947f5325d7a053c021dba3c26ef68f87f4a0b4c5a58edbee10742f56cfadf930e35daeed3143fd3b5d8ae99805f6533ebec6a0b263bc07a0e9d2dffe6c4806555e3031e4939919286111ffe8657d7bbb24aa29a0aa66334b79bb7e66e1fff429b7ea46a65ae25216b60e8336d7f2f00b504cb564a04f84de6ff38669e1293f01eb1317e14c0324c1496f0d31f3427a24077402ab3a80b853f8518080a051c79b5a044ed1ff6f13ee5a035363d5a72e01b628bad2b6105c37049711ca99a09fadc8e933d93b558e7509b5cc3e09b5affe6175a989d0127e8ecf673f50de6380808080808080808080808080b872f870a02007649327f6988d577705dafc8f0aec1be762e1dfdee8fcd38a2a6377e95e0fb84df84b01874a9b6384488000a0311e9037b86296208aada7fc1271119c40501e85a9d63f1f0d1e88caaadb0a19a0ecb82bdbeb20e937d8e76b41c3a28125fe15f2a7001bf048cc3bc13a135bcb3200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000273f90270b901f4f901f1a0d10ffa3c6f46288f125fce414e16820e538133780f1c9895b0e461650434e23e80a0fdd7940de4ecc6ffc0eab413542235ec62a025fdc8e22b777d5be0b05f42e141a0adacc99d6fa6cda67143305ddd3cccd7cc9cdf7ca31eabdba8a44a5e8add0a80a099fe72ea9f82675878871545a161a11651d5b20ddd87a47928b9010bce7c548ba052453a71c92652a1fb0decb9eb1a5fe2d813d4e60e9f2376ef09700ee398be06a024f0364f54f1875fffc91c26c2325f479cb319c749a4266996b00d855135ac68a0da6334dacbbf88c7dfb38ef8e104bf3e4c3c76dd14d27379ff2ae70e7e7ab9d1a01ee7982d6286b8489a7d5bf965f0b02e47167199b9bee913ce3cc95977f46f63a02242b05a154bd9be1a5313481c17d453ad189e8ffcab974445c59d33ab5081eca04dfb6173b1000dff6a022a20aaeb5d5eec2f1ce84eb38681a4d8379474635e53a093cb3fd3831a4f16e38fcbc1c9bcf87f92854ebcf40b7448bef260ce1698e334a0d0c3b4be02031376800995c31b70669945f2860fe4c78830df72f995510e9e6fa0b04e211a20f72c59788ab56909e4f6cd25a86e660870bf04624cbd5f1199fe0fa09bb4e9f5a83cd32f6da5681e9b6951a793beefa8544278dd4e774dc9d6919d3ea0531e7714b705f2c9d91ab7d459a8e5792fa39e19162617c49ab8c2a900743c9880b853f85180a096455ee1d857c707946176fa5a0637d94a029274cc114caa338517ed6e5ee05e80808080808080a0fed642b03ea35568f81a6290ec469f00d0870f472bc2f0a75ea43cb9e9f7d5ee80808080808080a3e2a020b2607d8317fbced10bd604f811eb13993cfb33128e161dda8a07f28a4f9b870100000000000000000000000000"
                // {
                //     id: 0,
                //     sender: "0xDA1Ea1362475997419D2055dD43390AEE34c6c37",
                //     srcChainId: 31336,
                //     destChainId: 167001,
                //     owner: "0x4Ec242468812B6fFC8Be8FF423Af7bd23108d991",
                //     to: "0x9cEAce3304A68E10Dd2465dAa3ba7da44844E3ca",
                //     refundAddress:
                //         "0x4Ec242468812B6fFC8Be8FF423Af7bd23108d991",
                //     depositValue: 0,
                //     callValue: 0,
                //     processingFee: 0,
                //     gasLimit: 1000000,
                //     data: "0x0c6fab8200000000000000000000000000000000000000000000000000000000000000800000000000000000000000004ec242468812b6ffc8be8ff423af7bd23108d9910000000000000000000000004ec242468812b6ffc8be8ff423af7bd23108d99100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000007a68000000000000000000000000e48a03e23449975df36603c93f59a15e2de75c74000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000004544553540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000095465737445524332300000000000000000000000000000000000000000000000",
                //     memo: "CronJob SendTokens",
                // }
            )
        })
    })
})
