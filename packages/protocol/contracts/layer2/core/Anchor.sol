// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { RLPReader } from "@optimism/packages/contracts-bedrock/src/libraries/rlp/RLPReader.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

import "./Anchor_Layout.sol"; // DO NOT DELETE

/// @title Anchor
/// @notice Implements the Shasta fork's anchoring mechanism with checkpoint management, and the
/// Etna fork's permissionless checkpoint reveal.
/// @dev This contract implements:
///      - Anchoring of L1 checkpoints for cross-chain verification, before the Etna fork
///      - Revealing L1 checkpoints recorded by EIP-4788, from the Etna fork on
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

    /// @notice The canonical EIP-4788 beacon roots contract. From the Etna fork on, it records
    /// each L2 block's `parentBeaconBlockRoot`, which is the hash of the L1 block it anchors to.
    address public constant BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    // ---------------------------------------------------------------
    // Immutables
    // ---------------------------------------------------------------

    /// @notice Checkpoint store for storing L1 block data.
    ICheckpointStore public immutable checkpointStore;

    /// @notice The L1's chain ID.
    uint64 public immutable l1ChainId;

    /// @notice First L2 block timestamp at which the Etna fork is active.
    /// @dev `anchorV4` reverts from this timestamp on. 0 means Etna is active from genesis;
    /// `type(uint64).max` means Etna never activates.
    uint64 public immutable etnaTimestamp;

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
    uint256[43] private __gap;

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
    /// @param _etnaTimestamp First L2 block timestamp at which the Etna fork is active.
    constructor(ICheckpointStore _checkpointStore, uint64 _l1ChainId, uint64 _etnaTimestamp) {
        // Validate addresses
        require(address(_checkpointStore) != address(0), InvalidAddress());

        // Validate chain IDs
        require(_l1ChainId != 0 && _l1ChainId != block.chainid, InvalidL1ChainId());
        require(block.chainid > 1 && block.chainid <= type(uint64).max, InvalidL2ChainId());

        // Assign immutables
        checkpointStore = _checkpointStore;
        l1ChainId = _l1ChainId;
        etnaTimestamp = _etnaTimestamp;
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
    /// @dev Core function that anchors L1 block data for cross-chain verification. Reverts from
    /// `etnaTimestamp` on, where blocks no longer carry an anchor transaction.
    /// @param _checkpoint Checkpoint data for the L1 block being anchored.
    function anchorV4(ICheckpointStore.Checkpoint calldata _checkpoint)
        external
        onlyValidSender
        nonReentrant
    {
        require(block.timestamp < etnaTimestamp, AnchorDisabled());

        uint48 prevAnchorBlockNumber = _blockState.anchorBlockNumber;
        _validateBlock(_checkpoint);

        uint256 parentNumber = block.number - 1;
        blockHashes[parentNumber] = blockhash(parentNumber);

        emit Anchored(
            prevAnchorBlockNumber, _blockState.anchorBlockNumber, _blockState.ancestorsHash
        );
    }

    /// @notice Persists the L1 checkpoint whose block hash EIP-4788 recorded for an Etna L2 block.
    /// @dev Permissionless. From the Etna fork on, an L2 block's `parentBeaconBlockRoot` is the hash
    /// of the L1 block it anchors to, and EIP-4788 records it keyed by the L2 block's timestamp.
    /// The header is verified against that hash, so the state root and number read from it are
    /// authentic. An equal stored checkpoint makes this a no-op; a different one reverts.
    /// @param _l2Timestamp Timestamp of the L2 block whose `parentBeaconBlockRoot` is the L1 block
    /// hash.
    /// @param _headerRlp RLP encoding of that L1 block header.
    /// @return checkpoint_ The checkpoint, whether newly saved or already stored.
    function revealCheckpoint(
        uint64 _l2Timestamp,
        bytes calldata _headerRlp
    )
        external
        returns (ICheckpointStore.Checkpoint memory checkpoint_)
    {
        // The EIP-4788 getter takes the raw 32-byte timestamp, without a selector. It returns
        // nothing while the contract has no code, and reverts for a timestamp it does not hold.
        (bool ok, bytes memory ret) = BEACON_ROOTS.staticcall(abi.encode(uint256(_l2Timestamp)));
        require(ok && ret.length == 32, L1BlockHashNotFound());
        bytes32 blockHash = abi.decode(ret, (bytes32));
        // Pre-Etna blocks record a zero root.
        require(blockHash != bytes32(0), L1BlockHashNotFound());

        require(keccak256(_headerRlp) == blockHash, InvalidL1Header());

        // The hash binds the bytes to the real, canonically encoded header, so only the lengths
        // that make the conversions below safe are checked.
        RLPReader.RLPItem[] memory fields = RLPReader.readList(_headerRlp);
        require(fields.length > 8, InvalidL1Header());
        bytes memory stateRoot = RLPReader.readBytes(fields[3]);
        bytes memory number = RLPReader.readBytes(fields[8]);
        require(stateRoot.length == 32 && number.length <= 6, InvalidL1Header());

        checkpoint_ = ICheckpointStore.Checkpoint({
            blockNumber: uint48(_toUint(number)),
            blockHash: blockHash,
            stateRoot: bytes32(stateRoot)
        });

        // A checkpoint exists when its block hash is non-zero. Never overwrite one.
        try checkpointStore.getCheckpoint(checkpoint_.blockNumber) returns (
            ICheckpointStore.Checkpoint memory existing
        ) {
            if (existing.blockHash != bytes32(0)) {
                require(
                    existing.blockHash == blockHash && existing.stateRoot == checkpoint_.stateRoot,
                    CheckpointConflict()
                );
                return checkpoint_;
            }
        } catch { }

        checkpointStore.saveCheckpoint(checkpoint_);
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

    /// @dev Folds big-endian bytes into an unsigned integer.
    /// @param _bytes At most 32 big-endian bytes.
    /// @return value_ The integer value; 0 for empty bytes.
    function _toUint(bytes memory _bytes) private pure returns (uint256 value_) {
        for (uint256 i; i < _bytes.length; ++i) {
            value_ = (value_ << 8) | uint8(_bytes[i]);
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error AncestorsHashMismatch();
    error AnchorDisabled();
    error CheckpointConflict();
    error InvalidAddress();
    error InvalidL1ChainId();
    error InvalidL1Header();
    error InvalidL2ChainId();
    error InvalidSender();
    error L1BlockHashNotFound();
}
