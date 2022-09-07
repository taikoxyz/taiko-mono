import { expect } from "chai"
import { UnsignedTransaction } from "ethers"
import { ethers } from "hardhat"

describe("LibECDSA", function () {
    let libECDSA: any

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

        libECDSA = await (
            await ethers.getContractFactory("TestLibECDSA", {
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

            const [v, r, s] = await libECDSA.signWithGoldFingerUseK(hash, k)

            expect(await libECDSA.recover(hash, v + 27, r, s)).to.be.equal(
                await libECDSA.goldFingerAddress()
            )
        }
    })

    function randomBigInt() {
        return ethers.BigNumber.from(ethers.utils.randomBytes(32))
    }
})
