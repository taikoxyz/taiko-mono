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
import "./LibBlockHeader.sol";
import "./LibZKP.sol";

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
//                  will always be zeros, and this will be checked by zkEVM.
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
    using LibBlockHeader for BlockHeader;
    /**********************
     * Constants   *
     **********************/
    uint256 public constant MAX_ANCHOR_HEIGHT_DIFF = 128;
    uint256 public constant MAX_BLOCK_GASLIMIT = 5000000; // TODO: figure out this value
    uint256 public constant MAX_THROW_AWAY_PARENT_DIFF = 64;
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
    bytes public verificationKey; // TODO

    uint256[45] private __gap;

    /**********************
     * Modifiers          *
     **********************/

    modifier withPendingBlock(uint256 id, BlockContext calldata context) {
        require(id > lastFinalizedId && id < nextPendingId, "invalid id");
        require(
            pendingBlocks[id] == keccak256(abi.encode(context)),
            "context mismatch"
        );
        _;
        _finalizeBlocks();
    }

    /**********************
     * Events             *
     **********************/

    event BlockProposed(uint256 indexed id, BlockContext context);
    event BlockProven(uint256 indexed id, BlockHeader header);
    event BlockInvalidated(uint256 indexed id);
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

        validateContext(context);

        context.timestamp = uint64(block.timestamp);
        context.mixHash = bytes32(block.difficulty);
        context.txListHash = keccak256(txList);

        pendingBlocks[nextPendingId] = keccak256(abi.encode(context));
        emit BlockProposed(nextPendingId, context);

        nextPendingId += 1;
    }

    function proveBlock(
        uint256 id,
        bool anchor,
        BlockHeader calldata header,
        BlockContext calldata context,
        bytes[2] calldata proofs
    ) external withPendingBlock(id, context) {
        _validateHeaderForContext(header, context);
        bytes32 blockHash = header.hashBlockHeader();

        LibZKP.verify(
            verificationKey,
            header.parentHash,
            blockHash,
            context.txListHash,
            proofs[0]
        );

        bytes32 key = keccak256(abi.encodePacked("ANCHOR_KEY", header.height));
        bytes32 value = anchor ? context.anchorHash : bytes32(0);

        LibTrieProof.verify(
            header.stateRoot,
            taikoL2Address,
            key,
            value,
            proofs[1]
        );

        proofRecords[id][header.parentHash] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({
                blockHash: blockHash,
                stateRoot: header.stateRoot
            })
        });

        emit BlockProven(id, header);
    }

    function proveBlockInvalid(
        uint256 id,
        bytes32 throwAwayTxListHash, // hash of a txList that contains a verifyBlockInvalid tx on L2.
        BlockHeader calldata throwAwayHeader,
        BlockContext calldata context,
        bytes[2] calldata proofs
    ) external withPendingBlock(id, context) {
        _validateHeader(throwAwayHeader);

        require(
            lastFinalizedHeight <=
                throwAwayHeader.height + MAX_THROW_AWAY_PARENT_DIFF,
            "parent too old"
        );
        require(
            throwAwayHeader.parentHash ==
                finalizedBlocks[throwAwayHeader.height - 1].blockHash
        );

        LibZKP.verify(
            verificationKey,
            throwAwayHeader.parentHash,
            throwAwayHeader.hashBlockHeader(),
            throwAwayTxListHash,
            proofs[0]
        );

        bytes32 key = keccak256(
            abi.encodePacked("TXLIST_KEY", context.txListHash)
        );

        LibTrieProof.verify(
            throwAwayHeader.stateRoot,
            taikoL2Address,
            key,
            context.txListHash,
            proofs[1]
        );

        _invalidateBlock(id);
    }

    function verifyBlockInvalid(
        uint256 id,
        BlockContext calldata context,
        bytes calldata txList
    ) external withPendingBlock(id, context) {
        require(keccak256(txList) == context.txListHash, "txList mismatch");
        require(!isTxListDecodable(txList));
        _invalidateBlock(id);
    }

    /**********************
     * Public Functions   *
     **********************/

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

    function validateContext(BlockContext memory context) public view {
        require(
            context.txListHash == 0x0 &&
                context.mixHash == 0x0 &&
                context.timestamp == 0,
            "nonzero placeholder fields"
        );

        require(
            block.number <= context.anchorHeight + MAX_ANCHOR_HEIGHT_DIFF &&
                context.anchorHash == blockhash(context.anchorHeight) &&
                context.anchorHash != 0x0
        );

        require(context.beneficiary != address(0), "null beneficiary");
        require(context.gasLimit <= MAX_BLOCK_GASLIMIT, "invalid gasLimit");
        require(context.extraData.length <= 32, "extraData too large");
    }

    /**********************
     * Private Functions  *
     **********************/

    function _invalidateBlock(uint256 id) private {
        proofRecords[id][JUMP_MARKER] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({
                blockHash: JUMP_MARKER,
                stateRoot: JUMP_MARKER
            })
        });
        emit BlockInvalidated(id);
    }

    function _finalizeBlocks() private {
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

    function _validateHeader(BlockHeader calldata header) private pure {
        require(
            header.parentHash != 0x0 &&
                header.gasLimit <= MAX_BLOCK_GASLIMIT &&
                header.extraData.length <= 32 &&
                header.difficulty == 0 &&
                header.nonce == 0,
            "header mismatch"
        );
    }

    function _validateHeaderForContext(
        BlockHeader calldata header,
        BlockContext memory context
    ) private pure {
        require(
            header.beneficiary == context.beneficiary &&
                header.gasLimit == context.gasLimit &&
                header.timestamp == context.timestamp &&
                keccak256(header.extraData) == keccak256(context.extraData) && // TODO: direct compare
                header.mixHash == context.mixHash,
            "header mismatch"
        );
    }
}
