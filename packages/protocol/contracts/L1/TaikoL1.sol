// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../common/EssentialContract.sol";
import "../common/ConfigManager.sol";
import "../libs/LibBlockHeader.sol";
import "../libs/LibConstants.sol";
import "../libs/LibMerkleProof.sol";
import "../libs/LibStorageProof.sol";
import "../libs/LibTxList.sol";
import "../libs/LibZKP.sol";
import "./broker/IProtoBroker.sol";

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

struct PendingBlock {
    bytes32 contextHash;
    uint128 gasPriceAtProposal;
    uint128 gasLimit;
    uint8 everProven;
}

struct Evidence {
    address prover;
    uint64 proposedAt;
    uint64 provenAt;
}

struct ForkChoice {
    bytes32 blockHash;
    Evidence[] evidences;
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
    using LibBlockHeader for BlockHeader;
    using LibTxList for bytes;
    /**********************
     * Constants   *
     **********************/

    uint256 public constant MAX_ANCHOR_HEIGHT_DIFF = 128;
    uint256 public constant MAX_PENDING_BLOCKS = 2048;
    uint256 public constant MAX_THROW_AWAY_PARENT_DIFF = 1024;
    uint256 public constant MAX_FINALIZATION_PER_TX = 5;
    uint256 public constant MAX_PROOFS_PER_BLOCK = 5;
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

    uint64 public genesisHeight;
    uint64 public lastFinalizedHeight;
    uint64 public lastFinalizedId;
    uint64 public nextPendingId;
    uint64 public numUnprovenBlocks;

    uint256[46] private __gap;

    /**********************
     * Events             *
     **********************/

    event BlockProposed(uint256 indexed id, BlockContext context);

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        Evidence evidence
    );

    event BlockFinalized(
        uint256 indexed id,
        uint256 indexed height,
        bytes32 blockHash
    );

    /**********************
     * Modifiers          *
     **********************/

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
        payable
        nonReentrant
    {
        // Try to finalize blocks first to make room
        finalizeBlocks();

        require(txList.length > 0, "empty txList");
        require(
            nextPendingId <= lastFinalizedId + MAX_PENDING_BLOCKS,
            "too many pending blocks"
        );
        validateContext(context);

        context.id = nextPendingId;
        context.proposedAt = uint64(block.timestamp);
        context.txListHash = txList.hashTxList();

        // if multiple L2 blocks included in the same L1 block,
        // their block.mixHash fields for randomness will be the same.
        context.mixHash = bytes32(block.difficulty);

        uint128 gasPrice = IProtoBroker(resolve("proto_broker")).chargeProposer(
            nextPendingId,
            nextPendingId - lastFinalizedId - 1,
            numUnprovenBlocks,
            msg.sender,
            context.gasLimit
        );

        _savePendingBlock(
            nextPendingId,
            PendingBlock({
                contextHash: _hashContext(context),
                gasPriceAtProposal: gasPrice,
                gasLimit: context.gasLimit,
                everProven: 1 // 0 and 1 means not proven ever
            })
        );

        emit BlockProposed(nextPendingId++, context);
    }

    function proveBlock(
        bool anchored,
        BlockHeader calldata header,
        BlockContext calldata context,
        bytes[2] calldata proofs
    ) external nonReentrant whenBlockIsPending(context) {
        _validateHeaderForContext(header, context);
        bytes32 blockHash = header.hashBlockHeader();

        LibZKP.verify(
            ConfigManager(resolve("config_manager")).getValue(ZKP_VKEY),
            header.parentHash,
            blockHash,
            _computePublicInputHash(msg.sender, context.txListHash),
            proofs[0]
        );

        (bytes32 proofKey, bytes32 proofVal) = LibStorageProof
            .computeAnchorProofKV(
                header.height,
                context.anchorHeight,
                context.anchorHash
            );

        if (!anchored) {
            proofVal = 0;
        }

        LibMerkleProof.verify(
            header.stateRoot,
            resolve("taiko_l2"),
            proofKey,
            proofVal,
            proofs[1]
        );

        numUnprovenBlocks += 1;

        _proveBlock(
            MAX_PROOFS_PER_BLOCK,
            context,
            header.parentHash,
            blockHash
        );
    }

    function proveBlockInvalid(
        bytes32 throwAwayTxListHash, // hash of a txList that contains a verifyBlockInvalid tx on L2.
        BlockHeader calldata throwAwayHeader,
        BlockContext calldata context,
        bytes[2] calldata proofs
    ) external nonReentrant whenBlockIsPending(context) {
        require(
            throwAwayHeader.isPartiallyValidForTaiko(),
            "throwAwayHeader invalid"
        );

        require(
            lastFinalizedHeight <=
                throwAwayHeader.height + MAX_THROW_AWAY_PARENT_DIFF,
            "parent too old"
        );
        require(
            throwAwayHeader.parentHash ==
                finalizedBlocks[throwAwayHeader.height - 1],
            "parent mismatch"
        );

        LibZKP.verify(
            ConfigManager(resolve("config_manager")).getValue(ZKP_VKEY),
            throwAwayHeader.parentHash,
            throwAwayHeader.hashBlockHeader(),
            _computePublicInputHash(msg.sender, throwAwayTxListHash),
            proofs[0]
        );

        (bytes32 key, bytes32 value) = LibStorageProof
            .computeInvalidTxListProofKV(context.txListHash);

        LibMerkleProof.verify(
            throwAwayHeader.stateRoot,
            resolve("taiko_l2"),
            key,
            value,
            proofs[1]
        );

        _proveBlock(
            MAX_PROOFS_PER_BLOCK,
            context,
            SKIP_OVER_BLOCK_HASH,
            SKIP_OVER_BLOCK_HASH
        );
    }

    function verifyBlockInvalid(
        BlockContext calldata context,
        bytes calldata txList
    ) external nonReentrant whenBlockIsPending(context) {
        require(txList.hashTxList() == context.txListHash, "txList mismatch");
        require(!LibTxListValidator.isTxListValid(txList), "txList decoded");

        _proveBlock(
            1, // no uncles
            context,
            SKIP_OVER_BLOCK_HASH,
            SKIP_OVER_BLOCK_HASH
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
                context.txListHash == 0 &&
                context.mixHash == 0 &&
                context.proposedAt == 0,
            "nonzero placeholder fields"
        );

        require(
            block.number <= context.anchorHeight + MAX_ANCHOR_HEIGHT_DIFF &&
                context.anchorHash == blockhash(context.anchorHeight) &&
                context.anchorHash != 0,
            "invalid anchor"
        );

        require(context.beneficiary != address(0), "null beneficiary");
        require(
            context.gasLimit <= LibConstants.MAX_TAIKO_BLOCK_GAS_LIMIT,
            "invalid gasLimit"
        );
        require(context.extraData.length <= 32, "extraData too large");
    }

    /**********************
     * Private Functions  *
     **********************/

    function _proveBlock(
        uint256 maxNumProofs,
        BlockContext memory context,
        bytes32 parentHash,
        bytes32 blockHash
    ) private {
        ForkChoice storage fc = forkChoices[context.id][parentHash];

        if (fc.blockHash == 0) {
            fc.blockHash = blockHash;
        } else {
            require(fc.blockHash == blockHash, "conflicting proof");
            require(fc.evidences.length < maxNumProofs, "too many proofs");

            for (uint256 i = 0; i < fc.evidences.length; i++) {
                require(
                    fc.evidences[i].prover != msg.sender,
                    "duplicate proof"
                );
            }
        }

        Evidence memory evidence = Evidence({
            prover: msg.sender,
            proposedAt: context.proposedAt,
            provenAt: uint64(block.timestamp)
        });

        fc.evidences.push(evidence);

        PendingBlock storage blk = _getPendingBlock(context.id);
        if (blk.everProven != 2) {
            // special value 2 means this block is proven at least once.
            blk.everProven = 2;
            numUnprovenBlocks -= 1;
        }

        emit BlockProven(context.id, parentHash, blockHash, evidence);
    }

    function _finalizeBlock(uint64 id, ForkChoice storage fc) private {
        PendingBlock storage blk = _getPendingBlock(id);

        for (uint256 i = 0; i < fc.evidences.length; i++) {
            Evidence memory evidence = fc.evidences[i];

            IProtoBroker(resolve("proto_broker")).payProver(
                id,
                fc.evidences.length,
                evidence.prover,
                blk.gasPriceAtProposal,
                blk.gasLimit,
                evidence.provenAt,
                evidence.proposedAt
            );
        }

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
            "invalid id"
        );
        require(
            _getPendingBlock(context.id).contextHash == _hashContext(context),
            "context mismatch"
        );
    }

    function _validateHeader(BlockHeader calldata header) private pure {
        require(
            header.parentHash != 0 &&
                header.gasLimit <= LibConstants.MAX_TAIKO_BLOCK_GAS_LIMIT &&
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
                header.timestamp == context.proposedAt &&
                header.extraData.length == context.extraData.length &&
                keccak256(header.extraData) == keccak256(context.extraData) &&
                header.mixHash == context.mixHash,
            "header mismatch"
        );
    }

    function _hashContext(BlockContext memory context)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(context));
    }

    // We currently assume the public input has at least
    // two parts: msg.sender, and txListHash.
    // TODO(daniel): figure it out.
    function _computePublicInputHash(address prover, bytes32 txListHash)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(prover, txListHash));
    }
}
