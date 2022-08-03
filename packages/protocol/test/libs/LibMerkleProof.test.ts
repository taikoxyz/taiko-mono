import { expect } from "chai"
import { Contract } from "ethers"
// eslint-disable-next-line node/no-extraneous-import
import * as rlp from "rlp"
import * as utils from "../../tasks/utils"
const hre = require("hardhat")

describe.skip("LibMerkleProof", function () {
    let libTrieProof: Contract
    let syncHashStore: Contract

    before(async () => {
        hre.args = { confirmations: 1 }
        if (hre.network.name === "hardhat") {
            throw new Error(`hardhat: eth_getProof - Method not supported`)
        }

        const deployer = await utils.getDeployer(hre)

        const addressManager = await utils.deployContract(hre, "AddressManager")
        await utils.waitTx(hre, await addressManager.init())
        await utils.waitTx(
            hre,
            await addressManager.setAddress("rollup", deployer)
        )

        libTrieProof = await utils.deployContract(hre, "LibMerkleProof")
        syncHashStore = await utils.deployContract(hre, "L2SyncHashStore", {}, [
            addressManager.address,
        ])
    })

    for (let index = 0; index < 10; index++) {
        const SYNC_HASH_KEY = hre.ethers.utils.id(`TAIKO.SYNC_HASH_KEY`)
        const syncHash = hre.ethers.utils.id(`random value ${index}`)

        it(`verify testCases[${index}]: ${syncHash}`, async function () {
            const setReceipt = await utils.waitTx(
                hre,
                await syncHashStore.set(syncHash)
            )

            const block = await hre.ethers.provider.send(
                "eth_getBlockByNumber",
                [hre.ethers.utils.hexlify(setReceipt.blockNumber), false]
            )

            const proof = await hre.ethers.provider.send("eth_getProof", [
                syncHashStore.address,
                [SYNC_HASH_KEY],
                hre.ethers.utils.hexlify(setReceipt.blockNumber),
            ])

            const coder = new hre.ethers.utils.AbiCoder()
            const mkproof = coder.encode(
                ["bytes", "bytes"],
                [
                    `0x` + rlp.encode(proof.accountProof).toString("hex"),
                    `0x` +
                        rlp.encode(proof.storageProof[0].proof).toString("hex"),
                ]
            )

            await libTrieProof.callStatic.verify(
                block.stateRoot,
                syncHashStore.address,
                SYNC_HASH_KEY,
                syncHash,
                mkproof
            )

            // test verify revert with invalid value
            let verifyFailed = false

            try {
                const invalidSyncHash = hre.ethers.utils.id(
                    `random value ${Math.random()}`
                )

                await libTrieProof.callStatic.verify(
                    block.stateRoot,
                    syncHashStore.address,
                    SYNC_HASH_KEY,
                    invalidSyncHash,
                    mkproof
                )
            } catch (err) {
                verifyFailed = true
            }

            expect(verifyFailed).to.be.equal(true)
        })
    }
})
