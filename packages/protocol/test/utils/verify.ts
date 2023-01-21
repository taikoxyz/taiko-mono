import { TaikoL1 } from "../../typechain";
import { BlockVerifiedEvent } from "../../typechain/LibVerifying";

async function verifyBlocks(taikoL1: TaikoL1, maxBlocks: number) {
    const verifyTx = await taikoL1.verifyBlocks(maxBlocks);
    const verifyReceipt = await verifyTx.wait(1);
    const verifiedEvent: BlockVerifiedEvent = (
        verifyReceipt.events as any[]
    ).find((e) => e.event === "BlockVerified");
    return verifiedEvent;
}

export default verifyBlocks;
