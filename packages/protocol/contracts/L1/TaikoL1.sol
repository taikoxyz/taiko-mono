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
import "../common/IMintableERC20.sol";
import "../libs/LibBlockHeader.sol";
import "../libs/LibConstants.sol";
import "../libs/LibMath.sol";
import "../libs/LibMerkleProof.sol";
import "../libs/LibStorageProof.sol";
import "../libs/LibTxList.sol";
import "../libs/LibZKP.sol";

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
    uint128 feeReserve;
}

struct PendingBlock {
    bytes32 contextHash;
    address proposer;
}

struct Evidence {
    address prover;
    uint128 proverFee;
    uint128 feeRebate;
    uint128 reward;
    uint64 proposedAt;
    uint64 provedAt;
}

struct ForkChoice {
    bytes32 blockHash;
    Evidence[] evidences;
}

// all stat time units are nanosecond
struct Stats {
    uint64 avgPendingSize;
    uint64 avgProvingDelay;
    uint64 avgProvingDelayWithUncles;
    uint64 avgFinalizationDelay;
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
    using SafeCastUpgradeable for uint256;
    using LibBlockHeader for BlockHeader;
    using LibTxList for bytes;
    using LibMath for uint256;
    /**********************
     * Constants   *
     **********************/
    uint256 public constant MAX_ANCHOR_HEIGHT_DIFF = 128;
    uint256 public constant MAX_PENDING_BLOCKS = 2048;
    uint256 public constant MAX_THROW_AWAY_PARENT_DIFF = 1024;
    uint256 public constant MAX_FINALIZATION_PER_TX = 5;
    uint256 public constant DAO_REWARD_RATIO = 100; // 100%
    uint256 public constant MAX_PROOFS_PER_BLOCK = 5;
    uint256 public constant PROVER_FEE_RESERVE_RATIO = 4; // 400%
    uint256 public constant BLOCK_GAS_LIMIT_EXTRA = 1000000; // TODO
    bytes32 public constant SKIP_OVER_BLOCK_HASH = bytes32(uint256(1));
    uint256 public constant STAT_AVERAGING_FACTOR = 2048;
    string public constant ZKP_VKEY = "TAIKO_ZKP_VKEY";
    uint64 public constant NANO_PER_SECOND = 1E9;
    uint64 public constant UTILIZATION_FEE_RATIO = 500; // 5x

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

    uint256 public unsettledProverFee;

    // The following two variables are automiatically adjusted based on
    // the latest finalized blocks.
    uint128 public proverGasPrice; // TODO: auto-adjustable
    uint128 public proverReward; // TODO: auto-adjustable

    Stats private _stats; // 1 slot

    uint256[43] private __gap;

    /**********************
     * Events             *
     **********************/

    event ProverPaid(
        address indexed prover,
        uint256 id,
        uint256 proverFee,
        uint256 reward
    );
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

    function init(
        address _addressManager,
        bytes32 _genesisBlockHash,
        uint256 _proverGasPrice,
        uint256 _amountMintToDAO,
        uint256 _amountMintToTeam
    ) external initializer {
        EssentialContract._init(_addressManager);

        proverGasPrice = _proverGasPrice;

        finalizedBlocks[0] = _genesisBlockHash;
        nextPendingId = 1;

        genesisHeight = block.number.toUint64();

        emit BlockFinalized(0, 0, _genesisBlockHash);

        IMintableERC20 taiToken = IMintableERC20(resolve("tai_token"));
        taiToken.mint(resolve("dao_vault"), _amountMintToDAO);

        taiToken.mint(resolve("team_vault"), _amountMintToTeam);
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

        // Check fees
        context.feeReserve = uint128(
            (PROVER_FEE_RESERVE_RATIO *
                proverGasPrice *
                (context.gasLimit + BLOCK_GAS_LIMIT_EXTRA)).max(
                    type(uint128).max
                )
        );

        _chargeProposer(context.feeReserve);

        _savePendingBlock(nextPendingId, _hashContext(context));
        emit BlockProposed(nextPendingId++, context);

        // Update stats first.
        _stats.avgPendingSize = _calcAverage(
            _stats.avgPendingSize,
            nextPendingId - lastFinalizedId - 1
        );
    }

    // TODO: how to verify the zkp is associated with msg.sender?
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
            proofVal = 0x0;
        }

        LibMerkleProof.verify(
            header.stateRoot,
            resolve("taiko_l2"),
            proofKey,
            proofVal,
            proofs[1]
        );

        _proveBlock(
            MAX_PROOFS_PER_BLOCK,
            context,
            header.parentHash,
            blockHash
        );
    }

    // TODO: how to verify the zkp is associated with msg.sender?
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

        _proveBlock(1, context, SKIP_OVER_BLOCK_HASH, SKIP_OVER_BLOCK_HASH);
    }

    /**********************
     * Public Functions   *
     **********************/

    function finalizeBlocks() public {
        uint64 id = lastFinalizedId + 1;
        uint256 processed = 0;
        uint256 totalReward = 0;

        while (id < nextPendingId && processed <= MAX_FINALIZATION_PER_TX) {
            ForkChoice storage fc = forkChoices[id][
                finalizedBlocks[lastFinalizedHeight]
            ];

            if (fc.blockHash != 0) {
                finalizedBlocks[++lastFinalizedHeight] = fc.blockHash;
                totalReward += _finalizeBlock(id, fc);
            } else {
                fc = forkChoices[id][SKIP_OVER_BLOCK_HASH];
                if (fc.blockHash != 0) {
                    totalReward += _finalizeBlock(id, fc);
                } else {
                    break;
                }
            }

            lastFinalizedId += 1;
            id += 1;
            processed += 1;
        }

        _mintDaoReward(totalReward);
    }

    function validateContext(BlockContext memory context) public view {
        require(
            context.id == 0 &&
                context.txListHash == 0x0 &&
                context.mixHash == 0x0 &&
                context.proposedAt == 0 &&
                context.feeReserve == 0,
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
        stats.avgPendingSize /= NANO_PER_SECOND;
        stats.avgProvingDelay /= NANO_PER_SECOND;
        stats.avgProvingDelayWithUncles /= NANO_PER_SECOND;
        stats.avgFinalizationDelay /= NANO_PER_SECOND;
    }

    function getUtilizationFeeBips()
        public
        view
        returns (
            uint256 /*basisPoints*/
        )
    {
        // TODO(daniel): optimize the math. Maybe also include `proverGasPrice` in the
        // calculation.
        uint256 numPendingBlocks = nextPendingId - lastFinalizedId;

        // threshold is the middle point of MAX_PENDING_BLOCKS/2 and
        // _stats.avgPendingSize
        uint256 threshold = MAX_PENDING_BLOCKS / 4 + _stats.avgPendingSize / 2;
        if (numPendingBlocks <= threshold) return 0;

        return
            (UTILIZATION_FEE_RATIO * 100 * (numPendingBlocks - threshold)) /
            (MAX_PENDING_BLOCKS - threshold);
    }

    function getBlockTaiReward(uint256 provingDelay)
        public
        view
        returns (uint128)
    {
        // TODO: implement this
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

        uint128 reward = getBlockTaiReward(
            block.timestamp - context.proposedAt
        ) / (fc.evidences.length + 1).toUint128();

        Evidence memory evidence = Evidence({
            prover: msg.sender,
            proverFee: 0,
            feeRebate: 0,
            reward: reward,
            proposedAt: context.proposedAt,
            provedAt: block.timestamp.toUint64()
        });

        if (fc.evidences.length == 0) {
            evidence.proverFee = (proverGasPrice *
                (context.gasLimit + BLOCK_GAS_LIMIT_EXTRA))
                .min(context.feeReserve)
                .toUint128();
            evidence.feeRebate = context.feeReserve - evidence.proverFee;
        }

        fc.evidences.push(evidence);

        emit BlockProven(context.id, parentHash, blockHash, evidence);
    }

    function _finalizeBlock(uint64 id, ForkChoice storage fc)
        private
        returns (uint256 totalReward)
    {
        for (uint256 i = 0; i < fc.evidences.length; i++) {
            Evidence memory evidence = fc.evidences[i];

            // Pay prover fee and block reward
            _payProver(i, evidence);

            totalReward += evidence.reward;

            // Update stats
            if (i == 0) {
                _stats.avgFinalizationDelay = _calcAverage(
                    _stats.avgFinalizationDelay,
                    (block.timestamp - evidence.proposedAt).toUint64()
                );

                _stats.avgProvingDelay = _calcAverage(
                    _stats.avgProvingDelay,
                    evidence.provedAt - evidence.proposedAt
                );
            }

            _stats.avgProvingDelayWithUncles = _calcAverage(
                _stats.avgProvingDelayWithUncles,
                evidence.provedAt - evidence.proposedAt
            );
        }

        emit BlockFinalized(
            id,
            lastFinalizedHeight,
            finalizedBlocks[lastFinalizedHeight]
        );
    }

    function _chargeProposer(uint256 proverFee) private {
        uint256 utilizationFee = (proverFee * getUtilizationFeeBips()) / 10000;
        uint256 totalFees = proverFee + utilizationFee;

        require(msg.value >= totalFees, "insufficient fee");

        // Refund
        if (msg.value > totalFees) {
            payable(msg.sender).transfer(msg.value - totalFees);
        }
        if (utilizationFee > 0) {
            payable(resolve("dao_vault")).transfer(utilizationFee);
        }
    }

    function _payProver(uint256 id, Evidence memory evidence) private {
        address proposer = _getPendingBlock(id).proposer;

        bool success;
        (success, ) = evidence.prover.call{value: evidence.proverFee}("");
        if (!success) {
            unsettledProverFee += evidence.proverFee;
        }

        (success, ) = proposer.call{value: evidence.feeRebate}("");
        if (!success) {
            unsettledProverFee += evidence.feeRebate;
        }

        (success, ) = resolve("dao_vault").call{value: unsettledProverFee - 1}(
            ""
        );
        if (success) {
            unsettledProverFee = 1;
        }

        if (evidence.reward != 0) {
            IMintableERC20(resolve("tai_token")).mint(
                evidence.prover,
                evidence.reward
            );
        }

        emit ProverPaid(
            evidence.prover,
            id,
            evidence.proverFee,
            evidence.reward
        );
    }

    function _mintDaoReward(uint256 totalReward) private {
        uint256 daoReward = (totalReward * DAO_REWARD_RATIO) / 100;
        if (daoReward == 0) return;

        IMintableERC20(resolve("tai_token")).mint(
            resolve("dao_vault"),
            daoReward
        );
    }

    function _savePendingBlock(uint256 id, bytes32 contextHash) private {
        pendingBlocks[id % MAX_PENDING_BLOCKS] = PendingBlock({
            contextHash: contextHash,
            proposer: msg.sender
        });
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
        if (current == 0) return avg;
        if (avg == 0) return current;

        uint256 _avg = ((STAT_AVERAGING_FACTOR - 1) *
            avg +
            current *
            NANO_PER_SECOND) / STAT_AVERAGING_FACTOR;
        return _avg.toUint64();
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
