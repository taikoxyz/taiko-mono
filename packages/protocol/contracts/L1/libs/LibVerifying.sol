// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../common/AddressResolver.sol";
import "../../libs/LibMath.sol";
import "../../signal/ISignalService.sol";
import "../../signal/LibSignals.sol";
import "../tiers/ITierProvider.sol";
import "../TaikoData.sol";
import "./LibUtils.sol";

/// @title LibVerifying
/// @notice A library for handling block verification in the Taiko protocol.
library LibVerifying {
    using LibMath for uint256;

    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
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

    function init(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bytes32 genesisBlockHash
    )
        external
    {
        if (!isConfigValid(config)) revert L1_INVALID_CONFIG();

        // Init state
        state.slotA.genesisHeight = uint64(block.number);
        state.slotA.genesisTimestamp = uint64(block.timestamp);
        state.slotB.numBlocks = 1;

        // Init the genesis block
        TaikoData.Block storage blk = state.blocks[0];
        blk.nextTransitionId = 2;
        blk.proposedAt = uint64(block.timestamp);
        blk.verifiedTransitionId = 1;

        // Init the first state transition
        TaikoData.TransitionState storage ts = state.transitions[0][1];
        ts.blockHash = genesisBlockHash;
        ts.prover = address(0);
        ts.timestamp = uint64(block.timestamp);

        emit BlockVerified({
            blockId: 0,
            assignedProver: address(0),
            prover: address(0),
            blockHash: genesisBlockHash,
            stateRoot: 0,
            tier: 0,
            contestations: 0
        });
    }

    function isConfigValid(TaikoData.Config memory config) public pure returns (bool isValid) {
        if (
            config.chainId <= 1 //
                || config.blockMaxProposals == 1
                || config.blockRingBufferSize <= config.blockMaxProposals + 1
                || config.blockMaxGasLimit == 0 || config.blockMaxTxListBytes == 0
                || config.blockMaxTxListBytes > 128 * 1024 // calldata up to 128K
                || config.livenessBond == 0 || config.ethDepositRingBufferSize <= 1
                || config.ethDepositMinCountPerBlock == 0
            // Audit recommendation, and gas tested. Processing 32 deposits (as initially set in
            // TaikoL1.sol) costs 72_502 gas.
            || config.ethDepositMaxCountPerBlock > 32
                || config.ethDepositMaxCountPerBlock < config.ethDepositMinCountPerBlock
                || config.ethDepositMinAmount == 0
                || config.ethDepositMaxAmount <= config.ethDepositMinAmount
                || config.ethDepositMaxAmount >= type(uint96).max || config.ethDepositGas == 0
                || config.ethDepositMaxFee == 0
                || config.ethDepositMaxFee >= type(uint96).max / config.ethDepositMaxCountPerBlock
        ) return false;

        return true;
    }

    /// @dev Verifies up to N blocks.
    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint64 maxBlocksToVerify
    )
        internal
    {
        // Retrieve the latest verified block and the associated transition used
        // for its verification.
        TaikoData.SlotB memory b = state.slotB;
        uint64 blockId = b.lastVerifiedBlockId;

        uint64 slot = blockId % config.blockRingBufferSize;

        TaikoData.Block storage blk = state.blocks[slot];
        if (blk.blockId != blockId) revert L1_BLOCK_MISMATCH();

        uint32 tid = blk.verifiedTransitionId;

        // The following scenario should never occur but is included as a
        // precaution.
        if (tid == 0) revert L1_TRANSITION_ID_ZERO();

        // The `blockHash` variable represents the most recently trusted
        // blockHash on L2.
        bytes32 blockHash = state.transitions[slot][tid].blockHash;
        bytes32 stateRoot;
        uint64 processed;
        address tierProvider;

        // Unchecked is safe:
        // - assignment is within ranges
        // - blockId and processed values incremented will still be OK in the
        // next 584K years if we verifying one block per every second
        unchecked {
            ++blockId;

            while (blockId < b.numBlocks && processed < maxBlocksToVerify) {
                slot = blockId % config.blockRingBufferSize;

                blk = state.blocks[slot];
                if (blk.blockId != blockId) revert L1_BLOCK_MISMATCH();

                tid = LibUtils.getTransitionId(state, blk, slot, blockHash);
                // When `tid` is 0, it indicates that there is no proven
                // transition with its parentHash equal to the blockHash of the
                // most recently verified block.
                if (tid == 0) break;

                // A transition with the correct `parentHash` has been located.
                TaikoData.TransitionState storage ts = state.transitions[slot][tid];

                // It's not possible to verify this block if either the
                // transition is contested and awaiting higher-tier proof or if
                // the transition is still within its cooldown period.
                if (ts.contester != address(0)) {
                    break;
                } else {
                    if (tierProvider == address(0)) {
                        tierProvider = resolver.resolve("tier_provider", false);
                    }
                    if (
                        uint256(ITierProvider(tierProvider).getTier(ts.tier).cooldownWindow)
                            + uint256(ts.timestamp).max(state.slotB.lastUnpausedAt) > block.timestamp
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

                IERC20 tko = IERC20(resolver.resolve("taiko_token", false));
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
                ++processed;
            }

            if (processed > 0) {
                uint64 lastVerifiedBlockId = b.lastVerifiedBlockId + processed;

                // Update protocol level state variables
                state.slotB.lastVerifiedBlockId = lastVerifiedBlockId;

                // Store the L2's state root as a signal to the local signal
                // service to allow for multi-hop bridging.
                //
                // This also means if we verified more than one block, only the last one's stateRoot
                // is sent as a signal and verifiable with merkle proofs, all other blocks'
                // stateRoot are not.
                ISignalService(resolver.resolve("signal_service", false)).relayStateRoot(
                    config.chainId, stateRoot
                );
            }
        }
    }
}
