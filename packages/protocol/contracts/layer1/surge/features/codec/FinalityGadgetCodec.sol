// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "../../../core/iface/IInbox.sol";

/// @title FinalityGadgetCodec
/// @notice Codec contract for types required by `FinalityGadgetInbox`
/// @custom:security-contact security@nethermind.io
contract FinalityGadgetCodec {
    /// @notice Encodes an array of commitments into bytes
    /// @param _commitments The array of commitments to encode
    /// @return The ABI-encoded commitments
    function encodeCommitments(IInbox.Commitment[] calldata _commitments)
        external
        pure
        returns (bytes memory)
    {
        return abi.encode(_commitments);
    }

    /// @notice Decodes bytes into an array of commitments
    /// @param _data The ABI-encoded commitments data
    /// @return The decoded array of commitments
    function decodeCommitments(bytes calldata _data)
        external
        pure
        returns (IInbox.Commitment[] memory)
    {
        return abi.decode(_data, (IInbox.Commitment[]));
    }
}
