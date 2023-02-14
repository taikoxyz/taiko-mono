import { ethers, utils } from "ethers";
import { expect } from "chai";

async function txShouldRevertWithCustomError(
    txPromise: Promise<any>,
    provider: ethers.providers.JsonRpcProvider,
    customError: String
) {
    try {
        await txPromise;
        expect.fail("Expected promise to throw but it didn't");
    } catch (tx) {
        // console.log(tx)
        const _tx = await provider.getTransaction(tx.transactionHash);
        // console.log(_tx)
        const code = await provider.call(_tx, _tx.blockNumber);
        const expectedCode = utils
            .keccak256(utils.toUtf8Bytes(customError))
            .substring(0, 10);

        if (code !== expectedCode) {
            expect.fail(
                "Error code mismatch: actual=",
                code,
                "expected=",
                expectedCode
            );
        }
    }
}

async function readShouldRevertWithCustomError(
    txPromise: Promise<any>,
    customError: String
) {
    try {
        await txPromise;

        expect.fail("Expected promise to throw but it didn't");
    } catch (result) {
        if (result.errorSignature !== customError) {
            expect.fail(
                "Error code mismatch: actual=",
                result.errorSignature,
                "expected=",
                customError
            );
        }
    }
}

export { txShouldRevertWithCustomError, readShouldRevertWithCustomError };
