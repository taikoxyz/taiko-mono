import { expect } from "chai"
import { Contract } from "ethers"
// eslint-disable-next-line node/no-extraneous-import
import * as rlp from "rlp"
import * as utils from "../../../tasks/utils"
const hre = require("hardhat")

const action = process.env.TEST_LIB_MERKLE_PROOF ? describe : describe.skip

action("LibMerkleProof", function () {
    let libTrieProof: Contract
    let taikoL2: Contract
    let libStorageProof: Contract

    before(async () => {
        const provider = new hre.ethers.providers.JsonRpcProvider(
            "http://localhost:18545"
        )

        let retry = 0

        while (true) {
            try {
                const network = await provider.getNetwork()
                if (network.chainId) break
            } catch (_) {}

            if (++retry > 10) {
                throw new Error("test ethereum node initializing timeout")
            }

            await sleep(1000)
        }

        console.log("test ethereum node initialized")

        hre.args = { confirmations: 1 }

        const addressManager = await utils.deployContract(hre, "AddressManager")
        await utils.waitTx(hre, await addressManager.init())

        libStorageProof = await utils.deployContract(hre, "TestLibStorageProof")

        const libTxListDecoder = await utils.deployContract(
            hre,
            "LibTxListDecoder"
        )

        libTrieProof = await utils.deployContract(hre, "LibMerkleProof")
        taikoL2 = await utils.deployContract(hre, "TaikoL2", {
            LibTxListDecoder: libTxListDecoder.address,
        })
    })

    it("should verify inclusion proof", async function () {
        const anchorHeight = Math.floor(Math.random() * 1024)
        const anchorHash = hre.ethers.utils.randomBytes(32)

        const anchorReceipt = await utils.waitTx(
            hre,
            await taikoL2.anchor(anchorHeight, anchorHash)
        )

        expect(anchorReceipt.status).to.be.equal(1)

        const anchorKV = await libStorageProof.computeAnchorProofKV(
            anchorReceipt.blockNumber,
            anchorHeight,
            anchorHash
        )

        expect(anchorKV[0].length).not.to.be.equal(
            hre.ethers.constants.HashZero
        )
        expect(anchorKV[1].length).not.to.be.equal(
            hre.ethers.constants.HashZero
        )

        const proof = await hre.ethers.provider.send("eth_getProof", [
            taikoL2.address,
            [anchorKV[0]],
            hre.ethers.utils.hexValue(
                hre.ethers.utils.hexlify(anchorReceipt.blockNumber)
            ),
        ])

        expect(proof.storageProof[0].key).to.be.equal(anchorKV[0])
        expect(proof.storageProof[0].value).to.be.equal(anchorKV[1])

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
                hre.ethers.utils.hexlify(anchorReceipt.blockNumber)
            ),
            false,
        ])

        await libTrieProof.callStatic.verify(
            block.stateRoot,
            taikoL2.address,
            anchorKV[0],
            anchorKV[1],
            mkproof
        )

        // test verify revert with invalid value
        let verifyFailed = false

        try {
            const invalidProofValue = hre.ethers.utils.randomBytes(32)

            await libTrieProof.callStatic.verify(
                block.stateRoot,
                taikoL2.address,
                anchorKV[0],
                invalidProofValue,
                mkproof
            )
        } catch (err) {
            verifyFailed = true
        }

        expect(verifyFailed).to.be.equal(true)
    })

    it("should verify exclusion proof", async function () {
        const block = await hre.ethers.provider.send("eth_getBlockByNumber", [
            "latest",
            false,
        ])

        const key = hre.ethers.utils.hexlify(hre.ethers.utils.randomBytes(32))
        const value = hre.ethers.constants.HashZero

        const proof = await hre.ethers.provider.send("eth_getProof", [
            taikoL2.address,
            [key],
            block.number,
        ])

        console.log({ proof })

        expect(proof.storageProof[0].key).to.be.equal(key)
        expect(proof.storageProof[0].value).to.be.equal("0x0")

        const coder = new hre.ethers.utils.AbiCoder()
        const mkproof = coder.encode(
            ["bytes", "bytes"],
            [
                `0x` + rlp.encode(proof.accountProof).toString("hex"),
                `0x` + rlp.encode(proof.storageProof[0].proof).toString("hex"),
            ]
        )

        await libTrieProof.callStatic.verify(
            block.stateRoot,
            taikoL2.address,
            key,
            value,
            mkproof
        )
    })
})

function sleep(ms: number) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms)
    })
}
