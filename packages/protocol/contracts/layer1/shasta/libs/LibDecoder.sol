// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "./LibBlobs.sol";

import { IInbox } from "../iface/IInbox.sol";

/// @title LibDecoder
/// @notice Library for encoding and decoding data structures used in the Inbox system
/// @custom:security-contact security@taiko.xyz
// TODO:
// - [ ] provide better decode/encode implementation
library LibDecoder {
    // -------------------------------------------------------------------
    // Decode Functions
    // -------------------------------------------------------------------

    /// @notice Decodes data into CoreState, BlobReference array, and ClaimRecord array
    /// @param _data The encoded data
    /// @return deadline_ The decoded deadline
    /// @return coreState_ The decoded CoreState
    /// @return proposals_ The decoded array of Proposals
    /// @return blobReference_ The decoded BlobReference
    /// @return claimRecords_ The decoded array of ClaimRecords
    function decodeProposeData(bytes calldata _data)
        internal
        pure
        returns (
            uint64 deadline_,
            IInbox.CoreState memory coreState_,
            IInbox.Proposal[] memory proposals_,
            LibBlobs.BlobReference memory blobReference_,
            IInbox.ClaimRecord[] memory claimRecords_
        )
    {
        (deadline_, coreState_, proposals_, blobReference_, claimRecords_) = abi.decode(
            _data,
            (
                uint64,
                IInbox.CoreState,
                IInbox.Proposal[],
                LibBlobs.BlobReference,
                IInbox.ClaimRecord[]
            )
        );
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

    // -------------------------------------------------------------------
    // Encode Functions
    // -------------------------------------------------------------------

    /// @notice Encodes CoreState, BlobReference, and ClaimRecord array into bytes
    /// @param _coreState The CoreState to encode
    /// @param _blobReference The BlobReference to encode
    /// @param _claimRecords The array of ClaimRecords to encode
    /// @return data_ The encoded data
    function encodeProposeData(
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobReference,
        IInbox.ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        returns (bytes memory data_)
    {
        data_ = abi.encode(_coreState, _blobReference, _claimRecords);
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
