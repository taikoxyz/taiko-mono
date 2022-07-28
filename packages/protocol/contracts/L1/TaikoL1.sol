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

struct BlockConstraints {
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
    bytes32 public constant INVALID_BLOCK_MARKER = bytes32(uint256(1));

    // Finalized taiko block headers
    ShortHeader[] public finalizedBlocks;

    // Pending Taiko blocks
    mapping(uint256 => bytes32) public pendingBlocks;

    mapping(uint256 => mapping(bytes32 => ProofRecord)) public proofRecords;

    address public taikoL2Address;
    uint64 public lastFinalizedBlockId;
    uint64 public nextPendingBlockId;

    modifier mayFinalizeBlocks() {
        _;
        tryToFinalizedMoreBlocks();
    }

    modifier blockIsPending(uint256 id) {
        require(id > lastFinalizedBlockId && id < nextPendingBlockId);
        _;
    }

    event BlockProposed(uint256 indexed id, BlockConstraints constraints);

    /// @dev When a L2 block is proposed, we always implicitly require that the following
    // fields have zero values: difficulty, nonce.
    function proposeBlock(
        bytes calldata txList, // or bytes32 txListHash when using blob
        BlockConstraints memory constraints
    ) external {
        require(txList.length > 0, "null tx list");

        require(
            constraints.txListHash == 0x0 &&
                constraints.mixHash == 0x0 &&
                constraints.timestamp == 0,
            "placeholder not zero"
        );

        require(
            constraints.anchorHeight >= block.number - MAX_ANCHOR_HEIGHT_DIFF &&
                constraints.anchorHash == blockhash(constraints.anchorHeight) &&
                constraints.anchorHash != 0x0
        );

        require(constraints.beneficiary != address(0), "null beneficiary");
        require(
            constraints.gasLimit > 0 &&
                constraints.gasLimit <= MAX_BLOCK_GASLIMIT,
            "gas limit too large"
        );

        require(constraints.extraData.length <= 32, "extraData too large");

        // WARN: Taiko L2 allows block.timestamp >= parent.timestamp
        constraints.timestamp = uint64(block.timestamp);

        // See https://blog.ethereum.org/2021/11/29/how-the-merge-impacts-app-layer/
        constraints.mixHash = bytes32(block.difficulty);

        constraints.txListHash = keccak256(txList);

        pendingBlocks[nextPendingBlockId] = keccak256(abi.encode(constraints));
        emit BlockProposed(nextPendingBlockId, constraints);

        nextPendingBlockId += 1;
    }

    function proveBlock(
        uint256 id,
        BlockConstraints calldata constraints,
        BlockHeader calldata header,
        bytes32 anchorHash,
        bytes calldata zkproof,
        bytes calldata mkproof
    ) external blockIsPending(id) mayFinalizeBlocks {
        require(
            pendingBlocks[id] == keccak256(abi.encode(constraints)),
            "mismatch"
        );
        verifyBlockHeader(header, constraints);
        bytes32 blockHash = hashBlockHeader(header);

        verifyZKProof(
            header.parentHash,
            blockHash,
            constraints.txListHash,
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
        require(anchorHash == 0x0 || anchorHash == constraints.anchorHash);

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
                stateRoot: header.stateRoot,
                height: header.height
            })
        });
    }

    function proveBlockInvalid(
        uint256 id,
        bytes32 throwAwayTxListHash, // hash of a txList that contains a verifyBlockInvalid tx on L2.
        BlockConstraints calldata constraints,
        BlockHeader calldata header,
        bytes[2] calldata proofs
    ) external blockIsPending(id) mayFinalizeBlocks {
        require(
            pendingBlocks[id] == keccak256(abi.encode(constraints)),
            "mismatch"
        );
        verifyBlockHeader(header, constraints);
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

        // we need to calculate key based on taikoL2Address and pendingBlocks[id].txListHash
        // but the following calculation is not correct.
        bytes32 expectedKey; // = keccak256(taikoL2Address, pendingBlocks[id].txListHash);

        LibTrieProof.verify(
            header.stateRoot,
            taikoL2Address,
            expectedKey,
            constraints.txListHash,
            proofs[1]
        );

        proofRecords[id][INVALID_BLOCK_MARKER] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({
                blockHash: INVALID_BLOCK_MARKER,
                stateRoot: 0x0,
                height: 0
            })
        });
    }

    function verifyBlockInvalid(
        uint256 id,
        BlockConstraints calldata constraints,
        bytes calldata txList
    ) external blockIsPending(id) mayFinalizeBlocks {
        require(
            pendingBlocks[id] == keccak256(abi.encode(constraints)),
            "mismatch"
        );
        require(!isTxListDecodable(txList));
        require(keccak256(txList) == constraints.txListHash);

        proofRecords[id][INVALID_BLOCK_MARKER] = ProofRecord({
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
        BlockConstraints memory constraints
    ) public pure {
        require(
            header.beneficiary == constraints.beneficiary &&
                header.difficulty == 0 &&
                header.gasLimit == constraints.gasLimit &&
                header.timestamp == constraints.timestamp &&
                keccak256(header.extraData) ==
                keccak256(constraints.extraData) && // TODO: direct compare
                header.mixHash == constraints.mixHash &&
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

        uint256 i = lastFinalizedBlockId + 1;

        while (i < nextPendingBlockId) {
            ShortHeader storage header = proofRecords[i][parent.blockHash]
                .header;

            if (header.blockHash != 0x0) {
                finalizedBlocks.push(header);
                parent = header;
                lastFinalizedBlockId += 1;
                i += 1;
            } else if (
                proofRecords[i][INVALID_BLOCK_MARKER].header.blockHash ==
                INVALID_BLOCK_MARKER
            ) {
                lastFinalizedBlockId += 1;
                i += 1;
            } else {
                break;
            }
        }
    }
}
