// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoData.sol";

/// @title LibData
/// @notice A library that offers helper functions.
/// @custom:security-contact security@taiko.xyz
library LibData {
    function paramV1toV2(TaikoData.BlockParams memory v1)
        internal
        pure
        returns (TaikoData.BlockParams2 memory v2)
    { }

    function metadataV2toV1(TaikoData.BlockMetadata2 memory v2)
        internal
        pure
        returns (TaikoData.BlockMetadata memory)
    { }

    function metadataV1toV2(TaikoData.BlockMetadata memory v1)
        internal
        pure
        returns (TaikoData.BlockMetadata2 memory)
    { }

    function hashMetadata(
        bool postFork,
        TaikoData.BlockMetadata2 memory _meta
    )
        internal
        pure
        returns (bytes32)
    {
        return postFork
            ? keccak256(abi.encode(_meta)) //
            : keccak256(abi.encode(metadataV2toV1(_meta)));
    }
}
