import { ethers } from "hardhat";
import { BlockMetadata } from "./block_metadata";
import Evidence from "./evidence";

function encodeBlockMetadata(meta: BlockMetadata) {
    return ethers.utils.defaultAbiCoder.encode(
        [
            "tuple(uint64 id,uint64 gasLimit,uint64 timestamp,uint64 l1Height,bytes32 l1Hash,bytes32 mixHash,bytes32 txListHash,uint32 txListStart,uint32 txListEnd,address beneficiary}",
        ],
        [meta]
    );
}

function encodeEvidence(evidence: Evidence) {
    return ethers.utils.defaultAbiCoder.encode(
        [
            "tuple(tuple(uint64 id,uint64 gasLimit,uint64 timestamp,uint64 l1Height,bytes32 l1Hash,bytes32 mixHash,bytes32 txListHash,uint32 txListStart,uint32 txListEnd,address beneficiary) meta,tuple(bytes data,uint256 circuitId) zkproof,bytes32 parentHash,bytes32 blockHash,bytes32 signalRoot,address prover)",
        ],
        [evidence]
    );
}

export { encodeBlockMetadata, encodeEvidence };
