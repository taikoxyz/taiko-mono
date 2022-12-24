import { expect } from "chai";
import { UnsignedTransaction } from "ethers";
import { ethers } from "hardhat";

describe("LibTxUtils", function () {
    let libTxUtils: any;
    let libRLPWriter: any;
    let libRLPReader: any;
    let testUnsignedTxs: Array<UnsignedTransaction>;
    const chainId = 167;

    const signingKey = new ethers.utils.SigningKey(
        ethers.utils.randomBytes(32)
    );
    const signerAddress = new ethers.Wallet(signingKey.privateKey).address;

    before(async function () {
        libTxUtils = await (
            await ethers.getContractFactory("TestLibTxUtils")
        ).deploy();

        libRLPReader = await (
            await ethers.getContractFactory("TestLibRLPReader")
        ).deploy();

        libRLPWriter = await (
            await ethers.getContractFactory("TestLibRLPWriter")
        ).deploy();

        const unsignedLegacyTx: UnsignedTransaction = {
            type: 0,
            // if chainId is defined, ether.js will automatically use EIP-155
            // signature
            chainId,
            nonce: Math.floor(Math.random() * 1024),
            gasPrice: randomBigInt(),
            gasLimit: randomBigInt(),
            to: ethers.Wallet.createRandom().address,
            value: randomBigInt(),
            data: ethers.utils.randomBytes(32),
        };

        const unsigned2930Tx: UnsignedTransaction = {
            type: 1,
            chainId,
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
        };

        const unsigned1559Tx: UnsignedTransaction = {
            type: 2,
            chainId,
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
        };

        testUnsignedTxs = [unsignedLegacyTx, unsigned2930Tx, unsigned1559Tx];
    });

    it("should hash the unsigned tx payloads correctly", async function () {
        for (const unsignedTx of testUnsignedTxs) {
            const expectedHash = ethers.utils.keccak256(
                ethers.utils.serializeTransaction(unsignedTx)
            );

            const signature = signingKey.signDigest(expectedHash);

            const hash = await libTxUtils.hashUnsignedTx(
                chainId,

                {
                    txType: unsignedTx.type,
                    destination: unsignedTx.to,
                    data: unsignedTx.data,
                    gasLimit: unsignedTx.gasLimit,
                    v: signature.v,
                    r: signature.r,
                    s: signature.s,
                    txData: ethers.utils.serializeTransaction(
                        unsignedTx,
                        signature
                    ),
                }
            );

            expect(hash).to.be.equal(expectedHash);
        }
    });

    it("should verify valid transaction signatures", async function () {
        for (const unsignedTx of testUnsignedTxs) {
            const expectedHash = ethers.utils.keccak256(
                ethers.utils.serializeTransaction(unsignedTx)
            );
            const signature = signingKey.signDigest(expectedHash);

            expect(
                await libTxUtils.recoverSender(chainId, {
                    txType: unsignedTx.type,
                    destination: unsignedTx.to,
                    data: unsignedTx.data,
                    gasLimit: unsignedTx.gasLimit,
                    v: signature.v - 27,
                    r: signature.r,
                    s: signature.s,
                    txData: ethers.utils.serializeTransaction(
                        unsignedTx,
                        signature
                    ),
                })
            ).to.be.equal(signerAddress);
        }
    });

    it("should verify invalid transaction signatures", async function () {
        for (const unsignedTx of testUnsignedTxs) {
            const expectedHash = ethers.utils.keccak256(
                ethers.utils.serializeTransaction(unsignedTx)
            );
            const signature = signingKey.signDigest(expectedHash);

            const invalidSignature = {
                v: 75,
                r: "0xb14e3f5eab11cd2c459b04a91a9db8bd6f5acccfbd830c9693c84f8d21187eef",
                s: "0x5cf4b3b2b3957e7016366d180493c2c226ea8ad12aed7faddbc0ce3a6789256d",
            };

            const txData = await changeSignature(
                unsignedTx.type,
                ethers.utils.arrayify(
                    ethers.utils.serializeTransaction(unsignedTx, signature)
                ),
                invalidSignature
            );

            expect(
                await libTxUtils.recoverSender(chainId, {
                    txType: unsignedTx.type,
                    destination: unsignedTx.to,
                    data: unsignedTx.data,
                    gasLimit: unsignedTx.gasLimit,
                    v: invalidSignature.v,
                    r: invalidSignature.r,
                    s: invalidSignature.s,
                    txData,
                })
            ).to.be.equal(ethers.constants.AddressZero);
        }
    });

    async function changeSignature(
        type: any,
        encoded: Uint8Array,
        signature: any
    ) {
        if (type !== 0) encoded = encoded.slice(1);

        const rlpItemsList = (await libRLPReader.readList(encoded)).slice(
            0,
            -3
        );

        let result = await libRLPWriter.writeList(
            rlpItemsList.concat([
                await libRLPWriter.writeUint(signature.v),
                await libRLPWriter.writeBytes(signature.r),
                await libRLPWriter.writeBytes(signature.s),
            ])
        );

        if (type !== 0) result = ethers.utils.concat([[type], result]);

        return ethers.utils.hexlify(result);
    }

    function randomBigInt() {
        return ethers.BigNumber.from(ethers.utils.randomBytes(32));
    }
});
