// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title TaikoL2Deprecated
/// @notice This contract includes deprecated functions whose ABI are still used by client for old
/// blocks.
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoL2Deprecated {
    error L2_DEPRECATED_METHOD();

    function anchor(
        bytes32, /*_l1BlockHash*/
        bytes32, /*_l1StateRoot*/
        uint64, /*_l1BlockId*/
        uint32 /*_parentGasUsed */
    )
        external
    {
        revert L2_DEPRECATED_METHOD();
    }

    function getBasefee(
        uint64 _anchorBlockId,
        uint32 _parentGasUsed
    )
        public
        pure
        returns (uint256, /*basefee_*/ uint64 /*parentGasExcess_*/ )
    { }

      function adjustExcess(
        uint64 _currGasExcess,
        uint64 _currGasTarget,
        uint64 _newGasTarget
    )
        public
        pure
        returns (uint64 /*newGasExcess_*/)
    {
    }
}
