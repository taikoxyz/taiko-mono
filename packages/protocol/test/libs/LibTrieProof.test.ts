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

            // const stateRoot = block.stateRoot

            // RLP encode the proof together for LibTrieProof to decode
            // const encodedProof = ethers.utils.defaultAbiCoder.encode(
            //     ["bytes", "bytes"],
            //     [
            //         RLP.encode(proof.accountProof),
            //         RLP.encode(proof.storageProof[0].proof),
            //     ]
            // )

            await testLibTreProof.verify2(
                "0x58ba8c1587a05c4c1f99ccee01b57ac16357925a975db7e391ed8f7ee53dc244",
                "0xB12d6112D64B213880Fa53F815aF1F29c91CaCe9",
                "0x5327789baa6755943f7b2d418c675a91369c2ced234095c1d257a9e4860cde89",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003a068d0446ba8f26b8c10dd542318b91a56e7ac4902ac2fa7d4c6bcbe88359dc73a1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347000000000000000000000000000000000000000000000000000000000000000058ba8c1587a05c4c1f99ccee01b57ac16357925a975db7e391ed8f7ee53dc2447f45fc4870ba33218cef46d1aa5f0de6f074e5d59e34156c07bfaf6d73f414769ac84d41433f0bcb30b659b02b30a5638da0d29ede100b15d097a85be0a0a6830040000800000000000000000000000000000000000000000000001000000000000000000000000000001004000400000000000000000001000000000020000000800000000000000010000800200020000000000000000000000000000000000000000010000000080000000008040000000000000000000000001000010400400000000000000000000000000200000000000000000000000000004000000002000000000000020000000000000000000000000000000041800000002000000000000a800000100000000000000000000000400000100000000000000000000010000000004000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000710000000000000000000000000000000000000000000000000000000000aa60e500000000000000000000000000000000000000000000000000000000000430a300000000000000000000000000000000000000000000000000000000635bb14200000000000000000000000000000000000000000000000000000000000002c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000061d883010b00846765746888676f312e31382e37856c696e757800000000000000de704d66ded652f424ddedce3df9b6a7f6903ae0b2685faf821b1c8d7062481822570c8c2ba2ee17c3405d401452212ccf0954fb32120915a8bdcc03918dab93000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004e0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000283f90280b901b4f901b1a06df290b81f3211bb9895503ff6594826aac547504ac91cecfdd01dbb09122b60a0013c0def0d0183f5fd312ff7e9fd8cfd7bd7e2d8efa50b191cca7754cfb0b736a0fe29e5ec8e138687327fb592db91e3baecc9f405c494e97a688162166e1be66980a02c1e0971068058bd212c3e1f7def5b339ea5a4427d883f1b130681ab9b18bff0a0b9e5b7328855eaba8092e295435990f12a6bf289b2da875dfad1a1e8214934efa07ffab3684a9dbf9086a73ec3d46a9a57084666aadc3260d8333742346f845d13a014bb918dacf676f9bd5744c898e83df4a7ee9642141e655f42ddcefb0cfe92a780a0a440b1d6a11e7b48149843d2ab6954356fe5a6f62182515299bd6eef91c4910680a0fe95046e78caeaa31a6f247bae2a208c5be4e7c3e0c4df663b422dc30d9d7c82a0d5980aa1b5ca7d3dace71dd0c3fa75f8af1f4876bd50eb3102c447329b078409a0d06486f3dd6e44d4dceb8de9f5eecce89c18b51f82759ac8b781144b7a428f1da073d5cc524c5bbfdcd98aa21dda3e62065692ce4d8bb500d21c1bb8263d153de0a055c56ee5681c7a30cee5908aab0fb5884e2855cabb65c5ab48cb4a0e93608eb380b853f8518080a0b149f5df48ffdee17c1d8f31a97d34cb3284f72adc9b77e5602749fdfff0f95ba09fadc8e933d93b558e7509b5cc3e09b5affe6175a989d0127e8ecf673f50de6380808080808080808080808080b872f870a02007649327f6988d577705dafc8f0aec1be762e1dfdee8fcd38a2a6377e95e0fb84df84b0187071afd498d0000a037256282389bf2f071e1de12d064207fc82b55ea6e778768a5de33f550baebdea0659823b90ae3f4663eb4d3cab3b1549fddecbc721742b4e163d2ef9cee96a366000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001b3f901b0b90114f901118080a04fc5f13ab2f9ba0c2da88b0151ab0e7cf4d85d08cca45ccd923c6ab76323eb28a0ce4f9165f17fa4025d0ced663cb96a285aec39d36c3d8239ab948368c42045aea0bee52e2794e399ca3dd7a4e8f8dfa3cae0d1f9e4f3105cc63df57911c70be8bf808080a07394a09684ef3b2c87e9e2a753eb4ac78e2047b980e16d2e2133aee78946370d80a07a74f7fb076fce3920db31a282161747f8bd6cacce4fe9cd6d9cc8f20e992286a0f4984a11f61a2921456141df88de6e1a710d28681b91af794c5a721e47839cd7a09dbe337aabd86699cd20073eb93e928a87bc1af7814f349aa01d77a91089a5d68080a0f5ae72cc5e9e74189b3b3f95f09213c8c607021024170c424ce3e4cda3c12e1580b873f8718080808080a07474a0536ebd29f098441a82f46ba80d19334ad69320a1a33c0be232d901f4ba80808080a043b6fcc103e20427967dd498e7a61027a32edda74e15caec989d5b3991f0f679808080a0a5ca2d8b583c459a466ae978f5a08f2759df4b0b198eecd15380df2fcc6ec71d8080a3e2a02026a2f93d13b218d3c86752358e387bec6838b7633acd40706a4e7d453a13640100000000000000000000000000",
                {
                    id: 0,
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
