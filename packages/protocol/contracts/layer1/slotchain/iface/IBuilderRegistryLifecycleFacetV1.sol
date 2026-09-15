// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Immutable BuilderRegistry lifecycle-facet configuration
/// @custom:security-contact security@taiko.xyz
interface IBuilderRegistryLifecycleFacetV1 {
    /// @notice Returns one facet's exact selector and shared-storage commitments.
    /// @return magic_ The fixed `BRF1` magic.
    /// @return schema_ The fixed schema version one.
    /// @return facetKind_ Seat lifecycle is one and lease lifecycle is two.
    /// @return storageLayoutHash_ The common compiler-normalized Registry storage-layout hash.
    /// @return selectorSetHash_ The commitment to this facet's canonical ordered selectors.
    /// @return configurationHash_ The complete immutable facet configuration commitment.
    function builderRegistryLifecycleFacetConfigV1()
        external
        pure
        returns (
            bytes4 magic_,
            uint8 schema_,
            uint8 facetKind_,
            bytes32 storageLayoutHash_,
            bytes32 selectorSetHash_,
            bytes32 configurationHash_
        );
}
