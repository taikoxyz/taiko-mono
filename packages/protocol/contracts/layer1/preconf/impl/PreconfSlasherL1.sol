// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IPreconfSlasherL1.sol";
import "../libs/LibPreconfUtils.sol";
import "src/shared/bridge/IBridge.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/common/EssentialResolverContract.sol";
import "src/layer2/preconf/IPreconfSlasherL2.sol";
import "@eth-fabric/urc/IRegistry.sol";
import "@eth-fabric/urc/ISlasher.sol";

/// @title PreconfSlasherL1
/// @notice This contract is called by the L2 slasher contract via the native bridge. This
/// interfaces with the URC and slashes for preconfirmation faults.
/// @custom:security-contact security@taiko.xyz
contract PreconfSlasherL1 is IPreconfSlasher, EssentialResolverContract {
    address public immutable urc;

    constructor(address _resolver, address _urc) EssentialResolverContract(_resolver) {
        urc = _urc;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc ISlasher
    function slash(
        Delegation calldata, /* delegation */
        Commitment calldata _commitment,
        address, /* committer */
        bytes calldata _evidence,
        address _challenger
    )
        external
        view
        returns (uint256)
    {
        // Verify calling context
        require(_challenger == address(this), ChallengerIsNotSelf());
        require(msg.sender == urc, CallerIsNotURC());

        IPreconfSlasherL2.Fault fault = abi.decode(_evidence, (IPreconfSlasherL2.Fault));
        IPreconfSlasherL2.Preconfirmation memory preconfirmation =
            abi.decode(_commitment.payload, (IPreconfSlasherL2.Preconfirmation));

        // Liveness faults are not slashed if the proposer's submission slot was potentially reorged
        if (fault == IPreconfSlasherL2.Fault.Liveness) {
            require(
                LibPreconfUtils.getBeaconBlockRootAt(preconfirmation.submissionWindowEnd)
                    != bytes32(0),
                MissedSlot()
            );
        }

        IPreconfSlasher.SlashAmount memory amount = getSlashAmount();
        return
            (fault == IPreconfSlasherL2.Fault.Liveness) ? amount.livenessFault : amount.safetyFault;
    }

    /// @dev Invoked by the L2 preconf slasher
    function onMessageInvocation(bytes calldata _data) external payable {
        // Verify that the sender on the L2 side is the preconf slasher contract
        IBridge.Context memory ctx = IBridge(resolve(LibNames.B_BRIDGE, false)).context();
        address selfOnSrcChain = resolve(ctx.srcChainId, LibNames.B_PRECONF_SLASHER, false);
        require(ctx.from == selfOnSrcChain, CallerIsNotPreconfSlasherL2());

        (
            IPreconfSlasherL2.Fault fault,
            bytes32 registrationRoot,
            ISlasher.SignedCommitment memory signedCommitment
        ) = abi.decode(_data, (IPreconfSlasherL2.Fault, bytes32, ISlasher.SignedCommitment));

        // Slash the operator via the URC
        IRegistry(urc).slashCommitment(registrationRoot, signedCommitment, abi.encode(fault));
    }

    // Views
    // ---------------------------------------------------------------

    /// @inheritdoc IPreconfSlasher
    function getSlashAmount() public pure returns (SlashAmount memory slashAmount) {
        // Note: These values will be changed
        slashAmount = SlashAmount({ livenessFault: 0.5 ether, safetyFault: 1 ether });
    }
}
