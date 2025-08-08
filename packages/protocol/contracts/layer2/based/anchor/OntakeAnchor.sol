// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/based/LibSharedData.sol";
import { IBlockHashProvider } from "../iface/IBlockHashProvider.sol";

/// @title OntakeAnchor
/// @notice Anchoring functions for the Ontake and pre-Ontake fork.
/// @custom:security-contact security@taiko.xyz
abstract contract OntakeAnchor is EssentialContract, IBlockHashProvider {
    error L2_DEPRECATED_METHOD();

    constructor() EssentialContract() { }

    modifier deprecated() {
        revert L2_DEPRECATED_METHOD();
        _;
    }

    function anchor(
        bytes32 _l1BlockHash,
        bytes32 _l1StateRoot,
        uint64 _l1BlockId,
        uint32 _parentGasUsed
    )
        external
        deprecated
    { }

    function getBasefee(
        uint64 _anchorBlockId,
        uint32 _parentGasUsed
    )
        public
        pure
        deprecated
        returns (uint256 basefee_, uint64 parentGasExcess_)
    { }

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

    function calculateBaseFee(
        LibSharedData.BaseFeeConfig calldata _baseFeeConfig,
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
        LibSharedData.BaseFeeConfig calldata _baseFeeConfig
    )
        external
        deprecated
    { }
}
