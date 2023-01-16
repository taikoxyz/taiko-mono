import { ethers } from "ethers";
import { TaikoL1, TaikoL2 } from "../../typechain";
import { BlockMetadata } from "./block_metadata";
import { proveBlock } from "./prove";
import sleep from "./sleep";

class Prover {
    private readonly taikoL1: TaikoL1;
    private readonly taikoL2: TaikoL2;
    private readonly l1Provider: ethers.providers.JsonRpcProvider;
    private readonly l2Provider: ethers.providers.JsonRpcProvider;
    private readonly l2Signer: ethers.Signer;
    private provingMutex: boolean = false;

    constructor(
        taikoL1: TaikoL1,
        taikoL2: TaikoL2,
        l1Provider: ethers.providers.JsonRpcProvider,
        l2Provider: ethers.providers.JsonRpcProvider,
        l2Signer: ethers.Signer
    ) {
        this.taikoL1 = taikoL1;
        this.taikoL2 = taikoL2;
        this.l1Provider = l1Provider;
        this.l2Provider = l2Provider;
        this.l2Signer = l2Signer;
    }

    async prove(
        proverAddress: string,
        blockId: number,
        blockNumber: number,
        meta: BlockMetadata
    ) {
        while (this.provingMutex) {
            await sleep(100);
        }
        this.provingMutex = true;

        await proveBlock(
            this.taikoL1,
            this.taikoL2,
            this.l2Signer,
            this.l2Provider,
            proverAddress,
            blockId,
            blockNumber,
            meta
        );
    }
}

export default Prover;
