import { ethers } from "hardhat";
import { BlockMetadata } from "./block_metadata";

function encodeBlockMetadata(meta: BlockMetadata) {
    return ethers.utils.defaultAbiCoder.encode(
        [
            "tuple(uint256 id, uint256 l1Height, bytes32 l1Hash, address beneficiary, bytes32 txListHash, bytes32 mixHash, bytes extraData, uint64 gasLimit, uint64 timestamp, uint64 commitHeight, uint64 commitSlot)",
        ],
        [meta]
    );
}

export { encodeBlockMetadata };
