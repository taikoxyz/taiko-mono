// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoData.sol";

/// @title IHook
/// @custom:security-contact security@taiko.xyz
interface IHook {
    function onBlockProposed(
        TaikoData.Block memory _blk,
        TaikoData.BlockMetadata memory _meta,
        bytes memory _data
    )
        external
        payable;
}
