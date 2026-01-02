// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IRegistry } from "@eth-fabric/urc/IRegistry.sol";
import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";
import { IPreconfSlasherL1 } from "src/layer1/preconf/iface/IPreconfSlasherL1.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { LibPreconfUtils } from "src/layer1/preconf/libs/LibPreconfUtils.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { IPreconfSlasher } from "src/shared/preconf/IPreconfSlasher.sol";

/// @title PreconfSlasherL1
/// @notice This contract is called by the L2 slasher contract via the native bridge. This
/// interfaces with the URC and slashes for preconfirmation faults.
/// @dev This is a stateless contract intended to be delegatecall-ed to by the `UnifiedSlasher`
/// @custom:security-contact security@taiko.xyz
contract PreconfSlasherL1 is IPreconfSlasherL1 {
    address public immutable urc;
    address public immutable preconfSlasherL2;
    address public immutable bridge;

    constructor(address _urc, address _preconfSlasherL2, address _bridge) {
        urc = _urc;
        preconfSlasherL2 = _preconfSlasherL2;
        bridge = _bridge;
    }

    /// @inheritdoc IPreconfSlasherL1
    function slash(
        ISlasher.Commitment calldata _commitment,
        bytes calldata _evidence,
        address _challenger
    )
        external
        view
        returns (uint256)
    {
        // Verify calling context
        require(_challenger == address(this), ChallengerIsNotSelf());

        require(
            _commitment.commitmentType == LibPreconfConstants.PRECONF_COMMITMENT_TYPE,
            InvalidCommitmentType()
        );

        IPreconfSlasher.Fault fault = abi.decode(_evidence, (IPreconfSlasher.Fault));
        IPreconfSlasher.Preconfirmation memory preconfirmation =
            abi.decode(_commitment.payload, (IPreconfSlasher.Preconfirmation));

        SlashAmount memory slashAmount = getSlashAmount();
        if (
            fault == IPreconfSlasher.Fault.MissedSubmission
                || fault == IPreconfSlasher.Fault.MissingEOP
        ) {
            // If the preconfer has missed its L1 slot, these faults are classified under liveness
            // faults, and incur a smaller penalty.
            if (
                LibPreconfUtils.getBeaconBlockRootAt(preconfirmation.submissionWindowEnd)
                    == bytes32(0)
            ) {
                return slashAmount.livenessFault;
            }
        }

        return slashAmount.safetyFault;
    }

    /// @inheritdoc IMessageInvocable
    /// @dev Invoked by the L2 preconf slasher
    function onMessageInvocation(bytes calldata _data) external payable {
        // Verify that the sender on the L2 side is the preconf slasher contract
        IBridge.Context memory ctx = IBridge(bridge).context();
        require(ctx.from == preconfSlasherL2, CallerIsNotPreconfSlasherL2());

        (
            IPreconfSlasher.Fault fault,
            bytes32 registrationRoot,
            ISlasher.SignedCommitment memory signedCommitment
        ) = abi.decode(_data, (IPreconfSlasher.Fault, bytes32, ISlasher.SignedCommitment));

        // Slash the operator via the URC
        IRegistry(urc).slashCommitment(registrationRoot, signedCommitment, abi.encode(fault));
    }

    // Views
    // ---------------------------------------------------------------

    /// @inheritdoc IPreconfSlasherL1
    function getSlashAmount() public pure returns (SlashAmount memory) {
        // Note: These values will be changed
        return SlashAmount({ livenessFault: 0.5 ether, safetyFault: 1 ether });
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error CallerIsNotPreconfSlasherL2();
    error ChallengerIsNotSelf();
    error InvalidCommitmentType();
    error MissedSlot();
}
