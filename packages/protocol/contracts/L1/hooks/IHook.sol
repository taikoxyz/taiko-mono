// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoData.sol";

/// @title IHook
/// @custom:security-contact security@taiko.xyz
interface IHook {
    /// @notice Called when a block is proposed.
    /// @param _blk The proposed block.
    /// @param _meta The metadata of the proposed block.
    /// @param _data The data of the proposed block.
    function onBlockProposed(
        TaikoData.Block memory _blk,
        TaikoData.BlockMetadata memory _meta,
        bytes memory _data
    )
        external
        payable;
}
