import { ethers } from "hardhat";
import { BlockMetadata } from "./block_metadata";
import Evidence from "./evidence";

function encodeBlockMetadata(meta: BlockMetadata) {
    return ethers.utils.defaultAbiCoder.encode(
        [
            "tuple(uint256 id, uint256 l1Height, bytes32 l1Hash, address beneficiary, bytes32 txListHash, bytes32 mixHash, bytes extraData, uint64 gasLimit, uint64 timestamp, uint64 commitHeight, uint64 commitSlot)",
        ],
        [meta]
    );
}

function encodeEvidence(evidence: Evidence) {
    return ethers.utils.defaultAbiCoder.encode(
        [
            "tuple(tuple(uint256 id, uint256 l1Height, bytes32 l1Hash, address beneficiary, bytes32 txListHash, bytes32 mixHash, bytes extraData, uint64 gasLimit, uint64 timestamp, uint64 commitHeight, uint64 commitSlot) meta, tuple(bytes32 parentHash, bytes32 ommersHash, address beneficiary, bytes32 stateRoot, bytes32 transactionsRoot, bytes32 receiptsRoot, bytes32[8] logsBloom, uint256 difficulty, uint128 height, uint64 gasLimit, uint64 gasUsed, uint64 timestamp, bytes extraData, bytes32 mixHash, uint64 nonce, uint256 baseFeePerGas) header, address prover, bytes[] proofs, uint16[] circuits)",
        ],
        [evidence]
    );
}

export { encodeBlockMetadata, encodeEvidence };
