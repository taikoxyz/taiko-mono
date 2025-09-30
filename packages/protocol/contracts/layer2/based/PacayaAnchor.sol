// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/layer2/based/libs/LibEIP1559.sol";
import "src/layer2/based/OntakeAnchor.sol";

/// @title PacayaAnchor
/// @notice Anchoring functions for the Pacaya fork.
/// @custom:deprecated This contract is deprecated and should not be used in new implementations
/// @custom:security-contact security@taiko.xyz
abstract contract PacayaAnchor is OntakeAnchor {
    using LibAddress for address;
    using LibMath for uint256;
    using SafeERC20 for IERC20;

    event Withdrawn(address token, address to, uint256 amount);

    /// @notice Golden touch address is the only address that can do the anchor transaction.
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;
    uint256 public constant BASEFEE_MIN_VALUE = 25_000_000; //  0.025 gwei

    ISignalService public immutable signalService;
    uint64 public immutable pacayaForkHeight;
    uint64 public immutable shastaForkHeight;

    /// @notice Mapping from L2 block numbers to their block hashes. All L2 block hashes will
    /// be saved in this mapping.
    mapping(uint256 blockId => bytes32 blockHash) internal _blockhashes;

    /// @notice A hash to check the integrity of public inputs.
    /// @dev Slot 2.
    bytes32 public publicInputHash;

    /// @notice The gas excess value used to calculate the base fee.
    /// @dev Slot 3.
    uint64 public parentGasExcess;

    /// @notice The last synced L1 block height.
    uint64 public lastCheckpoint;

    /// @notice The last L2 block's timestamp.
    uint64 public parentTimestamp;

    /// @notice The last L2 block's gas target.
    uint64 public parentGasTarget;

    /// @notice The L1's chain ID.
    /// @dev Slot 4.
    uint64 public l1ChainId;
    uint32 public lastAnchorGasUsed;

    uint256[46] private __gap;

    /// @notice Emitted when the latest L1 block details are anchored to L2.
    /// @param parentHash The hash of the parent block.
    /// @param parentGasExcess The gas excess value used to calculate the base fee.
    event Anchored(bytes32 parentHash, uint64 parentGasExcess);

    /// @notice Emitted when the gas target has been updated.
    /// @param oldGasTarget The previous gas target.
    /// @param newGasTarget The new gas target.
    /// @param oldGasExcess The previous gas excess.
    /// @param newGasExcess The new gas excess.
    /// @param basefee The base fee in this block.
    event EIP1559Update(
        uint64 oldGasTarget,
        uint64 newGasTarget,
        uint64 oldGasExcess,
        uint64 newGasExcess,
        uint256 basefee
    );

    error SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED();
    error L2_BASEFEE_MISMATCH();
    error L2_FORK_ERROR();
    error L2_INVALID_L1_CHAIN_ID();
    error L2_INVALID_L2_CHAIN_ID();
    error L2_INVALID_SENDER();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error L2_TOO_LATE();

    modifier onlyGoldenTouch() {
        require(msg.sender == GOLDEN_TOUCH_ADDRESS, L2_INVALID_SENDER());
        _;
    }

    constructor(address _signalService, uint64 _pacayaForkHeight, uint64 _shastaForkHeight) {
        signalService = ISignalService(_signalService);
        pacayaForkHeight = _pacayaForkHeight;
        shastaForkHeight = _shastaForkHeight;
    }

    /// @notice Anchors the latest L1 block details to L2 for cross-layer
    /// message verification.
    /// @dev The gas limit for this transaction must be set to 1,000,000 gas.
    /// @dev This function can be called freely as the golden touch private key is publicly known,
    /// but the Taiko node guarantees the first transaction of each block is always this anchor
    /// transaction, and any subsequent calls will revert with L2_PUBLIC_INPUT_HASH_MISMATCH.
    /// @param _anchorBlockId The `anchorBlockId` value in this block's metadata.
    /// @param _anchorStateRoot The state root for the L1 block with id equals `_anchorBlockId`.
    /// @param _parentGasUsed The gas used in the parent block.
    /// @param _baseFeeConfig The base fee configuration.
    /// @param _signalSlots The signal slots to mark as received.
    function anchorV3(
        uint64 _anchorBlockId,
        bytes32 _anchorStateRoot,
        uint32 _parentGasUsed,
        BaseFeeConfig calldata _baseFeeConfig,
        bytes32[] calldata _signalSlots
    )
        external
        nonZeroBytes32(_anchorStateRoot)
        nonZeroValue(_anchorBlockId)
        nonZeroValue(_baseFeeConfig.gasIssuancePerSecond)
        nonZeroValue(_baseFeeConfig.adjustmentQuotient)
        onlyGoldenTouch
        nonReentrant
    {
        require(_signalSlots.length == 0, SAME_SLOT_SIGNALS_NO_LONG_SUPPORTED());
        require(block.number >= pacayaForkHeight, L2_FORK_ERROR());
        require(shastaForkHeight == 0 || block.number < shastaForkHeight, L2_FORK_ERROR());

        uint256 parentId = block.number - 1;
        _verifyAndUpdatePublicInputHash(parentId);
        _verifyBaseFeeAndUpdateGasExcess(_parentGasUsed, _baseFeeConfig);
        _syncChainData(_anchorBlockId, _anchorStateRoot);
        _updateParentHashAndTimestamp(parentId);

        // signalService.receiveSignals(_signalSlots);
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
        whenNotPaused
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

    /// @notice Calculates the base fee and gas excess using EIP-1559 configuration for the given
    /// parameters.
    /// @param _parentGasUsed Gas used in the parent block.
    /// @param _baseFeeConfig Configuration parameters for base fee calculation.
    /// @return basefee_ The calculated EIP-1559 base fee per gas.
    /// @return newGasTarget_ The new gas target value.
    /// @return newGasExcess_ The new gas excess value.
    function getBasefeeV2(
        uint32 _parentGasUsed,
        uint64 _blockTimestamp,
        BaseFeeConfig calldata _baseFeeConfig
    )
        public
        view
        returns (uint256 basefee_, uint64 newGasTarget_, uint64 newGasExcess_)
    {
        // uint32 * uint8 will never overflow
        uint64 newGasTarget =
            uint64(_baseFeeConfig.gasIssuancePerSecond) * _baseFeeConfig.adjustmentQuotient;

        (newGasTarget_, newGasExcess_) =
            LibEIP1559.adjustExcess(parentGasTarget, newGasTarget, parentGasExcess);

        uint64 gasIssuance =
            (_blockTimestamp - parentTimestamp) * _baseFeeConfig.gasIssuancePerSecond;

        if (
            _baseFeeConfig.maxGasIssuancePerBlock != 0
                && gasIssuance > _baseFeeConfig.maxGasIssuancePerBlock
        ) {
            gasIssuance = _baseFeeConfig.maxGasIssuancePerBlock;
        }

        (basefee_, newGasExcess_) = LibEIP1559.calc1559BaseFee(
            newGasTarget_, newGasExcess_, gasIssuance, _parentGasUsed, _baseFeeConfig.minGasExcess
        );

        if (basefee_ < BASEFEE_MIN_VALUE) {
            basefee_ = BASEFEE_MIN_VALUE;
        }
    }

    /// @inheritdoc IBlockHashProvider
    function getBlockHash(uint256 _blockId) public view returns (bytes32 blockHash_) {
        if (_blockId >= block.number) return 0;
        if (_blockId + 256 >= block.number) return blockhash(_blockId);
        blockHash_ = _blockhashes[_blockId];
    }

    /// @notice Tells if we need to validate basefee (for simulation).
    /// @return skipCheck_ Returns true to skip checking basefee mismatch.
    function skipFeeCheck() public pure virtual returns (bool skipCheck_) {
        return false;
    }

    // -------------------------------------------------------------------
    // Internal functions
    // -------------------------------------------------------------------

    /// @dev Synchronizes chain data with the given anchor block ID and state root.
    /// @param _anchorBlockId The ID of the anchor block.
    /// @param _anchorStateRoot The state root of the anchor block.
    function _syncChainData(uint64 _anchorBlockId, bytes32 _anchorStateRoot) internal {
        /// @dev If the anchor block ID is less than or equal to the last checkpoint, return
        /// early.
        if (_anchorBlockId <= lastCheckpoint) return;

        /// @dev Store the L1's state root as a signal to the local signal service to
        /// allow for multi-hop bridging.
        signalService.syncChainData(
            l1ChainId, LibSignals.STATE_ROOT, _anchorBlockId, _anchorStateRoot
        );

        /// @dev Update the last checkpoint to the current anchor block ID.
        lastCheckpoint = _anchorBlockId;
    }

    /// @dev Updates the parent block hash and timestamp.
    /// @param _parentId The ID of the parent block.
    function _updateParentHashAndTimestamp(uint256 _parentId) internal {
        // Get the block hash of the parent block.
        bytes32 parentHash = blockhash(_parentId);

        // Store the parent block hash in the _blockhashes mapping.
        _blockhashes[_parentId] = parentHash;

        // Update the parent timestamp to the current block timestamp.
        parentTimestamp = uint64(block.timestamp);

        // Emit an event to signal that the parent hash and gas excess have been anchored.
        emit Anchored(parentHash, parentGasExcess);
    }

    /// @dev Verifies the current ancestor block hash and updates it with a new aggregated hash.
    /// @param _parentId The ID of the parent block.
    function _verifyAndUpdatePublicInputHash(uint256 _parentId) internal {
        // Calculate the current and new ancestor hashes based on the parent block ID.
        (bytes32 currPublicInputHash_, bytes32 newPublicInputHash_) =
            _calcPublicInputHash(_parentId);

        // Ensure the current ancestor block hash matches the expected value.
        require(publicInputHash == currPublicInputHash_, L2_PUBLIC_INPUT_HASH_MISMATCH());

        // Update the ancestor block hash to the new calculated value.
        publicInputHash = newPublicInputHash_;
    }

    /// @dev Verifies that the base fee per gas is correct and updates the gas excess.
    /// @param _parentGasUsed The gas used by the parent block.
    /// @param _baseFeeConfig The configuration parameters for calculating the base fee.
    function _verifyBaseFeeAndUpdateGasExcess(
        uint32 _parentGasUsed,
        BaseFeeConfig calldata _baseFeeConfig
    )
        internal
    {
        (uint256 basefee, uint64 newGasTarget, uint64 newGasExcess) =
            getBasefeeV2(_parentGasUsed, uint64(block.timestamp), _baseFeeConfig);

        require(block.basefee == basefee || skipFeeCheck(), L2_BASEFEE_MISMATCH());

        emit EIP1559Update(parentGasTarget, newGasTarget, parentGasExcess, newGasExcess, basefee);

        // Record telemetry for the last observed parent gas used value.
        lastAnchorGasUsed = _parentGasUsed;

        parentGasTarget = newGasTarget;
        parentGasExcess = newGasExcess;
    }

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
}
