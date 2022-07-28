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

struct BlockHeader {
    bytes32 parentHash;
    bytes32 ommersHash;
    address beneficiary;
    bytes32 stateRoot;
    bytes32 transactionsRoot;
    bytes32 receiptsRoot;
    bytes32[8] logsBloom;
    uint256 difficulty;
    uint128 height;
    uint64 gasLimit;
    uint64 gasUsed;
    uint64 timestamp;
    bytes extraData;
    bytes32 mixHash;
    uint64 nonce;
}

struct BlockContext {
    uint256 anchorHeight;
    bytes32 anchorHash;
    address beneficiary;
    uint64 gasLimit;
    bytes extraData;
    bytes32 txListHash;
    bytes32 mixHash;
    uint64 timestamp;
}

struct ShortHeader {
    bytes32 blockHash;
    bytes32 stateRoot;
}

struct ProofRecord {
    address prover;
    ShortHeader header;
}

/// @dev We have the following design assumptions:
/// - Assumption 1: the `difficulty` and `nonce` fields in Taiko block header
//                  will always be zeros.
///
/// - Assumption 2: Taiko L2 allows block.timestamp >= parent.timestamp.
///
/// - Assumption 3: mixHash will be used by Taiko L2 for randomness, see:
///                 https://blog.ethereum.org/2021/11/29/how-the-merge-impacts-app-layer
///
/// - Assumption 4: Taiko zkEVM will check `sum(tx_i.gasLimit) <= header.gasLimit`
///                 and `header.gasLimit <= MAX_BLOCK_GASLIMIT`
///
contract TaikoL1 {
    /**********************
     * Constants   *
     **********************/
    uint256 public constant MAX_ANCHOR_HEIGHT_DIFF = 128;
    uint256 public constant MAX_BLOCK_GASLIMIT = 5000000; // TODO: figure out this value
    bytes32 private constant JUMP_MARKER = bytes32(uint256(1));

    /**********************
     * State Variables    *
     **********************/

    // Finalized taiko block headers
    mapping(uint256 => ShortHeader) public finalizedBlocks;

    // block id => block context hash
    mapping(uint256 => bytes32) public pendingBlocks;

    mapping(uint256 => mapping(bytes32 => ProofRecord)) public proofRecords;

    address public taikoL2Address;
    uint64 public lastFinalizedHeight;
    uint64 public lastFinalizedId;
    uint64 public nextPendingId;

    uint256[45] private __gap;

    /**********************
     * Modifiers          *
     **********************/

    modifier mayFinalizeBlocks(uint256 id, BlockContext calldata context) {
        require(id > lastFinalizedId && id < nextPendingId, "invalid id");
        require(
            pendingBlocks[id] == keccak256(abi.encode(context)),
            "context mismatch"
        );
        _;
        tryFinalizingBlocks();
    }

    /**********************
     * Events             *
     **********************/

    event BlockProposed(uint256 indexed id, BlockContext context);
    event BlockFinalized(uint256 indexed id, BlockHeader header);

    /**********************
     * External Functions *
     **********************/

    /// @notice Propose a Taiko L2 block.
    /// @param context The context that the actual L2 block header must satisfy.
    ///        Note the following fields in the provided context object must
    ///        be zeros, and their actual values will be provisioned by Ethereum.
    ///        - txListHash
    ///        - mixHash
    ///        - timestamp
    /// @param txList A list of transactions in this block, encoded with RLP.
    ///
    function proposeBlock(BlockContext memory context, bytes calldata txList)
        external
    {
        require(txList.length > 0, "empty txList");

        require(
            context.txListHash == 0x0 &&
                context.mixHash == 0x0 &&
                context.timestamp == 0,
            "nonzero placeholder fields"
        );

        require(
            context.anchorHeight >= block.number - MAX_ANCHOR_HEIGHT_DIFF &&
                context.anchorHash == blockhash(context.anchorHeight) &&
                context.anchorHash != 0x0
        );

        require(context.beneficiary != address(0), "null beneficiary");
        require(context.gasLimit <= MAX_BLOCK_GASLIMIT, "invalid gasLimit");
        require(context.extraData.length <= 32, "extraData too large");

        context.timestamp = uint64(block.timestamp);
        context.mixHash = bytes32(block.difficulty);
        context.txListHash = keccak256(txList);

        pendingBlocks[nextPendingId] = keccak256(abi.encode(context));
        emit BlockProposed(nextPendingId, context);

        nextPendingId += 1;
    }

    function proveBlock(
        uint256 id,
        bool anchoring,
        BlockContext calldata context,
        BlockHeader calldata header,
        bytes[2] calldata proofs
    ) external mayFinalizeBlocks(id, context) {
        verifyBlockHeader(header, context);
        bytes32 blockHash = hashBlockHeader(header);

        verifyZKP(header.parentHash, blockHash, context.txListHash, proofs[0]);

        // we need to calculate key based on taikoL2Address,  pendingBlocks[id].anchorHeight
        // but the following calculation is not correct.
        //
        // see TaikoL2.sol `prepareBlock`
        bytes32 expectedKey = keccak256(
            abi.encodePacked("PREPARE BLOCK", header.height)
        );
        bytes32 expectedValue = anchoring ? context.anchorHash : bytes32(0);

        LibTrieProof.verify(
            header.stateRoot,
            taikoL2Address,
            expectedKey,
            expectedValue,
            proofs[1]
        );

        proofRecords[id][header.parentHash] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({
                blockHash: blockHash,
                stateRoot: header.stateRoot
            })
        });
    }

    function proveBlockInvalid(
        uint256 id,
        bytes32 throwAwayTxListHash, // hash of a txList that contains a verifyBlockInvalid tx on L2.
        BlockContext calldata context,
        BlockHeader calldata header,
        bytes[2] calldata proofs
    ) external mayFinalizeBlocks(id, context) {
        verifyBlockHeader(header, context);
        bytes32 blockHash = hashBlockHeader(header);

        require(
            header.parentHash != 0x0 &&
                header.parentHash ==
                finalizedBlocks[header.height - 1].blockHash
        );

        verifyZKP(header.parentHash, blockHash, throwAwayTxListHash, proofs[0]);

        // we need to calculate key based on taikoL2Address and pendingBlocks[id].txListHash
        // but the following calculation is not correct.
        bytes32 expectedKey; // = keccak256(taikoL2Address, pendingBlocks[id].txListHash);

        LibTrieProof.verify(
            header.stateRoot,
            taikoL2Address,
            expectedKey,
            context.txListHash,
            proofs[1]
        );

        proofRecords[id][JUMP_MARKER] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({blockHash: JUMP_MARKER, stateRoot: 0x0})
        });
    }

    function verifyBlockInvalid(
        uint256 id,
        BlockContext calldata context,
        bytes calldata txList
    ) external mayFinalizeBlocks(id, context) {
        require(!isTxListDecodable(txList));
        require(keccak256(txList) == context.txListHash);

        proofRecords[id][JUMP_MARKER] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({blockHash: JUMP_MARKER, stateRoot: 0x0})
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

    function verifyZKP(
        bytes32 parentBlockHash,
        bytes32 blockHash,
        bytes32 txListHash,
        bytes calldata zkproof
    ) public view {
        // TODO
    }

    function verifyBlockHeader(
        BlockHeader calldata header,
        BlockContext memory context
    ) public pure {
        require(
            header.beneficiary == context.beneficiary &&
                header.difficulty == 0 &&
                header.gasLimit == context.gasLimit &&
                header.timestamp == context.timestamp &&
                keccak256(header.extraData) == keccak256(context.extraData) && // TODO: direct compare
                header.mixHash == context.mixHash &&
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

    function tryFinalizingBlocks() internal {
        // ShortHeader memory parent = finalizedBlocks[finalizedBlocks.length - 1];
        // uint256 i = lastFinalizedId + 1;
        // while (i < nextPendingId) {
        //     ShortHeader storage header = proofs[i][parent.blockHash]
        //         .header;
        //     if (header.blockHash != 0x0) {
        //         finalizedBlocks[lastFinalizedHeight++] = header;
        //         parent = header;
        //         lastFinalizedId++;
        //         i++;
        //     } else if (
        //         proofs[i][JUMP_MARKER].header.blockHash ==
        //         JUMP_MARKER
        //     ) {
        //         lastFinalizedId++;
        //         i++;
        //     } else {
        //         break;
        //     }
        // }
    }
}
