import { expect } from "chai"
import { UnsignedTransaction } from "ethers"
import { ethers } from "hardhat"

describe("LibInvalidTxList", function () {
    let libInvalidTxList: any
    let libRLPWriter: any
    let libRLPReader: any

    const unsignedLegacyTx: UnsignedTransaction = {
        type: 0,
        nonce: Math.floor(Math.random() * 1024),
        gasPrice: randomBigInt(),
        gasLimit: randomBigInt(),
        to: ethers.Wallet.createRandom().address,
        value: randomBigInt(),
        data: ethers.utils.randomBytes(32),
    }

    const unsigned2930Tx: UnsignedTransaction = {
        type: 1,
        chainId: Math.floor(Math.random() * 1024),
        nonce: Math.floor(Math.random() * 1024),
        gasPrice: randomBigInt(),
        gasLimit: randomBigInt(),
        to: ethers.Wallet.createRandom().address,
        value: randomBigInt(),
        accessList: [
            [
                ethers.Wallet.createRandom().address,
                [ethers.utils.hexlify(ethers.utils.randomBytes(32))],
            ],
        ],
        data: ethers.utils.randomBytes(32),
    }

    const unsigned1559Tx: UnsignedTransaction = {
        type: 2,
        chainId: Math.floor(Math.random() * 1024),
        nonce: Math.floor(Math.random() * 1024),
        maxPriorityFeePerGas: randomBigInt(),
        maxFeePerGas: randomBigInt(),
        gasLimit: randomBigInt(),
        to: ethers.Wallet.createRandom().address,
        value: randomBigInt(),
        accessList: [
            [
                ethers.Wallet.createRandom().address,
                [ethers.utils.hexlify(ethers.utils.randomBytes(32))],
            ],
        ],
        data: ethers.utils.randomBytes(32),
    }

    const testUnsignedTxs = [unsignedLegacyTx, unsigned2930Tx, unsigned1559Tx]

    const signingKey = new ethers.utils.SigningKey(ethers.utils.randomBytes(32))

    before(async function () {
        libInvalidTxList = await (
            await ethers.getContractFactory("TestLibInvalidTxList")
        ).deploy()

        libRLPReader = await (
            await ethers.getContractFactory("TestLib_RLPReader")
        ).deploy()

        libRLPWriter = await (
            await ethers.getContractFactory("TestLib_RLPWriter")
        ).deploy()
    })

    it("should parse the recover payloads correctly", async function () {
        for (const unsignedTx of testUnsignedTxs) {
            const expectedHash = ethers.utils.keccak256(
                ethers.utils.serializeTransaction(unsignedTx)
            )

            const signature = signingKey.signDigest(expectedHash)
            const { v: expectedV, r: expectedR, s: expectedS } = signature

            const [hash, v, r, s] = await libInvalidTxList.parseRecoverPayloads(
                {
                    txType: unsignedTx.type,
                    gasLimit: unsignedTx.gasLimit,
                    txData: ethers.utils.serializeTransaction(
                        unsignedTx,
                        signature
                    ),
                }
            )

            expect(hash).to.be.equal(expectedHash)
            expect(v).to.be.equal(expectedV)
            expect(r).to.be.equal(expectedR)
            expect(s).to.be.equal(expectedS)
        }
    })

    it("should verify valid transaction signatures", async function () {
        for (const unsignedTx of testUnsignedTxs) {
            const expectedHash = ethers.utils.keccak256(
                ethers.utils.serializeTransaction(unsignedTx)
            )
            const signature = signingKey.signDigest(expectedHash)

            expect(
                await libInvalidTxList.verifySignature({
                    txType: unsignedTx.type,
                    gasLimit: unsignedTx.gasLimit,
                    txData: ethers.utils.serializeTransaction(
                        unsignedTx,
                        signature
                    ),
                })
            ).to.be.true
        }
    })

    it("should verify invalid transaction signatures", async function () {
        for (const unsignedTx of testUnsignedTxs) {
            const expectedHash = ethers.utils.keccak256(
                ethers.utils.serializeTransaction(unsignedTx)
            )
            const signature = signingKey.signDigest(expectedHash)

            const randomSignature = {
                v: Math.floor(Math.random() * 1024),
                r: ethers.utils.hexlify(ethers.utils.randomBytes(32)),
                s: ethers.utils.hexlify(ethers.utils.randomBytes(32)),
            }

            const txData = changeSignatures(
                unsignedTx.type,
                ethers.utils.arrayify(
                    ethers.utils.serializeTransaction(unsignedTx, signature)
                ),
                randomSignature.v,
                randomSignature.r,
                randomSignature.s
            )

            expect(
                await libInvalidTxList.verifySignature({
                    txType: unsignedTx.type,
                    gasLimit: unsignedTx.gasLimit,
                    txData,
                })
            ).to.be.false
        }
    })

    async function changeSignatures(
        type: any,
        encoded: Uint8Array,
        v: number,
        r: string,
        s: string
    ) {
        if (type !== 0) encoded = encoded.slice(1)

        const rlpItemsList = (await libRLPReader.readList(encoded)).slice(0, -3)

        let result = await libRLPWriter.writeList(
            rlpItemsList.concat([
                await libRLPWriter.writeUint(v),
                await libRLPWriter.writeBytes(r),
                await libRLPWriter.writeBytes(s),
            ])
        )

        if (type !== 0) result = ethers.utils.concat([[type], result])

        return ethers.utils.hexlify(result)
    }

    function randomBigInt() {
        return ethers.BigNumber.from(ethers.utils.randomBytes(32))
    }
})
