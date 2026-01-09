// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { FinalityGadgetInbox } from "../../features/FinalityGadgetInbox.sol";
import { FinalizationStreakInbox } from "../../features/FinalizationStreakInbox.sol";
import { RollbackInbox } from "../../features/RollbackInbox.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @title SurgeInbox
/// @notice Surge inbox implementation for internal-devnet deployment
/// @custom:security-contact security@nethermind.io
contract SurgeInbox is FinalityGadgetInbox, FinalizationStreakInbox, RollbackInbox {
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
        FinalizationStreakInbox(_maxFinalizationDelayBeforeStreakReset)
        RollbackInbox(_maxFinalizationDelayBeforeRollback)
    { }

    /// @dev Resolves diamond inheritance conflict for _afterActivate
    function _afterActivate() internal override(Inbox, FinalizationStreakInbox) {
        super._afterActivate();
    }

    /// @dev Resolves diamond inheritance conflict for _beforePropose
    function _beforePropose() internal override(Inbox, RollbackInbox) {
        super._beforePropose();
    }

    /// @dev Resolves diamond inheritance conflict for _beforeProve
    function _beforeProve() internal override(Inbox, FinalizationStreakInbox, RollbackInbox) {
        super._beforeProve();
    }

    /// @dev Resolves diamond inheritance conflict for _buildConsumptionResult
    function _buildConsumptionResult(ProposeInput memory _input)
        internal
        virtual
        override(Inbox, RollbackInbox)
        returns (ConsumptionResult memory result_)
    {
        result_ = super._buildConsumptionResult(_input);
    }

    /// @dev Resolves diamond inheritance conflict for _handleProofVerification
    function _handleProofVerification(
        uint256 _proposalAge,
        Commitment memory _commitment,
        bytes calldata _proof
    )
        internal
        view
        override(Inbox, FinalityGadgetInbox)
    {
        super._handleProofVerification(_proposalAge, _commitment, _proof);
    }
}
