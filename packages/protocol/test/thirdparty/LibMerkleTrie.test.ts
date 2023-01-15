import { expect } from "chai";
import { ethers } from "hardhat";
import { BaseTrie } from "merkle-patricia-tree";
import { TestLibMerkleTrie } from "../../typechain";
import { MerkleTrie } from "../utils/trie";
import { randomBytes } from "crypto";

describe("LibMerkleTrie", function () {
    let libMerkleTrie: TestLibMerkleTrie;
    let defaultMerkleTrie: MerkleTrie<BaseTrie>;
    const defaultAmountOfNodes = 32;
    const defaultNodeLength = 32;

    beforeEach(async function () {
        libMerkleTrie = await (
            await ethers.getContractFactory("TestLibMerkleTrie")
        ).deploy();

        defaultMerkleTrie = new MerkleTrie(
            defaultAmountOfNodes,
            defaultNodeLength,
            () => new BaseTrie()
        );
        await defaultMerkleTrie.init();
    });

    describe("verifyInclusionProof()", () => {
        it(`is included, ${defaultAmountOfNodes} bytes, ${defaultNodeLength} node length`, async () => {
            for (const n of defaultMerkleTrie.nodes) {
                const key = n.key;
                const t = await defaultMerkleTrie.makeTest(key);
                const isIncluded = await libMerkleTrie.verifyInclusionProof(
                    key,
                    t.node.value,
                    t.proof.proof,
                    t.root.root
                );
                expect(isIncluded).to.be.eq(true);
            }
        });
    });

    describe("get()", () => {
        it(`is included`, async () => {
            const key = defaultMerkleTrie.nodes[0].key;
            const t = await defaultMerkleTrie.makeTest(key);
            const isIncluded = await libMerkleTrie.get(
                key,
                t.proof.proof,
                t.root.root
            );

            expect(isIncluded[0]).to.be.eq(true);
            expect(isIncluded[1]).to.be.eq(
                ethers.utils.hexlify(defaultMerkleTrie.nodes[0].value)
            );
        });
        it(`is not included`, async () => {
            const t = await defaultMerkleTrie.makeTest(
                defaultMerkleTrie.nodes[0].key
            );

            const key = randomBytes(defaultNodeLength);
            const isIncluded = await libMerkleTrie.get(
                key,
                t.proof.proof,
                t.root.root
            );

            expect(isIncluded[0]).to.be.eq(false);
            expect(isIncluded[1]).to.be.eq("0x");
        });
    });
});
