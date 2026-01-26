// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ICircuitVerifier } from "../iface/ICircuitVerifier.sol";
import { IShadow } from "../iface/IShadow.sol";
import { IShadowVerifier } from "../iface/IShadowVerifier.sol";
import { ShadowPublicInputs } from "../lib/ShadowPublicInputs.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title ShadowVerifier
/// @notice Verifies Shadow ZK proofs against checkpointed L1 state roots.
/// @custom:security-contact security@taiko.xyz
contract ShadowVerifier is IShadowVerifier {
    /// @notice The circuit verifier for cryptographic verification.
    ICircuitVerifier public immutable circuitVerifier;

    /// @notice The checkpoint store for L1 state roots.
    ICheckpointStore public immutable checkpointStore;

    /// @param _checkpointStore The checkpoint store address.
    /// @param _circuitVerifier The circuit verifier address.
    constructor(address _checkpointStore, address _circuitVerifier) {
        require(_checkpointStore != address(0), ZeroAddress());
        require(_circuitVerifier != address(0), ZeroAddress());
        checkpointStore = ICheckpointStore(_checkpointStore);
        circuitVerifier = ICircuitVerifier(_circuitVerifier);
    }

    /// @inheritdoc IShadowVerifier
    function verifyProof(
        bytes calldata _proof,
        IShadow.PublicInput calldata _input
    )
        external
        view
        returns (bool _isValid_)
    {
        bytes32 expectedStateRoot = checkpointStore.getCheckpoint(_input.blockNumber).stateRoot;
        require(expectedStateRoot != bytes32(0), CheckpointNotFound(_input.blockNumber));
        require(
            expectedStateRoot == _input.stateRoot,
            StateRootMismatch(expectedStateRoot, _input.stateRoot)
        );

        uint256[] memory publicInputs = ShadowPublicInputs.toArray(_input);
        bool ok = circuitVerifier.verifyProof(_proof, publicInputs);
        require(ok, ProofVerificationFailed());
        _isValid_ = true;
    }
}
