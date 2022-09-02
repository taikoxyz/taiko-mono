import { expect } from "chai"
import { Contract } from "ethers"
import { ethers } from "hardhat"
// eslint-disable-next-line node/no-extraneous-import
import * as rlp from "rlp"
import * as utils from "../../tasks/utils"
const hre = require("hardhat")

describe("integration:LibTrieProof", function () {
    let libTrieProof: Contract

    before(async () => {
        hre.args = { confirmations: 1 }
        if (hre.network.name === "hardhat") {
            throw new Error(`hardhat: eth_getProof - Method not supported`)
        }

        const baseLibTrieProof = await utils.deployContract(hre, "LibTrieProof")

        libTrieProof = await utils.deployContract(hre, "TestLibTrieProof", {
            LibTrieProof: baseLibTrieProof.address,
        })
    })

    it("should verify trie proofs", async function () {
        const key = ethers.utils.hexlify(hre.ethers.utils.randomBytes(32))
        const value = ethers.utils.hexlify(hre.ethers.utils.randomBytes(32))

        const setStorageTx = await libTrieProof.setStorage(key, value)
        const setStorageReceipt = await setStorageTx.wait()

        expect(setStorageReceipt.status).to.be.equal(1)

        const block = await hre.ethers.provider.send("eth_getBlockByNumber", [
            "latest",
            false,
        ])

        const proof = await hre.ethers.provider.send("eth_getProof", [
            libTrieProof.address,
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
            libTrieProof.prove(
                block.stateRoot,
                libTrieProof.address,
                key,
                value,
                mkproof
            )
        ).not.to.be.reverted

        await expect(
            libTrieProof.prove(
                block.stateRoot,
                libTrieProof.address,
                key,
                hre.ethers.utils.randomBytes(32),
                mkproof
            )
        ).to.be.reverted
    })
})
