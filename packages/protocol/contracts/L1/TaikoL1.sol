// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../libs/LibStorageProof.sol";
import "../libs/LibMerkleProof.sol";
import "../libs/LibTxList.sol";
import "../libs/LibConstants.sol";
import "./LibBlockHeader.sol";
import "./LibZKP.sol";
import "./KeyManager.sol";

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
    uint256 proverFee;
}

struct Snippet {
    bytes32 blockHash;
    bytes32 stateRoot;
}

struct Evidence {
    address prover;
    uint256 proverFee;
    uint64 proposedAt;
    uint64 provenAt;
    Snippet snippet;
}

struct Stats {
    uint64 avgPendingSize; // scaled by STAT_SCALE
    uint64 avgProvingDelay; // scaled by STAT_SCALE
    uint64 avgFinalizationDelay; // scaled by STAT_SCALE
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
/// This contract shall be deployed as the initial implementation of a
/// https://docs.openzeppelin.com/contracts/4.x/api/proxy#UpgradeableBeacon contract,
/// then a https://docs.openzeppelin.com/contracts/4.x/api/proxy#BeaconProxy contract
/// shall be deployed infront of it.
contract TaikoL1 is ReentrancyGuardUpgradeable {
    using SafeCastUpgradeable for uint256;
    using LibBlockHeader for BlockHeader;
    using LibTxList for bytes;
    /**********************
     * Constants   *
     **********************/
    uint256 public constant MAX_ANCHOR_HEIGHT_DIFF = 128;
    uint256 public constant MAX_PENDING_BLOCKS = 1024;
    uint256 public constant MAX_THROW_AWAY_PARENT_DIFF = 1024;
    uint256 public constant MAX_FINALIZATION_WRITES_PER_TX = 5;
    uint256 public constant MAX_FINALIZATION_READS_PER_TX = 50;
    string public constant ZKP_VKEY = "TAIKO_ZKP_VKEY";

    bytes32 private constant JUMP_MARKER = bytes32(uint256(1));
    uint256 private constant STAT_AVERAGING_FACTOR = 2048;
    uint64 private constant STAT_SCALE = 1000000;

    /**********************
     * State Variables    *
     **********************/

    // Finalized taiko block headers
    mapping(uint256 => Snippet) public finalizedBlocks;

    // block id => block context hash
    mapping(uint256 => bytes32) public pendingBlocks;

    mapping(uint256 => mapping(bytes32 => Evidence)) public evidences;

    address public keyManagerAddress;
    address public taikoL2Address;
    address public daoAddress;

    uint64 public genesisHeight;
    uint64 public lastFinalizedHeight;
    uint64 public lastFinalizedId;
    uint64 public nextPendingId;

    uint256 public proverBaseFee;
    uint256 public proverGasPrice; // TODO: auto-adjustable

    Stats private _stats; // 1 slot

    uint256[40] private __gap;

    /**********************
     * Events             *
     **********************/

    event BlockProposed(uint256 indexed id, BlockContext context);
    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        Evidence evidence
    );
    event BlockProvenInvalid(uint256 indexed id);
    event BlockFinalized(
        uint256 indexed id,
        uint256 indexed height,
        Evidence evidence
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

    function init(
        Snippet calldata genesis,
        address _keyManagerAddress,
        address _taikoL2Address,
        address _daoAddress,
        uint256 _proverBaseFee,
        uint256 _proverGasPrice
    ) external initializer {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        require(
            !AddressUpgradeable.isContract(_keyManagerAddress),
            "invalid keyManager"
        );
        require(_taikoL2Address != address(0), "invalid keyManager");

        proverBaseFee = _proverBaseFee;
        proverGasPrice = _proverGasPrice;

        finalizedBlocks[0] = genesis;
        nextPendingId = 1;

        genesisHeight = block.number.toUint64();
        keyManagerAddress = _keyManagerAddress;
        taikoL2Address = _taikoL2Address;
        daoAddress = _daoAddress;

        Evidence memory evidence = Evidence({
            prover: address(0),
            proverFee: 0,
            proposedAt: 0,
            provenAt: 0,
            snippet: genesis
        });
        emit BlockFinalized(0, 0, evidence);
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
        context.proposedAt = block.timestamp.toUint64();
        context.txListHash = txList.hashTxList();

        // if multiple L2 blocks included in the same L1 block,
        // their block.mixHash fields for randomness will be the same.
        context.mixHash = bytes32(block.difficulty);

        context.proverFee = context.gasLimit * proverGasPrice + proverBaseFee;

        require(msg.value >= context.proverFee, "insufficient fee");

        if (msg.value > context.proverFee) {
            payable(msg.sender).transfer(msg.value - context.proverFee);
        }

        _stats.avgPendingSize = _calcAverage(
            _stats.avgPendingSize,
            nextPendingId - lastFinalizedId - 1
        );

        _savePendingBlock(nextPendingId, _hashContext(context));
        emit BlockProposed(nextPendingId, context);

        nextPendingId += 1;
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
            KeyManager(keyManagerAddress).getKey(ZKP_VKEY),
            header.parentHash,
            blockHash,
            context.txListHash,
            proofs[0]
        );

        (bytes32 proofKey, bytes32 proofVal) = LibStorageProof
            .computeAnchorProofKV(
                header.height,
                context.anchorHeight,
                context.anchorHash
            );

        if (!anchored) {
            proofVal = 0x0;
        }

        LibMerkleProof.verify(
            header.stateRoot,
            taikoL2Address,
            proofKey,
            proofVal,
            proofs[1]
        );

        Evidence memory evidence = Evidence({
            prover: msg.sender,
            proverFee: context.proverFee,
            proposedAt: context.proposedAt,
            provenAt: block.timestamp.toUint64(),
            snippet: Snippet({
                blockHash: blockHash,
                stateRoot: header.stateRoot
            })
        });

        evidences[context.id][header.parentHash] = evidence;

        emit BlockProven(context.id, header.parentHash, evidence);
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
                finalizedBlocks[throwAwayHeader.height - 1].blockHash,
            "parent mismatch"
        );

        LibZKP.verify(
            KeyManager(keyManagerAddress).getKey(ZKP_VKEY),
            throwAwayHeader.parentHash,
            throwAwayHeader.hashBlockHeader(),
            throwAwayTxListHash,
            proofs[0]
        );

        (bytes32 key, bytes32 value) = LibStorageProof
            .computeInvalidTxListProofKV(context.txListHash);

        LibMerkleProof.verify(
            throwAwayHeader.stateRoot,
            taikoL2Address,
            key,
            value,
            proofs[1]
        );

        _invalidateBlock(context);
    }

    function verifyBlockInvalid(
        BlockContext calldata context,
        bytes calldata txList
    ) external nonReentrant whenBlockIsPending(context) {
        require(txList.hashTxList() == context.txListHash, "txList mismatch");
        require(!LibTxListValidator.isTxListValid(txList), "txList decoded");

        _invalidateBlock(context);
    }

    /**********************
     * Public Functions   *
     **********************/

    function finalizeBlocks() public {
        Snippet memory parent = finalizedBlocks[lastFinalizedHeight];
        uint64 id = lastFinalizedId + 1;
        uint256 reads = 0;
        uint256 writes = 0;
        while (
            id < nextPendingId &&
            reads <= MAX_FINALIZATION_READS_PER_TX &&
            writes <= MAX_FINALIZATION_WRITES_PER_TX
        ) {
            Evidence storage evidence = evidences[id][parent.blockHash];

            if (evidence.prover != address(0)) {
                finalizedBlocks[++lastFinalizedHeight] = evidence.snippet;

                _handleFinalizedBlock(id, lastFinalizedHeight, evidence);
                parent = evidence.snippet;
                writes += 1;
            } else {
                if (evidences[id][JUMP_MARKER].prover != address(0)) {
                    _handleFinalizedBlock(
                        id,
                        lastFinalizedHeight,
                        evidences[id][JUMP_MARKER]
                    );
                } else {
                    break;
                }
            }

            lastFinalizedId += 1;
            id += 1;
            reads += 1;
        }
    }

    function validateContext(BlockContext memory context) public view {
        require(
            context.id == 0 &&
                context.txListHash == 0x0 &&
                context.mixHash == 0x0 &&
                context.proposedAt == 0 &&
                context.proverFee == 0,
            "nonzero placeholder fields"
        );

        require(
            block.number <= context.anchorHeight + MAX_ANCHOR_HEIGHT_DIFF &&
                context.anchorHash == blockhash(context.anchorHeight) &&
                context.anchorHash != 0x0,
            "invalid anchor"
        );

        require(context.beneficiary != address(0), "null beneficiary");
        require(
            context.gasLimit <= LibConstants.MAX_TAIKO_BLOCK_GAS_LIMIT,
            "invalid gasLimit"
        );
        require(context.extraData.length <= 32, "extraData too large");
    }

    function getStats() public view returns (Stats memory stats) {
        stats = _stats;
        stats.avgPendingSize /= STAT_SCALE;
        stats.avgProvingDelay /= STAT_SCALE;
        stats.avgFinalizationDelay /= STAT_SCALE;
    }

    /**********************
     * Private Functions  *
     **********************/

    function _invalidateBlock(BlockContext memory context) private {
        require(
            evidences[context.id][JUMP_MARKER].prover == address(0),
            "already invalidated"
        );
        evidences[context.id][JUMP_MARKER] = Evidence({
            prover: msg.sender,
            proverFee: context.proverFee,
            proposedAt: context.proposedAt,
            provenAt: block.timestamp.toUint64(),
            snippet: Snippet({blockHash: 0x0, stateRoot: 0x0})
        });
        emit BlockProvenInvalid(context.id);
    }

    function _handleFinalizedBlock(
        uint64 id,
        uint64 height,
        Evidence storage evidence
    ) private {
        bool success;
        (success, ) = evidence.prover.call{value: evidence.proverFee}("");

        if (!success && daoAddress != address(0)) {
            (success, ) = daoAddress.call{value: evidence.proverFee}("");
        }

        _stats.avgProvingDelay = _calcAverage(
            _stats.avgProvingDelay,
            evidence.provenAt - evidence.proposedAt
        );

        _stats.avgFinalizationDelay = _calcAverage(
            _stats.avgFinalizationDelay,
            block.timestamp.toUint64() - evidence.proposedAt
        );

        emit BlockFinalized(id, height, evidence);

        // Delete the evidence to potentially avoid 5 sstore ops.
        evidence.prover = address(0);
        evidence.proverFee = 0;
        evidence.proposedAt = 0;
        evidence.proposedAt = 0;
        delete evidence.snippet;
    }

    function _savePendingBlock(uint256 id, bytes32 contextHash)
        private
        returns (bytes32)
    {
        return pendingBlocks[id % MAX_PENDING_BLOCKS] = contextHash;
    }

    function _getPendingBlock(uint256 id) private view returns (bytes32) {
        return pendingBlocks[id % MAX_PENDING_BLOCKS];
    }

    function _checkContextPending(BlockContext calldata context) private view {
        require(
            context.id > lastFinalizedId && context.id < nextPendingId,
            "invalid id"
        );
        require(
            _getPendingBlock(context.id) == _hashContext(context),
            "context mismatch"
        );
    }

    function _validateHeader(BlockHeader calldata header) private pure {
        require(
            header.parentHash != 0x0 &&
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
                keccak256(header.extraData) == keccak256(context.extraData) && // TODO: direct compare
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

    function _calcAverage(uint64 avg, uint64 current)
        private
        pure
        returns (uint64)
    {
        if (avg == 0) {
            return current;
        }
        uint256 value = ((STAT_AVERAGING_FACTOR - 1) *
            avg +
            current *
            STAT_SCALE) / STAT_AVERAGING_FACTOR;
        return value.toUint64();
    }
}
