import { expect } from "chai";
// eslint-disable-next-line import/no-named-default
import { default as hre, ethers } from "hardhat";

describe("integration:LibReceiptDecoder", function () {
    let libReceiptDecoder: any;

    before(async function () {
        if (hre.network.name === "hardhat") {
            throw new Error(
                `hardhat: debug_getRawReceipts - Method not supported`
            );
        }

        const baseLibReceiptDecoder = await (
            await ethers.getContractFactory("LibReceiptDecoder")
        ).deploy();

        libReceiptDecoder = await (
            await ethers.getContractFactory("TestLibReceiptDecoder", {
                libraries: {
                    LibReceiptDecoder: baseLibReceiptDecoder.address,
                },
            })
        ).deploy();
    });

    it("should decode RLP encoded transaction receipts", async function () {
        for (const txType of [0, 1, 2]) {
            const { maxFeePerGas, gasPrice } =
                await hre.ethers.provider.getFeeData();

            let txOptions = {};

            if (txType === 0) txOptions = { gasPrice };
            else if (txType === 1) txOptions = { gasPrice, accessList: [] };
            else txOptions = { maxFeePerGas };

            const tx = await libReceiptDecoder.emitTestEvent(
                ethers.BigNumber.from(ethers.utils.randomBytes(32)),
                ethers.utils.randomBytes(32),
                txOptions
            );

            expect(tx.type).to.be.equal(txType);

            const expectedReceipt = await tx.wait();

            // Retrieves the RLP-encoded raw receipts from node
            const [encodedReceipt] = await hre.ethers.provider.send(
                "debug_getRawReceipts",
                [tx.blockHash]
            );

            const receipt = await libReceiptDecoder.decodeReceipt(
                encodedReceipt
            );

            // Status
            expect(receipt.status).to.be.equal(expectedReceipt.status);
            // CumulativeGasUsed
            expect(receipt.cumulativeGasUsed).to.be.equal(
                expectedReceipt.cumulativeGasUsed
            );
            // LogsBloom
            expect(
                `0x${receipt.logsBloom.map((s: any) => s.slice(2)).join("")}`
            ).to.be.equal(expectedReceipt.logsBloom);
            // Logs
            expect(receipt.logs.length).to.be.equal(
                expectedReceipt.logs.length
            );
            for (let i = 0; i < receipt.logs.length; i++) {
                const log = receipt.logs[i];
                const expectedLog = expectedReceipt.logs[i];

                expect(log.contractAddress).to.be.equal(expectedLog.address);
                expect(log.topics).to.be.eql(expectedLog.topics);
                expect(log.data).to.be.equal(expectedLog.data);
            }
        }
    });
});
