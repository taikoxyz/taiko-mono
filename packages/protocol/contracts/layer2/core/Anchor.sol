// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

import "./Anchor_Layout.sol"; // DO NOT DELETE

/// @title Anchor
/// @notice Implements the Shasta fork's anchoring mechanism with prover designation and checkpoint
/// management.
/// @dev This contract implements:
///      - Prover designation with signature authentication
///      - State tracking for multi-block proposals
///      - Anchoring of L1 checkpoints for cross-chain verification
/// @custom:security-contact security@taiko.xyz
contract Anchor is EssentialContract {

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Stored anchor state for the latest processed block.
    /// @dev 2 slots
    struct AnchorState {
        uint48 lastProposalId;
        uint48 anchorBlockNumber;
        bytes32 ancestorsHash;
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

    /// @notice Checkpoint store for storing L1 block data.
    ICheckpointStore public immutable checkpointStore;

    /// @notice The L1's chain ID.
    uint64 public immutable l1ChainId;

    // ---------------------------------------------------------------
    // State variables
    // ---------------------------------------------------------------

    /// @notice Mapping from block number to block hash.
    mapping(uint256 blockNumber => bytes32 blockHash) public blockHashes;

    /// @dev Slots used by the Pacaya anchor contract itself.
    /// slot1: publicInputHash
    /// slot2: parentGasExcess, lastSyncedBlock, parentTimestamp, parentGasTarget
    /// slot3: l1ChainId
    uint256[3] private _pacayaSlots;

    /// @notice Latest anchor state, updated on every processed block.
    AnchorState internal _state;

    /// @notice Storage gap for upgrade safety.
    uint256[42] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event Anchored(
        uint48 indexed proposalId,
        bool indexed isNewProposal,
        uint48 prevAnchorBlockNumber,
        uint48 anchorBlockNumber,
        bytes32 ancestorsHash
    );

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------

    modifier onlyValidSender() {
        require(msg.sender == GOLDEN_TOUCH_ADDRESS, InvalidSender());
        _;
    }

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Anchor contract.
    /// @param _checkpointStore The address of the checkpoint store.
    /// @param _l1ChainId The L1 chain ID.
    constructor(ICheckpointStore _checkpointStore, uint64 _l1ChainId) {
        // Validate addresses
        require(address(_checkpointStore) != address(0), InvalidAddress());

        // Validate chain IDs
        require(_l1ChainId != 0 && _l1ChainId != block.chainid, InvalidL1ChainId());
        require(block.chainid > 1 && block.chainid <= type(uint64).max, InvalidL2ChainId());

        // Assign immutables
        checkpointStore = _checkpointStore;
        l1ChainId = _l1ChainId;
    }

    /// @notice Initializes the owner of the Anchor.
    /// @param _owner The owner of this contract
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Processes a block within a proposal and anchors L1 data.
    /// @dev Core function that processes blocks sequentially within a proposal:
    ///      1. Designates prover when a new proposal starts (i.e. the first block of a proposal)
    ///      2. Anchors L1 block data for cross-chain verification
    /// @param _proposalId Proposal ID for the current batch.
    /// @param _checkpoint Checkpoint data for the L1 block being anchored.
    function anchorV4(uint48 _proposalId, ICheckpointStore.Checkpoint calldata _checkpoint)
        external
        onlyValidSender
        nonReentrant
    {
        if (_proposalId < _state.lastProposalId) {
            // Proposal ID cannot go backward
            revert ProposalIdMismatch();
        }

        bool isNewProposal = _proposalId > _state.lastProposalId;
        // We do not need to account for proposalId = 0, since that's genesis
        if (isNewProposal) {
            _state.lastProposalId = _proposalId;
        }
        uint48 prevAnchorBlockNumber = _state.anchorBlockNumber;
        _validateBlock(_checkpoint);

        uint256 parentNumber = block.number - 1;
        blockHashes[parentNumber] = blockhash(parentNumber);

        emit Anchored(
            _state.lastProposalId,
            isNewProposal,
            prevAnchorBlockNumber,
            _state.anchorBlockNumber,
            _state.ancestorsHash
        );
    }

    // ---------------------------------------------------------------
    // Public View Functions
    // ---------------------------------------------------------------

    /// @notice Returns the current anchor state snapshot.
    function getState() external view returns (AnchorState memory) {
        return _state;
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Validates and processes block-level data.
    /// @param _checkpoint Anchor checkpoint data from L1.
    function _validateBlock(ICheckpointStore.Checkpoint calldata _checkpoint) private {
        // Verify and update ancestors hash
        (bytes32 oldAncestorsHash, bytes32 newAncestorsHash) = _calcAncestorsHash();
        if (_state.ancestorsHash != bytes32(0)) {
            require(_state.ancestorsHash == oldAncestorsHash, AncestorsHashMismatch());
        }
        _state.ancestorsHash = newAncestorsHash;

        // Anchor checkpoint data if a fresher L1 block is provided
        if (_checkpoint.blockNumber > _state.anchorBlockNumber) {
            checkpointStore.saveCheckpoint(_checkpoint);
            _state.anchorBlockNumber = _checkpoint.blockNumber;
        }
    }

    /// @dev Calculates the aggregated ancestor block hash for the current block's parent.
    /// @dev This function computes two public input hashes: one for the previous state and one for
    /// the new state.
    /// It uses a ring buffer to store the previous 255 block hashes and the current chain ID.
    /// @return oldAncestorsHash_ The public input hash for the previous state.
    /// @return newAncestorsHash_ The public input hash for the new state.
    function _calcAncestorsHash()
        private
        view
        returns (bytes32 oldAncestorsHash_, bytes32 newAncestorsHash_)
    {
        uint256 parentId = block.number - 1;

        // 255 bytes32 ring buffer + 1 bytes32 for chainId
        bytes32[256] memory inputs;
        inputs[255] = bytes32(block.chainid);

        // Unchecked is safe because it cannot overflow.
        unchecked {
            // Put the previous 255 blockhashes (excluding the parent's) into a
            // ring buffer.
            for (uint256 i; i < 255 && parentId >= i + 1; ++i) {
                uint256 j = parentId - i - 1;
                inputs[j % 255] = blockhash(j);
            }
        }

        assembly {
            oldAncestorsHash_ := keccak256(
                inputs,
                8192 /*mul(256, 32)*/
            )
        }

        inputs[parentId % 255] = blockhash(parentId);
        assembly {
            newAncestorsHash_ := keccak256(
                inputs,
                8192 /*mul(256, 32)*/
            )
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error AncestorsHashMismatch();
    error InvalidAddress();
    error InvalidL1ChainId();
    error InvalidL2ChainId();
    error InvalidSender();
    error ProposalIdMismatch();
}
