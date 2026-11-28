// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ISignalService } from "src/shared/signal/ISignalService.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title SignalService_ReadingRemoteStorage
/// @notice Test double that links two signal services living in the same test EVM.
/// @dev Replaces only the merkle-proof check. A proof attests that one storage slot of the remote
/// signal service is set; this double reads that same slot directly from the remote signal
/// service instead. A signal is therefore received if and only if the remote app really sent it,
/// unlike `SignalService_WithoutProofVerification`, which accepts everything.
/// @dev The proof bytes, the checkpoints and the received-signal cache are ignored. Sending
/// signals, the slot derivation, pausing and ownership are the real `SignalService`.
contract SignalService_ReadingRemoteStorage is SignalService {
    constructor(
        address authorizedSyncer,
        address remoteSignalService,
        address _pauser
    )
        SignalService(authorizedSyncer, remoteSignalService, _pauser)
    { }

    /// @inheritdoc ISignalService
    function proveSignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata /*_proof*/
    )
        external
        view
        override
        whenNotPaused
        returns (uint256)
    {
        _checkSentOnRemote(_chainId, _app, _signal);
        return 0;
    }

    /// @inheritdoc ISignalService
    function verifySignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata /*_proof*/
    )
        external
        view
        override
        whenNotPaused
    {
        _checkSentOnRemote(_chainId, _app, _signal);
    }

    /// @dev Reverts unless the remote signal service holds the signal in the slot a proof would
    /// have attested to.
    /// @param _chainId The chain the signal was sent on.
    /// @param _app The address that sent the signal.
    /// @param _signal The signal.
    function _checkSentOnRemote(uint64 _chainId, address _app, bytes32 _signal) private view {
        require(
            ISignalService(_remoteSignalService)
                .isSignalSent(getSignalSlot(_chainId, _app, _signal)),
            SS_SIGNAL_NOT_RECEIVED()
        );
    }
}
