// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { PacayaAnchor } from "./PacayaAnchor.sol";
import { ISyncedBlockManager } from "src/shared/based/iface/ISyncedBlockManager.sol";
import { IBondManager as IShastaBondManager } from "./IBondManager.sol";
import { LibBondInstruction } from "src/shared/based/libs/LibBondInstruction.sol";

/// @title ShastaAnchor
/// @notice Anchoring functions for the Shasta fork.
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaAnchor is PacayaAnchor {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Stores the current state of an anchor proposal being processed.
    /// @dev This state is updated incrementally as each block in a proposal is processed via
    /// updateState().
    struct State {
        bytes32 bondInstructionsHash; // Cumulative hash of all bond instructions processed so far
        uint48 anchorBlockNumber; // Latest L1 block number anchored
    }

    struct ProverAuth {
        uint48 proposalId;
        address proposer;
        uint48 provingFeeGwei;
        bytes signature;
    }

    // ---------------------------------------------------------------
    // State variables
    // ---------------------------------------------------------------

    // The v4Anchor's transaction gas limit, this value must be enforced
    uint64 public constant ANCHOR_GAS_LIMIT = 1_000_000;

    uint48 public immutable livenessBondGwei;
    uint48 public immutable provabilityBondGwei;
    uint48 public immutable provingTaxGwei;
    uint48 public immutable lowBondProvingRewardGwei;
    uint48 public immutable poolThresholdGwei;

    IShastaBondManager public immutable bondManager;
    ISyncedBlockManager public immutable syncedBlockManager;

    State public _state;

    // Proving incentive pool state
    uint96 public provingFeePoolGwei;
    mapping(uint48 proposalId => bool isLowBond) public lowBondProposals;

    uint256[46] private __gap;

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------

    /// @notice Initializes the ShastaAnchor contract.
    /// @param _livenessBondGwei The liveness bond amount in Gwei.
    /// @param _provabilityBondGwei The provability bond amount in Gwei.
    /// @param _signalService The address of the signal service.
    /// @param _pacayaForkHeight The block height at which the Pacaya fork is activated.
    /// @param _shastaForkHeight The block height at which the Shasta fork is activated.
    /// @param _syncedBlockManager The address of the synced block manager.
    /// @param _bondManager The address of the bond manager.
    /// @param _provingTaxGwei The tax amount per proposal in Gwei.
    /// @param _lowBondProvingRewardGwei The reward for proving low-bond proposals in Gwei.
    /// @param _poolThresholdGwei The threshold below which tax is collected in Gwei.
    constructor(
        uint48 _livenessBondGwei,
        uint48 _provabilityBondGwei,
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight,
        ISyncedBlockManager _syncedBlockManager,
        IShastaBondManager _bondManager,
        uint48 _provingTaxGwei,
        uint48 _lowBondProvingRewardGwei,
        uint48 _poolThresholdGwei
    )
        PacayaAnchor(_signalService, _pacayaForkHeight, _shastaForkHeight)
    {
        require(
            _shastaForkHeight == 0 || _shastaForkHeight > _pacayaForkHeight, InvalidForkHeight()
        );

        livenessBondGwei = _livenessBondGwei;
        provabilityBondGwei = _provabilityBondGwei;
        syncedBlockManager = _syncedBlockManager;
        bondManager = _bondManager;
        provingTaxGwei = _provingTaxGwei;
        lowBondProvingRewardGwei = _lowBondProvingRewardGwei;
        poolThresholdGwei = _poolThresholdGwei;
    }

    // ---------------------------------------------------------------
    // External functions
    // ---------------------------------------------------------------

    /// @notice Sets the state of the anchor for a proposal's block, processing bond instructions
    /// and synchronizing L1 block data.
    /// @dev Critical function in the Taiko anchoring mechanism that:
    ///      1. Processes blocks sequentially within a proposal (0 to blockCount-1)
    ///      2. Handles prover designation and bond debiting for first block only
    ///      3. Incrementally processes and validates bond instructions with cumulative hashing
    ///      4. Synchronizes L1 block data for cross-chain verification
    ///      5. Updates parent block hash for chain continuity
    ///
    /// Requirements:
    ///      - Caller must be the golden touch address (system account)
    ///      - Shasta fork must be active (block.number >= shastaForkHeight)
    ///      - Blocks must be processed in order (blockIndex 0, 1, 2, ...)
    ///      - ProverAuth only allowed on first block (_blockIndex == 0)
    ///      - Bond instructions hash must match cumulative hash after processing
    ///      - If anchorBlockNumber is 0, hash and stateRoot must also be 0
    ///
    /// @param _proposalId Unique identifier of the proposal being anchored
    /// @param _proposer Address of the entity that proposed this batch of blocks
    /// @param _proverAuth Encoded ProverAuth struct for prover designation (must be empty after
    /// block 0)
    /// @param _bondInstructionsHash Expected cumulative hash after processing this block's
    /// instructions
    /// @param _bondInstructions Array of bond credit instructions to process for this specific
    /// block
    /// @param _blockIndex Current block index within the proposal (0-based, must be < blockCount)
    /// @param _anchorBlockNumber L1 block number to anchor (0 = skip anchoring for this block)
    /// @param _anchorBlockHash L1 block hash at _anchorBlockNumber (must be 0 if not anchoring)
    /// @param _anchorStateRoot L1 state root at _anchorBlockNumber (must be 0 if not anchoring)
    function updateState(
        // Proposal level fields - define the overall batch
        uint48 _proposalId,
        address _proposer,
        bytes calldata _proverAuth,
        bytes32 _bondInstructionsHash,
        LibBondInstruction.BondInstruction[] calldata _bondInstructions,
        // Block level fields - specific to this block in the proposal
        uint16 _blockIndex,
        uint48 _anchorBlockNumber,
        bytes32 _anchorBlockHash,
        bytes32 _anchorStateRoot
    )
        external
        onlyGoldenTouch
        nonReentrant
    {
        // Ensure Shasta fork is active
        require(block.number >= shastaForkHeight, L2_FORK_ERROR());

        // Keep track of the parent block hash for future reference, this logic also guarantees
        // setState cannot be called twice for the same block.
        uint256 parentId = block.number - 1;
        require(_blockhashes[parentId] == 0, BlockHashAlreadySet());
        _blockhashes[parentId] = blockhash(parentId);

        // First block of proposal: initialize proposal state and verify prover
        if (_blockIndex == 0) {
            // Check if proposer has sufficient bonds
            bool hasInsufficientBonds = !bondManager.hasSufficientBond(_proposer, 0);

            if (hasInsufficientBonds) {
                // Mark as low-bond proposal
                lowBondProposals[_proposalId] = true;
            } else if (provingFeePoolGwei < poolThresholdGwei) {
                // Collect proving tax only if pool is below threshold
                uint96 taxDebited = bondManager.debitBond(_proposer, provingTaxGwei);
                provingFeePoolGwei += taxDebited;
            }

            // Verify prover authentication and debit bonds if valid
            _verifyProverAuth(_proposalId, _proposer, _proverAuth);
        }

        // Process L1 anchor data if provided
        if (_anchorBlockNumber > _state.anchorBlockNumber) {
            // Save the L1 block data for cross-chain verification
            syncedBlockManager.saveSyncedBlock(
                _anchorBlockNumber, _anchorBlockHash, _anchorStateRoot
            );

            // Process bond instructions incrementally
            bytes32 bondInstructionsHash = _state.bondInstructionsHash;

            for (uint256 i; i < _bondInstructions.length; ++i) {
                LibBondInstruction.BondInstruction memory instruction = _bondInstructions[i];

                // Check if this is a low-bond proposal
                if (lowBondProposals[instruction.proposalId]) {
                    // For low-bond proposals, pay reward from the pool to the actual prover
                    // (creditTo)
                    // regardless of timing
                    _payProvingReward(instruction.creditTo);
                } else {
                    // Normal bond instruction processing
                    uint48 bond = _getBondAmount(instruction.bondType);
                    
                    // Only process bond if amount is non-zero
                    if (bond > 0) {
                        // Credit the bond to the receiver
                        uint96 bondDebited = bondManager.debitBond(instruction.debitFrom, bond);
                        bondManager.creditBond(instruction.creditTo, bondDebited);
                    }
                }

                // Update cumulative hash
                bondInstructionsHash =
                    LibBondInstruction.aggregateBondInstruction(bondInstructionsHash, instruction);
            }
            // Verify the cumulative hash matches expected value
            require(bondInstructionsHash == _bondInstructionsHash, BondInstructionsHashMismatch());

            _state.bondInstructionsHash = bondInstructionsHash;
            _state.anchorBlockNumber = _anchorBlockNumber;
        }
    }

    /// @notice Returns the current state of the anchor.
    /// @return _ The current state.
    function getState() external view returns (State memory) {
        return _state;
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Pays proving reward for low-bond proposals from the fee pool
    /// @param _prover The address of the prover to reward
    function _payProvingReward(address _prover) private {
        // Calculate reward amount (minimum of pool balance and configured reward)
        uint96 reward = lowBondProvingRewardGwei;
        if (provingFeePoolGwei < reward) {
            reward = provingFeePoolGwei;
        }

        // Pay the reward if available
        if (reward > 0) {
            provingFeePoolGwei -= reward;
            bondManager.creditBond(_prover, reward);
        }
    }

    /// @dev Returns the bond amount based on the bond type.
    /// @param _bondType The type of bond
    /// @return The bond amount in Gwei, or 0 for NONE
    function _getBondAmount(LibBondInstruction.BondType _bondType) private view returns (uint48) {
        if (_bondType == LibBondInstruction.BondType.LIVENESS) {
            return livenessBondGwei;
        } else if (_bondType == LibBondInstruction.BondType.PROVABILITY) {
            return provabilityBondGwei;
        } else {
            // BondType.NONE
            return 0;
        }
    }

    /// @dev Verifies prover authorization and debits required bonds.
    /// The function checks if the proposer has designated themselves as a prover
    /// by providing a valid signature. If valid, it debits the required bonds.
    /// @param _proposalId The proposal ID to verify against
    /// @param _proposer The proposer's address to verify
    /// @param _proverAuth Encoded ProverAuth containing signature
    /// @return The designated prover's address if valid, address(0) if no prover or invalid
    function _verifyProverAuth(
        uint48 _proposalId,
        address _proposer,
        bytes calldata _proverAuth
    )
        private
        returns (address)
    {
        // Empty auth means no designated prover
        if (_proverAuth.length == 0) return address(0);

        ProverAuth memory proverAuth = abi.decode(_proverAuth, (ProverAuth));

        // Handle zero proposal ID case - all fields must be empty
        if (proverAuth.proposalId != _proposalId) return _proposer;
        if (proverAuth.proposer != _proposer) return _proposer;
        if (proverAuth.signature.length == 0) return _proposer;

        // Verify the ECDSA signature
        bytes32 message = keccak256(abi.encode(proverAuth.proposalId, proverAuth.proposer));
        address signer = ECDSA.recover(message, proverAuth.signature);

        // Ensure valid signature from the proposer (self-designation)
        if (signer == address(0) || signer != _proposer) return _proposer;

        // Check if signer has sufficient bond balance
        if (!bondManager.hasSufficientBond(signer, proverAuth.provingFeeGwei)) {
            return _proposer;
        }

        // Debit the required bonds from the designated prover
        uint96 bondDebited = bondManager.debitBond(_proposer, proverAuth.provingFeeGwei);
        bondManager.creditBond(signer, bondDebited);

        return signer;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BlockHashAlreadySet();
    error BondInstructionsHashMismatch();
    error InvalidBlockIndex();
    error InvalidAnchorBlockNumber();
    error InvalidForkHeight();
    error NonZeroAnchorBlockHash();
    error NonZeroAnchorStateRoot();
    error NonZeroBlockIndex();
    error ZeroBlockCount();
}
