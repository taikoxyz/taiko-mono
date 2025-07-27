// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IInbox.sol";

/// @title LibCodecProverAuth
/// @notice Library for encoding and decoding ProverAuth
/// @custom:security-contact security@taiko.xyz
// TODO(dnaiel): implement this library
library LibCodecProverAuth {
    /// @notice Encodes a ProverAuth struct into bytes
    /// @param _auth The ProverAuth to encode
    /// @return _ The encoded data
    function encode(IInbox.ProverAuth memory _auth) internal pure returns (bytes memory) {
        return abi.encode(_auth);
    }

    /// @notice Decodes bytes into a ProverAuth struct
    /// @param _data The encoded data
    /// @return _ The decoded ProverAuth
    function decode(bytes memory _data) internal pure returns (IInbox.ProverAuth memory) {
        return abi.decode(_data, (IInbox.ProverAuth));
    }
}
