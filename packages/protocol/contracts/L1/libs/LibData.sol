// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoData.sol";

/// @title LibData
/// @notice A library that offers helper functions.
/// @custom:security-contact security@taiko.xyz
library LibData {
    function blockV2toV1(
        TaikoData.BlockV2 memory _v2
    )
        internal
        pure
        returns (TaikoData.Block memory)
    {
        return TaikoData.Block({
            metaHash: _v2.metaHash,
            assignedProver: _v2.assignedProver,
            livenessBond: _v2.livenessBond,
            blockId: _v2.blockId,
            proposedAt: _v2.proposedAt,
            proposedIn: _v2.proposedIn,
            nextTransitionId: _v2.nextTransitionId,
            verifiedTransitionId: _v2.verifiedTransitionId
        });
    }
}
