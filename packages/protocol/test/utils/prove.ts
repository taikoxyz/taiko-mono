import { ethers } from "ethers";
import RLP from "rlp";
import { TaikoL1, TaikoL2 } from "../../typechain";
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
        proofs: [], // TODO
    };
    // we have mkp + zkp returnign true in testing, so can just push 0xff
    // instead of actually making proofs for anchor tx, anchor receipt, and
    // zkp
    for (let i = 0; i < zkProofsPerBlock + 2; i++) {
        evidence.proofs.push("0xff");
    }

    inputs[0] = encodeEvidence(evidence);
    inputs[1] = anchorTx;
    inputs[2] = anchorReceipt;
    return inputs;
};

// TODO
const proveBlock = async (
    taikoL1: TaikoL1,
    taikoL2: TaikoL2,
    l2Signer: ethers.Signer,
    l2Provider: ethers.providers.JsonRpcProvider,
    proverAddress: string,
    blockId: number,
    blockNumber: number,
    meta: BlockMetadata
) => {
    const config = await taikoL1.getConfig();
    const header = await getBlockHeader(l2Provider, blockNumber);

    const anchorTxPopulated = await taikoL2.populateTransaction.anchor(
        meta.l1Height,
        meta.l1Hash,
        {
            gasPrice: ethers.utils.parseUnits("5", "gwei"),
            gasLimit: config.anchorTxGasLimit,
        }
    );

    delete anchorTxPopulated.from;

    const anchorTxSigned = await l2Signer.signTransaction(anchorTxPopulated);

    const anchorTx = await l2Provider.sendTransaction(anchorTxSigned);

    await anchorTx.wait();

    const anchorReceipt = await anchorTx.wait(1);

    const anchorTxRLPEncoded = RLP.encode(
        ethers.utils.serializeTransaction(anchorTxPopulated)
    );

    const anchorReceiptRLPEncoded = RLP.encode(
        ethers.utils.serializeTransaction(anchorReceipt)
    );

    const inputs = buildProveBlockInputs(
        meta,
        header.blockHeader,
        proverAddress,
        anchorTxRLPEncoded,
        anchorReceiptRLPEncoded,
        config.zkProofsPerBlock.toNumber()
    );
    const tx = await taikoL1.proveBlock(blockId, inputs);
    console.log("Proved block tx", tx.hash);
    const receipt = await tx.wait(1);
    return receipt;
};

export { buildProveBlockInputs, proveBlock };
