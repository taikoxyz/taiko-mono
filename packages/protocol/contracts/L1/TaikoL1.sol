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
}

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

struct ProofRecord {
    address prover;
    ShortHeader header;
}

contract TaikoL1 {
    /**********************
     * Constants   *
     **********************/
    uint256 public constant MAX_ANCHOR_HEIGHT_DIFF = 128;
    uint256 public constant MAX_BLOCK_GASLIMIT = 5000000; // TODO
    bytes32 public constant JUMP_MARKER = bytes32(uint256(1));

    /**********************
     * State Variables    *
     **********************/

    // Finalized taiko block headers
    mapping(uint256 => ShortHeader) public finalizedBlocks;

    // block id => block context hash
    mapping(uint256 => bytes32) public pendingBlocks;

    mapping(uint256 => mapping(bytes32 => ProofRecord)) public proofRecords;

    address public taikoL2Address;
    uint64 public lastFinalizedBlockHeight;
    uint64 public lastFinalizedBlockId;
    uint64 public nextPendingBlockId;

    // uint256[50] private __gap;

    /**********************
     * Modifiers          *
     **********************/

    modifier mayFinalizeBlocks(uint256 id) {
        require(id > lastFinalizedBlockId && id < nextPendingBlockId);
        _;
        tryToFinalizedMoreBlocks();
    }

    /**********************
     * Events             *
     **********************/

    event BlockProposed(uint256 indexed id, BlockContext context);

    /**********************
     * External Functions *
     **********************/

    /// @dev When a L2 block is proposed, we always implicitly require that the following
    // fields have zero values: difficulty, nonce.
    function proposeBlock(
        bytes calldata txList, // or bytes32 txListHash when using blob
        BlockContext memory context
    ) external {
        require(txList.length > 0, "null tx list");

        require(
            context.txListHash == 0x0 &&
                context.mixHash == 0x0 &&
                context.timestamp == 0,
            "placeholder not zero"
        );

        require(
            context.anchorHeight >= block.number - MAX_ANCHOR_HEIGHT_DIFF &&
                context.anchorHash == blockhash(context.anchorHeight) &&
                context.anchorHash != 0x0
        );

        require(context.beneficiary != address(0), "null beneficiary");
        require(
            context.gasLimit > 0 && context.gasLimit <= MAX_BLOCK_GASLIMIT,
            "gas limit too large"
        );

        require(context.extraData.length <= 32, "extraData too large");

        // WARN: Taiko L2 allows block.timestamp >= parent.timestamp
        context.timestamp = uint64(block.timestamp);

        // See https://blog.ethereum.org/2021/11/29/how-the-merge-impacts-app-layer/
        context.mixHash = bytes32(block.difficulty);

        context.txListHash = keccak256(txList);

        pendingBlocks[nextPendingBlockId] = keccak256(abi.encode(context));
        emit BlockProposed(nextPendingBlockId, context);

        nextPendingBlockId += 1;
    }

    function proveBlock(
        uint256 id,
        BlockContext calldata context,
        BlockHeader calldata header,
        bytes32 anchorHash,
        bytes calldata zkproof,
        bytes calldata mkproof
    ) external mayFinalizeBlocks(id) {
        require(
            pendingBlocks[id] == keccak256(abi.encode(context)),
            "mismatch"
        );
        verifyBlockHeader(header, context);
        bytes32 blockHash = hashBlockHeader(header);

        verifyZKProof(
            header.parentHash,
            blockHash,
            context.txListHash,
            zkproof
        );

        // we need to calculate key based on taikoL2Address,  pendingBlocks[id].anchorHeight
        // but the following calculation is not correct.
        //
        // see TaikoL2.sol `prepareBlock`
        bytes32 expectedKey = keccak256(
            abi.encodePacked("PREPARE BLOCK", header.height)
        );

        // The prepareBlock tx may fail due to out-of-gas, therefore, we have to accept
        // an 0x0 value. In such case, we need to punish the block proposer for the failed
        // prepareBlock tx.
        require(anchorHash == 0x0 || anchorHash == context.anchorHash);

        LibTrieProof.verify(
            header.stateRoot,
            taikoL2Address,
            expectedKey,
            anchorHash,
            mkproof
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
    ) external mayFinalizeBlocks(id) {
        require(
            pendingBlocks[id] == keccak256(abi.encode(context)),
            "mismatch"
        );
        verifyBlockHeader(header, context);
        bytes32 blockHash = hashBlockHeader(header);

        require(
            header.parentHash != 0x0 &&
                header.parentHash ==
                finalizedBlocks[header.height - 1].blockHash
        );

        verifyZKProof(
            header.parentHash,
            blockHash,
            throwAwayTxListHash,
            proofs[0]
        );

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
    ) external mayFinalizeBlocks(id) {
        require(
            pendingBlocks[id] == keccak256(abi.encode(context)),
            "mismatch"
        );
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

    function tryToFinalizedMoreBlocks() internal {
        // ShortHeader memory parent = finalizedBlocks[finalizedBlocks.length - 1];
        // uint256 i = lastFinalizedBlockId + 1;
        // while (i < nextPendingBlockId) {
        //     ShortHeader storage header = proofRecords[i][parent.blockHash]
        //         .header;
        //     if (header.blockHash != 0x0) {
        //         finalizedBlocks[lastFinalizedBlockHeight++] = header;
        //         parent = header;
        //         lastFinalizedBlockId++;
        //         i++;
        //     } else if (
        //         proofRecords[i][JUMP_MARKER].header.blockHash ==
        //         JUMP_MARKER
        //     ) {
        //         lastFinalizedBlockId++;
        //         i++;
        //     } else {
        //         break;
        //     }
        // }
    }
}
