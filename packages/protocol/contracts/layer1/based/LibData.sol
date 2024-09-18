// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../verifiers/IVerifier.sol";
import "./TaikoData.sol";

/// @title LibData
/// @notice A library that offers helper functions.
/// @custom:security-contact security@taiko.xyz
library LibData {
    function blockV2toV1(TaikoData.BlockV2 memory _v2)
        internal
        pure
        returns (TaikoData.Block memory)
    {
        return TaikoData.Block({
            metaHash: _v2.metaHash,
            assignedProver: _v2.assignedProver,
            livenessBond: 0, // liveness bond is now in metadata
            blockId: _v2.blockId,
            proposedAt: _v2.proposedAt,
            proposedIn: _v2.proposedIn,
            nextTransitionId: _v2.nextTransitionId,
            verifiedTransitionId: _v2.verifiedTransitionId
        });
    }

    function verifierContextV2toV1(IVerifier.ContextV2 memory _v2)
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
