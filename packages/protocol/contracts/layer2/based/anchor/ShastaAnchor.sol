// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/based/LibSharedData.sol";
import "./PacayaAnchor.sol";

/// @title ShastaAnchor
/// @notice Anchoring functions for the Shasta fork.
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaAnchor is PacayaAnchor {
    error InvalidForkHeight();
    error NonZeroAnchorStateRoot();
    error ZeroAnchorStateRoot();
    error NonEmptySignalSlots();

    // The v4Anchor's transaction gas limit, this value must be enforced by the node and prover.
    // When there are 16 signals in v4Anchor's parameter, the estimated gas cost is actually
    // around 361,579 gas.  We set the limit to 1,000,000 to be safe.
    uint256 public constant ANCHOR_GAS_LIMIT = 1_000_000;

    uint256[50] private __gap;

    constructor(
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight
    )
        PacayaAnchor(_signalService, _pacayaForkHeight)
    {
        require(
            _shastaForkHeight == 0 || _shastaForkHeight > _pacayaForkHeight, InvalidForkHeight()
        );
        shastaForkHeight = _shastaForkHeight;
    }

    /// @notice Anchors the latest L1 block details to L2 for cross-layer
    /// message verification.
    /// @dev The gas limit for this transaction must be set to 1,000,000 gas.
    /// @dev This function can be called freely as the golden touch private key is publicly known,
    /// but the Taiko node guarantees the first transaction of each block is always this anchor
    /// transaction, and any subsequent calls will revert with L2_PUBLIC_INPUT_HASH_MISMATCH.
    /// @param _anchorBlockId The `anchorBlockId` value in this block's metadata. This value must be
    /// 0 for all except the last block in the batch.
    /// @param _anchorStateRoot The state root for the L1 block with id equals `_anchorBlockId`. This
    /// value must be 0 for all except the last block in the batch.
    /// @param _parentGasUsed The gas used in the parent block.
    /// @param _baseFeeConfig The base fee configuration.
    /// @param _signalSlots The signal slots to mark as received. This array must be empty for all
    /// except the last block in the batch.
    function v4Anchor(
        uint64 _anchorBlockId,
        bytes32 _anchorStateRoot,
        uint256, /*_parentBaseFee*/
        uint32 _parentGasUsed,
        LibSharedData.BaseFeeConfig calldata _baseFeeConfig,
        bytes32[] calldata _signalSlots
    )
        external
        nonZeroValue(_baseFeeConfig.gasIssuancePerSecond)
        nonZeroValue(_baseFeeConfig.adjustmentQuotient)
        onlyGoldenTouch
        nonReentrant
    {
        require(block.number >= shastaForkHeight, L2_FORK_ERROR());

        uint256 parentId = block.number - 1;
        _verifyAndUpdatePublicInputHash(parentId);
        _verifyBaseFeeAndUpdateGasExcess(_parentGasUsed, _baseFeeConfig);
        _updateParentHashAndTimestamp(parentId);

        if (_anchorBlockId == 0) {
            // For blocks that are not the last in the batch, _anchorBlockId, _anchorStateRoot, and
            // _signalSlots must be zero or empty.
            require(_anchorStateRoot == 0, NonZeroAnchorStateRoot());
            require(_signalSlots.length == 0, NonEmptySignalSlots());
        } else {
            // For the final block in the batch, _anchorStateRoot must be non-zero.
            require(_anchorStateRoot != 0, ZeroAnchorStateRoot());
            _syncChainData(_anchorBlockId, _anchorStateRoot);
            signalService.receiveSignals(_signalSlots);
        }

        // We need to add one SSTORE from non-zero to non-zero (5000), one addition (3), and one
        // subtraction (3).
        lastAnchorGasUsed = uint32(ANCHOR_GAS_LIMIT - gasleft() + 5006);
    }

    function v4GetBaseFee(
        uint32 _parentGasUsed,
        uint64 _blockTimestamp,
        LibSharedData.BaseFeeConfig calldata _baseFeeConfig
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
    }
}
