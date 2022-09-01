import { expect } from "chai"
import { Contract } from "ethers"
import { ethers } from "hardhat"
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

    it("should verify inclusion proofs", async function () {
        const key = ethers.utils.hexlify(hre.ethers.utils.randomBytes(32))
        const value = ethers.utils.hexlify(hre.ethers.utils.randomBytes(32))

        const setStorageTx = await libMerkleProof.setStorage(key, value)
        const setStorageReceipt = await setStorageTx.wait()

        expect(setStorageReceipt.status).to.be.equal(1)

        const proof = await hre.ethers.provider.send("eth_getProof", [
            libMerkleProof.address,
            [key],
            hre.ethers.utils.hexValue(
                hre.ethers.utils.hexlify(setStorageReceipt.blockNumber)
            ),
        ])

        expect(proof.storageProof[0].key).to.be.equal(key)
        expect(proof.storageProof[0].value).to.be.equal(value)

        const coder = new hre.ethers.utils.AbiCoder()
        const mkproof = coder.encode(
            ["bytes", "bytes"],
            [
                `0x` + rlp.encode(proof.accountProof).toString("hex"),
                `0x` + rlp.encode(proof.storageProof[0].proof).toString("hex"),
            ]
        )

        const block = await hre.ethers.provider.send("eth_getBlockByNumber", [
            hre.ethers.utils.hexValue(
                hre.ethers.utils.hexlify(setStorageReceipt.blockNumber)
            ),
            false,
        ])

        await libMerkleProof.callStatic.verifyStorage(
            block.stateRoot,
            libMerkleProof.address,
            key,
            value,
            mkproof
        )

        await expect(
            libMerkleProof.callStatic.verifyStorage(
                block.stateRoot,
                libMerkleProof.address,
                key,
                hre.ethers.utils.randomBytes(32),
                mkproof
            )
        ).to.be.reverted
    })
})
