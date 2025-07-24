// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

/// @title LibCodecHeaderExtraInfo
/// @notice Library for encoding and decoding HeaderExtraInfo
/// @custom:security-contact security@taiko.xyz
library LibCodecHeaderExtraInfo {
    /// @notice Encodes a HeaderExtraInfo struct into bytes
    /// @dev The client must ensure that the lower 128 bits of the extraData field in the header of
    /// each block in this batch match the specified value. The upper 128 bits of the extraData
    /// field are validated using off-chain protocol logic.
    /// @dev Bit-level encoding for efficient storage:
    ///      - Bits 0-7: Base fee sharing percentage (0-100)
    ///      - Bit 8: Forced inclusion flag (0 or 1)
    ///      - Bits 9-40: Gas issuance per second (32 bits)
    ///      - Bits 41-127: Reserved for future use
    /// @param _headerExtraInfo The HeaderExtraInfo to encode
    /// @return _ The encoded data
    function encode(I.HeaderExtraInfo memory _headerExtraInfo) internal pure returns (bytes32) {
        uint256 v = _headerExtraInfo.sharingPctg; // bits 0-7
        v |= _headerExtraInfo.isForcedInclusion ? 1 << 8 : 0; // bit 8
        v |= _headerExtraInfo.gasIssuancePerSecond << 9; // bits 9-40

        return bytes32(v);
    }

    /// @notice Decodes bytes into a HeaderExtraInfo struct
    /// @param _data The encoded data
    /// @return _ The decoded HeaderExtraInfo
    function decode(bytes32 _data) internal pure returns (I.HeaderExtraInfo memory) {
        uint256 v = uint256(_data);

        return I.HeaderExtraInfo({
            sharingPctg: uint8(v & 0xff), // bits 0-7
            isForcedInclusion: (v >> 8) & 1 == 1, // bit 8
            gasIssuancePerSecond: uint32((v >> 9) & 0xffffffff) // bits 9-40
         });
    }
}
