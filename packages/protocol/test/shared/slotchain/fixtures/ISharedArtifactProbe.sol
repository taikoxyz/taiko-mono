// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ISharedArtifactProbe {
    /// @notice Hashes a value under the fixed artifact-ownership probe domain.
    /// @dev Used to consume owner-profile bytecode without importing its implementation.
    /// @param _value Value to hash.
    /// @return hash_ Domain-separated hash.
    function artifactHash(bytes32 _value) external pure returns (bytes32 hash_);
}
