// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IL1StateRootProvider } from "./IL1StateRootProvider.sol";
import { SignalService } from "./SignalService.sol";

/// @title SignalServiceL2
/// @notice Verifies L1 signals using execution state roots recorded by the L2 Anchor's oracle.
/// @dev Uses SignalService's VERSION namespace and adds no storage slots.
/// @custom:security-contact security@taiko.xyz
contract SignalServiceL2 is SignalService {
    /// @notice Initializes the L2 root provider, remote SignalService and pauser.
    /// @param _authorizedSyncer L2 Anchor that saves legacy checkpoints and provides Etna roots.
    /// @param _remoteSignalService L1 SignalService whose account and signal slots are proven.
    /// @param _pauser Optional additional pause authority.
    constructor(
        address _authorizedSyncer,
        address _remoteSignalService,
        address _pauser
    )
        SignalService(_authorizedSyncer, _remoteSignalService, _pauser)
    { }

    /// @dev Reads the authenticated root from the configured provider.
    /// @param _blockId L1 block number before Etna, L2 timestamp from Etna on.
    /// @return stateRoot_ Authenticated L1 execution state root.
    function _getStateRoot(uint64 _blockId) internal view override returns (bytes32 stateRoot_) {
        return IL1StateRootProvider(_authorizedSyncer).getL1StateRoot(_blockId);
    }
}
