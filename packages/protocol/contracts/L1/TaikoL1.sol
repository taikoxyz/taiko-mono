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
import "../libs/LibTrieProof.sol";

struct ShortHeader {
    bytes32 blockHash;
    bytes32 stateRoot;
    uint256 height;
}

struct BlockHeader {
    bytes32 parentHash;
    bytes32 ommersHash;
    address beneficiary;
    bytes32 stateRoot;
    bytes32 transactionsRoot;
    bytes32 receiptsRoot;
    bytes32[8] logsBloom;
    uint256 difficulty; // must always be 0
    uint128 height;
    uint64 gasLimit;
    uint64 gasUsed;
    uint64 timestamp;
    bytes extraData;
    bytes32 mixHash;
    uint64 nonce; // must always be 0
}

struct PendingBlock {
    uint256 anchorHeight; // known L1 block height
    bytes32 anchorHash; // known L1 block hash
    address beneficiary;
    uint64 gasLimit;
    bytes extraData;
    bytes32 txListHash; // the hash or KGZ commitment of the encoded txList
    bytes32 mixHash;
    uint64 timestamp;
}

struct ProofRecord {
    address prover; // msg.sender of proveBlock tx
    ShortHeader header;
}

contract TaikoL1 {
    uint256 public constant MAX_ANCHOR_HEIGHT_DIFF = 128;
    uint256 public constant MAX_BLOCK_GASLIMIT = 5000000; // TODO
    bytes32 public constant INVALID_BLOCK_MARKER =
        keccak256("INVALID_BLOCK_MARKER");
    // Finalized taiko block headers
    ShortHeader[] public finalizedBlocks;

    // Pending Taiko blocks
    mapping(uint256 => PendingBlock) public pendingBlocks;

    mapping(uint256 => mapping(bytes32 => ProofRecord)) public proofRecords;

    address public taikoL2Address;
    uint64 public lastFinalizedBlockIndex;
    uint64 public nextPendingBlockIndex;

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

    event BlockProposed(uint256 indexed index, PendingBlock blk);

    /// @dev When a L2 block is proposed, we always implicitly require that the following fields
    ///      have zero values: difficulty, nonce.
    function proposeBlock(
        bytes calldata txList, // or bytes32 txListHash when using blob
        PendingBlock memory blk
    ) external {
        require(txList.length > 0, "null tx list");

        require(
            blk.txListHash == 0x0 && blk.mixHash == 0x0 && blk.timestamp == 0,
            "placeholder not zero"
        );

        require(
            blk.anchorHeight >= block.number - MAX_ANCHOR_HEIGHT_DIFF &&
                blk.anchorHash == blockhash(blk.anchorHeight) &&
                blk.anchorHash != 0x0
        );

        require(blk.beneficiary != address(0), "null beneficiary");
        require(
            blk.gasLimit > 0 && blk.gasLimit <= MAX_BLOCK_GASLIMIT,
            "gas limit too large"
        );

        require(blk.extraData.length <= 32, "extraData too large");

        // WARN: Taiko L2 allows block.timestamp >= parent.timestamp
        blk.timestamp = uint64(block.timestamp);

        // See https://blog.ethereum.org/2021/11/29/how-the-merge-impacts-app-layer/
        blk.mixHash = bytes32(block.difficulty);

        blk.txListHash = keccak256(txList);

        pendingBlocks[nextPendingBlockIndex] = blk;
        emit BlockProposed(nextPendingBlockIndex, blk);

        nextPendingBlockIndex += 1;
    }

    //TODO:add MAX_PENDING_SIZE
    function proveBlock(
        uint256 index,
        BlockHeader calldata header,
        bytes32 anchorHash,
        bytes calldata zkproof,
        bytes calldata mkproof
    ) external blockIsPending(index) mayFinalizeBlocks {
        PendingBlock memory blk = pendingBlocks[index];
        verifyBlockHeader(header, blk);
        bytes32 blockHash = hashBlockHeader(header);

        verifyZKProof(header.parentHash, blockHash, blk.txListHash, zkproof);

        // we need to calculate key based on taikoL2Address,  pendingBlocks[index].anchorHeight
        // but the following calculation is not correct.
        //
        // see TaikoL2.sol `prepareBlock`
        bytes32 expectedKey = keccak256(
            abi.encodePacked("PREPARE BLOCK", header.height)
        );

        // The prepareBlock tx may fail due to out-of-gas, therefore, we have to accept
        // an 0x0 value. In such case, we need to punish the block proposer for the failed
        // prepareBlock tx.
        require(
            anchorHash == 0x0 || anchorHash == pendingBlocks[index].anchorHash
        );

        LibTrieProof.verify(
            header.stateRoot,
            taikoL2Address,
            expectedKey,
            anchorHash,
            mkproof
        );

        proofRecords[index][header.parentHash] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({
                blockHash: blockHash,
                stateRoot: header.stateRoot,
                height: header.height
            })
        });
    }

    function proveBlockInvalid(
        uint256 index,
        bytes32 throwAwayTxListHash, // hash of a txList that contains a verifyBlockInvalid tx on L2.
        BlockHeader calldata header,
        bytes[2] calldata proofs
    )
        external
        // bytes calldata zkproof,
        // bytes calldata mkproof
        blockIsPending(index)
        mayFinalizeBlocks
    {
        PendingBlock memory blk = pendingBlocks[index];
        verifyBlockHeader(header, blk);
        bytes32 blockHash = hashBlockHeader(header);

        require(
            header.parentHash == finalizedBlocks[header.height - 1].blockHash
        );

        verifyZKProof(
            header.parentHash,
            blockHash,
            throwAwayTxListHash,
            proofs[0]
        );

        // we need to calculate key based on taikoL2Address and pendingBlocks[index].txListHash
        // but the following calculation is not correct.
        bytes32 expectedKey; // = keccak256(taikoL2Address, pendingBlocks[index].txListHash);

        LibTrieProof.verify(
            header.stateRoot,
            taikoL2Address,
            expectedKey,
            pendingBlocks[index].txListHash,
            proofs[1]
        );

        proofRecords[index][INVALID_BLOCK_MARKER] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({
                blockHash: INVALID_BLOCK_MARKER,
                stateRoot: 0x0,
                height: 0
            })
        });
    }

    function verifyBlockInvalid(uint256 index, bytes calldata txList)
        external
        blockIsPending(index)
        mayFinalizeBlocks
    {
        require(!isTxListDecodable(txList));
        require(keccak256(txList) == pendingBlocks[index].txListHash);

        proofRecords[index][INVALID_BLOCK_MARKER] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({
                blockHash: INVALID_BLOCK_MARKER,
                stateRoot: 0x0,
                height: 0
            })
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

    function verifyZKProof(
        bytes32 parentBlockHash,
        bytes32 blockHash,
        bytes32 txListHash,
        bytes calldata zkproof
    ) public view {
        // TODO
    }

    function verifyBlockHeader(
        BlockHeader calldata header,
        PendingBlock memory blk
    ) public pure {
        require(
            header.beneficiary == blk.beneficiary &&
                header.difficulty == 0 &&
                header.gasLimit == blk.gasLimit &&
                header.timestamp == blk.timestamp &&
                keccak256(header.extraData) == keccak256(blk.extraData) && // TODO: direct compare
                header.mixHash == blk.mixHash &&
                header.nonce == 0,
            "header mismatch"
        );
    }

    function hashBlockHeader(BlockHeader calldata header)
        public
        pure
        returns (bytes32)
    {
        // TODO
    }

    function tryToFinalizedMoreBlocks() internal {
        ShortHeader memory parent = finalizedBlocks[finalizedBlocks.length - 1];

        uint256 i = lastFinalizedBlockIndex + 1;

        while (i < nextPendingBlockIndex) {
            ShortHeader storage header = proofRecords[i][parent.blockHash]
                .header;

            if (header.blockHash != 0x0) {
                finalizedBlocks.push(header);
                parent = header;
                lastFinalizedBlockIndex += 1;
                i += 1;
            } else if (
                proofRecords[i][INVALID_BLOCK_MARKER].header.blockHash ==
                INVALID_BLOCK_MARKER
            ) {
                lastFinalizedBlockIndex += 1;
                i += 1;
            } else {
                break;
            }
        }
    }
}
