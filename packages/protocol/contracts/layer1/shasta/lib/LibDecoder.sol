// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";

/// @title LibDecoder
/// @notice Library for encoding and decoding data structures used in the Inbox system
/// @custom:security-contact security@taiko.xyz
// TODO:
// - [ ] provide better decode/encode implementation
library LibDecoder {
    // -------------------------------------------------------------------------
    // Decode Functions
    // -------------------------------------------------------------------------

    /// @notice Decodes data into CoreState, BlobLocator array, and ClaimRecord array
    /// @param _data The encoded data
    /// @return coreState_ The decoded CoreState
    /// @return blobLocator_ The decoded BlobLocator
    /// @return claimRecords_ The decoded array of ClaimRecords
    function decodeProposeData(bytes calldata _data)
        internal
        pure
        returns (
            IInbox.CoreState memory coreState_,
            IInbox.BlobLocator memory blobLocator_,
            IInbox.ClaimRecord[] memory claimRecords_
        )
    {
        (coreState_, blobLocator_, claimRecords_) =
            abi.decode(_data, (IInbox.CoreState, IInbox.BlobLocator, IInbox.ClaimRecord[]));
    }

    /// @notice Decodes data into Proposal array and Claim array
    /// @param _data The encoded data
    /// @return proposals_ The decoded array of Proposals
    /// @return claims_ The decoded array of Claims
    function decodeProveData(bytes calldata _data)
        internal
        pure
        returns (IInbox.Proposal[] memory proposals_, IInbox.Claim[] memory claims_)
    {
        (proposals_, claims_) = abi.decode(_data, (IInbox.Proposal[], IInbox.Claim[]));
    }

    // -------------------------------------------------------------------------
    // Encode Functions
    // -------------------------------------------------------------------------

    /// @notice Encodes CoreState, BlobLocator array, and ClaimRecord array into bytes
    /// @param _coreState The CoreState to encode
    /// @param _blobLocators The array of BlobLocators to encode
    /// @param _claimRecords The array of ClaimRecords to encode
    /// @return data_ The encoded data
    function encodeProposeData(
        IInbox.CoreState memory _coreState,
        IInbox.BlobLocator[] memory _blobLocators,
        IInbox.ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        returns (bytes memory data_)
    {
        data_ = abi.encode(_coreState, _blobLocators, _claimRecords);
    }

    /// @notice Encodes Proposal array and Claim array into bytes
    /// @param _proposals The array of Proposals to encode
    /// @param _claims The array of Claims to encode
    /// @return data_ The encoded data
    function encodeProveData(
        IInbox.Proposal[] memory _proposals,
        IInbox.Claim[] memory _claims
    )
        internal
        pure
        returns (bytes memory data_)
    {
        data_ = abi.encode(_proposals, _claims);
    }
}
