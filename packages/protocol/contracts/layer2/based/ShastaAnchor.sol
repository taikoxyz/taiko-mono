// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { PacayaAnchor } from "./PacayaAnchor.sol";
import { LibCheckpointStore } from "src/shared/shasta/libs/LibCheckpointStore.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { IBondManager as IShastaBondManager } from "./IBondManager.sol";
import { LibBonds } from "src/shared/shasta/libs/LibBonds.sol";

/// @title ShastaAnchor
/// @notice Implements the Shasta fork's anchoring mechanism with advanced bond management,
/// prover designation and checkpoint management.
/// @dev This contract extends PacayaAnchor to add:
///      - Bond-based economic security for proposals and proofs
///      - Prover designation with signature authentication
///      - Cumulative bond instruction processing with integrity verification
///      - State tracking for multi-block proposals
///      - Checkpoint storage for L1 block data
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaAnchor is PacayaAnchor, ICheckpointStore {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Stores the current state of an anchor proposal being processed.
    /// @dev This state is updated incrementally as each block in a proposal is processed.
    struct State {
        bytes32 bondInstructionsHash; // Latest known bond instructions hash
        uint48 anchorBlockNumber; // Latest L1 block number anchored to L2
        address designatedProver; // The prover designated for the current batch
        bool isLowBondProposal; // Indicates if the proposal has insufficient bonds
        uint48 endOfSubmissionWindowTimestamp; // The timestamp of the last slot where the current
            // preconfer can submit preconf-ed blocks to the L2 network.
    }

    /// @notice Authentication data for prover designation.
    /// @dev Used to allow a proposer to designate another address as the prover.
    struct ProverAuth {
        uint48 proposalId; // The proposal ID this auth is for
        address proposer; // The original proposer address
        uint48 provingFeeGwei; // Fee in Gwei that prover will receive
        bytes signature; // ECDSA signature from the designated prover
    }

    // ---------------------------------------------------------------
    // Constants and Immutables
    // ---------------------------------------------------------------

    /// @notice Gas limit for anchor transactions (must be enforced).
    uint64 public constant ANCHOR_GAS_LIMIT = 1_000_000;

    /// @notice Bond amount in Gwei for liveness guarantees.
    uint48 public immutable livenessBondGwei;

    /// @notice Bond amount in Gwei for provability guarantees.
    uint48 public immutable provabilityBondGwei;

    /// @notice Contract managing bond deposits, withdrawals, and transfers.
    IShastaBondManager public immutable bondManager;

    /// @notice Maximum number of checkpoints to store in ring buffer.
    uint16 public immutable maxCheckpointHistory;

    // ---------------------------------------------------------------
    // State variables
    // ---------------------------------------------------------------

    /// @notice Current state of the anchor proposal being processed.
    /// @dev 3 slots used to store the state:
    State private _state;

    mapping(uint256 blockId => uint256 endOfSubmissionWindowTimestamp) public
        blockIdToEndOfSubmissionWindowTimeStamp;

    /// @dev Storage for checkpoint management
    /// @dev 2 slots used
    LibCheckpointStore.Storage internal _checkpointStorage;

    /// @notice Storage gap for upgrade safety.
    uint256[44] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the ShastaAnchor contract.
    /// @param _livenessBondGwei The liveness bond amount in Gwei.
    /// @param _provabilityBondGwei The provability bond amount in Gwei.
    /// @param _signalService The address of the signal service.
    /// @param _pacayaForkHeight The block height at which the Pacaya fork is activated.
    /// @param _shastaForkHeight The block height at which the Shasta fork is activated.
    /// @param _maxCheckpointHistory The maximum number of checkpoints to store.
    /// @param _bondManager The address of the bond manager.
    constructor(
        uint48 _livenessBondGwei,
        uint48 _provabilityBondGwei,
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight,
        uint16 _maxCheckpointHistory,
        IShastaBondManager _bondManager
    )
        PacayaAnchor(_signalService, _pacayaForkHeight, _shastaForkHeight)
    {
        require(
            _shastaForkHeight == 0 || _shastaForkHeight > _pacayaForkHeight, InvalidForkHeight()
        );
        require(_maxCheckpointHistory != 0, LibCheckpointStore.InvalidMaxCheckpointHistory());

        livenessBondGwei = _livenessBondGwei;
        provabilityBondGwei = _provabilityBondGwei;
        maxCheckpointHistory = _maxCheckpointHistory;
        bondManager = _bondManager;
    }

    // ---------------------------------------------------------------
    // External Functions (Non-View)
    // ---------------------------------------------------------------

    /// @notice Processes a block within a proposal, handling bond instructions and L1 data
    /// anchoring.
    /// @dev Core function that processes blocks sequentially within a proposal:
    ///      1. Designates prover on first block (blockIndex == 0)
    ///      2. Processes bond transfers with cumulative hash verification
    ///      3. Anchors L1 block data for cross-chain verification
    ///      4. Tracks parent block hash to prevent duplicate calls
    /// @param _proposalId Unique identifier of the proposal being anchored.
    /// @param _proposer Address of the entity that proposed this batch of blocks.
    /// @param _proverAuth Encoded ProverAuth for prover designation (empty after block 0).
    /// @param _bondInstructionsHash Bond instructions hash in the (-BOND_PROCESSING_DELAY) ancestor
    /// proposal. This value must be zero if _proposalId <= BOND_PROCESSING_DELAY.
    /// @param _bondInstructions Bond credit instructions to process for this block.
    /// @param _blockIndex Current block index within the proposal (0-based).
    /// @param _anchorBlockNumber L1 block number to anchor (0 to skip anchoring).
    /// @param _anchorBlockHash L1 block hash at _anchorBlockNumber.
    /// @param _anchorStateRoot L1 state root at _anchorBlockNumber.
    /// @param _endOfSubmissionWindowTimestamp The timestamp of the last slot where the current
    /// preconfer
    /// can propose.
    /// @return previousState_ The previous state of the anchor. This value make proving easier.
    /// @return newState_ The new state of the anchor.
    function updateState(
        // Proposal level fields - define the overall batch
        uint48 _proposalId,
        address _proposer,
        bytes calldata _proverAuth,
        bytes32 _bondInstructionsHash,
        LibBonds.BondInstruction[] calldata _bondInstructions,
        // Block level fields - specific to this block in the proposal
        uint16 _blockIndex,
        uint48 _anchorBlockNumber,
        bytes32 _anchorBlockHash,
        bytes32 _anchorStateRoot,
        uint48 _endOfSubmissionWindowTimestamp
    )
        external
        onlyGoldenTouch
        nonReentrant
        returns (State memory previousState_, State memory newState_)
    {
        // Fork validation
        require(block.number >= shastaForkHeight, L2_FORK_ERROR());

        previousState_ = _state;
        newState_ = previousState_;

        // Prevent duplicate calls within same block
        _trackParentBlockHash(block.number - 1);

        // Handle prover designation on first block
        if (_blockIndex == 0) {
            uint256 proverFee;
            (newState_.isLowBondProposal, newState_.designatedProver, proverFee) =
                _getDesignatedProver(_proposalId, _proposer, _proverAuth);

            if (proverFee > 0) {
                bondManager.debitBond(_proposer, proverFee);
                bondManager.creditBond(newState_.designatedProver, proverFee);
            }
        }

        // Process new L1 anchor data
        if (_anchorBlockNumber > previousState_.anchorBlockNumber) {
            // Save L1 block data
            LibCheckpointStore.saveCheckpoint(
                _checkpointStorage,
                ICheckpointStore.Checkpoint({
                    blockNumber: _anchorBlockNumber,
                    blockHash: _anchorBlockHash,
                    stateRoot: _anchorStateRoot
                }),
                maxCheckpointHistory
            );

            // Process bond instructions with hash verification
            bytes32 newBondInstructionsHash =
                _processBondInstructions(_bondInstructions, _bondInstructionsHash);

            // Update state atomically
            newState_.bondInstructionsHash = newBondInstructionsHash;
            newState_.anchorBlockNumber = _anchorBlockNumber;
        }

        newState_.endOfSubmissionWindowTimestamp = _endOfSubmissionWindowTimestamp;
        _state = newState_;

        blockIdToEndOfSubmissionWindowTimeStamp[block.number] = _endOfSubmissionWindowTimestamp;
    }

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @notice Returns the current state of the anchor.
    /// @return The current state containing bond hash, anchor block, and designated prover.
    function getState() external view returns (State memory) {
        return _state;
    }

    /// @notice Returns the designated prover
    /// @param _proposalId The proposal ID.
    /// @param _proposer The proposer address.
    /// @param _proverAuth Encoded prover authentication data.
    /// @return isLowBondProposal_ True if proposer has insufficient bonds.
    /// @return designatedProver_ The designated prover address.
    /// @return provingFeeToTransfer_ The proving fee to transfer from the proposer to the
    /// designated prover.
    function getDesignatedProver(
        uint48 _proposalId,
        address _proposer,
        bytes calldata _proverAuth
    )
        external
        view
        returns (bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_)
    {
        return _getDesignatedProver(_proposalId, _proposer, _proverAuth);
    }

    /// @inheritdoc ICheckpointStore
    function getCheckpoint(uint48 _offset) external view returns (Checkpoint memory) {
        return LibCheckpointStore.getCheckpoint(_checkpointStorage, _offset, maxCheckpointHistory);
    }

    /// @inheritdoc ICheckpointStore
    function getLatestCheckpointBlockNumber() external view returns (uint48) {
        return LibCheckpointStore.getLatestCheckpointBlockNumber(_checkpointStorage);
    }

    /// @inheritdoc ICheckpointStore
    function getNumberOfCheckpoints() external view returns (uint48) {
        return LibCheckpointStore.getNumberOfCheckpoints(_checkpointStorage);
    }

    // ---------------------------------------------------------------
    // Private functions
    // ---------------------------------------------------------------

    /// @dev Tracks parent block hash to prevent duplicate updateState calls within same block.
    /// @param _parentId The parent block number (current block - 1).
    function _trackParentBlockHash(uint256 _parentId) private {
        require(_blockhashes[_parentId] == 0, BlockHashAlreadySet());
        _blockhashes[_parentId] = blockhash(_parentId);
    }

    /// @dev Returns the designated prover
    /// @param _proposalId The proposal ID.
    /// @param _proposer The proposer address.
    /// @param _proverAuth Encoded prover authentication data.
    /// @return isLowBondProposal_ True if proposer has insufficient bonds.
    /// @return designatedProver_ The designated prover address.
    /// @return provingFeeToTransfer_ The proving fee to transfer from the proposer to the
    /// designated prover.
    function _getDesignatedProver(
        uint48 _proposalId,
        address _proposer,
        bytes calldata _proverAuth
    )
        private
        view
        returns (bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_)
    {
        // Determine prover and fee
        uint256 provingFee;
        (designatedProver_, provingFee) = _validateProverAuth(_proposalId, _proposer, _proverAuth);

        // Convert proving fee from Gwei to Wei
        provingFee *= 1e9;

        // Check bond sufficiency (convert provingFeeGwei to Wei)
        isLowBondProposal_ = !bondManager.hasSufficientBond(_proposer, provingFee);

        // Handle low bond proposals
        if (isLowBondProposal_) {
            // Use previous designated prover
            designatedProver_ = _state.designatedProver;
        } else if (designatedProver_ != _proposer) {
            if (!bondManager.hasSufficientBond(designatedProver_, 0)) {
                // Fallback to proposer if designated prover has insufficient bonds
                designatedProver_ = _proposer;
            } else {
                provingFeeToTransfer_ = provingFee;
            }
        }
    }

    /// @dev Validates prover authentication and extracts signer.
    /// @param _proposalId The proposal ID to validate against.
    /// @param _proposer The proposer address to validate against.
    /// @param _proverAuth Encoded prover authentication data.
    /// @return signer_ The recovered signer address (proposer if validation fails).
    /// @return provingFeeGwei_ The proving fee in Gwei (0 if validation fails).
    function _validateProverAuth(
        uint48 _proposalId,
        address _proposer,
        bytes calldata _proverAuth
    )
        private
        pure
        returns (address signer_, uint48 provingFeeGwei_)
    {
        // Check if _proverAuth has minimum required length for ProverAuth struct
        // ProverAuth: uint48 (6) + address (20) + uint48 (6) + dynamic bytes offset (32) +
        // bytes length (32) + minimum signature data (65) = 161 bytes minimum
        if (_proverAuth.length < 161) {
            return (_proposer, 0);
        }

        // Decode ProverAuth safely without try-catch
        ProverAuth memory proverAuth = abi.decode(_proverAuth, (ProverAuth));

        // Validate proposal and proposer match
        if (proverAuth.proposalId != _proposalId || proverAuth.proposer != _proposer) {
            return (_proposer, 0);
        }

        // Verify ECDSA signature
        bytes32 message = keccak256(
            abi.encode(proverAuth.proposalId, proverAuth.proposer, proverAuth.provingFeeGwei)
        );
        (address recovered, ECDSA.RecoverError error) =
            ECDSA.tryRecover(message, proverAuth.signature);

        // Return recovered signer or fallback to proposer
        if (error == ECDSA.RecoverError.NoError && recovered != address(0)) {
            signer_ = recovered;
            if (signer_ != _proposer) {
                provingFeeGwei_ = proverAuth.provingFeeGwei;
            }
        } else {
            signer_ = _proposer;
        }
    }

    /// @dev Processes bond instructions with cumulative hash verification.
    /// @param _bondInstructions Bond instructions to process.
    /// @param _expectedHash Expected cumulative hash after processing.
    /// @return newHash_ The new cumulative hash.
    function _processBondInstructions(
        LibBonds.BondInstruction[] calldata _bondInstructions,
        bytes32 _expectedHash
    )
        private
        returns (bytes32 newHash_)
    {
        // Start with current cumulative hash
        newHash_ = _state.bondInstructionsHash;

        // Process each instruction
        uint256 length = _bondInstructions.length;
        for (uint256 i; i < length; ++i) {
            LibBonds.BondInstruction memory instruction = _bondInstructions[i];

            // Determine bond amount based on type
            uint48 bond;
            if (instruction.bondType == LibBonds.BondType.LIVENESS) {
                bond = livenessBondGwei;
            } else if (instruction.bondType == LibBonds.BondType.PROVABILITY) {
                bond = provabilityBondGwei;
            }

            // Transfer bond from payer to receiver
            if (bond != 0) {
                uint256 bondDebited = bondManager.debitBond(instruction.payer, bond);
                bondManager.creditBond(instruction.receiver, bondDebited);
            }

            // Update cumulative hash
            newHash_ = LibBonds.aggregateBondInstruction(newHash_, instruction);
        }

        // Verify hash integrity
        require(newHash_ == _expectedHash, BondInstructionsHashMismatch());
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
    error ProposalIdMismatch();
    error ProposerMismatch();
}
