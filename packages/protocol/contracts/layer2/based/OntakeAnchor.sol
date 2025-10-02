// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import { IBlockHashProvider } from "./IBlockHashProvider.sol";

/// @title OntakeAnchor
/// @notice Anchoring functions for the Ontake and pre-Ontake fork.
/// @custom:deprecated This contract is deprecated and should not be used in new implementations
/// @custom:security-contact security@taiko.xyz
abstract contract OntakeAnchor is EssentialContract, IBlockHashProvider {
    // -------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------

    /// @dev Struct that represents L2 basefee configurations
    struct BaseFeeConfig {
        // This is the base fee change denominator per 12 second window.
        uint8 adjustmentQuotient;
        uint8 sharingPctg;
        uint32 gasIssuancePerSecond;
        uint64 minGasExcess;
        uint32 maxGasIssuancePerBlock;
    }

    // -------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------

    error L2_DEPRECATED_METHOD();

    // -------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------

    modifier deprecated() {
        revert L2_DEPRECATED_METHOD();
        _;
    }

    // -------------------------------------------------------------------
    // External functions (deprecated)
    // -------------------------------------------------------------------

    function anchor(
        bytes32 _l1BlockHash,
        bytes32 _l1StateRoot,
        uint64 _l1BlockId,
        uint32 _parentGasUsed
    )
        external
        deprecated
    { }

    /// @dev Deprecated function for getting base fee
    function getBasefee(
        uint64 _anchorBlockId,
        uint32 _parentGasUsed
    )
        public
        pure
        deprecated
        returns (uint256 basefee_, uint64 parentGasExcess_)
    { }

    /// @dev Deprecated function for adjusting gas excess
    function adjustExcess(
        uint64 _currGasExcess,
        uint64 _currGasTarget,
        uint64 _newGasTarget
    )
        public
        pure
        deprecated
        returns (uint64 newGasExcess_)
    { }

    /// @dev Deprecated function for calculating base fee
    function calculateBaseFee(
        BaseFeeConfig calldata _baseFeeConfig,
        uint64 _blocktime,
        uint64 _parentGasExcess,
        uint32 _parentGasUsed
    )
        public
        pure
        deprecated
        returns (uint256 basefee_, uint64 parentGasExcess_)
    { }

    function anchorV2(
        uint64 _anchorBlockId,
        bytes32 _anchorStateRoot,
        uint32 _parentGasUsed,
        BaseFeeConfig calldata _baseFeeConfig
    )
        external
        deprecated
    { }

    // -------------------------------------------------------------------
    // Public functions (deprecated)
    // -------------------------------------------------------------------
}
