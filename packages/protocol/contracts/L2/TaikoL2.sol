// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../libs/LibAddress.sol";
import "../signal/ISignalService.sol";
import "./Lib1559Math.sol";

/// @title TaikoL2
/// @notice Taiko L2 is a smart contract that handles cross-layer message
/// verification and manages EIP-1559 gas pricing for Layer 2 (L2) operations.
/// It is used to anchor the latest L1 block details to L2 for cross-layer
/// communication, manage EIP-1559 parameters for gas pricing, and store
/// verified L1 block information.
/// @custom:security-contact security@taiko.xyz
contract TaikoL2 is EssentialContract {
    using LibAddress for address;
    using SafeERC20 for IERC20;

    /// @notice Golden touch address is the only address that can do the anchor transaction.
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;

    /// @notice The average gas used for proposing, proving, and verifying one single L2 block
    /// on L1.  The current value is ~450_000 gas, but we use 225000 here for now to only cover 50%
    /// of the L1 fees.
    uint256 public constant BLOCK_GAS_COST_ON_L1 = 225_000;

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

    uint64 public avgBlockGasUsed; // was parentTimestamp
    uint64 private __deprecated2; // was __currentBlockTimestamp

    /// @notice The L1's chain ID.
    uint64 public l1ChainId;

    uint256[46] private __gap;

    struct Config {
        uint32 gasTargetPerL1Block;
        uint8 basefeeAdjustmentQuotient;
        uint64 ontakeForkHeight;
    }

    /// @notice Emitted when the latest L1 block details are anchored to L2.
    /// @param parentHash The hash of the parent block.
    /// @param gasExcess The gas excess value used to calculate the base fee.
    event Anchored(bytes32 parentHash, uint64 gasExcess);

    /// @notice Emitted when the latest L1 block details are anchored to L2.
    /// @param parentHash The hash of the parent block.
    /// @param gasExcess The gas excess value used to calculate the base fee.
    /// @param l1BaseFee The L1's basefee.
    /// @param l1BlobBaseFee The L1's blob basefee.
    event Anchored2(bytes32 parentHash, uint64 gasExcess, uint256 l1BaseFee, uint256 l1BlobBaseFee);

    error L2_BASEFEE_MISMATCH();
    error L2_FORK_ERROR();
    error L2_INVALID_L1_BASE_FEE();
    error L2_INVALID_L1_CHAIN_ID();
    error L2_INVALID_L2_CHAIN_ID();
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
        __Essential_init(_owner, _addressManager);

        if (_l1ChainId == 0 || _l1ChainId == block.chainid) {
            revert L2_INVALID_L1_CHAIN_ID();
        }
        if (block.chainid <= 1 || block.chainid > type(uint64).max) {
            revert L2_INVALID_L2_CHAIN_ID();
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

        l1ChainId = _l1ChainId;
        gasExcess = _gasExcess;
        (publicInputHash,) = _calcPublicInputHash(block.number);
    }

    /// @notice Anchors the latest L1 block details to L2 for cross-layer
    /// message verification.
    /// @dev This function can be called freely as the golden touch private key is publicly known,
    /// but the Taiko node guarantees the first transaction of each block is always this anchor
    /// transaction, and any subsequent calls will revert with L2_PUBLIC_INPUT_HASH_MISMATCH.
    /// @param _l1BlockHash The `anchorBlockHash` value in this block's metadata.
    /// @param _l1StateRoot The state root for the L1 block with id equals `_l1BlockId`
    /// @param _l1BlockId The `anchorBlockId` value in this block's metadata.
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
        Config memory config = getConfig();
        if (block.number >= config.ontakeForkHeight) revert L2_FORK_ERROR();

        _anchor(
            config, //
            _l1BlockHash,
            _l1StateRoot,
            0,
            0,
            _l1BlockId,
            _parentGasUsed,
            false
        );
    }

    /// @notice Anchors the latest L1 block details to L2 for cross-layer
    /// message verification.
    /// @dev This function can be called freely as the golden touch private key is publicly known,
    /// but the Taiko node guarantees the first transaction of each block is always this anchor
    /// transaction, and any subsequent calls will revert with L2_PUBLIC_INPUT_HASH_MISMATCH.
    /// @param _l1BlockHash The `anchorBlockHash` value in this block's metadata.
    /// @param _l1StateRoot The state root for the L1 block with id equals `_l1BlockId`
    /// @param _l1BaseFee The L1's basefee.
    /// @param _l1BlobBaseFee The L1's blob basefee.
    /// @param _l1BlockId The `anchorBlockId` value in this block's metadata.
    /// @param _parentGasUsed The gas used in the parent block.
    function anchor2(
        bytes32 _l1BlockHash,
        bytes32 _l1StateRoot,
        uint256 _l1BaseFee,
        uint256 _l1BlobBaseFee,
        uint64 _l1BlockId,
        uint32 _parentGasUsed,
        bool _waiveBaseFee
    )
        external
        nonReentrant
    {
        Config memory config = getConfig();
        if (block.number < config.ontakeForkHeight) revert L2_FORK_ERROR();

        _anchor(
            config,
            _l1BlockHash,
            _l1StateRoot,
            _l1BaseFee,
            _l1BlobBaseFee,
            _l1BlockId,
            _parentGasUsed,
            _waiveBaseFee
        );
    }

    function _anchor(
        Config memory _config,
        bytes32 _l1BlockHash,
        bytes32 _l1StateRoot,
        uint256 _l1BaseFee,
        uint256 _l1BlobBaseFee,
        uint64 _l1BlockId,
        uint32 _parentGasUsed,
        bool _waiveBaseFee
    )
        private
    {
        if (
            _l1BlockHash == 0 || _l1StateRoot == 0 || _l1BlockId == 0
                || (block.number != 1 && _parentGasUsed == 0)
        ) {
            revert L2_INVALID_PARAM();
        }

        if (msg.sender != GOLDEN_TOUCH_ADDRESS) revert L2_INVALID_SENDER();

        if (block.number < _config.ontakeForkHeight) {
            if (_l1BaseFee != 0 || _l1BlobBaseFee != 0) revert L2_INVALID_L1_BASE_FEE();
        }

        uint256 parentId;
        unchecked {
            parentId = block.number - 1;
        }

        // Verify ancestor hashes
        (bytes32 publicInputHashOld, bytes32 publicInputHashNew) = _calcPublicInputHash(parentId);
        if (publicInputHash != publicInputHashOld) {
            revert L2_PUBLIC_INPUT_HASH_MISMATCH();
        }

        // Verify the base fee per gas is correct
        (uint256 _basefee, uint256 _basefeeExtra, uint64 _gasExcess, uint64 _avgBlockGasUsed) =
            getBasefee(_l1BlockId, _l1BaseFee, _l1BlobBaseFee, _parentGasUsed);

        uint256 expectedBaseFee = _waiveBaseFee ? 0 : _basefee + _basefeeExtra;
        if (!skipFeeCheck() && block.basefee != expectedBaseFee) {
            revert L2_BASEFEE_MISMATCH();
        }

        if (_l1BlockId > lastSyncedBlock) {
            // Store the L1's state root as a signal to the local signal service to
            // allow for multi-hop bridging.
            ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false)).syncChainData(
                l1ChainId, LibStrings.H_STATE_ROOT, _l1BlockId, _l1StateRoot
            );

            lastSyncedBlock = _l1BlockId;
        }

        // Update state variables
        bytes32 _parentHash = blockhash(parentId);
        l2Hashes[parentId] = _parentHash;
        publicInputHash = publicInputHashNew;
        gasExcess = _gasExcess;
        avgBlockGasUsed = _avgBlockGasUsed;

        if (block.number < _config.ontakeForkHeight) {
            emit Anchored(_parentHash, _gasExcess);
        } else {
            emit Anchored2(_parentHash, _gasExcess, _l1BaseFee, _l1BlobBaseFee);
        }
    }

    /// @notice Withdraw token or Ether from this address
    /// @param _token Token address or address(0) if Ether.
    /// @param _to Withdraw to address.
    function withdraw(
        address _token,
        address _to
    )
        external
        whenNotPaused
        onlyFromOwnerOrNamed(LibStrings.B_WITHDRAWER)
        nonReentrant
    {
        if (_to == address(0)) revert L2_INVALID_PARAM();
        if (_token == address(0)) {
            _to.sendEtherAndVerify(address(this).balance);
        } else {
            IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));
        }
    }

    /// @notice Gets the basefee and gas excess using EIP-1559 configuration for
    /// the given parameters.
    /// @param _l1BlockId The synced L1 height in the next Taiko block
    /// @param _l1BaseFee The L1's basefee.
    /// @param _l1BlobBaseFee The L1's blob basefee.
    /// @param _parentGasUsed Gas used in the parent block.
    /// @return basefee_ The calculated EIP-1559 base fee per gas.
    /// @return basefeeExtra_ The additional value added to base fee due to L1 cost.
    /// @return gasExcess_ The new gasExcess value.
    function getBasefee(
        uint64 _l1BlockId,
        uint256 _l1BaseFee,
        uint256 _l1BlobBaseFee,
        uint32 _parentGasUsed
    )
        public
        view
        returns (
            uint256 basefee_,
            uint256 basefeeExtra_,
            uint64 gasExcess_,
            uint64 avgBlockGasUsed_
        )
    {
        Config memory config = getConfig();
        uint64 gasIssuance = uint64(_l1BlockId - lastSyncedBlock) * config.gasTargetPerL1Block;

        (basefee_, gasExcess_) = Lib1559Math.calc1559BaseFee(
            config.gasTargetPerL1Block,
            config.basefeeAdjustmentQuotient,
            gasExcess,
            gasIssuance,
            _parentGasUsed
        );

        if (avgBlockGasUsed == 0) {
            avgBlockGasUsed_ = _parentGasUsed;
        } else {
            avgBlockGasUsed_ = (avgBlockGasUsed * 63 + _parentGasUsed) / 64;
        }

        if (avgBlockGasUsed_ != 0) {
            basefeeExtra_ = (BLOCK_GAS_COST_ON_L1 * _l1BaseFee + _l1BlobBaseFee) / avgBlockGasUsed_;
        }
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
    function getConfig() public view virtual returns (Config memory) {
        // Assuming we sell 3x more blockspace than Ethereum: 15_000_000 * 4
        // Note that Brecht's concern is that this value may be too large.
        // We need to monitor L2 state growth and lower this value when necessary.
        return Config({
            gasTargetPerL1Block: 60_000_000,
            basefeeAdjustmentQuotient: 8,
            ontakeForkHeight: 500_000
        });
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
}
