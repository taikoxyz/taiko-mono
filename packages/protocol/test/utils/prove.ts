import { ethers } from "ethers";
import { TaikoL1 } from "../../typechain";
import { BlockProvenEvent } from "../../typechain/LibProving";
import { BlockMetadata } from "./block_metadata";
import { encodeEvidence } from "./encoding";
import Evidence from "./evidence";
import { BlockHeader, getBlockHeader } from "./rpc";

const buildProveBlockInputs = (
    meta: BlockMetadata,
    header: BlockHeader,
    prover: string,
    anchorTx: Uint8Array | string,
    anchorReceipt: Uint8Array | string,
    zkProofsPerBlock: number
) => {
    const inputs = [];
    const evidence: Evidence = {
        meta: meta,
        header: header,
        prover: prover,
        proofs: [],
        circuits: [],
    };

    // we have mkp + zkp returnign true in testing, so can just push 0xff
    // instead of actually making proofs for anchor tx, anchor receipt, and
    // zkp
    for (let i = 0; i < zkProofsPerBlock + 2; i++) {
        evidence.proofs.push("0xff");
    }

    for (let i = 0; i < zkProofsPerBlock; i++) {
        evidence.circuits.push(1);
    }

    inputs[0] = encodeEvidence(evidence);
    inputs[1] = anchorTx;
    inputs[2] = anchorReceipt;
    return inputs;
};

const proveBlock = async (
    taikoL1: TaikoL1,
    l2Provider: ethers.providers.JsonRpcProvider,
    proverAddress: string,
    blockId: number,
    blockNumber: number,
    meta: BlockMetadata
): Promise<BlockProvenEvent> => {
    const config = await taikoL1.getConfig();
    const header = await getBlockHeader(l2Provider, blockNumber);
    const inputs = buildProveBlockInputs(
        meta,
        header.blockHeader,
        proverAddress,
        "0x",
        "0x",
        config.zkProofsPerBlock.toNumber()
    );
    const tx = await taikoL1.proveBlock(blockId, inputs);
    const receipt = await tx.wait(1);
    const event: BlockProvenEvent = (receipt.events as any[]).find(
        (e) => e.event === "BlockProven"
    );
    return event;
};

export { buildProveBlockInputs, proveBlock };
