// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/based/LibSharedData.sol";
import "../eip1559/LibEIP1559Classic.sol";
import "./PacayaAnchor.sol";

/// @title ShastaAnchor
/// @notice Anchoring functions for the Shasta fork.
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaAnchor is PacayaAnchor {
    uint64 public immutable shastaForkHeight;

    error InvalidForkHeight();

    uint256[50] private __gap;

    constructor(
        address _resolver,
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight
    )
        PacayaAnchor(_resolver, _signalService, _pacayaForkHeight)
    {
        require(shastaForkHeight == 0 || shastaForkHeight > _pacayaForkHeight, InvalidForkHeight());
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
    function shastaAnchor(
        uint64 _anchorBlockId,
        bytes32 _anchorStateRoot,
        uint256 _parentBaseFee,
        uint64 _parentGasUsed,
        LibSharedData.BaseFeeConfig calldata _baseFeeConfig,
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
        require(shastaForkHeight != 0 && block.number >= shastaForkHeight, L2_FORK_ERROR());

        uint256 parentId = block.number - 1;
        _verifyAndUpdatePublicInputHash(parentId);

        uint256 blockTime = block.timestamp - parentTimestamp;
        require(
            shastaGetBaseFee(
                _parentBaseFee,
                _parentGasUsed,
                blockTime,
                _baseFeeConfig.adjustmentQuotient,
                _baseFeeConfig.gasIssuancePerSecond
            ) == block.basefee || skipFeeCheck(),
            L2_BASEFEE_MISMATCH()
        );

        if (blockTime == 0) {
            accumulatedAncestorGasUsed += _parentGasUsed;
        } else {
            accumulatedAncestorGasUsed = 0;
        }

        _syncChainData(_anchorBlockId, _anchorStateRoot);
        _updateParentHashAndTimestamp(parentId);

        signalService.receiveSignals(_signalSlots);
    }

    function shastaGetBaseFee(
        uint256 _parentBaseFee,
        uint64 _parentGasUsed,
        uint256 _blockTime,
        uint256 _adjustmentQuotient,
        uint256 _gasIssuancePerSecond
    )
        public
        view
        returns (uint256)
    {
        return _blockTime == 0
            ? _parentBaseFee
            : LibEIP1559Classic.calculateClassicBaseFee(
                _parentBaseFee,
                _parentGasUsed + accumulatedAncestorGasUsed,
                _adjustmentQuotient,
                _gasIssuancePerSecond,
                _blockTime
            );
    }
}
