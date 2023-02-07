import { expect } from "chai";
import { ContractTransaction } from "ethers";

const customErrorSelectors: { [key: string]: string } = {
    InvalidProcessMessageGasLimit: "0x4de260a2",
};

async function assertCustomError(
    fn: () => Promise<ContractTransaction>,
    error: string
) {
    try {
        await fn();
    } catch (e) {
        console.log("error", e);
        expect(
            (e as { transaction: { data: string } }).transaction.data
        ).to.be.eq(customErrorSelectors[error]);
    }
}

export { customErrorSelectors, assertCustomError };
