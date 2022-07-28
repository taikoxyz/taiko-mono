// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../libs/LibTxListDecoder.sol";

struct TaikoHeader {
    bytes32 blockHash;
}

struct PendingBlock {
    uint256 anchorHeight; // known L1 block height
    bytes32 anchorHash; // known L1 block hash
    bytes32 txListHash; // the hash or KGZ commitment of the encoded txList
}

struct ProofReceipt {
    bytes32 blockHash; // the claimed block hash of this block
    address prover; // msg.sender of proveBlock tx
}

contract TaikoL1 {
    bytes32 public constant INVALID_BLOCK_MARKER =
        keccak256("INVALID_BLOCK_MARKER");
    // Finalized taiko block headers
    mapping(uint256 => TaikoHeader) finalizedBlockHeaders;

    // Pending Taiko blocks
    mapping(uint256 => PendingBlock) pendingBlocks;

    mapping(uint256 => mapping(bytes32 => ProofReceipt)) proofReceipts;

    address taikoL2Address;
    uint64 lastFinalizedBlockIndex;
    uint64 nextPendingBlockIndex;

    modifier mayFinalizeBlocks() {
        _;
        tryToFinalizedMoreBlocks();
    }

    modifier blockIsPending(uint256 index) {
        require(
            index > lastFinalizedBlockIndex && index < nextPendingBlockIndex
        );
        _;
    }

    function proposeBlock(
        uint256 anchorHeight,
        bytes32 anchorHash,
        bytes calldata txList // or bytes32 txListHash when using blob
    ) external {
        require(txList.length > 0);

        require(
            anchorHeight >= block.number - 100 &&
                blockhash(anchorHeight) == anchorHash
        );

        pendingBlocks[nextPendingBlockIndex++] = PendingBlock({
            anchorHeight: anchorHeight,
            anchorHash: anchorHash,
            txListHash: keccak256(txList)
        });
    }

    function proveBlock(
        uint256 index,
        bytes32 parentBlockHash,
        bytes32 blockHash,
        bytes calldata zkproof,
        bytes calldata mkproof
    ) external blockIsPending(index) mayFinalizeBlocks {
        verifyZKProof(
            parentBlockHash,
            blockHash,
            pendingBlocks[index].txListHash,
            zkproof
        );
        (bytes32 storageKey, bytes32 storageValue) = verifyMKProof(
            blockHash,
            mkproof
        );

        // we need to calculate storageKey based on taikoL2Address,  pendingBlocks[index].anchorHeight
        // but the following calculation is not correct.
        //
        // see TaikoL2.sol `prepareBlock`
        bytes32 expectedStorageKey; // = keccak256(taikoL2Address, pendingBlocks[index].anchorHeight);

        require(
            storageKey == expectedStorageKey &&
                storageValue == pendingBlocks[index].anchorHash
        );

        proofReceipts[index][parentBlockHash] = ProofReceipt({
            blockHash: blockHash,
            prover: msg.sender
        });
    }

    function proveBlockInvalid(
        uint256 index,
        uint256 parentIndex,
        bytes32 txListHash, // hash of a txList that contains a verifyBlockInvalid tx on L2.
        bytes32 blockHash,
        bytes calldata zkproof,
        bytes calldata mkproof
    ) external blockIsPending(index) mayFinalizeBlocks {
        require(lastFinalizedBlockIndex >= parentIndex);

        bytes32 parentBlockHash = finalizedBlockHeaders[parentIndex].blockHash;

        verifyZKProof(parentBlockHash, blockHash, txListHash, zkproof);

        (bytes32 storageKey, bytes32 storageValue) = verifyMKProof(
            blockHash,
            mkproof
        );

        // we need to calculate storageKey based on taikoL2Address and pendingBlocks[index].txListHash
        // but the following calculation is not correct.
        bytes32 expectedStorageKey; // = keccak256(taikoL2Address, pendingBlocks[index].txListHash);

        require(
            storageKey == expectedStorageKey &&
                storageValue == pendingBlocks[index].txListHash
        );

        proofReceipts[index][INVALID_BLOCK_MARKER] = ProofReceipt({
            blockHash: INVALID_BLOCK_MARKER,
            prover: msg.sender
        });
    }

    function verifyBlockInvalid(uint256 index, bytes calldata txList)
        external
        blockIsPending(index)
        mayFinalizeBlocks
    {
        require(!isTxListDecodable(txList));
        require(keccak256(txList) == pendingBlocks[index].txListHash);

        proofReceipts[index][INVALID_BLOCK_MARKER] = ProofReceipt({
            blockHash: INVALID_BLOCK_MARKER,
            prover: msg.sender
        });
    }

    function isTxListDecodable(bytes calldata encoded)
        public
        view
        returns (bool)
    {
        try LibTxListDecoder.decodeTxList(encoded) returns (TxList memory) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }

    function tryToFinalizedMoreBlocks() internal {
        bytes32 parentBlockHash = finalizedBlockHeaders[lastFinalizedBlockIndex]
            .blockHash;
        uint256 i = lastFinalizedBlockIndex + 1;

        while (i < nextPendingBlockIndex) {
            if (proofReceipts[i][parentBlockHash].blockHash != 0x0) {
                parentBlockHash = proofReceipts[i][parentBlockHash].blockHash;
                finalizedBlockHeaders[i] = TaikoHeader({
                    blockHash: parentBlockHash
                });
                nextPendingBlockIndex += 1;
                i += 1;
            } else if (
                proofReceipts[i][INVALID_BLOCK_MARKER].blockHash ==
                INVALID_BLOCK_MARKER
            ) {
                finalizedBlockHeaders[i] = TaikoHeader({
                    blockHash: parentBlockHash
                });
                nextPendingBlockIndex += 1;
                i += 1;
            } else {
                break;
            }
        }
    }

    function verifyZKProof(
        bytes32 parentBlockHash,
        bytes32 blockHash,
        bytes32 txListHash,
        bytes calldata zkproof
    ) public view {
        // TODO
    }

    function verifyMKProof(bytes32 blockHash, bytes memory mkproof)
        public
        view
        returns (bytes32 storageKey, bytes32 storageValue)
    {}
}
