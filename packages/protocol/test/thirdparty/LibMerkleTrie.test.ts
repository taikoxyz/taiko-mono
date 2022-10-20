import { expect } from "chai"
import { ethers } from "hardhat"
import { TestLibMerkleTrie } from "../../typechain"
import { MerkleTrie } from "../utils/trie"

const defaultAmountOfNodes = 32
const defaultNodeLength = 32
describe("LibMerkleTrie", function () {
    async function deployLibMerkleTrieFixture(
        amountOfNodes: number,
        len: number
    ) {
        const [owner] = await ethers.getSigners()

        const LibMerkleTrieFactory = await ethers.getContractFactory(
            "TestLibMerkleTrie"
        )

        const libMerkleTrie: TestLibMerkleTrie =
            await LibMerkleTrieFactory.deploy()

        const defaultMerkleTrie = new MerkleTrie(amountOfNodes, len)
        await defaultMerkleTrie.init()

        return { owner, libMerkleTrie, defaultMerkleTrie, LibMerkleTrieFactory }
    }

    describe("verifyInclusionProof()", () => {
        it(`is included, ${defaultAmountOfNodes} bytes, ${defaultNodeLength} node length`, async () => {
            const { libMerkleTrie, defaultMerkleTrie } =
                await deployLibMerkleTrieFixture(
                    defaultAmountOfNodes,
                    defaultNodeLength
                )

            for (const n of defaultMerkleTrie.nodes) {
                const key = n.key
                const t = await defaultMerkleTrie.makeTest(key)
                const isIncluded = await libMerkleTrie.verifyInclusionProof(
                    key,
                    t.node.value,
                    t.proof.proof,
                    t.root.root
                )
                expect(isIncluded).to.be.eq(true)
            }
        })
    })

    describe("get()", () => {
        it(`is included`, async () => {
            const { libMerkleTrie, defaultMerkleTrie } =
                await deployLibMerkleTrieFixture(
                    defaultAmountOfNodes,
                    defaultNodeLength
                )

            const key = defaultMerkleTrie.nodes[0].key
            const t = await defaultMerkleTrie.makeTest(key)
            const isIncluded = await libMerkleTrie.get(
                key,
                t.proof.proof,
                t.root.root
            )

            expect(isIncluded[0]).to.be.eq(true)
            expect(isIncluded[1]).to.be.eq(
                ethers.utils.hexlify(defaultMerkleTrie.nodes[0].value)
            )
        })
        it(`is not included`, async () => {
            const { libMerkleTrie, defaultMerkleTrie } =
                await deployLibMerkleTrieFixture(
                    defaultAmountOfNodes,
                    defaultNodeLength
                )
            const t = await defaultMerkleTrie.makeTest(
                defaultMerkleTrie.nodes[0].key
            )

            const key = Buffer.allocUnsafe(defaultNodeLength)
            const isIncluded = await libMerkleTrie.get(
                key,
                t.proof.proof,
                t.root.root
            )

            expect(isIncluded[0]).to.be.eq(false)
            expect(isIncluded[1]).to.be.eq("0x")
        })
    })
})
