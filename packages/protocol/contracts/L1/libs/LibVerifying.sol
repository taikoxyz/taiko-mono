// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../common/IAddressResolver.sol";
import "../../libs/LibMath.sol";
import "../../signal/ISignalService.sol";
import "../../signal/LibSignals.sol";
import "../tiers/ITierProvider.sol";
import "../TaikoData.sol";
import "./LibUtils.sol";

/// @title LibVerifying
/// @notice A library for handling block verification in the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
library LibVerifying {
    using LibMath for uint256;

    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
    /// @notice Emitted when a block is verified.
    /// @param blockId The block ID.
    /// @param assignedProver The assigned prover of the block.
    /// @param prover The actual prover of the block.
    /// @param blockHash The block hash.
    /// @param stateRoot The state root.
    /// @param tier The tier of the transition used for verification.
    /// @param contestations The number of contestations.
    event BlockVerified(
        uint256 indexed blockId,
        address indexed assignedProver,
        address indexed prover,
        bytes32 blockHash,
        bytes32 stateRoot,
        uint16 tier,
        uint8 contestations
    );

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_BLOCK_MISMATCH();
    error L1_INVALID_CONFIG();
    error L1_TRANSITION_ID_ZERO();

    /// @notice Initializes the Taiko protocol state.
    /// @param _state The state to initialize.
    /// @param _config The configuration for the Taiko protocol.
    /// @param _genesisBlockHash The block hash of the genesis block.
    function init(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        bytes32 _genesisBlockHash
    )
        external
    {
        if (!_isConfigValid(_config)) revert L1_INVALID_CONFIG();

        // Init state
        _state.slotA.genesisHeight = uint64(block.number);
        _state.slotA.genesisTimestamp = uint64(block.timestamp);
        _state.slotB.numBlocks = 1;

        // Init the genesis block
        TaikoData.Block storage blk = _state.blocks[0];
        blk.nextTransitionId = 2;
        blk.proposedAt = uint64(block.timestamp);
        blk.verifiedTransitionId = 1;

        // Init the first state transition
        TaikoData.TransitionState storage ts = _state.transitions[0][1];
        ts.blockHash = _genesisBlockHash;
        ts.prover = address(0);
        ts.timestamp = uint64(block.timestamp);

        emit BlockVerified({
            blockId: 0,
            assignedProver: address(0),
            prover: address(0),
            blockHash: _genesisBlockHash,
            stateRoot: 0,
            tier: 0,
            contestations: 0
        });
    }

    /// @dev Verifies up to N blocks.
    function verifyBlocks(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        uint64 _maxBlocksToVerify
    )
        internal
    {
        if (_maxBlocksToVerify == 0) {
            return;
        }

        // Retrieve the latest verified block and the associated transition used
        // for its verification.
        TaikoData.SlotB memory b = _state.slotB;
        uint64 blockId = b.lastVerifiedBlockId;

        uint64 slot = blockId % _config.blockRingBufferSize;

        TaikoData.Block storage blk = _state.blocks[slot];
        if (blk.blockId != blockId) revert L1_BLOCK_MISMATCH();

        uint32 tid = blk.verifiedTransitionId;

        // The following scenario should never occur but is included as a
        // precaution.
        if (tid == 0) revert L1_TRANSITION_ID_ZERO();

        // The `blockHash` variable represents the most recently trusted
        // blockHash on L2.
        bytes32 blockHash = _state.transitions[slot][tid].blockHash;
        bytes32 stateRoot;
        uint64 numBlocksVerified;
        address tierProvider;

        // Unchecked is safe:
        // - assignment is within ranges
        // - blockId and numBlocksVerified values incremented will still be OK in the
        // next 584K years if we verifying one block per every second
        unchecked {
            ++blockId;

            while (blockId < b.numBlocks && numBlocksVerified < _maxBlocksToVerify) {
                slot = blockId % _config.blockRingBufferSize;

                blk = _state.blocks[slot];
                if (blk.blockId != blockId) revert L1_BLOCK_MISMATCH();

                tid = LibUtils.getTransitionId(_state, blk, slot, blockHash);
                // When `tid` is 0, it indicates that there is no proven
                // transition with its parentHash equal to the blockHash of the
                // most recently verified block.
                if (tid == 0) break;

                // A transition with the correct `parentHash` has been located.
                TaikoData.TransitionState storage ts = _state.transitions[slot][tid];

                // It's not possible to verify this block if either the
                // transition is contested and awaiting higher-tier proof or if
                // the transition is still within its cooldown period.
                if (ts.contester != address(0)) {
                    break;
                } else {
                    if (tierProvider == address(0)) {
                        tierProvider = _resolver.resolve("tier_provider", false);
                    }
                    if (
                        uint256(ITierProvider(tierProvider).getTier(ts.tier).cooldownWindow) * 60
                            + uint256(ts.timestamp).max(_state.slotB.lastUnpausedAt) > block.timestamp
                    ) {
                        // If cooldownWindow is 0, the block can theoretically
                        // be proved and verified within the same L1 block.
                        break;
                    }
                }

                // Mark this block as verified
                blk.verifiedTransitionId = tid;

                // Update variables
                blockHash = ts.blockHash;
                stateRoot = ts.stateRoot;

                // We consistently return the liveness bond and the validity
                // bond to the actual prover of the transition utilized for
                // block verification. If the actual prover happens to be the
                // block's assigned prover, he will receive both deposits,
                // ultimately earning the proving fee paid during block
                // proposal. In contrast, if the actual prover is different from
                // the block's assigned prover, the liveness bond serves as a
                // reward to the actual prover, while the assigned prover
                // forfeits his liveness bond due to failure to fulfill their
                // commitment.
                uint256 bondToReturn = uint256(ts.validityBond) + blk.livenessBond;

                // Nevertheless, it's possible for the actual prover to be the
                // same individual or entity as the block's assigned prover.
                // Consequently, we have chosen to grant the actual prover only
                // half of the liveness bond as a reward.
                if (ts.prover != blk.assignedProver) {
                    bondToReturn -= blk.livenessBond >> 1;
                }

                IERC20 tko = IERC20(_resolver.resolve("taiko_token", false));
                tko.transfer(ts.prover, bondToReturn);

                // Note: We exclusively address the bonds linked to the
                // transition used for verification. While there may exist
                // other transitions for this block, we disregard them entirely.
                // The bonds for these other transitions are burned either when
                // the transitions are generated or proven. In such cases, both
                // the provers and contesters of those transitions forfeit their bonds.

                emit BlockVerified({
                    blockId: blockId,
                    assignedProver: blk.assignedProver,
                    prover: ts.prover,
                    blockHash: blockHash,
                    stateRoot: stateRoot,
                    tier: ts.tier,
                    contestations: ts.contestations
                });

                ++blockId;
                ++numBlocksVerified;
            }

            if (numBlocksVerified > 0) {
                uint64 lastVerifiedBlockId = b.lastVerifiedBlockId + numBlocksVerified;

                // Update protocol level state variables
                _state.slotB.lastVerifiedBlockId = lastVerifiedBlockId;

                // sync chain data
                _syncChainData(_config, _resolver, lastVerifiedBlockId, stateRoot);
            }
        }
    }

    function _syncChainData(
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        uint64 _lastVerifiedBlockId,
        bytes32 _stateRoot
    )
        private
    {
        ISignalService signalService = ISignalService(_resolver.resolve("signal_service", false));

        (uint64 lastSyncedBlock,) = signalService.getSyncedChainData(
            _config.chainId, LibSignals.STATE_ROOT, 0 /* latest block Id*/
        );

        if (_lastVerifiedBlockId > lastSyncedBlock + _config.blockSyncThreshold) {
            signalService.syncChainData(
                _config.chainId, LibSignals.STATE_ROOT, _lastVerifiedBlockId, _stateRoot
            );
        }
    }

    function _isConfigValid(TaikoData.Config memory _config) private view returns (bool) {
        if (
            _config.chainId <= 1 || _config.chainId == block.chainid //
                || _config.blockMaxProposals == 1
                || _config.blockRingBufferSize <= _config.blockMaxProposals + 1
                || _config.blockMaxGasLimit == 0 || _config.blockMaxTxListBytes == 0
                || _config.blockMaxTxListBytes > 128 * 1024 // calldata up to 128K
                || _config.livenessBond == 0 || _config.ethDepositRingBufferSize <= 1
                || _config.ethDepositMinCountPerBlock == 0
            // Audit recommendation, and gas tested. Processing 32 deposits (as initially set in
            // TaikoL1.sol) costs 72_502 gas.
            || _config.ethDepositMaxCountPerBlock > 32
                || _config.ethDepositMaxCountPerBlock < _config.ethDepositMinCountPerBlock
                || _config.ethDepositMinAmount == 0
                || _config.ethDepositMaxAmount <= _config.ethDepositMinAmount
                || _config.ethDepositMaxAmount > type(uint96).max || _config.ethDepositGas == 0
                || _config.ethDepositMaxFee == 0
                || _config.ethDepositMaxFee > type(uint96).max / _config.ethDepositMaxCountPerBlock
        ) return false;

        return true;
    }
}
