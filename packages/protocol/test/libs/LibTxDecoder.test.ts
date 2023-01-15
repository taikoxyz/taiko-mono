import { expect } from "chai";
import { UnsignedTransaction } from "ethers";
import { ethers } from "hardhat";
import * as log from "../../tasks/log";

describe("LibTxDecoder", function () {
    let rlpWriter: any;
    let libTxDecoder: any;
    let signer0: any;

    const chainId = 167;

    before(async function () {
        rlpWriter = await (
            await ethers.getContractFactory("TestLibRLPWriter")
        ).deploy();
        libTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        ).deploy();

        signer0 = (await ethers.getSigners())[0];
    });

    async function rlpEncodeTxList(txList: string[]) {
        const rlpEncodedBytes = [];
        for (const tx of txList) {
            const txRlp = await rlpWriter.writeBytes(tx);
            rlpEncodedBytes.push(txRlp);
        }
        const txListBytes = await rlpWriter.writeList(rlpEncodedBytes);
        return txListBytes;
    }

    describe("decodeTxList", function () {
        it("should not revert if tx list is empty", async function () {
            const txList: string[] = [];
            const txListBytes = await rlpEncodeTxList(txList);

            let decoded = await libTxDecoder.callStatic.decodeTxList(
                chainId,
                txListBytes
            );

            expect(decoded.items.length).to.be.eql(0);
            decoded = await libTxDecoder.callStatic.decodeTxList(chainId, []);
            expect(decoded.items.length).to.be.eql(0);
        });

        it("should revert with random bytes", async function () {
            const randomBytes = ethers.utils.hexlify(
                ethers.utils.randomBytes(73)
            );

            await expect(
                libTxDecoder.callStatic.decodeTxList(chainId, randomBytes)
            ).to.be.reverted;
        });

        it("can decode txList with legacy transaction", async function () {
            const txLegacy: UnsignedTransaction = {
                nonce: 1,
                chainId: chainId,
                gasPrice: 11e9,
                gasLimit: 123456,
                to: ethers.Wallet.createRandom().address,
                value: ethers.utils.parseEther("1.23"),
                data: ethers.utils.randomBytes(10),
            };

            const signature = await signer0.signMessage("abc123");
            // log.debug('signature: ', signature)

            const txLegacyBytes = ethers.utils.serializeTransaction(
                txLegacy,
                signature
            );
            log.debug("txLegacyBytes: ", txLegacyBytes);
            const txListBytes = await rlpEncodeTxList([txLegacyBytes]);
            log.debug("txListBytes: ", txListBytes);

            const decodedTxList = await libTxDecoder.callStatic.decodeTxList(
                chainId,
                txListBytes
            );
            // log.debug('decodedT: ', decodedTxList)
            expect(decodedTxList.items.length).to.equal(1);
            const decodedTx1 = decodedTxList.items[0];
            expect(decodedTx1.gasLimit.toNumber()).to.equal(txLegacy.gasLimit);
        });

        it("can decode txList with 2930 transaction", async function () {
            const tx2930: UnsignedTransaction = {
                type: 1,
                chainId: 12345,
                nonce: 123,
                gasPrice: 11e9,
                gasLimit: 123,
                to: ethers.Wallet.createRandom().address,
                value: ethers.utils.parseEther("10.23"),
                accessList: [],
                data: ethers.utils.randomBytes(20),
            };

            const signature = await signer0.signMessage(
                tx2930.data?.toString()
            );
            log.debug("signature: ", signature);

            const txBytes = ethers.utils.serializeTransaction(
                tx2930,
                signature
            );
            log.debug("txBytes: ", txBytes);
            const txListBytes = await rlpEncodeTxList([txBytes]);
            log.debug("txListBytes: ", txListBytes);

            const decodedTxList = await libTxDecoder.callStatic.decodeTxList(
                chainId,
                txListBytes
            );
            expect(decodedTxList.items.length).to.equal(1);
            const decodedTx1 = decodedTxList.items[0];
            expect(decodedTx1.gasLimit.toNumber()).to.equal(tx2930.gasLimit);
        });

        it("can decode txList with 1559 transaction", async function () {
            const tx1559: UnsignedTransaction = {
                type: 2,
                chainId: 12345,
                nonce: 123,
                maxPriorityFeePerGas: 2e9,
                maxFeePerGas: 22e9,
                gasLimit: 1234567,
                to: ethers.Wallet.createRandom().address,
                value: ethers.utils.parseEther("10.123"),
                accessList: [],
                data: ethers.utils.randomBytes(20),
            };

            const signature = await signer0.signMessage(
                tx1559.data?.toString()
            );
            log.debug("signature: ", signature);

            const txBytes = ethers.utils.serializeTransaction(
                tx1559,
                signature
            );
            log.debug("txBytes: ", txBytes);
            const txListBytes = await rlpEncodeTxList([txBytes]);
            log.debug("txListBytes: ", txListBytes);

            const decodedTxList = await libTxDecoder.callStatic.decodeTxList(
                chainId,
                txListBytes
            );
            expect(decodedTxList.items.length).to.equal(1);
            const decodedTx1 = decodedTxList.items[0];
            expect(decodedTx1.gasLimit.toNumber()).to.equal(tx1559.gasLimit);
        });
    });

    it("can decode txList with multiple types", async function () {
        const signature = await signer0.signMessage("123456abcdef");
        const txLegacy: UnsignedTransaction = {
            nonce: 1,
            chainId: chainId,
            gasPrice: 11e9,
            gasLimit: 123456,
            to: ethers.Wallet.createRandom().address,
            value: ethers.utils.parseEther("1.23"),
            data: ethers.utils.randomBytes(10),
        };

        const tx2930: UnsignedTransaction = {
            type: 1,
            chainId: 12345,
            nonce: 123,
            gasPrice: 11e9,
            gasLimit: 123,
            to: ethers.Wallet.createRandom().address,
            value: ethers.utils.parseEther("10.23"),
            accessList: [],
            data: ethers.utils.randomBytes(20),
        };

        const tx1559: UnsignedTransaction = {
            type: 2,
            chainId: 12345,
            nonce: 123,
            maxPriorityFeePerGas: 2e9,
            maxFeePerGas: 22e9,
            gasLimit: 1234567,
            to: ethers.Wallet.createRandom().address,
            value: ethers.utils.parseEther("10.123"),
            accessList: [],
            data: ethers.utils.randomBytes(20),
        };

        const txObjArr = [txLegacy, tx2930, tx1559];
        const txRawBytesArr = [];
        for (const txObj of txObjArr) {
            const txBytes = ethers.utils.serializeTransaction(txObj, signature);
            txRawBytesArr.push(txBytes);
        }
        const txListBytes = await rlpEncodeTxList(txRawBytesArr);

        const decodedTxList = await libTxDecoder.callStatic.decodeTxList(
            chainId,
            txListBytes
        );
        // log.debug('decodedT: ', decodedTxList)
        expect(decodedTxList.items.length).to.equal(txObjArr.length);
        for (let i = 0; i < txObjArr.length; i++) {
            const txObj = txObjArr[i];
            const decodedTx = decodedTxList.items[i];
            expect(decodedTx.gasLimit.toNumber()).to.equal(txObj.gasLimit);
        }
    });
});
