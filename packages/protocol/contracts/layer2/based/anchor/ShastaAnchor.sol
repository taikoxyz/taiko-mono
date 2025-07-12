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

    uint256 public constant MAX_BASE_FEE = 2.5 gwei;
    uint256 public constant MIN_BASE_FEE = 0.005 gwei;

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

    /// @notice This function anchors the latest L1 block details to L2, enabling cross-layer
    /// message verification.
    /// @dev The gas limit for this transaction is required to be set to 1,000,000 gas.
    /// @dev Although this function can be invoked freely due to the public availability of the
    /// golden touch private key,
    /// the Taiko node ensures that the first transaction of each block is always this anchor
    /// transaction. Any subsequent calls will be reverted with L2_PUBLIC_INPUT_HASH_MISMATCH.
    /// @param _anchorBlockId This is the `anchorBlockId` value in the metadata of this block.
    /// @param _anchorStateRoot This is the state root for the L1 block with an id equal to
    /// `_anchorBlockId`.
    /// @param _parentGasUsed This is the amount of gas used in the parent block.
    /// @param _baseFeeConfig This is the configuration for the base fee.
    /// @param _signalSlots These are the signal slots to be marked as received.
    function anchor4(
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
            // This block must not be the last block in the batch.
            require(_anchorStateRoot == 0, NonZeroAnchorStateRoot());
        } else {
            // This block must be the last block in the batch.
            require(_anchorStateRoot != 0, ZeroAnchorStateRoot());
            _syncChainData(_anchorBlockId, _anchorStateRoot);
        }

        if (_signalSlots.length != 0) {
            signalService.receiveSignals(_signalSlots);
        }

        // We need to add one SSTORE from non-zero to non-zero (5000), one addition (3), and one
        // subtraction (3).
        lastAnchorGasUsed = uint32(ANCHOR_GAS_LIMIT - gasleft() + 5006);
    }

    function getBaseFee4(
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

        if (basefee_ > MAX_BASE_FEE) {
            basefee_ = MAX_BASE_FEE;
        }
        if (basefee_ < MIN_BASE_FEE) {
            basefee_ = MIN_BASE_FEE;
        }
    }
}
