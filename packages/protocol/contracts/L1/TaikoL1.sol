// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../common/EssentialContract.sol";
import "../common/ConfigManager.sol";
import "../libs/LibBlockHeader.sol";
import "../libs/LibMerkleProof.sol";
import "../libs/LibStorageProof.sol";
import "../libs/LibTaikoConstants.sol";
import "../libs/LibTxListDecoder.sol";
import "../libs/LibZKP.sol";

// import "./broker/IProtoBroker.sol";

/// @dev We have quit a few ZKP design assumptions. These assumptions are documentd in
///      https://github.com/taikochain/taiko-mono/packages/protocol/DESIGN.md
///
/// This contract shall be deployed as the initial implementation of a
/// https://docs.openzeppelin.com/contracts/4.x/api/proxy#UpgradeableBeacon contract,
/// then a https://docs.openzeppelin.com/contracts/4.x/api/proxy#BeaconProxy contract
/// shall be deployed infront of it.
contract TaikoL1 is EssentialContract {
    using SafeCastUpgradeable for uint256;
    using LibBlockHeader for BlockHeader;
    using LibTxListDecoder for bytes;

    /**********************
     * Structs            *
     **********************/
    enum EverProven {
        _NO, //=0
        NO, //=1
        YES //=2
    }

    struct PendingBlock {
        bytes32 contextHash;
        uint128 proposerFee;
        uint8 everProven;
    }

    struct BlockContext {
        uint256 id;
        uint256 anchorHeight;
        bytes32 anchorHash;
        address beneficiary;
        uint64 gasLimit;
        uint64 proposedAt;
        bytes32 txListHash;
        bytes32 mixHash;
        bytes extraData;
    }

    struct ForkChoice {
        bytes32 blockHash;
        uint64 proposedAt;
        uint64 provenAt;
        address[] provers;
    }

    struct Evidence {
        BlockContext context;
        BlockHeader header;
        address prover;
        bytes32 parentHash;
        bytes[2] proofs;
    }

    /**********************
     * Constants          *
     **********************/

    uint256 public constant MAX_ANCHOR_HEIGHT_DIFF = 128;
    uint256 public constant MAX_PENDING_BLOCKS = 2048;
    uint256 public constant MAX_THROW_AWAY_PARENT_DIFF = 1024;
    uint256 public constant MAX_FINALIZATION_PER_TX = 5;
    uint256 public constant PROPOSING_DELAY_MIN = 1 minutes;
    uint256 public constant PROPOSING_DELAY_MAX = 30 minutes;
    uint256 public constant MAX_PROOFS_PER_FORK_CHOICE = 5;
    bytes32 public constant INVALID_BLOCK_DEADEND_HASH = bytes32(uint256(1));
    string public constant ZKP_VKEY = "TAIKO_ZKP_VKEY";

    /**********************
     * State Variables    *
     **********************/

    // block id => block hash
    mapping(uint256 => bytes32) public finalizedBlocks;

    // block id => PendingBlock
    mapping(uint256 => PendingBlock) public pendingBlocks;

    // block id => parent hash => fork choice
    mapping(uint256 => mapping(bytes32 => ForkChoice)) public forkChoices;

    mapping(bytes32 => uint256) public commits;

    uint64 public genesisHeight;
    uint64 public lastFinalizedHeight;
    uint64 public lastFinalizedId;
    uint64 public nextPendingId;
    uint64 public numUnprovenBlocks;

    uint256[44] private __gap;

    /**********************
     * Events             *
     **********************/

    event BlockCommitted(bytes32 hash, uint256 expireAt);

    event BlockProposed(uint256 indexed id, BlockContext context);

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        uint64 proposedAt,
        uint64 provenAt,
        address prover
    );

    event BlockFinalized(
        uint256 indexed id,
        uint256 indexed height,
        bytes32 blockHash
    );

    /**********************
     * Modifiers          *
     **********************/

    modifier whenBlockIsCommitted(BlockContext memory context) {
        validateContext(context);

        bytes32 hash = keccak256(
            abi.encodePacked(context.beneficiary, context.txListHash)
        );
        require(isCommitValid(hash), "L1:invalid commit");
        delete commits[hash];
        _;
        finalizeBlocks();
    }

    /**********************
     * External Functions *
     **********************/

    function init(address _addressManager, bytes32 _genesisBlockHash)
        external
        initializer
    {
        EssentialContract._init(_addressManager);

        finalizedBlocks[0] = _genesisBlockHash;
        nextPendingId = 1;
        genesisHeight = uint64(block.number);

        emit BlockFinalized(0, 0, _genesisBlockHash);
    }

    function commitBlock(bytes32 hash) external {
        require(hash != 0, "L1:zero hash");

        require(
            commits[hash] == 0 ||
                block.timestamp > commits[hash] + PROPOSING_DELAY_MAX,
            "L1:already committed"
        );
        commits[hash] = block.timestamp;
        emit BlockCommitted(hash, block.timestamp + PROPOSING_DELAY_MAX);
    }

    /// @notice Propose a Taiko L2 block.
    /// @param context The context that the actual L2 block header must satisfy.
    ///        Note the following fields in the provided context object must
    ///        be zeros, and their actual values will be provisioned by Ethereum.
    ///        - id
    ///        - mixHash
    ///        - proposedAt
    ///        - anchorHeight
    ///        - anchorHash
    /// @param txList A list of transactions in this block, encoded with RLP.
    function proposeBlock(BlockContext memory context, bytes calldata txList)
        external
        payable
        nonReentrant
        whenBlockIsCommitted(context)
    {
        require(
            txList.length > 0 &&
                txList.length <=
                LibTaikoConstants.TAIKO_BLOCK_MAX_TXLIST_BYTES &&
                context.txListHash == txList.hashTxList(),
            "L1:invalid txList"
        );
        require(
            nextPendingId <= lastFinalizedId + MAX_PENDING_BLOCKS,
            "L1:too many pending blocks"
        );

        context.id = nextPendingId;
        context.anchorHeight = block.number - 1;
        context.anchorHash = blockhash(block.number - 1);
        context.proposedAt = uint64(block.timestamp);

        // if multiple L2 blocks included in the same L1 block,
        // their block.mixHash fields for randomness will be the same.
        context.mixHash = bytes32(block.difficulty);

        uint256 proposerFee = 0;
        // IProtoBroker(resolve("proto_broker"))
        //     .chargeProposer(
        //         nextPendingId,
        //         msg.sender,
        //         context.gasLimit,
        //         numUnprovenBlocks
        //     );

        _savePendingBlock(
            nextPendingId,
            PendingBlock({
                contextHash: _hashContext(context),
                proposerFee: proposerFee.toUint128(),
                everProven: uint8(EverProven.NO)
            })
        );

        numUnprovenBlocks += 1;

        emit BlockProposed(nextPendingId++, context);
    }

    function proveBlock(Evidence calldata evidence) external nonReentrant {
        _proveBlock(evidence, evidence.context, 0);

        (bytes32 proofKey, bytes32 proofVal) = LibStorageProof
            .computeAnchorProofKV(
                evidence.header.height,
                evidence.parentHash,
                evidence.context.anchorHeight,
                evidence.context.anchorHash
            );

        LibMerkleProof.verifyStorage(
            evidence.header.stateRoot,
            resolve("taiko_l2"),
            proofKey,
            proofVal,
            evidence.proofs[1]
        );

        finalizeBlocks();
    }

    function proveBlockInvalid(
        Evidence calldata evidence,
        BlockContext calldata target
    ) external nonReentrant {
        _proveBlock(evidence, target, INVALID_BLOCK_DEADEND_HASH);

        (bytes32 proofKey, bytes32 proofVal) = LibStorageProof
            .computeInvalidBlockProofKV(
                evidence.header.height,
                evidence.parentHash,
                target.txListHash
            );

        LibMerkleProof.verifyStorage(
            evidence.header.stateRoot,
            resolve("taiko_l2"),
            proofKey,
            proofVal,
            evidence.proofs[1]
        );

        finalizeBlocks();
    }

    /**********************
     * Public Functions   *
     **********************/

    function finalizeBlocks() public {
        uint64 id = lastFinalizedId + 1;
        uint256 processed = 0;

        while (id < nextPendingId && processed <= MAX_FINALIZATION_PER_TX) {
            bytes32 lastFinalizedHash = finalizedBlocks[lastFinalizedHeight];
            ForkChoice storage fc = forkChoices[id][lastFinalizedHash];

            if (fc.blockHash == INVALID_BLOCK_DEADEND_HASH) {
                _finalizeBlock(id, fc);
            } else if (fc.blockHash != 0) {
                finalizedBlocks[++lastFinalizedHeight] = fc.blockHash;
                _finalizeBlock(id, fc);
            } else {
                break;
            }

            lastFinalizedId += 1;
            id += 1;
            processed += 1;
        }
    }

    function validateContext(BlockContext memory context) public view {
        require(
            context.id == 0 &&
                context.anchorHeight == 0 &&
                context.anchorHash == 0 &&
                context.mixHash == 0 &&
                context.proposedAt == 0 &&
                context.beneficiary != address(0) &&
                context.txListHash != 0,
            "L1:nonzero placeholder fields"
        );

        require(
            block.number <= context.anchorHeight + MAX_ANCHOR_HEIGHT_DIFF &&
                context.anchorHash == blockhash(context.anchorHeight) &&
                context.anchorHash != 0,
            "L1:invalid anchor"
        );

        require(
            context.gasLimit <= LibTaikoConstants.TAIKO_BLOCK_MAX_GAS_LIMIT,
            "L1:invalid gasLimit"
        );
        require(context.extraData.length <= 32, "L1:extraData too large");
    }

    function isCommitValid(bytes32 hash) public view returns (bool) {
        return
            hash != 0 &&
            commits[hash] != 0 &&
            block.timestamp >= commits[hash] + PROPOSING_DELAY_MIN &&
            block.timestamp <= commits[hash] + PROPOSING_DELAY_MAX;
    }

    /**********************
     * Private Functions  *
     **********************/

    function _proveBlock(
        Evidence calldata evidence,
        BlockContext calldata target,
        bytes32 blockHashOverride
    ) private {
        require(evidence.context.id == target.id, "L1:not same height");
        require(evidence.prover != address(0), "L1:invalid prover");

        _checkContextPending(target);
        _validateHeaderForContext(evidence.header, evidence.context);

        bytes32 blockHash = evidence.header.hashBlockHeader(
            evidence.parentHash
        );

        LibZKP.verify(
            ConfigManager(resolve("config_manager")).getValue(ZKP_VKEY),
            evidence.proofs[0],
            blockHash,
            evidence.prover,
            evidence.context.txListHash
        );

        _markBlockProven(
            evidence.prover,
            evidence.context,
            evidence.parentHash,
            blockHashOverride == 0 ? blockHash : blockHashOverride
        );
    }

    function _markBlockProven(
        address prover,
        BlockContext memory context,
        bytes32 parentHash,
        bytes32 blockHash
    ) private {
        ForkChoice storage fc = forkChoices[context.id][parentHash];

        if (fc.blockHash == 0) {
            fc.blockHash = blockHash;
            fc.proposedAt = context.proposedAt;
            fc.provenAt = uint64(block.timestamp);
        } else {
            require(
                fc.blockHash == blockHash &&
                    fc.proposedAt == context.proposedAt,
                "L1:conflicting proof"
            );
            require(
                fc.provers.length < MAX_PROOFS_PER_FORK_CHOICE,
                "L1:too many proofs"
            );

            // No uncle proof can take more than 1.5x time the first proof did.
            uint256 delay = fc.provenAt - fc.proposedAt;
            uint256 deadline = fc.provenAt + delay / 2;
            require(block.timestamp <= deadline, "L1:too late");

            for (uint256 i = 0; i < fc.provers.length; i++) {
                require(fc.provers[i] != prover, "L1:duplicate prover");
            }
        }

        fc.provers.push(prover);

        PendingBlock storage blk = _getPendingBlock(context.id);
        if (blk.everProven != uint8(EverProven.YES)) {
            blk.everProven = uint8(EverProven.YES);
            numUnprovenBlocks -= 1;
        }

        emit BlockProven(
            context.id,
            parentHash,
            blockHash,
            fc.proposedAt,
            fc.provenAt,
            prover
        );
    }

    function _finalizeBlock(
        uint64 id,
        ForkChoice storage /*fc*/
    ) private {
        // IProtoBroker(resolve("proto_broker")).payProvers(
        //     id,
        //     fc.provenAt,
        //     fc.proposedAt,
        //     _getPendingBlock(id).proposerFee,
        //     fc.provers
        // );

        emit BlockFinalized(
            id,
            lastFinalizedHeight,
            finalizedBlocks[lastFinalizedHeight]
        );
    }

    function _savePendingBlock(uint256 id, PendingBlock memory blk) private {
        pendingBlocks[id % MAX_PENDING_BLOCKS] = blk;
    }

    function _getPendingBlock(uint256 id)
        private
        view
        returns (PendingBlock storage)
    {
        return pendingBlocks[id % MAX_PENDING_BLOCKS];
    }

    function _checkContextPending(BlockContext calldata context) private view {
        require(
            context.id > lastFinalizedId && context.id < nextPendingId,
            "L1:invalid id"
        );
        require(
            _getPendingBlock(context.id).contextHash == _hashContext(context),
            "L1:context mismatch"
        );
    }

    function _validateHeader(BlockHeader calldata header) private pure {
        require(
            header.gasLimit <= LibTaikoConstants.TAIKO_BLOCK_MAX_GAS_LIMIT &&
                header.extraData.length <= 32 &&
                header.difficulty == 0 &&
                header.nonce == 0,
            "L1:header mismatch"
        );
    }

    function _validateHeaderForContext(
        BlockHeader calldata header,
        BlockContext memory context
    ) private pure {
        require(
            header.beneficiary == context.beneficiary &&
                header.gasLimit == context.gasLimit &&
                header.timestamp == context.proposedAt &&
                header.extraData.length == context.extraData.length &&
                keccak256(header.extraData) == keccak256(context.extraData) &&
                header.mixHash == context.mixHash,
            "L1:header mismatch"
        );
    }

    function _hashContext(BlockContext memory context)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(context));
    }
}
