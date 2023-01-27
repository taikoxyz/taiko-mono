import { expect } from "chai";
import { ethers } from "ethers";
import { EventEmitter } from "stream";
import { TaikoL1 } from "../../typechain";
import { BlockProposedEvent } from "../../typechain/LibProposing";
import { BlockProvenEvent } from "../../typechain/LibProving";
import { BlockMetadata } from "./block_metadata";
import { encodeEvidence } from "./encoding";
import { BLOCK_PROVEN_EVENT } from "./event";
import Evidence from "./evidence";
import Prover from "./prover";
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

function newProverListener(
    prover: Prover,
    taikoL1: TaikoL1,
    eventEmitter: EventEmitter
) {
    return async (proposedEvent: BlockProposedEvent, blockNumber: number) => {
        try {
            const { args } = await prover.prove(
                await prover.getSigner().getAddress(),
                proposedEvent.args.id.toNumber(),
                blockNumber,
                proposedEvent.args.meta as any as BlockMetadata
            );
            const { blockHash, id: blockId, parentHash, provenAt } = args;

            const proposedBlock = await taikoL1.getProposedBlock(
                proposedEvent.args.id.toNumber()
            );

            const forkChoice = await taikoL1.getForkChoice(
                blockId.toNumber(),
                parentHash
            );

            expect(forkChoice.blockHash).to.be.eq(blockHash);

            expect(forkChoice.provers[0]).to.be.eq(
                await prover.getSigner().getAddress()
            );

            const provedBlock = {
                proposedAt: proposedBlock.proposedAt.toNumber(),
                provenAt: provenAt.toNumber(),
                id: proposedEvent.args.id.toNumber(),
                parentHash: parentHash,
                blockHash: blockHash,
                forkChoice: forkChoice,
                deposit: proposedBlock.deposit,
                proposer: proposedBlock.proposer,
            };

            eventEmitter.emit(BLOCK_PROVEN_EVENT, provedBlock);
        } catch (e) {
            eventEmitter.emit("error", e);
        }
    };
}

export { buildProveBlockInputs, proveBlock, newProverListener };
