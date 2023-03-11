import { ethers } from "ethers";
import { TaikoL1 } from "../../typechain";
import { BlockProposedEvent } from "../../typechain/LibProposing";
import { proposeBlock } from "./propose";
import sleep from "./sleep";

class Proposer {
    private readonly taikoL1: TaikoL1;
    private readonly l2Provider: ethers.providers.JsonRpcProvider;
    private readonly maxNumBlocks: number;
    private signer: ethers.Wallet;

    private proposingMutex: boolean = false;

    constructor(
        taikoL1: TaikoL1,
        l2Provider: ethers.providers.JsonRpcProvider,
        maxNumBlocks: number,
        signer: ethers.Wallet
    ) {
        this.taikoL1 = taikoL1;
        this.l2Provider = l2Provider;
        this.maxNumBlocks = maxNumBlocks;
        this.signer = signer;
    }

    getSigner() {
        return this.signer;
    }

    async proposeBlock(block?: ethers.providers.Block) {
        try {
            while (this.proposingMutex) {
                await sleep(500);
            }
            this.proposingMutex = true;
            if (!block) block = await this.l2Provider.getBlock("latest");

            const receipt = await proposeBlock(
                this.taikoL1,
                block,
                block.gasLimit
            );

            const proposedEvent: BlockProposedEvent = (
                receipt.events as any[]
            ).find((e) => e.event === "BlockProposed");

            this.proposingMutex = false;

            return { receipt, proposedEvent };
        } finally {
            this.proposingMutex = false;
        }
    }
}

export default Proposer;
