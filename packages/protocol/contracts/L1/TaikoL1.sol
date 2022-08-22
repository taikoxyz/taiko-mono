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
import "../libs/LibZKP.sol";

// import "./broker/IProtoBroker.sol";

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
///                 and `header.gasLimit <= MAX_TAIKO_BLOCK_GAS_LIMIT`
///
/// - Assumption 5: Prover can use its address as public input to generate unique
///                 ZKP that's only valid if he transacts with this address. This is
///                 critical to ensure the ZKP will not be stolen by others
///
/// This contract shall be deployed as the initial implementation of a
/// https://docs.openzeppelin.com/contracts/4.x/api/proxy#UpgradeableBeacon contract,
/// then a https://docs.openzeppelin.com/contracts/4.x/api/proxy#BeaconProxy contract
/// shall be deployed infront of it.
contract TaikoL1 is EssentialContract {
    using SafeCastUpgradeable for uint256;
    using LibBlockHeader for BlockHeader;
    using LibTxListDecoder for bytes;
    using LibTxListValidator for bytes;

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
        bytes32 ancestorAggHash;
        bytes extraData;
    }

    struct ForkChoice {
        bytes32 blockHash;
        uint64 proposedAt;
        uint64 provenAt;
        address[] provers;
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
    bytes32 public constant SKIP_OVER_BLOCK_HASH = bytes32(uint256(1));
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

    event BlockCommitted(
        address indexed sender,
        bytes32 hash,
        uint256 commitTime
    );

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
        bytes32 hash = keccak256(abi.encode(context));
        require(isCommitValid(hash), "L1:invalid commit");
        delete commits[hash];
        _;
        finalizeBlocks();
    }

    modifier whenBlockIsPending(BlockContext calldata context) {
        _checkContextPending(context);
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
        emit BlockCommitted(msg.sender, hash, block.timestamp);
    }

    /// @notice Propose a Taiko L2 block.
    /// @param context The context that the actual L2 block header must satisfy.
    ///        Note the following fields in the provided context object must
    ///        be zeros, and their actual values will be provisioned by Ethereum.
    ///        - txListHash
    ///        - mixHash
    ///        - proposedAt
    /// @param txList A list of transactions in this block, encoded with RLP.
    function proposeBlock(BlockContext memory context, bytes calldata txList)
        external
        payable
        nonReentrant
        whenBlockIsCommitted(context)
    {
        require(
            txList.length > 0 && context.txListHash == txList.hashTxList(),
            "L1:invalid txList"
        );
        require(
            nextPendingId <= lastFinalizedId + MAX_PENDING_BLOCKS,
            "L1:too many pending blocks"
        );

        context.id = nextPendingId;
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

    function proveBlock(
        BlockContext calldata context,
        BlockHeader calldata header,
        bytes32[256] calldata ancestorHashes,
        bytes[2] calldata proofs
    ) external nonReentrant whenBlockIsPending(context) {
        _validateHeaderForContext(header, context);

        bytes32 blockHash = header.hashBlockHeader(ancestorHashes[0]);

        require(
            context.ancestorAggHash ==
                LibStorageProof.aggregateAncestorHashs(ancestorHashes),
            "L1:ancestorAggHash"
        );

        _proveBlock(
            MAX_PROOFS_PER_FORK_CHOICE,
            context,
            ancestorHashes[0],
            blockHash
        );

        (bytes32 proofKey, bytes32 proofVal) = LibStorageProof
            .computeAnchorProofKV(
                header.height,
                context.anchorHeight,
                context.anchorHash,
                context.ancestorAggHash
            );

        LibMerkleProof.verify(
            header.stateRoot,
            resolve("taiko_l2"),
            proofKey,
            proofVal,
            proofs[0]
        );

        LibZKP.verify(
            ConfigManager(resolve("config_manager")).getValue(ZKP_VKEY),
            ancestorHashes,
            blockHash,
            context.txListHash,
            msg.sender,
            proofs[1]
        );
    }

    function proveBlockInvalid(
        BlockContext calldata context,
        BlockHeader calldata throwAwayHeader,
        bytes32[256] calldata ancestorHashes,
        bytes32 throwAwayTxListHash,
        bytes[2] calldata proofs
    ) external nonReentrant whenBlockIsPending(context) {
        require(
            throwAwayHeader.isPartiallyValidForTaiko(),
            "L1:throwAwayHeader invalid"
        );

        require(
            lastFinalizedHeight <=
                throwAwayHeader.height + MAX_THROW_AWAY_PARENT_DIFF,
            "L1:parent too old"
        );
        require(
            ancestorHashes[0] == finalizedBlocks[throwAwayHeader.height - 1],
            "L1:parent mismatch"
        );

        require(
            context.ancestorAggHash ==
                LibStorageProof.aggregateAncestorHashs(ancestorHashes),
            "L1:ancestorAggHash"
        );

        _proveBlock(
            MAX_PROOFS_PER_FORK_CHOICE,
            context,
            SKIP_OVER_BLOCK_HASH,
            SKIP_OVER_BLOCK_HASH
        );

        (bytes32 proofKey, bytes32 proofVal) = LibStorageProof
            .computeInvalidTxListProofKV(
                context.txListHash,
                context.ancestorAggHash
            );

        LibMerkleProof.verify(
            throwAwayHeader.stateRoot,
            resolve("taiko_l2"),
            proofKey,
            proofVal,
            proofs[0]
        );

        LibZKP.verify(
            ConfigManager(resolve("config_manager")).getValue(ZKP_VKEY),
            ancestorHashes,
            throwAwayHeader.hashBlockHeader(ancestorHashes[0]),
            throwAwayTxListHash,
            msg.sender,
            proofs[1]
        );
    }

    /**********************
     * Public Functions   *
     **********************/

    function finalizeBlocks() public {
        uint64 id = lastFinalizedId + 1;
        uint256 processed = 0;

        while (id < nextPendingId && processed <= MAX_FINALIZATION_PER_TX) {
            ForkChoice storage fc = forkChoices[id][
                finalizedBlocks[lastFinalizedHeight]
            ];

            if (fc.blockHash != 0) {
                finalizedBlocks[++lastFinalizedHeight] = fc.blockHash;
                _finalizeBlock(id, fc);
            } else {
                fc = forkChoices[id][SKIP_OVER_BLOCK_HASH];
                if (fc.blockHash != 0) {
                    _finalizeBlock(id, fc);
                } else {
                    break;
                }
            }

            lastFinalizedId += 1;
            id += 1;
            processed += 1;
        }
    }

    function validateContext(BlockContext memory context) public view {
        require(
            context.id == 0 &&
                context.mixHash == 0 &&
                context.proposedAt == 0 &&
                context.ancestorAggHash != 0 &&
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
            context.gasLimit <= LibTxListValidator.MAX_TAIKO_BLOCK_GAS_LIMIT,
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
        uint256 maxNumProofsPerForkChoice,
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
                fc.provers.length < maxNumProofsPerForkChoice,
                "L1:too many proofs"
            );

            // No uncle proof can take more than 1.5x time the first proof did.
            uint256 delay = fc.provenAt - fc.proposedAt;
            uint256 deadline = fc.provenAt + delay / 2;
            require(block.timestamp <= deadline, "L1:too late");

            for (uint256 i = 0; i < fc.provers.length; i++) {
                require(fc.provers[i] != msg.sender, "L1:duplicate prover");
            }
        }

        fc.provers.push(msg.sender);

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
            msg.sender
        );
    }

    function _finalizeBlock(uint64 id, ForkChoice storage fc) private {
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
            header.gasLimit <= LibTxListValidator.MAX_TAIKO_BLOCK_GAS_LIMIT &&
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
