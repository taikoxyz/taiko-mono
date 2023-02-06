import { expect } from "chai";
import { TaikoL1 } from "../../typechain";

async function halt(taikoL1: TaikoL1, halt: boolean) {
    await (await taikoL1.halt(true)).wait(1);
    const isHalted = await taikoL1.isHalted();
    expect(isHalted).to.be.eq(halt);
    return isHalted;
}

export default halt;
