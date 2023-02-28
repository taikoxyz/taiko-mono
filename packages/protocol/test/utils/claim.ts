import { BigNumber } from "ethers";
import { TaikoL1 } from "../../typechain";
import { ClaimBlockBidEvent } from "../../typechain/LibProving";
import sleep from "./sleep";

const claimBlock = async (
    taikoL1: TaikoL1,
    blockId: number,
    bid: BigNumber
) => {
    const tx = await taikoL1.claimBlock(blockId, {
        value: bid,
        gasLimit: 1000000,
    });
    const receipt = await tx.wait(1);
    const claimBlockBidEvent: ClaimBlockBidEvent = (
        receipt.events! as any[]
    ).find((e) => e.event === "ClaimBlockBid");
    return { tx, receipt, claimBlockBidEvent };
};

const waitForClaimToBeProvable = async (taikoL1: TaikoL1, blockId: number) => {
    let isProvable = await taikoL1.isClaimedBlockProvable(blockId);
    while (!isProvable) {
        await sleep(1 * 1000);
        isProvable = await taikoL1.isClaimedBlockProvable(blockId);
    }
    return isProvable;
};

export { claimBlock, waitForClaimToBeProvable };
