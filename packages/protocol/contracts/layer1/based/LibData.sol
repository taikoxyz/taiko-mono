// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../verifiers/IVerifier.sol";
import "./TaikoData.sol";

/// @title LibData
/// @notice A library that offers data conversion helper functions.
/// @custom:security-contact security@taiko.xyz
library LibData {
    /// @notice Converts a BlockV2 struct to a Block struct.
    /// @param _v2 The BlockV2 struct to convert.
    /// @return The converted Block struct.
    function blockV2ToV1(TaikoData.BlockV2 memory _v2)
        internal
        pure
        returns (TaikoData.Block memory)
    {
        return TaikoData.Block({
            metaHash: _v2.metaHash,
            assignedProver: address(0), // assigned prover is now meta.proposer.
            livenessBond: 0, // liveness bond is now meta.livenessBond
            blockId: _v2.blockId,
            proposedAt: _v2.proposedAt,
            proposedIn: _v2.proposedIn,
            nextTransitionId: _v2.nextTransitionId,
            verifiedTransitionId: _v2.verifiedTransitionId
        });
    }

    /// @notice Converts a ContextV2 struct to a Context struct.
    /// @param _v2 The ContextV2 struct to convert.
    /// @return The converted Context struct.
    function verifierContextV2ToV1(IVerifier.ContextV2 memory _v2)
        internal
        pure
        returns (IVerifier.Context memory)
    {
        return IVerifier.Context({
            metaHash: _v2.metaHash,
            blobHash: _v2.blobHash,
            prover: _v2.prover,
            blockId: _v2.blockId,
            isContesting: _v2.isContesting,
            blobUsed: _v2.blobUsed,
            msgSender: _v2.msgSender
        });
    }
}
