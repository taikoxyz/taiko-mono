// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/based/LibSharedData.sol";
import "../eip1559/LibEIP1559Classic.sol";
import "./PacayaAnchor.sol";

/// @title ShastaAnchor
/// @notice Anchoring functions for the Shasta fork.
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaAnchor is PacayaAnchor {
    error InvalidForkHeight();

    // The v4Anchor's transaction gas limit, this value must be enforced by the node and prover.
    // When there are 16 signals in v4Anchor's parameter, the estimated gas cost is actually
    // around 361,579 gas.  We set the limit to 1,000,000 to be safe.
    uint256 public constant ANCHOR_GAS_LIMIT = 1_000_000;

    uint256[50] private __gap;

    constructor(
        address _resolver,
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight
    )
        PacayaAnchor(_resolver, _signalService, _pacayaForkHeight)
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
    /// @param _anchorBlockId The `anchorBlockId` value in this block's metadata.
    /// @param _anchorStateRoot The state root for the L1 block with id equals `_anchorBlockId`.
    /// @param _parentGasUsed The gas used in the parent block.
    /// @param _baseFeeConfig The base fee configuration.
    /// @param _signalSlots The signal slots to mark as received.
    function v4Anchor(
        uint64 _anchorBlockId,
        bytes32 _anchorStateRoot,
        uint256 _parentBaseFee,
        uint32 _parentGasUsed,
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
        // If shastaForkHeight is 0, the shasta fork is not scheduled to be active. Set it to 1 to
        // activate shasta immediately after genesis.
        require(shastaForkHeight != 0 && block.number >= shastaForkHeight, L2_FORK_ERROR());

        uint256 parentId = block.number - 1;
        _verifyAndUpdatePublicInputHash(parentId);

        uint256 blockTime = block.timestamp - parentTimestamp;

        require(
            v4GetBaseFee(
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

        // We need to add one SSTORE from non-zero to non-zero (5000), one addition (3), and one
        // subtraction (3).
        lastAnchorGasUsed = uint32(ANCHOR_GAS_LIMIT - gasleft() + 5006);
    }

    function v4GetBaseFee(
        uint256 _parentBaseFee,
        uint64 _parentGasUsed,
        uint256 _blockTime,
        uint8 _adjustmentQuotient,
        uint32 _gasIssuancePerSecond
    )
        public
        view
        returns (uint256)
    {
        return _blockTime == 0
            ? _parentBaseFee
            : LibEIP1559Classic.calculateBaseFee(
                _parentBaseFee,
                _parentGasUsed + accumulatedAncestorGasUsed,
                _adjustmentQuotient,
                _gasIssuancePerSecond,
                _blockTime
            );
    }
}
