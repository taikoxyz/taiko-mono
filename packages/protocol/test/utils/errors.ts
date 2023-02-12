import { ethers, utils } from "ethers";
import { expect } from "chai";

async function txShouldRevertWithCustomError(
    provider: ethers.providers.JsonRpcProvider,
    txPromise: Promise<any>,
    customError: String
) {
    try {
        await (await txPromise).wait(1);
        expect.fail("Expected promise to throw but it didn't");
    } catch (tx) {
        const _tx = await provider.getTransaction(tx.transactionHash);

        const code = await provider.call(_tx, _tx.blockNumber);

        const expectedCode = utils
            .keccak256(utils.toUtf8Bytes(customError))
            .substring(0, 10);
        console.log(code, expectedCode);
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

export { txShouldRevertWithCustomError };
