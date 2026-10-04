// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibTrieProof } from "../libs/LibTrieProof.sol";
import { IL1StateRootProvider } from "./IL1StateRootProvider.sol";
import { ISignalServiceL2 } from "./ISignalServiceL2.sol";
import { SignalService } from "./SignalService.sol";

/// @title SignalServiceL2
/// @notice Verifies L1 signals using execution state roots recorded by the L2 Anchor's oracle.
/// @dev Uses SignalService's VERSION namespace and adds no storage slots.
/// @custom:security-contact security@taiko.xyz
contract SignalServiceL2 is SignalService, ISignalServiceL2 {
    /// @notice Four-byte prefix identifying timestamp-indexed state-root proofs.
    bytes4 public constant STATE_ROOT_PROOF_MAGIC = bytes4(keccak256("TAIKO_STATE_ROOT_PROOF_V1"));

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

    /// @dev Verifies an Etna envelope, or delegates legacy/cached proofs to the base verifier.
    /// @param _chainId Source chain ID.
    /// @param _app Source application that sent the signal.
    /// @param _signal Signal being proven.
    /// @param _proof Magic-prefixed StateRootProof, legacy HopProof[], or empty cached proof.
    function _verifySignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        internal
        view
        override
    {
        if (_proof.length < 4 || bytes4(_proof[:4]) != STATE_ROOT_PROOF_MAGIC) {
            super._verifySignalReceived(_chainId, _app, _signal, _proof);
            return;
        }
        require(_app != address(0), ZERO_ADDRESS());
        require(_signal != bytes32(0), ZERO_VALUE());

        StateRootProof memory proof = abi.decode(_proof[4:], (StateRootProof));
        if (proof.accountProof.length == 0 || proof.storageProof.length == 0) {
            revert SS_EMPTY_PROOF();
        }
        bytes32 stateRoot =
            IL1StateRootProvider(_authorizedSyncer).getL1StateRoot(proof.l2Timestamp);
        if (stateRoot == bytes32(0)) revert SS_INVALID_CHECKPOINT();
        LibTrieProof.verifyMerkleProof(
            stateRoot,
            _remoteSignalService,
            getSignalSlot(_chainId, _app, _signal),
            _signal,
            proof.accountProof,
            proof.storageProof
        );
    }
}
