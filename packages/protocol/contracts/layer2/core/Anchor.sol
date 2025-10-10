// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { IBondManager } from "./IBondManager.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title Anchor
/// @notice Implements the Shasta fork's anchoring mechanism with advanced bond management,
/// prover designation and checkpoint management.
/// @dev This contract directly inherits EssentialContract:
///      - Bond-based economic security for proposals and proofs
///      - Prover designation with signature authentication
///      - Cumulative bond instruction processing with integrity verification
///      - State tracking for multi-block proposals
///      - Checkpoint storage for L1 block data
/// @custom:security-contact security@taiko.xyz
contract Anchor is EssentialContract {
    using LibAddress for address;
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice State containing all non-mapping state variables.
    struct State {
        bytes32 ancestorsHash;
        bytes32 bondInstructionsHash;
        address designatedProver;
        uint48 anchorBlockNumber;
        bool isLowBondProposal;
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
    // Constants
    // ---------------------------------------------------------------

    /// @notice Golden touch address is the only address that can do the anchor transaction.
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;

    /// @notice Gas limit for anchor transactions (must be enforced).
    uint64 public constant ANCHOR_GAS_LIMIT = 1_000_000;

    // ---------------------------------------------------------------
    // Immutables
    // ---------------------------------------------------------------

    /// @notice Contract managing bond deposits, withdrawals, and transfers.
    IBondManager public immutable bondManager;

    /// @notice Checkpoint store for storing L1 block data.
    ICheckpointStore public immutable checkpointStore;

    /// @notice Bond amount in Gwei for liveness guarantees.
    uint48 public immutable livenessBondGwei;

    /// @notice Bond amount in Gwei for provability guarantees.
    uint48 public immutable provabilityBondGwei;

    /// @notice Block height at which the Shasta fork is activated.
    uint64 public immutable shastaForkHeight;

    /// @notice The L1's chain ID.
    uint64 public immutable l1ChainId;

    // ---------------------------------------------------------------
    // State variables
    // ---------------------------------------------------------------

    /// @notice A hash to check the integrity of public inputs.
    bytes32 public ancestorsHash;

    /// @notice Latest known bond instructions hash.
    bytes32 public bondInstructionsHash;

    /// @notice The designated prover for the current batch.
    address public designatedProver;

    /// @notice Latest L1 block number anchored to L2.
    uint48 public anchorBlockNumber;

    /// @notice Indicates if the proposal has insufficient bonds.
    bool public isLowBondProposal;

    /// @notice Storage gap for upgrade safety.
    uint256[47] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event Anchored(
        bytes32 ancestorsHash,
        bytes32 bondInstructionsHash,
        address designatedProver,
        uint48 anchorBlockNumber,
        bool isLowBondProposal
    );

    event Withdrawn(address token, address to, uint256 amount);

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------

    modifier onlyValidSenderAndHeight() {
        require(msg.sender == GOLDEN_TOUCH_ADDRESS, InvalidSender());
        require(block.number >= shastaForkHeight, InvalidForkHeight());
        _;
    }

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Anchor contract.
    /// @param _checkpointStore The address of the checkpoint store.
    /// @param _bondManager The address of the bond manager.
    /// @param _livenessBondGwei The liveness bond amount in Gwei.
    /// @param _provabilityBondGwei The provability bond amount in Gwei.
    /// @param _shastaForkHeight The block height at which the Shasta fork is activated.
    /// @param _l1ChainId The L1 chain ID.
    constructor(
        ICheckpointStore _checkpointStore,
        IBondManager _bondManager,
        uint48 _livenessBondGwei,
        uint48 _provabilityBondGwei,
        uint64 _shastaForkHeight,
        uint64 _l1ChainId
    ) {
        // Validate addresses
        require(address(_checkpointStore) != address(0), InvalidAddress());
        require(address(_bondManager) != address(0), InvalidAddress());

        // Validate chain IDs
        require(_l1ChainId != 0 && _l1ChainId != block.chainid, InvalidL1ChainId());
        require(block.chainid > 1 && block.chainid <= type(uint64).max, InvalidL2ChainId());

        // Assign immutables
        checkpointStore = _checkpointStore;
        bondManager = _bondManager;
        livenessBondGwei = _livenessBondGwei;
        provabilityBondGwei = _provabilityBondGwei;
        shastaForkHeight = _shastaForkHeight;
        l1ChainId = _l1ChainId;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
        (ancestorsHash,) = _calcAncestorsHash(block.number);
    }

    /// @notice Processes a block within a proposal, handling bond instructions and L1 data
    /// anchoring.
    /// @dev Core function that processes blocks sequentially within a proposal:
    ///      1. Designates prover on first block (blockIndex == 0)
    ///      2. Processes bond transfers with cumulative hash verification
    ///      3. Anchors L1 block data for cross-chain verification
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
    function anchor(
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
        bytes32 _anchorStateRoot
    )
        external
        onlyValidSenderAndHeight
        nonReentrant
    {
        State memory state = _loadState();

        if (_blockIndex == 0) {
            state = _handleFirstBlock(
                state, _proposalId, _proposer, _proverAuth, _bondInstructions, _bondInstructionsHash
            );
        }

        state =
            _maybeAnchorCheckpoint(state, _anchorBlockNumber, _anchorBlockHash, _anchorStateRoot);
        state.ancestorsHash = _verifyAndUpdateAncestorsHash(block.number - 1, state.ancestorsHash);

        _persistState(state);

        emit Anchored(
            state.ancestorsHash,
            state.bondInstructionsHash,
            state.designatedProver,
            state.anchorBlockNumber,
            state.isLowBondProposal
        );
    }

    /// @notice Withdraw token or Ether from this address.
    /// Note: This contract receives a portion of L2 base fees, while the remainder is directed to
    /// L2 block's coinbase address.
    /// @param _token Token address or address(0) if Ether.
    /// @param _to Withdraw to address.
    function withdraw(
        address _token,
        address _to
    )
        external
        nonZeroAddr(_to)
        onlyOwner
        nonReentrant
    {
        uint256 amount;
        if (_token == address(0)) {
            amount = address(this).balance;
            _to.sendEtherAndVerify(amount);
        } else {
            amount = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransfer(_to, amount);
        }
        emit Withdrawn(_token, _to, amount);
    }

    // ---------------------------------------------------------------
    // Public View Functions
    // ---------------------------------------------------------------

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
        public
        view
        returns (bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_)
    {
        return _getDesignatedProver(_proposalId, _proposer, _proverAuth, designatedProver);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Loads the current contract state into memory for processing.
    /// @return state_ Snapshot of all non-gap storage variables.
    function _loadState() private view returns (State memory state_) {
        state_ = State({
            ancestorsHash: ancestorsHash,
            bondInstructionsHash: bondInstructionsHash,
            designatedProver: designatedProver,
            anchorBlockNumber: anchorBlockNumber,
            isLowBondProposal: isLowBondProposal
        });
    }

    /// @dev Writes a fully processed state back to storage.
    /// @param _state The state snapshot to persist.
    function _persistState(State memory _state) private {
        ancestorsHash = _state.ancestorsHash;
        bondInstructionsHash = _state.bondInstructionsHash;
        designatedProver = _state.designatedProver;
        anchorBlockNumber = _state.anchorBlockNumber;
        isLowBondProposal = _state.isLowBondProposal;
    }

    /// @dev Handles all logic that must only run on the first block of a proposal.
    /// @param _state Working state snapshot to mutate.
    /// @param _proposalId The proposal being processed.
    /// @param _proposer The proposer for the batch.
    /// @param _proverAuth ABI-encoded designation payload.
    /// @param _bondInstructions Bond instructions to process.
    /// @param _expectedBondInstructionsHash Expected hash of the processed instructions.
    /// @return Updated state reflecting prover designation and bond processing.
    function _handleFirstBlock(
        State memory _state,
        uint48 _proposalId,
        address _proposer,
        bytes calldata _proverAuth,
        LibBonds.BondInstruction[] calldata _bondInstructions,
        bytes32 _expectedBondInstructionsHash
    )
        private
        returns (State memory)
    {
        uint256 proverFee;
        (_state.isLowBondProposal, _state.designatedProver, proverFee) =
            _getDesignatedProver(_proposalId, _proposer, _proverAuth, _state.designatedProver);

        if (proverFee > 0) {
            bondManager.debitBond(_proposer, proverFee);
            bondManager.creditBond(_state.designatedProver, proverFee);
        }

        _state.bondInstructionsHash = _processBondInstructions(
            _state.bondInstructionsHash, _bondInstructions, _expectedBondInstructionsHash
        );

        return _state;
    }

    /// @dev Anchors checkpoint data when a fresher L1 block is provided.
    /// @param _state Working state snapshot to mutate.
    /// @param _anchorBlockNumber L1 block number being anchored.
    /// @param _anchorBlockHash Hash of the referenced L1 block.
    /// @param _anchorStateRoot State root of the referenced L1 block.
    /// @return Updated state with the latest anchored block number.
    function _maybeAnchorCheckpoint(
        State memory _state,
        uint48 _anchorBlockNumber,
        bytes32 _anchorBlockHash,
        bytes32 _anchorStateRoot
    )
        private
        returns (State memory)
    {
        if (_anchorBlockNumber <= _state.anchorBlockNumber) {
            return _state;
        }

        checkpointStore.saveCheckpoint(
            ICheckpointStore.Checkpoint({
                blockNumber: _anchorBlockNumber,
                blockHash: _anchorBlockHash,
                stateRoot: _anchorStateRoot
            })
        );

        _state.anchorBlockNumber = _anchorBlockNumber;
        return _state;
    }

    /// @dev Calculates the aggregated ancestor block hash for the given block ID.
    /// @dev This function computes two public input hashes: one for the previous state and one for
    /// the new state.
    /// It uses a ring buffer to store the previous 255 block hashes and the current chain ID.
    /// @param _blockId The ID of the block for which the public input hash is calculated.
    /// @return oldAncestorsHash_ The public input hash for the previous state.
    /// @return newAncestorsHash_ The public input hash for the new state.
    function _calcAncestorsHash(uint256 _blockId)
        private
        view
        returns (bytes32 oldAncestorsHash_, bytes32 newAncestorsHash_)
    {
        // 255 bytes32 ring buffer + 1 bytes32 for chainId
        bytes32[256] memory inputs;
        inputs[255] = bytes32(block.chainid);

        // Unchecked is safe because it cannot overflow.
        unchecked {
            // Put the previous 255 blockhashes (excluding the parent's) into a
            // ring buffer.
            for (uint256 i; i < 255 && _blockId >= i + 1; ++i) {
                uint256 j = _blockId - i - 1;
                inputs[j % 255] = blockhash(j);
            }
        }

        assembly {
            oldAncestorsHash_ := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }

        inputs[_blockId % 255] = blockhash(_blockId);
        assembly {
            newAncestorsHash_ := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }
    }

    /// @dev Returns the designated prover with provided current designatedProver.
    /// @param _proposalId The proposal ID.
    /// @param _proposer The proposer address.
    /// @param _proverAuth Encoded prover authentication data.
    /// @param _currentDesignatedProver The current designated prover from state.
    /// @return isLowBondProposal_ True if proposer has insufficient bonds.
    /// @return designatedProver_ The designated prover address.
    /// @return provingFeeToTransfer_ The proving fee to transfer from the proposer to the
    /// designated prover.
    function _getDesignatedProver(
        uint48 _proposalId,
        address _proposer,
        bytes calldata _proverAuth,
        address _currentDesignatedProver
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
            designatedProver_ = _currentDesignatedProver;
        } else if (designatedProver_ != _proposer) {
            if (!bondManager.hasSufficientBond(designatedProver_, 0)) {
                // Fallback to proposer if designated prover has insufficient bonds
                designatedProver_ = _proposer;
            } else {
                provingFeeToTransfer_ = provingFee;
            }
        }
    }

    /// @dev Processes bond instructions with cumulative hash verification.
    /// @param _currentHash Current cumulative hash from storage.
    /// @param _bondInstructions Bond instructions to process.
    /// @param _expectedHash Expected cumulative hash after processing.
    /// @return newHash_ The new cumulative hash.
    function _processBondInstructions(
        bytes32 _currentHash,
        LibBonds.BondInstruction[] calldata _bondInstructions,
        bytes32 _expectedHash
    )
        private
        returns (bytes32 newHash_)
    {
        // Start with current cumulative hash
        newHash_ = _currentHash;

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
                bondManager.creditBond(instruction.payee, bondDebited);
            }

            // Update cumulative hash
            newHash_ = LibBonds.aggregateBondInstruction(newHash_, instruction);
        }

        // Verify hash integrity
        require(newHash_ == _expectedHash, BondInstructionsHashMismatch());
    }

    /// @dev Verifies the current ancestor block hash and updates it with a new aggregated hash.
    /// @param _parentId The ID of the parent block.
    /// @param _currentAncestorsHash The hash stored in contract state.
    /// @return newAncestorsHash_ The newly computed hash to persist.
    function _verifyAndUpdateAncestorsHash(
        uint256 _parentId,
        bytes32 _currentAncestorsHash
    )
        private
        view
        returns (bytes32 newAncestorsHash_)
    {
        (bytes32 oldAncestorsHash, bytes32 computedNewHash) = _calcAncestorsHash(_parentId);
        require(_currentAncestorsHash == oldAncestorsHash, L2_PUBLIC_INPUT_HASH_MISMATCH());
        return computedNewHash;
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
        // ABI-encoded ProverAuth: uint48 (32 padded) + address (32 padded) + uint48 (32 padded) +
        // bytes offset (32) + bytes length (32) + minimum signature data (65) = 225 bytes minimum
        if (_proverAuth.length < 225) {
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

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BondInstructionsHashMismatch();
    error InvalidAddress();
    error InvalidAnchorBlockNumber();
    error InvalidBlockIndex();
    error InvalidForkHeight();
    error InvalidL1ChainId();
    error InvalidL2ChainId();
    error InvalidSender();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error NonZeroAnchorBlockHash();
    error NonZeroAnchorStateRoot();
    error NonZeroBlockIndex();
    error ProposalIdMismatch();
    error ProposerMismatch();
    error ZeroBlockCount();
}
