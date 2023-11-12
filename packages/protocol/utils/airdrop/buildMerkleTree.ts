import { MerkleTree } from "merkletreejs/dist/MerkleTree";
const { ethers } = require("ethers");
const keccak256 = require("keccak256");
const fs = require("fs");

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
    const inputData = ethers.utils.defaultAbiCoder.encode(
        ["address", "uint256"],
        [data.address, data.amount],
    );

    return Buffer.from(
        ethers.utils
            .keccak256(
                ethers.utils.defaultAbiCoder.encode(
                    ["bytes", "bytes"],
                    [
                        ethers.utils.toUtf8Bytes("CLAIM_TAIKO_AIRDROP"),
                        inputData,
                    ],
                ),
            )
            .slice(2),
        "hex",
    );
}

async function getMerkleProof(
    address: string,
    amount: number,
    claimList: IClaimListData[],
) {
    const merkleData = await buildMerkleTree(claimList);
    const leaf = buildLeaf({ address, amount });

    return merkleData.merkleTree.getHexProof(leaf);
}

async function main() {
    const filePath = process.argv[2];

    if (!filePath) {
        console.error(
            "Please provide a path to the JSON file as a command-line argument.",
        );
        return;
    }

    const jsonData = fs.readFileSync(filePath, "utf-8");
    const claimList: IClaimListData[] = JSON.parse(jsonData);
    const merkleData = await buildMerkleTree(claimList);

    console.log("Merkle root:", merkleData.rootHash);
    console.log("Nr of leaves (entries):", claimList.length);

    const exampleProof = await getMerkleProof(
        "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf",
        100,
        claimList,
    );

    console.log("Example proof for Alice (foundry) is: ", exampleProof);
}

main().catch((error) => {
    console.error(error);
});
