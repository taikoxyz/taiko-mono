// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ICheckpointStore} from "../iface/ICheckpointStore.sol";
import {ICircuitVerifier} from "../iface/ICircuitVerifier.sol";
import {IShadow} from "../iface/IShadow.sol";
import {IShadowVerifier} from "../iface/IShadowVerifier.sol";
import {ShadowPublicInputs} from "../lib/ShadowPublicInputs.sol";

/// @custom:security-contact security@taiko.xyz

contract ShadowVerifier is IShadowVerifier {
    ICircuitVerifier public immutable circuitVerifier;
    ICheckpointStore public immutable checkpointStore;

    constructor(address _checkpointStore, address _circuitVerifier) {
        require(_checkpointStore != address(0), ZeroAddress());
        require(_circuitVerifier != address(0), ZeroAddress());
        checkpointStore = ICheckpointStore(_checkpointStore);
        circuitVerifier = ICircuitVerifier(_circuitVerifier);
    }

    /// @notice Verifies a proof and its public inputs.
    function verifyProof(bytes calldata _proof, IShadow.PublicInput calldata _input)
        external
        view
        returns (bool _isValid_)
    {
        bytes32 expectedStateRoot = checkpointStore.getCheckpoint(_input.blockNumber).stateRoot;
        require(expectedStateRoot != bytes32(0), CheckpointNotFound(_input.blockNumber));
        require(expectedStateRoot == _input.stateRoot, StateRootMismatch(expectedStateRoot, _input.stateRoot));

        uint256[] memory publicInputs = ShadowPublicInputs.toArray(_input);
        bool ok = circuitVerifier.verifyProof(_proof, publicInputs);
        require(ok, ProofVerificationFailed());
        _isValid_ = true;
    }
}
