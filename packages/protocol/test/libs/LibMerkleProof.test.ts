import { expect } from "chai"
import { Contract } from "ethers"
import { ethers } from "hardhat"
import { BaseTrie as Trie } from "merkle-patricia-tree"
// eslint-disable-next-line node/no-extraneous-import
import * as rlp from "rlp"
import * as utils from "../../tasks/utils"
const hre = require("hardhat")

describe("geth:LibMerkleProof", function () {
    let libMerkleProof: Contract

    before(async () => {
        hre.args = { confirmations: 1 }
        if (hre.network.name === "hardhat") {
            throw new Error(
                `hardhat: debug_getRawReceipts - Method not supported`
            )
        }

        const baseLibMerkleProof = await utils.deployContract(
            hre,
            "LibMerkleProof"
        )

        libMerkleProof = await utils.deployContract(hre, "TestLibMerkleProof", {
            LibMerkleProof: baseLibMerkleProof.address,
        })
    })

    it("should verify proofs of transactionsRoot/receiptsRoot", async function () {
        const tx = await ethers.provider.getSigner().sendTransaction({
            to: ethers.constants.AddressZero,
            value: ethers.utils.parseEther("0"),
        })

        await tx.wait()

        const block = await hre.ethers.provider.send("eth_getBlockByNumber", [
            "latest",
            false,
        ])

        // receipts root
        const [encodedReceipt] = await hre.ethers.provider.send(
            "debug_getRawReceipts",
            ["latest"]
        )

        const receiptTree = new Trie()

        await receiptTree.put(rlp.encode(0), encodedReceipt)

        expect(ethers.utils.hexlify(receiptTree.root)).to.be.equal(
            block.receiptsRoot
        )

        const receiptProof = await Trie.createProof(receiptTree, rlp.encode(0))

        await expect(
            libMerkleProof.prove(
                block.receiptsRoot,
                0,
                encodedReceipt,
                rlp.encode(receiptProof)
            )
        ).not.to.be.reverted

        await expect(
            libMerkleProof.prove(
                block.receiptsRoot,
                Math.ceil(Math.random() * 1024),
                encodedReceipt,
                rlp.encode(receiptProof)
            )
        ).to.be.reverted

        // transactions root
        const encodedTx = await hre.ethers.provider.send(
            "eth_getRawTransactionByHash",
            [tx.hash]
        )

        const txTree = new Trie()

        await txTree.put(rlp.encode(0), encodedTx)

        expect(ethers.utils.hexlify(txTree.root)).to.be.equal(
            block.transactionsRoot
        )

        const txProof = await Trie.createProof(txTree, rlp.encode(0))

        await expect(
            libMerkleProof.prove(
                block.transactionsRoot,
                0,
                encodedTx,
                rlp.encode(txProof)
            )
        ).not.to.be.reverted

        await expect(
            libMerkleProof.prove(
                block.transactionsRoot,
                Math.ceil(Math.random() * 1024),
                encodedTx,
                rlp.encode(txProof)
            )
        ).to.be.reverted
    })
})
