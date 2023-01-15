import { expect } from "chai";
import { randomBytes } from "crypto";
import { ethers } from "hardhat";
import { SecureTrie } from "merkle-patricia-tree";
import { TestLibSecureMerkleTrie } from "../../typechain";
import { MerkleTrie } from "../utils/trie";

describe("LibSecureMerkleTrie", function () {
    let libSecureMerkleTrie: TestLibSecureMerkleTrie;
    let defaultSecureMerkleTrie: MerkleTrie<SecureTrie>;
    const defaultAmountOfNodes = 32;
    const defaultNodeLength = 32;

    beforeEach(async function () {
        libSecureMerkleTrie = await (
            await ethers.getContractFactory("TestLibSecureMerkleTrie")
        ).deploy();

        defaultSecureMerkleTrie = new MerkleTrie(
            defaultAmountOfNodes,
            defaultNodeLength,
            () => new SecureTrie()
        );
        await defaultSecureMerkleTrie.init();
    });

    describe("verifyInclusionProof()", () => {
        it(`is included, ${defaultAmountOfNodes} bytes, ${defaultNodeLength} node length`, async () => {
            const n = defaultSecureMerkleTrie.nodes[0];
            const key = n.key;
            const t = await defaultSecureMerkleTrie.makeTest(key);
            const isIncluded = await libSecureMerkleTrie.verifyInclusionProof(
                key,
                t.node.value,
                t.proof.proof,
                t.root.root
            );
            expect(isIncluded).to.be.eq(true);
        });
    });

    describe("get()", () => {
        it(`is included`, async () => {
            const key = defaultSecureMerkleTrie.nodes[0].key;
            const t = await defaultSecureMerkleTrie.makeTest(key);
            const isIncluded = await libSecureMerkleTrie.get(
                key,
                t.proof.proof,
                t.root.root
            );

            expect(isIncluded[0]).to.be.eq(true);
            expect(isIncluded[1]).to.be.eq(
                ethers.utils.hexlify(defaultSecureMerkleTrie.nodes[0].value)
            );
        });

        it(`is not included`, async () => {
            const t = await defaultSecureMerkleTrie.makeTest(
                defaultSecureMerkleTrie.nodes[0].key
            );

            const key = randomBytes(defaultNodeLength);
            const isIncluded = await libSecureMerkleTrie.get(
                key,
                t.proof.proof,
                t.root.root
            );

            expect(isIncluded[0]).to.be.eq(false);
            expect(isIncluded[1]).to.be.eq("0x");
        });
    });
});
