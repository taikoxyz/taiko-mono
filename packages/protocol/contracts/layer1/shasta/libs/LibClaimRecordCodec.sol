// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IInbox.sol";

/// @title LibClaimRecordCodec
/// @notice Library for encoding/decoding claim record data using standard abi encoding
/// @custom:security-contact security@taiko.xyz
library LibClaimRecordCodec {
    /// @dev Encodes the claim record data using simple abi.encode
    /// @param _claimRecord The claim record to encode
    /// @return The encoded data as bytes
    function encode(IInbox.ClaimRecord memory _claimRecord) internal pure returns (bytes memory) {
        return abi.encode(_claimRecord);
    }

    /// @dev Decodes the claim record data using simple abi.decode
    /// @param _data The encoded data
    /// @return claimRecord_ The decoded claim record
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ClaimRecord memory claimRecord_)
    {
        claimRecord_ = abi.decode(_data, (IInbox.ClaimRecord));
    }
}
