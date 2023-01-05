import { expect } from "chai";
import { ethers } from "hardhat";
import RLP from "rlp";
import { EthGetProofResponse } from "../utils/rpc";

describe("integration2:LibTrieProof", function () {
    async function deployLibTrieProofFixture() {
        const libTrieProof = await (
            await ethers.getContractFactory("LibTrieProof")
        ).deploy();

        const testLibTreProof = await (
            await ethers.getContractFactory("TestLibTrieProof", {
                libraries: {
                    LibTrieProof: libTrieProof.address,
                },
            })
        ).deploy();

        return { testLibTreProof };
    }
    describe("verify()", function () {
        it("verifies", async function () {
            const { testLibTreProof } = await deployLibTrieProofFixture();

            // Two random bytes32
            const key =
                "0xc0dcf937b3f6136dd70a1ad11cc57b040fd410f3c49a5146f20c732895a3cc21";
            const val =
                "0x74bb61e381e9238a08b169580f3cbf9b8b79d7d5ee708d3e286103eb291dfd08";

            await testLibTreProof.writeStorageAt(key, val);

            // use this instead of ethers.provider.getBlock() beccause it doesnt have stateRoot
            // in the response
            const block: { stateRoot: string; number: string; hash: string } =
                await ethers.provider.send("eth_getBlockByNumber", [
                    "latest",
                    false,
                ]);

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                testLibTreProof.address,
                key,
                block.number
            );
            // make sure it equals 1 so our proof will pass
            expect(storageValue).to.be.eq(val);

            // rpc call to get the merkle proof
            const proof: EthGetProofResponse = await ethers.provider.send(
                "eth_getProof",
                [testLibTreProof.address, [key], block.hash]
            );

            // RLP encode the proof together for LibTrieProof to decode
            const encodedProof = ethers.utils.defaultAbiCoder.encode(
                ["bytes", "bytes"],
                [
                    RLP.encode(proof.accountProof),
                    RLP.encode(proof.storageProof[0].proof),
                ]
            );
            // proof verifies the storageValue at key is 1
            const verified = await testLibTreProof.verify(
                block.stateRoot,
                testLibTreProof.address,
                key,
                val,
                encodedProof
            );
            expect(verified).to.be.eq(true);
        });
    });
});
