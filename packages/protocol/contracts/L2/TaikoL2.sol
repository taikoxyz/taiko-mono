// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../libs/LibAddress.sol";
import "../libs/LibMath.sol";
import "../signal/ISignalService.sol";
import "../signal/LibSignals.sol";
import "./Lib1559Math.sol";
import "./CrossChainOwned.sol";

/// @title TaikoL2
/// @notice Taiko L2 is a smart contract that handles cross-layer message
/// verification and manages EIP-1559 gas pricing for Layer 2 (L2) operations.
/// It is used to anchor the latest L1 block details to L2 for cross-layer
/// communication, manage EIP-1559 parameters for gas pricing, and store
/// verified L1 block information.
/// @custom:security-contact security@taiko.xyz
contract TaikoL2 is CrossChainOwned {
    using LibAddress for address;
    using LibMath for uint256;
    using SafeERC20 for IERC20;

    struct Config {
        uint32 gasTargetPerL1Block;
        uint8 basefeeAdjustmentQuotient;
    }

    /// @notice Golden touch address is the only address that can do the anchor transaction.
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;

    /// @notice The number of L2 blocks to wait before syncing L1 block details.
    uint8 public constant BLOCK_SYNC_THRESHOLD = 5;

    /// @notice Mapping from L2 block numbers to their block hashes. All L2 block hashes will
    /// be saved in this mapping.
    mapping(uint256 blockId => bytes32 blockHash) public l2Hashes;

    /// @notice A hash to check the integrity of public inputs.
    /// @dev Slot 2.
    bytes32 public publicInputHash;

    /// @notice The gas excess value used to calculate the base fee.
    /// @dev Slot 3.
    uint64 public gasExcess;

    /// @notice The last synced L1 block height.
    uint64 public lastSyncedBlock;

    uint256[47] private __gap;

    /// @notice Emitted when the latest L1 block details are anchored to L2.
    /// @param parentHash The hash of the parent block.
    /// @param gasExcess The gas excess value used to calculate the base fee.
    event Anchored(bytes32 parentHash, uint64 gasExcess);

    error L2_BASEFEE_MISMATCH();
    error L2_INVALID_CHAIN_ID();
    error L2_INVALID_PARAM();
    error L2_INVALID_SENDER();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error L2_TOO_LATE();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _l1ChainId The ID of the base layer.
    /// @param _gasExcess The initial gasExcess.
    function init(
        address _owner,
        address _addressManager,
        uint64 _l1ChainId,
        uint64 _gasExcess
    )
        external
        initializer
    {
        __CrossChainOwned_init(_owner, _addressManager, _l1ChainId);

        if (block.chainid <= 1 || block.chainid > type(uint64).max) {
            revert L2_INVALID_CHAIN_ID();
        }

        if (block.number == 0) {
            // This is the case in real L2 genesis
        } else if (block.number == 1) {
            // This is the case in tests
            uint256 parentHeight = block.number - 1;
            l2Hashes[parentHeight] = blockhash(parentHeight);
        } else {
            revert L2_TOO_LATE();
        }

        gasExcess = _gasExcess;
        (publicInputHash,) = _calcPublicInputHash(block.number);
    }

    /// @notice Anchors the latest L1 block details to L2 for cross-layer
    /// message verification.
    /// @param _l1BlockHash The latest L1 block hash when this block was
    /// proposed.
    /// @param _l1StateRoot The latest L1 block's state root.
    /// @param _l1BlockId The latest L1 block height when this block was proposed.
    /// @param _parentGasUsed The gas used in the parent block.
    function anchor(
        bytes32 _l1BlockHash,
        bytes32 _l1StateRoot,
        uint64 _l1BlockId,
        uint32 _parentGasUsed
    )
        external
        nonReentrant
    {
        if (
            _l1BlockHash == 0 || _l1StateRoot == 0 || _l1BlockId == 0
                || (block.number != 1 && _parentGasUsed == 0)
        ) {
            revert L2_INVALID_PARAM();
        }

        if (msg.sender != GOLDEN_TOUCH_ADDRESS) revert L2_INVALID_SENDER();

        uint256 parentId;
        unchecked {
            parentId = block.number - 1;
        }

        // Verify ancestor hashes
        (bytes32 publicInputHashOld, bytes32 publicInputHashNew) = _calcPublicInputHash(parentId);
        if (publicInputHash != publicInputHashOld) {
            revert L2_PUBLIC_INPUT_HASH_MISMATCH();
        }

        Config memory config = getConfig();

        // Verify the base fee per gas is correct
        uint256 basefee;
        (basefee, gasExcess) = _calc1559BaseFee(config, _l1BlockId, _parentGasUsed);
        if (!skipFeeCheck() && block.basefee != basefee) {
            revert L2_BASEFEE_MISMATCH();
        }

        if (_l1BlockId > lastSyncedBlock + BLOCK_SYNC_THRESHOLD) {
            // Store the L1's state root as a signal to the local signal service to
            // allow for multi-hop bridging.
            ISignalService(resolve("signal_service", false)).syncChainData(
                ownerChainId, LibSignals.STATE_ROOT, _l1BlockId, _l1StateRoot
            );
            lastSyncedBlock = _l1BlockId;
        }
        // Update state variables
        l2Hashes[parentId] = blockhash(parentId);
        publicInputHash = publicInputHashNew;

        emit Anchored(blockhash(parentId), gasExcess);
    }

    /// @notice Withdraw token or Ether from this address
    /// @param _token Token address or address(0) if Ether.
    /// @param _to Withdraw to address.
    function withdraw(
        address _token,
        address _to
    )
        external
        onlyFromOwnerOrNamed("withdrawer")
        nonReentrant
        whenNotPaused
    {
        if (_to == address(0)) revert L2_INVALID_PARAM();
        if (_token == address(0)) {
            _to.sendEther(address(this).balance);
        } else {
            IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));
        }
    }

    /// @notice Gets the basefee and gas excess using EIP-1559 configuration for
    /// the given parameters.
    /// @param _l1BlockId The synced L1 height in the next Taiko block
    /// @param _parentGasUsed Gas used in the parent block.
    /// @return basefee_ The calculated EIP-1559 base fee per gas.
    function getBasefee(
        uint64 _l1BlockId,
        uint32 _parentGasUsed
    )
        public
        view
        returns (uint256 basefee_)
    {
        (basefee_,) = _calc1559BaseFee(getConfig(), _l1BlockId, _parentGasUsed);
    }

    /// @notice Retrieves the block hash for the given L2 block number.
    /// @param _blockId The L2 block number to retrieve the block hash for.
    /// @return The block hash for the specified L2 block id, or zero if the
    /// block id is greater than or equal to the current block number.
    function getBlockHash(uint64 _blockId) public view returns (bytes32) {
        if (_blockId >= block.number) return 0;
        if (_blockId + 256 >= block.number) return blockhash(_blockId);
        return l2Hashes[_blockId];
    }

    /// @notice Returns EIP1559 related configurations.
    /// @return config_ struct containing configuration parameters.
    function getConfig() public view virtual returns (Config memory config_) {
        // 4x Ethereum gas target, if we assume most of the time, L2 block time
        // is 3s, and each block is full (gasUsed is 15_000_000), then its
        // ~60_000_000, if the  network is congester than that, the base fee
        // will increase.
        config_.gasTargetPerL1Block = 15 * 1e6 * 4;
        config_.basefeeAdjustmentQuotient = 8;
    }

    /// @notice Tells if we need to validate basefee (for simulation).
    /// @return Returns true to skip checking basefee mismatch.
    function skipFeeCheck() public pure virtual returns (bool) {
        return false;
    }

    function _calcPublicInputHash(uint256 _blockId)
        private
        view
        returns (bytes32 publicInputHashOld, bytes32 publicInputHashNew)
    {
        bytes32[256] memory inputs;

        // Unchecked is safe because it cannot overflow.
        unchecked {
            // Put the previous 255 blockhashes (excluding the parent's) into a
            // ring buffer.
            for (uint256 i; i < 255 && _blockId >= i + 1; ++i) {
                uint256 j = _blockId - i - 1;
                inputs[j % 255] = blockhash(j);
            }
        }

        inputs[255] = bytes32(block.chainid);

        assembly {
            publicInputHashOld := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }

        inputs[_blockId % 255] = blockhash(_blockId);
        assembly {
            publicInputHashNew := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }
    }

    function _calc1559BaseFee(
        Config memory _config,
        uint64 _l1BlockId,
        uint32 _parentGasUsed
    )
        private
        view
        returns (uint256 basefee_, uint64 gasExcess_)
    {
        // gasExcess being 0 indicate the dynamic 1559 base fee is disabled.
        if (gasExcess > 0) {
            // We always add the gas used by parent block to the gas excess
            // value as this has already happened
            uint256 excess = uint256(gasExcess) + _parentGasUsed;

            // Calculate how much more gas to issue to offset gas excess.
            // after each L1 block time, config.gasTarget more gas is issued,
            // the gas excess will be reduced accordingly.
            // Note that when lastSyncedBlock is zero, we skip this step
            // because that means this is the first time calculating the basefee
            // and the difference between the L1 height would be extremely big,
            // reverting the initial gas excess value back to 0.
            uint256 numL1Blocks;
            if (lastSyncedBlock > 0 && _l1BlockId > lastSyncedBlock) {
                numL1Blocks = _l1BlockId - lastSyncedBlock;
            }

            if (numL1Blocks > 0) {
                uint256 issuance = numL1Blocks * _config.gasTargetPerL1Block;
                excess = excess > issuance ? excess - issuance : 1;
            }

            gasExcess_ = uint64(excess.min(type(uint64).max));

            // The base fee per gas used by this block is the spot price at the
            // bonding curve, regardless the actual amount of gas used by this
            // block, however, this block's gas used will affect the next
            // block's base fee.
            basefee_ = Lib1559Math.basefee(
                gasExcess_, uint256(_config.basefeeAdjustmentQuotient) * _config.gasTargetPerL1Block
            );
        }

        // Always make sure basefee is nonzero, this is required by the node.
        if (basefee_ == 0) basefee_ = 1;
    }
}
