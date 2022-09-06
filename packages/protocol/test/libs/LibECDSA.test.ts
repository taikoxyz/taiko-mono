import { BN } from "bn.js"
import { expect } from "chai"
import { UnsignedTransaction } from "ethers"
import { ethers } from "hardhat"
const { ec: EC } = require("elliptic")

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

    it("should output correct signature values", async function () {
        const expectedHash = ethers.utils.keccak256(
            ethers.utils.serializeTransaction(unsignedLegacyTx)
        )
        const curve = new EC("secp256k1")

        const keyPair = curve.keyFromPrivate(
            ethers.utils.arrayify(await libECDSA.TAIKO_GOLDFINGURE_PRIVATEKEY())
        )

        const digestBytes = ethers.utils.arrayify(expectedHash)

        const signature = keyPair.sign(digestBytes, {
            canonical: true,
            k: () => new BN(1),
        })

        const {
            recoveryParam: expectedV,
            r: expectedR,
            s: expectedS,
        } = ethers.utils.splitSignature({
            recoveryParam: signature.recoveryParam as any,
            r: ethers.utils.hexZeroPad("0x" + signature.r.toString(16), 32),
            s: ethers.utils.hexZeroPad("0x" + signature.s.toString(16), 32),
        })

        const [v, r, s] = await libECDSA.signWithGoldenFinger(expectedHash)

        expect(v).to.be.equal(expectedV)
        expect(r).to.be.equal(expectedR)
        expect(s).to.be.equal(expectedS)

        const recoveredAddress = ethers.utils.recoverAddress(digestBytes, {
            recoveryParam: expectedV,
            r: expectedR,
            s: expectedS,
        })

        expect(recoveredAddress).to.be.equal(
            await libECDSA.TAIKO_GOLDFINGER_ADDRESS()
        )
    })

    function randomBigInt() {
        return ethers.BigNumber.from(ethers.utils.randomBytes(32))
    }
})
