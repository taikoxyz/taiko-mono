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
    private signer: ethers.Wallet;

    private proposingMutex: boolean = false;

    constructor(
        taikoL1: TaikoL1,
        l2Provider: ethers.providers.JsonRpcProvider,
        commitConfirms: number,
        maxNumBlocks: number,
        initialCommitSlot: number,
        signer: ethers.Wallet
    ) {
        this.taikoL1 = taikoL1;
        this.l2Provider = l2Provider;
        this.commitConfirms = commitConfirms;
        this.maxNumBlocks = maxNumBlocks;
        this.nextCommitSlot = initialCommitSlot;
        this.signer = signer;
    }

    getSigner() {
        return this.signer;
    }

    async commitThenProposeBlock(block?: ethers.providers.Block) {
        try {
            while (this.proposingMutex) {
                await sleep(500);
            }
            this.proposingMutex = true;
            if (!block) block = await this.l2Provider.getBlock("latest");
            const commitSlot = this.nextCommitSlot++;
            const { tx, commit } = await commitBlock(
                this.taikoL1,
                block,
                commitSlot
            );
            const commitReceipt = await tx.wait(this.commitConfirms ?? 1);

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
        } finally {
            this.proposingMutex = false;
        }
    }
}

export default Proposer;
