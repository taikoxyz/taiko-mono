// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibAddress.sol";
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
        bytes32 publicInputHash;
        bytes32 bondInstructionsHash;
        address designatedProver;
        uint48 anchorBlockNumber;
        uint48 endOfSubmissionWindowTimestamp;
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

    /// @notice Bond amount in Gwei for liveness guarantees.
    uint48 public immutable livenessBondGwei;

    /// @notice Bond amount in Gwei for provability guarantees.
    uint48 public immutable provabilityBondGwei;

    /// @notice Contract managing bond deposits, withdrawals, and transfers.
    IBondManager public immutable bondManager;

    /// @notice Checkpoint store for storing L1 block data.
    ICheckpointStore public immutable checkpointStore;

    /// @notice Block height at which the Pacaya fork is activated.
    uint64 public immutable pacayaForkHeight;

    /// @notice Block height at which the Shasta fork is activated.
    uint64 public immutable shastaForkHeight;

    /// @notice The L1's chain ID.
    uint64 public immutable l1ChainId;

    // ---------------------------------------------------------------
    // State variables
    // ---------------------------------------------------------------

    mapping(uint256 blockId => uint256 endOfSubmissionWindowTimestamp) public
        blockIdToEndOfSubmissionWindowTimeStamp;

    /// @notice A hash to check the integrity of public inputs.
    bytes32 public publicInputHash;

    /// @notice Latest known bond instructions hash.
    bytes32 public bondInstructionsHash;

    /// @notice The designated prover for the current batch.
    /// @dev Packed in slot with anchorBlockNumber and endOfSubmissionWindowTimestamp.
    address public designatedProver;

    /// @notice Latest L1 block number anchored to L2.
    uint48 public anchorBlockNumber;

    /// @notice The timestamp of the last slot where the current preconfer can propose.
    uint48 public endOfSubmissionWindowTimestamp;

    /// @notice Indicates if the proposal has insufficient bonds.
    bool public isLowBondProposal;

    /// @notice Storage gap for upgrade safety.
    uint256[44] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event Anchored(
        bytes32 publicInputHash,
        bytes32 bondInstructionsHash,
        address designatedProver,
        uint48 anchorBlockNumber,
        uint48 endOfSubmissionWindowTimestamp,
        bool isLowBondProposal
    );

    event Withdrawn(address token, address to, uint256 amount);

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------

    modifier onlyGoldenTouch() {
        require(msg.sender == GOLDEN_TOUCH_ADDRESS, InvalidSender());
        _;
    }

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Anchor contract.
    /// @param _livenessBondGwei The liveness bond amount in Gwei.
    /// @param _provabilityBondGwei The provability bond amount in Gwei.
    /// @param _checkpointStore The address of the checkpoint store.
    /// @param _pacayaForkHeight The block height at which the Pacaya fork is activated.
    /// @param _shastaForkHeight The block height at which the Shasta fork is activated.
    /// @param _bondManager The address of the bond manager.
    /// @param _l1ChainId The L1 chain ID.
    constructor(
        uint48 _livenessBondGwei,
        uint48 _provabilityBondGwei,
        address _checkpointStore,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight,
        IBondManager _bondManager,
        uint64 _l1ChainId
    ) {
        require(
            _shastaForkHeight == 0 || _shastaForkHeight > _pacayaForkHeight, InvalidForkHeight()
        );
        require(_l1ChainId != 0, InvalidL1ChainId());
        require(_l1ChainId != block.chainid, InvalidL1ChainId());

        require(block.chainid > 1, InvalidL2ChainId());
        require(block.chainid <= type(uint64).max, InvalidL2ChainId());

        livenessBondGwei = _livenessBondGwei;
        provabilityBondGwei = _provabilityBondGwei;
        bondManager = _bondManager;
        checkpointStore = ICheckpointStore(_checkpointStore);
        pacayaForkHeight = _pacayaForkHeight;
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
        (publicInputHash,) = _calcPublicInputHash(block.number);
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
    /// @param _endOfSubmissionWindowTimestamp The timestamp of the last slot where the current
    /// preconfer can propose.
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
        bytes32 _anchorStateRoot,
        uint48 _endOfSubmissionWindowTimestamp
    )
        external
        onlyGoldenTouch
        nonReentrant
    {
        // ============================================================
        // PHASE 1: READ - Load current state into memory
        // ============================================================
        State memory state = State({
            publicInputHash: publicInputHash,
            bondInstructionsHash: bondInstructionsHash,
            designatedProver: designatedProver,
            anchorBlockNumber: anchorBlockNumber,
            endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
            isLowBondProposal: isLowBondProposal
        });

        // ============================================================
        // PHASE 2: VALIDATE & COMPUTE - All validation and computation
        // ============================================================

        // Fork validation
        require(block.number >= shastaForkHeight, ForkError());

        // Handle prover designation on first block
        if (_blockIndex == 0) {
            uint256 _proverFee;
            (state.isLowBondProposal, state.designatedProver, _proverFee) =
                _getDesignatedProver(_proposalId, _proposer, _proverAuth, state.designatedProver);

            if (_proverFee > 0) {
                bondManager.debitBond(_proposer, _proverFee);
                bondManager.creditBond(state.designatedProver, _proverFee);
            }

            // Process bond instructions with hash verification
            state.bondInstructionsHash =
                _processBondInstructions(_bondInstructions, _bondInstructionsHash);
        }

        // Process new L1 anchor data
        if (_anchorBlockNumber > state.anchorBlockNumber) {
            // Save L1 block data to checkpoint store (external call before state write)
            checkpointStore.saveCheckpoint(
                ICheckpointStore.Checkpoint({
                    blockNumber: _anchorBlockNumber,
                    blockHash: _anchorBlockHash,
                    stateRoot: _anchorStateRoot
                })
            );

            state.anchorBlockNumber = _anchorBlockNumber;
        }

        // Update submission window timestamp
        state.endOfSubmissionWindowTimestamp = _endOfSubmissionWindowTimestamp;

        // ============================================================
        // PHASE 3: WRITE - Write all state to storage atomically
        // ============================================================
        publicInputHash = state.publicInputHash;
        bondInstructionsHash = state.bondInstructionsHash;
        designatedProver = state.designatedProver;
        anchorBlockNumber = state.anchorBlockNumber;
        endOfSubmissionWindowTimestamp = state.endOfSubmissionWindowTimestamp;
        isLowBondProposal = state.isLowBondProposal;

        // Update mapping separately
        blockIdToEndOfSubmissionWindowTimeStamp[block.number] = state.endOfSubmissionWindowTimestamp;

        // ============================================================
        // PHASE 4: EMIT - Emit event with final state
        // ============================================================
        emit Anchored(
            state.publicInputHash,
            state.bondInstructionsHash,
            state.designatedProver,
            state.anchorBlockNumber,
            state.endOfSubmissionWindowTimestamp,
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
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Calculates the aggregated ancestor block hash for the given block ID.
    /// @dev This function computes two public input hashes: one for the previous state and one for
    /// the new state.
    /// It uses a ring buffer to store the previous 255 block hashes and the current chain ID.
    /// @param _blockId The ID of the block for which the public input hash is calculated.
    /// @return currPublicInputHash_ The public input hash for the previous state.
    /// @return newPublicInputHash_ The public input hash for the new state.
    function _calcPublicInputHash(uint256 _blockId)
        internal
        view
        returns (bytes32 currPublicInputHash_, bytes32 newPublicInputHash_)
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
            currPublicInputHash_ := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }

        inputs[_blockId % 255] = blockhash(_blockId);
        assembly {
            newPublicInputHash_ := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

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
        newHash_ = bondInstructionsHash;

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
    error ForkError();
    error InvalidAnchorBlockNumber();
    error InvalidBlockIndex();
    error InvalidForkHeight();
    error InvalidL1ChainId();
    error InvalidL2ChainId();
    error InvalidSender();
    error NonZeroAnchorBlockHash();
    error NonZeroAnchorStateRoot();
    error NonZeroBlockIndex();
    error ProposalIdMismatch();
    error ProposerMismatch();
    error PublicInputHashMismatch();
    error ZeroBlockCount();
}
