// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library LibSourceInlineProbe {
    bytes32 private constant DOMAIN = keccak256("slot-chain-source-inline-probe-v1");

    /// @dev Hashes a value with a chain-class discriminator for cross-profile verification.
    /// @param _value Value to hash.
    /// @param _chainClass Chain-class discriminator.
    /// @return hash_ Domain-separated hash.
    function hash(bytes32 _value, uint64 _chainClass) internal pure returns (bytes32 hash_) {
        return keccak256(abi.encodePacked(DOMAIN, _chainClass, _value));
    }
}
