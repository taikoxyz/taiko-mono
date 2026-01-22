// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { FinalityGadgetInbox } from "../../features/FinalityGadgetInbox.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @title SurgeInbox
/// @notice Surge inbox implementation for internal-devnet deployment
/// @custom:security-contact security@nethermind.io
contract SurgeInbox is FinalityGadgetInbox {
    /// @param _config The inbox configuration
    /// @param _maxFinalizationDelayBeforeStreakReset The maximum grace period after which the
    /// finalization streak is reset
    /// @param _maxFinalizationDelayBeforeRollback The maximum grace period after which the chain
    /// can be rollbacked to the last finalized proposal
    constructor(
        IInbox.Config memory _config,
        uint48 _maxFinalizationDelayBeforeStreakReset,
        uint48 _maxFinalizationDelayBeforeRollback
    )
        Inbox(_config)
    { }

    /// @dev Resolves diamond inheritance conflict for _handleProofVerification
    function _handleProofVerification(
        uint256 _proposalAge,
        Commitment memory _commitment,
        bytes calldata _proof
    )
        internal
        view
        override(FinalityGadgetInbox)
    {
        super._handleProofVerification(_proposalAge, _commitment, _proof);
    }
}
