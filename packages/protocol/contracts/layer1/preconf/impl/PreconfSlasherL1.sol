// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "src/layer2/preconf/IPreconfSlasherL2.sol";
import "@eth-fabric/urc/ISlasher.sol";

/// @title PreconfSlasherL1
/// @dev This contract is inherited by the `UnifiedSlasher`
/// @dev This contract is contains logic that is by `PreconfSlasherL2` for completing
/// the preconf slashing
/// @custom:security-contact security@taiko.xyz
abstract contract PreconfSlasherL1 {
    // Slashing logic
    // --------------------------------------------------------------------------

    /// @dev This is invoked internally by the `UnifiedSlasher` contract
    function _getPreconfSlashingFault(
        ISlasher.Commitment calldata _commitment,
        bytes calldata _evidence
    )
        internal
        view
        returns (IPreconfSlasherL2.Fault fault_)
    {
        IPreconfSlasherL2.Fault fault = abi.decode(_evidence, (IPreconfSlasherL2.Fault));
        IPreconfSlasherL2.Preconfirmation memory preconfirmation =
            abi.decode(_commitment.payload, (IPreconfSlasherL2.Preconfirmation));

        if (fault == IPreconfSlasherL2.Fault.PotentialLiveness) {
            // A potential liveness fault is a safety fault if the preconfer
            // did not miss its L1 slot.
            if (
                LibPreconfUtils.getBeaconBlockRootAt(preconfirmation.submissionWindowEnd)
                    != bytes32(0)
            ) {
                fault_ = IPreconfSlasherL2.Fault.Safety;
            } else {
                fault_ = IPreconfSlasherL2.Fault.Liveness;
            }
        }
    }
}
