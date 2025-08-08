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

    function anchor4(
        uint64 _anchorBlockId,
        bytes32 _anchorStateRoot
    )
        external
        onlyGoldenTouch
        nonReentrant
    {
        require(block.number >= shastaForkHeight, L2_FORK_ERROR());

        uint256 parentId = block.number - 1;
        _verifyAndUpdatePublicInputHash(parentId);
        // _verifyBaseFeeAndUpdateGasExcess(_parentGasUsed, _baseFeeConfig);
        _updateParentHashAndTimestamp(parentId);

        if (_anchorBlockId == 0) {
            // This block must not be the last block in the batch.
            require(_anchorStateRoot == 0, NonZeroAnchorStateRoot());
        } else {
            // This block must be the last block in the batch.
            require(_anchorStateRoot != 0, ZeroAnchorStateRoot());
            _syncChainData(_anchorBlockId, _anchorStateRoot);
        }

        // We need to add one SSTORE from non-zero to non-zero (5000), one addition (3), and one
        // subtraction (3).
        lastAnchorGasUsed = uint32(ANCHOR_GAS_LIMIT - gasleft() + 5006);
    }
}
