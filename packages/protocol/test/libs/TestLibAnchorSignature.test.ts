import { expect } from "chai"
import { UnsignedTransaction } from "ethers"
import { ethers } from "hardhat"

describe("LibAnchorSignature", function () {
    let libAnchorSignature: any

    const unsignedLegacyTx: UnsignedTransaction = {
        type: 0,
        chainId: Math.floor(Math.random() * 1024),
        nonce: Math.floor(Math.random() * 1024),
        gasPrice: randomBigInt(),
        gasLimit: randomBigInt(),
        to: ethers.Wallet.createRandom().address,
        value: randomBigInt(),
        data: ethers.utils.randomBytes(32),
    }

    before(async function () {
        const libUint512 = await (
            await ethers.getContractFactory("Uint512")
        ).deploy()

        libAnchorSignature = await (
            await ethers.getContractFactory("TestLibAnchorSignature", {
                libraries: {
                    Uint512: libUint512.address,
                },
            })
        ).deploy()
    })

    it("should calculate correct signature values", async function () {
        const validKs = [1, 2]

        for (const k of validKs) {
            const hash = ethers.utils.keccak256(
                ethers.utils.serializeTransaction(unsignedLegacyTx)
            )

            const [v, r, s] = await libAnchorSignature.signTransaction(hash, k)

            expect(
                await libAnchorSignature.recover(
                    hash,
                    v + 27,
                    ethers.utils.hexZeroPad(r, 32),
                    ethers.utils.hexZeroPad(s, 32)
                )
            ).to.be.equal(await libAnchorSignature.goldFingerAddress())
        }
    })

    function randomBigInt() {
        return ethers.BigNumber.from(ethers.utils.randomBytes(32))
    }
})
