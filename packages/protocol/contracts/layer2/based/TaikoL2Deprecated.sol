// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/based/LibSharedData.sol";

/// @title TaikoL2Deprecated
/// @notice This contract includes deprecated functions whose ABI are still used by client for old
/// blocks.
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoL2Deprecated {
    error L2_DEPRECATED_METHOD();

    modifier deprecated() {
        revert L2_DEPRECATED_METHOD();
        _;
    }

    function anchor(
        bytes32, /*_l1BlockHash*/
        bytes32, /*_l1StateRoot*/
        uint64, /*_l1BlockId*/
        uint32 /*_parentGasUsed */
    )
        external
        deprecated
    { }

    function getBasefee(
        uint64, /*_anchorBlockId*/
        uint32 /*_parentGasUsed*/
    )
        public
        pure
        deprecated
        returns (uint256, /*basefee_*/ uint64 /*parentGasExcess_*/ )
    { }

    function adjustExcess(
        uint64, /*_currGasExcess*/
        uint64, /*_currGasTarget*/
        uint64 /*_newGasTarget*/
    )
        public
        pure
        deprecated
        returns (uint64 /*newGasExcess_*/ )
    { }

    function calculateBaseFee(
        LibSharedData.BaseFeeConfig calldata, /*_baseFeeConfig*/
        uint64, /*_blocktime*/
        uint64, /*_parentGasExcess*/
        uint32 /*_parentGasUsed*/
    )
        public
        pure
        deprecated
        returns (uint256, /*basefee_*/ uint64 /*parentGasExcess_*/ )
    { }
}
