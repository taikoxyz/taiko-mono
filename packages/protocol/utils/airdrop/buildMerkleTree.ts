import { MerkleTree } from "merkletreejs/dist/MerkleTree";
import { claimList } from "./airdrop_db/claimList";
const { ethers } = require("ethers");

const keccak256 = require("keccak256");

interface IClaimListData {
    address: string;
    amount: number;
}

interface IMerkle {
    merkleTree: MerkleTree;
    rootHash: string;
}

async function buildMerkleTree(
    allowListDataArr: IClaimListData[],
): Promise<IMerkle> {
    // create merkle tree
    const leafNodes: any = [];
    for (let i = 0; i < allowListDataArr.length; i++) {
        leafNodes.push(buildLeaf(allowListDataArr[i]));
    }
    const merkleTree = new MerkleTree(leafNodes, keccak256, {
        sortPairs: true,
    });

    const rootHash = merkleTree.getHexRoot();

    return {
        merkleTree,
        rootHash,
    };
}

function buildLeaf(data: IClaimListData) {
    return Buffer.from(
        ethers.utils
            .keccak256(
                ethers.utils.defaultAbiCoder.encode(
                    ["bytes", "address", "uint256"],
                    [
                        ethers.utils.toUtf8Bytes("CLAIM_TAIKO_AIRDROP"),
                        data.address,
                        data.amount,
                    ],
                ),
            )
            .slice(2),
        "hex",
    );
}

async function getMerkleProof(address: string, amount: number) {
    const merkleData = await buildMerkleTree(claimList);
    const leaf = buildLeaf({ address, amount });

    return merkleData.merkleTree.getHexProof(leaf);
}

// Using typescript because it can be used for production BE (with DB too - while solidity libraries lacking that.
async function main() {
    const merkleData = await buildMerkleTree(claimList);
    // This one is same as merkleData.rootHash: console.log(merkleData.merkleTree.getHexRoot());
    console.log("Merkle root:", merkleData.rootHash);
    console.log("Nr of leaves (entries):", claimList.length);
    const exampleProof = await getMerkleProof(
        "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf",
        100,
    );
    console.log("Example proof for Alice (foundry) is: ", exampleProof);
}

main()
    .then(() => {})
    .catch((error) => {
        console.error(error);
    });
