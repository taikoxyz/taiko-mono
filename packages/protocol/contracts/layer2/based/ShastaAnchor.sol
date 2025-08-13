// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { PacayaAnchor } from "./PacayaAnchor.sol";
import { ISyncedBlockManager } from "src/shared/based/iface/ISyncedBlockManager.sol";
import { IBondManager as IShastaBondManager } from "./IBondManager.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

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
        address designatedProver; // The designated prover for the current batch
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

    IShastaBondManager public immutable bondManager;
    ISyncedBlockManager public immutable syncedBlockManager;

    State public _state;

    uint256[48] private __gap;

    // -------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------

    /// @notice Emitted when a prover is designated for a proposal.
    /// @param prover The address of the designated prover.
    event ProverDesignated(address prover);

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
    /// @param _isLowBondProposal Boolean indicating if this is a 'low bond proposal'
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
        bool _isLowBondProposal,
        bytes calldata _proverAuth,
        bytes32 _bondInstructionsHash,
        LibBonds.BondInstruction[] calldata _bondInstructions,
        // Block level fields - specific to this block in the proposal
        uint16 _blockIndex,
        uint48 _anchorBlockNumber,
        bytes32 _anchorBlockHash,
        bytes32 _anchorStateRoot
    )
        external
        onlyGoldenTouch
        nonReentrant
        returns (address designatedProver_)
    {
        // Ensure Shasta fork is active
        require(block.number >= shastaForkHeight, L2_FORK_ERROR());

        // Track parent block hash to ensure setState is only called once per block
        _trackParentBlockHash(block.number - 1);

        // Initialize proposal state on first block
        if (_blockIndex == 0) {
            designatedProver_ =
                _initializeProposal(_proposalId, _proposer, _isLowBondProposal, _proverAuth);
        }

        // Process L1 anchor data if we have a new anchor block
        if (_anchorBlockNumber > _state.anchorBlockNumber) {
            _processAnchorData(
                _anchorBlockNumber,
                _anchorBlockHash,
                _anchorStateRoot,
                _bondInstructions,
                _bondInstructionsHash
            );
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

    /// @dev Tracks the parent block hash to ensure setState is only called once per block.
    /// @param _parentId The parent block ID (current block number - 1)
    function _trackParentBlockHash(uint256 _parentId) private {
        require(_blockhashes[_parentId] == 0, BlockHashAlreadySet());
        _blockhashes[_parentId] = blockhash(_parentId);
    }

    /// @dev Initializes the proposal state for the first block.
    /// @param _proposalId The proposal ID
    /// @param _proposer The proposer address
    /// @param _isLowBondProposal Whether this is a low bond proposal
    /// @param _proverAuth The prover authentication data
    /// @return designatedProver_ The designated prover address
    function _initializeProposal(
        uint48 _proposalId,
        address _proposer,
        bool _isLowBondProposal,
        bytes calldata _proverAuth
    )
        private
        returns (address designatedProver_)
    {
        if (_isLowBondProposal) {
            designatedProver_ = _state.designatedProver;
        } else {
            designatedProver_ = _verifyProverAuth(_proposalId, _proposer, _proverAuth);
            _state.designatedProver = designatedProver_;
        }

        emit ProverDesignated(designatedProver_);
    }

    /// @dev Processes bond instructions and updates the cumulative hash.
    /// @param _bondInstructions The bond instructions to process
    /// @param _expectedHash The expected cumulative hash after processing
    /// @return newHash_ The new cumulative hash
    function _processBondInstructions(
        LibBonds.BondInstruction[] calldata _bondInstructions,
        bytes32 _expectedHash
    )
        private
        returns (bytes32 newHash_)
    {
        newHash_ = _state.bondInstructionsHash;

        for (uint256 i; i < _bondInstructions.length; ++i) {
            LibBonds.BondInstruction memory instruction = _bondInstructions[i];
            uint48 bond;
            if (instruction.bondType == LibBonds.BondType.LIVENESS) {
                bond = livenessBondGwei;
            } else if (instruction.bondType == LibBonds.BondType.PROVABILITY) {
                bond = provabilityBondGwei;
            }

            // Credit the bond to the receiver
            if (bond != 0) {
                uint96 bondDebited = bondManager.debitBond(instruction.payer, bond);
                bondManager.creditBond(instruction.receiver, bondDebited);
            }

            // Update cumulative hash
            newHash_ = LibBonds.aggregateBondInstruction(newHash_, instruction);
        }

        // Verify the cumulative hash matches expected value
        require(newHash_ == _expectedHash, BondInstructionsHashMismatch());
    }

    /// @dev Processes L1 anchor data by saving synced block and processing bond instructions.
    /// @param _anchorBlockNumber The L1 block number to anchor
    /// @param _anchorBlockHash The L1 block hash
    /// @param _anchorStateRoot The L1 state root
    /// @param _bondInstructions The bond instructions to process
    /// @param _bondInstructionsHash The expected bond instructions hash
    function _processAnchorData(
        uint48 _anchorBlockNumber,
        bytes32 _anchorBlockHash,
        bytes32 _anchorStateRoot,
        LibBonds.BondInstruction[] calldata _bondInstructions,
        bytes32 _bondInstructionsHash
    )
        private
    {
        // Save the L1 block data for cross-chain verification
        syncedBlockManager.saveSyncedBlock(_anchorBlockNumber, _anchorBlockHash, _anchorStateRoot);

        // Process bond instructions and update state
        bytes32 newBondHash = _processBondInstructions(_bondInstructions, _bondInstructionsHash);

        _state.bondInstructionsHash = newBondHash;
        _state.anchorBlockNumber = _anchorBlockNumber;
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
        if (_proverAuth.length == 0) return _proposer;

        ProverAuth memory proverAuth = abi.decode(_proverAuth, (ProverAuth));

        // Handle zero proposal ID case - all fields must be empty
        if (proverAuth.proposalId != _proposalId) return _proposer;
        if (proverAuth.proposer != _proposer) return _proposer;
        if (proverAuth.signature.length == 0) return _proposer;

        // Verify the ECDSA signature
        bytes32 message = keccak256(abi.encode(proverAuth.proposalId, proverAuth.proposer));
        address designatedProver = ECDSA.recover(message, proverAuth.signature);

        // Ensure valid signature from the proposer (self-designation)
        if (designatedProver == address(0) || designatedProver == _proposer) return _proposer;

        // Check if signer has sufficient bond balance
        if (
            !bondManager.hasSufficientBond(_proposer, proverAuth.provingFeeGwei)
                || !bondManager.hasSufficientBond(designatedProver, 0)
        ) {
            return _proposer;
        }

        // Debit the required bonds from the designated prover
        uint96 bondDebited = bondManager.debitBond(_proposer, proverAuth.provingFeeGwei);
        bondManager.creditBond(designatedProver, bondDebited);

        return designatedProver;
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
