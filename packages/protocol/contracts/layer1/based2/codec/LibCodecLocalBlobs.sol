// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IInbox.sol";

/// @title LibCodecLocalBlobs
/// @notice Library for encoding and decoding LocalBlobs
/// @custom:security-contact security@taiko.xyz
library LibCodecLocalBlobs {
    /// @notice Encodes a LocalBlobs struct into bytes
    /// @param _localBlobs The LocalBlobs to encode
    /// @return _ The encoded data
    /// @custom:encode optimize-gas
    function encode(IInbox.LocalBlobs memory _localBlobs) internal pure returns (bytes32) {
        uint256 v = uint256(_localBlobs.firstBlobIndex); // bits 0-7
        v |= uint256(_localBlobs.numBlobs) << 8; // bits 8-15
        return bytes32(v);
    }

    /// @notice Decodes bytes into a LocalBlobs struct
    /// @param _data The encoded data
    /// @return _ The decoded LocalBlobs
    /// @custom:encode optimize-gas
    function decode(bytes32 _data) internal pure returns (IInbox.LocalBlobs memory) {
        uint256 v = uint256(_data);
        return IInbox.LocalBlobs({
            firstBlobIndex: uint8(v & 0xff), // bits 0-7
            numBlobs: uint8((v >> 8) & 0xff) // bits 8-15
         });
    }
}
