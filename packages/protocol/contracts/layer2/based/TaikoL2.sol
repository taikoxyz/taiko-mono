// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoL2V1.sol";

/// @title TaikoL2
/// @notice TaikoL2's V2 version that supports Ontake hardfork.
/// @custom:security-contact security@taiko.xyz
contract TaikoL2 is TaikoL2V1 {
    using LibMath for uint256;

    uint256[50] private __gap;

    /// @notice Emitted when the gas target has been updated.
    /// @param oldGasTarget The previous gas target.
    /// @param newGasTarget The new gas target.
    event GasTargetUpdated(uint64 oldGasTarget, uint64 newGasTarget);

    /// @notice Emitted when the gas excess has been updated.
    /// @param oldGasExcess The previous gas excess.
    /// @param newGasExcess The new gas excess.
    event GasExcessUpdated(uint64 oldGasExcess, uint64 newGasExcess);

    /// @notice Emitted when the gas target update fails.
    event UpdateGasTargetFailed(
        uint64 parentGasTarget, uint64 parentGasExcess, LibSharedData.BaseFeeConfig baseFeeConfig
    );

    /// @notice Anchors the latest L1 block details to L2 for cross-layer
    /// message verification.
    /// @dev This function can be called freely as the golden touch private key is publicly known,
    /// but the Taiko node guarantees the first transaction of each block is always this anchor
    /// transaction, and any subsequent calls will revert with L2_PUBLIC_INPUT_HASH_MISMATCH.
    /// @param _anchorBlockId The `anchorBlockId` value in this block's metadata.
    /// @param _anchorStateRoot The state root for the L1 block with id equals `_anchorBlockId`.
    /// @param _parentGasUsed The gas used in the parent block.
    /// @param _baseFeeConfig The base fee configuration.
    function anchorV2(
        uint64 _anchorBlockId,
        bytes32 _anchorStateRoot,
        uint32 _parentGasUsed,
        LibSharedData.BaseFeeConfig calldata _baseFeeConfig
    )
        external
        nonZeroBytes32(_anchorStateRoot)
        nonZeroValue(_anchorBlockId)
        nonZeroValue(_baseFeeConfig.gasIssuancePerSecond)
        nonZeroValue(_baseFeeConfig.adjustmentQuotient)
        onlyGoldenTouch
        nonReentrant
    {
        require(block.number >= ontakeForkHeight(), L2_FORK_ERROR());

        uint256 parentId = block.number - 1;
        _verifyAndUpdatePublicInputHash(parentId);
        _verifyBaseFeeAndUpdateGasExcessV2(_parentGasUsed, _baseFeeConfig);
        _syncChainData(_anchorBlockId, _anchorStateRoot);
        _updateParentHashAndTimestamp(parentId);
    }

    /// @notice Calculates the base fee and gas excess using EIP-1559 configuration for the given
    /// parameters.
    /// @param _parentGasUsed Gas used in the parent block.
    /// @param _baseFeeConfig Configuration parameters for base fee calculation.
    /// @return basefee_ The calculated EIP-1559 base fee per gas.
    /// @return parentGasTarget_ The new parentGasTarget value.
    /// @return parentGasExcess_ The new parentGasExcess value.
    /// @return newGasTargetApplied_ Indicates if a new gas target was applied.
    function getBasefeeV2(
        uint32 _parentGasUsed,
        LibSharedData.BaseFeeConfig calldata _baseFeeConfig
    )
        public
        view
        returns (
            uint256 basefee_,
            uint64 parentGasTarget_,
            uint64 parentGasExcess_,
            bool newGasTargetApplied_
        )
    {
        // gasIssuancePerSecond (uint32) * adjustmentQuotient (uint8), will never overflow
        uint64 newGasTarget =
            uint64(_baseFeeConfig.gasIssuancePerSecond) * _baseFeeConfig.adjustmentQuotient;

        if (parentGasTarget != newGasTarget) {
            if (parentGasTarget == 0) {
                parentGasExcess_ = parentGasExcess;
                parentGasTarget_ = newGasTarget;
                newGasTargetApplied_ = true;
            } else {
                uint64 newGasExcess;
                (newGasTargetApplied_, newGasExcess) =
                    LibEIP1559.adjustExcess(parentGasExcess, parentGasTarget, newGasTarget);

                if (newGasTargetApplied_) {
                    parentGasExcess_ = newGasExcess;
                    parentGasTarget_ = newGasTarget;
                } else {
                    // Use the current excess and target values
                    parentGasExcess_ = parentGasExcess;
                    parentGasTarget_ = parentGasTarget;
                }
            }
        }

        // uint64 * uint32 will never overflow
        uint256 gasIssuance =
            (block.timestamp - parentTimestamp) * _baseFeeConfig.gasIssuancePerSecond;

        if (
            _baseFeeConfig.maxGasIssuancePerBlock != 0
                && gasIssuance > _baseFeeConfig.maxGasIssuancePerBlock
        ) {
            gasIssuance = _baseFeeConfig.maxGasIssuancePerBlock;
        }

        (basefee_, parentGasExcess_) = LibEIP1559.calc1559BaseFee(
            parentGasTarget_,
            parentGasExcess_,
            gasIssuance.capToUint64(),
            _parentGasUsed,
            _baseFeeConfig.minGasExcess
        );
    }

    /// @dev Verifies that the base fee per gas is correct and updates the gas excess.
    /// @param _parentGasUsed The gas used by the parent block.
    /// @param _baseFeeConfig The configuration parameters for calculating the base fee.
    function _verifyBaseFeeAndUpdateGasExcessV2(
        uint32 _parentGasUsed,
        LibSharedData.BaseFeeConfig calldata _baseFeeConfig
    )
        private
        returns (uint256 basefee_)
    {
        bool newGasTargetApplied_;
        uint64 parentGasTarget_;
        uint64 parentGasExcess_;

        (basefee_, parentGasTarget_, parentGasExcess_, newGasTargetApplied_) =
            getBasefeeV2(_parentGasUsed, _baseFeeConfig);

        require(skipFeeCheck() || block.basefee == basefee_, L2_BASEFEE_MISMATCH());

        if (!newGasTargetApplied_) {
            emit UpdateGasTargetFailed(parentGasTarget, parentGasExcess, _baseFeeConfig);
        } else {
            emit GasTargetUpdated(parentGasTarget, parentGasTarget_);
            parentGasTarget = parentGasTarget_;
        }

        emit GasExcessUpdated(parentGasExcess, parentGasExcess_);
        parentGasExcess = parentGasExcess_;
    }
}
