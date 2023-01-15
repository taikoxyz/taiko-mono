import { ethers } from "ethers";
import { TaikoL1 } from "../../typechain";
import { commitBlock } from "./commit";
import { proposeBlock } from "./propose";
import sleep from "./sleep";

class Proposer {
    private readonly taikoL1: TaikoL1;
    private readonly l2Provider: ethers.providers.JsonRpcProvider;
    private readonly commitConfirms: number;
    private readonly maxNumBlocks: number;
    private nextCommitSlot: number;

    private proposingMutex: boolean = false;

    constructor(
        taikoL1: TaikoL1,
        l2Provider: ethers.providers.JsonRpcProvider,
        commitConfirms: number,
        maxNumBlocks: number,
        initialCommitSlot: number
    ) {
        this.taikoL1 = taikoL1;
        this.l2Provider = l2Provider;
        this.commitConfirms = commitConfirms;
        this.maxNumBlocks = maxNumBlocks;
        this.nextCommitSlot = initialCommitSlot;
    }

    async commitThenProposeBlock(block?: ethers.providers.Block) {
        while (this.proposingMutex) {
            await sleep(100);
        }
        this.proposingMutex = true;
        if (!block) block = await this.l2Provider.getBlock("latest");
        const commitSlot = this.nextCommitSlot++;
        console.log("commiting ", block.number, "with commit slot", commitSlot);
        const { tx, commit } = await commitBlock(
            this.taikoL1,
            block,
            commitSlot
        );
        const commitReceipt = await tx.wait(this.commitConfirms ?? 1);

        console.log("proposing", block.number, "with commit slot", commitSlot);

        const receipt = await proposeBlock(
            this.taikoL1,
            block,
            commit.txListHash,
            commitReceipt.blockNumber as number,
            block.gasLimit,
            commitSlot
        );

        this.proposingMutex = false;

        return receipt;
    }
}

export default Proposer;
