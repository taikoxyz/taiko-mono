// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { PacayaAnchor } from "./PacayaAnchor.sol";
import { ISyncedBlockManager } from "src/shared/shasta/iface/ISyncedBlockManager.sol";
import { IShastaBondManager } from "src/shared/shasta/iface/IBondManager.sol";
import { LibBondOperation } from "src/shared/shasta/libs/LibBondOperation.sol";
import { LibManifest } from "./libs/LibManifest.sol";

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
        // Proposal level fields (set once per proposal on first block)
        uint48 proposalId; // Unique identifier for the current proposal
        uint16 blockCount; // Total number of blocks in the proposal
        address proposer; // Address that initiated the proposal
        address designatedProver; // Address authorized to prove this proposal (address(0) if none)
        bytes32 bondOperationsHash; // Cumulative hash of all bond operations processed so far
        // Block level fields (updated for each block in the proposal)
        uint16 blockIndex; // Current block being processed (0-indexed, < blockCount)
        uint48 anchorBlockNumber; // Latest L1 block number anchored
    }

    // ---------------------------------------------------------------
    // State variables
    // ---------------------------------------------------------------

    // The v4Anchor's transaction gas limit, this value must be enforced
    uint64 public constant ANCHOR_GAS_LIMIT = 1_000_000;

    uint48 public immutable livenessBondGwei;
    uint48 public immutable provabilityBondGwei;

    IShastaBondManager public immutable bondManager;
    ISyncedBlockManager public immutable syncedBlockManager;

    State public _state;

    uint256[48] private __gap;

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
    constructor(
        uint48 _livenessBondGwei,
        uint48 _provabilityBondGwei,
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight,
        ISyncedBlockManager _syncedBlockManager,
        IShastaBondManager _bondManager
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
    }

    // ---------------------------------------------------------------
    // External functions
    // ---------------------------------------------------------------

    /// @notice Sets the state of the anchor for a proposal's block, processing bond operations
    /// and synchronizing L1 block data.
    /// @dev Critical function in the Taiko anchoring mechanism that:
    ///      1. Processes blocks sequentially within a proposal (0 to blockCount-1)
    ///      2. Handles prover designation and bond debiting for first block only
    ///      3. Incrementally processes and validates bond operations with cumulative hashing
    ///      4. Synchronizes L1 block data for cross-chain verification
    ///      5. Updates parent block hash for chain continuity
    ///
    /// Requirements:
    ///      - Caller must be the golden touch address (system account)
    ///      - Shasta fork must be active (block.number >= shastaForkHeight)
    ///      - Blocks must be processed in order (blockIndex 0, 1, 2, ...)
    ///      - ProverAuth only allowed on first block (_blockIndex == 0)
    ///      - Bond operations hash must match cumulative hash after processing
    ///      - If anchorBlockNumber is 0, hash and stateRoot must also be 0
    ///
    /// @param _proposalId Unique identifier of the proposal being anchored
    /// @param _blockCount Total number of blocks in this proposal (must be > _blockIndex)
    /// @param _proposer Address of the entity that proposed this batch of blocks
    /// @param _proverAuth Encoded ProverAuth struct for prover designation (must be empty after
    /// block 0)
    /// @param _bondOperationsHash Expected cumulative hash after processing this block's operations
    /// @param _bondOperations Array of bond credit operations to process for this specific block
    /// @param _blockIndex Current block index within the proposal (0-based, must be < blockCount)
    /// @param _anchorBlockNumber L1 block number to anchor (0 = skip anchoring for this block)
    /// @param _anchorBlockHash L1 block hash at _anchorBlockNumber (must be 0 if not anchoring)
    /// @param _anchorStateRoot L1 state root at _anchorBlockNumber (must be 0 if not anchoring)
    function updateState(
        // Proposal level fields - define the overall batch
        uint48 _proposalId,
        uint16 _blockCount,
        address _proposer,
        bytes calldata _proverAuth,
        bytes32 _bondOperationsHash,
        LibBondOperation.BondOperation[] calldata _bondOperations,
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
        // Validate block index is within proposal bounds
        require(_blockIndex < _blockCount, InvalidBlockIndex());

        // First block of proposal: initialize proposal state and verify prover
        if (_blockIndex == 0) {
            _state.proposalId = _proposalId;
            _state.blockCount = _blockCount;
            _state.proposer = _proposer;

            // Verify prover authentication and debit bonds if valid
            _state.designatedProver = _verifyProverAuth(_proposalId, _proposer, _proverAuth);
        }

        // Update current block index
        _state.blockIndex = _blockIndex;

        // Process L1 anchor data if provided
        if (_anchorBlockNumber != 0) {
            // Save the L1 block data for cross-chain verification
            syncedBlockManager.saveSyncedBlock(
                _anchorBlockNumber, _anchorBlockHash, _anchorStateRoot
            );

            // Process bond operations incrementally
            bytes32 bondOperationsHash = _state.bondOperationsHash;

            for (uint256 i; i < _bondOperations.length; ++i) {
                LibBondOperation.BondOperation memory op = _bondOperations[i];
                // Credit the bond to the receiver
                bondManager.creditBond(op.receiver, op.credit);
                // Update cumulative hash
                bondOperationsHash = LibBondOperation.aggregateBondOperation(bondOperationsHash, op);
            }
            // Verify the cumulative hash matches expected value
            require(bondOperationsHash == _bondOperationsHash, BondOperationsHashMismatch());

            _state.bondOperationsHash = bondOperationsHash;
            _state.anchorBlockNumber = _anchorBlockNumber;
        } else {
            // If no anchor block, ensure hash and state root are also zero
            require(_anchorBlockHash == 0, NonZeroAnchorBlockHash());
            require(_anchorStateRoot == 0, NonZeroAnchorStateRoot());
        }

        // Update public input hash for parent block verification
        uint256 parentId = block.number - 1;
        _verifyAndUpdatePublicInputHash(parentId);

        // Cache parent block hash for future reference
        _blockhashes[parentId] = blockhash(parentId);
    }

    /// @notice Returns the current state of the anchor.
    /// @return _ The current state.
    function getState() external view returns (State memory) {
        return _state;
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

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

        LibManifest.ProverAuth memory proverAuth = abi.decode(_proverAuth, (LibManifest.ProverAuth));

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
        // TODO: fix minBondBalance
        uint256 minBondBalance = provabilityBondGwei + livenessBondGwei + proverAuth.provingFeeGwei;
        if (bondManager.getBondBalance(signer) < minBondBalance) return _proposer;

        // Debit the required bonds from the designated prover
        bondManager.debitBond(signer, proverAuth.provingFeeGwei);
        bondManager.creditBond(_proposer, proverAuth.provingFeeGwei);

        return signer;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BondOperationsHashMismatch();
    error InvalidForkHeight();
    error NonZeroAnchorBlockHash();
    error NonZeroAnchorStateRoot();
    error NonZeroBlockIndex();
    error ZeroBlockCount();
    error InvalidBlockIndex();
}
