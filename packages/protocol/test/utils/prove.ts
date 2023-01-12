import { ethers } from "ethers";
import RLP from "rlp";
import { TaikoL1, TaikoL2 } from "../../typechain";
import { BlockMetadata } from "./block_metadata";
import Evidence from "./evidence";
import { BlockHeader, getBlockHeader } from "./rpc";

const buildProveBlockInputs = (
    meta: BlockMetadata,
    header: BlockHeader,
    prover: string,
    anchorTx: Uint8Array,
    anchorReceipt: any
) => {
    const inputs = [];
    const evidence: Evidence = {
        meta: meta,
        header: header,
        prover: prover,
        proofs: [], // TODO
    };

    inputs[0] = evidence;
    inputs[1] = anchorTx;
    inputs[2] = anchorReceipt;
    return inputs;
};

const proveBlock = async (
    taikoL1: TaikoL1,
    taikoL2: TaikoL2,
    l1Provider: ethers.providers.JsonRpcProvider,
    l2Provider: ethers.providers.JsonRpcProvider,
    proverAddress: string,
    blockId: number,
    blockNumber: number,
    meta: BlockMetadata
) => {
    const header = await getBlockHeader(l2Provider, blockNumber);
    const anchorTx = await taikoL2.anchor(meta.l1Height, meta.l1Hash);
    const anchorTxRLPEncoded = await RLP.encode(
        ethers.utils.serializeTransaction(anchorTx)
    );
    const anchorReceipt = await anchorTx.wait(1);
    const anchorReceiptRLPEncoded = RLP.encode(
        ethers.utils.serializeTransaction(anchorReceipt)
    );

    const inputs = buildProveBlockInputs(
        meta,
        header.blockHeader,
        proverAddress,
        anchorTxRLPEncoded,
        anchorReceiptRLPEncoded
    );
    const tx = await taikoL1.proveBlock(blockId, inputs);
    console.log("Proved block tx", tx.hash);
    const receipt = await tx.wait(1);
    return receipt;
};

export { buildProveBlockInputs, proveBlock };
