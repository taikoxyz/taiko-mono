import { ethers, utils } from "ethers";
import { expect } from "chai";

async function txShouldRevertWithCustomError(
    txPromise: Promise<any>,
    provider: ethers.providers.JsonRpcProvider,
    customError: string
) {
    try {
        await txPromise;
        expect.fail("Expected promise to throw but it didn't");
    } catch (tx) {
        // console.log(tx)
        const _tx = await provider.getTransaction(
            (tx as { transactionHash: string }).transactionHash
        );
        const code = await provider.call(
            _tx as ethers.providers.TransactionRequest,
            _tx.blockNumber
        );

        const expectedCode = utils
            .keccak256(utils.toUtf8Bytes(customError))
            .substring(0, 10);

        if (code !== expectedCode) {
            expect.fail(
                `Error code mismatch: actual=
                ${code}
                expected=
                ${expectedCode}`
            );
        }
    }
}

async function readShouldRevertWithCustomError(
    txPromise: Promise<any>,
    customError: string
) {
    try {
        await txPromise;

        expect.fail("Expected promise to throw but it didn't");
    } catch (result) {
        const r = result as { errorSignature: string };
        if (r.errorSignature !== customError) {
            expect.fail(
                `Error code mismatch: actual=
                ${r.errorSignature} 
                "expected=" 
                ${customError}`
            );
        }
    }
}

export { txShouldRevertWithCustomError, readShouldRevertWithCustomError };
