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
            throw new Error(`hardhat: eth_getProof - Method not supported`)
        }

        const baseLibMerkleProof = await utils.deployContract(
            hre,
            "LibMerkleProof"
        )

        libMerkleProof = await utils.deployContract(hre, "TestLibMerkleProof", {
            LibMerkleProof: baseLibMerkleProof.address,
        })
    })

    it("should verify storage proofs", async function () {
        const key = ethers.utils.hexlify(hre.ethers.utils.randomBytes(32))
        const value = ethers.utils.hexlify(hre.ethers.utils.randomBytes(32))

        const setStorageTx = await libMerkleProof.setStorage(key, value)
        const setStorageReceipt = await setStorageTx.wait()

        expect(setStorageReceipt.status).to.be.equal(1)

        const block = await hre.ethers.provider.send("eth_getBlockByNumber", [
            "latest",
            false,
        ])

        const proof = await hre.ethers.provider.send("eth_getProof", [
            libMerkleProof.address,
            [key],
            "latest",
        ])

        expect(
            ethers.utils.hexlify(proof.storageProof[0].key, {
                hexPad: "left",
            })
        ).to.be.equal(key)
        expect(
            ethers.utils.hexlify(proof.storageProof[0].value, {
                hexPad: "left",
            })
        ).to.be.equal(value)

        const coder = new hre.ethers.utils.AbiCoder()
        const mkproof = coder.encode(
            ["bytes", "bytes"],
            [
                `0x` + rlp.encode(proof.accountProof).toString("hex"),
                `0x` + rlp.encode(proof.storageProof[0].proof).toString("hex"),
            ]
        )

        await expect(
            libMerkleProof.verifyStorage(
                block.stateRoot,
                libMerkleProof.address,
                key,
                value,
                mkproof
            )
        ).not.to.be.reverted

        await expect(
            libMerkleProof.verifyStorage(
                block.stateRoot,
                libMerkleProof.address,
                key,
                hre.ethers.utils.randomBytes(32),
                mkproof
            )
        ).to.be.reverted
    })

    it("should verify footprints", async function () {
        const tx = await libMerkleProof.setStorage(
            ethers.utils.hexlify(hre.ethers.utils.randomBytes(32)),
            ethers.utils.hexlify(hre.ethers.utils.randomBytes(32))
        )
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
            libMerkleProof.verifyFootprint(
                block.receiptsRoot,
                0,
                encodedReceipt,
                rlp.encode(receiptProof)
            )
        ).not.to.be.reverted

        await expect(
            libMerkleProof.verifyFootprint(
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
            libMerkleProof.verifyFootprint(
                block.transactionsRoot,
                0,
                encodedTx,
                rlp.encode(txProof)
            )
        ).not.to.be.reverted

        await expect(
            libMerkleProof.verifyFootprint(
                block.transactionsRoot,
                Math.ceil(Math.random() * 1024),
                encodedTx,
                rlp.encode(txProof)
            )
        ).to.be.reverted
    })
})
