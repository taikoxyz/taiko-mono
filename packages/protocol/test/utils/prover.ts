import { ethers } from "ethers";
import { TaikoL1 } from "../../typechain";
import { BlockProvenEvent } from "../../typechain/LibProving";
import { BlockMetadata } from "./block_metadata";
import { proveBlock } from "./prove";
import sleep from "./sleep";

class Prover {
    private readonly taikoL1: TaikoL1;
    private readonly l2Provider: ethers.providers.JsonRpcProvider;
    private provingMutex: boolean = false;
    private readonly signer: ethers.Wallet;

    constructor(
        taikoL1: TaikoL1,
        l2Provider: ethers.providers.JsonRpcProvider,
        signer: ethers.Wallet
    ) {
        this.taikoL1 = taikoL1;
        this.l2Provider = l2Provider;
        this.signer = signer;
    }

    getSigner() {
        return this.signer;
    }

    async prove(
        proverAddress: string,
        blockId: number,
        blockNumber: number,
        meta: BlockMetadata
    ): Promise<BlockProvenEvent> {
        while (this.provingMutex) {
            await sleep(100);
        }
        this.provingMutex = true;

        let blockProvenEvent: BlockProvenEvent;
        try {
            blockProvenEvent = await proveBlock(
                this.taikoL1,
                this.l2Provider,
                proverAddress,
                blockId,
                blockNumber,
                meta
            );
        } catch (e) {
            console.error("prove error", e);
            throw e;
        } finally {
            this.provingMutex = false;
        }

        return blockProvenEvent;
    }
}

export default Prover;
