// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

import "./Anchor_Layout.sol"; // DO NOT DELETE

/// @title Anchor
/// @notice Implements the Shasta fork's anchoring mechanism with checkpoint management.
/// @dev This contract implements:
///      - Anchoring of L1 checkpoints for cross-chain verification
/// @custom:security-contact security@taiko.xyz
contract Anchor is EssentialContract {
    using LibAddress for address;
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Stored block-level state for the latest anchor.
    /// @dev 2 slots
    struct BlockState {
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

    /// @dev Deprecated. Retained for storage layout compatibility.
    uint48 private _lastProposalId;

    /// @notice Latest block-level state, updated on every processed block.
    BlockState internal _blockState;

    /// @notice Storage gap for upgrade safety.
    uint256[41] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event Anchored(uint48 prevAnchorBlockNumber, uint48 anchorBlockNumber, bytes32 ancestorsHash);

    event Withdrawn(address token, address to, uint256 amount);

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

    /// @notice Processes a block and anchors L1 data.
    /// @dev Core function that anchors L1 block data for cross-chain verification.
    /// @param _checkpoint Checkpoint data for the L1 block being anchored.
    function anchorV4(ICheckpointStore.Checkpoint calldata _checkpoint)
        external
        onlyValidSender
        nonReentrant
    {
        uint48 prevAnchorBlockNumber = _blockState.anchorBlockNumber;
        _validateBlock(_checkpoint);

        uint256 parentNumber = block.number - 1;
        blockHashes[parentNumber] = blockhash(parentNumber);

        emit Anchored(
            prevAnchorBlockNumber, _blockState.anchorBlockNumber, _blockState.ancestorsHash
        );
    }

    /// @notice Withdraw token or Ether from this address.
    /// Note: This contract receives a portion of L2 base fees, while the remainder is directed to
    /// L2 block's coinbase address.
    /// @param _token Token address or address(0) if Ether.
    /// @param _to Withdraw to address.
    function withdraw(address _token, address _to) external onlyOwner nonReentrant {
        require(_to != address(0), InvalidAddress());
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

    /// @notice Returns the current block-level state snapshot.
    function getBlockState() external view returns (BlockState memory) {
        return _blockState;
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Validates and processes block-level data.
    /// @param _checkpoint Anchor checkpoint data from L1.
    function _validateBlock(ICheckpointStore.Checkpoint calldata _checkpoint) private {
        // Verify and update ancestors hash
        (bytes32 oldAncestorsHash, bytes32 newAncestorsHash) = _calcAncestorsHash();
        if (_blockState.ancestorsHash != bytes32(0)) {
            require(_blockState.ancestorsHash == oldAncestorsHash, AncestorsHashMismatch());
        }
        _blockState.ancestorsHash = newAncestorsHash;

        // Anchor checkpoint data if a fresher L1 block is provided
        if (_checkpoint.blockNumber > _blockState.anchorBlockNumber) {
            checkpointStore.saveCheckpoint(_checkpoint);
            _blockState.anchorBlockNumber = _checkpoint.blockNumber;
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
}
