// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoData.sol";

/// @title IHook
/// @custom:security-contact security@taiko.xyz
interface IHook {
    function onBlockProposed(
        TaikoData.Block memory blk,
        TaikoData.BlockMetadata memory meta,
        bytes memory data
    )
        external
        payable;
}
