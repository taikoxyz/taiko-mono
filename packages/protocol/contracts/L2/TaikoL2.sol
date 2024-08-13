// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { TaikoData } from "../L1/TaikoData.sol";
import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../libs/LibAddress.sol";
import "../signal/ISignalService.sol";
import "./Lib1559Math.sol";
import "./LibL2Config.sol";

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

    /// @notice Mapping from L2 block numbers to their block hashes. All L2 block hashes will
    /// be saved in this mapping.
    mapping(uint256 blockId => bytes32 blockHash) public l2Hashes;

    /// @notice A hash to check the integrity of public inputs.
    /// @dev Slot 2.
    bytes32 public publicInputHash;

    /// @notice The gas excess value used to calculate the base fee.
    /// @dev Slot 3.
    uint64 public parentGasExcess;

    /// @notice The last synced L1 block height.
    uint64 public lastSyncedBlock;
    uint64 public parentTimestamp;
    uint64 public parentGasTarget;

    /// @notice The L1's chain ID.
    /// @dev Slot 4.
    uint64 public l1ChainId;

    uint256[46] private __gap;

    /// @notice Emitted when the latest L1 block details are anchored to L2.
    /// @param parentHash The hash of the parent block.
    /// @param parentGasExcess The gas excess value used to calculate the base fee.
    event Anchored(bytes32 parentHash, uint64 parentGasExcess);

    error L2_BASEFEE_MISMATCH();
    error L2_INVALID_L1_CHAIN_ID();
    error L2_INVALID_L2_CHAIN_ID();
    error L2_INVALID_SENDER();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error L2_TOO_LATE();

    modifier onlyGoldenTouch() {
        if (msg.sender != GOLDEN_TOUCH_ADDRESS) revert L2_INVALID_SENDER();
        _;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    /// @param _l1ChainId The ID of the base layer.
    /// @param _initialGasExcess The initial parentGasExcess.
    function init(
        address _owner,
        address _rollupAddressManager,
        uint64 _l1ChainId,
        uint64 _initialGasExcess
    )
        external
        initializer
    {
        __Essential_init(_owner, _rollupAddressManager);

        if (_l1ChainId == 0 || _l1ChainId == block.chainid) {
            revert L2_INVALID_L1_CHAIN_ID();
        }
        if (block.chainid <= 1 || block.chainid > type(uint64).max) {
            revert L2_INVALID_L2_CHAIN_ID();
        }

        if (block.number == 0) {
            // This is the case in real L2 genesis
        }
        else if (block.number == 1) {
            // This is the case in tests
            uint256 parentHeight = block.number - 1;
            l2Hashes[parentHeight] = blockhash(parentHeight);
        } else {
            revert L2_TOO_LATE();
        }

        l1ChainId = _l1ChainId;
        parentGasExcess = _initialGasExcess;
        (publicInputHash,) = _calcPublicInputHash(block.number);
    }

    /// @dev Reinitialize some state variables.
    /// We may want to init the basefee to a default value using one of the following values.
    /// - _initialGasExcess = 274*5_000_000 => basefee =0.01 gwei
    /// - _initialGasExcess = 282*5_000_000 => basefee =0.05 gwei
    /// - _initialGasExcess = 288*5_000_000 => basefee =0.1 gwei
    function init2(uint64 _initialGasExcess) external onlyOwner reinitializer(2) {
        parentGasExcess = _initialGasExcess;
        parentTimestamp = uint64(block.timestamp);
        parentGasTarget = 0;
    }

    function anchorV2(
        uint64 _anchorBlockId,
        bytes32 _anchorStateRoot,
        uint32 _parentGasUsed,
        TaikoData.BaseFeeConfig calldata _baseFeeConfig
    )
        external
        nonZeroValue(uint256(_anchorStateRoot))
        nonZeroValue(uint256(_anchorBlockId))
        nonZeroValue(uint256(_baseFeeConfig.gasIssuancePerSecond))
        nonZeroValue(uint256(_baseFeeConfig.adjustmentQuotient))
        onlyGoldenTouch
        nonReentrant
    {
        uint256 parentId = block.number - 1;

        // Verify ancestor hashes
        {
            (bytes32 currentPublicInputHash, bytes32 newPublicInputHash) =
                _calcPublicInputHash(parentId);
            if (publicInputHash != currentPublicInputHash) revert L2_PUBLIC_INPUT_HASH_MISMATCH();
            publicInputHash = newPublicInputHash;
        }

        // Check if the gas settings has changed
        {
            uint64 newGasTarget =
                uint64(_baseFeeConfig.gasIssuancePerSecond) * _baseFeeConfig.adjustmentQuotient;

            if (parentGasTarget != newGasTarget) {
                if (parentGasTarget != 0) {
                    parentGasExcess = adjustExcess(parentGasExcess, parentGasTarget, newGasTarget);
                }
                parentGasTarget = newGasTarget;
            }
        }

        // Verify the base fee per gas is correct
        {
            (uint256 basefee, uint64 newGasExcess) = calculateBaseFee(
                _baseFeeConfig,
                uint64(block.timestamp - parentTimestamp),
                parentGasExcess,
                _parentGasUsed
            );

            if (!skipFeeCheck() && block.basefee != basefee) revert L2_BASEFEE_MISMATCH();
            parentGasExcess = newGasExcess;
        }

        if (_anchorBlockId > lastSyncedBlock) {
            // Store the L1's state root as a signal to the local signal service to
            // allow for multi-hop bridging.
            ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false)).syncChainData(
                l1ChainId, LibStrings.H_STATE_ROOT, _anchorBlockId, _anchorStateRoot
            );

            lastSyncedBlock = _anchorBlockId;
        }

        // Update state variables
        bytes32 parentHash = blockhash(parentId);
        l2Hashes[parentId] = parentHash;
        parentTimestamp = uint64(block.timestamp);

        emit Anchored(parentHash, parentGasExcess);
    }

    /// @notice Withdraw token or Ether from this address
    /// @param _token Token address or address(0) if Ether.
    /// @param _to Withdraw to address.
    function withdraw(
        address _token,
        address _to
    )
        external
        nonZeroAddr(_to)
        whenNotPaused
        onlyFromOwnerOrNamed(LibStrings.B_WITHDRAWER)
        nonReentrant
    {
        if (_token == address(0)) {
            _to.sendEtherAndVerify(address(this).balance);
        } else {
            IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));
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

    /// @notice Returns the new gas excess that will keep the basefee the same.
    /// @param _currGasExcess The current gas excess value.
    /// @param _currGasTarget The current gas target.
    /// @param _newGasTarget The new gas target.
    /// @return newGasExcess_ The new gas excess value.
    function adjustExcess(
        uint64 _currGasExcess,
        uint64 _currGasTarget,
        uint64 _newGasTarget
    )
        public
        pure
        returns (uint64 newGasExcess_)
    {
        return Lib1559Math.adjustExcess(_currGasExcess, _currGasTarget, _newGasTarget);
    }

    /// @notice Tells if we need to validate basefee (for simulation).
    /// @return Returns true to skip checking basefee mismatch.
    function skipFeeCheck() public pure virtual returns (bool) {
        return false;
    }

    /// @notice Calculates the basefee and the new gas excess value based on parent gas used and gas
    /// excess.
    /// @param _baseFeeConfig The base fee config object.
    /// @param _blocktime The time between this block and the parent block.
    /// @param _parentGasExcess The current gas excess value.
    /// @param _parentGasUsed Total gas used by the parent block.
    /// @return basefee_ Next block's base fee.
    /// @return parentGasExcess_ The new gas excess value.
    function calculateBaseFee(
        TaikoData.BaseFeeConfig calldata _baseFeeConfig,
        uint64 _blocktime,
        uint64 _parentGasExcess,
        uint32 _parentGasUsed
    )
        public
        pure
        returns (uint256 basefee_, uint64 parentGasExcess_)
    {
        uint64 gasIssuance = _blocktime * _baseFeeConfig.gasIssuancePerSecond;
        if (
            _baseFeeConfig.maxGasIssuancePerBlock != 0
                && gasIssuance > _baseFeeConfig.maxGasIssuancePerBlock
        ) {
            gasIssuance = _baseFeeConfig.maxGasIssuancePerBlock;
        }

        uint256 gasTarget =
            uint256(_baseFeeConfig.gasIssuancePerSecond) * _baseFeeConfig.adjustmentQuotient;

        return Lib1559Math.calc1559BaseFee(
            gasTarget, _parentGasExcess, gasIssuance, _parentGasUsed, _baseFeeConfig.minGasExcess
        );
    }

    function _calcPublicInputHash(
        uint256 _blockId
    )
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
